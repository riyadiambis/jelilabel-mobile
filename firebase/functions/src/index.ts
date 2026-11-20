import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { defineSecret } from 'firebase-functions/params';
import { HttpsError, onCall, onRequest } from 'firebase-functions/v2/https';

import { tanganiAdmobSsvCallback } from './admob_ssv.js';
import { buatPenyimpanFirestore, hapusDataPenggunaDiStore } from './kuota.js';
import { GalatOcrError, MODEL_DEFAULT } from './ocr.js';
import { eksekusiPindaiLabel } from './pindai.js';

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
      return await eksekusiPindaiLabel({
        store,
        uid,
        data: request.data,
        apiKey: geminiApiKey.value(),
        model: process.env.GEMINI_MODEL || MODEL_DEFAULT,
      });
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
    await tanganiAdmobSsvCallback({
      req,
      res,
      store,
    });
  },
);
