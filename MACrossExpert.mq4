//+------------------------------------------------------------------+
//|                                                MACrossExpert.mq4 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

#property copyright "Copyright 2023, Taj."
#property link      "https://www.mql5.com"
#property description "Developed by Atikur Rahman"

#property strict

// Trade
#include <ValidatorTech/Frameworks/Framework_1.0/Trade/Trade.mqh>

// Indicators
#include <ValidatorTech/MovingAverage/MAIndicator.mqh>
#include <ValidatorTech/MovingAverage/MATouchSignal.mqh>
#include <ValidatorTech/MovingAverage/MACrossoverSignal.mqh>

// Utility Classes
#include <ValidatorTech/UtilityClasses/UtilityFunctions.mqh>


input string            ExpertPermission        =  ">>>>>>>>>>    Expert Permission    <<<<<<<<<<";   // Expert Permission
input bool              IsExpertAllowedToTrade  =  true;       // Is Expert Allowed To Trade


input string            MASetting           =  ">>>>>>>>>>    Moving Average Setting    <<<<<<<<<<";   // Moving Average Setting
input int               Slow_MA_Period      =  50;
input ENUM_MA_METHOD    Slow_MA_Method      =  MODE_SMA;

input int               Fast_MA_Period      =  50;
input ENUM_MA_METHOD    Fast_MA_Method      =  MODE_SMA;

input bool              UsePreviousCandle   = false;  // Use previous candle close for MA cross
input bool              UseCurrentCandle    = false;  // Use current candle for MA cross


input string            OrderSettings        =  ">>>>>>>>>>    Order Settings    <<<<<<<<<<";   // Order Settings
input double            OrderLotSize        = 0.01;   // Order lot size
input int               OrderTP             = 100;    // Order take profit
input int               OrderSL             = 50;     // Order stop loss
input bool              UseMASLTP           = false;  // Use MA cross as SL TP
input bool              UseManualSLTP       = false;  // Use manual SL TP


input string   MagicComments = "<=========    Magic, Comments     =========>";
input int               Magic               =  123456;// Magic Number
input string            OrderComments       =  "";    // Order Comments



int mDigits;                              // Current Symbol Digit
string mSymbol;                           // Current Chart Symbol
ENUM_TIMEFRAMES cPeriod;                  // Current Chart Time Period 

// Trade class
CTradeCustom Trade;
CPositionInfoCustom PositionInfo;

// Moving Average Indicator Classes
CMAIndicator *slowMA, *fastMA;
CMACrossoverSignal *crossoverSignal;

bool newBar = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
//---

   mSymbol  =  Symbol();
   cPeriod  =  Period();
   mDigits  =  (int)SymbolInfoInteger(mSymbol, SYMBOL_DIGITS);   
      
   Trade.SetExpertMagicNumber(Magic);
   
   //
   MovingAverageSetup();
   
   IsNewBar(true);
   
//---
   return(INIT_SUCCEEDED);
}


//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
//---
   delete slowMA;
   delete fastMA;
   delete crossoverSignal;
}


//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
//---

   if(!IsExpertAllowedToTrade) return;
   
   
   // Returen true value, if new bar is generated, otherwise return false
   newBar = IsNewBar(true);
   
   if(newBar) {
      string message = crossoverSignal.CrossoverSignal();
      //Print("message: " + message);
      
      if(OrdersTotal() > 0 && StringLen(message) > 0) {
         //Print("Existing Order will close: ", message);
         closeAllPositions();
         
         if(StringLen(message) > 0 && StringFind(message, "BUY") >= 0) {
            //Print("111 Re-entry BUY: ", message);
            placeOrders(ORDER_TYPE_BUY);
         }
         else if(StringLen(message) > 0 && StringFind(message, "SELL") >= 0) {
            //Print("111 Re-entry SELL: ", message);
            placeOrders(ORDER_TYPE_SELL);
         }
      } 
      else if(OrdersTotal() == 0){
         if(StringLen(message) > 0 && StringFind(message, "BUY") >= 0) {
            //Print("111 MA Cross message: ", message);
            placeOrders(ORDER_TYPE_BUY);
         }
         else if(StringLen(message) > 0 && StringFind(message, "SELL") >= 0) {
            //Print("222 MA Cross message: ", message);
            placeOrders(ORDER_TYPE_SELL);
         }
      }
   } 
   else {
   
   }
}
//+------------------------------------------------------------------+

void placeOrders(ENUM_ORDER_TYPE orderType) {
   //Print("mSymbol: ", mSymbol, ", Symbol(): ", Symbol(), ", Magic: ", Magic,  ", trade magic: ", trade.RequestMagic());
   
   double buyEntry   =  NormalizeDouble(SymbolInfoDouble(mSymbol, SYMBOL_ASK), mDigits);
   double sellEntry  =  NormalizeDouble(SymbolInfoDouble(mSymbol, SYMBOL_BID), mDigits);
   //double entry    =  SymbolInfoDouble(mSymbol, SYMBOL_LAST);
  
   double sl = 0.0, tp = 0.0, lot = OrderLotSize;

   if(orderType == ORDER_TYPE_BUY) {
      // Calculate pending order gaps with entry price
      lot   =  MathMin(lot,SymbolInfoDouble(mSymbol,SYMBOL_VOLUME_MAX));
      lot   =  MathMax(lot,SymbolInfoDouble(mSymbol,SYMBOL_VOLUME_MIN));  
     
      if(OrderSL > 0 && UseManualSLTP) sl =  buyEntry - PipsToPrice(OrderSL, mSymbol);
      if(OrderTP > 0 && UseManualSLTP) tp =  buyEntry + PipsToPrice(OrderTP, mSymbol);
      //sl =  buyEntry - PipsToPrice(100, mSymbol);
      //tp    =  calculatTP(buyEntry, mOrderType);
      executeBuy(buyEntry, sl, tp, lot, 0, OrderComments); 
      
      
   }
   else if(orderType == ORDER_TYPE_SELL) {
      // Calculate pending order gaps with entry price
      lot   =  MathMin(lot,SymbolInfoDouble(mSymbol,SYMBOL_VOLUME_MAX));
      lot   =  MathMax(lot,SymbolInfoDouble(mSymbol,SYMBOL_VOLUME_MIN));
      
      
      if(OrderSL > 0 && UseManualSLTP) sl =  buyEntry + PipsToPrice(OrderSL, mSymbol);
      if(OrderTP > 0 && UseManualSLTP) tp =  sellEntry - PipsToPrice(OrderTP, mSymbol);
      //sl    =  calculatSL(sellEntry, mOrderType);
      //sl =  sellEntry + PipsToPrice(100, mSymbol);
      //tp    =  calculatTP(sellEntry, mOrderType);
      executeSell(sellEntry, sl, tp, lot, 0, OrderComments); 
      
   }

}


// Moving Average Indicator Setup
void MovingAverageSetup() {
   
   // Touch or Break the Moving Average Strategy
   slowMA   = new CMAIndicator(mSymbol, PERIOD_CURRENT, Slow_MA_Period, 0, Slow_MA_Method, PRICE_CLOSE);
   fastMA   = new CMAIndicator(mSymbol, PERIOD_CURRENT, Fast_MA_Period, 0, Fast_MA_Method, PRICE_CLOSE);
   
   // Crossover Signal
   if(UsePreviousCandle)
      crossoverSignal         =  new CMACrossoverSignal(1, 2, 3, fastMA, slowMA);
   if(UseCurrentCandle)
      crossoverSignal         =  new CMACrossoverSignal(0, 1, 2, fastMA, slowMA);
   
}


// Check if there is a new bar has created
bool IsNewBar(bool first_call = false) {
   
   static bool result = false;
   if(!first_call) return result;
   
   //Print("first_call = "+first_call);
   static datetime previousBarTime = 0;
   datetime currentBarTime = iTime(Symbol(), Period(), 0);
   result = false;
   
   if(currentBarTime != previousBarTime) {
      previousBarTime = currentBarTime;
      result = true;
   }
   
   return result;
}


//+------------------------------------------------------------------+
//| Order BUY & SELL function                                             |
//+------------------------------------------------------------------+

void executeBuy(double entry, double slPrice, double tpPrice, double lots, 
                int orderExecutionType, string comment) {
   //return;
   bool result = false, IsEntryPriceEmpty = false;
   //while(!result) {
      
      if(entry <= 0) IsEntryPriceEmpty = true;
      
      double tp = 0.0, sl = 0.0;
      entry = (entry > 0) ? NormalizeDouble(entry, mDigits) : 
                               NormalizeDouble(SymbolInfoDouble(mSymbol, SYMBOL_ASK), mDigits);
      
      if(tpPrice > 0) {
         if(IsEntryPriceEmpty) tp = NormalizeDouble(entry+tpPrice, mDigits);
         else tp = NormalizeDouble(tpPrice, mDigits);  
      }   
      
      if(slPrice > 0) {
         if(IsEntryPriceEmpty) sl = NormalizeDouble(entry-tpPrice, mDigits);
         else sl = NormalizeDouble(slPrice, mDigits);   
      } 
      
      if(lots > 0.0) lots = lots;      
      if(lots <= 0.0) {
         Alert("Please enter a valid lot size.");
         return;
      }
  
      
      //Print("222 entry: "+entry+", sl: "+sl+", tp: "+tp+", lots: "+lots+ ", tradeType: "+tradeType
      //   +", orderExecutionType: "+orderExecutionType+", comment: "+comment);
         
      if(orderExecutionType == 0) {
         result = Trade.Buy(lots, mSymbol, entry, sl, tp, comment);
         //buyPos = trade.ResultOrder();
         //Print("111 result: "+result);
      }
      
   //}
}


void executeSell(double entry, double slPrice, double tpPrice, double lots, 
                  int orderExecutionType, string comment) {
   //return;
   bool result = false, IsEntryPriceEmpty = false;
   //while(!result) {
      
      if(entry <= 0) IsEntryPriceEmpty = true;
   
      double tp = 0.0, sl = 0.0;
      entry = (entry > 0) ? NormalizeDouble(entry, mDigits) : 
                               NormalizeDouble(SymbolInfoDouble(mSymbol, SYMBOL_BID), mDigits);
      
      
      if(tpPrice > 0) {
         if(IsEntryPriceEmpty) tp = NormalizeDouble(entry-tpPrice, mDigits);
         else tp = NormalizeDouble(tpPrice, mDigits);  
      }   
      
      if(slPrice > 0) {
         if(IsEntryPriceEmpty) sl = NormalizeDouble(entry+tpPrice, mDigits);
         else sl = NormalizeDouble(slPrice, mDigits);  
      }   
   
      if(lots > 0.0) lots = lots;
      if(lots <= 0.0) {
         Alert("Please enter a valid lot size.");
         return;
      }
      
   
      //Print("333 entry: "+entry+", sl: "+sl+", tp: "+tp+", lots: "+lots + ", tradeType: "+tradeType
      //   +", orderExecutionType: "+orderExecutionType+", comment: "+comment);
      
      if(orderExecutionType == 0) {
         result = Trade.Sell(lots, mSymbol, entry, sl, tp, comment);
         //sellPos = trade.ResultOrder();
         //Print("222 result: "+result);
      }
    
   //}      
}


//+------------------------------------------------------------------+
//| Order close function                                             |
//+------------------------------------------------------------------+
void closeAllPositions() {

   // delete all positions and pending orders
   for(int i = OrdersTotal()-1; i >= 0; i--){
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
         int ticket = OrderTicket();
         if(ticket > 0) { 
            if((OrderType() == OP_BUY || OrderType() == OP_SELL) && 
               (OrderSymbol() == mSymbol) && (OrderMagicNumber() == Magic)) {
               bool result = false;
               result = OrderClose(ticket, OrderLots(), OrderClosePrice(), 0, clrNONE);
               if(!result) {
                  Print("Error in OrderDelete. Error code=",GetLastError()); 
               }
            }
            else
            if((OrderType() == OP_BUYSTOP || OrderType() == OP_BUYLIMIT || 
               OrderType() == OP_SELLSTOP || OrderType() == OP_SELLLIMIT) && 
               (OrderSymbol() == mSymbol) && (OrderMagicNumber() == Magic)) {
               bool result = false;
               result = OrderDelete(ticket);
               if(!result) {
                  Print("Error in OrderDelete. Error code=",GetLastError()); 
               } 
            }
         }
      }
   }
}