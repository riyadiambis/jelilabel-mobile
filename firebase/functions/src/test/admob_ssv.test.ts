import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import test from 'node:test';

import {
  parseQueryAdmobSsv,
  tanganiAdmobSsvCallback,
  verifikasiTandaTanganAdmob,
} from '../admob_ssv.js';
import { PenyimpanKuotaMemori, cekKuotaTersedia } from '../kuota.js';

function buatUrlSsvTertanda(
  privateKey: crypto.KeyObject,
  keyId: number,
  adUnit: string = '1234567890',
): string {
  const payload =
    `ad_network=5450213213286189855&ad_unit=${adUnit}&reward_amount=1&reward_item=pindai&timestamp=1763630000000&transaction_id=tx-admob-99&user_id=anon-uid-1`;
  const signer = crypto.createSign('SHA256');
  signer.update(payload, 'utf8');
  signer.end();
  const sigUrlSafe = signer
    .sign(privateKey)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');

  return `/admobSsvCallback?${payload}&signature=${encodeURIComponent(sigUrlSafe)}&key_id=${keyId}`;
}

test('verifikasiTandaTanganAdmob menerima tanda tangan ECDSA SHA-256 yang sah', async () => {
  const { publicKey, privateKey } = crypto.generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
  const pemPublik = publicKey.export({ type: 'spki', format: 'pem' }).toString();
  const rawUrl = buatUrlSsvTertanda(privateKey, 3335741209);

  const hasil = await verifikasiTandaTanganAdmob({
    rawUrl,
    expectedAdUnit: '1234567890',
    ambilKunci: async () => [{ keyId: 3335741209, pem: pemPublik }],
  });

  assert.equal(hasil.valid, true);
  if (hasil.valid) {
    assert.equal(hasil.data.userId, 'anon-uid-1');
    assert.equal(hasil.data.transactionId, 'tx-admob-99');
  }
});

test('verifikasiTandaTanganAdmob menolak payload yang diubah atau key_id salah', async () => {
  const { publicKey, privateKey } = crypto.generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
  const pemPublik = publicKey.export({ type: 'spki', format: 'pem' }).toString();
  const rawUrl = buatUrlSsvTertanda(privateKey, 3335741209);

  const diubah = rawUrl.replace('user_id=anon-uid-1', 'user_id=penyerang');
  const hasilUbah = await verifikasiTandaTanganAdmob({
    rawUrl: diubah,
    expectedAdUnit: '1234567890',
    ambilKunci: async () => [{ keyId: 3335741209, pem: pemPublik }],
  });
  assert.equal(hasilUbah.valid, false);

  const hasilKeySalah = await verifikasiTandaTanganAdmob({
    rawUrl,
    expectedAdUnit: '1234567890',
    ambilKunci: async () => [{ keyId: 999999, pem: pemPublik }],
  });
  assert.equal(hasilKeySalah.valid, false);

  const hasilUnitSalah = await verifikasiTandaTanganAdmob({
    rawUrl,
    ambilKunci: async () => [{ keyId: 3335741209, pem: pemPublik }],
    expectedAdUnit: '9999999999',
  });
  assert.equal(hasilUnitSalah.valid, false);

  const hasilUnitCocok = await verifikasiTandaTanganAdmob({
    rawUrl,
    ambilKunci: async () => [{ keyId: 3335741209, pem: pemPublik }],
    expectedAdUnit: '1234567890',
  });
  assert.equal(hasilUnitCocok.valid, true);

  assert.equal(parseQueryAdmobSsv('/admobSsvCallback?user_id=u1'), null);
  assert.equal(
    parseQueryAdmobSsv(
      '/admobSsvCallback?transaction_id=tx-1&user_id=a/b&signature=abc&key_id=1',
    ),
    null,
  );
});

test('SSV fail-closed menolak hadiah bila ADMOB_AD_UNIT_ID tidak diset kecuali penanda eksplisit', async () => {
  const { publicKey, privateKey } = crypto.generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
  const pemPublik = publicKey.export({ type: 'spki', format: 'pem' }).toString();
  const rawUrl = buatUrlSsvTertanda(privateKey, 3335741209, '1234567890');
  const ambilKunci = async () => [{ keyId: 3335741209, pem: pemPublik }];

  // Tanpa expectedAdUnit dan tanpa izinkanTanpaAdUnit -> wajib ditolak
  const tanpaUnit = await verifikasiTandaTanganAdmob({ rawUrl, ambilKunci });
  assert.equal(tanpaUnit.valid, false);

  const unitKosong = await verifikasiTandaTanganAdmob({
    rawUrl,
    expectedAdUnit: '   ',
    ambilKunci,
  });
  assert.equal(unitKosong.valid, false);

  // Dengan penanda eksplisit untuk emulator/tes -> diterima
  const denganPenanda = await verifikasiTandaTanganAdmob({
    rawUrl,
    ambilKunci,
    izinkanTanpaAdUnit: true,
  });
  assert.equal(denganPenanda.valid, true);

  // Uji handler HTTP callback
  const buatRes = () => {
    const out = { status: 0, body: '' };
    return {
      out,
      res: {
        status(code: number) {
          out.status = code;
          return {
            send(body: unknown) {
              out.body = String(body);
              return out;
            },
          };
        },
      },
    };
  };

  const waktu = new Date('2026-11-20T03:00:00Z');
  const store = new PenyimpanKuotaMemori();

  // 1) env ADMOB_AD_UNIT_ID tidak diset -> tolak 403, bonus tidak bertambah
  const r1 = buatRes();
  await tanganiAdmobSsvCallback({
    req: { method: 'GET', originalUrl: rawUrl },
    res: r1.res,
    store,
    env: {},
    ambilKunci,
    waktu,
  });
  assert.equal(r1.out.status, 403);
  assert.equal((await cekKuotaTersedia(store, 'anon-uid-1', waktu)).bonusIklan, 0);

  // 2) FUNCTIONS_EMULATOR=true saja tanpa penanda eksplisit -> tetap tolak 403
  const r2 = buatRes();
  await tanganiAdmobSsvCallback({
    req: { method: 'GET', originalUrl: rawUrl },
    res: r2.res,
    store,
    env: { FUNCTIONS_EMULATOR: 'true' },
    ambilKunci,
    waktu,
  });
  assert.equal(r2.out.status, 403);
  assert.equal((await cekKuotaTersedia(store, 'anon-uid-1', waktu)).bonusIklan, 0);

  // 3) ad_unit lain dari ADMOB_AD_UNIT_ID -> tolak 403
  const r3 = buatRes();
  await tanganiAdmobSsvCallback({
    req: { method: 'GET', originalUrl: rawUrl },
    res: r3.res,
    store,
    env: { ADMOB_AD_UNIT_ID: '9999999999' },
    ambilKunci,
    waktu,
  });
  assert.equal(r3.out.status, 403);
  assert.equal((await cekKuotaTersedia(store, 'anon-uid-1', waktu)).bonusIklan, 0);

  // 4) ADMOB_AD_UNIT_ID cocok -> 200 OK dan bonus +1
  const r4 = buatRes();
  await tanganiAdmobSsvCallback({
    req: { method: 'GET', originalUrl: rawUrl },
    res: r4.res,
    store,
    env: { ADMOB_AD_UNIT_ID: '1234567890' },
    ambilKunci,
    waktu,
  });
  assert.equal(r4.out.status, 200);
  assert.equal((await cekKuotaTersedia(store, 'anon-uid-1', waktu)).bonusIklan, 1);

  // 5) Emulator dengan penanda eksplisit -> 200 OK
  const storeEmu = new PenyimpanKuotaMemori();
  const r5 = buatRes();
  await tanganiAdmobSsvCallback({
    req: { method: 'GET', originalUrl: rawUrl },
    res: r5.res,
    store: storeEmu,
    env: {
      FUNCTIONS_EMULATOR: 'true',
      ADMOB_SSV_EMULATOR_ALLOW_UNSET_AD_UNIT: 'true',
    },
    ambilKunci,
    waktu,
  });
  assert.equal(r5.out.status, 200);
  assert.equal((await cekKuotaTersedia(storeEmu, 'anon-uid-1', waktu)).bonusIklan, 1);
});
