import assert from 'node:assert/strict';
import test from 'node:test';

import {
  KUOTA_DASAR,
  PenyimpanKuotaMemori,
  catatPindaiBerhasil,
  cekKuotaTersedia,
} from '../kuota.js';
import { GalatOcrError } from '../ocr.js';
import { eksekusiPindaiLabel } from '../pindai.js';

const JPEG_VALID_B64 = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46]).toString(
  'base64',
);

const JSON_TERBACA = JSON.stringify({
  terbaca: true,
  takaran_saji: { jumlah: 30, satuan: 'g' },
  sajian_per_kemasan: 2,
  per_sajian: {
    energi_kkal: 140,
    gula_g: 12,
    natrium_mg: 95,
    garam_g: null,
    lemak_total_g: 6,
    protein_g: 2,
    karbohidrat_g: 19,
  },
});

const JSON_TIDAK_TERBACA = JSON.stringify({
  terbaca: false,
  takaran_saji: null,
  sajian_per_kemasan: null,
  per_sajian: null,
});

test('eksekusiPindaiLabel mereservasi kuota sebelum memanggil Gemini dan tidak mengurangi ganda saat berhasil', async () => {
  const store = new PenyimpanKuotaMemori();
  const waktu = new Date('2026-11-20T03:00:00Z');
  let sisaSaatGeminiDipanggil = -1;

  const { hasil, kuota } = await eksekusiPindaiLabel({
    store,
    uid: 'u1',
    data: { gambarBase64: JPEG_VALID_B64, versiKontrak: 1 },
    apiKey: 'kunci-uji',
    waktu,
    klienGemini: async () => {
      const sedangJalan = await cekKuotaTersedia(store, 'u1', waktu);
      sisaSaatGeminiDipanggil = sedangJalan.sisa;
      return JSON_TERBACA;
    },
  });

  assert.equal(hasil.terbaca, true);
  assert.equal(sisaSaatGeminiDipanggil, KUOTA_DASAR - 1);
  assert.equal(kuota.terpakai, 1);
  assert.equal(kuota.sisa, KUOTA_DASAR - 1);
});

test('eksekusiPindaiLabel mengembalikan reservasi kuota bila label tidak terbaca atau Gemini galat', async () => {
  const store = new PenyimpanKuotaMemori();
  const waktu = new Date('2026-11-20T03:00:00Z');

  // 1) terbaca: false -> kuota dikembalikan
  const resTidakTerbaca = await eksekusiPindaiLabel({
    store,
    uid: 'u1',
    data: { gambarBase64: JPEG_VALID_B64, versiKontrak: 1 },
    apiKey: 'kunci-uji',
    waktu,
    klienGemini: async () => JSON_TIDAK_TERBACA,
  });
  assert.equal(resTidakTerbaca.hasil.terbaca, false);
  assert.equal(resTidakTerbaca.kuota.terpakai, 0);
  assert.equal(resTidakTerbaca.kuota.sisa, KUOTA_DASAR);

  // 2) OCR melempar galat -> kuota dikembalikan
  await assert.rejects(
    () =>
      eksekusiPindaiLabel({
        store,
        uid: 'u1',
        data: { gambarBase64: JPEG_VALID_B64, versiKontrak: 1 },
        apiKey: 'kunci-uji',
        waktu,
        klienGemini: async () => {
          throw new GalatOcrError('deadline-exceeded', 'Batas waktu habis.');
        },
      }),
    (err: unknown) => err instanceof GalatOcrError && err.kode === 'deadline-exceeded',
  );

  const setelahGalat = await cekKuotaTersedia(store, 'u1', waktu);
  assert.equal(setelahGalat.terpakai, 0);
  assert.equal(setelahGalat.sisa, KUOTA_DASAR);

  // 3) Respons Gemini JSON rusak -> kuota dikembalikan
  await assert.rejects(
    () =>
      eksekusiPindaiLabel({
        store,
        uid: 'u1',
        data: { gambarBase64: JPEG_VALID_B64, versiKontrak: 1 },
        apiKey: 'kunci-uji',
        waktu,
        klienGemini: async () => 'bukan json',
      }),
    (err: unknown) => err instanceof GalatOcrError && err.kode === 'internal',
  );

  const setelahJsonRusak = await cekKuotaTersedia(store, 'u1', waktu);
  assert.equal(setelahJsonRusak.terpakai, 0);
  assert.equal(setelahJsonRusak.sisa, KUOTA_DASAR);
});

test('dua permintaan paralel saat sisa 1 hanya memanggil Gemini satu kali', async () => {
  const store = new PenyimpanKuotaMemori();
  const waktu = new Date('2026-11-20T03:00:00Z');

  for (let i = 0; i < KUOTA_DASAR - 1; i++) {
    await catatPindaiBerhasil(store, 'u1', true, waktu);
  }
  assert.equal((await cekKuotaTersedia(store, 'u1', waktu)).sisa, 1);

  let panggilanGemini = 0;
  const jalankanPindai = () =>
    eksekusiPindaiLabel({
      store,
      uid: 'u1',
      data: { gambarBase64: JPEG_VALID_B64, versiKontrak: 1 },
      apiKey: 'kunci-uji',
      waktu,
      klienGemini: async () => {
        panggilanGemini += 1;
        await new Promise((r) => setTimeout(r, 20));
        return JSON_TERBACA;
      },
    });

  const hasilParalel = await Promise.allSettled([jalankanPindai(), jalankanPindai()]);
  const sukses = hasilParalel.filter((r) => r.status === 'fulfilled');
  const gagal = hasilParalel.filter((r) => r.status === 'rejected');

  assert.equal(panggilanGemini, 1);
  assert.equal(sukses.length, 1);
  assert.equal(gagal.length, 1);
  if (gagal[0].status === 'rejected') {
    assert.ok(gagal[0].reason instanceof GalatOcrError);
    assert.equal(gagal[0].reason.kode, 'resource-exhausted');
  }

  const akhir = await cekKuotaTersedia(store, 'u1', waktu);
  assert.equal(akhir.terpakai, KUOTA_DASAR);
  assert.equal(akhir.sisa, 0);
});
