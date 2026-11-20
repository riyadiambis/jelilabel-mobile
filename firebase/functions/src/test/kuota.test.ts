import assert from 'node:assert/strict';
import test from 'node:test';

import {
  BONUS_IKLAN_MAKS,
  KUOTA_DASAR,
  PLAFON_MINGGUAN,
  PenyimpanKuotaMemori,
  catatPindaiBerhasil,
  cekKuotaTersedia,
  hapusDataPenggunaDiStore,
  klaimBonusAdmobSsv,
  tanggalSeninLokal,
} from '../kuota.js';

test('tanggalSeninLokal menghitung Senin Asia/Jakarta dengan tepat', () => {
  // 2026-11-22 17:05 UTC = 2026-11-23 00:05 WIB (Senin)
  assert.equal(tanggalSeninLokal(new Date('2026-11-22T17:05:00Z')), '2026-11-23');
  // 2026-11-22 16:55 UTC = 2026-11-22 23:55 WIB (Minggu, masih minggu 2026-11-16)
  assert.equal(tanggalSeninLokal(new Date('2026-11-22T16:55:00Z')), '2026-11-16');
});

test('catatPindaiBerhasil hanya mengurangi kuota jika terbaca === true', async () => {
  const store = new PenyimpanKuotaMemori();
  const waktu = new Date('2026-11-20T03:00:00Z');

  const awal = await cekKuotaTersedia(store, 'u1', waktu);
  assert.equal(awal.sisa, KUOTA_DASAR);

  const gagal = await catatPindaiBerhasil(store, 'u1', false, waktu);
  assert.equal(gagal.terpakai, 0);
  assert.equal(gagal.sisa, KUOTA_DASAR);

  const sukses = await catatPindaiBerhasil(store, 'u1', true, waktu);
  assert.equal(sukses.terpakai, 1);
  assert.equal(sukses.sisa, KUOTA_DASAR - 1);
});

test('klaimBonusAdmobSsv idempoten pada transaction_id yang sama dan dibatasi +10/minggu', async () => {
  const store = new PenyimpanKuotaMemori();
  const waktu = new Date('2026-11-20T03:00:00Z');

  const pertama = await klaimBonusAdmobSsv(store, 'u1', 'tx-001', waktu);
  assert.equal(pertama.status, 'ditambahkan');
  assert.equal(pertama.kuota.bonusIklan, 1);
  assert.equal(pertama.kuota.sisa, KUOTA_DASAR + 1);

  const duplikat = await klaimBonusAdmobSsv(store, 'u1', 'tx-001', waktu);
  assert.equal(duplikat.status, 'duplikat');
  assert.equal(duplikat.kuota.bonusIklan, 1);

  for (let i = 2; i <= BONUS_IKLAN_MAKS; i++) {
    const res = await klaimBonusAdmobSsv(store, 'u1', `tx-00${i}`, waktu);
    assert.equal(res.status, 'ditambahkan');
  }

  const lewatBatas = await klaimBonusAdmobSsv(store, 'u1', 'tx-099', waktu);
  assert.equal(lewatBatas.status, 'batas_tercapai');
  assert.equal(lewatBatas.kuota.bonusIklan, BONUS_IKLAN_MAKS);
  assert.equal(lewatBatas.kuota.sisa, PLAFON_MINGGUAN);

  // Masuk Senin baru -> reset ke dasar 5 dan bonus 0
  const seninBaru = new Date('2026-11-22T17:10:00Z');
  const mingguBaru = await cekKuotaTersedia(store, 'u1', seninBaru);
  assert.equal(mingguBaru.terpakai, 0);
  assert.equal(mingguBaru.bonusIklan, 0);
  assert.equal(mingguBaru.sisa, KUOTA_DASAR);
});

test('hapusDataPenggunaDiStore menghapus dokumen pengguna dan riwayat SSV', async () => {
  const store = new PenyimpanKuotaMemori();
  const waktu = new Date('2026-11-20T03:00:00Z');

  await catatPindaiBerhasil(store, 'u1', true, waktu);
  await klaimBonusAdmobSsv(store, 'u1', 'tx-1', waktu);
  assert.ok(store.lihatPengguna('u1'));

  await hapusDataPenggunaDiStore(store, 'u1');
  assert.equal(store.lihatPengguna('u1'), undefined);

  await assert.rejects(() => klaimBonusAdmobSsv(store, 'a/b', 'tx-1', waktu));
  await assert.rejects(() => klaimBonusAdmobSsv(store, 'u1', 'tx/1', waktu));
});
