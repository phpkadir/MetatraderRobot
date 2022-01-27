//  Metatrader 4 only works well and you should checkout periodically.
// This version Pipmaker_V13_1 by Enforcer has been modified from the PipMakerV10.
// All orders are now closed when ProfitTarget is reached to eliminate outlying orders from building up negative equity.
// Multiplier/CounterTrendMultiplier now acts as Martingale - doubling lot size at Spacing pips away in opposite trend from initial order (CounterTrendMultiplier) or
// at TrendSpacing intervals in same direction of initial order if set to "1".
// Added option for a stop loss on each order but not profitable when used in backtests.
// This EA allows for both Buy and Sell orders at the same time in the same currency which will act as a hedge until the prevailing trend resumes thus limiting
// drawdown.  This obviously won't work if your broker does not allow hedging.
//Enforcer's addons/changes/fixes:
//- Loss Management - orders that fall below max alowed loss are closed and optionally a recovery order is placed
//- Added iTrend indicator
//- Added reverse signal option
// - Added more take profit methods - close all orders when profit reach profit target (old mode), close if buys or sells reach 
// profit target and mixed mode, which one comes first (best)
// - Added MoneyManagement, wii calculate lot size, lot increment and profit target
// - Replaced DPO with TMA (triple moving average)
// - Reworked CCI to trigger at specified level
// - Added Forced start option
// - Added AutoSpacing, default spacing will be calculated by StdDev
// - removed VarySpacing by number of orders
// - Added ARSI indicator (Adaptive RSI - external)
// - Added ProfitTrailing option
// - added ProfitSkew option - will modify default ProfitTarget when MoneyManagement=true
// - added ATR as option for ARSI trigger
// - added Fisher indicator by yast77
// - god bless me
#include <stdlib.mqh>
#include <stderror.mqh>
#define  NL    "\n"

// Regular variables
extern bool    TradeShort              = true; //Allow place sell ordes
extern bool    TradeLong               = true; //Allow place buy orders

extern bool    UseTMA                  = false; //Triple moving average
extern int     MAperiod                = 240;

extern bool    UseARSI                = true;  //Adaptive RSI
extern int     RSI_period             = 5;    // TF for ARSI
extern int     RSI_bars               = 28;    // lenght of ARSI
extern double  ARSI_trigger           = 0; // level to trigger trade. If = 0 will be used ATR as automatic trigger level

extern bool    UseCCI                 = false;
extern int     CCI_Period             = 60; // CCi time frame
extern int     CCI_lenght             = 60; //CCI bars
extern int     cci_trigger            = 25; // +/- level. lower value = enter in trade faster

extern bool    Use_iTrend              = true;
extern int     iTrendPeriod            = 60; //iTrend TF

extern bool    Use_Fisher                = true;
extern int     FisherPeriod            = 60; //Fisher TF
extern int     Fisher_Bars             = 10; //Fisher indicator bars
extern double  Buy_Enter_Level         = 1.5; //Buy enter level
extern double  Sell_Enter_Level         = -1.5; //Sell enter level

extern bool    ReverseDirection        = true; // true = will trade long when price is low and short and price is high. false = will trade long when price is high and short when price is low


extern bool    MoneyMangement          = true; //will autocalculate lot size, lot increment and profit target
extern bool    MicroAccount            = false; //will divide LotSize by 10
extern double  MaximumRisk             = 0.1;  // 1 mean 0.1% of balance
extern double  LotSize                 = 0.1; //NULL if MoneyMangement is true
extern double  LotIncrement            = 0.1; //NULL if MoneyMangement is true
extern double  Multiplier              = 0;  // Will increase orders in Martingale fashion in direction of trend if set to "1". Used with TrendSpacing only.
extern double  CounterTrendMultiplier  = 0;  // Will increase orders in Martingale fashion in opposite direction of trend if set to "1". Used with Spacing only.

extern double  ProfitTarget            = 10;  // All orders closed when this profit target amount (in dollars) is reached
extern double  ProfitSkew              = 2;  // Increase/decrease ProfitTarget when MoneyMangement=true
extern int     ProfitMode              = 1;  // 1= mixed mode, 2= global mode, 3= split mode
extern bool    ProfitTrailing          = true;  // Will try to allow profit grow beyond ProfitTarget
extern double  MaxRetrace              = 2;  // Maximum percent of MaxProfit allowed to decrease before close all orders

extern int     ForcedStart             = 0;  // 1 = New cycle will start if signal is for long, 2 = New cycle will start if signal is for short, 0 = disabled
extern double  SL                      = 999;  // Performs better with no initial stoploss.

extern bool    AutoSpacing             = true;  //Spacing will be calculated using stdDev
extern int     StDevTF                 = 60;    // TF for StDev
extern int     StDevPer                = 14;    // lenght of StDev
extern int     StDevMode               = MODE_EMA; // mode of StDev - 0=SMA, 1=EMA, 2=SMMA, 3=LWMA 
extern int     Spacing                 = 15; // Minimum distance of orders placed against the trend of the initial order, In effect only if AutoSpacing=false
extern int     TrendSpacing            = 15; // Minimum distance of orders placed with the trend of the initial order (set to 1000 to disable )

extern int     CloseDelay              = 121; // Minimum close time for IBFX to not be considered scalping
extern bool    CeaseTrading            = false;
extern string  PauseTrading            ="Pause Trading at Timeinterval";
extern int     StartTime               = 0; //Example: Trading pause starts at day 15 hour 14, minute 30 (server time)--> input= 151430
extern int     EndTime                 = 0; //Example: Trading pause ends at day 15 hour 15, minute 10 (server time)--> input= 151510
extern string  QuitTrading             = "Quit Trading at Time";
extern int     endDayHourMinute        = 0; //Example: Quit trading on day 17 hour 21 minute 59 (server time)-->input=172159
extern bool    RightSideLabel          = false;
extern int     SessionTarget           = 10000; //Trading will be stopped if this amount has been earned in this session
extern int     MaximumBuyOrders        = 100;
extern int     MaximumSellOrders       = 100;
 
extern string  LossManagement         = "What to do if things are going wrong";
extern string  Warning                = "This feature is in early stage and is not finished!";
extern bool    AllowRecovery          = false;   //enable/disable loss management
extern double  MaxLossPercent         = 1;      //maximum loss in balance procents 1=1% max loss
extern bool    ExitAllTrades          = true;   //Close all open orders
extern bool    StopTrading            = true;   //stop trading if loss management was triggered
extern bool    PlaceRecoveryOrders    = true;   //Use counter orders to get in profit
extern int     MaxRecoveryOrders      = 2;      //max extra orders to use for recovery
extern double  RecoveryTakeProfit     = 5;      //take profit in points
extern double  RecoveryStopLoss       = 200;     //stop loss in points
extern double  RecoveryLotMultiplier  = 1;     //lot size is auto calculated for USD based pairs. Increase or decrease according to pair used.
extern bool    RecReverse             = false;  // reverse direction of recovery trading

// Internal settings
//int            Step           = 1;
string EA_name                = "PipMaker_v15_3";
double         stoploss       = 0;
int            Error          = 0;
int            Order          = 0;
int            Slippage       = 2;
int            Reference      = 0;
string         TradeComment;
int            MaxBuys        = 0;
int            MaxSells       = 0;
double         MaxProfit      = 0;
bool           Auditing       = false;
string         Filename;
double         initialBalance;
int            lotPrecision;
bool           TradeAllowed   = true;
bool           CloseBuysNOW; 
bool           CloseSellsNOW; 
bool           CloseAllNOW;

int init()
{
   if (Symbol() == "AUDCADm" || Symbol() == "AUDCAD") Reference = 801001;
   if (Symbol() == "AUDJPYm" || Symbol() == "AUDJPY") Reference = 801002;
   if (Symbol() == "AUDNZDm" || Symbol() == "AUDNZD") Reference = 801003;
   if (Symbol() == "AUDUSDm" || Symbol() == "AUDUSD") Reference = 801004;
   if (Symbol() == "CHFJPYm" || Symbol() == "CHFJPY") Reference = 801005;
   if (Symbol() == "EURAUDm" || Symbol() == "EURAUD") Reference = 801006;
   if (Symbol() == "EURCADm" || Symbol() == "EURCAD") Reference = 801007;
   if (Symbol() == "EURCHFm" || Symbol() == "EURCHF") Reference = 801008;
   if (Symbol() == "EURGBPm" || Symbol() == "EURGBP") Reference = 801009;
   if (Symbol() == "EURJPYm" || Symbol() == "EURJPY") Reference = 801010;
   if (Symbol() == "EURUSDm" || Symbol() == "EURUSD") Reference = 801011;
   if (Symbol() == "GBPCHFm" || Symbol() == "GBPCHF") Reference = 801012;
   if (Symbol() == "GBPJPYm" || Symbol() == "GBPJPY") Reference = 801013;
   if (Symbol() == "GBPUSDm" || Symbol() == "GBPUSD") Reference = 801014;
   if (Symbol() == "NZDJPYm" || Symbol() == "NZDJPY") Reference = 801015;
   if (Symbol() == "NZDUSDm" || Symbol() == "NZDUSD") Reference = 801016;
   if (Symbol() == "USDCHFm" || Symbol() == "USDCHF") Reference = 801017;
   if (Symbol() == "USDJPYm" || Symbol() == "USDJPY") Reference = 801018;
   if (Symbol() == "USDCADm" || Symbol() == "USDCAD") Reference = 801019;
   if (Symbol() == "USDTRYm" || Symbol() == "USDTRY") Reference = 801020;
   if (Reference == 0) Reference = 801999;
   initialBalance= AccountBalance();   
   TradeComment  = StringConcatenate(Symbol()," ",Period()," ",EA_name);      
   Filename = StringConcatenate(EA_name+"_",Symbol(),"_",Period(),"_M",".txt");
   CalculateLotPrecision();
   CloseBuysNOW  = false; CloseSellsNOW = false; CloseAllNOW = false;
   return(0);
}

int deinit()
{
   if(ObjectFind("MidPoint")==0){
      ObjectDelete("MidPoint");      
   }
   if(ObjectFind("MarginPercent")==0){
      ObjectDelete("MarginPercent");
   }
   if(ObjectFind("LowMarginPercent")==0){
      ObjectDelete("LowMarginPercent");
   }   
   Comment("");
   return(0);
}

void CalculateLotPrecision(){
   double lotstep=MarketInfo(Symbol(),MODE_LOTSTEP);
   if(lotstep==1) lotPrecision=0;
   if(lotstep==0.1) lotPrecision=1;
   if(lotstep==0.01) lotPrecision=2;
   if(lotstep==0.001) lotPrecision=3;
}

double AutoLot()
  {
   double lot;
   //lot=NormalizeDouble(AccountFreeMargin()*MaximumRisk/10000.0,2);
   lot=NormalizeDouble(AccountBalance()/10000,lotPrecision)*MaximumRisk;
   if(MicroAccount)lot=NormalizeDouble(lot/10,lotPrecision);

   if(lot<0.01) lot=0.01;
   return(lot);
  }


int RecoveryOrders(){
int RecTotal=0;
int cnt;
   for(cnt=0;cnt<OrdersTotal();cnt++)
   {
      OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
      if(OrderMagicNumber() == Reference * 2 && OrderComment()=="Rec" && OrderSymbol()==Symbol())
      RecTotal++;
   }
   return (RecTotal);
}


void PlaceBuyOrder()
{
   double BuyOrders, Lots;
   double LowestBuy = 1000, HighestBuy;
   
   if(MoneyMangement)
   {
    LotSize=AutoLot();
   if(LotIncrement>0) LotIncrement=LotSize;
    }

   RefreshRates();
   for (Order = OrdersTotal() - 1; Order >= 0; Order--)
   {
      if (OrderSelect(Order, SELECT_BY_POS, MODE_TRADES))
      {
         if (OrderSymbol() == Symbol() && OrderMagicNumber() == Reference && OrderType() == OP_BUY)
         {
            if (OrderOpenPrice() < LowestBuy) LowestBuy = OrderOpenPrice();
            if (OrderOpenPrice() > HighestBuy) HighestBuy = OrderOpenPrice();
            BuyOrders++;
         }
      }
   }

   if (Ask >= HighestBuy + (TrendSpacing * Point))
   {
      if (Multiplier == 1)
         Lots = NormalizeDouble(MathPow(2,BuyOrders)*LotSize, lotPrecision);
      else
         Lots = NormalizeDouble(LotSize + (LotIncrement * BuyOrders), lotPrecision);
   }

   if (Ask <= LowestBuy - (Spacing * Point))
   {
      if (CounterTrendMultiplier == 1)
         Lots = NormalizeDouble(MathPow(2,BuyOrders)*LotSize, lotPrecision);
      else
         Lots = NormalizeDouble(LotSize + (LotIncrement * BuyOrders), lotPrecision);
   }

   if(BuyOrders==0)
   {
      Lots = NormalizeDouble(LotSize, lotPrecision);
   }

   if (Lots == 0)
   {
      if (Multiplier == 1)
         Lots = NormalizeDouble(LotSize, lotPrecision);
      else
         Lots = NormalizeDouble(LotSize, lotPrecision);
   }
   
   if(IsTradeAllowed()==true  && BuyOrders < MaximumBuyOrders)
   {
      if (SL == 0) stoploss = 0; else stoploss = Ask - (SL * Point);
      OrderSend(Symbol(), OP_BUY, Lots, Ask, Slippage, stoploss, 0, TradeComment, Reference,0, Blue);
   }

   Error = GetLastError();
   if (Error != 0)
      Write("Error opening BUY order: " + ErrorDescription(Error) + " (C" + Error + ")  Ask:" + Ask + "  Slippage:" + Slippage);
}

void PlaceSellOrder()
{
   double SellOrders, Lots;
   double HighestSell, LowestSell = 1000;
   
   if(MoneyMangement)
   {
    LotSize=AutoLot();
   if(LotIncrement>0) LotIncrement=LotSize;
   }
   
   RefreshRates();
   for (Order = OrdersTotal() - 1; Order >= 0; Order--)
   {
      if (OrderSelect(Order, SELECT_BY_POS, MODE_TRADES))
      {
         if (OrderSymbol() == Symbol() && OrderMagicNumber() == Reference && OrderType() == OP_SELL)
         {
            if (OrderOpenPrice() > HighestSell) HighestSell = OrderOpenPrice();
            if (OrderOpenPrice() < LowestSell) LowestSell = OrderOpenPrice();
            SellOrders++;
         }
      }
   }

   if (Bid <= LowestSell - (TrendSpacing * Point))
   {
//         if (Multiplier)
      if (Multiplier == 1)
         Lots = NormalizeDouble(MathPow(2,SellOrders)*LotSize, lotPrecision);
      else
         Lots = NormalizeDouble(LotSize + (LotIncrement * SellOrders), lotPrecision);
   }
   
   if (Bid >= HighestSell + (Spacing * Point))
   {
//         if (Multiplier)
      if (CounterTrendMultiplier == 1)
         Lots = NormalizeDouble(MathPow(2,SellOrders)*LotSize, lotPrecision);
      else
        Lots = NormalizeDouble(LotSize + (LotIncrement * SellOrders), lotPrecision);
   }

   if(SellOrders==0)
   {
      Lots = NormalizeDouble(LotSize, lotPrecision);
   }

   if (Lots == 0)
   {
//         if (Multiplier) 
      if (Multiplier == 1)
         Lots = NormalizeDouble(LotSize, lotPrecision);
      else
         Lots = NormalizeDouble(LotSize, lotPrecision);
   }
   
   if(IsTradeAllowed()==true && SellOrders < MaximumSellOrders)
   {  
      if (SL == 0) stoploss = 0; else stoploss = Bid + (SL * Point); 
      OrderSend(Symbol(), OP_SELL, Lots, Bid, Slippage, stoploss, 0, TradeComment, Reference,0, Red);
   }
   
   Error = GetLastError();
   if (Error != 0)
      Write("Error opening SELL order: " + ErrorDescription(Error) + " (D" + Error + ")  Bid:" + Bid + "  Slippage:" + Slippage);
}

void CloseAllBuyProfit()
{
int spread=MarketInfo(Symbol(),MODE_SPREAD);
   for(int i = OrdersTotal()-1; i >=0; i--)
       {
       OrderSelect(i, SELECT_BY_POS);
       bool result = false;
       if (OrderSymbol()==Symbol() && OrderMagicNumber() == Reference && OrderType() == OP_BUY)  
         {
            int Retry=0; while (Retry<5 && !IsTradeAllowed()) { Retry++; Sleep(2000); }
            if (TimeCurrent()-OrderOpenTime() >= CloseDelay) result = OrderClose( OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(), MODE_BID), 0, Aqua );
         }
       }
     
  return; 
}

void CloseAllSellProfit()
{
int spread=MarketInfo(Symbol(),MODE_SPREAD);
   for(int i = OrdersTotal()-1; i >=0; i--)
      {
      OrderSelect(i, SELECT_BY_POS);
      bool result = false;
      if (OrderSymbol()==Symbol() && OrderMagicNumber() == Reference && OrderType() == OP_SELL) 
       {
         int Retry=0; while (Retry<5 && !IsTradeAllowed()) { Retry++; Sleep(2000); }
         if (TimeCurrent()-OrderOpenTime() >= CloseDelay) result = OrderClose( OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(), MODE_ASK), 0, Lime );
       }
     }
 
  return; 
}

int start()
{
   double         MarginPercent;
   static double  LowMarginPercent = 10000000, LowEquity = 10000000;
   double         BuyPipTarget, SellPipTarget;
   int            SellOrders, BuyOrders;
   double         BuyPips, SellPips, BuyLots, SellLots;
   double         LowestBuy = 999, HighestBuy = 0.0001, LowestSell = 999, HighestSell = 0.0001, HighPoint, MidPoint, LowPoint;
   double         Profit = 0, BuyProfit = 0, SellProfit = 0, PosBuyProfit = 0, PosSellProfit = 0;
   int            HighestBuyTicket, LowestBuyTicket, HighestSellTicket, LowestSellTicket;
   double         HighestBuyProfit, LowestBuyProfit, HighestSellProfit, LowestSellProfit;
   bool           SELLme = false;
   bool           BUYme = false;
   double         Margin = MarketInfo(Symbol(), MODE_MARGINREQUIRED);
   string         Message;

   

   for (Order = OrdersTotal() - 1; Order >= 0; Order--)
   {
      if (OrderSelect(Order, SELECT_BY_POS, MODE_TRADES))
      {
         if (OrderSymbol() == Symbol() && OrderMagicNumber() == Reference)
         {
            
            Profit = OrderProfit() + OrderSwap() + OrderCommission();
            
            if (OrderType() == OP_BUY)
            {
               if (OrderOpenPrice() >= HighestBuy)
               {
                  HighestBuy = OrderOpenPrice();
                  HighestBuyTicket = OrderTicket();
                  HighestBuyProfit = Profit;
               }

               if (OrderOpenPrice() <= LowestBuy)
               {
                  LowestBuy = OrderOpenPrice();
                  LowestBuyTicket = OrderTicket();
                  LowestBuyProfit = Profit;
               }

               BuyOrders++;
               if (BuyOrders > MaxBuys) MaxBuys = BuyOrders;
               BuyLots += OrderLots();

               BuyProfit += Profit;
               if (Profit > 0) PosBuyProfit += Profit; 
               
            }

            if (OrderType() == OP_SELL)
            {
               if (OrderOpenPrice() <= LowestSell)
               {
                  LowestSell = OrderOpenPrice();
                  LowestSellTicket = OrderTicket();
                  LowestSellProfit = Profit;
               }

               if (OrderOpenPrice() >= HighestSell)
               {
                  HighestSell = OrderOpenPrice();
                  HighestSellTicket = OrderTicket();
                  HighestSellProfit = Profit;
               }

               SellOrders++;
               if (SellOrders > MaxSells) MaxSells = SellOrders;
               SellLots += OrderLots();

               SellProfit += Profit;
               if (Profit > 0) PosSellProfit += Profit; 
            }
         }
      }
   }
   if (SellOrders==0)CloseSellsNOW=false;
   if (BuyOrders==0)CloseBuysNOW=false;
   if (SellOrders==0 && BuyOrders==0)CloseAllNOW=false;

      //BuyPipTarget = ProfitTarget;
      //SellPipTarget = ProfitTarget;

   if (HighestBuy >= HighestSell)
      HighPoint = HighestBuy;
   else
      HighPoint = HighestSell;

   if (LowestBuy <= LowestSell)
      LowPoint = LowestBuy;
   else
      LowPoint = LowestSell;

   MidPoint = (HighPoint + LowPoint) / 2;

//   if ((SellOrders > 1 && BuyOrders > 0) || (SellOrders > 0 && BuyOrders > 1)) MidPoint = (HighPoint + LowPoint) / 2;

   RefreshRates();
//------------------------------------------------------------------------------------------------
 if(MoneyMangement){
  ProfitTarget=(AutoLot()*100*ProfitSkew);
 }
//------------------------------------------------------------------------------------------------
// ---------------------------------- Take Profit code --------------------------------------
 
 double TotalProfit = BuyProfit + SellProfit;
 double TotalOrders = BuyOrders + SellOrders;
 
  if(TotalProfit > MaxProfit) MaxProfit =TotalProfit;
  if(TotalOrders == 0 || TotalProfit<=0)MaxProfit = 0; 
  if (CloseAllNOW)ExitAllTradesNOW(Aqua, "");
//------------------------------------
  if(ProfitTrailing)
  {
   ProfitMode=0;
   if(TotalProfit >=ProfitTarget  && TotalProfit <= (MaxProfit-(MaxProfit*MaxRetrace)/100))
      {
      ExitAllTradesNOW(Lime,"Max profit reached");
      CloseAllNOW=True;
      }
  }
//------------------------------------
 if (ProfitMode==1 || ProfitMode==3)
 {
      if(BuyProfit>=ProfitTarget)CloseBuysNOW=True;
      if(SellProfit>=ProfitTarget)CloseSellsNOW=True;
 }
 if ((ProfitMode==1 || ProfitMode==2) && (BuyProfit + SellProfit >= ProfitTarget)) {ExitAllTradesNOW(Lime,"Max target reached");CloseAllNOW=True;}
 if (CloseBuysNOW)CloseAllBuyProfit();
 if (CloseSellsNOW)CloseAllSellProfit();

// ----------------------------------End Take Profit code --------------------------------------
   int Direction= Direction();
 
   if(ReverseDirection)  Direction = -Direction;    

// ---------------------------------- Loss Management code --------------------------------------
   bool NoBuy=false;
   bool NoSell=false;
   
   if(AllowRecovery)
   {
      int returnValue;
 	   if(iMA(Symbol(),5,10,0,MODE_SMA,PRICE_CLOSE,0) < iMA(Symbol(),5,10,1,MODE_SMA,PRICE_CLOSE,1)) {returnValue=-1;} // Trade Direction Short
	   if(iMA(Symbol(),5,10,0,MODE_SMA,PRICE_OPEN,0) > iMA(Symbol(),5,10,1,MODE_SMA,PRICE_OPEN,1)) {returnValue=1;} // Trade Direction Long 
      if(RecReverse) returnValue=-returnValue; //If for some reason consider necessary to invert direction
       
      double MaxLoss = AccountBalance()/100*MaxLossPercent;
         
      if(SellProfit<=-MaxLoss)
      {
            NoSell=true; //Do not allow to place more losing orders
            NoBuy=false;
          
          if(ExitAllTrades) {ExitAllTradesNOW(Aqua,"Sell profit going under max allowed loss");  CloseAllNOW=True;}
          
          if(PlaceRecoveryOrders && RecoveryOrders() < MaxRecoveryOrders)
          {
             //Calculate recovery lot size
          double totalSLoss=SellProfit-ProfitTarget;
          double pointSValue=(-totalSLoss/RecoveryTakeProfit);
          double recoverySLot=pointSValue/10 * RecoveryLotMultiplier;
          if(returnValue == 1) OrderSend(Symbol(), OP_BUY,  recoverySLot, Ask, Slippage, Ask - RecoveryStopLoss * Point, Ask + RecoveryTakeProfit * Point, "Rec", Reference*2,0, Green);
          if(returnValue == -1)OrderSend(Symbol(), OP_SELL, recoverySLot, Bid, Slippage, Bid + RecoveryStopLoss * Point, Bid - RecoveryTakeProfit * Point, "Rec", Reference*2,0, Red);

          if(StopTrading) CeaseTrading=true;
          }
        }

         if(BuyProfit<=-MaxLoss)
         {
           NoBuy=true; //Do not allow to place more losing orders
           NoSell=false;
          
          if(ExitAllTrades){ExitAllTradesNOW(Aqua,"Buy profit going under max allowed loss");  CloseAllNOW=True;}
          
          if(PlaceRecoveryOrders && RecoveryOrders() < MaxRecoveryOrders){
             //Calculate recovery lot size
          double totalBLoss=BuyProfit-ProfitTarget;
          double pointBValue=(-totalBLoss/RecoveryTakeProfit);
          double recoveryBLot=pointBValue/10 * RecoveryLotMultiplier;
          if(returnValue == -1)OrderSend(Symbol(), OP_SELL, recoveryBLot, Bid, Slippage, Bid + RecoveryStopLoss * Point, Bid - RecoveryTakeProfit *  Point, "Rec", Reference*2,0, Red);
          if(returnValue == 1) OrderSend(Symbol(), OP_BUY,  recoveryBLot, Ask, Slippage, Ask - RecoveryStopLoss * Point, Ask + RecoveryTakeProfit * Point,  "Rec", Reference*2,0, Green);

          if(StopTrading) CeaseTrading=true;          
          }
         }
      }
// ----------------------------------End Loss Management code -------------------------------------   

// ----------------------------------Forced cycle start code -------------------------------------- 

   if(ForcedStart>0 && BuyOrders+SellOrders==0){
      if((ForcedStart==1 && Direction==-1) || (ForcedStart==2 && Direction==1)) TradeAllowed=false;
}
// ----------------------------------End Forced cycle start code ----------------------------------

// ----------------------------------Variable spacing code ----------------------------------------

   if (AutoSpacing == 1){
      double stddev = iStdDev(Symbol(),StDevTF,StDevPer,0,StDevMode,PRICE_OPEN,0)/Point;
      Spacing = stddev;
      //if(Spacing<15) Spacing=15;
      if(TrendSpacing != 1000)  TrendSpacing=stddev;
      else TrendSpacing = 1000;
   }
// ----------------------------------End Variable spacing code ------------------------------------- 


  
// ----------------------------------Open Trade code -----------------------------------------------
if(TradeAllowed){
   // BUY Trade Criteria
   if (HighestBuy > 0 && LowestBuy < 1000)
   {
      if (Ask <= LowestBuy - (Spacing * Point) || Ask >= HighestBuy + (TrendSpacing * Point))
      {
         BUYme = true;
      }         
      if (Direction != 1)BUYme = false;
      if (CeaseTrading && BuyOrders == 0) BUYme = false;
      if (NoBuy)BUYme = false;
      if (PauseAtTime(StartTime,EndTime,1)!=1) BUYme = false;//Ask < Trend marketQuality()!=1
      if (CloseBuysNOW || CloseAllNOW)BUYme = false;
      if (BUYme && TradeLong==true) PlaceBuyOrder();
   }

   // SELL Trade Criteria
   if (HighestSell > 0 && LowestSell < 1000)
   {
      if (Bid >= HighestSell + (Spacing * Point) || Bid <= LowestSell - (TrendSpacing * Point))
      {
         SELLme = true;
      }         
      if (Direction != -1)SELLme = false;
      if (CeaseTrading && SellOrders == 0) SELLme = false;
      if (NoSell)SELLme = false;
      if (PauseAtTime(StartTime,EndTime,-1)!=-1) SELLme = false;//Bid > Trend marketQuality()!=-1
      if (CloseSellsNOW || CloseAllNOW)SELLme = false;
      if (SELLme && TradeShort==true) PlaceSellOrder();
   }
 }  
// ----------------------------------End Open Trade code --------------------------------------   

   if(AccountMargin()!=0)
   {
      MarginPercent = MathRound((AccountEquity() / AccountMargin()) * 100);
   }   

   if (LowMarginPercent > MarginPercent && MarginPercent!=0) LowMarginPercent = MarginPercent;
   if (AccountEquity() < LowEquity) LowEquity = AccountEquity();

if(IsVisualMode() || !IsTesting())
{
   Message = "                  "+EA_name + NL +
             "                            ProfitTarget           " + DoubleToStr(ProfitTarget, 2) + NL +
             "                            MaxProfit              " + DoubleToStr(MaxProfit, 2) + NL +
             "                            Floating PL            " + DoubleToStr(TotalProfit, 2) + NL +
             "                            Buys                    " + BuyOrders + "  Highest: " + MaxBuys + NL +
             "                            BuyLots                " + DoubleToStr(BuyLots, 2) + NL +
             "                            BuyProfit              " + DoubleToStr(BuyProfit, 2) + NL +
             "                            Highest Buy           " + DoubleToStr(HighestBuy, Digits) + " #" + DoubleToStr(HighestBuyTicket, 0) + "  Profit: " + DoubleToStr(HighestBuyProfit, 2) + NL +
             "                            Highest Sell           " + DoubleToStr(HighestSell, Digits) + " #" + DoubleToStr(HighestSellTicket, 0) + "  Profit: " + DoubleToStr(HighestSellProfit, 2) + NL + NL +
             "                            Sells                     " + SellOrders + "  Highest: " + MaxSells + NL +
             "                            SellLots                 " + DoubleToStr(SellLots, 2) + NL +
             "                            SellProfit               " + DoubleToStr(SellProfit, 2) + NL +
             "                            Lowest Buy            " + DoubleToStr(LowestBuy, Digits) + " #" + DoubleToStr(LowestBuyTicket, 0) + "  Profit: " + DoubleToStr(LowestBuyProfit, 2) + NL +
             "                            Lowest Sell            " + DoubleToStr(LowestSell, Digits) + " #" + DoubleToStr(LowestSellTicket, 0) + "  Profit: " + DoubleToStr(LowestSellProfit, 2) + NL + NL +
             "                            Spacing                " + Spacing + NL +
             "                            Trend Spacing       " + TrendSpacing + NL +NL+
             "                            Balance                " + DoubleToStr(AccountBalance(), 2) + NL +
             "                            Equity                  " + DoubleToStr(AccountEquity(), 2) + "  Lowest: " + DoubleToStr(LowEquity, 2) + NL + NL +
             "                            Margin                  " + DoubleToStr(AccountMargin(), 2) + NL +
             "                            MarginPercent        " + DoubleToStr(MarginPercent, 2) + NL +
             "                            LowMarginPercent  " + DoubleToStr(LowMarginPercent, 2) + NL +
             "                            Current Time is      " +  TimeToStr(TimeCurrent(), TIME_SECONDS);
   Comment(Message);
 
 //------------------------------------------------------------------------------------------------  
   if (RightSideLabel) 
   {
      string MarPercent = DoubleToStr(MarginPercent, 0);
      string LowMarPercent = DoubleToStr(LowMarginPercent, 0);

      string AcctBalance = DoubleToStr(AccountBalance(), 0);
      ObjectDelete("MarginPercent");

      if (ObjectFind("MarginPercent") != 0)
      {
         ObjectCreate("MarginPercent", OBJ_TEXT, 0, Time[0], Close[0]);
         ObjectSetText("MarginPercent", MarPercent + "%  " + LowMarPercent + "%  $" + AcctBalance, 10, "Arial Black", DodgerBlue);
      }
      else
      {
         ObjectMove("MarginPercent", 0, Time[0], Close[0]);
      }
   }

   if (ObjectFind("MidPoint") != 0)
   {
      ObjectCreate("MidPoint", OBJ_HLINE, 0, Time[0], MidPoint);
      ObjectSet("MidPoint", OBJPROP_COLOR, Gold);
      ObjectSet("MidPoint", OBJPROP_WIDTH, 2);
   }
   else
   {
      ObjectMove("MidPoint", 0, Time[0], MidPoint);
   }
}
 //------------------------------------------------------------------------------------------------    
   //QuitTrading(SellOrders);
   getSessionTarget();
   QuitAtTime(endDayHourMinute);
   return(0);
}
//------------------------------------------------------------------------------------------------

void Write(string String)
{
   int Handle;

   if (!Auditing) return;

   Handle = FileOpen(Filename, FILE_READ|FILE_WRITE|FILE_CSV, "/t");
   if (Handle < 1)
   {
      Print("Error opening audit file: Code ", GetLastError());
      return;
   }

   if (!FileSeek(Handle, 0, SEEK_END))
   {
      Print("Error seeking end of audit file: Code ", GetLastError());
      return;
   }

   if (FileWrite(Handle, TimeToStr(CurTime(), TIME_DATE|TIME_SECONDS) + "  " + String) < 1)
   {
      Print("Error writing to audit file: Code ", GetLastError());
      return;
   }

   FileClose(Handle);
}

//------------------------------------------------------------------------------------------------
int Direction() //tradeDirection=1: long, tradeDirection=-1: short 
{
int tradeDirection;

  if (((UseTMA && TMADecision() == 1) || !UseTMA) 
  && ((UseCCI && CCIDecision()  == 1) || !UseCCI) 
  && ((UseARSI && ARSIDecision()  == 1) || !UseARSI) 
  && ((Use_iTrend && iTrendDecision()  == 1) || !Use_iTrend)
  && ((Use_Fisher && FisherDecision() == 1 )|| !Use_Fisher))
   {
      tradeDirection=1;
   }
  if(((UseTMA && TMADecision() == -1)   || !UseTMA) 
  && ((UseCCI && CCIDecision()  == -1)  || !UseCCI) 
  && ((UseARSI && ARSIDecision() == -1) || !UseARSI) 
  && ((Use_iTrend && iTrendDecision()  == -1) || !Use_iTrend)
  && ((Use_Fisher && FisherDecision() == -1) || !Use_Fisher))
      tradeDirection=-1;
 
    if((TMADecision()==0 && CCIDecision()==0 && iTrendDecision()==0 && ARSIDecision()==0 && FisherDecision()==0) 
    || (!UseTMA && !UseCCI && !Use_iTrend && !UseARSI && !Use_Fisher))
      tradeDirection=0;
 
   return (tradeDirection);  
}

//------------------------------------------------------------------------------------------------
int TMADecision() //tradeDirection=1: long, tradeDirection=-1: short 
{
  int tradeDirection;
   
   if(UseTMA==True)
   {
      double MA3_0 = iMA(NULL, MAperiod, 3, 0, 3, PRICE_CLOSE, 0);
      double MA3_1 = iMA(NULL, MAperiod, 3, 0, 3, PRICE_CLOSE, 1);
      double MA20_0 = iMA(NULL, MAperiod, 20, 0, 3, PRICE_CLOSE, 0);
      double MA20_1 = iMA(NULL, MAperiod, 20, 0, 3, PRICE_CLOSE, 1);
      double MA50_0 = iMA(NULL, MAperiod, 50, 0, 3, PRICE_CLOSE, 0);
      double MA50_1 = iMA(NULL, MAperiod, 50, 0, 3, PRICE_CLOSE, 1);
      
     
      if (MA50_0<MA50_1 && MA20_0<MA20_1 && MA3_0<MA3_1 && MA3_0<MA20_0) {tradeDirection=-1;} 
      if (MA50_0>MA50_1 && MA20_0>MA20_1 && MA3_0>MA3_1 && MA3_0>MA20_0) {tradeDirection=1;} 
	}
	else
	tradeDirection=0;
	return(tradeDirection);
}
//------------------------------------------------------------------------------------------------
int CCIDecision()
{
 int tradeDirection;

   if(UseCCI==true)
   {
   double cci=0;
   cci=iCCI( NULL, CCI_Period, CCI_lenght, PRICE_TYPICAL, 0);
   if(cci < -cci_trigger)tradeDirection =-1;
    if(cci > cci_trigger)tradeDirection = 1;
   }
   else
   tradeDirection = 0;

   return(tradeDirection);         
}

int ARSIDecision()
{
 int tradeDirection;
double RSI_1, RSI_2, RSIT;
   if(UseARSI==true)
   {
      RSI_1 = iCustom(NULL, RSI_period,"Adaptive RSI", RSI_bars, PRICE_CLOSE, 0)*10;
      RSI_2 = iCustom(NULL, RSI_period,"Adaptive RSI", RSI_bars, PRICE_CLOSE, 1)*10;
      if(ARSI_trigger==0) RSIT = iATR(NULL,1,13, 0)*10;
      if(ARSI_trigger>0)  RSIT = ARSI_trigger;
      
       if ( RSI_1 > RSI_2 && RSI_1 - RSI_2 > RSIT) {tradeDirection=1;}
       if ( RSI_1 < RSI_2 && RSI_2 - RSI_1 > RSIT) {tradeDirection=-1;}   
   }
   else
   tradeDirection = 0;

   return(tradeDirection);         
}

int iTrendDecision()
{
int tradeDirection;
   if(Use_iTrend==true)
   {
  	   double B1_1 = iCustom(NULL, iTrendPeriod, "i_Trend", 0, 0, 0, 20, 2, 13, 300, 0, 0);
      double B1_2 = iCustom(NULL, iTrendPeriod, "i_Trend", 0, 0, 0, 20, 2, 13, 300, 1, 0);
      double B2_2 = iCustom(NULL, iTrendPeriod, "i_Trend", 0, 0, 0, 20, 2, 13, 300, 0, 1);
      
      double S1_1 = iCustom(NULL, iTrendPeriod, "i_Trend", 0, 0, 0, 20, 2, 13, 300, 0, 0);
      double S1_2 = iCustom(NULL, iTrendPeriod, "i_Trend", 0, 0, 0, 20, 2, 13, 300, 1, 0);
      double S2_2 = iCustom(NULL, iTrendPeriod, "i_Trend", 0, 0, 0, 20, 2, 13, 300, 0, 1);
   
      if (B1_1 > B1_2 && B1_1 > B2_2) {tradeDirection=1;}
      if (S1_1 < S1_2 && S1_1 < S2_2) {tradeDirection=-1;}
 
   }     
   else
  tradeDirection=0;
   return(tradeDirection); 
}

//macd
int FisherDecision()
{
int tradeDirection;
   if(Use_Fisher==true)
   {
   
      double fish0 = iCustom(NULL,FisherPeriod,"Fisher_m11",Fisher_Bars,0.3,0,0);
   
      if (fish0 >= Buy_Enter_Level) {tradeDirection=1;}
      if (fish0 <= Sell_Enter_Level) {tradeDirection=-1;}
 
   }     
   else
  tradeDirection=0;
   return(tradeDirection); 
}
   
  
   
//------------------------------------------------------------------------------------------------
void QuitAtTime(int endDayHour)//input example: close trading tomorrow at 20:59. Today: 14. April, toworrow:15.April. 142059
{
   int t=TimeDay(TimeCurrent())*10000+TimeHour(TimeCurrent())*100+TimeMinute(TimeCurrent());
   if(t>=endDayHour && endDayHour!=0)
   {
      CeaseTrading=true;
      ExitAllTradesNOW(Gold, "Stopped Trading because endtime reached!");
      CloseAllNOW=True;
   }
}

int PauseAtTime(int startTime, int endTime, int tradeDirection)
{
   int returnValue;
   if(startTime!=0 && endTime!=0)
   {
      int t=TimeDay(TimeCurrent())*10000+TimeHour(TimeCurrent())*100+TimeMinute(TimeCurrent());
      if(t>=startTime && t<=endTime)
      {
         returnValue=0;
      }
      else
      {
         if(tradeDirection==1){returnValue=1;}
         if(tradeDirection==-1){returnValue=-1;}
      }
   }
   else
   {
      if(tradeDirection==1){returnValue=1;}
      if(tradeDirection==-1){returnValue=-1;}      
   }
   return (returnValue);
}

double SessionProfit()
{
   double profitHistory;
   double profitOpenP;
   double returnValue;
     
   for(int i = OrdersHistoryTotal()-1; i>=0; i--)
   {
      OrderSelect(i,SELECT_BY_POS,MODE_HISTORY);
      if(OrderSymbol()==Symbol() && OrderMagicNumber()==Reference)
      {
         if(OrderComment()==TradeComment)
         {
            profitHistory +=OrderProfit(); 
         }
      }
   }
   
   for(int j=OrdersTotal()-1;j>=0;j--)
   {
      OrderSelect(j,SELECT_BY_POS,MODE_TRADES);
      if(OrderSymbol()==Symbol() && OrderMagicNumber()==Reference)
      {
         if(OrderComment()==TradeComment)
         {
            profitOpenP +=OrderProfit(); 
         }
      }      
   }
   
   returnValue=profitHistory+profitOpenP;   
   return(returnValue);         
}
//------------------------------------------------------------------------------------------------
void getSessionTarget()
{
   if(SessionTarget>0)
   {
      if(SessionProfit()>=SessionTarget)
      {     
         CeaseTrading=true;
         ExitAllTradesNOW(Aqua, "Session Target Achieved. YUHUUI!");
         CloseAllNOW=true; 
       }
   }   

}
void ExitAllTradesNOW(color Color, string reason)
{
   if (CloseAllNOW)
   {
      bool success;
      for (int cnt = OrdersTotal() - 1; cnt >= 0; cnt --)
      {
         OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
         if (OrderSymbol() == Symbol() && OrderMagicNumber() == Reference)
         {
            success=OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), Slippage, Color);
            if(success==true)
            {
            if(!IsTesting())   Print("Closed all positions because ",reason);
            }
         } 
      }     
   }
 }
//-----------------------------------------END-----------------------------------------------------
