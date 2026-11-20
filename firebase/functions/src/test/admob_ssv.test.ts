import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import test from 'node:test';

import { parseQueryAdmobSsv, verifikasiTandaTanganAdmob } from '../admob_ssv.js';

function buatUrlSsvTertanda(privateKey: crypto.KeyObject, keyId: number): string {
  const payload =
    'ad_network=5450213213286189855&ad_unit=1234567890&reward_amount=1&reward_item=pindai&timestamp=1763630000000&transaction_id=tx-admob-99&user_id=anon-uid-1';
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
    ambilKunci: async () => [{ keyId: 3335741209, pem: pemPublik }],
  });
  assert.equal(hasilUbah.valid, false);

  const hasilKeySalah = await verifikasiTandaTanganAdmob({
    rawUrl,
    ambilKunci: async () => [{ keyId: 999999, pem: pemPublik }],
  });
  assert.equal(hasilKeySalah.valid, false);

  assert.equal(parseQueryAdmobSsv('/admobSsvCallback?user_id=u1'), null);
});
