import assert from 'node:assert/strict';
import test from 'node:test';

import {
  BATAS_GAMBAR_BYTE,
  GalatOcrError,
  MODEL_DEFAULT,
  PROMPT_OCR,
  prosesOcrLabel,
  validasiHasilGemini,
  validasiPermintaanOcr,
} from '../ocr.js';

const JPEG_VALID_B64 = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46]).toString('base64');

test('validasiPermintaanOcr menerima JPEG valid dengan versiKontrak 1', () => {
  const hasil = validasiPermintaanOcr({ gambarBase64: JPEG_VALID_B64, versiKontrak: 1 });
  assert.equal(hasil.versiKontrak, 1);
  assert.equal(hasil.gambarBase64, JPEG_VALID_B64);
});

test('validasiPermintaanOcr menolak versiKontrak salah, bukan JPEG, dan ukuran > 1 MB', () => {
  assert.throws(
    () => validasiPermintaanOcr({ gambarBase64: JPEG_VALID_B64, versiKontrak: 2 }),
    (err: unknown) => err instanceof GalatOcrError && err.kode === 'invalid-argument',
  );

  const pngB64 = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]).toString('base64');
  assert.throws(
    () => validasiPermintaanOcr({ gambarBase64: pngB64, versiKontrak: 1 }),
    (err: unknown) => err instanceof GalatOcrError && err.kode === 'invalid-argument',
  );

  const besar = Buffer.alloc(BATAS_GAMBAR_BYTE + 10, 0x00);
  besar[0] = 0xff;
  besar[1] = 0xd8;
  besar[2] = 0xff;
  assert.throws(
    () => validasiPermintaanOcr({ gambarBase64: besar.toString('base64'), versiKontrak: 1 }),
    (err: unknown) => err instanceof GalatOcrError && err.kode === 'invalid-argument',
  );
});

test('validasiHasilGemini menormalkan terbaca false bila gula/natrium/garam semua null', () => {
  const raw = JSON.stringify({
    terbaca: true,
    takaran_saji: { jumlah: 30, satuan: 'gram' },
    sajian_per_kemasan: 2,
    per_sajian: {
      energi_kkal: 100,
      gula_g: null,
      natrium_mg: null,
      garam_g: null,
      lemak_total_g: 2,
      protein_g: 1,
      karbohidrat_g: 10,
    },
  });
  const hasil = validasiHasilGemini(raw);
  assert.equal(hasil.terbaca, false);
  assert.equal(hasil.takaran_saji?.satuan, null);
});

test('prosesOcrLabel memanggil klien Gemini dengan model default gemini-3.1-flash-lite dan mengembalikan JSON tervalidasi', async () => {
  let modelDipakai = '';
  let promptDipakai = '';

  const hasil = await prosesOcrLabel({
    data: { gambarBase64: JPEG_VALID_B64, versiKontrak: 1 },
    apiKey: 'kunci-uji',
    klienGemini: async ({ model, prompt }) => {
      modelDipakai = model;
      promptDipakai = prompt;
      return JSON.stringify({
        terbaca: true,
        takaran_saji: { jumlah: 200, satuan: 'ml' },
        sajian_per_kemasan: 1,
        per_sajian: {
          energi_kkal: 130,
          gula_g: 12,
          natrium_mg: 95,
          garam_g: null,
          lemak_total_g: 3,
          protein_g: 6,
          karbohidrat_g: 18,
        },
      });
    },
  });

  assert.equal(modelDipakai, MODEL_DEFAULT);
  assert.equal(promptDipakai, PROMPT_OCR);
  assert.equal(hasil.terbaca, true);
  assert.equal(hasil.per_sajian?.gula_g, 12);
  assert.equal(hasil.per_sajian?.natrium_mg, 95);
});
