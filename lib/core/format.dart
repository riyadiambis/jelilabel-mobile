const _hari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
const _bulan = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
const _bulanLengkap = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

/// Awal minggu lokal (Senin pukul 00:00).
DateTime awalMinggu(DateTime t) {
  final l = t.isUtc ? t.toLocal() : t;
  return DateTime(l.year, l.month, l.day - (l.weekday - DateTime.monday));
}

/// "16 sampai 22 November" (atau "30 November sampai 6 Desember" bila lintas bulan).
String rentangMinggu(DateTime senin) {
  final awal = awalMinggu(senin);
  final akhir = awal.add(const Duration(days: 6));
  if (awal.month == akhir.month) {
    return '${awal.day} sampai ${akhir.day} ${_bulanLengkap[akhir.month - 1]}';
  }
  return '${awal.day} ${_bulanLengkap[awal.month - 1]} sampai ${akhir.day} ${_bulanLengkap[akhir.month - 1]}';
}

/// "Rabu, 19 Nov". Tanpa paket intl: cukup untuk bahasa Indonesia saja.
String tanggalPendek(DateTime t) => '${_hari[t.weekday - 1]}, ${t.day} ${_bulan[t.month - 1]}';

/// "19 Nov"
String tanggalSingkat(DateTime t) => '${t.day} ${_bulan[t.month - 1]}';

/// "Rab"
String hariSingkat(DateTime t) => _hari[t.weekday - 1].substring(0, 3);

/// "10.15"
String jam(DateTime t) => '${t.hour.toString().padLeft(2, '0')}.${t.minute.toString().padLeft(2, '0')}';
