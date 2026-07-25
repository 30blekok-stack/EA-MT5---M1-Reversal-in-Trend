//+------------------------------------------------------------------+
//|                                   XAUUSD_ReversalTrend_M1.mq5     |
//|                                                                  |
//|  EA MT5 - "XAUUSD M1 Reversal-in-Trend"                          |
//|  Entry reversal dari zona ekstrem oscillator (RSI / Stochastic)  |
//|  + candle konfirmasi (rejection wick), DI-GATE oleh filter tren  |
//|  TF besar (M15/H1). Karakter jadi: beli dip saat tren naik /     |
//|  jual rally saat tren turun (pullback-entry dalam tren).         |
//|                                                                  |
//|  Manajemen stop DUA TAHAP:                                       |
//|    Tahap 1 = Breakeven (buffer dinamis min. spread + komisi)     |
//|    Tahap 2 = Trailing (baru aktif SETELAH breakeven ter-set)     |
//|                                                                  |
//|  Single entry (maks 1 posisi), tanpa grid/averaging/martingale.  |
//|                                                                  |
//|  Catatan pemakaian:                                              |
//|   - Dirancang untuk XAUUSD (gold) timeframe M1.                  |
//|   - Semua jarak dinyatakan dalam "points" terhadap SYMBOL_POINT. |
//|     Default disetel untuk gold 2-digit (point = 0.01). Bila      |
//|     broker Anda 3-digit, kalikan input "points" sekitar 10x.     |
//|   - Uji dulu di DEMO / forward test sebelum akun riil.           |
//+------------------------------------------------------------------+
#property copyright "Reversal-in-Trend EA"
#property version   "1.00"
#property description "XAUUSD M1 Reversal-in-Trend (RSI/Stoch + candle konfirmasi), Breakeven -> Trailing"

#include <Trade/Trade.mqh>

//==================================================================//
//                         ENUMERASI INPUT                          //
//==================================================================//
enum ENUM_OSC_MODE   { OSC_RSI = 0, OSC_STOCH = 1, OSC_BOTH = 2 };       // Mode oscillator
enum ENUM_SL_MODE    { SL_CONFIRM = 0, SL_SWING = 1, SL_ATR = 2 };       // Mode hard SL
enum ENUM_TRAIL_MODE { TRAIL_ATR = 0, TRAIL_FIXED = 1, TRAIL_EMA = 2 };  // Mode trailing
enum ENUM_TP_MODE    { TP_NONE = 0, TP_RR = 1, TP_POINTS = 2 };          // Mode take profit
enum ENUM_LOT_MODE   { LOT_FIXED = 0, LOT_RISK = 1 };                    // Mode lot

//==================================================================//
//                          INPUT PARAMETER                         //
//==================================================================//

//--- Filter Tren (gate arah, dievaluasi lebih dulu) ---------------
input group "=== Filter Tren ==="
input ENUM_TIMEFRAMES InpTrendTimeframe = PERIOD_M15;  // TF penentu tren (M15 default, boleh H1)
input int             InpTrendEMAPeriod = 50;          // Periode EMA tren
input bool            InpUseSlopeFilter = true;        // Aktifkan filter kemiringan EMA
input int             InpSlopeLookback  = 5;           // Bar lookback untuk hitung slope
input double          InpMinSlopePoints = 10.0;        // Ambang minimal slope (points) agar tak dianggap datar
input bool            InpUseADXFilter   = true;        // Aktifkan filter kekuatan tren (ADX)
input ENUM_TIMEFRAMES InpADXTimeframe   = PERIOD_M15;  // TF ADX (default = TF tren)
input int             InpADXPeriod      = 14;          // Periode ADX
input double          InpADXMinLevel    = 25.0;        // ADX minimal agar entry diizinkan

//--- Sinyal Oscillator (di M1) ------------------------------------
input group "=== Sinyal Oscillator (M1) ==="
input ENUM_OSC_MODE   InpOscMode        = OSC_RSI;     // Pilihan oscillator
input int             InpRSIPeriod      = 14;          // Periode RSI
// CATATAN: level RSI dibuat LONGGAR by default. Di tren kuat, RSI M1 jarang
// menyentuh 30, sehingga "RSI<30 + filter tren" bikin sinyal sangat langka.
// Karena itu default BUY=40 / SELL=60 (asimetris/adjustable, mudah dioptimasi).
input double          InpRSIBuyLevel    = 40.0;        // Level oversold RSI untuk BUY (longgar)
input double          InpRSISellLevel   = 60.0;        // Level overbought RSI untuk SELL (longgar)
input int             InpStochK         = 5;           // %K Stochastic
input int             InpStochD         = 3;           // %D Stochastic
input int             InpStochSlowing   = 3;           // Slowing Stochastic
input double          InpStochBuyLevel  = 30.0;        // Zona oversold Stochastic (BUY)
input double          InpStochSellLevel = 70.0;        // Zona overbought Stochastic (SELL)
input int             InpSignalValidBars= 3;           // Masa berlaku sinyal (bar) setelah cross
input bool            InpSameBarOnly    = false;       // true = cross & candle konfirmasi harus 1 bar (paling ketat)

//--- Candle Konfirmasi (kuantitatif) ------------------------------
input group "=== Candle Konfirmasi ==="
input double          InpMinWickRatio     = 0.30;      // Rasio minimal rejection wick / total range
input double          InpMinClosePosition = 0.50;      // Posisi close minimal di paruh atas(BUY)/bawah(SELL)
input double          InpMinRangeATRRatio = 0.0;       // Range minimal = rasio x ATR (0 = nonaktif)

//--- Stop Loss (hard SL) ------------------------------------------
input group "=== Stop Loss (hard SL) ==="
input ENUM_SL_MODE    InpSLMode        = SL_CONFIRM;   // Mode SL (ConfirmCandle direkomendasikan)
input int             InpSLBufferPoints= 20;           // Buffer SL (points)
input int             InpSwingLookback = 10;           // Lookback swing (mode SwingLowHigh)
input int             InpATRPeriod     = 14;           // Periode ATR (M1)
input double          InpATRMultSL     = 1.5;          // Multiplier ATR untuk SL (mode ATR)
input int             InpMinSLPoints   = 50;           // Jarak SL minimal (points) - kalau lebih rapat, dilebarkan
input int             InpMaxSLPoints   = 800;          // Jarak SL maksimal (points) - kalau lebih lebar, entry dibatalkan

//--- Breakeven (Tahap 1) ------------------------------------------
input group "=== Breakeven (Tahap 1) ==="
input bool            InpUseBreakeven          = true; // Aktifkan breakeven
input int             InpBreakevenTriggerPoints= 100;  // Profit (points) untuk mengunci breakeven
input int             InpBreakevenBufferPoints = 5;    // Buffer breakeven (dipakai sebagai NILAI MINIMUM)
input int             InpCommissionPoints      = 0;    // Komisi round-turn dalam points (untuk buffer BE)

//--- Trailing (Tahap 2) -------------------------------------------
input group "=== Trailing (Tahap 2) ==="
input bool            InpUseTrailing        = true;    // Aktifkan trailing (hanya jalan setelah breakeven ter-set)
input ENUM_TRAIL_MODE InpTrailMode          = TRAIL_ATR;// Mode trailing
input double          InpATRMultTrail       = 1.5;     // Multiplier ATR untuk trailing
input int             InpTrailDistancePoints= 150;     // Jarak trailing tetap (mode FixedStep)
input int             InpTrailStepPoints    = 30;      // Step geser trailing (mode FixedStep)
input int             InpTrailEMAPeriod     = 20;      // Periode EMA trailing (mode EMA)
input int             InpMinModifyStepPoints= 5;       // Selisih minimal (points) agar SL dimodifikasi (throttle)

//--- Take Profit / Manajemen Tambahan -----------------------------
input group "=== Take Profit / Manajemen ==="
input ENUM_TP_MODE    InpTPMode        = TP_NONE;      // Mode TP (None = andalkan trailing)
input double          InpRR            = 1.5;          // Risk:Reward (mode RR)
input int             InpTPPoints      = 300;          // Jarak TP (points, mode Points)
input bool            InpUsePartial    = false;        // Aktifkan partial close
input double          InpPartialPercent= 50.0;         // Persen volume yang ditutup saat partial
input int             InpPartialAtPoints=150;          // Profit (points) untuk partial
input bool            InpUseTimeExit   = false;        // Aktifkan time-based exit
input int             InpMaxBarsInTrade= 30;           // Tutup jika belum profit setelah sekian bar

//--- Lot / Risk ---------------------------------------------------
input group "=== Lot / Risk ==="
input ENUM_LOT_MODE   InpLotMode     = LOT_FIXED;      // Mode lot
input double          InpFixedLot    = 0.01;           // Lot tetap (mode Fixed)
input double          InpRiskPercent = 0.5;            // Risiko % balance per trade (mode RiskPct)

//--- Filter Pasar -------------------------------------------------
input group "=== Filter Pasar ==="
input int             InpMaxSpreadPoints = 50;         // Spread maksimal (points)
input bool            InpUseSession      = false;      // Aktifkan filter sesi/jam
input int             InpSessionStartHour= 8;          // Jam mulai (waktu SERVER broker - beda tiap broker!)
input int             InpSessionEndHour  = 22;         // Jam selesai (waktu SERVER broker)
input bool            InpUseATRFilter    = false;      // Aktifkan filter ATR
input int             InpATRMinPoints    = 20;         // ATR minimal (points)
input int             InpATRMaxPoints    = 500;        // ATR maksimal (points)
input bool            InpUseNewsFilter   = false;      // Aktifkan filter news (Economic Calendar)
input int             InpNewsMinutesBefore = 15;       // Blackout menit sebelum news (tambahan)
input int             InpNewsMinutesAfter  = 15;       // Blackout menit sesudah news (tambahan)
input bool            InpNewsHighImpactOnly= true;     // Hanya news high-impact (tambahan)

//--- Proteksi Akun ------------------------------------------------
input group "=== Proteksi Akun ==="
input double          InpMaxDailyLossPercent    = 5.0; // Stop trading hari itu bila rugi harian > %
input int             InpMaxTradesPerDay        = 20;  // Batas entry per hari
input int             InpMaxOpenPositions       = 1;   // Maks posisi terbuka (default 1 - single entry)
input double          InpDailyProfitTargetPercent = 0.0;// Target profit harian % (0 = nonaktif)

//--- Umum ---------------------------------------------------------
input group "=== Umum ==="
input long            InpMagicNumber      = 20250722;  // Magic number EA
input int             InpMaxSlippagePoints= 30;         // Deviation/slippage maksimal (points)
input bool            InpVerboseLog       = true;      // Cetak alasan entry ditolak (debug di Tester)

//==================================================================//
//                        VARIABEL GLOBAL                           //
//==================================================================//
CTrade   trade;                       // objek operasi order

// Handle indikator
int      g_hTrendEMA = INVALID_HANDLE; // EMA pada TF tren
int      g_hADX      = INVALID_HANDLE; // ADX pada TF ADX
int      g_hRSI      = INVALID_HANDLE; // RSI M1
int      g_hStoch    = INVALID_HANDLE; // Stochastic M1
int      g_hATR      = INVALID_HANDLE; // ATR M1
int      g_hTrailEMA = INVALID_HANDLE; // EMA trailing M1

// Deteksi bar M1 baru
datetime g_lastBarTime = 0;

// State machine latch (arm/trigger/expire)
enum ENUM_LATCH { LATCH_IDLE = 0, LATCH_ARMED = 1, LATCH_TRIGGERED = 2 };
ENUM_LATCH g_buyLatch  = LATCH_IDLE;
ENUM_LATCH g_sellLatch = LATCH_IDLE;
int        g_buyBarsSinceTrig  = 0;
int        g_sellBarsSinceTrig = 0;
int        g_lastTrendDir = -2;        // sentinel supaya reset di bar pertama

// Cache per-posisi (di-key per tiket, sumber kebenaran tetap kondisi nyata SL)
ulong    g_curTicket    = 0;
bool     g_partialDone  = false;

// Penghitung harian
datetime g_dayStart       = 0;
double   g_dayStartEquity = 0.0;
int      g_tradesToday    = 0;
bool     g_blockedToday   = false;

//==================================================================//
//                          UTIL / LOGGING                          //
//==================================================================//
void LogReject(const string msg) { if(InpVerboseLog) Print("[TOLAK] ", msg); }
void LogInfo(const string msg)   { if(InpVerboseLog) Print("[INFO] ",  msg); }

//--- Salin buffer indikator ke array as-series (index 0 = terbaru) --
bool CopySeries(const int handle, const int bufIndex, const int count, double &arr[])
{
   ArraySetAsSeries(arr, true);
   int copied = CopyBuffer(handle, bufIndex, 0, count, arr);
   return (copied >= count);
}

//--- Jumlah desimal volume dari step ------------------------------
int VolumeDigits(double step)
{
   int d = 0;
   while(step < 1.0 && d < 8) { step *= 10.0; d++; }
   return d;
}

//--- Normalisasi volume ke step & clamp min/max -------------------
double NormalizeVolume(double lot)
{
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(step <= 0.0) step = 0.01;
   lot = MathFloor(lot / step) * step;
   if(lot < vmin) lot = vmin;   // NB: pada mode risk, jika hasil < min maka dipaksa ke min (risiko sedikit > target)
   if(lot > vmax) lot = vmax;
   return NormalizeDouble(lot, VolumeDigits(step));
}

//==================================================================//
//                              OnInit                              //
//==================================================================//
int OnInit()
{
   // Buat handle indikator
   g_hTrendEMA = iMA(_Symbol, InpTrendTimeframe, InpTrendEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_hADX      = iADX(_Symbol, InpADXTimeframe, InpADXPeriod);
   g_hRSI      = iRSI(_Symbol, PERIOD_M1, InpRSIPeriod, PRICE_CLOSE);
   g_hStoch    = iStochastic(_Symbol, PERIOD_M1, InpStochK, InpStochD, InpStochSlowing, MODE_SMA, STO_LOWHIGH);
   g_hATR      = iATR(_Symbol, PERIOD_M1, InpATRPeriod);
   g_hTrailEMA = iMA(_Symbol, PERIOD_M1, InpTrailEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);

   if(g_hTrendEMA == INVALID_HANDLE || g_hADX == INVALID_HANDLE ||
      g_hRSI == INVALID_HANDLE || g_hStoch == INVALID_HANDLE ||
      g_hATR == INVALID_HANDLE || g_hTrailEMA == INVALID_HANDLE)
   {
      Print("Gagal membuat handle indikator. OnInit dibatalkan.");
      return(INIT_FAILED);
   }

   // Konfigurasi CTrade
   trade.SetExpertMagicNumber((ulong)InpMagicNumber);
   trade.SetDeviationInPoints((ulong)InpMaxSlippagePoints);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetAsyncMode(false);

   // Inisialisasi penghitung harian
   ResetDailyIfNeeded(true);

   LogInfo("EA XAUUSD_ReversalTrend_M1 aktif. Point=" + DoubleToString(_Point, _Digits) +
           " Digits=" + IntegerToString(_Digits));
   return(INIT_SUCCEEDED);
}

//==================================================================//
//                             OnDeinit                             //
//==================================================================//
void OnDeinit(const int reason)
{
   if(g_hTrendEMA != INVALID_HANDLE) IndicatorRelease(g_hTrendEMA);
   if(g_hADX      != INVALID_HANDLE) IndicatorRelease(g_hADX);
   if(g_hRSI      != INVALID_HANDLE) IndicatorRelease(g_hRSI);
   if(g_hStoch    != INVALID_HANDLE) IndicatorRelease(g_hStoch);
   if(g_hATR      != INVALID_HANDLE) IndicatorRelease(g_hATR);
   if(g_hTrailEMA != INVALID_HANDLE) IndicatorRelease(g_hTrailEMA);
}

//==================================================================//
//                              OnTick                              //
//==================================================================//
void OnTick()
{
   // Reset penghitung bila ganti hari server
   ResetDailyIfNeeded(false);

   // Breakeven & trailing dievaluasi TIAP TICK
   ManageOpenPosition();

   // Logika ENTRY hanya sekali per bar M1 baru
   datetime t = iTime(_Symbol, PERIOD_M1, 0);
   if(t != g_lastBarTime)
   {
      g_lastBarTime = t;
      OnNewBar();
   }
}

//==================================================================//
//                    PROSES SETIAP BAR M1 BARU                     //
//==================================================================//
void OnNewBar()
{
   // 1) Evaluasi tren (gate arah)
   int dir = EvaluateTrend();   // +1 = BUY, -1 = SELL, 0 = tidak ada

   // 2) Reset latch bila arah tren berubah
   if(dir != g_lastTrendDir)
   {
      ResetLatches();
      g_lastTrendDir = dir;
   }

   // 3) Update latch oscillator sesuai arah aktif
   UpdateLatches(dir);

   // 4) Coba entry (single entry, cek proteksi harian & batas posisi)
   if(dir != 0 && CountOwnPositions() < InpMaxOpenPositions && CanTradeToday())
      TryEnter(dir);
}

//==================================================================//
//                     1. FILTER TREN (GATE ARAH)                   //
//==================================================================//
// Return +1 = izin BUY, -1 = izin SELL, 0 = tidak ada arah valid.
int EvaluateTrend()
{
   double ema[];
   if(!CopySeries(g_hTrendEMA, 0, InpSlopeLookback + 3, ema))
      return 0;   // data EMA belum siap

   double emaNow  = ema[1];                       // EMA bar tertutup terakhir
   double emaPast = ema[1 + InpSlopeLookback];    // EMA sekian bar lalu
   double closeTrend = iClose(_Symbol, InpTrendTimeframe, 1);
   if(closeTrend <= 0.0) return 0;

   double slopePoints = (emaNow - emaPast) / _Point;  // kemiringan dalam points

   bool up   = (closeTrend > emaNow);
   bool down = (closeTrend < emaNow);

   // Filter kemiringan (agar EMA datar tidak dianggap tren)
   if(InpUseSlopeFilter)
   {
      up   = up   && (slopePoints >=  InpMinSlopePoints);
      down = down && (slopePoints <= -InpMinSlopePoints);
   }

   // Filter kekuatan tren (ADX)
   if(InpUseADXFilter)
   {
      double adx[];
      if(!CopySeries(g_hADX, 0, 3, adx))
         return 0;
      if(adx[1] < InpADXMinLevel)
      {
         // tren lemah -> tidak ada entry
         return 0;
      }
   }

   if(up)   return  1;
   if(down) return -1;
   return 0;   // sideways / slope datar
}

//==================================================================//
//                 2. SINYAL OSCILLATOR + LATCH                     //
//==================================================================//

//--- Kondisi armed (sedang di zona ekstrem) -----------------------
bool RsiBuyArm()
{
   double r[];
   if(!CopySeries(g_hRSI, 0, 3, r)) return false;
   return (r[1] < InpRSIBuyLevel);
}
bool RsiSellArm()
{
   double r[];
   if(!CopySeries(g_hRSI, 0, 3, r)) return false;
   return (r[1] > InpRSISellLevel);
}
bool StochBuyArm()
{
   double k[];
   if(!CopySeries(g_hStoch, 0, 3, k)) return false;
   return (k[1] < InpStochBuyLevel);
}
bool StochSellArm()
{
   double k[];
   if(!CopySeries(g_hStoch, 0, 3, k)) return false;
   return (k[1] > InpStochSellLevel);
}

//--- Kondisi cross-balik (pemicu) pada bar tertutup terakhir -------
// Bandingkan index 1 vs 2 (bar tertutup), bukan bar berjalan index 0.
bool RsiBuyCross()
{
   double r[];
   if(!CopySeries(g_hRSI, 0, 3, r)) return false;
   return (r[2] < InpRSIBuyLevel && r[1] >= InpRSIBuyLevel);   // cross balik ke atas level oversold
}
bool RsiSellCross()
{
   double r[];
   if(!CopySeries(g_hRSI, 0, 3, r)) return false;
   return (r[2] > InpRSISellLevel && r[1] <= InpRSISellLevel); // cross balik ke bawah level overbought
}
bool StochBuyCross()
{
   double k[], d[];
   if(!CopySeries(g_hStoch, 0, 3, k)) return false;   // %K
   if(!CopySeries(g_hStoch, 1, 3, d)) return false;   // %D
   // %K sempat di bawah zona, lalu %K cross ke atas %D
   return (k[2] < InpStochBuyLevel && k[2] <= d[2] && k[1] > d[1]);
}
bool StochSellCross()
{
   double k[], d[];
   if(!CopySeries(g_hStoch, 0, 3, k)) return false;
   if(!CopySeries(g_hStoch, 1, 3, d)) return false;
   return (k[2] > InpStochSellLevel && k[2] >= d[2] && k[1] < d[1]);
}

//--- Gabungan sesuai InpOscMode -----------------------------------
bool OscBuyArm()
{
   switch(InpOscMode)
   {
      case OSC_RSI:   return RsiBuyArm();
      case OSC_STOCH: return StochBuyArm();
      default:        return RsiBuyArm() && StochBuyArm();   // BOTH: dua-duanya di zona
   }
}
bool OscSellArm()
{
   switch(InpOscMode)
   {
      case OSC_RSI:   return RsiSellArm();
      case OSC_STOCH: return StochSellArm();
      default:        return RsiSellArm() && StochSellArm();
   }
}
bool OscBuyCross()
{
   switch(InpOscMode)
   {
      case OSC_RSI:   return RsiBuyCross();
      case OSC_STOCH: return StochBuyCross();
      default:        return RsiBuyCross() && StochBuyCross();  // BOTH: strict, dua cross setuju
   }
}
bool OscSellCross()
{
   switch(InpOscMode)
   {
      case OSC_RSI:   return RsiSellCross();
      case OSC_STOCH: return StochSellCross();
      default:        return RsiSellCross() && StochSellCross();
   }
}

//--- Reset & expire latch -----------------------------------------
void ResetLatches()
{
   g_buyLatch = LATCH_IDLE;  g_buyBarsSinceTrig = 0;
   g_sellLatch = LATCH_IDLE; g_sellBarsSinceTrig = 0;
}
void ExpireLatch(int dir)
{
   if(dir > 0) { g_buyLatch = LATCH_IDLE;  g_buyBarsSinceTrig = 0; }
   else        { g_sellLatch = LATCH_IDLE; g_sellBarsSinceTrig = 0; }
}

//--- Update state machine latch tiap bar baru ---------------------
void UpdateLatches(int dir)
{
   // Hanya arah yang diizinkan tren yang di-update; arah lain dipaksa idle.
   if(dir > 0)
   {
      g_sellLatch = LATCH_IDLE; g_sellBarsSinceTrig = 0;
      UpdateBuyLatch();
   }
   else if(dir < 0)
   {
      g_buyLatch = LATCH_IDLE; g_buyBarsSinceTrig = 0;
      UpdateSellLatch();
   }
   else
   {
      ResetLatches();
   }
}

void UpdateBuyLatch()
{
   switch(g_buyLatch)
   {
      case LATCH_IDLE:
         if(OscBuyArm()) g_buyLatch = LATCH_ARMED;   // masuk zona ekstrem -> armed
         break;

      case LATCH_ARMED:
         if(OscBuyCross())                            // cross balik keluar zona -> triggered
         {
            g_buyLatch = LATCH_TRIGGERED;
            g_buyBarsSinceTrig = 0;
         }
         else if(!OscBuyArm())
         {
            g_buyLatch = LATCH_IDLE;                  // keluar zona tanpa cross bersih -> batal
         }
         break;

      case LATCH_TRIGGERED:
         if(OscBuyArm())
         {
            g_buyLatch = LATCH_ARMED;                 // kembali masuk zona -> hangus, re-arm
            g_buyBarsSinceTrig = 0;
         }
         else
         {
            g_buyBarsSinceTrig++;
            if(g_buyBarsSinceTrig > InpSignalValidBars)
               g_buyLatch = LATCH_IDLE;               // hangus karena melewati masa berlaku
         }
         break;
   }
}

void UpdateSellLatch()
{
   switch(g_sellLatch)
   {
      case LATCH_IDLE:
         if(OscSellArm()) g_sellLatch = LATCH_ARMED;
         break;

      case LATCH_ARMED:
         if(OscSellCross())
         {
            g_sellLatch = LATCH_TRIGGERED;
            g_sellBarsSinceTrig = 0;
         }
         else if(!OscSellArm())
         {
            g_sellLatch = LATCH_IDLE;
         }
         break;

      case LATCH_TRIGGERED:
         if(OscSellArm())
         {
            g_sellLatch = LATCH_ARMED;
            g_sellBarsSinceTrig = 0;
         }
         else
         {
            g_sellBarsSinceTrig++;
            if(g_sellBarsSinceTrig > InpSignalValidBars)
               g_sellLatch = LATCH_IDLE;
         }
         break;
   }
}

//==================================================================//
//               2c. CANDLE KONFIRMASI (KUANTITATIF)                //
//==================================================================//
// Dievaluasi pada candle M1 index 1 (sudah close).
bool ConfirmCandle(int dir)
{
   int i = 1;
   double o = iOpen (_Symbol, PERIOD_M1, i);
   double c = iClose(_Symbol, PERIOD_M1, i);
   double h = iHigh (_Symbol, PERIOD_M1, i);
   double l = iLow  (_Symbol, PERIOD_M1, i);
   double range = h - l;
   if(range <= 0.0) return false;   // aman terhadap pembagian nol (high == low)

   if(dir > 0)
   {
      if(!(c > o)) return false;                        // harus bullish
      double lowerWick = MathMin(o, c) - l;             // rejection wick bawah
      if(lowerWick / range < InpMinWickRatio) return false;
      double closePos = (c - l) / range;                // posisi close
      if(closePos < InpMinClosePosition) return false;  // close harus di paruh atas
   }
   else
   {
      if(!(c < o)) return false;                        // harus bearish
      double upperWick = h - MathMax(o, c);             // rejection wick atas
      if(upperWick / range < InpMinWickRatio) return false;
      double closePosTop = (h - c) / range;             // jarak close dari high
      if(closePosTop < InpMinClosePosition) return false; // close harus di paruh bawah
   }

   // Opsional: saring candle mikro tak bermakna
   if(InpMinRangeATRRatio > 0.0)
   {
      double atr = GetATR();
      if(atr > 0.0 && range < InpMinRangeATRRatio * atr) return false;
   }
   return true;
}

//==================================================================//
//                        EKSEKUSI ENTRY                            //
//==================================================================//
void TryEnter(int dir)
{
   ENUM_LATCH latch = (dir > 0) ? g_buyLatch : g_sellLatch;
   int barsSince    = (dir > 0) ? g_buyBarsSinceTrig : g_sellBarsSinceTrig;

   if(latch != LATCH_TRIGGERED) return;   // belum triggered

   // Mode SameBarOnly: cross & candle konfirmasi harus pada bar yang sama (barsSince==0).
   if(InpSameBarOnly && barsSince > 0)
   {
      ExpireLatch(dir);
      return;
   }

   // Candle konfirmasi kuantitatif
   if(!ConfirmCandle(dir))
      return;   // belum ada konfirmasi; latch tetap sampai hangus (mode normal)

   // Filter pasar
   if(!MarketFiltersPass())
      return;

   // Buka posisi
   if(OpenTrade(dir))
      ExpireLatch(dir);   // setelah entry, latch di-reset
}

//--- Cek semua filter pasar ---------------------------------------
bool MarketFiltersPass()
{
   // Spread
   double spreadPoints = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) -
                          SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
   if(spreadPoints > InpMaxSpreadPoints)
   {
      LogReject("spread=" + DoubleToString(spreadPoints, 0) + " > " + IntegerToString(InpMaxSpreadPoints));
      return false;
   }

   // Sesi / jam server
   if(InpUseSession && !InSession())
   {
      LogReject("di luar jam sesi");
      return false;
   }

   // Filter ATR
   if(InpUseATRFilter)
   {
      double atrPoints = GetATR() / _Point;
      if(atrPoints < InpATRMinPoints || atrPoints > InpATRMaxPoints)
      {
         LogReject("ATR=" + DoubleToString(atrPoints, 0) + " di luar rentang");
         return false;
      }
   }

   // Filter news
   if(InpUseNewsFilter && InNewsBlackout())
   {
      LogReject("dalam blackout news");
      return false;
   }

   return true;
}

//--- Buka trade dengan SL/TP/lot ----------------------------------
bool OpenTrade(int dir)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double entry = (dir > 0) ? ask : bid;

   // Hitung hard SL
   double sl;
   if(!ComputeSL(dir, entry, sl))
      return false;   // SL terlalu lebar / data belum siap -> batal

   double slDistPoints = MathAbs(entry - sl) / _Point;

   // Hitung TP
   double tp = ComputeTP(dir, entry, slDistPoints);

   // Hormati stops level untuk TP (kalau terlalu dekat, batalkan TP)
   double stops = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(tp > 0.0)
   {
      if(dir > 0 && (tp - ask) < stops) tp = 0.0;
      if(dir < 0 && (bid - tp) < stops) tp = 0.0;
   }

   // Hitung lot
   double lot = ComputeLot(slDistPoints);
   if(lot <= 0.0)
   {
      LogReject("lot hasil 0 (cek data tick value / risk)");
      return false;
   }

   sl = NormalizeDouble(sl, _Digits);
   tp = (tp > 0.0) ? NormalizeDouble(tp, _Digits) : 0.0;

   // Kirim order dengan retry saat requote
   bool ok = false;
   for(int attempt = 0; attempt < 3 && !ok; attempt++)
   {
      if(dir > 0) ok = trade.Buy (lot, _Symbol, 0.0, sl, tp, "ReversalTrend");
      else        ok = trade.Sell(lot, _Symbol, 0.0, sl, tp, "ReversalTrend");

      if(!ok)
      {
         uint rc = trade.ResultRetcode();
         if(rc == TRADE_RETCODE_REQUOTE || rc == TRADE_RETCODE_PRICE_CHANGED ||
            rc == TRADE_RETCODE_PRICE_OFF)
         {
            Sleep(150);
            ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            continue;   // coba lagi
         }
         LogReject("order gagal retcode=" + IntegerToString((int)rc));
         break;
      }
   }

   if(ok)
   {
      g_tradesToday++;
      g_curTicket   = 0;      // dipaksa refresh di ManageOpenPosition
      g_partialDone = false;
      LogInfo((dir > 0 ? "BUY" : "SELL") + " dibuka. lot=" + DoubleToString(lot, 2) +
              " SL=" + DoubleToString(sl, _Digits) + " TP=" + DoubleToString(tp, _Digits) +
              " (SLdist=" + DoubleToString(slDistPoints, 0) + " pts)");
   }
   return ok;
}

//==================================================================//
//                    3. HARD STOP LOSS                             //
//==================================================================//
bool ComputeSL(int dir, double entry, double &slOut)
{
   double buf = InpSLBufferPoints * _Point;
   double slRaw;

   if(InpSLMode == SL_CONFIRM)
   {
      // SL di bawah low / di atas high candle konfirmasi (termasuk wick) + buffer.
      double l = iLow (_Symbol, PERIOD_M1, 1);
      double h = iHigh(_Symbol, PERIOD_M1, 1);
      slRaw = (dir > 0) ? (l - buf) : (h + buf);
   }
   else if(InpSLMode == SL_SWING)
   {
      double ext = (dir > 0) ? SwingLow(InpSwingLookback) : SwingHigh(InpSwingLookback);
      slRaw = (dir > 0) ? (ext - buf) : (ext + buf);
   }
   else // SL_ATR
   {
      double atr = GetATR();
      if(atr <= 0.0) { LogReject("ATR belum siap untuk SL"); return false; }
      slRaw = (dir > 0) ? (entry - atr * InpATRMultSL) : (entry + atr * InpATRMultSL);
   }

   double slDist = MathAbs(entry - slRaw) / _Point;
   double stops  = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minReq = MathMax((double)InpMinSLPoints, stops + 1.0);

   // Terlalu rapat -> lebarkan ke minimum
   if(slDist < minReq) slDist = minReq;

   // Terlalu lebar -> batalkan entry (jangan dipaksakan)
   if(slDist > InpMaxSLPoints)
   {
      LogReject("SL terlalu lebar=" + DoubleToString(slDist, 0) + " > " + IntegerToString(InpMaxSLPoints));
      return false;
   }

   slOut = (dir > 0) ? (entry - slDist * _Point) : (entry + slDist * _Point);
   return true;
}

double SwingLow(int lb)
{
   double m = iLow(_Symbol, PERIOD_M1, 1);
   for(int i = 2; i <= lb; i++)
   {
      double v = iLow(_Symbol, PERIOD_M1, i);
      if(v < m) m = v;
   }
   return m;
}
double SwingHigh(int lb)
{
   double m = iHigh(_Symbol, PERIOD_M1, 1);
   for(int i = 2; i <= lb; i++)
   {
      double v = iHigh(_Symbol, PERIOD_M1, i);
      if(v > m) m = v;
   }
   return m;
}

//==================================================================//
//                    5. TAKE PROFIT                                //
//==================================================================//
double ComputeTP(int dir, double entry, double slDistPoints)
{
   if(InpTPMode == TP_NONE) return 0.0;

   double dist;
   if(InpTPMode == TP_RR) dist = slDistPoints * InpRR * _Point;
   else                   dist = InpTPPoints * _Point;   // TP_POINTS

   return (dir > 0) ? (entry + dist) : (entry - dist);
}

//==================================================================//
//                    6. POSITION SIZING                            //
//==================================================================//
double ComputeLot(double slDistPoints)
{
   double lot;
   if(InpLotMode == LOT_FIXED)
   {
      lot = InpFixedLot;
   }
   else // LOT_RISK
   {
      double bal      = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskMoney= bal * InpRiskPercent / 100.0;
      double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tickSize <= 0.0 || tickVal <= 0.0) return 0.0;

      // Nilai uang per 1 point per 1 lot
      double moneyPerPointPerLot = tickVal * _Point / tickSize;
      double denom = slDistPoints * moneyPerPointPerLot;
      if(denom <= 0.0) return 0.0;

      lot = riskMoney / denom;
   }
   return NormalizeVolume(lot);
}

//==================================================================//
//        4. MANAJEMEN STOP DUA TAHAP (breakeven -> trailing)       //
//        + partial close + time exit  (dievaluasi TIAP TICK)       //
//==================================================================//
void ManageOpenPosition()
{
   ulong ticket = GetOwnPositionTicket();
   if(ticket == 0)
   {
      // tidak ada posisi -> reset cache
      g_curTicket = 0;
      g_partialDone = false;
      return;
   }

   // Deteksi posisi baru (cache di-key per tiket, reset saat ganti tiket)
   if(ticket != g_curTicket)
   {
      g_curTicket = ticket;
      g_partialDone = false;
   }

   if(!PositionSelectByTicket(ticket)) return;

   long   type  = PositionGetInteger(POSITION_TYPE);
   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   double curSL = PositionGetDouble(POSITION_SL);
   double curTP = PositionGetDouble(POSITION_TP);
   double vol   = PositionGetDouble(POSITION_VOLUME);
   bool   isBuy = (type == POSITION_TYPE_BUY);

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // Pengukuran profit: BUY pakai Bid (harga tutup), SELL pakai Ask.
   double profitPoints = isBuy ? (bid - entry) / _Point : (entry - ask) / _Point;

   // --- Partial close ---
   HandlePartial(ticket, vol, profitPoints);

   // --- Time-based exit ---
   HandleTimeExit(ticket, profitPoints);

   // Posisi mungkin sudah tertutup penuh oleh time exit; cek ulang.
   if(!PositionSelectByTicket(ticket)) return;
   curSL = PositionGetDouble(POSITION_SL);
   curTP = PositionGetDouble(POSITION_TP);

   // --- Status breakeven diturunkan dari KONDISI NYATA (bukan cuma memori) ---
   // BUY: BE dianggap ter-set jika SL >= entry. SELL: SL <= entry (dan SL valid).
   bool beSet = false;
   if(curSL > 0.0)
      beSet = isBuy ? (curSL >= entry - 0.5 * _Point) : (curSL <= entry + 0.5 * _Point);

   // ================= Tahap 1: Breakeven =================
   if(InpUseBreakeven && !beSet && profitPoints >= InpBreakevenTriggerPoints)
   {
      // Buffer DINAMIS: minimal InpBreakevenBufferPoints, tapi tak boleh lebih kecil
      // dari (spread + komisi). Spread gold sering 15-30 point, jadi entry+5 bisa
      // masih rugi bersih setelah spread & komisi.
      double spreadPoints = (ask - bid) / _Point;
      double beBuffer = MathMax((double)InpBreakevenBufferPoints, spreadPoints + (double)InpCommissionPoints);
      double newSL = isBuy ? (entry + beBuffer * _Point) : (entry - beBuffer * _Point);

      if(SLisBetterAndValid(isBuy, newSL, curSL, bid, ask))
      {
         if(ModifyPosition(ticket, newSL, curTP))
         {
            curSL = newSL;
            beSet = true;
            LogInfo("Breakeven ter-set di " + DoubleToString(newSL, _Digits) +
                    " (buffer=" + DoubleToString(beBuffer, 0) + " pts)");
         }
      }
   }

   // ================= Tahap 2: Trailing (hanya setelah BE ter-set) =================
   if(InpUseTrailing && beSet)
   {
      double trailSL;
      if(ComputeTrailSL(isBuy, bid, ask, curSL, trailSL))
      {
         // SL hanya boleh ke arah profit, tidak pernah lebih longgar dari BE / SL sekarang.
         if(isBuy) trailSL = MathMax(trailSL, curSL);
         else      trailSL = MathMin(trailSL, curSL);

         if(SLisBetterAndValid(isBuy, trailSL, curSL, bid, ask))
            ModifyPosition(ticket, trailSL, curTP);
      }
   }
}

//--- Hitung SL trailing sesuai mode -------------------------------
bool ComputeTrailSL(bool isBuy, double bid, double ask, double curSL, double &out)
{
   if(InpTrailMode == TRAIL_ATR)
   {
      double atr = GetATR();
      if(atr <= 0.0) return false;
      out = isBuy ? (bid - atr * InpATRMultTrail) : (ask + atr * InpATRMultTrail);
      return true;
   }
   else if(InpTrailMode == TRAIL_FIXED)
   {
      double cand = isBuy ? (bid - InpTrailDistancePoints * _Point)
                          : (ask + InpTrailDistancePoints * _Point);
      // Geser hanya bila harga sudah maju minimal InpTrailStepPoints.
      if(isBuy) { if((cand - curSL) < InpTrailStepPoints * _Point) return false; }
      else      { if((curSL - cand) < InpTrailStepPoints * _Point) return false; }
      out = cand;
      return true;
   }
   else // TRAIL_EMA
   {
      double ema = GetTrailEMA();
      if(ema <= 0.0) return false;
      double buf = InpSLBufferPoints * _Point;
      out = isBuy ? (ema - buf) : (ema + buf);
      return true;
   }
}

//--- Validasi SL baru: ke arah profit, hormati stops/freeze, throttle
bool SLisBetterAndValid(bool isBuy, double newSL, double curSL, double bid, double ask)
{
   double stops  = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double freeze = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   double minDist = MathMax(stops, freeze) * _Point;

   if(isBuy)
   {
      if(newSL <= curSL) return false;                 // harus naik (ke arah profit)
      if((bid - newSL) < minDist) return false;        // terlalu dekat harga saat ini
   }
   else
   {
      if(curSL > 0.0 && newSL >= curSL) return false;  // harus turun (ke arah profit)
      if((newSL - ask) < minDist) return false;
   }

   // Throttle: jangan modify kalau selisih terlalu kecil (cegah spam & penolakan)
   if(MathAbs(newSL - curSL) < InpMinModifyStepPoints * _Point) return false;

   return true;
}

//--- Modify posisi dengan retry -----------------------------------
bool ModifyPosition(ulong ticket, double sl, double tp)
{
   sl = NormalizeDouble(sl, _Digits);
   tp = (tp > 0.0) ? NormalizeDouble(tp, _Digits) : 0.0;

   for(int attempt = 0; attempt < 3; attempt++)
   {
      if(trade.PositionModify(ticket, sl, tp)) return true;
      uint rc = trade.ResultRetcode();
      if(rc == TRADE_RETCODE_REQUOTE || rc == TRADE_RETCODE_PRICE_CHANGED)
      {
         Sleep(120);
         continue;
      }
      break;
   }
   return false;
}

//--- Partial close -------------------------------------------------
void HandlePartial(ulong ticket, double vol, double profitPoints)
{
   if(!InpUsePartial || g_partialDone) return;
   if(profitPoints < InpPartialAtPoints) return;

   double closeVol = NormalizeVolume(vol * InpPartialPercent / 100.0);
   if(closeVol <= 0.0 || closeVol >= vol)
   {
      g_partialDone = true;   // tidak valid untuk partial (mis. volume min); tandai selesai
      return;
   }
   if(trade.PositionClosePartial(ticket, closeVol))
   {
      g_partialDone = true;
      LogInfo("Partial close " + DoubleToString(closeVol, 2) + " lot @profit " +
              DoubleToString(profitPoints, 0) + " pts");
   }
}

//--- Time-based exit ----------------------------------------------
void HandleTimeExit(ulong ticket, double profitPoints)
{
   if(!InpUseTimeExit) return;
   datetime posTime = (datetime)PositionGetInteger(POSITION_TIME);
   int bars = iBarShift(_Symbol, PERIOD_M1, posTime, false);
   if(bars >= InpMaxBarsInTrade && profitPoints <= 0.0)
   {
      if(trade.PositionClose(ticket))
         LogInfo("Time exit: tutup posisi setelah " + IntegerToString(bars) + " bar tanpa profit");
   }
}

//==================================================================//
//                    7. FILTER PASAR (helper)                      //
//==================================================================//
double GetATR()
{
   double a[];
   if(!CopySeries(g_hATR, 0, 3, a)) return 0.0;
   return a[1];
}
double GetTrailEMA()
{
   double e[];
   if(!CopySeries(g_hTrailEMA, 0, 3, e)) return 0.0;
   return e[1];
}

bool InSession()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);   // waktu SERVER broker
   int hour = dt.hour;
   if(InpSessionStartHour <= InpSessionEndHour)
      return (hour >= InpSessionStartHour && hour < InpSessionEndHour);
   // sesi melewati tengah malam (start > end)
   return (hour >= InpSessionStartHour || hour < InpSessionEndHour);
}

// Filter news via MQL5 Economic Calendar.
// CATATAN: Calendar API TIDAK berfungsi di Strategy Tester -> di tester selalu return false.
bool InNewsBlackout()
{
   if(MQLInfoInteger(MQL_TESTER)) return false;

   datetime now  = TimeCurrent();
   datetime from = now - InpNewsMinutesBefore * 60;
   datetime to   = now + InpNewsMinutesAfter  * 60;

   MqlCalendarValue values[];
   // Gold sangat reaktif terhadap rilis USD.
   int n = CalendarValueHistory(values, from, to, NULL, "USD");
   for(int i = 0; i < n; i++)
   {
      MqlCalendarEvent ev;
      if(!CalendarEventById(values[i].event_id, ev)) continue;
      if(!InpNewsHighImpactOnly || ev.importance == CALENDAR_IMPORTANCE_HIGH)
         return true;
   }
   return false;
}

//==================================================================//
//                    8. PROTEKSI AKUN (helper)                     //
//==================================================================//
void ResetDailyIfNeeded(bool force)
{
   datetime today = TimeCurrent() - (TimeCurrent() % 86400);
   if(force || today != g_dayStart)
   {
      g_dayStart       = today;
      g_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      g_tradesToday    = 0;
      g_blockedToday   = false;
   }
}

bool CanTradeToday()
{
   if(g_blockedToday) return false;

   if(g_tradesToday >= InpMaxTradesPerDay)
   {
      LogReject("batas trade/hari tercapai");
      return false;
   }

   double dayResult = AccountInfoDouble(ACCOUNT_EQUITY) - g_dayStartEquity;

   double maxLoss = g_dayStartEquity * InpMaxDailyLossPercent / 100.0;
   if(maxLoss > 0.0 && dayResult <= -maxLoss)
   {
      g_blockedToday = true;
      LogReject("batas rugi harian tercapai");
      return false;
   }

   if(InpDailyProfitTargetPercent > 0.0)
   {
      double target = g_dayStartEquity * InpDailyProfitTargetPercent / 100.0;
      if(dayResult >= target)
      {
         g_blockedToday = true;
         LogReject("target profit harian tercapai");
         return false;
      }
   }
   return true;
}

//==================================================================//
//                  POSISI MILIK EA (magic + symbol)                //
//==================================================================//
ulong GetOwnPositionTicket()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
         return ticket;
   }
   return 0;
}

int CountOwnPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
         count++;
   }
   return count;
}
//+------------------------------------------------------------------+
