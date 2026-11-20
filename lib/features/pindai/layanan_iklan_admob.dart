import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'layanan_iklan.dart';

const String _adUnitRewardedProd = String.fromEnvironment('ADMOB_REWARDED_UNIT_ID');
const String _adUnitRewardedTestAndroid = 'ca-app-pub-3940256099942544/5224354917';

String? _pilihAdUnitId() {
  if (_adUnitRewardedProd.isNotEmpty) return _adUnitRewardedProd;
  if (kDebugMode) return _adUnitRewardedTestAndroid;
  return null;
}

/// Implementasi produksi iklan video berhadiah memakai Google AdMob RewardedAd.
///
/// Pada mode Spark (`pakaiSsv: false`), bonus +1 diberikan lokal saat `onUserEarnedReward`.
/// Jika `pakaiSsv: true` (`PINDAI_LEWAT_FUNCTIONS=true`), UID anonim dikirim ke Cloud Functions
/// lewat Server-Side Verification (SSV).
class LayananIklanAdMob implements LayananIklanKuota {
  LayananIklanAdMob({this.pakaiSsv = false});

  final bool pakaiSsv;

  @override
  Future<bool> tampilkanVideoHadiah() async {
    final adUnitId = _pilihAdUnitId();
    if (adUnitId == null) return false;

    String? ssvUid;
    if (pakaiSsv) {
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser ?? (await auth.signInAnonymously()).user;
      final uid = user?.uid;
      if (uid == null || uid.isEmpty) return false;
      ssvUid = uid;
    }

    final completer = Completer<bool>();
    var hadiahDiterima = false;

    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          if (ssvUid != null) {
            ad.setServerSideOptions(ServerSideVerificationOptions(userId: ssvUid));
          }
          ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
            onAdDismissedFullScreenContent: (RewardedAd ad) {
              ad.dispose();
              if (!completer.isCompleted) completer.complete(hadiahDiterima);
            },
            onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError _) {
              ad.dispose();
              if (!completer.isCompleted) completer.complete(false);
            },
          );
          ad.show(
            onUserEarnedReward: (_, _) {
              hadiahDiterima = true;
            },
          );
        },
        onAdFailedToLoad: (LoadAdError _) {
          if (!completer.isCompleted) completer.complete(false);
        },
      ),
    );

    return completer.future;
  }
}

/// Menghapus data kuota pengguna di Firestore lewat Cloud Functions `hapusDataPengguna`.
Future<void> hapusDataServer() async {
  if (Firebase.apps.isEmpty) return;
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) return;
  final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast2').httpsCallable(
    'hapusDataPengguna',
    options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
  );
  await callable.call<dynamic>();
}
