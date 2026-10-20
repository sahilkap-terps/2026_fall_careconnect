package com.careconnect.config;

import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.TestPropertySource;

import javax.sql.DataSource;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;

/**
 * Verifies {@link SchemaPatchRunner#dedupBeforeUniqueIndex} (I3d) against a real PostgreSQL — the
 * thing H2 and the mocked unit tests cannot exercise, because the de-dup is
 * {@code isPostgreSql()}-gated and written in PL/pgSQL. The review (Team E cross-team review,
 * §I3d) raised that the original {@code ctid}-based retention kept an arbitrary physical row and
 * deleted divergent clinical content silently. These cases pin the replacement rule:
 *
 * <ul>
 *   <li>survivor = greatest {@code source_updated_at}, tie-broken by greatest {@code id};</li>
 *   <li>every loser is copied to {@code ehr_dedup_quarantine} before deletion (reversible);</li>
 *   <li>the guard short-circuits when the target index already exists;</li>
 *   <li>distinct keys are untouched;</li>
 *   <li>the subsequent {@code CREATE UNIQUE INDEX} succeeds once the group is de-duplicated.</li>
 * </ul>
 *
 * <p>Opt-in, like the other PostgreSQL tests in this module: skipped unless {@code EHR_IT_JDBC_URI}
 * is set. Everything runs against a throwaway {@code sptest_dedup_med} table (not the real
 * {@code ehr_*} tables) and the test's own {@code ehr_dedup_quarantine} rows are scoped by
 * {@code table_name}, so a shared target database is never mutated beyond what each test cleans up.
 *
 * <p>Test IDs TC-EHR-DEDUP-001..005 are permanent. Never renumber, never reuse.
 */
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@EnabledIfEnvironmentVariable(named = "EHR_IT_JDBC_URI", matches = ".+")
@TestPropertySource(properties = {
        "spring.datasource.url=${EHR_IT_JDBC_URI}",
        "spring.datasource.username=${EHR_IT_DB_USER}",
        "spring.datasource.password=${EHR_IT_DB_PASSWORD}",
        "spring.datasource.driver-class-name=org.postgresql.Driver",
        "spring.jpa.database-platform=org.hibernate.dialect.PostgreSQLDialect",
        "spring.jpa.hibernate.ddl-auto=none",
        "spring.flyway.enabled=false",
        "spring.sql.init.mode=never"
})
class SchemaPatchRunnerDedupPostgresTest {

    private static final String TABLE = "sptest_dedup_med";
    private static final String KEY = "external_medication_id";
    private static final String INDEX = "uq_sptest_dedup_med";

    /** The de-dup statement under test, built exactly as the runner builds it. */
    private static final String DEDUP = SchemaPatchRunner.dedupBeforeUniqueIndex(TABLE, KEY, INDEX);

    private static final Instant T1 = Instant.parse("2026-01-01T00:00:00Z");
    private static final Instant T2 = Instant.parse("2026-02-01T00:00:00Z");

    @Autowired
    private DataSource dataSource;
    @Autowired
    private EntityManager em; // forces the JPA datasource to be the one under test

    private JdbcTemplate jdbc;

    @BeforeEach
    void setUp() {
        jdbc = new JdbcTemplate(dataSource);
        jdbc.execute(SchemaPatchRunner.createDedupQuarantineTable());
        jdbc.execute("DROP TABLE IF EXISTS " + TABLE);
        jdbc.execute("CREATE TABLE " + TABLE + " ("
                + "id bigserial PRIMARY KEY, "
                + "patient_id bigint NOT NULL, "
                + "source_id bigint NOT NULL, "
                + "external_medication_id varchar(255) NOT NULL, "
                + "source_updated_at timestamptz NOT NULL, "
                + "medication_display varchar(512))");
        jdbc.update("DELETE FROM ehr_dedup_quarantine WHERE table_name = ?", TABLE);
    }

    @AfterEach
    void tearDown() {
        jdbc.execute("DROP TABLE IF EXISTS " + TABLE);
        jdbc.update("DELETE FROM ehr_dedup_quarantine WHERE table_name = ?", TABLE);
    }

    private void insert(long patient, long source, String ext, Instant updated, String display) {
        jdbc.update("INSERT INTO " + TABLE + " (patient_id, source_id, external_medication_id, "
                        + "source_updated_at, medication_display) VALUES (?,?,?,?,?)",
                patient, source, ext, OffsetDateTime.ofInstant(updated, ZoneOffset.UTC), display);
    }

    private long liveCount() {
        return jdbc.queryForObject("SELECT count(*) FROM " + TABLE, Long.class);
    }

    private long quarantineCount() {
        return jdbc.queryForObject(
                "SELECT count(*) FROM ehr_dedup_quarantine WHERE table_name = ?", Long.class, TABLE);
    }

    @Test
    @DisplayName("TC-EHR-DEDUP-001: keeps the greatest source_updated_at; quarantines the older row")
    void keepsLatestBySourceUpdatedAt() {
        insert(1, 1, "rx-1", T1, "older");
        insert(1, 1, "rx-1", T2, "newer");

        jdbc.execute(DEDUP);

        assertThat(liveCount()).isEqualTo(1);
        assertThat(jdbc.queryForObject(
                "SELECT medication_display FROM " + TABLE, String.class)).isEqualTo("newer");
        assertThat(quarantineCount()).isEqualTo(1);
        assertThat(jdbc.queryForObject(
                "SELECT row_data->>'medication_display' FROM ehr_dedup_quarantine WHERE table_name = ?",
                String.class, TABLE)).isEqualTo("older");
    }

    @Test
    @DisplayName("TC-EHR-DEDUP-002: on equal source_updated_at, keeps the greatest id (last inserted)")
    void tieBreaksOnId() {
        insert(1, 1, "rx-1", T1, "first");
        insert(1, 1, "rx-1", T1, "second");

        jdbc.execute(DEDUP);

        assertThat(liveCount()).isEqualTo(1);
        assertThat(jdbc.queryForObject(
                "SELECT medication_display FROM " + TABLE, String.class)).isEqualTo("second");
        assertThat(quarantineCount()).isEqualTo(1);
    }

    @Test
    @DisplayName("TC-EHR-DEDUP-003: three-row group collapses to one survivor, two quarantined")
    void threeRowGroupCollapsesToOne() {
        insert(1, 1, "rx-1", T1, "a");
        insert(1, 1, "rx-1", T2, "b");
        insert(1, 1, "rx-1", T1, "c");

        jdbc.execute(DEDUP);

        assertThat(liveCount()).isEqualTo(1);
        assertThat(jdbc.queryForObject(
                "SELECT medication_display FROM " + TABLE, String.class)).isEqualTo("b");
        assertThat(quarantineCount()).isEqualTo(2);
    }

    @Test
    @DisplayName("TC-EHR-DEDUP-004: distinct keys are left untouched; nothing quarantined; index then builds")
    void distinctKeysUntouchedThenIndexBuilds() {
        insert(1, 1, "rx-1", T1, "one");
        insert(1, 1, "rx-2", T1, "two");
        insert(2, 1, "rx-1", T1, "three");

        jdbc.execute(DEDUP);

        assertThat(liveCount()).isEqualTo(3);
        assertThat(quarantineCount()).isZero();

        // The whole point of the de-dup: the required unique index now builds cleanly.
        assertThatCode(() -> jdbc.execute(
                "CREATE UNIQUE INDEX IF NOT EXISTS " + INDEX + " ON " + TABLE
                        + " (patient_id, source_id, external_medication_id)"))
                .doesNotThrowAnyException();
    }

    @Test
    @DisplayName("TC-EHR-DEDUP-005: guard short-circuits when the index name already exists (no deletes)")
    void noOpWhenIndexAlreadyPresent() {
        // An index of the target name already exists, so the guard must do nothing — even though
        // duplicate-key rows are present (possible here only because this stand-in index is non-unique).
        jdbc.execute("CREATE INDEX " + INDEX + " ON " + TABLE + " (patient_id)");
        insert(1, 1, "rx-1", T1, "older");
        insert(1, 1, "rx-1", T2, "newer");

        jdbc.execute(DEDUP);

        assertThat(liveCount()).isEqualTo(2);
        assertThat(quarantineCount()).isZero();
        List<String> displays = jdbc.queryForList(
                "SELECT medication_display FROM " + TABLE + " ORDER BY id", String.class);
        assertThat(displays).containsExactly("older", "newer");
    }
}
