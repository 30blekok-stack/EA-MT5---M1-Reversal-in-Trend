# XAUUSD_ReversalTrend_M1 — EA MetaTrader 5

EA **scalping XAUUSD (gold) di M1** dengan strategi **reversal-in-trend**:
entry reversal dari zona ekstrem oscillator (RSI / Stochastic) + candle
konfirmasi (rejection wick), yang **hanya dieksekusi bila searah tren TF besar
(M15/H1)**. Karakternya menjadi *beli dip saat tren naik / jual rally saat tren
turun* — pullback-entry dalam tren, bukan counter-trend buta.

Manajemen stop **dua tahap**: **breakeven** dulu (buffer dinamis), lalu
**trailing** menyusul. **Single entry** (maksimal 1 posisi), tanpa
grid/averaging/martingale.

> ⚠️ Uji dulu di **DEMO / forward test** sebelum akun riil. Hasil backtest
> bukan jaminan performa live.

---

## 1. Cara Pasang

1. Buka **MetaEditor** (dari MT5: `Tools → MetaQuotes Language Editor` atau `F4`).
2. Salin file `XAUUSD_ReversalTrend_M1.mq5` ke folder:
   `MQL5/Experts/` (mis. `MQL5/Experts/XAUUSD_ReversalTrend_M1.mq5`).
3. Klik **Compile** (`F7`). Harus **tanpa error dan tanpa warning**.
4. Di MT5, buka chart **XAUUSD** timeframe **M1**.
5. Drag EA dari **Navigator → Expert Advisors** ke chart.
6. Pada tab **Common**, aktifkan **Allow Algo Trading**. Pastikan tombol
   **Algo Trading** di toolbar MT5 juga aktif (hijau).
7. Atur input di tab **Inputs** sesuai broker & selera, lalu **OK**.

> **Penting soal "points" & digit gold.** Semua jarak dinyatakan dalam *points*
> terhadap `SYMBOL_POINT`. Default disetel untuk **gold 2-digit** (point = 0.01,
> jadi 100 points = pergerakan harga 1.00 USD). Bila simbol broker Anda **3-digit**
> (point = 0.001), kalikan semua input berbasis *points* (SL, breakeven, trailing,
> spread, ATR) sekitar **10×**.

---

## 2. Penjelasan Input

### Filter Tren (gate arah — dievaluasi lebih dulu)
| Input | Default | Fungsi |
|---|---|---|
| `InpTrendTimeframe` | M15 | TF penentu tren (alternatif H1). |
| `InpTrendEMAPeriod` | 50 | Periode EMA tren. Harga di atas EMA + slope naik → hanya BUY; di bawah + slope turun → hanya SELL. |
| `InpUseSlopeFilter` | true | Aktifkan syarat kemiringan EMA (agar EMA datar tidak dianggap tren). |
| `InpSlopeLookback` | 5 | Jumlah bar untuk mengukur slope EMA. |
| `InpMinSlopePoints` | 10 | Ambang minimal slope (points). Di bawah ini = dianggap sideways. |
| `InpUseADXFilter` | true | Entry hanya bila tren cukup kuat (ADX). |
| `InpADXTimeframe` | M15 | TF ADX (default sama dengan TF tren). |
| `InpADXPeriod` | 14 | Periode ADX. |
| `InpADXMinLevel` | 25 | ADX minimal agar entry diizinkan. |

Jika tidak ada arah valid (sideways / slope datar / ADX lemah) → **tidak ada entry**.

### Sinyal Oscillator (M1)
| Input | Default | Fungsi |
|---|---|---|
| `InpOscMode` | RSI | `RSI`, `Stochastic`, atau `Both` (dua-duanya harus setuju). |
| `InpRSIPeriod` | 14 | Periode RSI. |
| `InpRSIBuyLevel` | **40** | Zona oversold RSI (BUY). Sengaja **longgar**: di tren kuat RSI M1 jarang menyentuh 30. |
| `InpRSISellLevel` | **60** | Zona overbought RSI (SELL). Longgar, asimetris, mudah dioptimasi. |
| `InpStochK / D / Slowing` | 5 / 3 / 3 | Parameter Stochastic. |
| `InpStochBuyLevel` | 30 | Zona oversold Stochastic (BUY). |
| `InpStochSellLevel` | 70 | Zona overbought Stochastic (SELL). |
| `InpSignalValidBars` | 3 | Masa berlaku sinyal (bar) setelah cross sebelum hangus. |
| `InpSameBarOnly` | false | true = cross oscillator & candle konfirmasi harus di **bar yang sama** (paling ketat, sinyal paling sedikit). |

**Latch (arm → trigger → expire).** Setup *armed* saat oscillator masuk zona
ekstrem, *triggered* saat cross balik keluar zona, dan *expired* jika candle
konfirmasi tak muncul dalam `InpSignalValidBars` bar / oscillator masuk zona lagi /
sudah terjadi entry. Latch juga **direset saat arah tren berubah**. Ini menjamin
satu peristiwa zona ekstrem menghasilkan **maksimal satu entry**.

### Candle Konfirmasi (kuantitatif)
| Input | Default | Fungsi |
|---|---|---|
| `InpMinWickRatio` | 0.30 | Rejection wick minimal = rasio × total range candle. |
| `InpMinClosePosition` | 0.50 | Posisi close: BUY di paruh atas `(close-low)/(high-low) ≥ nilai`; SELL kebalikan. |
| `InpMinRangeATRRatio` | 0.0 | Range minimal = rasio × ATR (0 = nonaktif, agar bukan candle mikro). |

### Stop Loss (hard SL)
| Input | Default | Fungsi |
|---|---|---|
| `InpSLMode` | ConfirmCandle | `ConfirmCandle` (SL di bawah low / atas high candle konfirmasi + buffer — titik invalidasi alami), `SwingLowHigh`, atau `ATR`. |
| `InpSLBufferPoints` | 20 | Buffer SL (points). |
| `InpSwingLookback` | 10 | Lookback swing (mode SwingLowHigh). |
| `InpATRPeriod` | 14 | Periode ATR (M1). |
| `InpATRMultSL` | 1.5 | Multiplier ATR untuk SL (mode ATR). |
| `InpMinSLPoints` | 50 | Jika SL terlalu rapat / di bawah stops level broker → dilebarkan ke minimum. |
| `InpMaxSLPoints` | 800 | Jika SL terlalu lebar → **entry dibatalkan** (tidak dipaksakan). |

### Breakeven (Tahap 1)
| Input | Default | Fungsi |
|---|---|---|
| `InpUseBreakeven` | true | Aktifkan breakeven. |
| `InpBreakevenTriggerPoints` | 100 | Floating profit (points) untuk mengunci breakeven. |
| `InpBreakevenBufferPoints` | 5 | Dipakai sebagai **nilai minimum**. Buffer efektif = `max(nilai ini, spread + komisi)`. |
| `InpCommissionPoints` | 0 | Komisi round-turn dalam points untuk perhitungan buffer BE. |

> **Kenapa buffer dinamis?** Spread gold sering 15–30 point, sehingga
> "entry + 5" bisa saja masih rugi bersih setelah spread & komisi. Karena itu
> buffer efektif = `MathMax(InpBreakevenBufferPoints, spread_saat_ini + InpCommissionPoints)`.

### Trailing (Tahap 2 — baru aktif setelah breakeven ter-set)
| Input | Default | Fungsi |
|---|---|---|
| `InpUseTrailing` | true | Aktifkan trailing. |
| `InpTrailMode` | ATR | `ATR`, `FixedStep`, atau `EMA`. |
| `InpATRMultTrail` | 1.5 | Multiplier ATR (mode ATR). |
| `InpTrailDistancePoints` | 150 | Jarak trailing tetap (mode FixedStep). |
| `InpTrailStepPoints` | 30 | Geser SL hanya bila harga maju sekian points (mode FixedStep). |
| `InpTrailEMAPeriod` | 20 | Periode EMA trailing M1 (mode EMA). |
| `InpMinModifyStepPoints` | 5 | Throttle: jangan modify jika selisih SL < nilai ini (cegah spam broker). |

SL **hanya bergerak ke arah profit** (`MathMax` untuk BUY, `MathMin` untuk SELL),
tidak pernah mundur, dan **tidak pernah lebih longgar dari level breakeven**.

### Take Profit / Manajemen
| Input | Default | Fungsi |
|---|---|---|
| `InpTPMode` | None | `None` (andalkan trailing), `RR` (`InpRR` × jarak SL), atau `Points`. |
| `InpRR` | 1.5 | Risk:Reward (mode RR). |
| `InpTPPoints` | 300 | Jarak TP dalam points (mode Points). |
| `InpUsePartial` | false | Tutup sebagian posisi saat profit tertentu. |
| `InpPartialPercent` | 50 | Persen volume yang ditutup. |
| `InpPartialAtPoints` | 150 | Profit (points) untuk partial. |
| `InpUseTimeExit` | false | Tutup posisi jika belum profit setelah sekian bar. |
| `InpMaxBarsInTrade` | 30 | Batas bar untuk time exit. |

### Lot / Risk
| Input | Default | Fungsi |
|---|---|---|
| `InpLotMode` | Fixed | `Fixed` atau `RiskPct`. |
| `InpFixedLot` | 0.01 | Lot tetap (mode Fixed). |
| `InpRiskPercent` | 0.5 | Risiko % balance per trade (mode RiskPct), memakai `TICK_VALUE`/`TICK_SIZE`, dinormalisasi ke `VOLUME_STEP`. |

### Filter Pasar
| Input | Default | Fungsi |
|---|---|---|
| `InpMaxSpreadPoints` | 50 | Tolak entry bila spread lebih besar. |
| `InpUseSession` | false | Aktifkan filter jam. |
| `InpSessionStartHour` / `InpSessionEndHour` | 8 / 22 | Jam sesi — **waktu SERVER broker** (beda-beda per broker!). |
| `InpUseATRFilter` | false | Entry hanya bila `InpATRMinPoints ≤ ATR ≤ InpATRMaxPoints`. |
| `InpATRMinPoints` / `InpATRMaxPoints` | 20 / 500 | Rentang ATR (points). |
| `InpUseNewsFilter` | false | Blackout window pakai MQL5 Economic Calendar. **Tidak berfungsi di Strategy Tester.** |
| `InpNewsMinutesBefore` / `InpNewsMinutesAfter` | 15 / 15 | Lebar blackout sebelum/sesudah rilis. |
| `InpNewsHighImpactOnly` | true | Hanya blackout news high-impact (USD). |

### Proteksi Akun
| Input | Default | Fungsi |
|---|---|---|
| `InpMaxDailyLossPercent` | 5.0 | Stop trading hari itu bila rugi harian melewati batas. |
| `InpMaxTradesPerDay` | 20 | Batas entry per hari. |
| `InpMaxOpenPositions` | 1 | Maks posisi terbuka (single entry). |
| `InpDailyProfitTargetPercent` | 0.0 | Stop setelah target profit harian tercapai (0 = nonaktif). |

### Umum
| Input | Default | Fungsi |
|---|---|---|
| `InpMagicNumber` | 20250722 | Magic number — EA hanya mengelola posisinya sendiri. |
| `InpMaxSlippagePoints` | 30 | Deviation/slippage maksimal (points). |
| `InpVerboseLog` | true | Cetak alasan entry ditolak (spread, ADX, sesi, sinyal hangus, SL terlalu lebar) — sangat membantu debug di Strategy Tester. |

---

## 3. Struktur Kode (ringkas)

Satu file `.mq5`, terbagi per modul dengan komentar Bahasa Indonesia:

- **OnInit / OnDeinit** — buat & rilis handle indikator (`iMA`, `iRSI`,
  `iStochastic`, `iATR`, `iADX`), konfigurasi `CTrade` (magic, deviation, filling).
- **OnTick** — breakeven & trailing dievaluasi **tiap tick**; logika entry hanya
  dijalankan **sekali per bar M1 baru** (`OnNewBar`).
- **EvaluateTrend()** — gate arah (EMA + slope + ADX) pada TF tren.
- **Latch (arm/trigger/expire)** — state machine per arah, memakai nilai
  oscillator **bar tertutup** (index 1 vs 2), reset saat tren berubah.
- **ConfirmCandle()** — validasi candle secara **kuantitatif** (rasio wick &
  posisi close), aman terhadap pembagian nol.
- **ComputeSL / ComputeTP / ComputeLot** — hard SL (clamp min/max & stops level),
  TP, dan sizing (Fixed / RiskPct).
- **ManageOpenPosition()** — breakeven (buffer dinamis), trailing (ATR/Fixed/EMA),
  partial, time exit. Status breakeven **diturunkan dari kondisi nyata SL**
  (BUY: `SL ≥ entry`), sehingga tetap benar setelah restart/recompile.
- **Filter pasar & proteksi akun** — spread, sesi, ATR, news, batas harian.

---

## 4. Panduan Backtest untuk Gold

1. `View → Strategy Tester` (`Ctrl+R`).
2. **Symbol**: XAUUSD broker Anda. **Period**: M1.
3. **Modelling**: **Every tick based on real ticks** (paling akurat untuk M1).
4. **Spread**: jangan pakai spread tetap yang kecil. Gunakan **Current** atau
   nilai realistis (mis. 20–40 points untuk gold 2-digit) — spread sangat
   memengaruhi hasil karena breakeven & SL dihitung dalam points.
5. **Komisi**: masukkan komisi broker Anda di setelan simbol / akun. Cerminkan
   juga lewat `InpCommissionPoints` agar buffer breakeven realistis.
6. Nyalakan `InpVerboseLog = true` untuk melihat **alasan entry ditolak** di tab
   *Journal* (spread, ADX, sesi, sinyal hangus, SL terlalu lebar).
7. Optimasi yang paling berpengaruh: `InpRSIBuyLevel` / `InpRSISellLevel`,
   `InpMinSlopePoints`, `InpADXMinLevel`, `InpMinWickRatio`, dan parameter
   SL/breakeven/trailing.

> **Catatan.** Filter news (Economic Calendar) tidak aktif di Strategy Tester —
> hanya berlaku saat live. Selalu jalankan **demo / forward test** sebelum riil.

---

## 5. Asumsi yang Diambil

- Default input dioptimalkan untuk **gold 2-digit** (point = 0.01). Untuk simbol
  3-digit, sesuaikan input berbasis *points* (≈10×).
- Mode oscillator `Both` bersifat **ketat**: kedua cross (RSI & Stochastic) harus
  terpenuhi. Untuk sinyal lebih sering, pakai `RSI` atau `Stochastic` saja.
- Entry dieksekusi **market** pada pembukaan bar M1 baru setelah candle konfirmasi
  close.
- Time exit menutup posisi bila belum profit setelah `InpMaxBarsInTrade` bar
  (dihitung via `iBarShift` dari waktu buka posisi).
- Ditambahkan input news `InpNewsMinutesBefore/After` dan `InpNewsHighImpactOnly`
  (tidak eksplisit di spesifikasi) agar blackout window dapat diatur.
