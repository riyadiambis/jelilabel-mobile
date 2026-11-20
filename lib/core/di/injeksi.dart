import 'package:get_it/get_it.dart';

import '../../features/asupan/asupan_cubit.dart';
import '../../features/asupan/data/asupan_repository.dart';
import '../database/basis_data.dart';

final getIt = GetIt.instance;

Future<void> siapkanDependensi({
  String? lokasiDb,
  DateTime Function()? jam,
}) async {
  await resetDependensi();
  final basisData = await BasisData.buka(lokasiDb: lokasiDb);
  getIt.registerSingleton<BasisData>(basisData);
  getIt.registerLazySingleton<AsupanRepository>(() => AsupanRepository(getIt<BasisData>().db));
  getIt.registerFactory<AsupanCubit>(() => AsupanCubit(getIt<AsupanRepository>(), jam: jam));
}

Future<void> resetDependensi() async {
  if (getIt.isRegistered<BasisData>()) {
    await getIt<BasisData>().tutup();
  }
  await getIt.reset();
}
