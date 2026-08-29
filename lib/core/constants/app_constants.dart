/// App-wide constants.
class AppConstants {
  const AppConstants._();

  // ── Donation cooldown ───────────────────────────────────────────────
  /// Minimum days between whole-blood donations (Pakistan Red Crescent).
  static const int donationCooldownDays = 56;

  /// Minimum days between platelet donations.
  static const int plateletCooldownDays = 7;

  // ── Supported blood types ───────────────────────────────────────────
  static const List<String> bloodTypes = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-',
  ];

  // ── Compatible donor map ────────────────────────────────────────────
  /// Maps a recipient blood type to the blood types that can donate to them.
  static const Map<String, List<String>> compatibleDonors = {
    'A+':  ['A+', 'A-', 'O+', 'O-'],
    'A-':  ['A-', 'O-'],
    'B+':  ['B+', 'B-', 'O+', 'O-'],
    'B-':  ['B-', 'O-'],
    'AB+': ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
    'AB-': ['A-', 'B-', 'AB-', 'O-'],
    'O+':  ['O+', 'O-'],
    'O-':  ['O-'],
  };

  // ── Pakistani cities (initial list) ─────────────────────────────────
  static const List<String> defaultCities = [
    'Karachi',
    'Lahore',
    'Islamabad',
    'Rawalpindi',
    'Faisalabad',
    'Multan',
    'Peshawar',
    'Quetta',
    'Sialkot',
    'Gujranwala',
    'Hyderabad',
    'Bahawalpur',
    'Sargodha',
    'Sukkur',
    'Larkana',
    'Abbottabad',
    'Mardan',
    'Mingora',
    'Nawabshah',
    'Sahiwal',
    'Rahim Yar Khan',
    'Kasur',
    'Okara',
    'Wah Cantt',
    'Dera Ghazi Khan',
    'Sheikhupura',
    'Jhelum',
    'Gujrat',
    'Mirpur Khas',
    'Chiniot',
    'Dera Ismail Khan',
    'Kohat',
    'Nowshera',
    'Muzaffarabad',
    'Mirpur',
    'Gilgit',
    'Skardu',
    'Turbat',
    'Gwadar',
    'Vehari',
  ];

  // ── Pakistani city coordinates ──────────────────────────────────────
  static const Map<String, ({double lat, double lng})> cityCoords = {
    'karachi':            (lat: 24.8607, lng: 67.0011),
    'lahore':             (lat: 31.5204, lng: 74.3587),
    'islamabad':          (lat: 33.6844, lng: 73.0479),
    'rawalpindi':         (lat: 33.5651, lng: 73.0169),
    'faisalabad':         (lat: 31.4504, lng: 73.1350),
    'multan':             (lat: 30.1575, lng: 71.5249),
    'peshawar':           (lat: 34.0151, lng: 71.5249),
    'quetta':             (lat: 30.1798, lng: 66.9750),
    'sialkot':            (lat: 32.4945, lng: 74.5229),
    'gujranwala':         (lat: 32.1877, lng: 74.1945),
    'hyderabad':          (lat: 25.3960, lng: 68.3578),
    'bahawalpur':         (lat: 29.3544, lng: 71.6911),
    'sargodha':           (lat: 32.0740, lng: 72.6861),
    'sukkur':             (lat: 27.7052, lng: 68.8574),
    'larkana':            (lat: 27.5551, lng: 68.2140),
    'abbottabad':         (lat: 34.1708, lng: 73.2218),
    'mardan':             (lat: 34.1989, lng: 72.0417),
    'mingora':            (lat: 34.7725, lng: 72.3617),
    'nawabshah':          (lat: 26.2483, lng: 68.4100),
    'sahiwal':            (lat: 30.6682, lng: 73.1114),
    'rahim yar khan':     (lat: 28.4187, lng: 70.3036),
    'kasur':              (lat: 31.1187, lng: 74.4503),
    'okara':              (lat: 30.8138, lng: 73.4537),
    'wah cantt':          (lat: 33.7934, lng: 72.6894),
    'dera ghazi khan':    (lat: 30.0459, lng: 70.6387),
    'sheikhupura':        (lat: 31.7167, lng: 73.9850),
    'jhelum':             (lat: 32.9345, lng: 73.7310),
    'gujrat':             (lat: 32.5776, lng: 74.0783),
    'mirpur khas':        (lat: 25.5276, lng: 69.0156),
    'chiniot':            (lat: 31.7167, lng: 72.9788),
    'dera ismail khan':   (lat: 31.8313, lng: 70.9017),
    'kohat':              (lat: 33.5869, lng: 71.4414),
    'nowshera':           (lat: 34.0077, lng: 71.9877),
    'muzaffarabad':       (lat: 34.3700, lng: 73.4711),
    'mirpur':             (lat: 33.1461, lng: 73.7497),
    'gilgit':             (lat: 35.9208, lng: 74.3144),
    'skardu':             (lat: 35.2974, lng: 75.6333),
    'turbat':             (lat: 26.2975, lng: 62.8378),
    'gwadar':             (lat: 25.1217, lng: 62.3254),
    'vehari':             (lat: 30.0444, lng: 72.3556),
  };

  // ── Urgency levels ──────────────────────────────────────────────────
  static const String urgencyNormal = 'normal';
  static const String urgencyUrgent = 'urgent';
  static const String urgencyCritical = 'critical';

  // ── User roles ──────────────────────────────────────────────────────
  static const String roleSeeker = 'seeker';
  static const String roleDonor = 'donor';

  // ── Pagination ──────────────────────────────────────────────────────
  static const int defaultPageSize = 20;

  // ── Map defaults ────────────────────────────────────────────────────
  /// Default center: Islamabad, Pakistan
  static const double defaultLatitude = 33.6844;
  static const double defaultLongitude = 73.0479;
  static const double defaultZoom = 12.0;
}
