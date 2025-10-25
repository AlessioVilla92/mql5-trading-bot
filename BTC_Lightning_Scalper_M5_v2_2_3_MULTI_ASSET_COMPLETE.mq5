//+------------------------------------------------------------------+
//|                  BTC_Lightning_Scalper_M5_v2.2.3_COMPLETE.mq5   |
//|                   LIGHTNING SCALPER - MULTI-ASSET EDITION        |
//|           ✅ Sistema Multi-Asset Completo Implementato           |
//|           ✅ Selezione Manuale: BTC/ETH/FOREX/GOLD/etc           |
//|           ✅ Auto-Detection Intelligente                         |
//|           ✅ Database Completo Specifiche Asset                  |
//|           ✅ Validazioni Automatiche                             |
//|           ✅ Dashboard Info Asset Real-Time                      |
//|           ✅ Tutte le funzionalità v2.2.2 preservate             |
//+------------------------------------------------------------------+
#property copyright "Lightning Scalper v2.2.3 MULTI-ASSET - Complete Edition"
#property link      "Universal: BTC/ETH/FOREX/GOLD/INDICES"
#property version   "2.23"
#property description "Multi-asset scalper with intelligent asset detection"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//+------------------------------------------------------------------+
//|                        ENUMS & CONSTANTS                        |
//+------------------------------------------------------------------+

enum ENUM_LOG_LEVEL {
    LOG_LEVEL_ERROR = 0,
    LOG_LEVEL_WARNING = 1,
    LOG_LEVEL_INFO = 2,
    LOG_LEVEL_DEBUG = 3
};

// === NUOVO: ENUM ASSET TYPE - Sistema Multi-Asset ===
enum ENUM_ASSET_TYPE {
    ASSET_FOREX_MAJOR = 0,      // Forex Major (EUR, GBP, USD pairs) 5-digit
    ASSET_FOREX_JPY = 1,        // Forex JPY pairs (3-digit)
    ASSET_CRYPTO_BTC = 2,       // Bitcoin (BTCUSD, BTCUSDT)
    ASSET_CRYPTO_ETH = 3,       // Ethereum (ETHUSD, ETHUSDT)
    ASSET_CRYPTO_OTHER = 4,     // Other Crypto (SOL, BNB, ADA, etc)
    ASSET_GOLD = 5,             // Gold (XAUUSD)
    ASSET_SILVER = 6,           // Silver (XAGUSD)
    ASSET_OIL = 7,              // Oil (USOIL, BRENT)
    ASSET_INDICES = 8,          // Stock Indices (SPX, NAS100, etc)
    ASSET_AUTO = 9              // Auto-detect from symbol name/digits
};

//+------------------------------------------------------------------+
//|                        STRUCTURES                               |
//+------------------------------------------------------------------+

// === NUOVO: Asset Specifications Database ===
struct AssetSpecs {
    string   name;              // Descriptive name
    int      expectedDigits;    // Expected decimal places
    double   pointValue;        // Value of 1 point
    double   pipValue;          // Value of 1 pip
    double   minStopDistance;   // Minimum SL/TP distance in pips
    double   typicalSpread;     // Typical spread in pips
    double   maxSpreadPips;     // Max acceptable spread for scalping
    double   minVolatility;     // Minimum volatility %
    double   maxVolatility;     // Maximum volatility %
    bool     allowScalping;     // Is asset suitable for scalping
    string   notes;             // Additional notes
};

struct SuperTrendState {
    double upperBand;
    double lowerBand;
    double trendLine;
    int    direction;
    bool   changed;
    double atr;
    double prevUpperBand;
    double prevLowerBand;
    int    prevDirection;
    datetime lastChangeTime;
    int    lastChangeBar;
    bool   initialized;
};

struct MicroTrendAnalysis {
    int    direction;
    double strength;
    double velocity;
    double momentum;
    bool   confirmed;
    int    consistency;
};

struct QualityScore {
    double total;
    double trend_align;
    double momentum_score;
    double volatility_score;
    double volume_score;
    bool   tradeable;
    string reason;
};

struct TradingStats {
    int    totalTrades;
    int    winningTrades;
    int    losingTrades;
    double totalProfit;
    double totalLoss;
    double bestTrade;
    double worstTrade;
    int    consecutiveWins;
    int    consecutiveLosses;
    int    maxConsecutiveWins;
    int    maxConsecutiveLosses;
    double totalProfitPips;
    double avgWinPips;
    double avgLossPips;
    double currentWinRate;
    datetime lastTradeTime;
};

struct SessionData {
    int      dailyTradeCount;
    double   dailyStartBalance;
    datetime currentDayDate;
    int      hourlyTradeCount;
    datetime currentHourStart;
    double   sessionHighBalance;
    double   sessionLowBalance;
    double   maxDrawdown;
    double   maxRunup;
    double   peakBalance;
};

//+------------------------------------------------------------------+
//|                     INPUT PARAMETERS                            |
//+------------------------------------------------------------------+

input group "=== 🎯 ASSET CONFIGURATION (NUOVO!) ==="
input ENUM_ASSET_TYPE InpAssetType = ASSET_AUTO;     // Asset Type Selection
input bool      InpShowAssetInfo      = true;        // Show Asset Info on Init
input bool      InpAutoAdjustParams   = true;        // Auto-suggest parameters

input group "=== EA Configuration ==="
input double    InpLotSize            = 0.01;        // Lot Size
input int       InpMagicNumber        = 223500;      // Magic Number  
input string    InpTradeComment       = "LTG_v223";  // Trade Comment

string g_TradeComment;

input group "=== Risk/Reward - FIXED REALISTIC ==="
input double    InpFixedStopLoss      = 50.0;        // Stop Loss (pips)
input double    InpFixedTakeProfit    = 80.0;        // Take Profit (pips)
input bool      InpUseAdaptiveTP      = true;        // Adaptive TP (volatility-based)
input double    InpLowVolMultiplier   = 0.85;        // Low Vol TP Multiplier
input double    InpHighVolMultiplier  = 1.25;        // High Vol TP Multiplier

input group "=== SuperTrend Entry - OPTIMIZED ==="
input int       InpSTPeriod           = 7;           // ST Period
input double    InpSTMultiplier       = 1.5;         // ST Multiplier
input bool      InpSTUseHL            = false;       // Use High/Low
input int       InpEntryWindowBars    = 15;          // Entry window (bars)

input group "=== MicroTrend Detection - FIXED ==="
input bool      InpUseMicroTrend      = true;        // Enable MicroTrend
input int       InpMicroBars          = 5;           // Analysis bars
input double    InpMicroThreshold     = 0.8;         // Threshold (pips)
input double    InpMicroMinStrength   = 30.0;        // Min Strength %

input group "=== Quality Filter - BALANCED ==="
input bool      InpUseQualityFilter   = true;        // Enable Quality Filter
input double    InpMinQuality         = 20.0;        // Min Quality Score

input group "=== Volume Filter ==="
input bool      InpUseVolumeFilter    = false;       // Enable Volume Filter
input double    InpMinVolumeRatio     = 0.5;         // Min Volume Ratio

input group "=== Time Filter ==="
input bool      InpUseTimeFilter      = false;       // Enable Time Filter
input int       InpAvoidHourStart     = 2;           // Avoid Start Hour (UTC)
input int       InpAvoidHourEnd       = 6;           // Avoid End Hour (UTC)

input group "=== Breakeven & Trailing ==="
input bool      InpUseBreakeven       = true;        // Use Breakeven
input double    InpBETrigger          = 20.0;        // BE Trigger (pips)
input double    InpBELevel            = 5.0;         // BE Lock Level (pips)
input bool      InpUseTrailing        = true;        // Use Trailing Stop
input double    InpTrailStart         = 30.0;        // Trail Start (pips)
input double    InpTrailDistance      = 15.0;        // Trail Distance (pips)

input group "=== Position Management ==="
input int       InpMaxPositions       = 1;           // Max Open Positions
input int       InpMaxDailyTrades     = 40;          // Max Daily Trades
input double    InpMaxDailyLoss       = 100.0;       // Max Daily Loss ($)
input int       InpMinBarsBetween     = 2;           // Min Bars Between Trades
input int       InpMaxTradeDuration   = 60;          // Max Trade Duration (minutes)

input group "=== Visual Markers ==="
input bool      InpShowEntryMarkers   = true;        // Show Entry Markers
input bool      InpKeepMarkersOnExit  = true;        // Keep Markers When Removed
input color     InpLongArrowColor     = clrLime;     // Long Arrow Color
input color     InpShortArrowColor    = clrRed;      // Short Arrow Color
input color     InpEntryLineColor     = clrDodgerBlue; // Entry Line Color
input int       InpArrowSize          = 2;           // Arrow Size

input group "=== Alerts ==="
input bool      InpSendAlerts         = false;       // Send Alerts
input bool      InpAlertOnEntry       = true;        // Alert on Entry
input bool      InpAlertOnExit        = true;        // Alert on Exit
input bool      InpAlertOnBE          = false;       // Alert on Breakeven
input bool      InpAlertOnTarget      = true;        // Alert on Take Profit

input group "=== Dashboard & Display ==="
input bool      InpShowDashboard      = true;        // Show Dashboard
input int       InpDashboardX         = 15;          // Dashboard X
input int       InpDashboardY         = 30;          // Dashboard Y
input color     InpColorProfit        = clrLime;     // Profit Color
input color     InpColorLoss          = clrRed;      // Loss Color
input color     InpColorNeutral       = clrYellow;   // Neutral Color

input group "=== Logging ==="
input ENUM_LOG_LEVEL InpLogLevel      = LOG_LEVEL_INFO; // Log Level

//+------------------------------------------------------------------+
//|                     GLOBAL VARIABLES                            |
//+------------------------------------------------------------------+

CTrade         trade;
CPositionInfo  position;
CAccountInfo   account;

int handle_atr;
int handle_ma_fast;
int handle_ma_slow;

SuperTrendState stEntry;
MicroTrendAnalysis microTrend;
QualityScore quality;
TradingStats stats;
SessionData session;

// === NUOVO: Multi-Asset System Globals ===
ENUM_ASSET_TYPE g_CurrentAssetType;
AssetSpecs      g_CurrentAssetSpecs;
bool            g_AssetValidated = false;

double cached_volatility = 0;
double cached_avg_volatility = 0;
double cached_spread_points = 0;
double currentSL = 0;
double currentTP = 0;
double effectiveRR = 0;

bool     systemActive = true;
bool     dailyLimitReached = false;
int      lastTradeBar = 0;
datetime lastAlertTime = 0;

string dashboardName = "LTG_Scalper_v223";

//+------------------------------------------------------------------+
//|              MULTI-ASSET SYSTEM - CORE FUNCTIONS                |
//+------------------------------------------------------------------+

// === NUOVO: Auto-Detection Asset Type ===
ENUM_ASSET_TYPE DetectAssetType()
{
    string symbol = _Symbol;
    StringToUpper(symbol);
    
    // Bitcoin detection
    if(StringFind(symbol, "BTC") >= 0 || StringFind(symbol, "BITCOIN") >= 0) {
        LogPrint(LOG_LEVEL_INFO, "🔍 Auto-detected: BITCOIN");
        return ASSET_CRYPTO_BTC;
    }
    
    // Ethereum detection
    if(StringFind(symbol, "ETH") >= 0 || StringFind(symbol, "ETHEREUM") >= 0) {
        LogPrint(LOG_LEVEL_INFO, "🔍 Auto-detected: ETHEREUM");
        return ASSET_CRYPTO_ETH;
    }
    
    // Other crypto
    if(StringFind(symbol, "SOL") >= 0 || StringFind(symbol, "BNB") >= 0 ||
       StringFind(symbol, "ADA") >= 0 || StringFind(symbol, "DOT") >= 0 ||
       StringFind(symbol, "USDT") >= 0 || StringFind(symbol, "USDC") >= 0) {
        LogPrint(LOG_LEVEL_INFO, "🔍 Auto-detected: OTHER CRYPTO");
        return ASSET_CRYPTO_OTHER;
    }
    
    // Gold detection
    if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0) {
        LogPrint(LOG_LEVEL_INFO, "🔍 Auto-detected: GOLD");
        return ASSET_GOLD;
    }
    
    // Silver detection
    if(StringFind(symbol, "XAG") >= 0 || StringFind(symbol, "SILVER") >= 0) {
        LogPrint(LOG_LEVEL_INFO, "🔍 Auto-detected: SILVER");
        return ASSET_SILVER;
    }
    
    // Oil detection
    if(StringFind(symbol, "OIL") >= 0 || StringFind(symbol, "BRENT") >= 0 ||
       StringFind(symbol, "WTI") >= 0 || StringFind(symbol, "CL") >= 0) {
        LogPrint(LOG_LEVEL_INFO, "🔍 Auto-detected: OIL");
        return ASSET_OIL;
    }
    
    // Indices detection
    if(StringFind(symbol, "SPX") >= 0 || StringFind(symbol, "NAS") >= 0 ||
       StringFind(symbol, "DOW") >= 0 || StringFind(symbol, "DAX") >= 0 ||
       StringFind(symbol, "FTSE") >= 0) {
        LogPrint(LOG_LEVEL_INFO, "🔍 Auto-detected: INDICES");
        return ASSET_INDICES;
    }
    
    // Forex JPY pairs
    if(StringFind(symbol, "JPY") >= 0) {
        LogPrint(LOG_LEVEL_INFO, "🔍 Auto-detected: FOREX JPY");
        return ASSET_FOREX_JPY;
    }
    
    // Forex detection by digits (fallback)
    if(_Digits == 5) {
        LogPrint(LOG_LEVEL_INFO, "🔍 Auto-detected by digits (5): FOREX MAJOR");
        return ASSET_FOREX_MAJOR;
    }
    
    if(_Digits == 3) {
        LogPrint(LOG_LEVEL_INFO, "🔍 Auto-detected by digits (3): FOREX JPY");
        return ASSET_FOREX_JPY;
    }
    
    if(_Digits == 2) {
        LogPrint(LOG_LEVEL_WARNING, "⚠️ Auto-detected by digits (2): Assuming CRYPTO");
        return ASSET_CRYPTO_BTC;
    }
    
    // Default fallback
    LogPrint(LOG_LEVEL_WARNING, "⚠️ Unable to auto-detect asset, using FOREX MAJOR as default");
    return ASSET_FOREX_MAJOR;
}

// === NUOVO: Get Asset Specifications Database ===
AssetSpecs GetAssetSpecifications(ENUM_ASSET_TYPE assetType)
{
    AssetSpecs specs;
    
    switch(assetType) {
        case ASSET_FOREX_MAJOR:
            specs.name = "Forex Major Pairs";
            specs.expectedDigits = 5;
            specs.pointValue = 0.00001;
            specs.pipValue = 0.0001;
            specs.minStopDistance = 2.0;     // Min 2 pips
            specs.typicalSpread = 0.5;       // 0.5 pips typical
            specs.maxSpreadPips = 2.0;       // Max 2 pips for scalping
            specs.minVolatility = 0.3;
            specs.maxVolatility = 1.5;
            specs.allowScalping = true;
            specs.notes = "EURUSD, GBPUSD, etc. - Excellent for scalping";
            break;
            
        case ASSET_FOREX_JPY:
            specs.name = "Forex JPY Pairs";
            specs.expectedDigits = 3;
            specs.pointValue = 0.001;
            specs.pipValue = 0.01;
            specs.minStopDistance = 2.0;
            specs.typicalSpread = 0.5;
            specs.maxSpreadPips = 2.5;
            specs.minVolatility = 0.3;
            specs.maxVolatility = 1.5;
            specs.allowScalping = true;
            specs.notes = "USDJPY, EURJPY, etc. - Good for scalping";
            break;
            
        case ASSET_CRYPTO_BTC:
            specs.name = "Bitcoin";
            specs.expectedDigits = 2;
            specs.pointValue = 0.01;
            specs.pipValue = 1.0;  // 1 USD = 1 pip
            specs.minStopDistance = 5.0;     // Min 5 USD
            specs.typicalSpread = 2.0;       // 2 USD typical
            specs.maxSpreadPips = 8.0;       // Max 8 USD for scalping
            specs.minVolatility = 0.5;
            specs.maxVolatility = 8.0;
            specs.allowScalping = true;
            specs.notes = "BTCUSD, BTCUSDT - Excellent for scalping, high volatility";
            break;
            
        case ASSET_CRYPTO_ETH:
            specs.name = "Ethereum";
            specs.expectedDigits = 2;
            specs.pointValue = 0.01;
            specs.pipValue = 1.0;  // 1 USD = 1 pip
            specs.minStopDistance = 3.0;     // Min 3 USD
            specs.typicalSpread = 0.5;       // 0.50 USD typical
            specs.maxSpreadPips = 3.0;       // Max 3 USD for scalping
            specs.minVolatility = 0.8;
            specs.maxVolatility = 10.0;
            specs.allowScalping = true;
            specs.notes = "ETHUSD, ETHUSDT - Excellent for scalping, high volatility";
            break;
            
        case ASSET_CRYPTO_OTHER:
            specs.name = "Other Cryptocurrencies";
            specs.expectedDigits = 2;  // Can vary
            specs.pointValue = 0.01;
            specs.pipValue = 1.0;
            specs.minStopDistance = 2.0;
            specs.typicalSpread = 0.5;
            specs.maxSpreadPips = 3.0;
            specs.minVolatility = 1.0;
            specs.maxVolatility = 15.0;
            specs.allowScalping = true;
            specs.notes = "SOL, BNB, ADA - Very high volatility, experts only!";
            break;
            
        case ASSET_GOLD:
            specs.name = "Gold (XAUUSD)";
            specs.expectedDigits = 2;
            specs.pointValue = 0.01;
            specs.pipValue = 0.1;  // Some brokers: 10 points = 1 pip
            specs.minStopDistance = 5.0;     // Min 5 pips
            specs.typicalSpread = 2.0;       // 2 pips typical
            specs.maxSpreadPips = 5.0;       // Max 5 pips for scalping
            specs.minVolatility = 0.3;
            specs.maxVolatility = 3.0;
            specs.allowScalping = true;
            specs.notes = "XAUUSD - Good for scalping, moderate volatility";
            break;
            
        case ASSET_SILVER:
            specs.name = "Silver (XAGUSD)";
            specs.expectedDigits = 3;
            specs.pointValue = 0.001;
            specs.pipValue = 0.01;
            specs.minStopDistance = 5.0;
            specs.typicalSpread = 3.0;
            specs.maxSpreadPips = 6.0;
            specs.minVolatility = 0.5;
            specs.maxVolatility = 5.0;
            specs.allowScalping = true;
            specs.notes = "XAGUSD - Higher volatility than gold";
            break;
            
        case ASSET_OIL:
            specs.name = "Oil";
            specs.expectedDigits = 2;
            specs.pointValue = 0.01;
            specs.pipValue = 1.0;
            specs.minStopDistance = 10.0;
            specs.typicalSpread = 3.0;
            specs.maxSpreadPips = 8.0;
            specs.minVolatility = 1.0;
            specs.maxVolatility = 8.0;
            specs.allowScalping = false;  // Not ideal for scalping
            specs.notes = "USOIL, BRENT - High volatility, wider stops needed";
            break;
            
        case ASSET_INDICES:
            specs.name = "Stock Indices";
            specs.expectedDigits = 1;  // Can vary
            specs.pointValue = 0.1;
            specs.pipValue = 1.0;
            specs.minStopDistance = 5.0;
            specs.typicalSpread = 0.5;
            specs.maxSpreadPips = 2.0;
            specs.minVolatility = 0.5;
            specs.maxVolatility = 3.0;
            specs.allowScalping = true;
            specs.notes = "SPX500, NAS100, etc. - Good for scalping";
            break;
            
        default:
            // Safe defaults
            specs.name = "Unknown Asset";
            specs.expectedDigits = _Digits;
            specs.pointValue = _Point;
            specs.pipValue = (_Digits == 5 || _Digits == 3) ? _Point * 10 : _Point;
            specs.minStopDistance = 5.0;
            specs.typicalSpread = 1.0;
            specs.maxSpreadPips = 5.0;
            specs.minVolatility = 0.3;
            specs.maxVolatility = 5.0;
            specs.allowScalping = true;
            specs.notes = "Unknown asset type - using safe defaults";
            break;
    }
    
    return specs;
}

// === NUOVO: Initialize Asset Configuration ===
bool InitializeAssetConfiguration()
{
    // Determine asset type
    if(InpAssetType == ASSET_AUTO) {
        g_CurrentAssetType = DetectAssetType();
    } else {
        g_CurrentAssetType = InpAssetType;
        LogPrint(LOG_LEVEL_INFO, "🎯 Manual asset selection: " + EnumToString(g_CurrentAssetType));
    }
    
    // Get asset specifications
    g_CurrentAssetSpecs = GetAssetSpecifications(g_CurrentAssetType);
    
    // Display asset information
    if(InpShowAssetInfo) {
        DisplayAssetInfo();
    }
    
    // Validate asset configuration
    return ValidateAssetConfiguration();
}

// === NUOVO: Display Asset Information ===
void DisplayAssetInfo()
{
    LogPrint(LOG_LEVEL_INFO, "========================================");
    LogPrint(LOG_LEVEL_INFO, "   🎯 ASSET CONFIGURATION");
    LogPrint(LOG_LEVEL_INFO, "========================================");
    LogPrint(LOG_LEVEL_INFO, "Asset: " + g_CurrentAssetSpecs.name);
    LogPrint(LOG_LEVEL_INFO, "Symbol: " + _Symbol);
    LogPrint(LOG_LEVEL_INFO, StringFormat("Digits: %d (expected: %d)", 
             _Digits, g_CurrentAssetSpecs.expectedDigits));
    LogPrint(LOG_LEVEL_INFO, StringFormat("Point Value: %.10f", g_CurrentAssetSpecs.pointValue));
    LogPrint(LOG_LEVEL_INFO, StringFormat("Pip Value: %.10f", g_CurrentAssetSpecs.pipValue));
    LogPrint(LOG_LEVEL_INFO, StringFormat("Min Stop Distance: %.1f pips", g_CurrentAssetSpecs.minStopDistance));
    LogPrint(LOG_LEVEL_INFO, StringFormat("Typical Spread: %.1f pips", g_CurrentAssetSpecs.typicalSpread));
    LogPrint(LOG_LEVEL_INFO, StringFormat("Max Spread (scalping): %.1f pips", g_CurrentAssetSpecs.maxSpreadPips));
    LogPrint(LOG_LEVEL_INFO, StringFormat("Volatility Range: %.2f%% - %.2f%%", 
             g_CurrentAssetSpecs.minVolatility, g_CurrentAssetSpecs.maxVolatility));
    LogPrint(LOG_LEVEL_INFO, "Scalping Suitable: " + (g_CurrentAssetSpecs.allowScalping ? "YES ✓" : "NO ✗"));
    LogPrint(LOG_LEVEL_INFO, "Notes: " + g_CurrentAssetSpecs.notes);
    LogPrint(LOG_LEVEL_INFO, "========================================");
    
    // Auto-adjust parameters recommendations
    if(InpAutoAdjustParams) {
        AutoAdjustParameters();
    }
}

// === NUOVO: Validate Asset Configuration ===
bool ValidateAssetConfiguration()
{
    bool valid = true;
    
    // Check digits match
    if(_Digits != g_CurrentAssetSpecs.expectedDigits) {
        LogPrint(LOG_LEVEL_WARNING, StringFormat("⚠️ WARNING: Symbol digits (%d) differ from expected (%d)", 
                 _Digits, g_CurrentAssetSpecs.expectedDigits));
        LogPrint(LOG_LEVEL_WARNING, "   This may indicate wrong asset type selection.");
        LogPrint(LOG_LEVEL_WARNING, "   EA will use actual symbol digits for calculations.");
    }
    
    // Check if scalping is allowed
    if(!g_CurrentAssetSpecs.allowScalping) {
        LogPrint(LOG_LEVEL_WARNING, "⚠️ WARNING: This asset is NOT recommended for scalping!");
        LogPrint(LOG_LEVEL_WARNING, "   Consider using higher timeframes or different asset.");
    }
    
    // Check current spread
    double currentSpread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) / 10.0;
    if(currentSpread > g_CurrentAssetSpecs.maxSpreadPips) {
        LogPrint(LOG_LEVEL_WARNING, StringFormat("⚠️ WARNING: Current spread (%.1f pips) exceeds max recommended (%.1f pips)!", 
                 currentSpread, g_CurrentAssetSpecs.maxSpreadPips));
        LogPrint(LOG_LEVEL_WARNING, "   Scalping may be difficult or unprofitable.");
        LogPrint(LOG_LEVEL_WARNING, "   Consider different broker or trading hours.");
    }
    
    // Check minimum stop distance
    if(InpFixedStopLoss < g_CurrentAssetSpecs.minStopDistance) {
        LogPrint(LOG_LEVEL_WARNING, StringFormat("⚠️ WARNING: Your SL (%.1f pips) is below minimum recommended (%.1f pips)", 
                 InpFixedStopLoss, g_CurrentAssetSpecs.minStopDistance));
        LogPrint(LOG_LEVEL_WARNING, "   You may get 'Invalid Stops' errors.");
    }
    
    g_AssetValidated = true;
    return valid;
}

// === NUOVO: Auto-Adjust Parameters ===
void AutoAdjustParameters()
{
    LogPrint(LOG_LEVEL_INFO, "🔧 Auto-adjusting parameters for " + g_CurrentAssetSpecs.name + "...");
    
    bool needsAdjustment = false;
    
    // Check SL vs minimum
    if(InpFixedStopLoss < g_CurrentAssetSpecs.minStopDistance * 1.5) {
        LogPrint(LOG_LEVEL_INFO, StringFormat("   💡 Recommended SL: %.1f pips (current: %.1f)", 
                 g_CurrentAssetSpecs.minStopDistance * 2.0, InpFixedStopLoss));
        needsAdjustment = true;
    }
    
    // Check TP for good R:R
    double recommendedTP = InpFixedStopLoss * 1.6;
    if(InpFixedTakeProfit < recommendedTP) {
        LogPrint(LOG_LEVEL_INFO, StringFormat("   💡 Recommended TP: %.1f pips for R:R 1:1.6 (current: %.1f)", 
                 recommendedTP, InpFixedTakeProfit));
        needsAdjustment = true;
    }
    
    // Check spread vs parameters
    double currentSpread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) / 10.0;
    if(currentSpread > g_CurrentAssetSpecs.maxSpreadPips) {
        LogPrint(LOG_LEVEL_WARNING, StringFormat("   ⚠️ Current spread %.1f pips > Max %.1f pips for scalping!", 
                 currentSpread, g_CurrentAssetSpecs.maxSpreadPips));
        LogPrint(LOG_LEVEL_WARNING, "   Consider using different broker or trading during high-liquidity hours.");
        needsAdjustment = true;
    }
    
    if(!needsAdjustment) {
        LogPrint(LOG_LEVEL_INFO, "   ✅ Current parameters are suitable for this asset");
    } else {
        LogPrint(LOG_LEVEL_INFO, "   📋 PARAMETER RECOMMENDATIONS:");
        LogPrint(LOG_LEVEL_INFO, "   These are suggestions - your current settings will be used.");
    }
}

// === NUOVO: Universal Pips to Price Conversion ===
double PipsToPrice(double pips)
{
    // Use current asset specifications
    return pips * g_CurrentAssetSpecs.pipValue;
}

// === NUOVO: Universal Price to Pips Conversion ===
double PriceToPips(double priceDistance)
{
    // Use current asset specifications
    if(g_CurrentAssetSpecs.pipValue == 0) return 0;
    return priceDistance / g_CurrentAssetSpecs.pipValue;
}

//+------------------------------------------------------------------+
//|                    INITIALIZATION                               |
//+------------------------------------------------------------------+

int OnInit()
{
    g_TradeComment = InpTradeComment;
    
    // === NUOVO: Initialize Multi-Asset System FIRST ===
    if(!InitializeAssetConfiguration()) {
        LogPrint(LOG_LEVEL_ERROR, "❌ Asset configuration failed!");
        return INIT_FAILED;
    }
    
    trade.SetExpertMagicNumber(InpMagicNumber);
    trade.SetDeviationInPoints(50);
    trade.SetTypeFilling(ORDER_FILLING_FOK);
    trade.SetAsyncMode(false);
    trade.LogLevel(LOG_LEVEL_ERRORS);
    
    if(_Period != PERIOD_M5) {
        LogPrint(LOG_LEVEL_ERROR, "❌ ERROR: This EA is optimized for M5 timeframe!");
        LogPrint(LOG_LEVEL_ERROR, "   Current timeframe: " + EnumToString((ENUM_TIMEFRAMES)_Period));
        Alert("Lightning Scalper ERROR: Wrong timeframe! Use M5");
        return INIT_PARAMETERS_INCORRECT;
    }
    
    if(!ValidateInputs()) {
        LogPrint(LOG_LEVEL_ERROR, "Invalid input parameters!");
        return INIT_PARAMETERS_INCORRECT;
    }
    
    handle_atr = iATR(_Symbol, PERIOD_CURRENT, InpSTPeriod);
    handle_ma_fast = iMA(_Symbol, PERIOD_CURRENT, 3, 0, MODE_SMA, PRICE_CLOSE);
    handle_ma_slow = iMA(_Symbol, PERIOD_CURRENT, 8, 0, MODE_SMA, PRICE_CLOSE);
    
    if(handle_atr == INVALID_HANDLE || 
       handle_ma_fast == INVALID_HANDLE || 
       handle_ma_slow == INVALID_HANDLE) {
        LogPrint(LOG_LEVEL_ERROR, "Failed to create indicator handles!");
        return INIT_FAILED;
    }
    
    ResetDailyStats();
    ResetStats();
    stEntry.initialized = false;
    
    systemActive = true;
    dailyLimitReached = false;
    
    CalculateAverageVolatility();
    CalculateAdaptiveTargets();
    
    if(InpShowDashboard) CreateDashboard();
    
    // Startup log
    LogPrint(LOG_LEVEL_INFO, "==============================================");
    LogPrint(LOG_LEVEL_INFO, "   LIGHTNING SCALPER M5 v2.2.3 COMPLETE");
    LogPrint(LOG_LEVEL_INFO, "   MULTI-ASSET EDITION");
    LogPrint(LOG_LEVEL_INFO, "==============================================");
    LogPrint(LOG_LEVEL_INFO, "✅ Timeframe: M5 (Correct)");
    LogPrint(LOG_LEVEL_INFO, "✅ Asset: " + g_CurrentAssetSpecs.name);
    LogPrint(LOG_LEVEL_INFO, "✅ Risk/Reward: 1:" + DoubleToString(effectiveRR, 2));
    LogPrint(LOG_LEVEL_INFO, "✅ Required WR: " + DoubleToString(100.0 / (1.0 + effectiveRR), 1) + "%");
    LogPrint(LOG_LEVEL_INFO, "==============================================");
    LogPrint(LOG_LEVEL_INFO, "Strategy:");
    LogPrint(LOG_LEVEL_INFO, "- Stop Loss: " + DoubleToString(InpFixedStopLoss, 1) + " pips");
    LogPrint(LOG_LEVEL_INFO, "- Take Profit: " + DoubleToString(InpFixedTakeProfit, 1) + " pips");
    LogPrint(LOG_LEVEL_INFO, "- SuperTrend: " + IntegerToString(InpSTPeriod) + "/" + DoubleToString(InpSTMultiplier, 1));
    LogPrint(LOG_LEVEL_INFO, "- MicroTrend: " + DoubleToString(InpMicroThreshold, 1) + " pips threshold");
    LogPrint(LOG_LEVEL_INFO, "- Quality Min: " + DoubleToString(InpMinQuality, 0) + "/100");
    LogPrint(LOG_LEVEL_INFO, "- Max Daily Trades: " + IntegerToString(InpMaxDailyTrades));
    LogPrint(LOG_LEVEL_INFO, "==============================================");
    LogPrint(LOG_LEVEL_INFO, "✅ LIGHTNING SCALPER v2.2.3 MULTI-ASSET READY!");
    LogPrint(LOG_LEVEL_INFO, "==============================================");
    
    if(InpSendAlerts) {
        Alert("Lightning Scalper v2.2.3 started on ", _Symbol, " M5");
    }
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//|                      MAIN TICK HANDLER                          |
//+------------------------------------------------------------------+

void OnTick()
{
    if(!systemActive || !IsTradeAllowed()) {
        if(InpShowDashboard) UpdateDashboard();
        return;
    }
    
    CheckDailyLimits();
    if(dailyLimitReached) {
        if(InpShowDashboard) UpdateDashboard();
        return;
    }
    
    UpdateIndicators();
    
    if(InpUseMicroTrend) {
        microTrend = AnalyzeMicroTrend();
    }
    
    ManageOpenPositions();
    
    if(CountOpenPositions() == 0) {
        CheckEntrySignal();
    }
    
    if(InpShowDashboard) UpdateDashboard();
}

//+------------------------------------------------------------------+
//|                     ENTRY LOGIC                                 |
//+------------------------------------------------------------------+

void CheckEntrySignal()
{
    if(Bars(_Symbol, PERIOD_CURRENT) - lastTradeBar < InpMinBarsBetween) return;
    if(session.dailyTradeCount >= InpMaxDailyTrades) return;
    
    if(InpUseTimeFilter) {
        MqlDateTime dt;
        TimeToStruct(TimeCurrent(), dt);
        if(dt.hour >= InpAvoidHourStart && dt.hour < InpAvoidHourEnd) {
            LogPrint(LOG_LEVEL_DEBUG, "⏰ Time filter: Hour " + IntegerToString(dt.hour) + " avoided");
            return;
        }
    }
    
    if(InpUseVolumeFilter && !CheckVolumeFilter()) return;
    
    if(!stEntry.initialized) return;
    
    int signal = 0;
    int barsSinceChange = GetBarsSince(stEntry.lastChangeBar);
    
    if(barsSinceChange <= InpEntryWindowBars) {
        signal = stEntry.direction;
        LogPrint(LOG_LEVEL_DEBUG, "✓ ST signal: " + (signal > 0 ? "BUY" : "SELL") +
                " (" + IntegerToString(barsSinceChange) + " bars ago)");
    }
    
    if(signal == 0) {
        LogPrint(LOG_LEVEL_DEBUG, "✗ No ST signal (change too old: " + 
                IntegerToString(barsSinceChange) + " bars)");
        return;
    }
    
    if(InpUseMicroTrend) {
        if(microTrend.direction != signal && microTrend.direction != 0) {
            LogPrint(LOG_LEVEL_DEBUG, "✗ MicroTrend not aligned: ST=" + 
                    IntegerToString(signal) + " Micro=" + IntegerToString(microTrend.direction));
            return;
        }
        
        if(microTrend.strength < InpMicroMinStrength) {
            LogPrint(LOG_LEVEL_DEBUG, "✗ MicroTrend weak: " + 
                    DoubleToString(microTrend.strength, 1) + "%");
            return;
        }
    }
    
    quality = CalculateQualityScore(signal);
    
    if(InpUseQualityFilter && !quality.tradeable) {
        LogPrint(LOG_LEVEL_DEBUG, "✗ Quality: " + quality.reason);
        return;
    }
    
    bool confirmed = CheckPriceAction(signal);
    if(!confirmed) {
        LogPrint(LOG_LEVEL_DEBUG, "✗ Price action not confirmed");
        return;
    }
    
    ExecuteTrade(signal);
}

bool CheckPriceAction(int signal)
{
    double close[], open[], high[], low[];
    CopyClose(_Symbol, PERIOD_CURRENT, 1, 2, close);
    CopyOpen(_Symbol, PERIOD_CURRENT, 1, 2, open);
    CopyHigh(_Symbol, PERIOD_CURRENT, 1, 1, high);
    CopyLow(_Symbol, PERIOD_CURRENT, 1, 1, low);
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(open, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    
    if(signal == 1) {
        double body = close[0] - open[0];
        double range = high[0] - low[0];
        return (body > 0 && body > range * 0.4 && close[0] > close[1]);
    }
    else {
        double body = open[0] - close[0];
        double range = high[0] - low[0];
        return (body > 0 && body > range * 0.4 && close[0] < close[1]);
    }
}

bool CheckVolumeFilter()
{
    long volume[];
    CopyTickVolume(_Symbol, PERIOD_CURRENT, 0, 21, volume);
    ArraySetAsSeries(volume, true);
    
    long currentVol = volume[0];
    long avgVol = 0;
    for(int i = 1; i <= 20; i++) avgVol += volume[i];
    avgVol /= 20;
    
    if(currentVol < avgVol * InpMinVolumeRatio) {
        LogPrint(LOG_LEVEL_DEBUG, "⚠️ Volume too low: " + IntegerToString(currentVol) + 
                " vs " + IntegerToString(avgVol));
        return false;
    }
    
    return true;
}

void ExecuteTrade(int signal)
{
    CalculateAdaptiveTargets();
    
    double price = (signal == 1) ? 
                   SymbolInfoDouble(_Symbol, SYMBOL_ASK) :
                   SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // === USA IL NUOVO SISTEMA MULTI-ASSET ===
    double sl = (signal == 1) ?
                price - PipsToPrice(currentSL) :
                price + PipsToPrice(currentSL);
    
    double tp = (signal == 1) ?
                price + PipsToPrice(currentTP) :
                price - PipsToPrice(currentTP);
    
    sl = NormalizeDouble(sl, _Digits);
    tp = NormalizeDouble(tp, _Digits);
    price = NormalizeDouble(price, _Digits);
    
    string comment = StringFormat("%s_%s_Q%.0f_RR%.2f", 
                                  g_TradeComment, 
                                  g_CurrentAssetSpecs.name,
                                  quality.total, 
                                  effectiveRR);
    
    bool result = false;
    
    if(signal == 1) {
        result = trade.Buy(InpLotSize, _Symbol, price, sl, tp, comment);
    }
    else {
        result = trade.Sell(InpLotSize, _Symbol, price, sl, tp, comment);
    }
    
    if(result) {
        ulong ticket = trade.ResultOrder();
        RegisterTrade();
        
        if(InpShowEntryMarkers) {
            DrawEntryMarkers(ticket, signal, price);
        }
        
        LogPrint(LOG_LEVEL_INFO, "========================================");
        LogPrint(LOG_LEVEL_INFO, "✅ " + (signal == 1 ? "BUY" : "SELL") + " OPENED - " + g_CurrentAssetSpecs.name);
        LogPrint(LOG_LEVEL_INFO, "Ticket: #" + IntegerToString(ticket));
        LogPrint(LOG_LEVEL_INFO, "Entry: " + DoubleToString(price, _Digits));
        LogPrint(LOG_LEVEL_INFO, "SL: " + DoubleToString(currentSL, 1) + " pips (" + 
                DoubleToString(sl, _Digits) + ")");
        LogPrint(LOG_LEVEL_INFO, "TP: " + DoubleToString(currentTP, 1) + " pips (" + 
                DoubleToString(tp, _Digits) + ")");
        LogPrint(LOG_LEVEL_INFO, "R:R: 1:" + DoubleToString(effectiveRR, 2));
        LogPrint(LOG_LEVEL_INFO, "Quality: " + DoubleToString(quality.total, 0) + "/100");
        LogPrint(LOG_LEVEL_INFO, "Asset: " + g_CurrentAssetSpecs.name);
        LogPrint(LOG_LEVEL_INFO, "========================================");
        
        if(InpSendAlerts && InpAlertOnEntry) {
            SendCustomAlert("ENTRY", signal, ticket, price);
        }
    }
    else {
        LogPrint(LOG_LEVEL_ERROR, "❌ Trade failed: " + IntegerToString(trade.ResultRetcode()) + 
                " - " + trade.ResultRetcodeDescription());
    }
}

//+------------------------------------------------------------------+
//|                  POSITION MANAGEMENT                            |
//+------------------------------------------------------------------+

void ManageOpenPositions()
{
    int total = PositionsTotal();
    
    for(int i = total - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;
        
        if(!position.SelectByTicket(ticket)) continue;
        if(position.Symbol() != _Symbol) continue;
        if(position.Magic() != InpMagicNumber) continue;
        
        double pips = GetPositionProfitPips(ticket);
        int ageMinutes = (int)((TimeCurrent() - position.Time()) / 60);
        
        if(ageMinutes > InpMaxTradeDuration) {
            ClosePosition(ticket, "TIMEOUT");
            continue;
        }
        
        if(InpUseBreakeven && pips >= InpBETrigger) {
            SetBreakeven(ticket);
        }
        
        if(InpUseTrailing && pips >= InpTrailStart) {
            UpdateTrailing(ticket, pips);
        }
    }
}

void SetBreakeven(ulong ticket)
{
    if(!position.SelectByTicket(ticket)) return;
    
    double beLevel;
    double posSL = position.StopLoss();
    double openPrice = position.PriceOpen();
    
    if(position.PositionType() == POSITION_TYPE_BUY) {
        beLevel = NormalizeDouble(openPrice + PipsToPrice(InpBELevel), _Digits);
        if(posSL < beLevel || posSL == 0) {
            if(trade.PositionModify(ticket, beLevel, position.TakeProfit())) {
                LogPrint(LOG_LEVEL_INFO, "✅ BE set for #" + IntegerToString(ticket) + 
                        " at +" + DoubleToString(InpBELevel, 1) + " pips");
                
                if(InpSendAlerts && InpAlertOnBE) {
                    SendCustomAlert("BREAKEVEN", (int)position.PositionType(), ticket, beLevel);
                }
            }
        }
    }
    else {
        beLevel = NormalizeDouble(openPrice - PipsToPrice(InpBELevel), _Digits);
        if(posSL > beLevel || posSL == 0) {
            if(trade.PositionModify(ticket, beLevel, position.TakeProfit())) {
                LogPrint(LOG_LEVEL_INFO, "✅ BE set for #" + IntegerToString(ticket) + 
                        " at +" + DoubleToString(InpBELevel, 1) + " pips");
                
                if(InpSendAlerts && InpAlertOnBE) {
                    SendCustomAlert("BREAKEVEN", (int)position.PositionType(), ticket, beLevel);
                }
            }
        }
    }
}

void UpdateTrailing(ulong ticket, double currentPips)
{
    if(!position.SelectByTicket(ticket)) return;
    
    double newSL;
    double posSL = position.StopLoss();
    
    if(position.PositionType() == POSITION_TYPE_BUY) {
        double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        newSL = NormalizeDouble(bid - PipsToPrice(InpTrailDistance), _Digits);
        
        if(newSL > posSL + (_Point * 10) || posSL == 0) {
            if(trade.PositionModify(ticket, newSL, position.TakeProfit())) {
                LogPrint(LOG_LEVEL_DEBUG, "✅ Trail updated for #" + IntegerToString(ticket));
            }
        }
    }
    else {
        double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        newSL = NormalizeDouble(ask + PipsToPrice(InpTrailDistance), _Digits);
        
        if(newSL < posSL - (_Point * 10) || posSL == 0) {
            if(trade.PositionModify(ticket, newSL, position.TakeProfit())) {
                LogPrint(LOG_LEVEL_DEBUG, "✅ Trail updated for #" + IntegerToString(ticket));
            }
        }
    }
}

void ClosePosition(ulong ticket, string reason)
{
    if(!position.SelectByTicket(ticket)) return;
    
    double pips = GetPositionProfitPips(ticket);
    double profit = position.Profit() + position.Swap() + position.Commission();
    
    if(trade.PositionClose(ticket)) {
        UpdateStats(profit, pips);
        
        LogPrint(LOG_LEVEL_INFO, "❌ CLOSED #" + IntegerToString(ticket) + " | " + reason);
        LogPrint(LOG_LEVEL_INFO, "   Pips: " + DoubleToString(pips, 1));
        LogPrint(LOG_LEVEL_INFO, "   Profit: $" + DoubleToString(profit, 2));
        
        if(InpSendAlerts && InpAlertOnExit) {
            string alertType = (profit > 0) ? "PROFIT" : "LOSS";
            if(reason == "TIMEOUT") alertType = "TIMEOUT";
            SendCustomAlert(alertType, (int)position.PositionType(), ticket, profit);
        }
        
        if(InpSendAlerts && InpAlertOnTarget && reason == "TARGET") {
            SendCustomAlert("TARGET", (int)position.PositionType(), ticket, profit);
        }
    }
}

//+------------------------------------------------------------------+
//|              INDICATOR CALCULATIONS                             |
//+------------------------------------------------------------------+

void UpdateIndicators()
{
    static datetime lastUpdate = 0;
    if(TimeCurrent() - lastUpdate < 5) return;
    lastUpdate = TimeCurrent();
    
    CalculateSuperTrend(stEntry, InpSTPeriod, InpSTMultiplier, 0, InpSTUseHL);
    cached_volatility = CalculateVolatility();
    cached_spread_points = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
}

void CalculateSuperTrend(SuperTrendState &st, int period, double multiplier,
                         int shift, bool useHL)
{
    int bars = Bars(_Symbol, PERIOD_CURRENT);
    if(bars < period + shift + 2) return;
    
    double atr[];
    if(CopyBuffer(handle_atr, 0, shift, 1, atr) <= 0) return;
    st.atr = atr[0];
    if(st.atr <= 0) return;
    
    double high[], low[], close[];
    CopyHigh(_Symbol, PERIOD_CURRENT, shift, 2, high);
    CopyLow(_Symbol, PERIOD_CURRENT, shift, 2, low);
    CopyClose(_Symbol, PERIOD_CURRENT, shift, 2, close);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    
    double hl2 = useHL ? (high[0] + low[0]) / 2.0 : close[0];
    
    double basicUpper = hl2 + (multiplier * st.atr);
    double basicLower = hl2 - (multiplier * st.atr);
    
    if(!st.initialized) {
        st.prevUpperBand = basicUpper;
        st.prevLowerBand = basicLower;
        st.prevDirection = (close[0] > hl2) ? 1 : -1;
        st.direction = st.prevDirection;
        st.upperBand = basicUpper;
        st.lowerBand = basicLower;
        st.trendLine = (st.direction == 1) ? st.lowerBand : st.upperBand;
        st.initialized = true;
        st.lastChangeTime = TimeCurrent();
        st.lastChangeBar = bars;
        st.changed = false;
        return;
    }
    
    if(basicUpper < st.prevUpperBand || close[1] > st.prevUpperBand) {
        st.upperBand = basicUpper;
    } else {
        st.upperBand = st.prevUpperBand;
    }
    
    if(basicLower > st.prevLowerBand || close[1] < st.prevLowerBand) {
        st.lowerBand = basicLower;
    } else {
        st.lowerBand = st.prevLowerBand;
    }
    
    int oldDirection = st.direction;
    
    if(st.prevDirection == 1) {
        if(close[0] <= st.lowerBand) {
            st.direction = -1;
            st.trendLine = st.upperBand;
        } else {
            st.direction = 1;
            st.trendLine = st.lowerBand;
        }
    } else {
        if(close[0] >= st.upperBand) {
            st.direction = 1;
            st.trendLine = st.lowerBand;
        } else {
            st.direction = -1;
            st.trendLine = st.upperBand;
        }
    }
    
    st.changed = (oldDirection != st.direction);
    if(st.changed) {
        st.lastChangeTime = TimeCurrent();
        st.lastChangeBar = bars;
        LogPrint(LOG_LEVEL_INFO, "🔄 SuperTrend changed to " + 
                (st.direction > 0 ? "BUY" : "SELL"));
    }
    
    st.prevUpperBand = st.upperBand;
    st.prevLowerBand = st.lowerBand;
    st.prevDirection = st.direction;
}

MicroTrendAnalysis AnalyzeMicroTrend()
{
    MicroTrendAnalysis mta;
    mta.direction = 0;
    mta.strength = 0;
    mta.velocity = 0;
    mta.momentum = 0;
    mta.confirmed = false;
    mta.consistency = 0;
    
    if(Bars(_Symbol, PERIOD_CURRENT) < InpMicroBars + 2) return mta;
    
    double ma_fast[], ma_slow[];
    if(CopyBuffer(handle_ma_fast, 0, 0, 1, ma_fast) <= 0) return mta;
    if(CopyBuffer(handle_ma_slow, 0, 0, 1, ma_slow) <= 0) return mta;
    
    double diff = ma_fast[0] - ma_slow[0];
    // === USA IL NUOVO SISTEMA MULTI-ASSET ===
    double pip_diff = PriceToPips(diff);
    
    if(pip_diff > InpMicroThreshold) {
        mta.direction = 1;
    } else if(pip_diff < -InpMicroThreshold) {
        mta.direction = -1;
    }
    
    double close[], open[];
    CopyClose(_Symbol, PERIOD_CURRENT, 1, InpMicroBars, close);
    CopyOpen(_Symbol, PERIOD_CURRENT, 1, InpMicroBars, open);
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(open, true);
    
    int bullBars = 0, bearBars = 0;
    for(int i = 0; i < InpMicroBars; i++) {
        if(close[i] > open[i]) bullBars++;
        else bearBars++;
        
        if(i < 3 && i < InpMicroBars - 1) {
            bool currentBull = (close[i] > open[i]);
            bool prevBull = (close[i+1] > open[i+1]);
            if(currentBull == prevBull) mta.consistency++;
        }
    }
    
    if(bullBars > bearBars) {
        mta.strength = (double)bullBars / InpMicroBars * 100;
    } else {
        mta.strength = (double)bearBars / InpMicroBars * 100;
    }
    
    double priceChange = close[0] - close[InpMicroBars - 1];
    // === USA IL NUOVO SISTEMA MULTI-ASSET ===
    mta.velocity = PriceToPips(MathAbs(priceChange)) / InpMicroBars;
    
    if(close[InpMicroBars - 1] != 0) {
        mta.momentum = (priceChange / close[InpMicroBars - 1]) * 100.0;
    }
    
    long volume[];
    CopyTickVolume(_Symbol, PERIOD_CURRENT, 0, 11, volume);
    ArraySetAsSeries(volume, true);
    
    long currentVol = volume[0];
    long avgVol = 0;
    for(int i = 1; i <= 10; i++) avgVol += volume[i];
    avgVol /= 10;
    
    mta.confirmed = (currentVol > avgVol * 0.8 && mta.strength > 40);
    
    return mta;
}

QualityScore CalculateQualityScore(int signal)
{
    QualityScore qs;
    qs.total = 0;
    qs.tradeable = false;
    
    if(stEntry.direction == signal) {
        qs.trend_align = 15;
        if(InpUseMicroTrend && microTrend.direction == signal) {
            qs.trend_align += 15;
        }
        else if(InpUseMicroTrend && microTrend.direction == 0) {
            qs.trend_align += 7;
        }
    }
    
    qs.momentum_score = 0;
    if(InpUseMicroTrend) {
        double momentum = microTrend.momentum;
        if(signal == 1 && momentum > 0.2) {
            qs.momentum_score = MathMin(momentum * 150, 30);
        }
        else if(signal == -1 && momentum < -0.2) {
            qs.momentum_score = MathMin(MathAbs(momentum) * 150, 30);
        }
    }
    
    qs.volatility_score = 0;
    if(cached_volatility >= g_CurrentAssetSpecs.minVolatility && 
       cached_volatility <= g_CurrentAssetSpecs.maxVolatility) {
        qs.volatility_score = 20;
    }
    else if(cached_volatility > 0) {
        qs.volatility_score = 10;
    }
    
    qs.volume_score = 0;
    long volume[];
    CopyTickVolume(_Symbol, PERIOD_CURRENT, 0, 11, volume);
    ArraySetAsSeries(volume, true);
    
    long currentVol = volume[0];
    long avgVol = 0;
    for(int i = 1; i <= 10; i++) avgVol += volume[i];
    avgVol /= 10;
    
    if(currentVol > avgVol * 1.2) {
        qs.volume_score = 10;
    }
    else if(currentVol > avgVol * 0.8) {
        qs.volume_score = 5;
    }
    
    qs.total = qs.trend_align + qs.momentum_score + 
               qs.volatility_score + qs.volume_score;
    
    qs.tradeable = (qs.total >= InpMinQuality);
    
    if(!qs.tradeable) {
        qs.reason = StringFormat("Score %.1f < %.1f (T:%.0f M:%.0f V:%.0f Vol:%.0f)", 
                                qs.total, InpMinQuality,
                                qs.trend_align, qs.momentum_score,
                                qs.volatility_score, qs.volume_score);
    } else {
        qs.reason = StringFormat("Score %.1f ✓", qs.total);
    }
    
    return qs;
}

void CalculateAdaptiveTargets()
{
    currentSL = InpFixedStopLoss;
    currentTP = InpFixedTakeProfit;
    
    if(InpUseAdaptiveTP && cached_avg_volatility > 0) {
        double volRatio = cached_volatility / cached_avg_volatility;
        
        if(volRatio < 0.7) {
            currentTP = InpFixedTakeProfit * InpLowVolMultiplier;
            if(currentTP / currentSL < 1.5) {
                currentTP = currentSL * 1.5;
            }
        }
        else if(volRatio > 1.5) {
            currentTP = InpFixedTakeProfit * InpHighVolMultiplier;
            currentSL = InpFixedStopLoss * 1.1;
        }
    }
    
    if(currentTP / currentSL < 1.5) {
        currentTP = currentSL * 1.5;
    }
    
    effectiveRR = currentTP / currentSL;
}

//+------------------------------------------------------------------+
//|              VISUAL MARKERS ON CHART                            |
//+------------------------------------------------------------------+

void DrawEntryMarkers(ulong ticket, int signal, double entryPrice)
{
    if(!InpShowEntryMarkers) return;
    
    datetime entryTime = TimeCurrent();
    string prefix = "Entry_" + IntegerToString(ticket) + "_";
    
    string lineName = prefix + "Line";
    datetime lineStart = entryTime - PeriodSeconds(PERIOD_CURRENT) / 2;
    datetime lineEnd = entryTime + PeriodSeconds(PERIOD_CURRENT) / 2;
    
    if(ObjectFind(0, lineName) < 0) {
        ObjectCreate(0, lineName, OBJ_TREND, 0, lineStart, entryPrice, lineEnd, entryPrice);
        ObjectSetInteger(0, lineName, OBJPROP_COLOR, InpEntryLineColor);
        ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
        ObjectSetInteger(0, lineName, OBJPROP_RAY_LEFT, false);
        ObjectSetInteger(0, lineName, OBJPROP_BACK, false);
        ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, true);
        ObjectSetInteger(0, lineName, OBJPROP_SELECTED, false);
        ObjectSetString(0, lineName, OBJPROP_TOOLTIP, "Entry: " + DoubleToString(entryPrice, _Digits) + 
                       " | " + (signal == 1 ? "LONG" : "SHORT") + " | #" + IntegerToString(ticket));
    }
    
    string arrowName = prefix + "Arrow";
    
    if(ObjectFind(0, arrowName) < 0) {
        // === USA IL NUOVO SISTEMA MULTI-ASSET ===
        double arrowPrice = (signal == 1) ? 
                           entryPrice - PipsToPrice(10) :
                           entryPrice + PipsToPrice(10);
        
        ObjectCreate(0, arrowName, OBJ_ARROW, 0, entryTime, arrowPrice);
        
        int arrowCode = (signal == 1) ? 233 : 234;
        ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, arrowCode);
        
        color arrowColor = (signal == 1) ? InpLongArrowColor : InpShortArrowColor;
        ObjectSetInteger(0, arrowName, OBJPROP_COLOR, arrowColor);
        ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, InpArrowSize);
        ObjectSetInteger(0, arrowName, OBJPROP_BACK, false);
        ObjectSetInteger(0, arrowName, OBJPROP_SELECTABLE, true);
        ObjectSetInteger(0, arrowName, OBJPROP_SELECTED, false);
        
        string direction = (signal == 1) ? "LONG ▲" : "SHORT ▼";
        ObjectSetString(0, arrowName, OBJPROP_TOOLTIP, 
                       direction + " Entry | Price: " + DoubleToString(entryPrice, _Digits) + 
                       " | Ticket: #" + IntegerToString(ticket) + 
                       " | Time: " + TimeToString(entryTime));
    }
    
    ChartRedraw(0);
    
    LogPrint(LOG_LEVEL_DEBUG, "✅ Entry markers drawn for ticket #" + IntegerToString(ticket));
}

void DeleteAllEntryMarkers()
{
    int total = ObjectsTotal(0, 0, -1);
    
    for(int i = total - 1; i >= 0; i--) {
        string objName = ObjectName(0, i, 0, -1);
        
        if(StringFind(objName, "Entry_") == 0) {
            ObjectDelete(0, objName);
        }
    }
    
    ChartRedraw(0);
    LogPrint(LOG_LEVEL_INFO, "🗑️ All entry markers cleared from chart");
}

//+------------------------------------------------------------------+
//|              ALERT SYSTEM                                       |
//+------------------------------------------------------------------+

void SendCustomAlert(string alertType, int direction, ulong ticket, double value)
{
    if(!InpSendAlerts) return;
    
    if(TimeCurrent() - lastAlertTime < 5) return;
    lastAlertTime = TimeCurrent();
    
    string message = "";
    string symbol = _Symbol;
    string dirText = (direction == 1 || direction == POSITION_TYPE_BUY) ? "LONG" : "SHORT";
    
    if(alertType == "ENTRY") {
        message = StringFormat("Lightning Scalper: %s %s opened on %s at %.5f | Ticket #%d",
                              dirText, alertType, symbol, value, ticket);
    }
    else if(alertType == "BREAKEVEN") {
        message = StringFormat("Lightning Scalper: %s moved to BREAKEVEN on %s | Ticket #%d",
                              dirText, symbol, ticket);
    }
    else if(alertType == "PROFIT" || alertType == "LOSS") {
        message = StringFormat("Lightning Scalper: %s closed with %s: $%.2f on %s | Ticket #%d",
                              dirText, alertType, value, symbol, ticket);
    }
    else if(alertType == "TARGET") {
        message = StringFormat("Lightning Scalper: %s hit TAKE PROFIT: $%.2f on %s | Ticket #%d",
                              dirText, value, symbol, ticket);
    }
    else if(alertType == "TIMEOUT") {
        message = StringFormat("Lightning Scalper: %s closed by TIMEOUT on %s | Ticket #%d",
                              dirText, symbol, ticket);
    }
    
    if(message != "") {
        Alert(message);
        LogPrint(LOG_LEVEL_INFO, "🔔 Alert sent: " + message);
    }
}

//+------------------------------------------------------------------+
//|              DASHBOARD SYSTEM                                   |
//+------------------------------------------------------------------+

void CreateDashboard()
{
    DeleteDashboard();
    
    string bgName = dashboardName + "_BG";
    ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, InpDashboardX);
    ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, InpDashboardY);
    ObjectSetInteger(0, bgName, OBJPROP_XSIZE, 450);
    ObjectSetInteger(0, bgName, OBJPROP_YSIZE, 540);
    ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, clrDarkSlateGray);
    ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, bgName, OBJPROP_COLOR, clrDodgerBlue);
    ObjectSetInteger(0, bgName, OBJPROP_WIDTH, 2);
    ObjectSetInteger(0, bgName, OBJPROP_BACK, false);
    
    CreateLabel(dashboardName + "_Title", InpDashboardX + 15, InpDashboardY + 10,
               "LIGHTNING SCALPER v2.2.3 MULTI-ASSET ⚡", 12, clrAqua, true);
}

void UpdateDashboard()
{
    if(!InpShowDashboard) return;
    
    static datetime lastUpdate = 0;
    if(TimeCurrent() - lastUpdate < 2) return;
    lastUpdate = TimeCurrent();
    
    int y = InpDashboardY + 40;
    int s = 18;
    
    // === NUOVO: Asset Info ===
    string assetInfo = "Asset: " + g_CurrentAssetSpecs.name;
    CreateLabel(dashboardName + "_Asset", InpDashboardX + 15, y, assetInfo, 10, clrAqua, false);
    y += s;
    
    // Status
    string status = systemActive ? "● ACTIVE" : "● STOPPED";
    if(dailyLimitReached) status = "● LIMIT";
    color statusCol = systemActive ? clrLime : clrRed;
    CreateLabel(dashboardName + "_Status", InpDashboardX + 15, y, status, 10, statusCol, false);
    
    string strat = StringFormat("SL %.0f | TP %.0f | RR 1:%.2f",
                               currentSL, currentTP, effectiveRR);
    CreateLabel(dashboardName + "_Strat", InpDashboardX + 120, y, strat, 9, clrWhite, false);
    y += s;
    
    string st = StringFormat("ST %d/%.1f: %s | Age: %d bars",
                            InpSTPeriod, InpSTMultiplier,
                            (stEntry.direction > 0 ? "▲ BUY" : "▼ SELL"),
                            GetBarsSince(stEntry.lastChangeBar));
    color stCol = stEntry.direction > 0 ? clrLime : clrRed;
    CreateLabel(dashboardName + "_ST", InpDashboardX + 15, y, st, 9, stCol, false);
    y += s;
    
    if(InpUseMicroTrend) {
        string mt = StringFormat("Micro: %s %.0f%% | Vel: %.1f | Mom: %.2f%%",
                                microTrend.direction == 1 ? "▲" : 
                                microTrend.direction == -1 ? "▼" : "→",
                                microTrend.strength,
                                microTrend.velocity,
                                microTrend.momentum);
        color mtCol = microTrend.direction == 1 ? clrLime : 
                     microTrend.direction == -1 ? clrRed : clrYellow;
        CreateLabel(dashboardName + "_MT", InpDashboardX + 15, y, mt, 9, mtCol, false);
        y += s;
    }
    
    string qf = StringFormat("Quality: %.0f/100 %s | Vol: %.2f%% | Spread: %.0f",
                            quality.total,
                            quality.tradeable ? "✓" : "✗",
                            cached_volatility,
                            cached_spread_points);
    CreateLabel(dashboardName + "_QF", InpDashboardX + 15, y, qf, 9,
               quality.tradeable ? clrLime : clrOrange, false);
    y += s + 5;
    
    CreateLabel(dashboardName + "_Sep1", InpDashboardX + 15, y,
               "─────────────────────────────────────", 8, clrGray, false);
    y += s;
    
    int openPos = CountOpenPositions();
    double currentPL = 0;
    
    int total = PositionsTotal();
    for(int i = 0; i < total; i++) {
        ulong ticket = PositionGetTicket(i);
        if(position.SelectByTicket(ticket)) {
            if(position.Symbol() == _Symbol && position.Magic() == InpMagicNumber) {
                currentPL += position.Profit() + position.Swap() + position.Commission();
            }
        }
    }
    
    string pos = StringFormat("Position: %d | P&L: $%.2f", openPos, currentPL);
    CreateLabel(dashboardName + "_Pos", InpDashboardX + 15, y, pos, 9,
               currentPL >= 0 ? clrLime : clrRed, false);
    y += s;
    
    double dailyPL = account.Balance() - session.dailyStartBalance;
    string daily = StringFormat("Today: %d/%d | $%.2f",
                               session.dailyTradeCount, InpMaxDailyTrades, dailyPL);
    CreateLabel(dashboardName + "_Daily", InpDashboardX + 15, y, daily, 9,
               dailyPL >= 0 ? clrLime : clrRed, false);
    y += s;
    
    string perf = StringFormat("WR: %.1f%% (%d/%d) | Net: %.1f pips",
                              stats.currentWinRate,
                              stats.winningTrades,
                              stats.totalTrades,
                              stats.totalProfitPips);
    color perfCol = stats.currentWinRate >= 50 ? clrLime : clrYellow;
    CreateLabel(dashboardName + "_Perf", InpDashboardX + 15, y, perf, 9, perfCol, false);
    y += s;
    
    double pf = (stats.totalLoss > 0) ? stats.totalProfit / stats.totalLoss : 0;
    string pfText = StringFormat("PF: %.2f | AvgW: %.1f | AvgL: %.1f",
                                pf, stats.avgWinPips, stats.avgLossPips);
    CreateLabel(dashboardName + "_PF", InpDashboardX + 15, y, pfText, 8,
               pf >= 1.5 ? clrLime : pf >= 1.0 ? clrYellow : clrRed, false);
    y += s;
    
    string bestWorst = StringFormat("Best: $%.2f | Worst: $%.2f",
                                   stats.bestTrade, stats.worstTrade);
    CreateLabel(dashboardName + "_BW", InpDashboardX + 15, y, bestWorst, 8, clrSilver, false);
    y += s;
    
    string streaks = StringFormat("Streak: %d W / %d L | Max: %d W / %d L",
                                 stats.consecutiveWins, stats.consecutiveLosses,
                                 stats.maxConsecutiveWins, stats.maxConsecutiveLosses);
    CreateLabel(dashboardName + "_Streaks", InpDashboardX + 15, y, streaks, 8, clrSilver, false);
    y += s + 5;
    
    CreateLabel(dashboardName + "_Sep2", InpDashboardX + 15, y,
               "─────────────────────────────────────", 8, clrGray, false);
    y += s;
    
    string sessionStats = StringFormat("Session: High $%.2f | Low $%.2f",
                                      session.sessionHighBalance,
                                      session.sessionLowBalance);
    CreateLabel(dashboardName + "_Session", InpDashboardX + 15, y, sessionStats, 8, clrWhite, false);
    y += s;
    
    string ddru = StringFormat("MaxDD: $%.2f | MaxRU: $%.2f",
                              session.maxDrawdown, session.maxRunup);
    CreateLabel(dashboardName + "_DDRU", InpDashboardX + 15, y, ddru, 8, clrWhite, false);
    y += s;
    
    string acc = StringFormat("Balance: $%.2f | Equity: $%.2f",
                             account.Balance(), account.Equity());
    CreateLabel(dashboardName + "_Acc", InpDashboardX + 15, y, acc, 9, clrWhite, false);
    y += s;
    
    double reqWR = 100.0 / (1.0 + effectiveRR);
    string rwr = StringFormat("Required WR: %.1f%% | Current: %.1f%%",
                             reqWR, stats.currentWinRate);
    color rwrCol = stats.currentWinRate >= reqWR ? clrLime : clrOrange;
    CreateLabel(dashboardName + "_RWR", InpDashboardX + 15, y, rwr, 8, rwrCol, false);
}

void CreateLabel(string name, int x, int y, string text, int size, color col, bool bold)
{
    if(ObjectFind(0, name) < 0) {
        ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
    }
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_COLOR, col);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
    ObjectSetString(0, name, OBJPROP_FONT, bold ? "Arial Bold" : "Segoe UI");
    ObjectSetString(0, name, OBJPROP_TEXT, text);
}

void DeleteDashboard()
{
    int total = ObjectsTotal(0, 0, -1);
    for(int i = total - 1; i >= 0; i--) {
        string obj = ObjectName(0, i, 0, -1);
        if(StringFind(obj, dashboardName) >= 0) {
            ObjectDelete(0, obj);
        }
    }
}

//+------------------------------------------------------------------+
//|                     UTILITY FUNCTIONS                           |
//+------------------------------------------------------------------+

int GetBarsSince(int targetBar)
{
    if(targetBar == 0) return 999999;
    int currentBars = Bars(_Symbol, PERIOD_CURRENT);
    return currentBars - targetBar;
}

double GetPositionProfitPips(ulong ticket)
{
    if(!position.SelectByTicket(ticket)) return 0;
    
    double openPrice = position.PriceOpen();
    double currentPrice;
    
    if(position.PositionType() == POSITION_TYPE_BUY) {
        currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        // === USA IL NUOVO SISTEMA MULTI-ASSET ===
        return PriceToPips(currentPrice - openPrice);
    } else {
        currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        // === USA IL NUOVO SISTEMA MULTI-ASSET ===
        return PriceToPips(openPrice - currentPrice);
    }
}

int CountOpenPositions()
{
    int count = 0;
    int total = PositionsTotal();
    
    for(int i = 0; i < total; i++) {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;
        
        if(position.SelectByTicket(ticket)) {
            if(position.Symbol() == _Symbol && position.Magic() == InpMagicNumber) {
                count++;
            }
        }
    }
    
    return count;
}

double CalculateVolatility()
{
    double atr[];
    if(CopyBuffer(handle_atr, 0, 0, 1, atr) <= 0) return 0;
    
    double close[];
    if(CopyClose(_Symbol, PERIOD_CURRENT, 0, 1, close) <= 0) return 0;
    
    if(close[0] <= 0) return 0;
    
    return (atr[0] / close[0]) * 100.0;
}

void CalculateAverageVolatility()
{
    int bars = Bars(_Symbol, PERIOD_CURRENT);
    if(bars < 21) return;
    
    double atr[];
    double close[];
    
    if(CopyBuffer(handle_atr, 0, 1, 20, atr) <= 0) return;
    if(CopyClose(_Symbol, PERIOD_CURRENT, 1, 20, close) <= 0) return;
    
    double totalVol = 0;
    int validBars = 0;
    
    for(int i = 0; i < 20; i++) {
        if(close[i] > 0 && atr[i] > 0) {
            totalVol += (atr[i] / close[i] * 100.0);
            validBars++;
        }
    }
    
    if(validBars > 0) {
        cached_avg_volatility = totalVol / validBars;
    }
}

void RegisterTrade()
{
    stats.lastTradeTime = TimeCurrent();
    lastTradeBar = Bars(_Symbol, PERIOD_CURRENT);
    session.dailyTradeCount++;
    session.hourlyTradeCount++;
    stats.totalTrades++;
}

void UpdateStats(double profit, double pips)
{
    if(profit > 0) {
        stats.winningTrades++;
        stats.totalProfit += profit;
        stats.consecutiveWins++;
        stats.consecutiveLosses = 0;
        
        if(stats.winningTrades > 0) {
            stats.avgWinPips = ((stats.avgWinPips * (stats.winningTrades - 1)) + pips) / stats.winningTrades;
        }
        
        if(stats.consecutiveWins > stats.maxConsecutiveWins) {
            stats.maxConsecutiveWins = stats.consecutiveWins;
        }
        if(profit > stats.bestTrade) stats.bestTrade = profit;
    } else {
        stats.losingTrades++;
        stats.totalLoss += MathAbs(profit);
        stats.consecutiveLosses++;
        stats.consecutiveWins = 0;
        
        if(stats.losingTrades > 0) {
            stats.avgLossPips = ((stats.avgLossPips * (stats.losingTrades - 1)) + MathAbs(pips)) / stats.losingTrades;
        }
        
        if(stats.consecutiveLosses > stats.maxConsecutiveLosses) {
            stats.maxConsecutiveLosses = stats.consecutiveLosses;
        }
        if(profit < stats.worstTrade) stats.worstTrade = profit;
    }
    
    stats.totalProfitPips += pips;
    
    if(stats.totalTrades > 0) {
        stats.currentWinRate = (double)stats.winningTrades / stats.totalTrades * 100;
    }
    
    double currentBalance = account.Balance();
    
    if(currentBalance > session.sessionHighBalance) {
        session.sessionHighBalance = currentBalance;
    }
    if(currentBalance < session.sessionLowBalance) {
        session.sessionLowBalance = currentBalance;
    }
    
    if(currentBalance > session.peakBalance) {
        session.peakBalance = currentBalance;
    }
    
    double currentDrawdown = session.peakBalance - currentBalance;
    if(currentDrawdown > session.maxDrawdown) {
        session.maxDrawdown = currentDrawdown;
    }
    
    double currentRunup = currentBalance - session.dailyStartBalance;
    if(currentRunup > session.maxRunup) {
        session.maxRunup = currentRunup;
    }
}

void CheckDailyLimits()
{
    CheckDailyReset();
    
    if(InpMaxDailyLoss > 0) {
        double dailyPL = account.Balance() - session.dailyStartBalance;
        if(dailyPL <= -InpMaxDailyLoss) {
            dailyLimitReached = true;
            systemActive = false;
            LogPrint(LOG_LEVEL_WARNING, "⚠️ Daily loss limit: $" + DoubleToString(dailyPL, 2));
            
            if(InpSendAlerts) {
                Alert("Lightning Scalper: Daily loss limit reached! EA stopped.");
            }
        }
    }
    
    if(session.dailyTradeCount >= InpMaxDailyTrades) {
        dailyLimitReached = true;
        LogPrint(LOG_LEVEL_WARNING, "⚠️ Daily trade limit: " + IntegerToString(session.dailyTradeCount));
    }
}

void CheckDailyReset()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    datetime today = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));
    
    if(today != session.currentDayDate) {
        ResetDailyStats();
        dailyLimitReached = false;
        systemActive = true;
        LogPrint(LOG_LEVEL_INFO, "📅 New trading day - Stats reset");
    }
    
    datetime currentHour = StringToTime(StringFormat("%04d.%02d.%02d %02d:00:00", 
                                                     dt.year, dt.mon, dt.day, dt.hour));
    if(currentHour != session.currentHourStart) {
        session.hourlyTradeCount = 0;
        session.currentHourStart = currentHour;
    }
}

void ResetDailyStats()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    session.currentDayDate = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));
    session.dailyTradeCount = 0;
    session.dailyStartBalance = account.Balance();
    session.sessionHighBalance = account.Balance();
    session.sessionLowBalance = account.Balance();
    session.maxDrawdown = 0;
    session.maxRunup = 0;
    session.peakBalance = account.Balance();
    session.hourlyTradeCount = 0;
    session.currentHourStart = TimeCurrent();
}

void ResetStats()
{
    stats.totalTrades = 0;
    stats.winningTrades = 0;
    stats.losingTrades = 0;
    stats.totalProfit = 0;
    stats.totalLoss = 0;
    stats.bestTrade = 0;
    stats.worstTrade = 0;
    stats.consecutiveWins = 0;
    stats.consecutiveLosses = 0;
    stats.maxConsecutiveWins = 0;
    stats.maxConsecutiveLosses = 0;
    stats.totalProfitPips = 0;
    stats.avgWinPips = 0;
    stats.avgLossPips = 0;
    stats.currentWinRate = 0;
    stats.lastTradeTime = 0;
}

bool ValidateInputs()
{
    if(InpLotSize <= 0) {
        LogPrint(LOG_LEVEL_ERROR, "Lot size must be > 0");
        return false;
    }
    
    if(InpFixedTakeProfit <= InpFixedStopLoss * 1.5) {
        LogPrint(LOG_LEVEL_ERROR, "TP/SL ratio too low! TP should be at least " + 
                DoubleToString(InpFixedStopLoss * 1.5, 1) + " pips");
        return false;
    }
    
    if(InpMicroThreshold <= 0) {
        LogPrint(LOG_LEVEL_ERROR, "MicroTrend threshold must be > 0");
        return false;
    }
    
    if(InpMinQuality < 0 || InpMinQuality > 100) {
        LogPrint(LOG_LEVEL_ERROR, "Quality score must be between 0 and 100");
        return false;
    }
    
    return true;
}

bool IsTradeAllowed()
{
    return (TerminalInfoInteger(TERMINAL_CONNECTED) && 
            !MQLInfoInteger(MQL_TESTER) &&
            TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) &&
            AccountInfoInteger(ACCOUNT_TRADE_ALLOWED));
}

void LogPrint(ENUM_LOG_LEVEL level, string message)
{
    if(level > InpLogLevel) return;
    
    string prefix = "";
    switch(level) {
        case LOG_LEVEL_ERROR:   prefix = "[ERROR] "; break;
        case LOG_LEVEL_WARNING: prefix = "[WARN] ";  break;
        case LOG_LEVEL_INFO:    prefix = "[INFO] ";  break;
        case LOG_LEVEL_DEBUG:   prefix = "[DEBUG] "; break;
    }
    
    Print(prefix + message);
}

//+------------------------------------------------------------------+
//|                      DEINIT                                     |
//+------------------------------------------------------------------+

void OnDeinit(const int reason)
{
    if(handle_atr != INVALID_HANDLE) IndicatorRelease(handle_atr);
    if(handle_ma_fast != INVALID_HANDLE) IndicatorRelease(handle_ma_fast);
    if(handle_ma_slow != INVALID_HANDLE) IndicatorRelease(handle_ma_slow);
    
    if(InpShowDashboard) DeleteDashboard();
    
    if(!InpKeepMarkersOnExit) {
        DeleteAllEntryMarkers();
        LogPrint(LOG_LEVEL_INFO, "🗑️ Entry markers removed from chart");
    } else {
        LogPrint(LOG_LEVEL_INFO, "📍 Entry markers kept on chart for analysis");
    }
    
    LogPrint(LOG_LEVEL_INFO, "==============================================");
    LogPrint(LOG_LEVEL_INFO, "  LIGHTNING SCALPER M5 v2.2.3 - FINAL REPORT");
    LogPrint(LOG_LEVEL_INFO, "==============================================");
    LogPrint(LOG_LEVEL_INFO, "Asset: " + g_CurrentAssetSpecs.name);
    LogPrint(LOG_LEVEL_INFO, "Total Trades: " + IntegerToString(stats.totalTrades));
    LogPrint(LOG_LEVEL_INFO, "Winners: " + IntegerToString(stats.winningTrades) + 
            " | Losers: " + IntegerToString(stats.losingTrades));
    LogPrint(LOG_LEVEL_INFO, "Win Rate: " + DoubleToString(stats.currentWinRate, 1) + "%");
    
    double pf = (stats.totalLoss > 0) ? stats.totalProfit / stats.totalLoss : 0;
    LogPrint(LOG_LEVEL_INFO, "Profit Factor: " + DoubleToString(pf, 2));
    LogPrint(LOG_LEVEL_INFO, "Avg Win: " + DoubleToString(stats.avgWinPips, 1) + " pips");
    LogPrint(LOG_LEVEL_INFO, "Avg Loss: " + DoubleToString(stats.avgLossPips, 1) + " pips");
    LogPrint(LOG_LEVEL_INFO, "Total Pips: " + DoubleToString(stats.totalProfitPips, 1));
    LogPrint(LOG_LEVEL_INFO, "Best Trade: $" + DoubleToString(stats.bestTrade, 2));
    LogPrint(LOG_LEVEL_INFO, "Worst Trade: $" + DoubleToString(stats.worstTrade, 2));
    LogPrint(LOG_LEVEL_INFO, "Max Win Streak: " + IntegerToString(stats.maxConsecutiveWins));
    LogPrint(LOG_LEVEL_INFO, "Max Loss Streak: " + IntegerToString(stats.maxConsecutiveLosses));
    LogPrint(LOG_LEVEL_INFO, "Max Drawdown: $" + DoubleToString(session.maxDrawdown, 2));
    LogPrint(LOG_LEVEL_INFO, "Max Runup: $" + DoubleToString(session.maxRunup, 2));
    LogPrint(LOG_LEVEL_INFO, "Net P&L: $" + DoubleToString(stats.totalProfit - stats.totalLoss, 2));
    LogPrint(LOG_LEVEL_INFO, "==============================================");
    LogPrint(LOG_LEVEL_INFO, "✅ LIGHTNING SCALPER v2.2.3 MULTI-ASSET STOPPED");
    LogPrint(LOG_LEVEL_INFO, "==============================================");
    
    if(InpSendAlerts) {
        Alert("Lightning Scalper v2.2.3 stopped on ", _Symbol);
    }
    
    Comment("");
}

//+------------------------------------------------------------------+
