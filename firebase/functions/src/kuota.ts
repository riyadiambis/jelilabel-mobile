import type { Firestore, Transaction } from 'firebase-admin/firestore';

export const KUOTA_DASAR = 5;
export const BONUS_IKLAN_MAKS = 10;
export const PLAFON_MINGGUAN = KUOTA_DASAR + BONUS_IKLAN_MAKS;
export const ZONA_WAKTU_DEFAULT = 'Asia/Jakarta';

export interface DokumenKuota {
  minggu: string;
  terpakai: number;
  bonusIklan: number;
}

export interface StatusKuota {
  minggu: string;
  dasar: number;
  bonusIklan: number;
  terpakai: number;
  sisa: number;
  plafon: number;
}

export type HasilKlaimSsv =
  | { status: 'ditambahkan'; kuota: StatusKuota }
  | { status: 'duplikat'; kuota: StatusKuota }
  | { status: 'batas_tercapai'; kuota: StatusKuota };

/**
 * Mengembalikan tanggal Senin lokal ('YYYY-MM-DD') untuk waktu & zona waktu tertentu.
 */
export function tanggalSeninLokal(
  waktu: Date = new Date(),
  timeZone: string = ZONA_WAKTU_DEFAULT,
): string {
  const bagian = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(waktu);

  const tahun = Number(bagian.find((p) => p.type === 'year')?.value);
  const bulan = Number(bagian.find((p) => p.type === 'month')?.value);
  const hari = Number(bagian.find((p) => p.type === 'day')?.value);

  const utcHari = new Date(Date.UTC(tahun, bulan - 1, hari));
  const hariKe = utcHari.getUTCDay(); // 0=Minggu, 1=Senin..6=Sabtu
  const selisihSenin = (hariKe + 6) % 7;
  const senin = new Date(Date.UTC(tahun, bulan - 1, hari - selisihSenin));

  const y = String(senin.getUTCFullYear()).padStart(4, '0');
  const m = String(senin.getUTCMonth() + 1).padStart(2, '0');
  const d = String(senin.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

export function hitungStatusKuota(
  doc: Partial<DokumenKuota> | undefined,
  mingguIni: string,
): StatusKuota {
  if (!doc || doc.minggu !== mingguIni) {
    return {
      minggu: mingguIni,
      dasar: KUOTA_DASAR,
      bonusIklan: 0,
      terpakai: 0,
      sisa: KUOTA_DASAR,
      plafon: PLAFON_MINGGUAN,
    };
  }
  const bonus = Math.max(0, Math.min(BONUS_IKLAN_MAKS, Math.trunc(doc.bonusIklan ?? 0)));
  const terpakai = Math.max(0, Math.trunc(doc.terpakai ?? 0));
  const sisa = Math.max(0, Math.min(PLAFON_MINGGUAN, KUOTA_DASAR + bonus - terpakai));
  return {
    minggu: mingguIni,
    dasar: KUOTA_DASAR,
    bonusIklan: bonus,
    terpakai,
    sisa,
    plafon: PLAFON_MINGGUAN,
  };
}

export interface KonteksTransaksiKuota {
  bacaPengguna(uid: string): Promise<DokumenKuota | undefined>;
  tulisPengguna(uid: string, doc: DokumenKuota): Promise<void>;
  adaTransaksiSsv(uid: string, txId: string): Promise<boolean>;
  catatTransaksiSsv(uid: string, txId: string, minggu: string): Promise<void>;
}

export interface PenyimpanKuota {
  dalamTransaksi<T>(fn: (tx: KonteksTransaksiKuota) => Promise<T>): Promise<T>;
  hapusPengguna(uid: string): Promise<void>;
}

export function buatPenyimpanFirestore(db: Firestore): PenyimpanKuota {
  return {
    async dalamTransaksi<T>(fn: (tx: KonteksTransaksiKuota) => Promise<T>): Promise<T> {
      return db.runTransaction(async (t: Transaction) => {
        const kuotaRef = (uid: string) => db.collection('kuota_mingguan').doc(uid);
        const ssvRef = (uid: string, txId: string) =>
          kuotaRef(uid).collection('ssv_transaksi').doc(txId);

        const tx: KonteksTransaksiKuota = {
          async bacaPengguna(uid: string) {
            const snap = await t.get(kuotaRef(uid));
            if (!snap.exists) return undefined;
            const d = snap.data() ?? {};
            return {
              minggu: typeof d.minggu === 'string' ? d.minggu : '',
              terpakai: typeof d.terpakai === 'number' ? d.terpakai : 0,
              bonusIklan: typeof d.bonusIklan === 'number' ? d.bonusIklan : 0,
            };
          },
          async tulisPengguna(uid: string, doc: DokumenKuota) {
            t.set(
              kuotaRef(uid),
              {
                minggu: doc.minggu,
                terpakai: doc.terpakai,
                bonusIklan: doc.bonusIklan,
              },
              { merge: true },
            );
          },
          async adaTransaksiSsv(uid: string, txId: string) {
            const snap = await t.get(ssvRef(uid, txId));
            return snap.exists;
          },
          async catatTransaksiSsv(uid: string, txId: string, minggu: string) {
            t.set(ssvRef(uid, txId), {
              transaction_id: txId,
              minggu,
            });
          },
        };
        return fn(tx);
      });
    },
    async hapusPengguna(uid: string): Promise<void> {
      const userRef = db.collection('users').doc(uid);
      await db.recursiveDelete(userRef);
    },
  };
}

export class PenyimpanKuotaMemori implements PenyimpanKuota {
  private readonly dataPribadi = new Map<string, Record<string, unknown>>();
  private readonly kuota = new Map<string, DokumenKuota>();
  private readonly ssv = new Map<string, Map<string, { transaction_id: string; minggu: string }>>();
  private antreanTransaksi: Promise<void> = Promise.resolve();

  async dalamTransaksi<T>(fn: (tx: KonteksTransaksiKuota) => Promise<T>): Promise<T> {
    const tx: KonteksTransaksiKuota = {
      bacaPengguna: async (uid) => {
        const d = this.kuota.get(uid);
        return d ? { ...d } : undefined;
      },
      tulisPengguna: async (uid, doc) => {
        this.kuota.set(uid, { ...doc });
      },
      adaTransaksiSsv: async (uid, txId) => this.ssv.get(uid)?.has(txId) ?? false,
      catatTransaksiSsv: async (uid, txId, minggu) => {
        let map = this.ssv.get(uid);
        if (!map) {
          map = new Map<string, { transaction_id: string; minggu: string }>();
          this.ssv.set(uid, map);
        }
        map.set(txId, { transaction_id: txId, minggu });
      },
    };
    const jalankan = this.antreanTransaksi.then(() => fn(tx));
    this.antreanTransaksi = jalankan.then(
      () => undefined,
      () => undefined,
    );
    return jalankan;
  }

  async hapusPengguna(uid: string): Promise<void> {
    this.dataPribadi.delete(uid);
  }

  simpanDataPribadi(uid: string, data: Record<string, unknown>): void {
    this.dataPribadi.set(uid, { ...data });
  }

  lihatDataPribadi(uid: string): Record<string, unknown> | undefined {
    const d = this.dataPribadi.get(uid);
    return d ? { ...d } : undefined;
  }

  lihatPengguna(uid: string): DokumenKuota | undefined {
    const d = this.kuota.get(uid);
    return d ? { ...d } : undefined;
  }
}

export async function cekKuotaTersedia(
  store: PenyimpanKuota,
  uid: string,
  waktu: Date = new Date(),
  timeZone: string = ZONA_WAKTU_DEFAULT,
): Promise<StatusKuota> {
  if (!idDokumenValid(uid)) throw new Error('uid wajib valid');
  const mingguIni = tanggalSeninLokal(waktu, timeZone);
  return store.dalamTransaksi(async (tx) => {
    const doc = await tx.bacaPengguna(uid);
    if (!doc || doc.minggu !== mingguIni) {
      await tx.tulisPengguna(uid, { minggu: mingguIni, terpakai: 0, bonusIklan: 0 });
      return hitungStatusKuota(undefined, mingguIni);
    }
    return hitungStatusKuota(doc, mingguIni);
  });
}

export type HasilReservasiKuota =
  | { berhasil: true; minggu: string; kuota: StatusKuota }
  | { berhasil: false; minggu: string; kuota: StatusKuota };

/**
 * Mereservasikan 1 kuota pindai secara atomik dalam transaksi sebelum memanggil Gemini.
 */
export async function reservasiKuotaPindai(
  store: PenyimpanKuota,
  uid: string,
  waktu: Date = new Date(),
  timeZone: string = ZONA_WAKTU_DEFAULT,
): Promise<HasilReservasiKuota> {
  if (!idDokumenValid(uid)) {
    throw new Error('uid wajib valid');
  }
  const mingguIni = tanggalSeninLokal(waktu, timeZone);
  return store.dalamTransaksi(async (tx) => {
    const doc = await tx.bacaPengguna(uid);
    const statusAwal = hitungStatusKuota(doc, mingguIni);
    if (statusAwal.sisa <= 0) {
      if (!doc || doc.minggu !== mingguIni) {
        await tx.tulisPengguna(uid, { minggu: mingguIni, terpakai: 0, bonusIklan: 0 });
      }
      return { berhasil: false, minggu: mingguIni, kuota: statusAwal };
    }

    const docBaru: DokumenKuota = {
      minggu: mingguIni,
      terpakai: statusAwal.terpakai + 1,
      bonusIklan: statusAwal.bonusIklan,
    };
    await tx.tulisPengguna(uid, docBaru);
    return {
      berhasil: true,
      minggu: mingguIni,
      kuota: hitungStatusKuota(docBaru, mingguIni),
    };
  });
}

/**
 * Mengembalikan 1 kuota yang sebelumnya direservasi jika OCR gagal, galat, atau tidak terbaca.
 */
export async function kembalikanReservasiKuota(
  store: PenyimpanKuota,
  uid: string,
  mingguReservasi: string,
  waktu: Date = new Date(),
  timeZone: string = ZONA_WAKTU_DEFAULT,
): Promise<StatusKuota> {
  if (!idDokumenValid(uid)) {
    throw new Error('uid wajib valid');
  }
  const mingguSekarang = tanggalSeninLokal(waktu, timeZone);
  return store.dalamTransaksi(async (tx) => {
    const doc = await tx.bacaPengguna(uid);
    if (!doc || doc.minggu !== mingguReservasi) {
      return hitungStatusKuota(doc, mingguSekarang);
    }
    const docBaru: DokumenKuota = {
      minggu: doc.minggu,
      terpakai: Math.max(0, doc.terpakai - 1),
      bonusIklan: doc.bonusIklan,
    };
    await tx.tulisPengguna(uid, docBaru);
    return hitungStatusKuota(docBaru, mingguSekarang);
  });
}

/**
 * Mencatat pemakaian kuota HANYA jika hasil OCR terbaca === true.
 */
export async function catatPindaiBerhasil(
  store: PenyimpanKuota,
  uid: string,
  terbaca: boolean,
  waktu: Date = new Date(),
  timeZone: string = ZONA_WAKTU_DEFAULT,
): Promise<StatusKuota> {
  const mingguIni = tanggalSeninLokal(waktu, timeZone);
  return store.dalamTransaksi(async (tx) => {
    const doc = await tx.bacaPengguna(uid);
    const statusAwal = hitungStatusKuota(doc, mingguIni);
    if (!terbaca) {
      if (!doc || doc.minggu !== mingguIni) {
        await tx.tulisPengguna(uid, { minggu: mingguIni, terpakai: 0, bonusIklan: 0 });
      }
      return statusAwal;
    }
    const terpakaiBaru = Math.min(KUOTA_DASAR + statusAwal.bonusIklan, statusAwal.terpakai + 1);
    const docBaru: DokumenKuota = {
      minggu: mingguIni,
      terpakai: terpakaiBaru,
      bonusIklan: statusAwal.bonusIklan,
    };
    await tx.tulisPengguna(uid, docBaru);
    return hitungStatusKuota(docBaru, mingguIni);
  });
}

function idDokumenValid(nilai: string): boolean {
  const trimmed = nilai.trim();
  return Boolean(trimmed) && !trimmed.includes('/') && trimmed !== '.' && trimmed !== '..';
}

/**
 * Klaim bonus +1 kuota dari AdMob SSV secara idempoten berdasarkan transaction_id.
 */
export async function klaimBonusAdmobSsv(
  store: PenyimpanKuota,
  uid: string,
  txId: string,
  waktu: Date = new Date(),
  timeZone: string = ZONA_WAKTU_DEFAULT,
): Promise<HasilKlaimSsv> {
  if (!idDokumenValid(uid) || !idDokumenValid(txId)) {
    throw new Error('uid dan transaction_id wajib valid');
  }
  const mingguIni = tanggalSeninLokal(waktu, timeZone);
  return store.dalamTransaksi(async (tx) => {
    const doc = await tx.bacaPengguna(uid);
    const statusAwal = hitungStatusKuota(doc, mingguIni);

    if (await tx.adaTransaksiSsv(uid, txId)) {
      return { status: 'duplikat', kuota: statusAwal };
    }

    if (statusAwal.bonusIklan >= BONUS_IKLAN_MAKS) {
      return { status: 'batas_tercapai', kuota: statusAwal };
    }

    const docBaru: DokumenKuota = {
      minggu: mingguIni,
      terpakai: statusAwal.terpakai,
      bonusIklan: statusAwal.bonusIklan + 1,
    };
    await tx.tulisPengguna(uid, docBaru);
    await tx.catatTransaksiSsv(uid, txId, mingguIni);

    return {
      status: 'ditambahkan',
      kuota: hitungStatusKuota(docBaru, mingguIni),
    };
  });
}

export async function hapusDataPenggunaDiStore(
  store: PenyimpanKuota,
  uid: string,
): Promise<void> {
  if (!idDokumenValid(uid)) throw new Error('uid wajib valid');
  await store.hapusPengguna(uid);
}
