export const BATAS_GAMBAR_BYTE = 1_048_576; // 1 MB
export const VERSI_KONTRAK_SAAT_INI = 1;
export const MODEL_DEFAULT = 'gemini-3.1-flash-lite';

export const PROMPT_OCR = [
  'Baca tabel Informasi Nilai Gizi pada gambar. Kembalikan JSON sesuai skema.',
  'Salin angka persis seperti tertulis. Jangan menebak atau menghitung.',
  'Jika nilai tidak terbaca atau tidak ada, isi null.',
  'Garam/natrium: isi natrium_mg. Jika label hanya menulis "garam" dalam gram, isi garam_g.',
].join('\n');

export type KodeGalatOcr = 'invalid-argument' | 'deadline-exceeded' | 'internal';

export class GalatOcrError extends Error {
  constructor(
    public readonly kode: KodeGalatOcr,
    pesan: string,
  ) {
    super(pesan);
    this.name = 'GalatOcrError';
  }
}

export interface PermintaanOcr {
  gambarBase64: string;
  versiKontrak: number;
}

export interface TakaranSajiOcr {
  jumlah: number | null;
  satuan: 'g' | 'ml' | null;
}

export interface PerSajianOcr {
  energi_kkal: number | null;
  gula_g: number | null;
  natrium_mg: number | null;
  garam_g: number | null;
  lemak_total_g: number | null;
  protein_g: number | null;
  karbohidrat_g: number | null;
}

export interface HasilOcr {
  terbaca: boolean;
  takaran_saji: TakaranSajiOcr | null;
  sajian_per_kemasan: number | null;
  per_sajian: PerSajianOcr | null;
}

export type KlienGemini = (params: {
  model: string;
  apiKey: string;
  gambarBase64: string;
  prompt: string;
}) => Promise<string>;

export function validasiPermintaanOcr(data: unknown): PermintaanOcr {
  if (!data || typeof data !== 'object') {
    throw new GalatOcrError('invalid-argument', 'Payload permintaan harus berupa objek JSON.');
  }
  const obj = data as Record<string, unknown>;
  if (obj.versiKontrak !== VERSI_KONTRAK_SAAT_INI) {
    throw new GalatOcrError('invalid-argument', 'versiKontrak tidak didukung.');
  }
  if (typeof obj.gambarBase64 !== 'string') {
    throw new GalatOcrError('invalid-argument', 'gambarBase64 wajib berupa string.');
  }
  if (obj.gambarBase64.length > BATAS_GAMBAR_BYTE * 2) {
    throw new GalatOcrError('invalid-argument', 'Ukuran gambar melebihi batas 1 MB.');
  }
  const bersih = obj.gambarBase64.replace(/\s+/g, '');
  if (!bersih || !/^[A-Za-z0-9+/]+={0,2}$/.test(bersih)) {
    throw new GalatOcrError('invalid-argument', 'gambarBase64 kosong atau bukan base64 valid.');
  }

  // Cek estimasi ukuran sebelum alokasi buffer besar
  const estimasiByte = Math.floor((bersih.length * 3) / 4);
  if (estimasiByte > BATAS_GAMBAR_BYTE + 4) {
    throw new GalatOcrError('invalid-argument', 'Ukuran gambar melebihi batas 1 MB.');
  }

  const buf = Buffer.from(bersih, 'base64');
  if (buf.length === 0 || buf.length > BATAS_GAMBAR_BYTE) {
    throw new GalatOcrError('invalid-argument', 'Ukuran gambar harus antara 1 byte hingga 1 MB.');
  }
  // Validasi header JPEG (SOI: FF D8 FF)
  if (buf.length < 3 || buf[0] !== 0xff || buf[1] !== 0xd8 || buf[2] !== 0xff) {
    throw new GalatOcrError('invalid-argument', 'Format gambar harus JPEG.');
  }

  return { gambarBase64: bersih, versiKontrak: VERSI_KONTRAK_SAAT_INI };
}

function bacaAngkaAtauNull(nilai: unknown): number | null {
  if (nilai === null || nilai === undefined) return null;
  if (typeof nilai === 'number' && Number.isFinite(nilai)) return nilai;
  return null;
}

export function validasiHasilGemini(rawText: string): HasilOcr {
  let parsed: unknown;
  try {
    parsed = JSON.parse(rawText);
  } catch {
    throw new GalatOcrError('internal', 'Respons Gemini bukan JSON valid.');
  }
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    throw new GalatOcrError('internal', 'Struktur JSON Gemini tidak valid.');
  }

  const obj = parsed as Record<string, unknown>;
  if (typeof obj.terbaca !== 'boolean') {
    throw new GalatOcrError('internal', 'Kolom terbaca wajib boolean.');
  }

  const takaranObj =
    obj.takaran_saji && typeof obj.takaran_saji === 'object' && !Array.isArray(obj.takaran_saji)
      ? (obj.takaran_saji as Record<string, unknown>)
      : null;

  const satuanRaw = takaranObj?.satuan;
  const satuan: 'g' | 'ml' | null = satuanRaw === 'g' || satuanRaw === 'ml' ? satuanRaw : null;

  const takaranSaji: TakaranSajiOcr | null = takaranObj
    ? {
        jumlah: bacaAngkaAtauNull(takaranObj.jumlah),
        satuan,
      }
    : null;

  const perObj =
    obj.per_sajian && typeof obj.per_sajian === 'object' && !Array.isArray(obj.per_sajian)
      ? (obj.per_sajian as Record<string, unknown>)
      : null;

  const perSajian: PerSajianOcr | null = perObj
    ? {
        energi_kkal: bacaAngkaAtauNull(perObj.energi_kkal),
        gula_g: bacaAngkaAtauNull(perObj.gula_g),
        natrium_mg: bacaAngkaAtauNull(perObj.natrium_mg),
        garam_g: bacaAngkaAtauNull(perObj.garam_g),
        lemak_total_g: bacaAngkaAtauNull(perObj.lemak_total_g),
        protein_g: bacaAngkaAtauNull(perObj.protein_g),
        karbohidrat_g: bacaAngkaAtauNull(perObj.karbohidrat_g),
      }
    : null;

  const adaZatUtama =
    perSajian !== null &&
    (perSajian.gula_g !== null || perSajian.natrium_mg !== null || perSajian.garam_g !== null);

  return {
    terbaca: obj.terbaca && adaZatUtama,
    takaran_saji: takaranSaji,
    sajian_per_kemasan: bacaAngkaAtauNull(obj.sajian_per_kemasan),
    per_sajian: perSajian,
  };
}

export const panggilGeminiRest: KlienGemini = async ({
  model,
  apiKey,
  gambarBase64,
  prompt,
}) => {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`;

  let res: Response;
  try {
    res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body: JSON.stringify({
        contents: [
          {
            parts: [
              { text: prompt },
              {
                inline_data: {
                  mime_type: 'image/jpeg',
                  data: gambarBase64,
                },
              },
            ],
          },
        ],
        generationConfig: {
          responseMimeType: 'application/json',
          thinkingConfig: { thinkingBudget: 0 },
        },
      }),
      signal: AbortSignal.timeout(25_000),
    });
  } catch (err) {
    if (err instanceof Error && (err.name === 'TimeoutError' || err.name === 'AbortError')) {
      throw new GalatOcrError('deadline-exceeded', 'Permintaan Gemini melewati batas waktu.');
    }
    throw new GalatOcrError('internal', 'Gagal menghubungi layanan Gemini.');
  }

  if (!res.ok) {
    if (res.status === 408 || res.status === 504) {
      throw new GalatOcrError('deadline-exceeded', 'Gemini melewati batas waktu.');
    }
    throw new GalatOcrError('internal', `Layanan Gemini mengembalikan status ${res.status}.`);
  }

  const body = (await res.json()) as {
    candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
  };
  const teks = body.candidates?.[0]?.content?.parts?.[0]?.text;
  if (typeof teks !== 'string' || !teks.trim()) {
    throw new GalatOcrError('internal', 'Respons Gemini kosong.');
  }
  return teks;
};

export async function prosesOcrLabel(params: {
  data: unknown;
  apiKey: string;
  model?: string;
  klienGemini?: KlienGemini;
}): Promise<HasilOcr> {
  const permintaan = validasiPermintaanOcr(params.data);
  if (!params.apiKey.trim()) {
    throw new GalatOcrError('internal', 'Kunci API Gemini server belum dikonfigurasi.');
  }
  const model = (params.model ?? MODEL_DEFAULT).trim() || MODEL_DEFAULT;
  const klien = params.klienGemini ?? panggilGeminiRest;
  const rawText = await klien({
    model,
    apiKey: params.apiKey,
    gambarBase64: permintaan.gambarBase64,
    prompt: PROMPT_OCR,
  });
  return validasiHasilGemini(rawText);
}
