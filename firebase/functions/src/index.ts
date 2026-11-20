import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { defineSecret } from 'firebase-functions/params';
import { HttpsError, onCall, onRequest } from 'firebase-functions/v2/https';

import { verifikasiTandaTanganAdmob } from './admob_ssv.js';
import {
  buatPenyimpanFirestore,
  catatPindaiBerhasil,
  cekKuotaTersedia,
  hapusDataPenggunaDiStore,
  klaimBonusAdmobSsv,
} from './kuota.js';
import { GalatOcrError, MODEL_DEFAULT, prosesOcrLabel, validasiPermintaanOcr } from './ocr.js';

initializeApp();
const store = buatPenyimpanFirestore(getFirestore());
const geminiApiKey = defineSecret('GEMINI_API_KEY');

export const pindaiLabelGizi = onCall(
  {
    region: 'asia-southeast2',
    enforceAppCheck: true,
    secrets: [geminiApiKey],
    memory: '256MiB',
    timeoutSeconds: 60,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Autentikasi anonim diperlukan.');
    }

    try {
      validasiPermintaanOcr(request.data);
    } catch (err) {
      if (err instanceof GalatOcrError) {
        throw new HttpsError(err.kode, err.message);
      }
      throw new HttpsError('invalid-argument', 'Permintaan tidak valid.');
    }

    const kuotaAwal = await cekKuotaTersedia(store, uid);
    if (kuotaAwal.sisa <= 0) {
      throw new HttpsError('resource-exhausted', 'Kuota pindai minggu ini habis.');
    }

    try {
      const hasil = await prosesOcrLabel({
        data: request.data,
        apiKey: geminiApiKey.value(),
        model: process.env.GEMINI_MODEL || MODEL_DEFAULT,
      });
      const kuota = await catatPindaiBerhasil(store, uid, hasil.terbaca);
      return { hasil, kuota };
    } catch (err) {
      if (err instanceof GalatOcrError) {
        throw new HttpsError(err.kode, err.message);
      }
      throw new HttpsError('internal', 'Gagal memproses pindai label.');
    }
  },
);

export const hapusDataPengguna = onCall(
  {
    region: 'asia-southeast2',
    enforceAppCheck: true,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Autentikasi anonim diperlukan.');
    }
    await hapusDataPenggunaDiStore(store, uid);
    return { terhapus: true };
  },
);

export const admobSsvCallback = onRequest(
  {
    region: 'asia-southeast2',
  },
  async (req, res) => {
    if (req.method !== 'GET') {
      res.status(405).send('Method Not Allowed');
      return;
    }

    const rawUrl = req.originalUrl || req.url;
    const hasil = await verifikasiTandaTanganAdmob({
      rawUrl,
      expectedAdUnit: process.env.ADMOB_AD_UNIT_ID,
    });
    if (!hasil.valid) {
      res.status(403).send(hasil.alasan);
      return;
    }

    try {
      await klaimBonusAdmobSsv(store, hasil.data.userId, hasil.data.transactionId);
      res.status(200).send('OK');
    } catch {
      res.status(500).send('Internal Error');
    }
  },
);
