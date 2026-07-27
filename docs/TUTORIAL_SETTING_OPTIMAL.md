# Tutorial Setting Optimal — XAUUSD_ReversalTrend_M1

Panduan menyetel EA agar **optimal untuk broker Anda**, plus penjelasan kenapa
default bawaan **tidak cocok langsung** dengan gold Exness.

> File preset siap-pakai: [`presets/XAUUSDm_Exness_3digit_optimal.set`](../presets/XAUUSDm_Exness_3digit_optimal.set)

---

## 1. PENTING: Cek dulu simbol Anda 2-digit atau 3-digit

Semua jarak di EA ini dihitung dalam **points** terhadap `SYMBOL_POINT`.
Nilai default di kode disetel untuk **gold 2-digit** (Point = 0.01). Broker Anda
harus dicek dulu:

| Cek | 2-digit | 3-digit |
|---|---|---|
| Harga gold tampil | `4103.20` | `4103.201` |
| `SYMBOL_POINT` | 0.01 | 0.001 |
| 1 dollar ($1.00) gerak | 100 points | 1000 points |

**Exness XAUUSDm biasanya 3-digit** (Point = 0.001) — terlihat dari harga
`4103.201` di chart Anda. Karena itu **semua input berbasis points harus ±10×
lebih besar** dari default. Preset di repo ini sudah diskalakan untuk 3-digit.

> **Kalau broker Anda 2-digit**, bagi semua nilai *points* di tabel bawah dengan
> 10 (mis. `InpMinSLPoints` 800 → 80, `InpMaxSpreadPoints` 300 → 30).

---

## 2. Kenapa default bawaan tidak akan entry di Exness

Spread gold Exness XAUUSDm di contoh Anda **± 240 points** (0.24). Dengan default
`InpMaxSpreadPoints = 50`, filter spread akan **menolak SEMUA entry**
(240 > 50). Selain itu:

- `InpMinSLPoints = 50` → SL cuma $0.05 → selalu dipaksa melebar / kena stops level.
- `InpBreakevenTriggerPoints = 100` → BE terpicu di $0.10, masih di dalam spread.

Itulah alasan Anda **wajib pakai preset optimal** (atau isi manual tabel di bawah).

---

## 3. Cara memuat preset (.set)

1. Salin `presets/XAUUSDm_Exness_3digit_optimal.set` ke folder preset MT5:
   `MQL5/Presets/` **atau** biarkan di mana saja lalu browse saat Load.
2. Di MT5, drag EA ke chart **XAUUSDm M1** (atau buka Strategy Tester).
3. Di tab **Inputs**, klik tombol **Load** (kanan bawah dialog).
4. Pilih file `.set` tadi → **Open**.
5. **Verifikasi** beberapa baris kunci dengan tabel di bawah (khususnya
   *TF penentu tren = 15 Minutes* dan *Spread maksimal = 300*).
6. Klik **OK**.

> Jika ada baris yang tidak termuat, isi manual sesuai tabel — tabel ini adalah
> sumber kebenaran.

---

## 4. Tabel nilai optimal (3-digit / Exness XAUUSDm)

### Filter Tren
| Input | Nilai | Alasan |
|---|---|---|
| TF penentu tren | **M15** | Tren M15 cukup responsif untuk scalp M1. |
| Periode EMA tren | 50 | Standar arah tren. |
| Aktifkan filter kemiringan EMA | true | Buang pasar datar. |
| Bar lookback slope | 5 | ~75 menit terakhir. |
| Ambang minimal slope (points) | **100.0** | = $0.10 gerak EMA; saring EMA datar. |
| Aktifkan filter ADX | true | Hanya entry saat tren kuat. |
| TF ADX | **M15** | Sama dengan TF tren. |
| Periode ADX | 14 | Standar. |
| ADX minimal | **22.0** | Sedikit dilonggarkan dari 25 agar setup M1 tak terlalu langka. |

### Sinyal Oscillator
| Input | Nilai | Alasan |
|---|---|---|
| Pilihan oscillator | **RSI** | Paling sering & stabil. `Both` paling ketat. |
| Periode RSI | 14 | Standar. |
| Level oversold RSI (BUY) | **40.0** | Longgar — RSI M1 di tren jarang sentuh 30. |
| Level overbought RSI (SELL) | **60.0** | Longgar, asimetris. |
| %K / %D / Slowing | 5 / 3 / 3 | Stochastic default. |
| Zona Stoch BUY / SELL | 30 / 70 | Standar. |
| Masa berlaku sinyal (bar) | 3 | Konfirmasi harus muncul ≤ 3 bar. |
| SameBarOnly | false | Konfirmasi boleh di bar berikutnya. |

### Candle Konfirmasi
| Input | Nilai | Alasan |
|---|---|---|
| Rasio minimal rejection wick | **0.30** | Wick ≥ 30% range. |
| Posisi close minimal | **0.50** | Close di paruh yang benar. |
| Range minimal = rasio × ATR | **0.40** | Buang candle mikro (< 0.4×ATR). |

### Stop Loss
| Input | Nilai | Alasan |
|---|---|---|
| Mode SL | **ConfirmCandle** | Invalidasi alami di bawah/atas wick. |
| Buffer SL (points) | **150** | = $0.15 di luar wick. |
| Lookback swing | 10 | Untuk mode SwingLowHigh. |
| Periode ATR | 14 | Standar. |
| Multiplier ATR SL | 1.5 | Untuk mode ATR. |
| **Jarak SL minimal (points)** | **800** | = $0.80. Harus jauh di atas spread (~240). |
| **Jarak SL maksimal (points)** | **4000** | = $4.00. Candle kelewat besar → entry dibatalkan. |

### Breakeven (Tahap 1)
| Input | Nilai | Alasan |
|---|---|---|
| Aktifkan breakeven | true | |
| Profit kunci BE (points) | **800** | = $0.80 (± 1R). |
| Buffer breakeven (min, points) | **300** | Buffer efektif = max(300, spread+komisi) → tetap profit bersih. |
| Komisi round-turn (points) | **0** | Akun Standard (spread-based). **Akun Raw/Zero: isi komisi Anda** (mis. 70). |

### Trailing (Tahap 2)
| Input | Nilai | Alasan |
|---|---|---|
| Aktifkan trailing | true | Jalan setelah BE ter-set. |
| Mode trailing | **ATR** | Adaptif ke volatilitas gold. |
| Multiplier ATR trailing | 1.5 | Jarak trailing = 1.5×ATR. |
| Jarak trailing tetap (points) | 1500 | (mode FixedStep) |
| Step geser trailing (points) | 300 | (mode FixedStep) |
| Periode EMA trailing | 20 | (mode EMA) |
| Selisih minimal modify (points) | **50** | Throttle; jangan modify < $0.05. |

### Take Profit / Manajemen
| Input | Nilai | Alasan |
|---|---|---|
| Mode TP | **None** | Andalkan trailing (biarkan profit berjalan). |
| Risk:Reward | 1.5 | (mode RR) |
| Jarak TP (points) | 3000 | (mode Points) |
| Partial close | **false** | Lot 0.01 tak bisa dipartial (di bawah step). Aktifkan hanya bila lot ≥ 0.02. |
| Time-based exit | false | Biarkan SL/trailing yang atur. |
| Maks bar dalam trade | 30 | (bila time exit diaktifkan) |

### Lot / Risk
| Input | Nilai | Alasan |
|---|---|---|
| Mode lot | **Fixed** | Deterministik untuk uji awal. |
| Lot tetap | **0.01** | Mulai kecil. |
| Risiko % balance | 0.5 | Dipakai bila ganti ke mode RiskPct. |

### Filter Pasar
| Input | Nilai | Alasan |
|---|---|---|
| **Spread maksimal (points)** | **300** | Izinkan entry saat spread ~240; blok saat spread melebar. Turunkan ke ~200 di sesi ramai / akun Raw. |
| Aktifkan filter sesi | false | Lihat catatan sesi di bawah. |
| Jam mulai / selesai | 8 / 22 | **Waktu SERVER broker** — cek dulu (bagian 5). |
| Filter ATR | false | Opsional. |
| ATR min / max (points) | 150 / 3000 | Nilai siap-pakai bila filter diaktifkan. |
| Filter news | false | Aktifkan untuk live (tak jalan di Tester). |

### Proteksi Akun
| Input | Nilai | Alasan |
|---|---|---|
| Maks rugi harian % | **4.0** | Stop hari itu bila rugi 4%. |
| Maks trade per hari | **15** | Cegah overtrading. |
| Maks posisi terbuka | **1** | Single entry. |
| Target profit harian % | 0.0 | Nonaktif. |

### Umum
| Input | Nilai | Alasan |
|---|---|---|
| Magic number | 20250722 | Pembeda posisi EA. |
| Deviation/slippage (points) | **200** | = $0.20; wajar untuk gold 3-digit. |
| Verbose log | true | Cetak alasan entry ditolak (bantu debug). |

---

## 5. Menyetel jam sesi (opsional tapi disarankan)

Gold paling likuid saat **overlap London–New York**. Filter sesi memakai **waktu
server broker**, yang beda-beda:

1. Cek jam server: lihat pojok waktu di Market Watch, atau bandingkan dengan
   GMT (Exness umumnya **GMT+0**, saat DST bisa GMT+1). Bila server = GMT+0:
   - London buka ± **08:00**, New York buka ± **13:00**, tutup ± **21:00–22:00**.
2. Untuk fokus sesi teraktif, set:
   - `Aktifkan filter sesi = true`
   - `Jam mulai = 8`, `Jam selesai = 22` (sesuaikan dengan server Anda).
3. Kalau ragu jam server, biarkan filter **false** dulu dan lihat jam mana yang
   paling banyak menghasilkan sinyal bagus di Journal.

---

## 6. Akun Standard vs Raw/Zero (penting untuk scalping M1)

Spread ~240 points (0.24) itu **lebar** untuk scalping M1 dan menggerus profit.

- **Akun Standard (XAUUSDm)**: spread lebih lebar, komisi 0 → `InpCommissionPoints = 0`.
- **Akun Raw/Zero**: spread jauh lebih tipis + komisi kecil → **lebih cocok untuk
  M1 scalp**. Jika pindah ke sana:
  - Turunkan `InpMaxSpreadPoints` ke ~120–200.
  - Isi `InpCommissionPoints` sesuai komisi round-turn broker (dalam points).
  - Boleh perkecil `InpMinSLPoints` / `InpBreakevenTriggerPoints` (mis. 500 / 500).

---

## 7. Verifikasi & backtest

1. **Strategy Tester** (`Ctrl+R`) → Symbol **XAUUSDm**, Period **M1**,
   Model **Every tick based on real ticks**.
2. **Spread**: pakai **Current** atau nilai realistis (jangan spread tetap kecil).
3. Nyalakan `InpVerboseLog = true`, cek tab **Journal** untuk alasan entry ditolak
   (spread / ADX / sesi / SL terlalu lebar). Kalau nol trade, biasanya
   `InpMaxSpreadPoints` kekecilan atau `InpMinSlopePoints`/`InpADXMinLevel`
   ketinggian.
4. **Optimasi** parameter paling berpengaruh (Tester → tab Inputs, centang Start/Step/Stop):
   - `InpRSIBuyLevel` 35–45, `InpRSISellLevel` 55–65
   - `InpADXMinLevel` 18–28
   - `InpMinSlopePoints` 50–200
   - `InpBreakevenTriggerPoints` 500–1200, `InpATRMultTrail` 1.0–2.5
   - `InpMinSLPoints` 600–1200
5. Jalankan **forward test / demo** minimal beberapa minggu sebelum akun riil.

---

## 8. Ringkas: yang WAJIB dicek sebelum live

- [ ] Simbol 3-digit? (harga 3 desimal) → pakai preset ini apa adanya.
- [ ] `InpMaxSpreadPoints` > spread rata-rata broker (default preset 300).
- [ ] `InpCommissionPoints` diisi bila akun Raw/Zero.
- [ ] Lot sesuai modal (mulai 0.01).
- [ ] Uji di **demo** dulu, cek Journal, baru naik ke riil.

> Preset ini titik-awal yang solid, **bukan jaminan profit**. Selalu validasi di
> demo/forward test dan sesuaikan dengan kondisi broker Anda.

---

## 9. Mode SUPER-FAST SCALP (frekuensi entry maksimal)

> Preset: [`presets/XAUUSDm_super_scalp_fast.set`](../presets/XAUUSDm_super_scalp_fast.set)

Kalau **belum ada posisi terbuka sama sekali**, penyebab paling umum:

1. **Gate tren terlalu ketat.** Preset optimal butuh `slope ≥ 100` **dan**
   `ADX ≥ 22` di M15. Saat market sepi (malam / off-session), dua syarat ini
   nyaris tak pernah terpenuhi → **arah tren tidak valid → EA tidak entry.**
2. **Spread melebihi batas.** Kalau spread melonjak di atas `InpMaxSpreadPoints`,
   semua entry ditolak. Cek tab **Journal** (log `[TOLAK] spread=...`).
3. **Off-session.** Gold sepi di luar jam London–New York → sedikit sinyal.

### Apa yang diubah di mode super-fast
| Bagian | Optimal | Super-Fast | Efek |
|---|---|---|---|
| TF tren / EMA | M15 / 50 | **M5 / 20** | Gate lebih responsif, arah lebih sering valid. |
| Filter slope | true (100) | **false** | Arah cukup dari harga vs EMA → hampir selalu ada arah. |
| Filter ADX | true (22) | **false** | Tak menunggu tren kuat. |
| Periode RSI | 14 | **7** | RSI lebih cepat → lebih sering cross. |
| Level RSI BUY/SELL | 40 / 60 | **45 / 55** | Dekat mid → cross sangat sering. |
| Masa berlaku sinyal | 3 | **5** | Lebih banyak peluang konfirmasi. |
| Wick / close / range | 0.30 / 0.50 / 0.40 | **0.10 / 0.35 / 0.0** | Hampir semua candle searah lolos. |
| Jarak SL min | 800 | **500** | SL rapat. |
| BE trigger | 800 | **400** | Kunci profit cepat. |
| Trailing ATR | 1.5 | **1.0** | Trailing ketat. |
| Mode TP | None | **Points 700** | Target kecil, tutup cepat. |
| Time exit | off | **on, 10 bar** | Trade tak berlama-lama (turnover cepat). |
| Spread maksimal | 300 | **400** | Lebih permisif (lihat peringatan). |
| Maks trade/hari | 15 | **100** | Izinkan banyak entry. |

### Cara pakai
1. Tab Inputs → **Load** → `XAUUSDm_super_scalp_fast.set` → **OK**.
2. **Tes saat sesi ramai** (London/NY) — di jam sepi tetap sedikit sinyal.
3. Lihat **Journal**: kalau masih nol, cari `[TOLAK] ...` untuk tahu filter mana
   yang menolak, lalu longgarkan yang itu.

### ⚠️ Kejujuran soal spread (WAJIB dibaca)
Spread XAUUSDm Anda **~240 points (0.24)**. Untuk scalping super cepat, tiap trade
sudah "minus 240 points" sejak dibuka. Dengan TP 700 points, **profit bersih ~460
points** kalau kena TP — dan spread bisa "memakan" sebagian besar target. Artinya:

- Preset ini **akan sering membuka posisi** (sesuai permintaan), **tapi**
  profitabilitas fast-scalp di spread selebar ini **berat**.
- **Solusi nyata untuk fast-scalp**: pakai akun **Exness Raw / Zero** (spread
  gold sering hanya 10–30 points + komisi kecil). Di akun itu, ubah:
  - `InpMaxSpreadPoints` → **60–120**
  - `InpCommissionPoints` → sesuai komisi round-turn (mis. 60–90)
  - `InpMinSLPoints` → **250–400**, `InpTPPoints` → **250–400**,
    `InpBreakevenTriggerPoints` → **200–300**
  - Barulah "scalping super cepat" jadi masuk akal secara biaya.

### Tuning cepat langsung di terminal (tanpa Load file)
Kalau mau langsung coba, ubah 5 input ini saja dari preset optimal:
- `Aktifkan filter kemiringan EMA` → **false**
- `Aktifkan filter ADX` → **false**
- `Level oversold RSI (BUY)` → **45**, `Level overbought RSI (SELL)` → **55**
- `Rasio minimal rejection wick` → **0.10**
- `Range minimal = rasio × ATR` → **0.0**

Lima perubahan ini biasanya sudah cukup memicu entry pertama.
