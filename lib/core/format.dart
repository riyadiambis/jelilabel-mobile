const _hari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
const _bulan = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

/// "Rabu, 19 Nov". Tanpa paket intl: cukup untuk bahasa Indonesia saja.
String tanggalPendek(DateTime t) => '${_hari[t.weekday - 1]}, ${t.day} ${_bulan[t.month - 1]}';

/// "Rab"
String hariSingkat(DateTime t) => _hari[t.weekday - 1].substring(0, 3);

/// "10.15"
String jam(DateTime t) => '${t.hour.toString().padLeft(2, '0')}.${t.minute.toString().padLeft(2, '0')}';
