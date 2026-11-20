import {
  type PenyimpanKuota,
  type StatusKuota,
  ZONA_WAKTU_DEFAULT,
  cekKuotaTersedia,
  kembalikanReservasiKuota,
  reservasiKuotaPindai,
} from './kuota.js';
import {
  GalatOcrError,
  type HasilOcr,
  type KlienGemini,
  prosesOcrLabel,
  validasiPermintaanOcr,
} from './ocr.js';

/**
 * Menjalankan alur pindai label dengan reservasi kuota atomik sebelum memanggil Gemini,
 * lalu mengembalikan reservasi jika OCR gagal, tidak terbaca, atau melempar galat.
 */
export async function eksekusiPindaiLabel(params: {
  store: PenyimpanKuota;
  uid: string;
  data: unknown;
  apiKey: string;
  model?: string;
  klienGemini?: KlienGemini;
  waktu?: Date;
  timeZone?: string;
}): Promise<{ hasil: HasilOcr; kuota: StatusKuota }> {
  validasiPermintaanOcr(params.data);
  if (!params.apiKey.trim()) {
    throw new GalatOcrError('internal', 'Kunci API Gemini server belum dikonfigurasi.');
  }

  const timeZone = params.timeZone ?? ZONA_WAKTU_DEFAULT;
  const reservasi = await reservasiKuotaPindai(
    params.store,
    params.uid,
    params.waktu ?? new Date(),
    timeZone,
  );
  if (!reservasi.berhasil) {
    throw new GalatOcrError('resource-exhausted', 'Kuota pindai minggu ini habis.');
  }

  try {
    const hasil = await prosesOcrLabel({
      data: params.data,
      apiKey: params.apiKey,
      model: params.model,
      klienGemini: params.klienGemini,
    });

    if (!hasil.terbaca) {
      const kuota = await kembalikanReservasiKuota(
        params.store,
        params.uid,
        reservasi.minggu,
        params.waktu ?? new Date(),
        timeZone,
      );
      return { hasil, kuota };
    }

    const kuota = await cekKuotaTersedia(
      params.store,
      params.uid,
      params.waktu ?? new Date(),
      timeZone,
    );
    return { hasil, kuota };
  } catch (err) {
    try {
      await kembalikanReservasiKuota(
        params.store,
        params.uid,
        reservasi.minggu,
        params.waktu ?? new Date(),
        timeZone,
      );
    } catch (refundErr) {
      console.error('Gagal mengembalikan reservasi kuota:', refundErr);
    }
    throw err;
  }
}
