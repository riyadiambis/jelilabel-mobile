import crypto from 'node:crypto';

export const ADMOB_VERIFIER_KEYS_URL = 'https://www.gstatic.com/admob/reward/verifier-keys.json';
const CACHE_TTL_MS = 24 * 60 * 60 * 1000;
const REFRESH_COOLDOWN_MS = 60 * 1000;

export interface KunciVerifikasiAdmob {
  keyId: number | string;
  pem: string;
  base64?: string;
}

export type PengambilKunciAdmob = (paksaSegar?: boolean) => Promise<KunciVerifikasiAdmob[]>;

let cacheKunci: { keys: KunciVerifikasiAdmob[]; diambilPada: number } | null = null;

export const ambilKunciAdmobDefault: PengambilKunciAdmob = async (paksaSegar = false) => {
  const sekarang = Date.now();
  if (
    cacheKunci &&
    (!paksaSegar
      ? sekarang - cacheKunci.diambilPada < CACHE_TTL_MS
      : sekarang - cacheKunci.diambilPada < REFRESH_COOLDOWN_MS)
  ) {
    return cacheKunci.keys;
  }
  const res = await fetch(ADMOB_VERIFIER_KEYS_URL, {
    signal: AbortSignal.timeout(10_000),
  });
  if (!res.ok) {
    throw new Error(`Gagal mengambil verifier-keys.json: status ${res.status}`);
  }
  const json = (await res.json()) as { keys?: KunciVerifikasiAdmob[] };
  if (!Array.isArray(json.keys)) {
    throw new Error('Format verifier-keys.json tidak valid');
  }
  cacheKunci = { keys: json.keys, diambilPada: sekarang };
  return json.keys;
};

export interface DataSsvAdmob {
  contentToVerify: string;
  signature: string;
  keyId: string;
  transactionId: string;
  userId: string;
  adUnit: string;
}

function idDokumenAman(nilai: string): boolean {
  return Boolean(nilai) && !nilai.includes('/') && nilai !== '.' && nilai !== '..';
}

export function parseQueryAdmobSsv(rawUrl: string): DataSsvAdmob | null {
  const qIdx = rawUrl.indexOf('?');
  const queryString = qIdx === -1 ? rawUrl : rawUrl.slice(qIdx + 1);
  if (!queryString) return null;

  const sigMarker = '&signature=';
  const sigIdx = queryString.indexOf(sigMarker);
  if (sigIdx === -1) return null;

  const contentToVerify = queryString.slice(0, sigIdx);
  const params = new URLSearchParams(queryString);
  const signature = params.get('signature') ?? '';
  const keyId = params.get('key_id') ?? '';
  const transactionId = (params.get('transaction_id') ?? '').trim();
  const userId = (params.get('user_id') || params.get('custom_data') || '').trim();
  const adUnit = (params.get('ad_unit') ?? '').trim();

  if (
    !contentToVerify ||
    !signature ||
    !keyId ||
    !idDokumenAman(transactionId) ||
    !idDokumenAman(userId)
  ) {
    return null;
  }

  return {
    contentToVerify,
    signature,
    keyId,
    transactionId,
    userId,
    adUnit,
  };
}

export async function verifikasiTandaTanganAdmob(params: {
  rawUrl: string;
  ambilKunci?: PengambilKunciAdmob;
  expectedAdUnit?: string;
}): Promise<{ valid: true; data: DataSsvAdmob } | { valid: false; alasan: string }> {
  const data = parseQueryAdmobSsv(params.rawUrl);
  if (!data) {
    return { valid: false, alasan: 'Parameter query SSV tidak lengkap' };
  }

  const expectedAdUnit = params.expectedAdUnit?.trim();
  if (expectedAdUnit && data.adUnit !== expectedAdUnit) {
    return { valid: false, alasan: 'ad_unit tidak cocok' };
  }

  const ambilKunci = params.ambilKunci ?? ambilKunciAdmobDefault;
  let kunciDaftar: KunciVerifikasiAdmob[];
  try {
    kunciDaftar = await ambilKunci(false);
  } catch {
    return { valid: false, alasan: 'Gagal mengambil kunci publik AdMob' };
  }

  let cocok = kunciDaftar.find((k) => String(k.keyId) === String(data.keyId));
  if (!cocok && !params.ambilKunci) {
    try {
      kunciDaftar = await ambilKunci(true);
      cocok = kunciDaftar.find((k) => String(k.keyId) === String(data.keyId));
    } catch {
      return { valid: false, alasan: 'Gagal memperbarui kunci publik AdMob' };
    }
  }
  if (!cocok || !cocok.pem) {
    return { valid: false, alasan: 'key_id tidak ditemukan' };
  }

  const normalizedSig = data.signature.replace(/-/g, '+').replace(/_/g, '/');
  const sigBuf = Buffer.from(normalizedSig, 'base64');

  try {
    const verifier = crypto.createVerify('SHA256');
    verifier.update(data.contentToVerify, 'utf8');
    verifier.end();
    const ok = verifier.verify(cocok.pem, sigBuf);
    if (!ok) {
      return { valid: false, alasan: 'Tanda tangan ECDSA tidak cocok' };
    }
    return { valid: true, data };
  } catch {
    return { valid: false, alasan: 'Gagal memverifikasi tanda tangan ECDSA' };
  }
}
