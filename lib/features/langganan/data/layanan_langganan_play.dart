import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
// ignore: depend_on_referenced_packages, GooglePlayProductDetails (base plan) hanya ada di paket platform bawaan in_app_purchase
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../../asupan/data/asupan_repository.dart';
import '../domain/layanan_langganan.dart';

/// Implementasi Google Play Billing. Mode Spark tanpa server: pembelian hanya diverifikasi
/// di HP (risiko pembelian palsu diterima untuk v1, ISSUE-23).
class LayananLanggananPlay implements LayananLangganan {
  LayananLanggananPlay(this._repo, {InAppPurchase? iap}) : _iap = iap ?? InAppPurchase.instance;

  final AsupanRepository _repo;
  final InAppPurchase _iap;
  final _status = StreamController<bool>.broadcast();
  final _produk = <BasePlan, ProductDetails>{};
  StreamSubscription<List<PurchaseDetails>>? _langganan;
  Completer<HasilBeli>? _menungguBeli;
  Completer<void>? _menungguPulih;
  bool _aktif = false;

  @override
  bool get plusAktif => _aktif;

  @override
  Stream<bool> get statusPlus => _status.stream;

  @override
  Future<void> inisialisasi() async {
    _aktif = await _repo.bacaPengaturan(AsupanRepository.kunciPlusAktif) == '1';
    _langganan ??= _iap.purchaseStream.listen(_tangani, onError: (_) {});
    // Tidak ditunggu agar app tidak tertahan: offline atau Play belum siap berarti status tersimpan
    // dipakai dulu dan dicek lagi saat app dibuka berikutnya.
    unawaited(pulihkan().then((_) {}, onError: (_) {}));
  }

  @override
  Future<List<PaketPlus>> muatProduk() async {
    if (!await _iap.isAvailable()) return const [];
    final hasil = await _iap.queryProductDetails({idProdukPlus});
    if (hasil.error != null) return const [];
    _produk.clear();
    for (final d in hasil.productDetails.whereType<GooglePlayProductDetails>()) {
      final i = d.subscriptionIndex;
      if (i == null) continue;
      final tawaran = d.productDetails.subscriptionOfferDetails![i];
      if (tawaran.offerId != null) continue; // hanya harga base plan, bukan promo
      for (final plan in BasePlan.values) {
        if (plan.id == tawaran.basePlanId) _produk[plan] = d;
      }
    }
    return [
      for (final plan in BasePlan.values)
        if (_produk[plan] != null) PaketPlus(basePlan: plan, harga: _produk[plan]!.price),
    ];
  }

  @override
  Future<HasilBeli> beli(BasePlan basePlan) async {
    if (_menungguBeli != null) return HasilBeli.gagal; // satu pembelian sekali jalan
    final produk = _produk[basePlan];
    if (produk == null) return HasilBeli.gagal;
    final menunggu = _menungguBeli = Completer<HasilBeli>();
    try {
      // Langganan di Android dibeli lewat buyNonConsumable; offerToken diambil dari produk.
      final mulai = await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: produk));
      if (!mulai) return HasilBeli.gagal;
      return await menunggu.future;
    } catch (_) {
      return HasilBeli.gagal;
    } finally {
      _menungguBeli = null;
    }
  }

  @override
  Future<bool> pulihkan() async {
    final menunggu = _menungguPulih = Completer<void>();
    try {
      await _iap.restorePurchases();
      await menunggu.future.timeout(const Duration(seconds: 15));
    } on TimeoutException {
      // Status tersimpan dipertahankan.
    } finally {
      _menungguPulih = null;
    }
    return _aktif;
  }

  /// Satu paket pembaruan dari Play. Status disimpan dulu, baru `completePurchase`;
  /// error atau batal tidak mengubah status.
  Future<void> _tangani(List<PurchaseDetails> daftar) async {
    var adaPlus = false;
    HasilBeli? hasil;
    for (final p in daftar) {
      if (p.productID != idProdukPlus) continue;
      switch (p.status) {
        case PurchaseStatus.pending:
          hasil = HasilBeli.tertunda;
        case PurchaseStatus.error:
          hasil = HasilBeli.gagal;
        case PurchaseStatus.canceled:
          hasil = HasilBeli.batal;
        case PurchaseStatus.purchased || PurchaseStatus.restored:
          try {
            await _setAktif(true, token: p.verificationData.serverVerificationData);
            if (p.pendingCompletePurchase) await _iap.completePurchase(p);
            adaPlus = true;
            hasil = HasilBeli.berhasil;
          } catch (_) {
            hasil = HasilBeli.gagal; // belum tersimpan: tidak di-complete, Play mengirim ulang
          }
      }
    }
    // Paket dari restorePurchases tanpa Plus berarti langganan sudah berakhir.
    final pulih = _menungguPulih;
    if (pulih != null && !pulih.isCompleted) {
      if (!adaPlus && hasil == null) {
        try {
          await _setAktif(false);
        } catch (_) {
          // Gagal menulis: status lama dipertahankan.
        }
      }
      pulih.complete();
    }
    if (hasil != null && _menungguBeli?.isCompleted == false) _menungguBeli!.complete(hasil);
  }

  Future<void> _setAktif(bool aktif, {String? token}) async {
    await _repo.tulisPengaturan(AsupanRepository.kunciPlusAktif, aktif ? '1' : '0');
    if (token != null) await _repo.tulisPengaturan(AsupanRepository.kunciPlusTokenTerakhir, token);
    if (_aktif == aktif) return;
    _aktif = aktif;
    if (!_status.isClosed) _status.add(aktif);
  }

  @override
  Future<void> tutup() async {
    await _langganan?.cancel();
    await _status.close();
  }
}
