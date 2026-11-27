import 'package:get_it/get_it.dart';

import '../../features/asupan/asupan_cubit.dart';
import '../../features/asupan/data/asupan_repository.dart';
import '../../features/bagikan/layanan_bagikan.dart';
import '../../features/pindai/layanan_iklan.dart';
import '../../features/pindai/pemindai_label.dart';
import '../../features/produk/produk_cubit.dart';
import '../../features/rapor/rapor_cubit.dart';
import '../../features/riwayat/riwayat_cubit.dart';
import '../../features/tantangan/data/tantangan_repository.dart';
import '../../features/tantangan/presentation/tantangan_cubit.dart';
import '../database/basis_data.dart';

final getIt = GetIt.instance;

Future<void> siapkanDependensi({
  String? lokasiDb,
  DateTime Function()? jam,
  LayananIklanKuota? layananIklan,
  PemindaiLabel? pemindaiLabel,
  LayananBagikan? layananBagikan,
  Future<void> Function()? hapusDataServer,
}) async {
  await resetDependensi();
  final basisData = await BasisData.buka(lokasiDb: lokasiDb);
  getIt.registerSingleton<BasisData>(basisData);
  getIt.registerLazySingleton<AsupanRepository>(() => AsupanRepository(getIt<BasisData>().db));
  getIt.registerLazySingleton<TantanganRepository>(() => TantanganRepository(getIt<BasisData>().db));
  getIt.registerLazySingleton<LayananIklanKuota>(() => layananIklan ?? const LayananIklanSimulasi());
  getIt.registerLazySingleton<PemindaiLabel>(() => pemindaiLabel ?? PemindaiLabelSimulasi());
  getIt.registerLazySingleton<LayananBagikan>(() => layananBagikan ?? const LayananBagikanSharePlus());
  getIt.registerFactory<AsupanCubit>(
    () => AsupanCubit(
      getIt<AsupanRepository>(),
      jam: jam,
      layananIklan: getIt<LayananIklanKuota>(),
      pemindaiLabel: getIt<PemindaiLabel>(),
      hapusDataServer: hapusDataServer,
    ),
  );
  getIt.registerFactory<ProdukCubit>(() => ProdukCubit(getIt<AsupanRepository>()));
  getIt.registerFactory<RaporCubit>(() => RaporCubit(getIt<AsupanRepository>(), jam: jam));
  getIt.registerFactory<RiwayatCubit>(() => RiwayatCubit(getIt<AsupanRepository>(), jam: jam));
  getIt.registerFactory<TantanganCubit>(() => TantanganCubit(getIt<TantanganRepository>(), jam: jam));
}

Future<void> resetDependensi() async {
  if (getIt.isRegistered<BasisData>()) {
    await getIt<BasisData>().tutup();
  }
  await getIt.reset();
}
