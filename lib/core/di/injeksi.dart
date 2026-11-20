import 'package:get_it/get_it.dart';

import '../../features/asupan/asupan_cubit.dart';
import '../../features/asupan/data/asupan_repository.dart';
import '../../features/pindai/layanan_iklan.dart';
import '../database/basis_data.dart';

final getIt = GetIt.instance;

Future<void> siapkanDependensi({
  String? lokasiDb,
  DateTime Function()? jam,
  LayananIklanKuota? layananIklan,
}) async {
  await resetDependensi();
  final basisData = await BasisData.buka(lokasiDb: lokasiDb);
  getIt.registerSingleton<BasisData>(basisData);
  getIt.registerLazySingleton<AsupanRepository>(() => AsupanRepository(getIt<BasisData>().db));
  getIt.registerLazySingleton<LayananIklanKuota>(() => layananIklan ?? const LayananIklanSimulasi());
  getIt.registerFactory<AsupanCubit>(
    () => AsupanCubit(
      getIt<AsupanRepository>(),
      jam: jam,
      layananIklan: getIt<LayananIklanKuota>(),
    ),
  );
}

Future<void> resetDependensi() async {
  if (getIt.isRegistered<BasisData>()) {
    await getIt<BasisData>().tutup();
  }
  await getIt.reset();
}
