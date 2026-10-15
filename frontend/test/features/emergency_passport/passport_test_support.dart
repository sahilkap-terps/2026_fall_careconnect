// Shared test data for the CC-12 scan tests: a passport with every section shared.

const fullPassport = {
  'name': 'Jordan Miller',
  'age': 41,
  'bloodType': 'O_POSITIVE',
  'allergies': [
    {'allergen': 'Penicillin', 'severity': 'LIFE_THREATENING', 'reaction': 'Anaphylaxis'},
    {'allergen': 'Peanuts', 'severity': 'MODERATE', 'reaction': 'Hives, swelling'},
    {'allergen': 'Latex', 'severity': null, 'reaction': null},
  ],
  'medications': [
    {'name': 'Lisinopril', 'dosage': '10 mg', 'frequency': 'Once daily'},
  ],
  'chronicConditions': 'Type 2 diabetes',
  'emergencyContact': {
    'name': 'Taylor Miller',
    'relationship': 'Spouse',
    'phone': '(415) 555-0184',
  },
  'lastUpdated': '2026-10-13T15:00:00Z',
};
