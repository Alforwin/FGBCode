//+------------------------------------------------------------------+
//|                                                  FGB 01 023.mq4 |
//|                         FGB Hybrid: Emergency from Deposit Only  |
//|                         Version 01.023 - Full Version            |
//+------------------------------------------------------------------+
#property copyright "Forex Gold Bot"
#property link      ""
#property version   "1.23"
#property strict

#resource "\\Indicators\\VininI_BB_MA_WPR5v1n.ex4"

//+------------------------------------------------------------------+
//| ВХОДНЫЕ ПАРАМЕТРЫ                                                |
//+------------------------------------------------------------------+
input string   s000              = "=== 1. MAIN SETTINGS ===";
input int      Magic             = 1000;        // Magic Number
input int      MagicLock         = 2000;        // Magic Lock Number
input int      iSlippage         = 10;          // Slippage (points)
input bool     iShowInfo         = true;        // Show Info Panel
input int      iMaxOrders        = 15;          // Max Orders Count

input string   s001              = "=== 2. TRADING MODE ===";
input int      TradingMode       = 2;           // Mode: 1=Safe, 2=Grid
input bool     iReverseSignal    = false;       // Reverse Signal
input int      iDiff             = 10;          // Signal Diff (points)

input string   s002              = "=== 3. RISK MANAGEMENT ===";
input double   iLot              = 0.01;        // Fixed Lot
input bool     iUseDynamicLot    = true;        // Use Dynamic Lot
input double   iRiskPercent      = 0.3;         // Risk % per trade
input double   iMinLot           = 0.01;        // Minimum lot
input double   iMaxLot           = 0.3;         // Maximum lot
input double   iLotBalancePerc   = 30.0;        // Lot Balance Percent
input int      iMinWaitOpen      = 15;          // Min Wait Open (sec)
input double   iInitialDeposit   = 10000.0;     // Initial Deposit

input string   s003              = "=== 4. GRID SETTINGS ===";
input int      iLockStep         = 120;         // Grid/Lock Step (points)
input int      iKnees            = 3;           // Max knees before downshift
input int      iKnees2           = 6;           // Max knees total
input double   iDownshift        = 0.6;         // Downshift multiplier
input double   iLockMult         = 1.15;        // Lock multiplier
input double   iLockProfit       = 10.0;        // Lock profit target ($)

input string   s004              = "=== 5. SUPER TRAIL SETTINGS ===";
input bool     iUseSuperTrail    = true;        // Use SuperTrail
input int      iTrailStart       = 120;         // Trail Start (points)
input int      iTrailATRPeriod   = 14;          // ATR Period for trail
input double   iTrailATRMult     = 1.5;         // ATR Multiplier
input int      iTrailMin         = 60;          // Min trail distance (points)
input int      iTakeProfit       = 250;         // Take Profit (points)
input int      iTrailUpdateSec   = 5;           // Min seconds between trail updates

input string   s005              = "=== 6. CSBO SETTINGS ===";
input bool     iUseCSBO          = true;        // Use Close Some By Opposite
input int      iCSBOCooldown     = 60;          // CSBO Cooldown (seconds)
input double   iEndLossPercent   = 90.0;        // EndLoss% (% от NetProfit)
input double   iEndLossStart     = 2000.0;      // EndLoss Start ($)

input string   s006              = "=== 7. SAFETY & EMERGENCY ===";
input double   iEmergencyDDPct   = 30.0;        // Emergency DD% (30% от начального депозита)
input bool     iStopOnEmergency  = true;        // Stop after emergency
input double   iCloseProfit      = 30.0;        // Close all at profit ($)
input double   iMaxLossPct       = 30.0;        // Max loss % from deposit (30%)
input int      iEmergencyCooldown= 300;         // Cooldown after emergency (sec)

input string   s007              = "=== 8. TIME SETTINGS ===";
input string   iBeginTime        = "00:00";     // Trading Start
input string   iEndTime          = "00:00";     // Trading End

input string   s008              = "=== 9. INDICATOR ===";
input int      iBar              = 0;           // Bar (0=current, 1=closed)
input int      Ind01_WPR_Period  = 42;
input int      Ind01_MA_Period   = 1;
input int      Ind01_MA_Mode     = 1;
input int      Ind01_BB_Period   = 89;
input double   Ind01_BB_Div      = 1.0;
input int      Ind01_Limit       = 1440;
input int      Ind01_Buffer      = 0;

input string   s009              = "=== 10. REVERSE ===";
input bool     iReverse          = false;       // Use Reverse
input int      iReversePips      = 15;          // Reverse Pips
input int      iReverseCooldown  = 30;          // Reverse cooldown (sec)

input string   s010              = "=== 11. BALANCE SETTINGS ===";
input int      iBalanceCooldown  = 120;         // Balance cooldown (sec)
input double   iBalanceMinDiff   = 0.05;        // Min lot diff for balance

input string   s011              = "=== 12. VISUAL ===";
input color    iColorTPBuy       = clrLime;
input color    iColorSLBuy       = clrRed;
input color    iColorTPSell      = clrLime;
input color    iColorSLSell      = clrRed;
input ENUM_LINE_STYLE iStyleTP   = STYLE_SOLID;
input ENUM_LINE_STYLE iStyleSL   = STYLE_SOLID;

//+------------------------------------------------------------------+
//| СТРУКТУРЫ                                                        |
//+------------------------------------------------------------------+
struct SOrderInfoCSBO
{
   int ticket;
   int type;
   double openPrice;
   double lot;
   double profit;
   double distance;
   bool isPositive;
};

struct SOrderTrailStep
{
   int ticket;
   int type;
   double open;
   double lot;
   double sl;
   bool trail;
};

//+------------------------------------------------------------------+
//| ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ                                            |
//+------------------------------------------------------------------+
double TPLevelBuy, SLLevelBuy, TPLevelSell, SLLevelSell;
double StoreProfit = 0;
double LastStoreLot;
double LastHighPrice = 0, LastLowPrice = 0;
double Ind01_0, Ind01_1;
double g_point;
double g_initialBalance = 0;
double g_peakEquity = 0;
int Signal;
int WithLocks[];
datetime LastOpenTime;
string LogTxt;
bool g_endLossTriggered = false;
bool g_ordersLimitReached = false;
bool g_isReducingOrders = false;
datetime g_lastReductionTime = 0;
datetime g_lastCSBOTime = 0;
int g_csboCallCount = 0;
bool g_allowCloseLossOrders = false;
bool g_emergencyTriggered = false;
datetime g_emergencyTime = 0;

// Контрольные переменные
datetime g_lastBalanceTime = 0;
datetime g_lastReverseTime = 0;
datetime g_lastTrailUpdate = 0;
int g_lastTrailTicket = 0;
double g_lastTrailSL = 0;

// Dynamic Lot
double g_maxEquity = 0;
bool g_drawdownMode = false;
double g_lastLot = 0;

// SuperTrail
int g_trailLevelsProfit[10];
int g_trailLevelsSL[10];
int g_trailLevelsCount = 10;

// StepTrail
SOrderTrailStep OrdersTrailStep[];

//+------------------------------------------------------------------+
//| БЕЗОПАСНЫЕ ФУНКЦИИ                                               |
//+------------------------------------------------------------------+
int SafeStringToInt(string str)
{
   if(str == "") return(0);
   return((int)StringToInteger(str));
}

bool SafeOrderCloseWithCheck(int ticket, double lot, double price)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return(true);
   
   double profit = OrderProfit() + OrderSwap() + OrderCommission();
   if(profit < 0 && !g_allowCloseLossOrders)
   {
      Log(StringFormat("BLOCKED: Close loss order %d (%.2f)", ticket, profit));
      return(false);
   }
   
   if(OrderClose(ticket, lot, price, iSlippage)) return(true);
   
   int err = GetLastError();
   if(err != 4108) Log(StringFormat("OrderClose failed: %d error=%d", ticket, err));
   return(false);
}

//+------------------------------------------------------------------+
//| АВАРИЙНЫЕ ФУНКЦИИ (ТОЛЬКО ОТ НАЧАЛЬНОГО ДЕПОЗИТА)                |
//+------------------------------------------------------------------+
bool IsEmergency()
{
   double equity = AccountEquity();
   
   // Обновляем максимум эквити (только для информации, не для аварии)
   if(equity > g_maxEquity) g_maxEquity = equity;
   
   // Расчет просадки ТОЛЬКО от начального депозита
   double drawdownFromDeposit = 0;
   if(g_initialBalance > 0) {
      drawdownFromDeposit = (g_initialBalance - equity) / g_initialBalance * 100;
   }
   
   // Авария при просадке от начального депозита
   if(drawdownFromDeposit >= iEmergencyDDPct) {
      Log(StringFormat("EMERGENCY: Drawdown from deposit %.1f%% >= %.0f%%", 
                       drawdownFromDeposit, iEmergencyDDPct));
      return(true);
   }
   
   // Проверка максимального убытка от начального депозита
   double netProfit = equity - g_initialBalance;
   double lossPct = -netProfit / g_initialBalance * 100;
   if(netProfit < 0 && lossPct >= iMaxLossPct) {
      Log(StringFormat("EMERGENCY: Loss %.1f%% >= %.0f%%", lossPct, iMaxLossPct));
      return(true);
   }
   
   return(false);
}

void EmergencyCloseAll()
{
   Log("!!! EMERGENCY CLOSE ALL ORDERS !!!");
   g_emergencyTriggered = true;
   g_emergencyTime = TimeCurrent();
   g_allowCloseLossOrders = true;
   
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != Magic && OrderMagicNumber() != MagicLock) continue;
      if(OrderType() > OP_SELL) continue;
      
      double closePrice = (OrderType() == OP_BUY) ? Bid : Ask;
      SafeOrderCloseWithCheck(OrderTicket(), OrderLots(), closePrice);
   }
   
   g_allowCloseLossOrders = false;
   Log("!!! EMERGENCY CLOSE COMPLETED !!!");
   
   if(iStopOnEmergency) {
      Log(StringFormat("Trading stopped. Will resume after %d seconds", iEmergencyCooldown));
   }
}

//+------------------------------------------------------------------+
//| ПРОВЕРКА РАЗБЛОКИРОВКИ                                           |
//+------------------------------------------------------------------+
void CheckEmergencyUnblock()
{
   if(g_emergencyTriggered && iStopOnEmergency) {
      if(TimeCurrent() - g_emergencyTime > iEmergencyCooldown) {
         g_emergencyTriggered = false;
         g_emergencyTime = 0;
         Log(StringFormat("Emergency cooldown expired. Trading resumed after %d seconds", iEmergencyCooldown));
      }
   }
}

//+------------------------------------------------------------------+
//| ДИНАМИЧЕСКИЙ ЛОТ                                                 |
//+------------------------------------------------------------------+
double NormalizeLotDynamic(double lot)
{
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   
   if(lot < minLot) lot = minLot;
   if(lot > maxLot) lot = maxLot;
   
   lot = MathRound(lot / lotStep) * lotStep;
   return(NormalizeDouble(lot, 2));
}

double GetRiskDistance()
{
   return(iLockStep);
}

double GetATRFactor()
{
   double currentATR = iATR(NULL, 0, 14, 0);
   double avgATR = 0;
   
   if(currentATR <= 0) return(1.0);
   
   for(int i = 1; i <= 50; i++)
      avgATR += iATR(NULL, 0, 14, i);
   avgATR /= 50;
   
   if(avgATR <= 0) return(1.0);
   
   double factor = avgATR / currentATR;
   if(factor < 0.5) factor = 0.5;
   if(factor > 1.5) factor = 1.5;
   
   return(factor);
}

double GetVininIFactor()
{
   double bbUpper = iCustom(Symbol(), PERIOD_CURRENT, "::Indicators\\VininI_BB_MA_WPR5v1n.ex4",
                            Ind01_WPR_Period, Ind01_MA_Period, Ind01_MA_Mode,
                            Ind01_BB_Period, Ind01_BB_Div, Ind01_Limit,
                            0, iBar);
   
   double bbLower = iCustom(Symbol(), PERIOD_CURRENT, "::Indicators\\VininI_BB_MA_WPR5v1n.ex4",
                            Ind01_WPR_Period, Ind01_MA_Period, Ind01_MA_Mode,
                            Ind01_BB_Period, Ind01_BB_Div, Ind01_Limit,
                            1, iBar);
   
   if(bbUpper <= 0 || bbLower <= 0) return(1.0);
   
   double currentPrice = Bid;
   double bbWidth = (bbUpper - bbLower) / currentPrice * 100;
   double volatilityFactor = 1.0;
   
   if(bbWidth > 3.0) volatilityFactor = 0.5;
   else if(bbWidth < 0.8) volatilityFactor = 1.5;
   else volatilityFactor = 1.0;
   
   return(volatilityFactor);
}

double GetDrawdownFactor()
{
   double equity = AccountEquity();
   
   if(equity > g_maxEquity) g_maxEquity = equity;
   
   double drawdown = (g_maxEquity - equity) / g_maxEquity;
   double factor = 1.0;
   
   if(drawdown >= 0.12) g_drawdownMode = true;
   else if(drawdown <= 0.06) g_drawdownMode = false;
   
   if(g_drawdownMode) factor = 1.5;
   if(drawdown > 0.12) factor = factor * (1.0 - MathMin(0.5, drawdown));
   
   return(factor);
}

double GetDynamicLot()
{
   if(!iUseDynamicLot) return(NormalizeLotDynamic(iLot));
   
   double riskDistance = GetRiskDistance();
   if(riskDistance <= 0) riskDistance = iLockStep;
   
   double equity = AccountEquity();
   double riskAmount = equity * (iRiskPercent / 100.0);
   
   double pointValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   
   int digits = (int)MarketInfo(Symbol(), MODE_DIGITS);
   double distancePoints = riskDistance;
   if(digits == 3 || digits == 5) {
      pointValue *= 10.0;
      distancePoints = riskDistance / 10.0;
   }
   
   double baseLot = riskAmount / (distancePoints * pointValue);
   if(baseLot <= 0) baseLot = iMinLot;
   
   double adaptFactor = (GetATRFactor() + GetVininIFactor()) / 2.0;
   
   double lot = baseLot * adaptFactor;
   
   double drawdownFactor = GetDrawdownFactor();
   lot = lot * drawdownFactor;
   
   lot = NormalizeLotDynamic(lot);
   if(lot < iMinLot) lot = iMinLot;
   if(lot > iMaxLot) lot = iMaxLot;
   
   if(g_lastLot > 0 && TradingMode == 2) {
      double maxChange = g_lastLot * 0.5;
      if(lot > g_lastLot + maxChange) lot = g_lastLot + maxChange;
      if(lot < g_lastLot - maxChange) lot = g_lastLot - maxChange;
   }
   
   g_lastLot = lot;
   
   return(lot);
}

//+------------------------------------------------------------------+
//| SUPERTRAIL (С ИСПРАВЛЕНИЕМ UNKNOWN TICKET)                       |
//+------------------------------------------------------------------+
void InitTrailLevels()
{
   g_trailLevelsProfit[0] = 100;
   g_trailLevelsSL[0] = 45;
   g_trailLevelsProfit[1] = 200;
   g_trailLevelsSL[1] = 80;
   g_trailLevelsProfit[2] = 350;
   g_trailLevelsSL[2] = 150;
   g_trailLevelsProfit[3] = 500;
   g_trailLevelsSL[3] = 220;
   g_trailLevelsProfit[4] = 700;
   g_trailLevelsSL[4] = 300;
   g_trailLevelsProfit[5] = 900;
   g_trailLevelsSL[5] = 400;
   g_trailLevelsProfit[6] = 1200;
   g_trailLevelsSL[6] = 500;
   g_trailLevelsProfit[7] = 1500;
   g_trailLevelsSL[7] = 600;
   g_trailLevelsProfit[8] = 1800;
   g_trailLevelsSL[8] = 700;
   g_trailLevelsProfit[9] = 2200;
   g_trailLevelsSL[9] = 800;
}

double GetSuperTrailStop(int direction, double currentPrice, double openPrice, double currentSL, int shift)
{
   if(g_point <= 0) return(currentSL);
   
   double trailSL = currentSL;
   double profitPoints = 0;
   double newSL = 0;
   
   if(direction == 1) {
      profitPoints = (currentPrice - openPrice) / g_point;
      
      for(int i = g_trailLevelsCount - 1; i >= 0; i--) {
         if(profitPoints >= g_trailLevelsProfit[i]) {
            newSL = currentPrice - g_trailLevelsSL[i] * g_point;
            break;
         }
      }
      
      if(newSL == 0 && profitPoints >= iTrailStart) {
         double trailValue = iTrailMin;
         double atr = iATR(Symbol(), PERIOD_CURRENT, iTrailATRPeriod, shift);
         if(atr > 0) {
            trailValue = atr * iTrailATRMult / g_point;
            if(trailValue < iTrailMin) trailValue = iTrailMin;
         }
         newSL = currentPrice - trailValue * g_point;
      }
      
      if(newSL > 0 && (currentSL == 0 || newSL > currentSL)) trailSL = newSL;
   }
   else {
      profitPoints = (openPrice - currentPrice) / g_point;
      
      for(int i = g_trailLevelsCount - 1; i >= 0; i--) {
         if(profitPoints >= g_trailLevelsProfit[i]) {
            newSL = currentPrice + g_trailLevelsSL[i] * g_point;
            break;
         }
      }
      
      if(newSL == 0 && profitPoints >= iTrailStart) {
         double trailValue = iTrailMin;
         double atr = iATR(Symbol(), PERIOD_CURRENT, iTrailATRPeriod, shift);
         if(atr > 0) {
            trailValue = atr * iTrailATRMult / g_point;
            if(trailValue < iTrailMin) trailValue = iTrailMin;
         }
         newSL = currentPrice + trailValue * g_point;
      }
      
      if(newSL > 0 && (currentSL == 0 || newSL < currentSL)) trailSL = newSL;
   }
   
   return(trailSL);
}

bool ShouldModifyTrail(int ticket, double currentSL, double newSL)
{
   if(newSL <= 0) return(false);
   if(MathAbs(newSL - currentSL) < g_point * 15) return(false);
   
   if(ticket == g_lastTrailTicket && TimeCurrent() - g_lastTrailUpdate < iTrailUpdateSec) {
      return(false);
   }
   
   g_lastTrailTicket = ticket;
   g_lastTrailUpdate = TimeCurrent();
   g_lastTrailSL = newSL;
   
   return(true);
}

void UpdateTrailOrdersList()
{
   SOrderTrailStep temp[];
   
   for(int i = 0; i < OrdersTotal(); i++) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != Magic) continue;
      if(OrderType() > OP_SELL) continue;
      if(HasLock(OrderTicket())) continue;
      
      // Проверка: ордер не закрыт
      if(OrderCloseTime() != 0) continue;
      
      double profit = OrderProfit() + OrderSwap() + OrderCommission();
      if(profit <= 0) continue;
      
      int idx = ArraySize(temp);
      ArrayResize(temp, idx + 1);
      temp[idx].ticket = OrderTicket();
      temp[idx].type = OrderType();
      temp[idx].open = OrderOpenPrice();
      temp[idx].lot = OrderLots();
      temp[idx].sl = OrderStopLoss();
      temp[idx].trail = (OrderStopLoss() != 0);
   }
   
   ArrayFree(OrdersTrailStep);
   ArrayCopy(OrdersTrailStep, temp);
}

void ProcessSuperTrail()
{
   UpdateTrailOrdersList();
   
   for(int i = 0; i < ArraySize(OrdersTrailStep); i++) {
      RefreshRates();
      
      // Проверка: ордер еще существует и не закрыт
      if(!OrderSelect(OrdersTrailStep[i].ticket, SELECT_BY_TICKET)) continue;
      if(OrderCloseTime() != 0) continue;
      
      if(OrdersTrailStep[i].type == OP_BUY) {
         double newSL = GetSuperTrailStop(1, Bid, OrdersTrailStep[i].open, OrdersTrailStep[i].sl, 0);
         
         if(ShouldModifyTrail(OrdersTrailStep[i].ticket, OrdersTrailStep[i].sl, newSL)) {
            if(OrderSelect(OrdersTrailStep[i].ticket, SELECT_BY_TICKET)) {
               if(OrderCloseTime() == 0) {
                  if(OrderModify(OrdersTrailStep[i].ticket, OrderOpenPrice(), newSL, OrderTakeProfit(), 0)) {
                     Log(StringFormat("SuperTrail BUY: %d SL=%.5f", OrdersTrailStep[i].ticket, newSL));
                     OrdersTrailStep[i].sl = newSL;
                  }
               }
            }
         }
         
         if(Bid > OrdersTrailStep[i].open + iTakeProfit * g_point) {
            if(OrderSelect(OrdersTrailStep[i].ticket, SELECT_BY_TICKET)) {
               if(OrderCloseTime() == 0) {
                  g_allowCloseLossOrders = true;
                  if(OrderClose(OrdersTrailStep[i].ticket, OrdersTrailStep[i].lot, Bid, iSlippage)) {
                     Log("Close TP buy "+(string)OrdersTrailStep[i].ticket);
                     BalanceOrders();
                     UpdateTrailOrdersList();
                     return;
                  }
                  g_allowCloseLossOrders = false;
               }
            }
         }
      }
      else if(OrdersTrailStep[i].type == OP_SELL) {
         double newSL = GetSuperTrailStop(-1, Ask, OrdersTrailStep[i].open, OrdersTrailStep[i].sl, 0);
         
         if(ShouldModifyTrail(OrdersTrailStep[i].ticket, OrdersTrailStep[i].sl, newSL)) {
            if(OrderSelect(OrdersTrailStep[i].ticket, SELECT_BY_TICKET)) {
               if(OrderCloseTime() == 0) {
                  if(OrderModify(OrdersTrailStep[i].ticket, OrderOpenPrice(), newSL, OrderTakeProfit(), 0)) {
                     Log(StringFormat("SuperTrail SELL: %d SL=%.5f", OrdersTrailStep[i].ticket, newSL));
                     OrdersTrailStep[i].sl = newSL;
                  }
               }
            }
         }
         
         if(Ask < OrdersTrailStep[i].open - iTakeProfit * g_point) {
            if(OrderSelect(OrdersTrailStep[i].ticket, SELECT_BY_TICKET)) {
               if(OrderCloseTime() == 0) {
                  g_allowCloseLossOrders = true;
                  if(OrderClose(OrdersTrailStep[i].ticket, OrdersTrailStep[i].lot, Ask, iSlippage)) {
                     Log("Close TP sell "+(string)OrdersTrailStep[i].ticket);
                     BalanceOrders();
                     UpdateTrailOrdersList();
                     return;
                  }
                  g_allowCloseLossOrders = false;
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| STEPTRAIL (заглушка)                                             |
//+------------------------------------------------------------------+
void StepTrailVirtual(void)
{
   return;
}

//+------------------------------------------------------------------+
//| CSBO ФУНКЦИИ (ПОЛНАЯ ЛОГИКА)                                     |
//+------------------------------------------------------------------+
int CollectOrdersInfoCSBO(SOrderInfoCSBO &orders[], bool includeLocks)
{
   ArrayResize(orders, 0);
   int count = 0;
   
   for(int i = 0; i < OrdersTotal(); i++) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != Magic && OrderMagicNumber() != MagicLock) continue;
      if(OrderType() > OP_SELL) continue;
      if(!includeLocks && OrderMagicNumber() == MagicLock) continue;
      
      SOrderInfoCSBO info;
      info.ticket = OrderTicket();
      info.type = OrderType();
      info.openPrice = OrderOpenPrice();
      info.lot = OrderLots();
      info.profit = OrderProfit() + OrderSwap() + OrderCommission();
      info.isPositive = (info.profit > 0);
      
      RefreshRates();
      double currentPrice = (info.type == OP_BUY) ? Bid : Ask;
      info.distance = MathAbs(currentPrice - info.openPrice) / g_point;
      
      ArrayResize(orders, count + 1);
      orders[count] = info;
      count++;
   }
   return count;
}

int ClosePositiveOrdersCSBO(SOrderInfoCSBO &orders[], int count, double &closedProfit)
{
   double totalClosedProfit = 0;
   int closedCount = 0;
   
   for(int i = 0; i < count; i++) {
      if(orders[i].isPositive && OrderSelect(orders[i].ticket, SELECT_BY_TICKET)) {
         RefreshRates();
         double closePrice = (orders[i].type == OP_BUY) ? Bid : Ask;
         
         if(SafeOrderCloseWithCheck(orders[i].ticket, orders[i].lot, closePrice)) {
            totalClosedProfit += orders[i].profit;
            closedCount++;
            Log(StringFormat("CSBO closed +: %d profit=%.2f", orders[i].ticket, orders[i].profit));
         }
      }
   }
   closedProfit = totalClosedProfit;
   return closedCount;
}

int CloseLossOrdersWithControlCSBO(SOrderInfoCSBO &orders[], int count, double totalPositiveProfit, double &closedLossProfit)
{
   int closedCount = 0;
   double remainingProfit = totalPositiveProfit;
   double totalClosedLoss = 0;
   
   int lossIndices[];
   ArrayResize(lossIndices, 0);
   
   for(int i = 0; i < count; i++) {
      if(!orders[i].isPositive) {
         int idx = ArraySize(lossIndices);
         ArrayResize(lossIndices, idx + 1);
         lossIndices[idx] = i;
      }
   }
   
   for(int i = 0; i < ArraySize(lossIndices) - 1; i++) {
      for(int j = i + 1; j < ArraySize(lossIndices); j++) {
         double lossI = -orders[lossIndices[i]].profit;
         double lossJ = -orders[lossIndices[j]].profit;
         if(lossI < lossJ) {
            int temp = lossIndices[i];
            lossIndices[i] = lossIndices[j];
            lossIndices[j] = temp;
         }
      }
   }
   
   for(int idx = 0; idx < ArraySize(lossIndices); idx++) {
      int i = lossIndices[idx];
      double lossAmount = -orders[i].profit;
      
      if(lossAmount <= remainingProfit) {
         if(OrderSelect(orders[i].ticket, SELECT_BY_TICKET)) {
            RefreshRates();
            double closePrice = (orders[i].type == OP_BUY) ? Bid : Ask;
            
            if(SafeOrderCloseWithCheck(orders[i].ticket, orders[i].lot, closePrice)) {
               totalClosedLoss += orders[i].profit;
               remainingProfit -= lossAmount;
               closedCount++;
               Log(StringFormat("CSBO closed -: %d loss=%.2f", orders[i].ticket, -orders[i].profit));
            }
         }
      }
      else {
         Log(StringFormat("CSBO stop: remaining profit %.2f < loss %.2f", remainingProfit, lossAmount));
         break;
      }
   }
   
   closedLossProfit = totalClosedLoss;
   return closedCount;
}

int OpenLocksForRemainingOrdersCSBO(SOrderInfoCSBO &orders[], int count)
{
   int locksOpened = 0;
   
   for(int i = 0; i < count; i++) {
      if(!orders[i].isPositive) {
         RefreshRates();
         double currentDistance;
         if(orders[i].type == OP_BUY)
            currentDistance = (orders[i].openPrice - Bid) / g_point;
         else
            currentDistance = (Ask - orders[i].openPrice) / g_point;
         
         if(currentDistance >= iLockStep) {
            bool hasLock = false;
            for(int j = 0; j < ArraySize(WithLocks); j++)
               if(WithLocks[j] == orders[i].ticket) { hasLock = true; break; }
            
            if(!hasLock) {
               int kneesCount = 0;
               for(int j = 0; j < OrdersTotal(); j++) {
                  if(!OrderSelect(j, SELECT_BY_POS, MODE_TRADES)) continue;
                  if(OrderMagicNumber() != MagicLock) continue;
                  string result[];
                  int split = StringSplit(OrderComment(), '|', result);
                  if(split >= 4 && result[1] == "Lock") {
                     int initTicket = SafeStringToInt(result[3]);
                     if(initTicket == orders[i].ticket) kneesCount++;
                  }
               }
               
               double multiplier = (kneesCount >= iKnees) ? iDownshift : iLockMult;
               
               if(kneesCount < iKnees2) {
                  int lockType = (orders[i].type == OP_BUY) ? OP_SELL : OP_BUY;
                  double lockLot = NormalizeLotDynamic(orders[i].lot * multiplier);
                  
                  if(lockLot > 0) {
                     double price = (lockType == OP_BUY) ? Ask : Bid;
                     string comment = StringFormat("|Lock|%d|%d|", orders[i].ticket, orders[i].ticket);
                     
                     int ticket = OrderSend(Symbol(), lockType, lockLot, NormalizeDouble(price, Digits()), 
                                           iSlippage, 0, 0, comment, MagicLock, 0);
                     
                     if(ticket > 0) {
                        int idx = ArraySize(WithLocks);
                        ArrayResize(WithLocks, idx + 1);
                        WithLocks[idx] = orders[i].ticket;
                        locksOpened++;
                        Log(StringFormat("CSBO lock: %d lot=%.2f", orders[i].ticket, lockLot));
                     }
                  }
               }
            }
         }
      }
   }
   return locksOpened;
}

void CloseSomeByOpposite()
{
   if(!iUseCSBO) return;
   if(TimeCurrent() - g_lastCSBOTime < iCSBOCooldown) return;
   
   int totalOrders = 0;
   double totalProfit = 0;
   int positiveCount = 0;
   int negativeCount = 0;
   
   for(int i = 0; i < OrdersTotal(); i++) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != Magic && OrderMagicNumber() != MagicLock) continue;
      if(OrderType() > OP_SELL) continue;
      totalOrders++;
      
      double profit = OrderProfit() + OrderSwap() + OrderCommission();
      if(profit > 0) {
         totalProfit += profit;
         positiveCount++;
      } else {
         negativeCount++;
      }
   }
   
   bool shouldActivate = false;
   
   if(iMaxOrders > 0 && totalOrders > iMaxOrders) {
      Log(StringFormat("CSBO: Orders limit %d > %d", totalOrders, iMaxOrders));
      shouldActivate = true;
      g_ordersLimitReached = true;
   }
   
   double currentEquity = AccountEquity();
   double netProfit = currentEquity - iInitialDeposit;
   
   if(!g_endLossTriggered && netProfit < 0) {
      double currentLoss = -netProfit;
      if(currentLoss >= iEndLossStart) {
         double lossPercent = currentLoss / iInitialDeposit * 100;
         if(lossPercent >= iEndLossPercent) {
            Log(StringFormat("CSBO: EndLoss %.1f%%", lossPercent));
            shouldActivate = true;
         }
      }
   }
   
   if(!shouldActivate) return;
   
   Log("========== CSBO START ==========");
   g_lastCSBOTime = TimeCurrent();
   g_csboCallCount++;
   g_isReducingOrders = true;
   g_allowCloseLossOrders = true;
   
   SOrderInfoCSBO orders[];
   int orderCount = CollectOrdersInfoCSBO(orders, true);
   
   if(orderCount == 0) {
      Log("CSBO: No orders");
      g_allowCloseLossOrders = false;
      g_isReducingOrders = false;
      return;
   }
   
   Log(StringFormat("CSBO: %d orders (P:%d N:%d)", orderCount, positiveCount, negativeCount));
   
   double positiveProfit = 0;
   int closedPositive = ClosePositiveOrdersCSBO(orders, orderCount, positiveProfit);
   Log(StringFormat("CSBO: Closed +%d profit=%.2f", closedPositive, positiveProfit));
   
   orderCount = CollectOrdersInfoCSBO(orders, true);
   if(orderCount == 0) {
      Log("CSBO: All closed");
      g_allowCloseLossOrders = false;
      g_isReducingOrders = false;
      return;
   }
   
   double lossProfit = 0;
   int closedLoss = CloseLossOrdersWithControlCSBO(orders, orderCount, positiveProfit, lossProfit);
   Log(StringFormat("CSBO: Closed -%d net=%.2f", closedLoss, positiveProfit + lossProfit));
   
   orderCount = CollectOrdersInfoCSBO(orders, true);
   if(orderCount == 0) {
      Log("CSBO: All closed");
      g_allowCloseLossOrders = false;
      g_isReducingOrders = false;
      return;
   }
   
   int locksOpened = OpenLocksForRemainingOrdersCSBO(orders, orderCount);
   Log(StringFormat("CSBO: Opened %d locks", locksOpened));
   
   g_allowCloseLossOrders = false;
   g_isReducingOrders = false;
   Log(StringFormat("========== CSBO END (#%d) ==========", g_csboCallCount));
}

//+------------------------------------------------------------------+
//| CABO - Close All By Opposite                                     |
//+------------------------------------------------------------------+
void CloseAllByOpposite()
{
   RefreshRates();
   Log("CloseAllByOpposite started");
   g_allowCloseLossOrders = true;
   
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != Magic && OrderMagicNumber() != MagicLock) continue;
      if(OrderType() > OP_SELL) continue;
      
      double closePrice = (OrderType() == OP_BUY) ? Bid : Ask;
      SafeOrderCloseWithCheck(OrderTicket(), OrderLots(), closePrice);
   }
   
   g_allowCloseLossOrders = false;
   Log("CloseAllByOpposite completed");
}

//+------------------------------------------------------------------+
//| ПРОВЕРКА ЗАКРЫТИЯ ПО СУММЕ                                       |
//+------------------------------------------------------------------+
void CheckCloseBySum()
{
   double totalProfit = 0;
   double currentEquity = AccountEquity();
   double netProfit = currentEquity - iInitialDeposit;
   
   for(int i = 0; i < OrdersTotal(); i++) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() == Symbol() && (OrderMagicNumber() == Magic || OrderMagicNumber() == MagicLock))
         totalProfit += OrderProfit() + OrderSwap() + OrderCommission();
   }
   
   if(iCloseProfit > 0 && totalProfit >= iCloseProfit) {
      Log(StringFormat("Target profit: %.2f", totalProfit));
      CloseAllByOpposite();
      return;
   }
   
   if(iEndLossPercent > 0 && !g_endLossTriggered && netProfit < 0) {
      double currentLoss = -netProfit;
      if(currentLoss >= iEndLossStart) {
         double lossPercent = currentLoss / iInitialDeposit * 100;
         if(lossPercent >= iEndLossPercent) {
            CloseSomeByOpposite();
         }
      }
   }
}

//+------------------------------------------------------------------+
//| КОНТРОЛЬ КОЛИЧЕСТВА ОРДЕРОВ                                      |
//+------------------------------------------------------------------+
void CheckOrdersCount()
{
   int totalOrders = 0;
   
   for(int i = 0; i < OrdersTotal(); i++) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != Magic && OrderMagicNumber() != MagicLock) continue;
      if(OrderType() > OP_SELL) continue;
      totalOrders++;
   }
   
   if(iMaxOrders > 0 && totalOrders > iMaxOrders && !g_isReducingOrders && !g_ordersLimitReached) {
      Log(StringFormat("Orders limit: %d > %d", totalOrders, iMaxOrders));
      CloseSomeByOpposite();
      g_lastReductionTime = TimeCurrent();
   }
   else if(totalOrders <= iMaxOrders && g_ordersLimitReached) {
      if(TimeCurrent() - g_lastReductionTime > 60) g_ordersLimitReached = false;
   }
}

//+------------------------------------------------------------------+
//| ФУНКЦИИ РАБОТЫ С ЛОКАМИ                                          |
//+------------------------------------------------------------------+
bool HasLock(int ticket)
{
   for(int i = 0; i < OrdersTotal(); i++) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderMagicNumber() != MagicLock) continue;
      string result[];
      if(StringSplit(OrderComment(), '|', result) >= 3 && result[1] == "Lock") {
         int lockTicket = SafeStringToInt(result[2]);
         if(lockTicket == ticket) return(true);
      }
   }
   return(false);
}

void AddToLockArray(int ticket)
{
   for(int i = 0; i < ArraySize(WithLocks); i++)
      if(WithLocks[i] == ticket) return;
   ArrayResize(WithLocks, ArraySize(WithLocks) + 1);
   WithLocks[ArraySize(WithLocks) - 1] = ticket;
}

int FindAllKnees(int initTicket)
{
   int knees = 0;
   for(int i = 0; i < OrdersTotal(); i++) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderMagicNumber() == MagicLock) {
         string result[];
         int splitCount = StringSplit(OrderComment(), '|', result);
         if(splitCount >= 4 && result[1] == "Lock") {
            int ticketInit = SafeStringToInt(result[3]);
            if(ticketInit == initTicket) knees++;
         }
      }
   }
   return(knees);
}

double GetProfitByInitTicket(int ticket)
{
   double profit = 0;
   for(int i = 0; i < OrdersTotal(); i++) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != Magic && OrderMagicNumber() != MagicLock) continue;
      
      bool isInGroup = false;
      if(OrderTicket() == ticket) isInGroup = true;
      else {
         string result[];
         int splitCount = StringSplit(OrderComment(), '|', result);
         if(splitCount >= 4 && result[1] == "Lock") {
            int initTicket = SafeStringToInt(result[3]);
            if(initTicket == ticket) isInGroup = true;
         }
      }
      if(isInGroup) profit += OrderProfit() + OrderSwap() + OrderCommission();
   }
   return(profit);
}

void CloseLockGroup(int initTicket)
{
   Log("Close lock group: " + (string)initTicket);
   
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != Magic && OrderMagicNumber() != MagicLock) continue;
      
      bool isInGroup = false;
      if(OrderTicket() == initTicket) isInGroup = true;
      else {
         string result[];
         if(StringSplit(OrderComment(), '|', result) >= 4 && result[1] == "Lock") {
            int groupId = SafeStringToInt(result[3]);
            if(groupId == initTicket) isInGroup = true;
         }
      }
      
      if(isInGroup) {
         double closePrice = (OrderType() == OP_BUY) ? Bid : Ask;
         SafeOrderCloseWithCheck(OrderTicket(), OrderLots(), closePrice);
      }
   }
}

void Locks(int signal)
{
   RefreshRates();
   
   if(AllowTime(iBeginTime, iEndTime)) {
      for(int i = 0; i < OrdersTotal(); i++) {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
         if(OrderType() >= 2) continue;
         if(OrderSymbol() != Symbol()) continue;
         if(OrderMagicNumber() != Magic && OrderMagicNumber() != MagicLock) continue;
         if(HasLock(OrderTicket())) continue;
         
         double priceDistance;
         if(OrderType() == OP_BUY)
            priceDistance = (OrderOpenPrice() - Bid) / g_point;
         else
            priceDistance = (Ask - OrderOpenPrice()) / g_point;
         
         if(priceDistance >= iLockStep) {
            int initTicket = OrderTicket();
            string result[];
            int splitCount = StringSplit(OrderComment(), '|', result);
            if(splitCount >= 3 && result[1] == "Lock") initTicket = SafeStringToInt(result[3]);
            
            int knees = FindAllKnees(initTicket);
            double lockMult = (knees >= iKnees) ? iDownshift : iLockMult;
            
            if(knees < iKnees2) {
               int lockType = (OrderType() == OP_BUY) ? OP_SELL : OP_BUY;
               double lot = NormalizeLotDynamic(OrderLots() * lockMult);
               
               if(lot > 0 && ((lockType == OP_BUY && signal == 1) || (lockType == OP_SELL && signal == -1))) {
                  double price = (lockType == OP_BUY) ? Ask : Bid;
                  string comment = StringFormat("|Lock|%d|%d|", OrderTicket(), initTicket);
                  Log("LOCK: "+(string)OrderTicket()+" lot="+DoubleToString(lot,2));
                  int ticket = OrderSend(Symbol(), lockType, lot, NormalizeDouble(price, Digits()), iSlippage, 0, 0, comment, MagicLock, 0);
                  if(ticket > 0) AddToLockArray(initTicket);
               }
            }
         }
      }
   }
   
   int closeTickets[];
   for(int i = 0; i < ArraySize(WithLocks); i++) {
      double totalProfit = GetProfitByInitTicket(WithLocks[i]);
      if(totalProfit > iLockProfit) {
         ArrayResize(closeTickets, ArraySize(closeTickets) + 1);
         closeTickets[ArraySize(closeTickets) - 1] = WithLocks[i];
      }
   }
   
   for(int i = 0; i < ArraySize(closeTickets); i++)
      CloseLockGroup(closeTickets[i]);
}

//+------------------------------------------------------------------+
//| ОБЩИЕ ФУНКЦИИ                                                    |
//+------------------------------------------------------------------+
int TotalOrders(int order_type = -1)
{
   int total = 0;
   for(int i = 0; i < OrdersTotal(); i++) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != Magic && OrderMagicNumber() != MagicLock) continue;
      if(order_type != -1 && OrderType() != order_type) continue;
      if(OrderType() < 2) total++;
   }
   return(total);
}

double TotalLots(int order_type)
{
   double lot = 0;
   for(int i = 0; i < OrdersTotal(); i++) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != Magic && OrderMagicNumber() != MagicLock) continue;
      if(order_type != -1 && OrderType() != order_type) continue;
      if(OrderType() < 2) lot += OrderLots();
   }
   return(lot);
}

int LastOrderType()
{
   int type = -1;
   datetime lastTime = 0;
   for(int i = 0; i < OrdersTotal(); i++) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != Magic) continue;
      if(OrderType() < 2 && OrderOpenTime() > lastTime) {
         lastTime = OrderOpenTime();
         type = OrderType();
      }
   }
   return(type);
}

datetime LastOrderTime(int type)
{
   datetime lastTime = 0;
   for(int i = 0; i < OrdersTotal(); i++) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == Magic) {
         if(type == -1 || OrderType() == type)
            if(OrderOpenTime() > lastTime) lastTime = OrderOpenTime();
      }
   }
   return(lastTime);
}

double GetMaxAllowedLot(double requestedLot)
{
   double freeMargin = AccountFreeMargin();
   double marginRequired = MarketInfo(Symbol(), MODE_MARGINREQUIRED);
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
   
   if(marginRequired <= 0) return(0);
   
   double maxLotByMargin = freeMargin / marginRequired;
   double absoluteMaxLot = MathMin(maxLotByMargin, maxLot);
   if(absoluteMaxLot < minLot) absoluteMaxLot = 0;
   
   double resultLot = MathMin(requestedLot, absoluteMaxLot);
   if(resultLot < minLot) resultLot = 0;
   
   return(NormalizeDouble(resultLot, 2));
}

double NormalizeLotMain(double lot)
{
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   if(lot < minLot) lot = minLot;
   if(lot > maxLot) lot = maxLot;
   lot = MathRound(lot / lotStep) * lotStep;
   return(NormalizeDouble(lot, 2));
}

int SendOrder(int type, double lot, double price = 0, double sl = 0, double tp = 0, 
              string comment = "", int magic = -1)
{
   if(magic == -1) magic = Magic;
   if(price == 0) price = (type == OP_BUY) ? Ask : Bid;
   
   double maxAllowedLot = GetMaxAllowedLot(lot);
   if(maxAllowedLot <= 0) return(-1);
   
   if(lot > maxAllowedLot) lot = maxAllowedLot;
   lot = NormalizeDouble(lot, 2);
   
   int ticket = OrderSend(Symbol(), type, lot, NormalizeDouble(price, Digits()), iSlippage,
                          NormalizeDouble(sl, Digits()), NormalizeDouble(tp, Digits()),
                          comment, magic, 0);
   
   if(ticket > 0) {
      LastOpenTime = TimeCurrent();
      Log(StringFormat("OrderSend SUCCESS: %d lot=%.2f", ticket, lot));
   } else {
      Log(StringFormat("OrderSend FAILED: error=%d", GetLastError()));
   }
   return(ticket);
}

void OpenFirstOrder(int signal)
{
   if(g_ordersLimitReached || g_isReducingOrders) return;
   if(g_emergencyTriggered) return;
   
   double lot;
   
   if(iUseDynamicLot)
      lot = GetDynamicLot();
   else
      lot = NormalizeLotMain(iLot);
   
   if(lot <= 0) {
      Log("Lot <= 0, cannot open");
      return;
   }
   
   if(signal == 1) {
      Log(StringFormat("TRY OPEN BUY: signal=%d lot=%.2f", signal, lot));
      if(SendOrder(OP_BUY, lot, 0, 0, 0, "|First|0|") > 0)
         LastStoreLot = lot;
   }
   else if(signal == -1) {
      Log(StringFormat("TRY OPEN SELL: signal=%d lot=%.2f", signal, lot));
      if(SendOrder(OP_SELL, lot, 0, 0, 0, "|First|0|") > 0)
         LastStoreLot = lot;
   }
}

bool ShouldAddOrder(int signal)
{
   if(g_ordersLimitReached || g_isReducingOrders) return(false);
   int lastType = LastOrderType();
   if(lastType == -1) return(false);
   return((lastType == OP_BUY && signal == -1) || (lastType == OP_SELL && signal == 1));
}

void AddOrder(int signal)
{
   if(g_ordersLimitReached || g_isReducingOrders) return;
   if(g_emergencyTriggered) return;
   
   double lot;
   
   if(iUseDynamicLot)
      lot = GetDynamicLot();
   else
      lot = NormalizeLotMain(iLot);
   
   if(lot <= 0) return;
   
   if(signal == -1 && LastOrderType() == OP_BUY) {
      if(SendOrder(OP_SELL, lot, 0, 0, 0, "|Add|0|") > 0)
         LastLowPrice = iLow(Symbol(), PERIOD_CURRENT, 0);
   }
   else if(signal == 1 && LastOrderType() == OP_SELL) {
      if(SendOrder(OP_BUY, lot, 0, 0, 0, "|Add|0|") > 0)
         LastHighPrice = iHigh(Symbol(), PERIOD_CURRENT, 0);
   }
}

void BalanceOrders()
{
   if(!AllowTime(iBeginTime, iEndTime) || iLotBalancePerc == 0) return;
   if(g_ordersLimitReached || g_isReducingOrders) return;
   if(g_emergencyTriggered) return;
   if(TimeCurrent() - g_lastBalanceTime < iBalanceCooldown) return;
   
   RefreshRates();
   
   double lotsBuy = TotalLots(OP_BUY);
   double lotsSell = TotalLots(OP_SELL);
   double ratio = iLotBalancePerc / 100.0 + 1.0;
   double lotsDiff = MathAbs(lotsBuy - lotsSell);
   
   if(lotsDiff < iBalanceMinDiff) return;
   
   if(lotsBuy > lotsSell && lotsBuy > lotsSell * ratio && Signal == -1) {
      double lot = NormalizeLotDynamic(lotsDiff);
      if(lot > 0) {
         Log("Balance: Sell " + DoubleToString(lot, 2));
         SendOrder(OP_SELL, lot, 0, 0, 0, "|Balance|0|");
         LastLowPrice = 0;
         g_lastBalanceTime = TimeCurrent();
      }
   }
   else if(lotsSell > lotsBuy && lotsSell > lotsBuy * ratio && Signal == 1) {
      double lot = NormalizeLotDynamic(lotsDiff);
      if(lot > 0) {
         Log("Balance: Buy " + DoubleToString(lot, 2));
         SendOrder(OP_BUY, lot, 0, 0, 0, "|Balance|0|");
         LastHighPrice = 0;
         g_lastBalanceTime = TimeCurrent();
      }
   }
}

void Reverse()
{
   if(g_ordersLimitReached || g_isReducingOrders) return;
   if(g_emergencyTriggered) return;
   if(LastOrderTime(-1) <= iTime(Symbol(), PERIOD_CURRENT, 0)) return;
   if(!AllowWait() || !AllowTime(iBeginTime, iEndTime)) return;
   if(TimeCurrent() - g_lastReverseTime < iReverseCooldown) return;
   
   double lot;
   
   if(iUseDynamicLot)
      lot = GetDynamicLot();
   else
      lot = NormalizeLotMain(iLot);
   
   if(lot <= 0) return;
   
   if(LastOrderType() == OP_BUY) {
      if(LastHighPrice > 0 && MathAbs(LastHighPrice - iHigh(Symbol(), PERIOD_CURRENT, 0)) > g_point &&
         Bid < iHigh(Symbol(), PERIOD_CURRENT, 0) - iReversePips * g_point) {
         if(SendOrder(OP_SELL, lot, 0, 0, 0, "|Reverse|0|") > 0) {
            LastLowPrice = iLow(Symbol(), PERIOD_CURRENT, 0);
            g_lastReverseTime = TimeCurrent();
         }
      }
   }
   else if(LastOrderType() == OP_SELL) {
      if(LastLowPrice > 0 && MathAbs(LastLowPrice - iLow(Symbol(), PERIOD_CURRENT, 0)) > g_point &&
         Ask > iLow(Symbol(), PERIOD_CURRENT, 0) + iReversePips * g_point) {
         if(SendOrder(OP_BUY, lot, 0, 0, 0, "|Reverse|0|") > 0) {
            LastHighPrice = iHigh(Symbol(), PERIOD_CURRENT, 0);
            g_lastReverseTime = TimeCurrent();
         }
      }
   }
}

int GetSignal()
{
   Ind01_0 = iCustom(Symbol(), PERIOD_CURRENT, "::Indicators\\VininI_BB_MA_WPR5v1n.ex4",
                     Ind01_WPR_Period, Ind01_MA_Period, Ind01_MA_Mode,
                     Ind01_BB_Period, Ind01_BB_Div, Ind01_Limit,
                     Ind01_Buffer, iBar);
   
   Ind01_1 = iCustom(Symbol(), PERIOD_CURRENT, "::Indicators\\VininI_BB_MA_WPR5v1n.ex4",
                     Ind01_WPR_Period, Ind01_MA_Period, Ind01_MA_Mode,
                     Ind01_BB_Period, Ind01_BB_Div, Ind01_Limit,
                     Ind01_Buffer, iBar + 1);
   
   int rawSignal = 0;
   
   if(Bid > iClose(Symbol(), PERIOD_CURRENT, 1) + iDiff * g_point && Ind01_0 > Ind01_1)
      rawSignal = 1;
   else if(Bid < iClose(Symbol(), PERIOD_CURRENT, 1) - iDiff * g_point && Ind01_0 < Ind01_1)
      rawSignal = -1;
   
   if(iReverseSignal) return(-rawSignal);
   return(rawSignal);
}

bool AllowTime(string begin, string end)
{
   if(begin == "00:00" && end == "00:00") return(true);
   datetime now = TimeCurrent();
   datetime time_begin, time_end;
   string today = TimeToString(iTime(NULL, PERIOD_D1, 0), TIME_DATE);
   time_begin = StringToTime(today + " " + begin);
   time_end = StringToTime(today + " " + end);
   if(time_begin < time_end)
      return(now >= time_begin && now < time_end);
   else
      return(now < time_end || now >= time_begin);
}

bool AllowWait()
{
   return(TimeCurrent() > LastOpenTime + iMinWaitOpen);
}

bool HLineCreate(long chart_ID, string name, int sub_window, double price, color clr, ENUM_LINE_STYLE style)
{
   if(!ObjectCreate(chart_ID, name, OBJ_HLINE, sub_window, 0, price)) return(false);
   ObjectSetInteger(chart_ID, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(chart_ID, name, OBJPROP_STYLE, style);
   return(true);
}

void MoveLines()
{
   ObjectMove(0, "TPBuy", 0, 0, TPLevelBuy);
   ObjectMove(0, "SLBuy", 0, 0, SLLevelBuy);
   ObjectMove(0, "TPSell", 0, 0, TPLevelSell);
   ObjectMove(0, "SLSell", 0, 0, SLLevelSell);
}

void InfoShow()
{
   double currentEquity = AccountEquity();
   double netProfit = currentEquity - iInitialDeposit;
   
   int totalOrders = 0;
   for(int i = 0; i < OrdersTotal(); i++) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != Magic && OrderMagicNumber() != MagicLock) continue;
      if(OrderType() > OP_SELL) continue;
      totalOrders++;
   }
   
   double currentLot = (iUseDynamicLot) ? g_lastLot : iLot;
   double equity = AccountEquity();
   double maxEquity = g_maxEquity;
   double drawdown = (maxEquity > 0) ? (maxEquity - equity) / maxEquity * 100 : 0;
   
   string out = "\n";
   out += "=== FGB 01 023 (Emergency from Deposit Only) ===\n";
   out += "Digits: " + IntegerToString(Digits()) + " | Point: " + DoubleToString(g_point, 5) + "\n";
   out += "Balance: " + DoubleToString(g_initialBalance, 2) + "\n";
   out += "Equity: " + DoubleToString(currentEquity, 2) + "\n";
   out += "Net Profit: " + DoubleToString(netProfit, 2) + "\n";
   out += "Drawdown: " + DoubleToString(drawdown, 1) + "%\n";
   out += "Orders: " + IntegerToString(totalOrders) + "/" + IntegerToString(iMaxOrders) + "\n";
   out += "Lot: " + DoubleToString(currentLot, 2) + "\n";
   out += "LockStep: " + IntegerToString(iLockStep) + "\n";
   out += "Trail: " + (iUseSuperTrail ? "SuperTrail" : "StepTrail") + "\n";
   out += "CSBO: " + (iUseCSBO ? "ON" : "OFF") + "\n";
   
   if(g_emergencyTriggered) {
      int remaining = iEmergencyCooldown - (int)(TimeCurrent() - g_emergencyTime);
      if(remaining > 0) out += "EMERGENCY! Resume in: " + IntegerToString(remaining) + " sec\n";
      else out += "EMERGENCY! (cooldown expired)\n";
   } else {
      out += "Status: NORMAL\n";
   }
   
   out += "Signal: " + (Signal == 1 ? "BUY" : (Signal == -1 ? "SELL" : "WAIT")) + "\n";
   out += LogTxt;
   Comment(out);
}

void Log(string txt)
{
   static string output[29];
   for(int i = 1; i < 29; i++) output[i - 1] = output[i];
   output[28] = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS) + " : " +
                DoubleToString(Bid, Digits()) + " : " + txt + "\n";
   LogTxt = "";
   for(int i = 28; i >= 0; i--) LogTxt += output[i];
   Print(txt);
}

//+------------------------------------------------------------------+
//| INIT                                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   g_point = Point();
   if(Digits() == 3 || Digits() == 5) {
      g_point = Point() * 10;
   }
   
   g_initialBalance = AccountBalance();
   g_maxEquity = g_initialBalance;
   g_peakEquity = g_initialBalance;
   
   InitTrailLevels();
   
   Print("========================================");
   Print("FGB 01 023 INITIALIZED (Emergency from Deposit Only)");
   Print("Symbol: ", Symbol());
   Print("Digits: ", Digits());
   Print("g_point: ", DoubleToString(g_point, 8));
   Print("Initial Balance: ", DoubleToString(g_initialBalance, 2));
   Print("Max Orders: ", iMaxOrders);
   Print("LockStep: ", iLockStep);
   Print("Emergency: 30% drawdown from INITIAL DEPOSIT only");
   Print("Cooldown: ", iEmergencyCooldown, " sec");
   Print("========================================");
   
   if(iShowInfo) {
      HLineCreate(0, "TPBuy", 0, 0, iColorTPBuy, iStyleTP);
      HLineCreate(0, "SLBuy", 0, 0, iColorSLBuy, iStyleSL);
      HLineCreate(0, "TPSell", 0, 0, iColorTPSell, iStyleTP);
      HLineCreate(0, "SLSell", 0, 0, iColorSLSell, iStyleSL);
   }
   
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   Comment("");
}

//+------------------------------------------------------------------+
//| TICK                                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!TotalOrders(OP_BUY)) { TPLevelBuy = 0; SLLevelBuy = 0; }
   if(!TotalOrders(OP_SELL)) { TPLevelSell = 0; SLLevelSell = 0; }
   
   // Проверка разблокировки после emergency
   CheckEmergencyUnblock();
   
   // Проверка аварийных условий
   if(IsEmergency()) {
      EmergencyCloseAll();
   }
   
   // Если emergency активен - не торгуем
   if(g_emergencyTriggered) {
      if(iShowInfo) {
         MoveLines();
         InfoShow();
      }
      return;
   }
   
   int signal = GetSignal();
   Signal = signal;
   
   static datetime lastSignalLog = 0;
   if(signal != 0 && TimeCurrent() - lastSignalLog > 30) {
      Log(StringFormat("SIGNAL: %d (Bid=%.5f, iDiff=%d)", signal, Bid, iDiff));
      lastSignalLog = TimeCurrent();
   }
   
   Locks(signal);
   CheckCloseBySum();
   CheckOrdersCount();
   
   if(iUseSuperTrail) {
      ProcessSuperTrail();
   }
   
   if(AllowTime(iBeginTime, iEndTime) && !g_emergencyTriggered) {
      if(TotalOrders(-1) == 0) {
         if(signal != 0) {
            OpenFirstOrder(signal);
         }
      }
      else if(ShouldAddOrder(signal) && AllowWait()) {
         AddOrder(signal);
      }
      BalanceOrders();
   }
   
   if(iReverse) Reverse();
   
   double equity = AccountEquity();
   if(equity > g_maxEquity) g_maxEquity = equity;
   if(equity > g_peakEquity) g_peakEquity = equity;
   
   if(iShowInfo) {
      MoveLines();
      InfoShow();
   }
}
//+------------------------------------------------------------------+