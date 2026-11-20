import assert from 'node:assert/strict';
import test from 'node:test';
import type { Firestore } from 'firebase-admin/firestore';

import {
  BONUS_IKLAN_MAKS,
  KUOTA_DASAR,
  PLAFON_MINGGUAN,
  PenyimpanKuotaMemori,
  buatPenyimpanFirestore,
  catatPindaiBerhasil,
  cekKuotaTersedia,
  hapusDataPenggunaDiStore,
  kembalikanReservasiKuota,
  klaimBonusAdmobSsv,
  reservasiKuotaPindai,
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

test('hapusDataPenggunaDiStore menghapus data pribadi tetapi mempertahankan kuota dan riwayat SSV', async () => {
  const store = new PenyimpanKuotaMemori();
  const waktu = new Date('2026-11-20T03:00:00Z');

  store.simpanDataPribadi('u1', { catatan: 'data pribadi pengguna' });
  await catatPindaiBerhasil(store, 'u1', true, waktu);
  await catatPindaiBerhasil(store, 'u1', true, waktu);
  await klaimBonusAdmobSsv(store, 'u1', 'tx-1', waktu);
  assert.ok(store.lihatDataPribadi('u1'));
  assert.ok(store.lihatPengguna('u1'));

  await hapusDataPenggunaDiStore(store, 'u1');
  assert.equal(store.lihatDataPribadi('u1'), undefined);

  // Kuota minggu berjalan tetap tersimpan (tidak reset ke 0)
  const kuotaSetelahHapus = await cekKuotaTersedia(store, 'u1', waktu);
  assert.equal(kuotaSetelahHapus.terpakai, 2);
  assert.equal(kuotaSetelahHapus.bonusIklan, 1);
  assert.equal(kuotaSetelahHapus.sisa, KUOTA_DASAR + 1 - 2);

  // Replay SSV dengan transaction_id lama tetap ditolak
  const replay = await klaimBonusAdmobSsv(store, 'u1', 'tx-1', waktu);
  assert.equal(replay.status, 'duplikat');
  assert.equal(replay.kuota.bonusIklan, 1);
  assert.equal(replay.kuota.sisa, KUOTA_DASAR + 1 - 2);

  await assert.rejects(() => klaimBonusAdmobSsv(store, 'a/b', 'tx-1', waktu));
  await assert.rejects(() => klaimBonusAdmobSsv(store, 'u1', 'tx/1', waktu));
});

test('buatPenyimpanFirestore memisahkan kuota & SSV dari users dan tidak menyimpan data pribadi', async () => {
  const docs = new Map<string, Record<string, unknown>>();
  const recursiveDeletedPaths: string[] = [];

  const makeDocRef = (path: string): unknown => ({
    path,
    collection: (sub: string) => ({
      doc: (id: string) => makeDocRef(`${path}/${sub}/${id}`),
    }),
  });

  const fakeDb = {
    collection: (col: string) => ({
      doc: (id: string) => makeDocRef(`${col}/${id}`),
    }),
    async runTransaction<T>(fn: (t: unknown) => Promise<T>): Promise<T> {
      const t = {
        get: async (ref: { path: string }) => {
          const d = docs.get(ref.path);
          return {
            exists: d !== undefined,
            data: () => d,
          };
        },
        set: (ref: { path: string }, data: Record<string, unknown>) => {
          docs.set(ref.path, { ...data });
        },
      };
      return fn(t);
    },
    recursiveDelete: async (ref: { path: string }) => {
      recursiveDeletedPaths.push(ref.path);
      for (const key of [...docs.keys()]) {
        if (key === ref.path || key.startsWith(`${ref.path}/`)) {
          docs.delete(key);
        }
      }
    },
  } as unknown as Firestore;

  const store = buatPenyimpanFirestore(fakeDb);
  const waktu = new Date('2026-11-20T03:00:00Z');
  docs.set('users/u1', { nama: 'Riyadi', email: 'pribadi@example.com' });

  await catatPindaiBerhasil(store, 'u1', true, waktu);
  await klaimBonusAdmobSsv(store, 'u1', 'tx-fs-1', waktu);
  await hapusDataPenggunaDiStore(store, 'u1');

  assert.deepEqual(recursiveDeletedPaths, ['users/u1']);
  assert.equal(docs.get('users/u1'), undefined);

  const kuotaDoc = docs.get('kuota_mingguan/u1');
  assert.deepEqual(kuotaDoc, {
    minggu: '2026-11-16',
    terpakai: 1,
    bonusIklan: 1,
  });

  const ssvDoc = docs.get('kuota_mingguan/u1/ssv_transaksi/tx-fs-1');
  assert.deepEqual(ssvDoc, {
    transaction_id: 'tx-fs-1',
    minggu: '2026-11-16',
  });

  const replay = await klaimBonusAdmobSsv(store, 'u1', 'tx-fs-1', waktu);
  assert.equal(replay.status, 'duplikat');
});

test('reservasiKuotaPindai dan kembalikanReservasiKuota aman terhadap transaksi paralel dan pergantian minggu', async () => {
  const store = new PenyimpanKuotaMemori();
  const waktu = new Date('2026-11-20T03:00:00Z');

  for (let i = 0; i < KUOTA_DASAR - 1; i++) {
    await catatPindaiBerhasil(store, 'u1', true, waktu);
  }

  const [r1, r2] = await Promise.all([
    reservasiKuotaPindai(store, 'u1', waktu),
    reservasiKuotaPindai(store, 'u1', waktu),
  ]);
  const jumlahBerhasil = [r1, r2].filter((r) => r.berhasil).length;
  assert.equal(jumlahBerhasil, 1);

  // Pergantian minggu saat panggilan lambat gagal tidak boleh mengurangi terpakai minggu baru
  const seninBaru = new Date('2026-11-23T03:00:00Z');
  await reservasiKuotaPindai(store, 'u1', seninBaru);
  const statusSenin = await kembalikanReservasiKuota(store, 'u1', '2026-11-16', seninBaru);
  assert.equal(statusSenin.terpakai, 1);
  assert.equal(statusSenin.sisa, KUOTA_DASAR - 1);
});
