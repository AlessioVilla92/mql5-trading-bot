//+==================================================================+
//|                                                                  |
//|   ██████╗ ██████╗ ███████╗██╗   ██╗ █████╗     ███████╗        |
//|   ██╔══██╗██╔══██╗██╔════╝██║   ██║██╔══██╗    ██╔════╝        |
//|   ██████╔╝██████╔╝█████╗  ██║   ██║███████║    █████╗          |
//|   ██╔══██╗██╔══██╗██╔══╝  ╚██╗ ██╔╝██╔══██║    ██╔══╝          |
//|   ██████╔╝██║  ██║███████╗ ╚████╔╝ ██║  ██║    ███████╗        |
//|   ╚═════╝ ╚═╝  ╚═╝╚══════╝  ╚═══╝  ╚═╝  ╚═╝    ╚══════╝        |
//|                                                                  |
//|   ████████╗██╗██╗   ██╗ █████╗ ███╗   ██╗                      |
//|   ╚══██╔══╝██║██║   ██║██╔══██╗████╗  ██║                      |
//|      ██║   ██║██║   ██║███████║██╔██╗ ██║                      |
//|      ██║   ██║╚██╗ ██╔╝██╔══██║██║╚██╗██║                      |
//|      ██║   ██║ ╚████╔╝ ██║  ██║██║ ╚████║                      |
//|      ╚═╝   ╚═╝  ╚═══╝  ╚═╝  ╚═╝╚═╝  ╚═══╝                      |
//|                                                                  |
//+==================================================================+
//|            BREVA E TIVAN - SMART GRID TRADING SYSTEM v1.3.3     |
//|                 Professional Multi-Asset EA                      |
//+------------------------------------------------------------------+
//|  Copyright © 2025 - Breva e Tivan Development Team              |
//|  Version: 1.3.3 FIXED - Close All Position Bug Fixed            |
//|  Release Date: October 2025                                      |
//+------------------------------------------------------------------+
//|  🔧 FIXES v1.3.3 FIXED:                                         |
//|  ✓ Fix bottoni bloccati dopo chiusura sistema                   |
//|  ✓ Warning parametri rimossi (solo log informativi)             |
//|  ✓ Dashboard migliorata con titolo grande                       |
//|  ✓ Grid SCOUT system con lottaggio ridotto                      |
//|  ✓ NUOVO: Close All Position cancella TUTTI gli ordini pending  |
//|  ✓ NUOVO: Close All funziona in qualsiasi stato del sistema     |
//+------------------------------------------------------------------+
//|  FEATURES:                                                       |
//|  ✓ Universal: FOREX | INDICES | CRYPTO                          |
//|  ✓ Dual Control: BUY/SELL with MARKET/LIMIT/STOP               |
//|  ✓ Zero-Spread Grid: Pending STOP orders                        |
//|  ✓ Trailing Protection: Dynamic grid adjustment                 |
//|  ✓ Cooldown System: Broker overload protection                  |
//|  ✓ Visual Dashboard: Real-time monitoring                       |
//|  ✓ Smart Validation: Multi-layer risk management                |
//|  ✓ Complete System Reset: Close ALL positions & pending orders  |
//+------------------------------------------------------------------+
#property copyright "Breva e Tivan © 2025"
#property link      "https://breva-tivan.com"
#property version   "1.33"
#property description "Professional Multi-Asset Grid Trading System"
#property description "FOREX | INDICES | CRYPTO | Universal Support"
#property strict

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| ENUMERAZIONI                                                      |
//+------------------------------------------------------------------+
enum ENUM_DIRECTION {
    LONG,           // Long (Buy) - Acquisto
    SHORT           // Short (Sell) - Vendita
};

enum ENUM_LOT_MODE {
    STANDARD,       // Standard - Volume Fisso
    PROGRESSION,    // Progression - Incremento Lineare
    SCOUT_SYSTEM    // Scout System - Grid 1 ridotto, poi standard
};

enum ENUM_SYSTEM_STATE {
    STATE_IDLE, STATE_MAIN_OPENING, STATE_MAIN_OPEN,
    STATE_GRID_ACTIVE, STATE_CLOSING, STATE_ERROR
};

enum ENUM_GRID_ORDER_TYPE {
    GRID_MARKET,    // Grid con ordini Market
    GRID_PENDING    // Grid con ordini Pending (ZERO SPREAD!)
};

enum ENUM_INSTRUMENT_TYPE {
    FOREX,          // 1. Forex (EUR/USD, GBP/USD, etc)
    INDICES,        // 2. Indices (US30, NAS100, etc)
    CRYPTO          // 3. Crypto (BTC/USD, ETH/USD, etc)
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - VERSIONE 1.3.3 FIXED                          |
//+------------------------------------------------------------------+
input group "══════════ 🎯 STRUMENTO & ORDINE PRINCIPALE ══════════"

input ENUM_INSTRUMENT_TYPE InstrumentType = CRYPTO;
// FOREX: Pips standard (0.0001 o 0.001 JPY)
// INDICES: Punti indice (1.0 o 0.1)
// CRYPTO: Dollari/Euro (0.01 o 0.10)

input double MainLotSize = 1.0;                         
// Volume in lotti (0.01=micro, 0.1=mini, 1.0=standard)

input int MainTakeProfitPips = 100;                     
// Take Profit in pips/punti dal prezzo entry
// FOREX: 100 pips | INDICES: 100 punti | CRYPTO: $100

input group "══════════ 📍 ORDINI LIMIT/STOP ══════════"
input int LimitOffsetPips = 3;
// FOREX: 2-5 pips | INDICES: 5-10 | CRYPTO: 10-20

input int StopOffsetPips = 5;
// FOREX: 5-10 pips | INDICES: 10-20 | CRYPTO: 20-50

input int LimitTimeoutSeconds = 300;
// Timeout ordini pending (secondi). 0 = infinito

input bool AutoRetryLimit = true;
// Riprova automaticamente se pending non eseguito

input int MaxLimitRetries = 3;
// Numero massimo tentativi riposizionamento

input group "══════════ 🛡️ GRID HEDGING - FOREX ══════════"
input int GridActivationPips_FOREX = 20;
// Raccomandato: 15-30 pips per EUR/USD, GBP/USD

input int GridSpacing_FOREX = 15;
// Raccomandato: 10-20 pips (calmo) | 20-40 (volatile)

input int GridTakeProfitPips_FOREX = 25;
// Raccomandato: 1.5-2x GridSpacing

input int FirstGridStopLoss_FOREX = 30;
// Raccomandato: 20-40 pips (UNICO rischio reale)

input group "══════════ 🛡️ GRID HEDGING - INDICES ══════════"
input int GridActivationPips_INDICES = 50;
// Raccomandato: 40-80 punti per US30, NAS100

input int GridSpacing_INDICES = 35;
// Raccomandato: 25-50 punti

input int GridTakeProfitPips_INDICES = 60;
// Raccomandato: 1.5-2x GridSpacing

input int FirstGridStopLoss_INDICES = 80;
// Raccomandato: 60-120 punti

input group "══════════ 🛡️ GRID HEDGING - CRYPTO ══════════"
input int GridActivationPips_CRYPTO = 120;
// Raccomandato: 100-150 per BTC/USD | 50-80 per ETH/USD

input int GridSpacing_CRYPTO = 90;
// Raccomandato: 70-110 per BTC | 40-60 per ETH

input int GridTakeProfitPips_CRYPTO = 130;
// Raccomandato: 1.2-1.5x GridSpacing

input int FirstGridStopLoss_CRYPTO = 200;
// Raccomandato: 150-250 per BTC | 80-120 per ETH

input group "══════════ 🛡️ GRID SETTINGS COMUNI ══════════"
input ENUM_GRID_ORDER_TYPE GridOrderType = GRID_PENDING;
// MARKET: Ordini immediati (spread pieno)
// PENDING: Ordini STOP (ZERO SPREAD!)

input int MaxGridLevels = 7;
// Numero massimo livelli grid (2-10)

input group "══════════ 🚀 TRAILING GRID ══════════"
input bool EnableTrailingGrid = true;
// Grid segue profitto verso breakeven

input int TrailingStartPips = 30;
// FOREX: 20-40 | INDICES: 50-80 | CRYPTO: 80-120

input int TrailingStepPips = 10;
// FOREX: 5-15 | INDICES: 15-30 | CRYPTO: 30-50

input int TrailingMinDistance = 15;
// FOREX: 10-20 | INDICES: 25-40 | CRYPTO: 50-80

input bool TrailToBreakeven = true;
// Permetti grid arrivare fino a entry price

input group "══════════ ⏱️ COOLDOWN SYSTEM ══════════"
input bool EnableCooldown = true;
// Attiva sistema cooldown per protezione broker

input int CooldownUpSeconds = 15;
// Cooldown dopo trailing UP (secondi)

input int CooldownDownSeconds = 10;
// Cooldown dopo nuovo grid level DOWN

input group "══════════ 💰 GESTIONE LOT SIZE ══════════"
input ENUM_LOT_MODE LotSizeMode = SCOUT_SYSTEM;
// STANDARD: Volume fisso tutti grid
// PROGRESSION: Incremento lineare
// SCOUT_SYSTEM: Grid 1 ridotto (SCOUT), poi standard

input double StandardLotSize = 0.02;
// [STANDARD] Volume fisso grid

input double ProgressionStartLot = 0.1;
// [PROGRESSION] Volume iniziale

input double ProgressionIncrement = 0.1;
// [PROGRESSION] Incremento per livello

input double ProgressionMaxLot = 1.0;
// [PROGRESSION] Cap massimo volume

input double ScoutLotSize = 0.01;
// [SCOUT_SYSTEM] Volume ridotto SOLO per Grid 1
// Raccomandato: 1/100 del MainLotSize

input group "══════════ 🔐 PROTEZIONE ACCOUNT ══════════"
input int MagicNumber = 987654;
// ID univoco EA

input int Slippage = 3;
// Slippage massimo accettabile (pips)

input bool EnableEmergencyStop = true;
// Stop emergenza automatico

input double EmergencyStopPercent = 35.0;
// Drawdown % per emergency stop

input group "══════════ 🎨 GRAFICA ══════════"
input color MainLineColor = clrDodgerBlue;
input color GridLineColor = clrOrange;
input color GridPendingColor = clrRed;
input color GridFilledColor = clrCrimson;
input color TPLineColor = clrLime;
input color TPMarkerColor = clrLimeGreen;
input color SLMarkerColor = clrDodgerBlue;
input color PanelBackColor = clrDarkSlateGray;
input color PanelTextColor = clrWhite;

input group "══════════ 🔔 ALERT & LOGGING ══════════"
input bool EnableAlerts = true;
// Alert popup per eventi importanti

input bool EnablePushNotifications = false;
// Notifiche push su mobile

input bool DetailedLogging = true;
// Log dettagliato operazioni

//+------------------------------------------------------------------+
//| VARIABILI GLOBALI                                                 |
//+------------------------------------------------------------------+
CTrade trade;

ENUM_SYSTEM_STATE currentState = STATE_IDLE;
bool systemActive = false;
datetime systemStartTime = 0;

// Parametri attivi (selezionati da instrument type)
int ActiveGridActivationPips = 0;
int ActiveGridSpacing = 0;
int ActiveGridTakeProfitPips = 0;
int ActiveFirstGridStopLoss = 0;

// Pending order management
ulong pendingOrderTicket = 0;
datetime pendingOrderTime = 0;
int pendingRetryCount = 0;
ENUM_DIRECTION pendingDirection = LONG;
string pendingOrderType = "";

// Main position
ulong mainTicket = 0;
double mainOpenPrice = 0;
double mainCurrentProfit = 0;
double mainTakeProfit = 0;
ENUM_DIRECTION mainDirection = LONG;

// Grid state
bool gridActive = false;
int currentGridLevel = 0;
ulong gridTickets[20];
ulong gridPendingTickets[20];
double gridOpenPrices[20];
double gridLotSizes[20];
double gridTakeProfits[20];
double gridStopLosses[20];
datetime gridOpenTimes[20];
bool gridIsFilled[20];
double currentGridTP = 0;

// Trailing grid
double trailedActivationPrice = 0;
double lastTrailedPrice = 0;
bool trailingActive = false;

// Cooldown system
bool cooldownActive = false;
datetime cooldownEndTime = 0;
string cooldownType = "";

// Performance
double totalGridProfit = 0;
double totalSystemProfit = 0;
double maxDrawdown = 0;
double currentDrawdown = 0;

// Weighted average
double priceTimesSizeSummation = 0;
double totalLotSizeSummation = 0;
double weightedAvgPrice = 0;

// Stats
int totalGridCycles = 0;
int totalGridOrders = 0;
int totalTrailingShifts = 0;
int totalPendingCanceled = 0;
int pendingOrdersCount = 0;
int filledOrdersCount = 0;

//+------------------------------------------------------------------+
//| Conversione Pips universale                                      |
//+------------------------------------------------------------------+
double PipsToPoints(double pips) {
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    
    switch(InstrumentType) {
        case FOREX:
            if(digits == 5 || digits == 3) {
                return pips * _Point * 10;
            }
            else if(digits == 4 || digits == 2) {
                return pips * _Point * 100;
            }
            return pips * _Point * 10;
            
        case INDICES:
            if(digits == 1) {
                return pips * _Point * 10;
            } else if(digits == 2) {
                return pips * _Point;
            }
            return pips * _Point;
            
        case CRYPTO:
            if(digits == 2) {
                return pips * _Point * 100;
            }
            else if(digits >= 3 && digits <= 4) {
                return pips * _Point * 10;
            }
            else if(digits >= 5) {
                return pips * _Point;
            }
            return pips * _Point * 10;
    }
    
    return pips * _Point * 10;
}

//+------------------------------------------------------------------+
//| Selezione parametri in base a strumento                          |
//+------------------------------------------------------------------+
void SelectActiveParameters() {
    switch(InstrumentType) {
        case FOREX:
            ActiveGridActivationPips = GridActivationPips_FOREX;
            ActiveGridSpacing = GridSpacing_FOREX;
            ActiveGridTakeProfitPips = GridTakeProfitPips_FOREX;
            ActiveFirstGridStopLoss = FirstGridStopLoss_FOREX;
            break;
            
        case INDICES:
            ActiveGridActivationPips = GridActivationPips_INDICES;
            ActiveGridSpacing = GridSpacing_INDICES;
            ActiveGridTakeProfitPips = GridTakeProfitPips_INDICES;
            ActiveFirstGridStopLoss = FirstGridStopLoss_INDICES;
            break;
            
        case CRYPTO:
            ActiveGridActivationPips = GridActivationPips_CRYPTO;
            ActiveGridSpacing = GridSpacing_CRYPTO;
            ActiveGridTakeProfitPips = GridTakeProfitPips_CRYPTO;
            ActiveFirstGridStopLoss = FirstGridStopLoss_CRYPTO;
            break;
    }
    
    if(DetailedLogging) {
        Print("═══ PARAMETRI ATTIVI ═══");
        Print("Tipo: ", EnumToString(InstrumentType));
        Print("Grid Activation: ", ActiveGridActivationPips, " pips");
        Print("Grid Spacing: ", ActiveGridSpacing, " pips");
        Print("Grid TP: ", ActiveGridTakeProfitPips, " pips");
        Print("First Grid SL: ", ActiveFirstGridStopLoss, " pips");
    }
}

//+------------------------------------------------------------------+
//| 🆕 Validazione parametri SENZA WARNING POPUP                     |
//+------------------------------------------------------------------+
bool ValidateInstrumentParameters() {
    string info = "";
    
    int minStopLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    double minDistance = minStopLevel * _Point;
    double minDistancePips = minDistance / PipsToPoints(1);
    
    // Log informativo (NO warning, NO alert)
    switch(InstrumentType) {
        case FOREX:
            if(ActiveGridActivationPips < 10) {
                info += "💡 INFO: GridActivation " + IntegerToString(ActiveGridActivationPips) + 
                       " pips è basso per FOREX (raccomandato 15-30)\n";
            }
            if(ActiveGridSpacing < 8) {
                info += "💡 INFO: GridSpacing " + IntegerToString(ActiveGridSpacing) + 
                       " pips è stretto per FOREX (raccomandato 10-20)\n";
            }
            break;
            
        case INDICES:
            if(ActiveGridActivationPips < 30) {
                info += "💡 INFO: GridActivation " + IntegerToString(ActiveGridActivationPips) + 
                       " punti è basso per INDICES (raccomandato 40-80)\n";
            }
            if(ActiveGridSpacing < 20) {
                info += "💡 INFO: GridSpacing " + IntegerToString(ActiveGridSpacing) + 
                       " punti è stretto per INDICES (raccomandato 25-50)\n";
            }
            break;
            
        case CRYPTO:
            if(ActiveGridActivationPips < 80) {
                info += "💡 INFO: GridActivation " + IntegerToString(ActiveGridActivationPips) + 
                       " pips è basso per CRYPTO (raccomandato 100-150)\n";
            }
            if(ActiveGridSpacing < 50) {
                info += "💡 INFO: GridSpacing " + IntegerToString(ActiveGridSpacing) + 
                       " pips è stretto per CRYPTO (raccomandato 70-110)\n";
            }
            break;
    }
    
    // Check broker minimum
    if(ActiveGridActivationPips < minDistancePips) {
        info += StringFormat("💡 INFO: GridActivation (%.0f) < Broker Min (%.0f pips)\n", 
                            ActiveGridActivationPips, minDistancePips);
    }
    
    if(ActiveGridSpacing < minDistancePips) {
        info += StringFormat("💡 INFO: GridSpacing (%.0f) < Broker Min (%.0f pips)\n", 
                            ActiveGridSpacing, minDistancePips);
    }
    
    // Mostra info solo nel log (NO popup, NO blocco)
    if(info != "") {
        Print("╔════════════════════════════════════════════════════════════╗");
        Print("║  💡 INFORMAZIONI PARAMETRI                                 ║");
        Print("╚════════════════════════════════════════════════════════════╝");
        Print(info);
        Print("Sistema continuerà normalmente. Modifica parametri se necessario.");
    }
    
    return true;  // Sempre TRUE - non blocca mai
}

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit() {
    Print("╔════════════════════════════════════════════════════════════╗");
    Print("║  BREVA E TIVAN v1.3.3 FIXED - SMART GRID TRADING SYSTEM   ║");
    Print("║  Professional Multi-Asset EA - INIZIALIZZAZIONE           ║");
    Print("╚════════════════════════════════════════════════════════════╝");
    
    SelectActiveParameters();
    
    trade.SetExpertMagicNumber(MagicNumber);
    trade.SetDeviationInPoints(Slippage);
    trade.SetTypeFilling(ORDER_FILLING_FOK);
    trade.SetAsyncMode(false);
    
    if(AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING) {
        Alert("⚠️ Account deve essere HEDGING mode!");
        Print("⚠️ ERRORE: Account non in modalità HEDGING");
        return(INIT_FAILED);
    }
    
    ArrayInitialize(gridTickets, 0);
    ArrayInitialize(gridPendingTickets, 0);
    ArrayInitialize(gridOpenPrices, 0);
    ArrayInitialize(gridLotSizes, 0);
    ArrayInitialize(gridTakeProfits, 0);
    ArrayInitialize(gridStopLosses, 0);
    ArrayInitialize(gridOpenTimes, 0);
    ArrayInitialize(gridIsFilled, false);
    
    CreateDashboard();
    CreateDualControlButtons();
    
    ValidateInstrumentParameters();
    
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    double point = _Point;
    double pipValue = PipsToPoints(1);
    
    Print("═══ CONFIGURAZIONE SISTEMA ═══");
    Print("✅ EA: Breva e Tivan v1.3.3 FIXED");
    Print("📊 Symbol: ", _Symbol);
    Print("🎯 Instrument: ", EnumToString(InstrumentType));
    Print("🔢 Decimals: ", digits);
    Print("📏 Point: ", point);
    Print("📐 1 Pip = ", pipValue, " points");
    Print("⚙️ Magic: ", MagicNumber);
    Print("🛡️ Grid Type: ", GridOrderType == GRID_PENDING ? "PENDING (Zero Spread!)" : "MARKET");
    Print("⏱️ Cooldown: ", EnableCooldown ? "ATTIVO" : "OFF");
    Print("💰 Lot Mode: ", EnumToString(LotSizeMode));
    if(LotSizeMode == SCOUT_SYSTEM) {
        Print("🔍 Scout Lot: ", ScoutLotSize, " (Grid 1 only)");
    }
    Print("🎛️ Control: BUY/SELL Dual Dashboard");
    Print("🔴 Close All: Cancella TUTTI gli ordini pending + posizioni");
    
    Print("\n═══ PARAMETRI GRID ATTIVI ═══");
    Print("Activation: ", ActiveGridActivationPips, " pips (", PipsToPoints(ActiveGridActivationPips), " points)");
    Print("Spacing: ", ActiveGridSpacing, " pips (", PipsToPoints(ActiveGridSpacing), " points)");
    Print("TP: ", ActiveGridTakeProfitPips, " pips (", PipsToPoints(ActiveGridTakeProfitPips), " points)");
    Print("First SL: ", ActiveFirstGridStopLoss, " pips (", PipsToPoints(ActiveFirstGridStopLoss), " points)");
    Print("Max Levels: ", MaxGridLevels);
    
    Print("\n✅ INIZIALIZZAZIONE COMPLETATA\n");
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    Print("╔════════════════════════════════════════════════════════════╗");
    Print("║  BREVA E TIVAN v1.3.3 FIXED - DEINIZIALIZZAZIONE          ║");
    Print("╚════════════════════════════════════════════════════════════╝");
    
    RemoveAllObjects();
    
    if(systemActive) {
        SaveSessionStatistics("EA Removed");
    }
    
    string reasonText = "";
    switch(reason) {
        case REASON_PROGRAM: reasonText = "EA stopped manually"; break;
        case REASON_REMOVE: reasonText = "EA removed from chart"; break;
        case REASON_RECOMPILE: reasonText = "EA recompiled"; break;
        case REASON_CHARTCHANGE: reasonText = "Symbol/timeframe changed"; break;
        case REASON_CHARTCLOSE: reasonText = "Chart closed"; break;
        case REASON_PARAMETERS: reasonText = "Input parameters changed"; break;
        case REASON_ACCOUNT: reasonText = "Account changed"; break;
        default: reasonText = "Unknown reason";
    }
    
    Print("Reason: ", reasonText);
    Print("═══ SHUTDOWN COMPLETED ═══\n");
    
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick() {
    if(currentState == STATE_MAIN_OPENING && pendingOrderTicket > 0) {
        CheckPendingMainOrderStatus();
        return;
    }
    
    if(!systemActive) return;
    
    if(EnableCooldown && cooldownActive) {
        if(TimeCurrent() >= cooldownEndTime) {
            cooldownActive = false;
            if(DetailedLogging) {
                Print("⏱️ Cooldown ", cooldownType, " terminato");
            }
        }
    }
    
    UpdateSystemMetrics();
    
    if(GridOrderType == GRID_PENDING && gridActive) {
        CheckPendingOrdersStatus();
    }
    
    switch(currentState) {
        case STATE_MAIN_OPEN:
            MonitorMainPosition();
            
            if(EnableTrailingGrid && !cooldownActive) {
                UpdateTrailingGrid();
            }
            
            CheckGridActivation();
            CheckMainTakeProfit();
            break;
            
        case STATE_GRID_ACTIVE:
            MonitorMainPosition();
            
            if(EnableTrailingGrid && !cooldownActive) {
                UpdateTrailingGrid();
            }
            
            CheckNewGridLevel();
            CheckGridClosures();
            CheckMainTakeProfit();
            break;
    }
    
    if(EnableEmergencyStop) {
        CheckEmergencyStop();
    }
    
    UpdateDashboard();
}

//+------------------------------------------------------------------+
//| Chart event handler                                               |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
    if(id == CHARTEVENT_OBJECT_CLICK) {
        HandleButtonClick(sparam);
    }
    
    if(id == CHARTEVENT_OBJECT_DRAG) {
        HandleObjectDrag(sparam);
    }
}

//+------------------------------------------------------------------+
//| 🔧 FIX: Button click handler con reset immediato                 |
//+------------------------------------------------------------------+
void HandleButtonClick(string clickedObject) {
    // 🔧 FIX: Reset bottone PRIMA di qualsiasi operazione
    ObjectSetInteger(0, clickedObject, OBJPROP_STATE, false);
    ChartRedraw();
    
    // BUY BUTTONS
    if(clickedObject == "BTN_BUY_MARKET") {
        if(currentState != STATE_IDLE) {
            Print("⚠️ Sistema già attivo - ignorato click");
            return;
        }
        
        Print("🟢 BUY MARKET richiesto");
        InitializeSystem(LONG, "MARKET");
        return;
    }
    
    if(clickedObject == "BTN_BUY_LIMIT") {
        if(currentState != STATE_IDLE) {
            Print("⚠️ Sistema già attivo - ignorato click");
            return;
        }
        
        Print("🟢 BUY LIMIT richiesto");
        InitializeSystem(LONG, "LIMIT");
        return;
    }
    
    if(clickedObject == "BTN_BUY_STOP") {
        if(currentState != STATE_IDLE) {
            Print("⚠️ Sistema già attivo - ignorato click");
            return;
        }
        
        Print("🟢 BUY STOP richiesto");
        InitializeSystem(LONG, "STOP");
        return;
    }
    
    // SELL BUTTONS
    if(clickedObject == "BTN_SELL_MARKET") {
        if(currentState != STATE_IDLE) {
            Print("⚠️ Sistema già attivo - ignorato click");
            return;
        }
        
        Print("🔴 SELL MARKET richiesto");
        InitializeSystem(SHORT, "MARKET");
        return;
    }
    
    if(clickedObject == "BTN_SELL_LIMIT") {
        if(currentState != STATE_IDLE) {
            Print("⚠️ Sistema già attivo - ignorato click");
            return;
        }
        
        Print("🔴 SELL LIMIT richiesto");
        InitializeSystem(SHORT, "LIMIT");
        return;
    }
    
    if(clickedObject == "BTN_SELL_STOP") {
        if(currentState != STATE_IDLE) {
            Print("⚠️ Sistema già attivo - ignorato click");
            return;
        }
        
        Print("🔴 SELL STOP richiesto");
        InitializeSystem(SHORT, "STOP");
        return;
    }
    
    // CLOSE ALL - 🔧 FIXED: Funziona sempre, anche con pending orders
    if(clickedObject == "BTN_CLOSE_ALL") {
        Print("🔴 CLOSE ALL POSITIONS richiesto");
        CloseEntireSystem("User Manual Close");
        return;
    }
}

//+------------------------------------------------------------------+
//| Object drag handler                                               |
//+------------------------------------------------------------------+
void HandleObjectDrag(string draggedObj) {
    if(StringFind(draggedObj, "TP_LINE") >= 0) {
        double newPrice = ObjectGetDouble(0, draggedObj, OBJPROP_PRICE, 0);
        
        if(draggedObj == "GRID_TP_LINE") {
            double oldTP = currentGridTP;
            currentGridTP = MathAbs(newPrice - mainOpenPrice);
            UpdateGridTakeProfits(currentGridTP);
            Print("📊 Grid TP: ", oldTP/_Point/10, " → ", currentGridTP/_Point/10, " pips");
        }
        
        if(draggedObj == "MAIN_TP_LINE") {
            mainTakeProfit = newPrice;
            UpdateMainTakeProfit(newPrice);
        }
        
        ChartRedraw();
    }
}

//+------------------------------------------------------------------+
//| System initialization                                             |
//+------------------------------------------------------------------+
bool InitializeSystem(ENUM_DIRECTION direction, string orderType) {
    if(!ValidateSystemStart()) {
        Print("❌ Validazione fallita - Sistema non avviato");
        return false;
    }
    
    Print("╔════════════════════════════════════════════════════════════╗");
    Print("║  INIZIALIZZAZIONE TRADING SYSTEM                           ║");
    Print("╚════════════════════════════════════════════════════════════╝");
    Print("📊 Direction: ", EnumToString(direction));
    Print("📍 Order Type: ", orderType);
    Print("🎯 Instrument: ", EnumToString(InstrumentType));
    
    currentState = STATE_MAIN_OPENING;
    mainDirection = direction;
    pendingDirection = direction;
    pendingOrderType = orderType;
    
    double entryPrice = 0;
    ENUM_ORDER_TYPE mtOrderType = direction == LONG ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    
    double currentPrice = direction == LONG ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK) :
                         SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    if(orderType == "MARKET") {
        entryPrice = currentPrice;
        mtOrderType = direction == LONG ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
        Print("📍 MARKET @ ", entryPrice);
    }
    else if(orderType == "LIMIT") {
        double offset = PipsToPoints(LimitOffsetPips);
        
        if(direction == LONG) {
            entryPrice = currentPrice - offset;
            mtOrderType = ORDER_TYPE_BUY_LIMIT;
        } else {
            entryPrice = currentPrice + offset;
            mtOrderType = ORDER_TYPE_SELL_LIMIT;
        }
        Print("📍 LIMIT @ ", entryPrice, " (offset ", LimitOffsetPips, " pips = ", offset, " points)");
    }
    else if(orderType == "STOP") {
        double offset = PipsToPoints(StopOffsetPips);
        
        if(direction == LONG) {
            entryPrice = currentPrice + offset;
            mtOrderType = ORDER_TYPE_BUY_STOP;
        } else {
            entryPrice = currentPrice - offset;
            mtOrderType = ORDER_TYPE_SELL_STOP;
        }
        Print("📍 STOP @ ", entryPrice, " (offset ", StopOffsetPips, " pips = ", offset, " points)");
    }
    
    mainTakeProfit = CalculateMainTP(entryPrice, direction);
    
    bool result = false;
    
    if(mtOrderType == ORDER_TYPE_BUY_LIMIT || mtOrderType == ORDER_TYPE_SELL_LIMIT ||
       mtOrderType == ORDER_TYPE_BUY_STOP || mtOrderType == ORDER_TYPE_SELL_STOP) {
        
        result = trade.OrderOpen(_Symbol, mtOrderType, MainLotSize, 0, entryPrice, 
                                0, mainTakeProfit, ORDER_TIME_GTC, 0, "BREVA-TIVAN-MAIN");
        
        if(result) {
            pendingOrderTicket = trade.ResultOrder();
            pendingOrderTime = TimeCurrent();
            pendingRetryCount = 0;
            Print("✅ Pending order piazzato: #", pendingOrderTicket);
            return true;
        }
    }
    else {
        result = trade.PositionOpen(_Symbol, mtOrderType, MainLotSize, entryPrice, 
                                   0, mainTakeProfit, "BREVA-TIVAN-MAIN");
        
        if(result) {
            CompleteSystemActivation(entryPrice);
            return true;
        }
    }
    
    if(!result) {
        string errorDesc = trade.ResultRetcodeDescription();
        uint errorCode = trade.ResultRetcode();
        Print("❌ Errore apertura posizione:");
        Print("   Code: ", errorCode);
        Print("   Description: ", errorDesc);
        
        currentState = STATE_ERROR;
        Sleep(2000);
        currentState = STATE_IDLE;
        
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check pending main order status                                  |
//+------------------------------------------------------------------+
void CheckPendingMainOrderStatus() {
    if(PositionSelectByTicket(pendingOrderTicket)) {
        double fillPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        Print("✅ Pending order ESEGUITO @ ", fillPrice);
        CompleteSystemActivation(fillPrice);
        return;
    }
    
    if(OrderSelect(pendingOrderTicket)) {
        if(LimitTimeoutSeconds > 0) {
            int elapsed = (int)(TimeCurrent() - pendingOrderTime);
            
            if(elapsed >= LimitTimeoutSeconds) {
                Print("⏱️ Pending timeout (", elapsed, "s)");
                trade.OrderDelete(pendingOrderTicket);
                
                if(AutoRetryLimit && pendingRetryCount < MaxLimitRetries) {
                    pendingRetryCount++;
                    Print("🔄 Retry ", pendingRetryCount, "/", MaxLimitRetries);
                    pendingOrderTicket = 0;
                    InitializeSystem(pendingDirection, pendingOrderType);
                } else {
                    Alert("⚠️ Pending non eseguito dopo ", MaxLimitRetries, " tentativi");
                    currentState = STATE_IDLE;
                    pendingOrderTicket = 0;
                }
            }
        }
        return;
    }
    
    Print("⚠️ Pending order perso/cancellato");
    currentState = STATE_IDLE;
    pendingOrderTicket = 0;
}

//+------------------------------------------------------------------+
//| Complete system activation                                        |
//+------------------------------------------------------------------+
void CompleteSystemActivation(double fillPrice) {
    mainTicket = PositionGetInteger(POSITION_TICKET);
    mainOpenPrice = fillPrice;
    systemActive = true;
    systemStartTime = TimeCurrent();
    currentState = STATE_MAIN_OPEN;
    pendingOrderTicket = 0;
    
    priceTimesSizeSummation = mainOpenPrice * MainLotSize;
    totalLotSizeSummation = MainLotSize;
    
    currentGridTP = PipsToPoints(ActiveGridTakeProfitPips);
    trailedActivationPrice = 0;
    lastTrailedPrice = 0;
    trailingActive = false;
    
    DrawMainPositionLine();
    DrawTakeProfitLines();
    
    if(GridOrderType == GRID_PENDING) {
        PlaceInitialGridPendingOrders();
    } else {
        DrawPredictedGridLevels();
    }
    
    Print("╔════════════════════════════════════════════════════════════╗");
    Print("║  ✅ SISTEMA ATTIVO - TRADING INIZIATO                     ║");
    Print("╚════════════════════════════════════════════════════════════╝");
    Print("📊 Main ", EnumToString(mainDirection), " @ ", mainOpenPrice);
    Print("🎯 TP: ", mainTakeProfit);
    Print("🛡️ Grid Type: ", GridOrderType == GRID_PENDING ? "PENDING" : "MARKET");
    
    if(EnableAlerts) {
        Alert("✅ BREVA E TIVAN - ", EnumToString(mainDirection), " Attivato!");
    }
}

//+------------------------------------------------------------------+
//| Place initial grid pending orders                                |
//+------------------------------------------------------------------+
void PlaceInitialGridPendingOrders() {
    Print("╔════════════════════════════════════════════════════════════╗");
    Print("║  PIAZZAMENTO GRID PENDING ORDERS                           ║");
    Print("╚════════════════════════════════════════════════════════════╝");
    
    double activationBase = mainOpenPrice + (mainDirection == LONG ? 
                           -PipsToPoints(ActiveGridActivationPips) : 
                           PipsToPoints(ActiveGridActivationPips));
    
    Print("Main Entry: ", mainOpenPrice);
    Print("Grid Activation: ", activationBase);
    Print("Distance: ", ActiveGridActivationPips, " pips = ", 
          MathAbs(activationBase - mainOpenPrice), " points");
    
    int successCount = 0;
    int failCount = 0;
    
    for(int i = 1; i <= MaxGridLevels; i++) {
        double levelPrice = 0;
        if(mainDirection == LONG) {
            levelPrice = activationBase - ((i-1) * PipsToPoints(ActiveGridSpacing));
        } else {
            levelPrice = activationBase + ((i-1) * PipsToPoints(ActiveGridSpacing));
        }
        
        if(PlaceGridPendingOrder(i, levelPrice)) {
            successCount++;
        } else {
            failCount++;
        }
    }
    
    Print("═══ RISULTATO PIAZZAMENTO ═══");
    Print("✅ Successo: ", successCount, "/", MaxGridLevels);
    if(failCount > 0) {
        Print("❌ Falliti: ", failCount);
    }
    
    pendingOrdersCount = successCount;
    
    if(successCount > 0 && EnableAlerts) {
        Alert("📊 Grid Pending: ", successCount, " ordini pronti (ZERO SPREAD!)");
    }
}

//+------------------------------------------------------------------+
//| Place single grid pending order                                  |
//+------------------------------------------------------------------+
bool PlaceGridPendingOrder(int level, double price) {
    ENUM_ORDER_TYPE orderType = mainDirection == LONG ? ORDER_TYPE_SELL_STOP : ORDER_TYPE_BUY_STOP;
    
    double lotSize = CalculateGridLotSize(level);
    double stopLoss = (level == 1) ? CalculateGridStopLoss(price, orderType) : 0;
    double takeProfit = CalculateGridTP(price, orderType);
    
    double currentPrice = mainDirection == LONG ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) :
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    int minStopLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    double minDistance = minStopLevel * _Point;
    double actualDistance = MathAbs(price - currentPrice);
    
    if(minStopLevel > 0 && actualDistance < minDistance) {
        Print("💡 INFO: Grid L", level, " skip (distance ", actualDistance, " < min ", minDistance, ")");
        return false;
    }
    
    string comment = "BREVA-GRID-PENDING-L" + IntegerToString(level);
    
    if(trade.OrderOpen(_Symbol, orderType, lotSize, 0, price, stopLoss, takeProfit, 
                      ORDER_TIME_GTC, 0, comment)) {
        ulong ticket = trade.ResultOrder();
        gridPendingTickets[level-1] = ticket;
        gridOpenPrices[level-1] = price;
        gridLotSizes[level-1] = lotSize;
        gridTakeProfits[level-1] = takeProfit;
        gridStopLosses[level-1] = stopLoss;
        gridIsFilled[level-1] = false;
        
        DrawGridPendingLevel(level, price, takeProfit, stopLoss);
        
        if(DetailedLogging) {
            Print("✅ Grid L", level, " PENDING @ ", price, " | Lot: ", lotSize);
        }
        
        return true;
    } else {
        Print("💡 INFO: Grid L", level, " fallito: ", trade.ResultRetcodeDescription());
        return false;
    }
}

//+------------------------------------------------------------------+
//| Check pending orders status                                      |
//+------------------------------------------------------------------+
void CheckPendingOrdersStatus() {
    pendingOrdersCount = 0;
    filledOrdersCount = 0;
    
    for(int i = 0; i < MaxGridLevels; i++) {
        if(gridPendingTickets[i] == 0) continue;
        
        if(PositionSelectByTicket(gridPendingTickets[i])) {
            if(!gridIsFilled[i]) {
                gridIsFilled[i] = true;
                gridTickets[i] = gridPendingTickets[i];
                gridOpenTimes[i] = TimeCurrent();
                totalGridOrders++;
                
                if(i == 0) {
                    currentGridLevel = MathMax(currentGridLevel, 1);
                    gridActive = true;
                    currentState = STATE_GRID_ACTIVE;
                } else {
                    currentGridLevel = MathMax(currentGridLevel, i+1);
                }
                
                priceTimesSizeSummation += gridOpenPrices[i] * gridLotSizes[i];
                totalLotSizeSummation += gridLotSizes[i];
                
                UpdateGridLevelVisual(i+1, true);
                
                Print("💰 Grid L", i+1, " FILLED @ ", gridOpenPrices[i]);
                
                if(EnableAlerts) {
                    Alert("💰 Grid Level ", i+1, " attivato!");
                }
                
                if(EnableCooldown) {
                    ActivateCooldown("DOWN", CooldownDownSeconds);
                }
            }
            filledOrdersCount++;
        }
        else if(OrderSelect(gridPendingTickets[i])) {
            pendingOrdersCount++;
        }
    }
}

//+------------------------------------------------------------------+
//| Activate cooldown                                                 |
//+------------------------------------------------------------------+
void ActivateCooldown(string type, int seconds) {
    cooldownActive = true;
    cooldownEndTime = TimeCurrent() + seconds;
    cooldownType = type;
    
    if(DetailedLogging) {
        Print("⏱️ Cooldown ", type, " attivato per ", seconds, "s");
    }
}

//+------------------------------------------------------------------+
//| Validation pre-start                                              |
//+------------------------------------------------------------------+
bool ValidateSystemStart() {
    Print("═══ VALIDAZIONE PRE-START ═══");
    
    // CHECK 1: Parametri base
    if(MainLotSize <= 0 || MainTakeProfitPips <= 0) {
        Print("❌ VALIDAZIONE FALLITA:");
        Print("   MainLotSize o MainTP invalidi");
        return false;
    }
    
    // CHECK 2: Parametri grid attivi
    if(ActiveGridSpacing <= 0 || ActiveGridActivationPips <= 0) {
        Print("❌ VALIDAZIONE FALLITA:");
        Print("   Parametri grid invalidi");
        return false;
    }
    
    // CHECK 3: Connessione broker
    if(!TerminalInfoInteger(TERMINAL_CONNECTED)) {
        Print("❌ VALIDAZIONE FALLITA:");
        Print("   Terminal non connesso al broker");
        return false;
    }
    
    // CHECK 4: Trading abilitato
    if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) {
        Print("❌ VALIDAZIONE FALLITA:");
        Print("   Trading non abilitato nel terminale");
        return false;
    }
    
    if(!MQLInfoInteger(MQL_TRADE_ALLOWED)) {
        Print("❌ VALIDAZIONE FALLITA:");
        Print("   Trading non abilitato per l'EA");
        return false;
    }
    
    // CHECK 5: Symbol trading abilitato
    if(!SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE)) {
        Print("❌ VALIDAZIONE FALLITA:");
        Print("   Trading non abilitato per ", _Symbol);
        return false;
    }
    
    // CHECK 6: Lot size compatibili
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    
    if(MainLotSize < minLot || MainLotSize > maxLot) {
        Print("❌ VALIDAZIONE FALLITA:");
        Print("   MainLotSize fuori range broker");
        return false;
    }
    
    if(LotSizeMode == STANDARD && StandardLotSize < minLot) {
        Print("❌ VALIDAZIONE FALLITA:");
        Print("   StandardLotSize < Min broker");
        return false;
    }
    
    if(LotSizeMode == SCOUT_SYSTEM && ScoutLotSize < minLot) {
        Print("❌ VALIDAZIONE FALLITA:");
        Print("   ScoutLotSize < Min broker");
        return false;
    }
    
    // CHECK 7: Margine sufficiente
    double totalLots = MainLotSize;
    for(int i = 1; i <= MaxGridLevels; i++) {
        totalLots += CalculateGridLotSize(i);
    }
    
    double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    double requiredMargin = totalLots * SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_INITIAL);
    
    if(requiredMargin > freeMargin * 0.8) {
        Print("❌ VALIDAZIONE FALLITA:");
        Print("   Margine insufficiente");
        return false;
    }
    
    Print("✅ Tutte le validazioni SUPERATE");
    
    return true;
}

//+------------------------------------------------------------------+
//| Monitor main position                                             |
//+------------------------------------------------------------------+
void MonitorMainPosition() {
    if(!PositionSelectByTicket(mainTicket)) {
        if(mainCurrentProfit > 0) {
            CloseEntireSystem("Main TP Reached");
        } else {
            CloseEntireSystem("Main Position Lost");
        }
    }
}

//+------------------------------------------------------------------+
//| Update trailing grid                                              |
//+------------------------------------------------------------------+
void UpdateTrailingGrid() {
    double currentPrice = mainDirection == LONG ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) :
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    double profitPips = 0;
    if(mainDirection == LONG) {
        profitPips = (currentPrice - mainOpenPrice) / PipsToPoints(1);
    } else {
        profitPips = (mainOpenPrice - currentPrice) / PipsToPoints(1);
    }
    
    if(profitPips >= TrailingStartPips) {
        if(!trailingActive) {
            trailingActive = true;
            Print("🚀 TRAILING GRID ATTIVATO @ +", profitPips, " pips");
            
            if(EnableAlerts) {
                Alert("🚀 Trailing Grid attivo!");
            }
        }
        
        double newActivation = 0;
        
        if(mainDirection == LONG) {
            newActivation = currentPrice - PipsToPoints(TrailingMinDistance);
            
            if(!TrailToBreakeven && newActivation > mainOpenPrice) {
                newActivation = mainOpenPrice - PipsToPoints(ActiveGridActivationPips);
            }
        } else {
            newActivation = currentPrice + PipsToPoints(TrailingMinDistance);
            
            if(!TrailToBreakeven && newActivation < mainOpenPrice) {
                newActivation = mainOpenPrice + PipsToPoints(ActiveGridActivationPips);
            }
        }
        
        double initialActivation = mainOpenPrice + (mainDirection == LONG ? 
                                   -PipsToPoints(ActiveGridActivationPips) : 
                                   PipsToPoints(ActiveGridActivationPips));
        
        if(trailedActivationPrice == 0) {
            trailedActivationPrice = initialActivation;
        }
        
        double improvement = MathAbs(newActivation - trailedActivationPrice) / PipsToPoints(1);
        
        if(improvement >= TrailingStepPips) {
            double oldAct = trailedActivationPrice;
            trailedActivationPrice = newActivation;
            lastTrailedPrice = currentPrice;
            
            if(GridOrderType == GRID_PENDING) {
                ShiftGridPendingOrders(newActivation);
            } else {
                UpdatePredictedGridLevels(newActivation);
            }
            
            totalTrailingShifts++;
            
            Print("📈 TRAILING: ", oldAct, " → ", newActivation, " (+", improvement, " pips)");
            
            if(EnableCooldown) {
                ActivateCooldown("UP", CooldownUpSeconds);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Shift grid pending orders                                         |
//+------------------------------------------------------------------+
void ShiftGridPendingOrders(double newActivation) {
    Print("🔄 SHIFT GRID PENDING ORDERS → ", newActivation);
    
    int canceledCount = 0;
    
    for(int i = 0; i < MaxGridLevels; i++) {
        if(gridPendingTickets[i] == 0) continue;
        if(gridIsFilled[i]) continue;
        
        if(OrderSelect(gridPendingTickets[i])) {
            if(trade.OrderDelete(gridPendingTickets[i])) {
                gridPendingTickets[i] = 0;
                canceledCount++;
                totalPendingCanceled++;
                RemoveGridLevelVisual(i+1);
            }
        }
    }
    
    if(DetailedLogging) {
        Print("✅ Cancellati ", canceledCount, " ordini pending");
    }
    
    int replacedCount = 0;
    for(int i = 1; i <= MaxGridLevels; i++) {
        if(gridIsFilled[i-1]) continue;
        
        double levelPrice = 0;
        if(mainDirection == LONG) {
            levelPrice = newActivation - ((i-1) * PipsToPoints(ActiveGridSpacing));
        } else {
            levelPrice = newActivation + ((i-1) * PipsToPoints(ActiveGridSpacing));
        }
        
        if(PlaceGridPendingOrder(i, levelPrice)) {
            replacedCount++;
        }
    }
    
    pendingOrdersCount = replacedCount;
    Print("✅ Ripiazzati ", replacedCount, " ordini pending");
}

//+------------------------------------------------------------------+
//| Check grid activation (MARKET mode)                              |
//+------------------------------------------------------------------+
void CheckGridActivation() {
    if(gridActive) return;
    if(GridOrderType == GRID_PENDING) return;
    
    double activationThreshold = trailingActive && trailedActivationPrice != 0 ? 
                                 trailedActivationPrice :
                                 (mainOpenPrice + (mainDirection == LONG ? 
                                  -PipsToPoints(ActiveGridActivationPips) : 
                                  PipsToPoints(ActiveGridActivationPips)));
    
    double currentPrice = mainDirection == LONG ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) :
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    bool shouldActivate = false;
    if(mainDirection == LONG && currentPrice <= activationThreshold) {
        shouldActivate = true;
    } else if(mainDirection == SHORT && currentPrice >= activationThreshold) {
        shouldActivate = true;
    }
    
    if(shouldActivate) {
        ActivateGrid(currentPrice);
    }
}

//+------------------------------------------------------------------+
//| Activate grid                                                     |
//+------------------------------------------------------------------+
void ActivateGrid(double currentPrice) {
    Print("🔄 GRID ATTIVATO @ ", currentPrice);
    gridActive = true;
    currentState = STATE_GRID_ACTIVE;
    OpenFirstGridLevel(currentPrice);
    
    if(EnableCooldown) {
        ActivateCooldown("DOWN", CooldownDownSeconds);
    }
}

//+------------------------------------------------------------------+
//| Open first grid level                                            |
//+------------------------------------------------------------------+
void OpenFirstGridLevel(double price) {
    ENUM_ORDER_TYPE gridType = mainDirection == LONG ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    
    double lotSize = CalculateGridLotSize(1);
    double stopLoss = CalculateGridStopLoss(price, gridType);
    double takeProfit = CalculateGridTP(price, gridType);
    
    if(trade.PositionOpen(_Symbol, gridType, lotSize, price, stopLoss, takeProfit, 
                         "BREVA-TIVAN-GRID-1")) {
        gridTickets[0] = trade.ResultOrder();
        gridOpenPrices[0] = price;
        gridLotSizes[0] = lotSize;
        gridTakeProfits[0] = takeProfit;
        gridStopLosses[0] = stopLoss;
        gridIsFilled[0] = true;
        gridOpenTimes[0] = TimeCurrent();
        currentGridLevel = 1;
        totalGridOrders++;
        filledOrdersCount++;
        
        priceTimesSizeSummation += price * lotSize;
        totalLotSizeSummation += lotSize;
        
        DrawGridFilledLevel(1, price, takeProfit, stopLoss);
    }
}

//+------------------------------------------------------------------+
//| Check new grid level                                             |
//+------------------------------------------------------------------+
void CheckNewGridLevel() {
    if(GridOrderType == GRID_PENDING) return;
    if(currentGridLevel >= MaxGridLevels) return;
    if(cooldownActive) return;
    
    double currentPrice = mainDirection == LONG ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK) :
                         SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    double lastGridPrice = gridOpenPrices[currentGridLevel - 1];
    double distance = MathAbs(currentPrice - lastGridPrice) / PipsToPoints(1);
    
    if(distance >= ActiveGridSpacing) {
        bool shouldOpen = false;
        if(mainDirection == LONG && currentPrice < lastGridPrice) {
            shouldOpen = true;
        } else if(mainDirection == SHORT && currentPrice > lastGridPrice) {
            shouldOpen = true;
        }
        
        if(shouldOpen) {
            OpenNextGridLevel(currentPrice);
        }
    }
}

//+------------------------------------------------------------------+
//| Open next grid level                                             |
//+------------------------------------------------------------------+
void OpenNextGridLevel(double price) {
    int level = currentGridLevel + 1;
    double lotSize = CalculateGridLotSize(level);
    ENUM_ORDER_TYPE gridType = mainDirection == LONG ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    double stopLoss = 0;
    double takeProfit = CalculateGridTP(price, gridType);
    
    if(trade.PositionOpen(_Symbol, gridType, lotSize, price, stopLoss, takeProfit, 
                         "BREVA-TIVAN-GRID-" + IntegerToString(level))) {
        gridTickets[level-1] = trade.ResultOrder();
        gridOpenPrices[level-1] = price;
        gridLotSizes[level-1] = lotSize;
        gridTakeProfits[level-1] = takeProfit;
        gridStopLosses[level-1] = stopLoss;
        gridIsFilled[level-1] = true;
        gridOpenTimes[level-1] = TimeCurrent();
        currentGridLevel = level;
        totalGridOrders++;
        filledOrdersCount++;
        
        priceTimesSizeSummation += price * lotSize;
        totalLotSizeSummation += lotSize;
        
        DrawGridFilledLevel(level, price, takeProfit, stopLoss);
        
        if(EnableCooldown) {
            ActivateCooldown("DOWN", CooldownDownSeconds);
        }
    }
}

//+------------------------------------------------------------------+
//| 🔍 SCOUT SYSTEM: Calculate grid lot size                         |
//+------------------------------------------------------------------+
double CalculateGridLotSize(int level) {
    double lotSize = 0;
    
    if(LotSizeMode == STANDARD) {
        lotSize = StandardLotSize;
    } 
    else if(LotSizeMode == PROGRESSION) {
        lotSize = ProgressionStartLot + ((level - 1) * ProgressionIncrement);
        if(lotSize > ProgressionMaxLot) {
            lotSize = ProgressionMaxLot;
        }
    } 
    else if(LotSizeMode == SCOUT_SYSTEM) {
        // 🔍 SCOUT: Grid 1 usa ScoutLotSize, poi StandardLotSize
        if(level == 1) {
            lotSize = ScoutLotSize;  // Lotto ridotto per scout
        } else {
            lotSize = StandardLotSize;  // Lotto normale per grid successivi
        }
    }
    
    return NormalizeLotSize(lotSize);
}

//+------------------------------------------------------------------+
//| Calculate grid stop loss                                          |
//+------------------------------------------------------------------+
double CalculateGridStopLoss(double entryPrice, ENUM_ORDER_TYPE orderType) {
    double slDistance = PipsToPoints(ActiveFirstGridStopLoss);
    
    double sl = 0;
    if(orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_BUY_STOP) {
        sl = entryPrice - slDistance;
    } else {
        sl = entryPrice + slDistance;
    }
    
    return NormalizeDouble(sl, _Digits);
}

//+------------------------------------------------------------------+
//| Calculate grid TP                                                 |
//+------------------------------------------------------------------+
double CalculateGridTP(double entryPrice, ENUM_ORDER_TYPE orderType) {
    double tpDistance = currentGridTP;
    
    double tp = 0;
    if(orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_BUY_STOP) {
        tp = entryPrice + tpDistance;
    } else {
        tp = entryPrice - tpDistance;
    }
    
    return NormalizeDouble(tp, _Digits);
}

//+------------------------------------------------------------------+
//| Calculate main TP                                                 |
//+------------------------------------------------------------------+
double CalculateMainTP(double entryPrice, ENUM_DIRECTION direction) {
    double tpDistance = PipsToPoints(MainTakeProfitPips);
    
    double tp = 0;
    if(direction == LONG) {
        tp = entryPrice + tpDistance;
    } else {
        tp = entryPrice - tpDistance;
    }
    
    return NormalizeDouble(tp, _Digits);
}

//+------------------------------------------------------------------+
//| Check grid closures                                               |
//+------------------------------------------------------------------+
void CheckGridClosures() {
    for(int i = 0; i < currentGridLevel; i++) {
        if(gridTickets[i] == 0) continue;
        if(!gridIsFilled[i]) continue;
        
        if(!PositionSelectByTicket(gridTickets[i])) {
            Print("💰 Grid L", i+1, " chiuso (TP)");
            totalGridCycles++;
            gridTickets[i] = 0;
            filledOrdersCount--;
        }
    }
}

//+------------------------------------------------------------------+
//| Check main TP                                                     |
//+------------------------------------------------------------------+
void CheckMainTakeProfit() {
    double currentPrice = mainDirection == LONG ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) :
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    bool tpHit = false;
    if(mainDirection == LONG && currentPrice >= mainTakeProfit) {
        tpHit = true;
    } else if(mainDirection == SHORT && currentPrice <= mainTakeProfit) {
        tpHit = true;
    }
    
    if(tpHit) {
        Print("🎯 Main TP @ ", currentPrice);
        
        if(EnableAlerts) {
            Alert("🎯 TAKE PROFIT RAGGIUNTO!");
        }
        
        CloseEntireSystem("Main TP Reached");
    }
}

//+------------------------------------------------------------------+
//| Update grid TPs                                                   |
//+------------------------------------------------------------------+
void UpdateGridTakeProfits(double newTPDistance) {
    for(int i = 0; i < MaxGridLevels; i++) {
        if(gridPendingTickets[i] == 0) continue;
        
        if(!gridIsFilled[i] && OrderSelect(gridPendingTickets[i])) {
            double openPrice = gridOpenPrices[i];
            ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            
            double tp = 0;
            if(orderType == ORDER_TYPE_BUY_STOP) {
                tp = openPrice + newTPDistance;
            } else {
                tp = openPrice - newTPDistance;
            }
            
            trade.OrderModify(gridPendingTickets[i], openPrice, 0, tp, ORDER_TIME_GTC, 0);
            gridTakeProfits[i] = tp;
        }
        
        if(gridIsFilled[i] && gridTickets[i] > 0 && PositionSelectByTicket(gridTickets[i])) {
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            ENUM_ORDER_TYPE posType = (ENUM_ORDER_TYPE)PositionGetInteger(POSITION_TYPE);
            
            double tp = 0;
            if(posType == ORDER_TYPE_BUY) {
                tp = openPrice + newTPDistance;
            } else {
                tp = openPrice - newTPDistance;
            }
            
            trade.PositionModify(gridTickets[i], 0, tp);
            gridTakeProfits[i] = tp;
        }
    }
}

//+------------------------------------------------------------------+
//| Update main TP                                                    |
//+------------------------------------------------------------------+
void UpdateMainTakeProfit(double newTP) {
    if(mainTicket > 0 && PositionSelectByTicket(mainTicket)) {
        trade.PositionModify(mainTicket, 0, newTP);
        mainTakeProfit = newTP;
    }
}

//+------------------------------------------------------------------+
//| Check emergency stop                                              |
//+------------------------------------------------------------------+
void CheckEmergencyStop() {
    if(currentDrawdown >= EmergencyStopPercent) {
        Print("🚨 EMERGENCY STOP - DD: ", currentDrawdown, "%");
        
        if(EnableAlerts) {
            Alert("🚨 EMERGENCY STOP ATTIVATO!");
        }
        
        CloseEntireSystem("EMERGENCY STOP");
    }
}

//+------------------------------------------------------------------+
//| 🔧 FIX COMPLETO: Close entire system - CANCELLA TUTTI GLI ORDINI |
//+------------------------------------------------------------------+
void CloseEntireSystem(string reason) {
    Print("╔════════════════════════════════════════════════════════════╗");
    Print("║  🔴 CHIUSURA SISTEMA: ", reason);
    Print("╚════════════════════════════════════════════════════════════╝");
    
    currentState = STATE_CLOSING;
    
    int closedPositions = 0;
    int canceledOrders = 0;
    
    // 🔧 FIX #1: Cancella MAIN pending order se presente
    if(pendingOrderTicket > 0) {
        if(OrderSelect(pendingOrderTicket)) {
            if(trade.OrderDelete(pendingOrderTicket)) {
                Print("✅ Main pending order cancellato: #", pendingOrderTicket);
                canceledOrders++;
                totalPendingCanceled++;
            } else {
                Print("❌ Errore cancellazione main pending: ", trade.ResultRetcodeDescription());
            }
        }
        pendingOrderTicket = 0; // Reset ticket
    }
    
    // 🔧 FIX #2: Cancella TUTTI gli ordini pending del simbolo con nostro magic
    for(int i = OrdersTotal() - 1; i >= 0; i--) {
        ulong orderTicket = OrderGetTicket(i);
        if(orderTicket > 0) {
            if(OrderSelect(orderTicket)) {
                if(OrderGetInteger(ORDER_MAGIC) == MagicNumber) {
                    if(OrderGetString(ORDER_SYMBOL) == _Symbol) {
                        if(trade.OrderDelete(orderTicket)) {
                            Print("✅ Pending order cancellato: #", orderTicket);
                            canceledOrders++;
                            totalPendingCanceled++;
                        } else {
                            Print("❌ Errore cancellazione pending: ", trade.ResultRetcodeDescription());
                        }
                    }
                }
            }
        }
    }
    
    // 🔧 FIX #3: Chiude TUTTE le posizioni aperte (main + grid)
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong posTicket = PositionGetTicket(i);
        if(posTicket > 0 && PositionSelectByTicket(posTicket)) {
            if(PositionGetInteger(POSITION_MAGIC) == MagicNumber) {
                if(PositionGetString(POSITION_SYMBOL) == _Symbol) {
                    if(trade.PositionClose(posTicket)) {
                        Print("✅ Posizione chiusa: #", posTicket);
                        closedPositions++;
                    } else {
                        Print("❌ Errore chiusura posizione: ", trade.ResultRetcodeDescription());
                    }
                }
            }
        }
    }
    
    SaveSessionStatistics(reason);
    
    Print("╔════════════════════════════════════════════════════════════╗");
    Print("║  REPORT FINALE SESSION                                     ║");
    Print("╠════════════════════════════════════════════════════════════╣");
    Print("║  📊 Posizioni chiuse: ", closedPositions);
    Print("║  📊 Ordini cancellati: ", canceledOrders);
    Print("║  💰 Profit totale: $", NormalizeDouble(totalSystemProfit, 2));
    Print("║  📉 Max DD: ", NormalizeDouble(maxDrawdown, 2), "%");
    Print("║  🔄 Grid cycles: ", totalGridCycles);
    Print("║  📊 Grid orders: ", totalGridOrders);
    Print("║  🚀 Trailing shifts: ", totalTrailingShifts);
    Print("╚════════════════════════════════════════════════════════════╝");
    
    if(EnableAlerts) {
        Alert("🔴 BREVA E TIVAN - Sistema chiuso: ", reason);
    }
    
    // Delay per garantire completamento operazioni
    Sleep(1000);
    ResetSystem();
}

//+------------------------------------------------------------------+
//| 🔧 FIX: Reset system con ripristino completo stato bottoni      |
//+------------------------------------------------------------------+
void ResetSystem() {
    systemActive = false;
    gridActive = false;
    currentState = STATE_IDLE;  // 🔧 FIX: Ripristino stato IDLE
    pendingOrderTicket = 0;
    
    mainTicket = 0;
    mainOpenPrice = 0;
    mainCurrentProfit = 0;
    mainTakeProfit = 0;
    
    currentGridLevel = 0;
    totalGridProfit = 0;
    totalSystemProfit = 0;
    currentDrawdown = 0;
    maxDrawdown = 0;
    
    trailedActivationPrice = 0;
    lastTrailedPrice = 0;
    trailingActive = false;
    
    cooldownActive = false;
    cooldownEndTime = 0;
    cooldownType = "";
    
    pendingOrdersCount = 0;
    filledOrdersCount = 0;
    
    ArrayInitialize(gridTickets, 0);
    ArrayInitialize(gridPendingTickets, 0);
    ArrayInitialize(gridOpenPrices, 0);
    ArrayInitialize(gridLotSizes, 0);
    ArrayInitialize(gridTakeProfits, 0);
    ArrayInitialize(gridStopLosses, 0);
    ArrayInitialize(gridOpenTimes, 0);
    ArrayInitialize(gridIsFilled, false);
    
    priceTimesSizeSummation = 0;
    totalLotSizeSummation = 0;
    weightedAvgPrice = 0;
    
    totalGridCycles = 0;
    totalGridOrders = 0;
    totalTrailingShifts = 0;
    totalPendingCanceled = 0;
    
    RemoveGraphicalLines();
    
    // 🔧 FIX: Forza reset bottoni
    ObjectSetInteger(0, "BTN_BUY_MARKET", OBJPROP_STATE, false);
    ObjectSetInteger(0, "BTN_BUY_LIMIT", OBJPROP_STATE, false);
    ObjectSetInteger(0, "BTN_BUY_STOP", OBJPROP_STATE, false);
    ObjectSetInteger(0, "BTN_SELL_MARKET", OBJPROP_STATE, false);
    ObjectSetInteger(0, "BTN_SELL_LIMIT", OBJPROP_STATE, false);
    ObjectSetInteger(0, "BTN_SELL_STOP", OBJPROP_STATE, false);
    ObjectSetInteger(0, "BTN_CLOSE_ALL", OBJPROP_STATE, false);
    
    ChartRedraw();
    
    Print("✅ Sistema resetato - Pronto per nuovo trade");
}

//+------------------------------------------------------------------+
//| Update system metrics                                             |
//+------------------------------------------------------------------+
void UpdateSystemMetrics() {
    mainCurrentProfit = 0;
    totalGridProfit = 0;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        if(PositionSelectByTicket(PositionGetTicket(i))) {
            if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            
            string comment = PositionGetString(POSITION_COMMENT);
            double profit = PositionGetDouble(POSITION_PROFIT);
            double swap = PositionGetDouble(POSITION_SWAP);
            double totalProfit = profit + swap;
            
            if(StringFind(comment, "MAIN") >= 0) {
                mainCurrentProfit = totalProfit;
            } else if(StringFind(comment, "GRID") >= 0) {
                totalGridProfit += totalProfit;
            }
        }
    }
    
    totalSystemProfit = mainCurrentProfit + totalGridProfit;
    
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    currentDrawdown = ((balance - equity) / balance) * 100;
    
    if(currentDrawdown > maxDrawdown) {
        maxDrawdown = currentDrawdown;
    }
    
    if(totalLotSizeSummation > 0) {
        weightedAvgPrice = priceTimesSizeSummation / totalLotSizeSummation;
    }
}

//+------------------------------------------------------------------+
//| Normalize lot size                                                |
//+------------------------------------------------------------------+
double NormalizeLotSize(double lot) {
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    lot = MathMax(lot, minLot);
    lot = MathMin(lot, maxLot);
    lot = MathRound(lot / lotStep) * lotStep;
    
    return NormalizeDouble(lot, 2);
}

//+------------------------------------------------------------------+
//| Save session statistics                                           |
//+------------------------------------------------------------------+
void SaveSessionStatistics(string reason) {
    int handle = FileOpen("Breva_Tivan_Stats.csv", FILE_WRITE | FILE_READ | FILE_CSV | FILE_ANSI, ',');
    
    if(handle != INVALID_HANDLE) {
        FileSeek(handle, 0, SEEK_END);
        
        FileWrite(handle,
                 TimeToString(systemStartTime),
                 TimeToString(TimeCurrent()),
                 _Symbol,
                 EnumToString(InstrumentType),
                 EnumToString(mainDirection),
                 DoubleToString(MainLotSize, 2),
                 IntegerToString(currentGridLevel),
                 IntegerToString(totalGridCycles),
                 IntegerToString(totalGridOrders),
                 IntegerToString(totalTrailingShifts),
                 IntegerToString(totalPendingCanceled),
                 DoubleToString(totalSystemProfit, 2),
                 DoubleToString(maxDrawdown, 2),
                 GridOrderType == GRID_PENDING ? "PENDING" : "MARKET",
                 trailingActive ? "Trailing-ON" : "Trailing-OFF",
                 reason);
        
        FileClose(handle);
    }
}

//+------------------------------------------------------------------+
//| UI FUNCTIONS - DUAL DASHBOARD MIGLIORATA                         |
//+------------------------------------------------------------------+

void CreateDashboard() {
    int x = 10, y = 30;
    int width = 360, height = 520;
    
    CreateRectangle("PANEL_BG", x, y, width, height, PanelBackColor);
    
    // 🎨 Titolo grande e ben visibile
    CreateLabel("LBL_TITLE1", x + 15, y + 10, "╔══════════════════════════╗", clrGold, 12, "Courier New");
    CreateLabel("LBL_TITLE2", x + 15, y + 28, "║  BREVA E TIVAN v1.3.3  ║", clrWhite, 14, "Arial Black");
    CreateLabel("LBL_TITLE3", x + 15, y + 48, "╚══════════════════════════╝", clrGold, 12, "Courier New");
    
    y += 70;
    string instrumentText = "Instrument: " + EnumToString(InstrumentType);
    CreateLabel("LBL_INSTRUMENT", x + 10, y, instrumentText, clrGold, 9);
    
    y += 20;
    CreateLabel("LBL_STATUS", x + 10, y, "Status: IDLE", clrLime, 9);
    
    y += 25;
    CreateLabel("LBL_MAIN_TITLE", x + 10, y, "═══ MAIN POSITION ═══", clrGold, 9, "Arial Bold");
    y += 20;
    CreateLabel("LBL_MAIN_INFO", x + 10, y, "Direction: - | Profit: -", PanelTextColor, 8);
    
    y += 30;
    CreateLabel("LBL_GRID_TITLE", x + 10, y, "═══ GRID HEDGING ═══", clrOrange, 9, "Arial Bold");
    y += 20;
    CreateLabel("LBL_GRID_INFO", x + 10, y, "Levels: 0 | Cycles: 0", PanelTextColor, 8);
    y += 18;
    CreateLabel("LBL_GRID_PROFIT", x + 10, y, "Grid Profit: 0.00", PanelTextColor, 8);
    y += 18;
    CreateLabel("LBL_GRID_ORDERS", x + 10, y, "Pending: 0 | Filled: 0", PanelTextColor, 8);
    
    y += 30;
    CreateLabel("LBL_TRAIL_TITLE", x + 10, y, "═══ TRAILING ═══", clrDodgerBlue, 9, "Arial Bold");
    y += 20;
    CreateLabel("LBL_TRAIL_INFO", x + 10, y, "Status: Inactive", PanelTextColor, 8);
    y += 18;
    CreateLabel("LBL_TRAIL_SHIFTS", x + 10, y, "Shifts: 0", PanelTextColor, 8);
    
    y += 30;
    CreateLabel("LBL_COOLDOWN_TITLE", x + 10, y, "═══ COOLDOWN ═══", clrYellow, 9, "Arial Bold");
    y += 20;
    CreateLabel("LBL_COOLDOWN_INFO", x + 10, y, "Status: Inactive", PanelTextColor, 8);
    
    y += 30;
    CreateLabel("LBL_PERF_TITLE", x + 10, y, "═══ PERFORMANCE ═══", clrDodgerBlue, 9, "Arial Bold");
    y += 20;
    CreateLabel("LBL_TOTAL_PROFIT", x + 10, y, "Total Profit: 0.00", PanelTextColor, 9);
    y += 18;
    CreateLabel("LBL_DRAWDOWN", x + 10, y, "Drawdown: 0.00%", PanelTextColor, 8);
    y += 18;
    CreateLabel("LBL_TIME", x + 10, y, "Time: 0h 0m", PanelTextColor, 8);
    
    ChartRedraw();
}

void CreateDualControlButtons() {
    int x = 10, y = 580;
    int btnWidth = 115;
    int btnHeight = 30;
    int spacing = 5;
    
    CreateLabel("LBL_BUY", x, y, "═══ BUY ═══", clrLimeGreen, 9, "Arial Bold");
    y += 20;
    
    CreateButton("BTN_BUY_MARKET", x, y, btnWidth, btnHeight, "MARKET", clrLimeGreen);
    CreateButton("BTN_BUY_LIMIT", x + btnWidth + spacing, y, btnWidth, btnHeight, "LIMIT", clrDodgerBlue);
    CreateButton("BTN_BUY_STOP", x + (btnWidth + spacing)*2, y, btnWidth, btnHeight, "STOP", clrGold);
    
    y += btnHeight + 15;
    
    CreateLabel("LBL_SELL", x, y, "═══ SELL ═══", clrRed, 9, "Arial Bold");
    y += 20;
    
    CreateButton("BTN_SELL_MARKET", x, y, btnWidth, btnHeight, "MARKET", clrRed);
    CreateButton("BTN_SELL_LIMIT", x + btnWidth + spacing, y, btnWidth, btnHeight, "LIMIT", clrOrangeRed);
    CreateButton("BTN_SELL_STOP", x + (btnWidth + spacing)*2, y, btnWidth, btnHeight, "STOP", clrDarkOrange);
    
    y += btnHeight + 15;
    
    CreateButton("BTN_CLOSE_ALL", x, y, (btnWidth + spacing)*3 - spacing, btnHeight, "CLOSE ALL POSITIONS", clrMaroon);
    
    ChartRedraw();
}

void UpdateDashboard() {
    if(!systemActive) {
        ObjectSetString(0, "LBL_STATUS", OBJPROP_TEXT, "Status: IDLE");
        ObjectSetInteger(0, "LBL_STATUS", OBJPROP_COLOR, clrGray);
        return;
    }
    
    string status = EnumToString(currentState);
    color statusColor = currentState == STATE_MAIN_OPEN ? clrLime : clrYellow;
    ObjectSetString(0, "LBL_STATUS", OBJPROP_TEXT, "Status: " + status);
    ObjectSetInteger(0, "LBL_STATUS", OBJPROP_COLOR, statusColor);
    
    string mainText = StringFormat("%s | P: %.2f", 
                                   EnumToString(mainDirection),
                                   mainCurrentProfit);
    ObjectSetString(0, "LBL_MAIN_INFO", OBJPROP_TEXT, mainText);
    
    string gridText = StringFormat("L: %d/%d | C: %d | O: %d",
                                  currentGridLevel, MaxGridLevels, 
                                  totalGridCycles, totalGridOrders);
    ObjectSetString(0, "LBL_GRID_INFO", OBJPROP_TEXT, gridText);
    
    string gridProfitText = StringFormat("Grid: %.2f", totalGridProfit);
    color gridColor = totalGridProfit > 0 ? clrLime : (totalGridProfit < 0 ? clrRed : clrWhite);
    ObjectSetString(0, "LBL_GRID_PROFIT", OBJPROP_TEXT, gridProfitText);
    ObjectSetInteger(0, "LBL_GRID_PROFIT", OBJPROP_COLOR, gridColor);
    
    string ordersText = StringFormat("Pending: %d | Filled: %d", pendingOrdersCount, filledOrdersCount);
    ObjectSetString(0, "LBL_GRID_ORDERS", OBJPROP_TEXT, ordersText);
    
    string trailText = trailingActive ? StringFormat("ACTIVE (Shifts: %d)", totalTrailingShifts) : "Inactive";
    color trailColor = trailingActive ? clrLime : clrGray;
    ObjectSetString(0, "LBL_TRAIL_INFO", OBJPROP_TEXT, "Status: " + trailText);
    ObjectSetInteger(0, "LBL_TRAIL_INFO", OBJPROP_COLOR, trailColor);
    
    string shiftsText = StringFormat("Total Shifts: %d", totalTrailingShifts);
    ObjectSetString(0, "LBL_TRAIL_SHIFTS", OBJPROP_TEXT, shiftsText);
    
    string cooldownText = "Inactive";
    color cooldownColor = clrGray;
    if(cooldownActive) {
        int remaining = (int)(cooldownEndTime - TimeCurrent());
        cooldownText = StringFormat("%s: %ds", cooldownType, remaining);
        cooldownColor = clrYellow;
    }
    ObjectSetString(0, "LBL_COOLDOWN_INFO", OBJPROP_TEXT, "Status: " + cooldownText);
    ObjectSetInteger(0, "LBL_COOLDOWN_INFO", OBJPROP_COLOR, cooldownColor);
    
    string profitText = StringFormat("Total: %.2f", totalSystemProfit);
    color profitColor = totalSystemProfit > 0 ? clrLime : (totalSystemProfit < 0 ? clrRed : clrWhite);
    ObjectSetString(0, "LBL_TOTAL_PROFIT", OBJPROP_TEXT, profitText);
    ObjectSetInteger(0, "LBL_TOTAL_PROFIT", OBJPROP_COLOR, profitColor);
    
    string ddText = StringFormat("DD: %.2f%% (Max: %.2f%%)",
                                currentDrawdown, maxDrawdown);
    color ddColor = currentDrawdown < 10 ? clrLime : 
                   (currentDrawdown < 20 ? clrYellow : clrRed);
    ObjectSetString(0, "LBL_DRAWDOWN", OBJPROP_TEXT, ddText);
    ObjectSetInteger(0, "LBL_DRAWDOWN", OBJPROP_COLOR, ddColor);
    
    int seconds = (int)(TimeCurrent() - systemStartTime);
    int hours = seconds / 3600;
    int minutes = (seconds % 3600) / 60;
    string timeText = StringFormat("Time: %dh %dm", hours, minutes);
    ObjectSetString(0, "LBL_TIME", OBJPROP_TEXT, timeText);
}

void DrawMainPositionLine() {
    string name = "MAIN_POS_LINE";
    ObjectCreate(0, name, OBJ_HLINE, 0, 0, mainOpenPrice);
    ObjectSetInteger(0, name, OBJPROP_COLOR, MainLineColor);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetString(0, name, OBJPROP_TEXT, "Main " + EnumToString(mainDirection) + " @ " + DoubleToString(mainOpenPrice, _Digits));
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

void DrawTakeProfitLines() {
    string mainTP = "MAIN_TP_LINE";
    ObjectCreate(0, mainTP, OBJ_HLINE, 0, 0, mainTakeProfit);
    ObjectSetInteger(0, mainTP, OBJPROP_COLOR, TPLineColor);
    ObjectSetInteger(0, mainTP, OBJPROP_WIDTH, 2);
    ObjectSetInteger(0, mainTP, OBJPROP_STYLE, STYLE_DOT);
    ObjectSetString(0, mainTP, OBJPROP_TEXT, "Main TP @ " + DoubleToString(mainTakeProfit, _Digits));
    ObjectSetInteger(0, mainTP, OBJPROP_SELECTABLE, true);
    
    string gridTP = "GRID_TP_LINE";
    double exampleGridTP = mainOpenPrice + (mainDirection == LONG ? -currentGridTP : currentGridTP);
    ObjectCreate(0, gridTP, OBJ_HLINE, 0, 0, exampleGridTP);
    ObjectSetInteger(0, gridTP, OBJPROP_COLOR, clrOrange);
    ObjectSetInteger(0, gridTP, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, gridTP, OBJPROP_STYLE, STYLE_DASHDOT);
    ObjectSetString(0, gridTP, OBJPROP_TEXT, "Grid TP (Drag to modify)");
    ObjectSetInteger(0, gridTP, OBJPROP_SELECTABLE, true);
}

void DrawPredictedGridLevels() {
    double activationBase = trailedActivationPrice != 0 ? trailedActivationPrice :
                           (mainOpenPrice + (mainDirection == LONG ? 
                            -PipsToPoints(ActiveGridActivationPips) : 
                            PipsToPoints(ActiveGridActivationPips)));
    
    for(int i = 1; i <= MaxGridLevels; i++) {
        double levelPrice = 0;
        if(mainDirection == LONG) {
            levelPrice = activationBase - ((i-1) * PipsToPoints(ActiveGridSpacing));
        } else {
            levelPrice = activationBase + ((i-1) * PipsToPoints(ActiveGridSpacing));
        }
        
        string name = "PRED_GRID_" + IntegerToString(i);
        ObjectCreate(0, name, OBJ_HLINE, 0, 0, levelPrice);
        ObjectSetInteger(0, name, OBJPROP_COLOR, GridLineColor);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
        ObjectSetString(0, name, OBJPROP_TEXT, "Predicted L" + IntegerToString(i));
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    }
}

void UpdatePredictedGridLevels(double newActivation) {
    for(int i = 1; i <= MaxGridLevels; i++) {
        double levelPrice = 0;
        if(mainDirection == LONG) {
            levelPrice = newActivation - ((i-1) * PipsToPoints(ActiveGridSpacing));
        } else {
            levelPrice = newActivation + ((i-1) * PipsToPoints(ActiveGridSpacing));
        }
        
        string name = "PRED_GRID_" + IntegerToString(i);
        ObjectMove(0, name, 0, 0, levelPrice);
    }
}

void DrawGridPendingLevel(int level, double price, double tp, double sl) {
    string baseName = "GRID_L" + IntegerToString(level);
    
    string lineName = baseName + "_LINE";
    ObjectCreate(0, lineName, OBJ_HLINE, 0, 0, price);
    ObjectSetInteger(0, lineName, OBJPROP_COLOR, GridPendingColor);
    ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
    ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DASHDOT);
    ObjectSetString(0, lineName, OBJPROP_TEXT, "PENDING L" + IntegerToString(level) + " @ " + DoubleToString(price, _Digits));
    ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
    
    string tpName = baseName + "_TP";
    ObjectCreate(0, tpName, OBJ_ARROW_RIGHT_PRICE, 0, TimeCurrent(), tp);
    ObjectSetInteger(0, tpName, OBJPROP_COLOR, TPMarkerColor);
    ObjectSetInteger(0, tpName, OBJPROP_WIDTH, 2);
    ObjectSetString(0, tpName, OBJPROP_TEXT, "TP L" + IntegerToString(level));
    ObjectSetInteger(0, tpName, OBJPROP_SELECTABLE, false);
    
    if(level == 1 && sl > 0) {
        string slName = baseName + "_SL";
        ObjectCreate(0, slName, OBJ_ARROW_RIGHT_PRICE, 0, TimeCurrent(), sl);
        ObjectSetInteger(0, slName, OBJPROP_COLOR, SLMarkerColor);
        ObjectSetInteger(0, slName, OBJPROP_WIDTH, 2);
        ObjectSetString(0, slName, OBJPROP_TEXT, "SL L1");
        ObjectSetInteger(0, slName, OBJPROP_SELECTABLE, false);
    }
}

void DrawGridFilledLevel(int level, double price, double tp, double sl) {
    string baseName = "GRID_L" + IntegerToString(level);
    
    string lineName = baseName + "_LINE";
    ObjectCreate(0, lineName, OBJ_HLINE, 0, 0, price);
    ObjectSetInteger(0, lineName, OBJPROP_COLOR, GridFilledColor);
    ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 3);
    ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetString(0, lineName, OBJPROP_TEXT, "FILLED L" + IntegerToString(level) + " @ " + DoubleToString(price, _Digits));
    ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
    
    string tpName = baseName + "_TP";
    ObjectCreate(0, tpName, OBJ_ARROW_RIGHT_PRICE, 0, TimeCurrent(), tp);
    ObjectSetInteger(0, tpName, OBJPROP_COLOR, TPMarkerColor);
    ObjectSetInteger(0, tpName, OBJPROP_WIDTH, 2);
    ObjectSetString(0, tpName, OBJPROP_TEXT, "TP L" + IntegerToString(level));
    ObjectSetInteger(0, tpName, OBJPROP_SELECTABLE, false);
    
    if(level == 1 && sl > 0) {
        string slName = baseName + "_SL";
        ObjectCreate(0, slName, OBJ_ARROW_RIGHT_PRICE, 0, TimeCurrent(), sl);
        ObjectSetInteger(0, slName, OBJPROP_COLOR, SLMarkerColor);
        ObjectSetInteger(0, slName, OBJPROP_WIDTH, 2);
        ObjectSetString(0, slName, OBJPROP_TEXT, "SL L1");
        ObjectSetInteger(0, slName, OBJPROP_SELECTABLE, false);
    }
}

void UpdateGridLevelVisual(int level, bool filled) {
    string baseName = "GRID_L" + IntegerToString(level);
    string lineName = baseName + "_LINE";
    
    if(filled) {
        ObjectSetInteger(0, lineName, OBJPROP_COLOR, GridFilledColor);
        ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 3);
        ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetString(0, lineName, OBJPROP_TEXT, "FILLED L" + IntegerToString(level));
    }
}

void RemoveGridLevelVisual(int level) {
    string baseName = "GRID_L" + IntegerToString(level);
    ObjectDelete(0, baseName + "_LINE");
    ObjectDelete(0, baseName + "_TP");
    ObjectDelete(0, baseName + "_SL");
}

void RemoveGraphicalLines() {
    ObjectDelete(0, "MAIN_POS_LINE");
    ObjectDelete(0, "MAIN_TP_LINE");
    ObjectDelete(0, "GRID_TP_LINE");
    
    for(int i = 1; i <= MaxGridLevels; i++) {
        ObjectDelete(0, "PRED_GRID_" + IntegerToString(i));
        RemoveGridLevelVisual(i);
    }
}

void RemoveAllObjects() {
    ObjectDelete(0, "PANEL_BG");
    ObjectDelete(0, "LBL_TITLE1");
    ObjectDelete(0, "LBL_TITLE2");
    ObjectDelete(0, "LBL_TITLE3");
    ObjectDelete(0, "LBL_INSTRUMENT");
    ObjectDelete(0, "LBL_STATUS");
    ObjectDelete(0, "LBL_MAIN_TITLE");
    ObjectDelete(0, "LBL_MAIN_INFO");
    ObjectDelete(0, "LBL_GRID_TITLE");
    ObjectDelete(0, "LBL_GRID_INFO");
    ObjectDelete(0, "LBL_GRID_PROFIT");
    ObjectDelete(0, "LBL_GRID_ORDERS");
    ObjectDelete(0, "LBL_TRAIL_TITLE");
    ObjectDelete(0, "LBL_TRAIL_INFO");
    ObjectDelete(0, "LBL_TRAIL_SHIFTS");
    ObjectDelete(0, "LBL_COOLDOWN_TITLE");
    ObjectDelete(0, "LBL_COOLDOWN_INFO");
    ObjectDelete(0, "LBL_PERF_TITLE");
    ObjectDelete(0, "LBL_TOTAL_PROFIT");
    ObjectDelete(0, "LBL_DRAWDOWN");
    ObjectDelete(0, "LBL_TIME");
    
    ObjectDelete(0, "LBL_BUY");
    ObjectDelete(0, "BTN_BUY_MARKET");
    ObjectDelete(0, "BTN_BUY_LIMIT");
    ObjectDelete(0, "BTN_BUY_STOP");
    
    ObjectDelete(0, "LBL_SELL");
    ObjectDelete(0, "BTN_SELL_MARKET");
    ObjectDelete(0, "BTN_SELL_LIMIT");
    ObjectDelete(0, "BTN_SELL_STOP");
    
    ObjectDelete(0, "BTN_CLOSE_ALL");
    
    RemoveGraphicalLines();
}

void CreateLabel(string name, int x, int y, string text, color clr, int fontSize, string font = "Arial") {
    ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
    ObjectSetString(0, name, OBJPROP_FONT, font);
}

void CreateButton(string name, int x, int y, int width, int height, string text, color clr) {
    ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
    ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrBlack);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
}

void CreateRectangle(string name, int x, int y, int width, int height, color clr) {
    ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
    ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrBlack);
}

//+==================================================================+
//|                                                                  |
//|                     ╔══════════════════════╗                     |
//|                     ║  BREVA E TIVAN v1.3.3 ║                    |
//|                     ║  Professional Trading  ║                    |
//|                     ╚══════════════════════╝                     |
//|                                                                  |
//|  Developed by: Breva e Tivan Development Team                   |
//|  Support: https://breva-tivan.com                               |
//|  Release: October 2025 - FIXED VERSION                           |
//|                                                                  |
//|  ⚠️ DISCLAIMER:                                                 |
//|  Trading involves substantial risk of loss and is not suitable  |
//|  for all investors. Past performance is not indicative of       |
//|  future results. Use this EA at your own risk.                  |
//|                                                                  |
//|  © 2025 All Rights Reserved - Breva e Tivan                     |
//|                                                                  |
//+==================================================================+
