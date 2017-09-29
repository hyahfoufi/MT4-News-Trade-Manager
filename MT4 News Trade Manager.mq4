#property version     "1.2"
#property description "This Trade Manager will help you manage your positions during news spikes."

#define  NL    "\n"
#property strict

string  s1  = "======= Conditions =======";
enum    LongOrShort{Both=0, Long=1, Short=2};
LongOrShort LongShort;
double  MinLots     = 0;
double  MaxLots     = 100;

extern string  s2              = "====== Stop Loss & Take Profit ======";
extern string  BE              = "Break even settings";
extern bool    BreakEven       = false;
extern int     BreakEvenPips   = 5;
extern int     BreakEvenProfit = 2;
bool    BreakEven2      = false;
int     BreakEvenPips2  = 10;
int     BreakEvenProfit2= 5;
extern string  ASL             = "Automatically Add SL and TP";
extern int     AutoStopLoss    = 0;
extern int     AutoTakeProfit  = 0;
string  JSL             = "Jumping stop loss settings";
bool    JumpingStop     = false;
int     JumpingStopPips = 30;
bool    AddBEP          = false;
bool    JumpAfterBreakevenOnly = false;

extern string  s3  = "====== Partial closure ======";
extern double  TP1 = 0;

extern string  s4          = "====== News TP ======";
extern int     SpikeTP1    = 0;
extern int     SpikeTP1Min = 10;
extern int     SpikeTP2    = 0;
extern int     SpikeTP2Min = 20;

string  s5          = "====== Maintain Connection ======";
int     hour        = -1;
int     minute      = 0;
int     hour2       = -1;
int     minute2     = 0;

extern string  s6          = "====== Buttons ======";
extern bool    ShowButtons = false;
extern int     ButtonX=10;
extern int     ButtonY=30;


int            nothing;
int            i=0; //loop counter
double         point; // Saves the Point and Digits of an order
double         TargetAsPips;

// Variables for CreateText
string         objectName="Trademan";
int            objN=0;
int            FontSize=8;
string         FontType="Arial Bold";
color          FontColor=White;
int            XOffset=240;
int            YOffset=10;
int            ObjectHeight=0;

// Spike
double         Distance;      // Entry distance within spike
int            OrderBarShift; // Bar index of the trade
double         BarHigh;
double         BarLow;

// Maintain Connection
int secofnews;                // Seconds from midnight to news time
int secofnews2;
int secofday;                 // Seconds from midnight to current time
int MaintainTicket  = -1;
int MaintainTicket2 = -1;

// Backtester Specific
bool TestOpened = false;
bool TestOpened2 = false;

int init()
{
   // Maintain Connection
   secofnews=hour*3600+minute*60;
   secofnews2=hour2*3600+minute2*60;

   // Account for 5 digit brokers
   point = Point;
   if(Digits==3 || Digits==5) point*=10;

   // Create Partial Closure buttons on chart
   if(ShowButtons)
   {
      CreateObject(objectName+"BTNAll",OBJ_BUTTON,ButtonX,ButtonY,60,20,"Close All","Tahoma",10,Wheat,Black,Black);
      CreateObject(objectName+"BTN10",OBJ_BUTTON,ButtonX+62,ButtonY,35,20,"10%","Tahoma",10,Wheat,Black,Black);
      CreateObject(objectName+"BTN25",OBJ_BUTTON,ButtonX+99,ButtonY,35,20,"25%","Tahoma",10,Wheat,Black,Black);
      CreateObject(objectName+"BTN50",OBJ_BUTTON,ButtonX+136,ButtonY,35,20,"50%","Tahoma",10,Wheat,Black,Black);
   }
   
   PrintSettings(); // Print EA settings in the comments section   
   return(0);
}

int deinit()
{
   Comment("");
   ObjectCleanup();
   return(0);
}

int start()
{
   // If running in Backtester
   if(IsTesting())
   {  
      if (!TestOpened && Month() == 8 && Day() == 7)
      {
         nothing = OrderSend(Symbol(), OP_SELLSTOP, 1, 1.0905, 5, 0, 0);
         TestOpened = true;
      }
      if (!TestOpened2 && Month() == 8 && Day() == 18)
      {
         nothing = OrderSend(Symbol(), OP_BUYSTOP, 1, 1.5615, 5, 0, 0);
         TestOpened2 = true;
      }
   }

   // Maintain Connection
   if (hour >= 0 || hour2 >= 0)
      MaintainConnection();

   // Stop if there is nothing to do
   if (OrdersTotal()==0)
      return(0);
   
   MonitorTrades(); // Stop loss adjusting, part closure
   
   return(0);
}

void MonitorTrades()
{
   ObjectHeight=YOffset+12;
   
   for (i=OrdersTotal(); i>=0; i--)
   { 
      nothing = OrderSelect(i, SELECT_BY_POS);
      
      if (OrderSymbol()==Symbol() && (OrderType()==OP_BUY || OrderType()==OP_SELL))
      {
         // Long or Short
         if (LongShort == Long)
            if (OrderType() != OP_BUY)
               continue;
         if (LongShort == Short)
            if (OrderType() != OP_SELL)
               continue;

         // Lots size (Inclusive)
         if ( StringFind(OrderComment(), "from") > -1 ) // If it's a partial position
         {
            if (OrderLots() < MinLots/2 || OrderLots() > MaxLots/2)
               continue;
         }
         else if (OrderLots() < MinLots || OrderLots() > MaxLots)
            continue;
        
         ManageTrade(); // The subroutine that calls the other working subroutines
//         CreateText("#"+OrderTicket()+" "+OrderSymbol(),FontColor,XOffset,ObjectHeight);
         
      } // Close if (OrderSymbol()==Symbol())
   } // Close For loop
} // end of MonitorTrades


void BreakEvenStopLoss(int BEPips, int BEProfit) // Move stop loss to breakeven
{
   int ticket;

   if (OrderType()==OP_BUY)
   {
      if (OrderClosePrice() >= OrderOpenPrice() + (point*BEPips) && OrderStopLoss() < OrderOpenPrice()+(BEProfit*point))
            ticket = OrderModify(OrderTicket(),OrderOpenPrice(),OrderOpenPrice()+(BEProfit*point),OrderTakeProfit(),0,CLR_NONE);
   }               			         
          
   if (OrderType()==OP_SELL)
   {
      if (OrderClosePrice() <= OrderOpenPrice() - (point*BEPips) && (OrderStopLoss() > OrderOpenPrice()-(BEProfit*point) || OrderStopLoss()==0))
            ticket = OrderModify(OrderTicket(),OrderOpenPrice(),OrderOpenPrice()-(BEProfit*point),OrderTakeProfit(),0,CLR_NONE);
   }


} // End BreakevenStopLoss sub

void JumpingStopLoss() // Jump sl by pips and at intervals chosen by user 
{
 
   // Abort the routine if JumpAfterBreakevenOnly is set to true and be sl is not yet set
   if (JumpAfterBreakevenOnly && OrderType()==OP_BUY)
      if(OrderStopLoss()<OrderOpenPrice()) return;
     
   if (JumpAfterBreakevenOnly && OrderType()==OP_SELL)
      if(OrderStopLoss()>OrderOpenPrice()) return;
     
   int ticket;
   double sl=OrderStopLoss(); //Stop loss
  
   if (OrderType()==OP_BUY)
   {
      // First check if sl needs setting to breakeven
      if (sl==0 || sl<OrderOpenPrice())
      {
         if (OrderClosePrice() >= OrderOpenPrice() + (JumpingStopPips*point))
         {
            sl=OrderOpenPrice();
            if (AddBEP==true) sl=sl+(BreakEvenProfit*point); // If user wants to add a profit to the break even
            ticket = OrderModify(OrderTicket(),OrderOpenPrice(),sl,OrderTakeProfit(),0,CLR_NONE);
            if (ticket>0)
               Print("Jumping stop set at breakeven: ", OrderSymbol(), ": SL ", sl, ": Ask ", Ask);
            return;
         }
      } //close if (sl==0 || sl<OrderOpenPrice()
      
      // Increment sl by sl + JumpingStopPips.
      // This will happen when market price >= (sl + JumpingStopPips)
      if (OrderClosePrice() >= sl + ((JumpingStopPips*2)*point) && sl>= OrderOpenPrice())      
      {
         sl=sl+(JumpingStopPips*point);
         ticket = OrderModify(OrderTicket(),OrderOpenPrice(),sl,OrderTakeProfit(),0,CLR_NONE);
         if (ticket>0)
            Print("Jumping stop set: ", OrderSymbol(), ": SL ", sl, ": Ask ", Ask);
      }// close if (Bid>= sl + (JumpingStopPips*point) && sl>= OrderOpenPrice())      
   }
      
   if (OrderType()==OP_SELL)
   {
      // First check if sl needs setting to breakeven
      if (sl==0 || sl>OrderOpenPrice())
      {
         if (OrderClosePrice() <= OrderOpenPrice() - (JumpingStopPips*point))
         {
            sl=OrderOpenPrice();
            if (AddBEP==true) sl=sl-(BreakEvenProfit*point); // If user wants to add a profit to the break even
            ticket = OrderModify(OrderTicket(),OrderOpenPrice(),sl,OrderTakeProfit(),0,CLR_NONE);
            if (ticket>0)
            {
               
               Print("Jumping stop set at breakeven: ", OrderSymbol(), ": SL ", sl, ": Ask ", Ask);
            }            
            return;
         }
      } //close if (sl==0 || sl>OrderOpenPrice()
      
      // Decrement sl by sl - JumpingStopPips.
      // This will happen when market price <= (sl - JumpingStopPips)
      if (OrderClosePrice()<= sl - ((JumpingStopPips*2)*point) && sl<= OrderOpenPrice())      
      {
         sl=sl-(JumpingStopPips*point);
         ticket = OrderModify(OrderTicket(),OrderOpenPrice(),sl,OrderTakeProfit(),0,CLR_NONE);
         if (ticket>0)
         {
            
            Print("Jumping stop set: ", OrderSymbol(), ": SL ", sl, ": Ask ", Ask);
         }            
            
      }// close if (Bid>= sl + (JumpingStopPips*point) && sl>= OrderOpenPrice())      
   
   
   }

} //End of JumpingStopLoss sub

void AutoSetStops()
// This will automatically add a SL and/or TP to orders with none set. 
{
   int ticket;
   double sl = OrderStopLoss();
   double tp = OrderTakeProfit();
   
   if (AutoTakeProfit > 0 && tp == 0)
   {
      if (OrderType()==OP_BUY)
         tp = OrderOpenPrice() + (AutoTakeProfit * point);
      else if (OrderType()==OP_SELL) 
         tp = OrderOpenPrice() - (AutoTakeProfit * point);
   }  

   if (SpikeTP2 > 0)
   {
      if (OrderType()==OP_BUY)
      {
         tp = BarLow + (SpikeTP2*point);
         if (tp - OrderOpenPrice() < SpikeTP2Min * point)
            tp = OrderOpenPrice() + (SpikeTP2Min * point);
         if (OrderClosePrice() > tp)
         {
            nothing = OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), 0, clrNONE);
            Print("Too late for TP, closing position manually at: " + OrderClosePrice() + " instead of: " + tp);
            return;
         }
      }
      else if (OrderType()==OP_SELL)
      {
         tp = BarHigh - (SpikeTP2*point);
         if (OrderOpenPrice() - tp < SpikeTP2Min * point)
            tp = OrderOpenPrice() - (SpikeTP2Min * point);
         if (OrderClosePrice() < tp)
         {
            nothing = OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), 0, clrNONE);
            Print("Too late for TP, closing position manually at: " + OrderClosePrice() + " instead of: " + tp);
            return;
         }
      }
   }
   
   if (AutoStopLoss > 0 && sl == 0)
   {
      if (OrderType()==OP_BUY)
         sl = OrderOpenPrice() - (AutoStopLoss * point);
      else if (OrderType()==OP_SELL)
         sl = OrderOpenPrice() + (AutoStopLoss * point);
   }
         ticket = OrderModify(OrderTicket(),OrderOpenPrice(),sl,tp,0,CLR_NONE);
         if (ticket>0)
            Print("Adding SL and/or TP: ", OrderSymbol(), ": SL:", sl, ": TP:", tp);
} // End of AutoSetStops()

void ExtractPartCloseVariables()
{
   int TargetPipsNews;
   
   if (TP1 > 0)
      TargetAsPips = TP1;

   if (SpikeTP1>0)
   {
      // TargetPipsNews is our TP1 target in pips, based on our spike calculations
      TargetPipsNews = ExtractTP1FromSpike();

      // Set TP1 to whichever comes first, news target, or original target
      if((TargetPipsNews > 0 && TargetPipsNews < TargetAsPips) || TargetAsPips == 0)
         TargetAsPips = TargetPipsNews;
   }
} // End ExtractPartCloseVariables

int ExtractTP1FromSpike()
{
   int TargetPips = -1;

   // Get the TP1 target based on expected spike, while accounting for the pips that have passed already
   TargetPips = SpikeTP1 - Distance;
    
   if (TargetPips < SpikeTP1Min)
      TargetPips = SpikeTP1Min;

   return(TargetPips);
}

void ExtractSpikeData()
{
   // Get the Index for the bar where the order was placed
   OrderBarShift = iBarShift(OrderSymbol(), PERIOD_M1, OrderOpenTime(), true);

   double PreviousClose = iClose(OrderSymbol(),PERIOD_M1,OrderBarShift+1);
   BarHigh = iHigh(OrderSymbol(), PERIOD_M1, OrderBarShift);
   BarLow = iLow(OrderSymbol(), PERIOD_M1, OrderBarShift);

   // If there's a gap, use the previous close as the High or Low
   if ( BarHigh < PreviousClose )
      BarHigh = PreviousClose;
   if ( BarLow > PreviousClose )
      BarLow = PreviousClose;

   // Get the distance in pips between the Low of the candle and order open price
   if (OrderType() == OP_BUY)
      Distance = (OrderOpenPrice() - BarLow) / point;
   else if (OrderType() == OP_SELL)
      Distance = (BarHigh - OrderOpenPrice()) / point;
}

void PartCloseOrder()
{
   int index=StringFind(OrderComment(), "from");
   if (index>-1) return; // Order already part-closed

   TargetAsPips=0;
   ExtractPartCloseVariables();   
   if(TargetAsPips==0) return; // User entry error

   int ticket;
   double ProfitTarget;
   double LotsToClose=OrderLots()/2;
   
   if (OrderType()==OP_BUY)
   {
      if(TargetAsPips>0)
      {
         ProfitTarget=NormalizeDouble(OrderOpenPrice()+(TargetAsPips*point),Digits);
         if (OrderClosePrice()>=ProfitTarget)
            ticket=OrderClose(OrderTicket(), LotsToClose,OrderClosePrice(),3,CLR_NONE);
      }
   }
   
   if (OrderType()==OP_SELL)
   {
      if(TargetAsPips>0)
      {
         ProfitTarget=NormalizeDouble(OrderOpenPrice()-(TargetAsPips*point),Digits);
         if (OrderClosePrice()<=ProfitTarget)
            ticket=OrderClose(OrderTicket(), LotsToClose,OrderClosePrice(),3,CLR_NONE);
      }
   }
} // End of PartCloseOrder()

void ManageTrade()
{     
   // Call the working subroutines one by one. 
   
   // Breakeven
   if(BreakEven2) BreakEvenStopLoss(BreakEvenPips2, BreakEvenProfit2);

   // Breakeven
   if(BreakEven) BreakEvenStopLoss(BreakEvenPips, BreakEvenProfit);

   // JumpingStop
   if(JumpingStop) JumpingStopLoss();
   
   // If we're trading spikes, extract spike data
   if (SpikeTP1>0 || SpikeTP2>0) ExtractSpikeData();

   // Set initial stoploss and/or takeprofit
   if ( (AutoStopLoss > 0 && OrderStopLoss() == 0) || (AutoTakeProfit > 0 && OrderTakeProfit() == 0) || (SpikeTP2 > 0 && OrderTakeProfit() == 0)) AutoSetStops();

   // Partial order closure at profit point chosen by user
   if (TP1 > 0 || SpikeTP1 > 0) PartCloseOrder();
      
} // End of ManageTrade()

void MaintainConnection()
{
   secofday=Hour()*3600+Minute()*60+Seconds();

   if ( hour >= 0 && MaintainTicket == -1)
      if ( secofday >= secofnews-15 && secofday < secofnews + 60)
      {
         MaintainTicket = OrderSend(Symbol(), OP_BUYLIMIT, 0.01, 0.001, 0, 0, 0, NULL, 724653,0, Red);      
         EventSetTimer(4);
      }
      
   if (hour2 >= 0 && MaintainTicket2 == -1)
      if ( secofday >= secofnews2-15 && secofday < secofnews2 + 60)
      {
         MaintainTicket2 = OrderSend(Symbol(), OP_BUYLIMIT, 0.01, 0.001, 0, 0, 0, NULL, 724653, 0, Red);      
         EventSetTimer(4);
      }
}

void OnTimer()
{
   if(MaintainTicket >= 0)
   {
      if( OrderDelete(MaintainTicket) )
      {
         MaintainTicket = -2;
         EventKillTimer();
      }
   }
   if(MaintainTicket2 >= 0)
   {
      if( OrderDelete(MaintainTicket2) )
      {
         MaintainTicket2 = -2;
         EventKillTimer();
      }
   }
}

void CreateText(string Text, color TextColor, int X, int Y)
{ 
  ObjectCreate(objectName+objN, OBJ_LABEL, 0, 0, 0);
  ObjectSet(objectName+objN, OBJPROP_XDISTANCE, X);
  ObjectSet(objectName+objN, OBJPROP_YDISTANCE, Y);
  ObjectSetText(objectName+objN,Text,FontSize,FontType,TextColor);
  objN++;
  ObjectHeight+=12;
}

void ObjectCleanup()
{
   for(i=ObjectsTotal(); i>=0; i--)
      if(StringFind(ObjectName(i),objectName,0)>=0)
         ObjectDelete(ObjectName(i));
}

void PrintSettings()
{
   string ScreenMessage;
  
//   CreateText("Managing These Trades:",FontColor,XOffset,YOffset);

   // Order Selection
//   ScreenMessage = TimeToStr(TimeCurrent(),TIME_SECONDS);
   ScreenMessage = StringConcatenate(ScreenMessage, NL, "News Trade Manager:");
/*   if (LongShort == Long)
      ScreenMessage = StringConcatenate(ScreenMessage, NL, "Long Positions");
   else if (LongShort == Short)
      ScreenMessage = StringConcatenate(ScreenMessage, NL, "Short Positions");
   if (MinLots > 0 || MaxLots < 100)
      ScreenMessage = StringConcatenate(ScreenMessage, NL, "Between ",MinLots," to ", MaxLots," Lots");
*/
   // SL TP Facilities
   if(BreakEven)
      ScreenMessage = StringConcatenate(ScreenMessage, NL, "Break even set to ", BreakEvenPips, ". BreakEvenProfit is set to ", BreakEvenProfit, " pips");
//   if(BreakEven2)
//      ScreenMessage = StringConcatenate(ScreenMessage, NL, "Break even 2 set to ", BreakEvenPips2, ". BreakEvenProfit2 is set to ", BreakEvenProfit2, " pips");
   if(JumpingStop==true)
   {
      ScreenMessage = StringConcatenate(ScreenMessage, NL, "Jumping stop set to ", JumpingStopPips);
      if (JumpAfterBreakevenOnly)
         ScreenMessage = StringConcatenate(ScreenMessage, " after breakeven is achieved");
      if(AddBEP==true)
         ScreenMessage = StringConcatenate(ScreenMessage, ", also adding BreakEvenProfit (", BreakEvenProfit, " pips)");            
   }
   if (AutoStopLoss > 0)
      ScreenMessage = StringConcatenate(ScreenMessage, NL, "StopLoss set to ", AutoStopLoss);    
   if (AutoTakeProfit > 0)
      ScreenMessage = StringConcatenate(ScreenMessage, NL, "TakeProfit set to ", AutoTakeProfit);
   if (TP1>0)
      ScreenMessage = StringConcatenate(ScreenMessage, NL, "TP1: ", TP1);
   if (SpikeTP1>0)
      ScreenMessage = StringConcatenate(ScreenMessage, NL, "SpikeTP1: ", SpikeTP1, " Min: ", SpikeTP1Min);
   if (SpikeTP2>0)
      ScreenMessage = StringConcatenate(ScreenMessage, NL, "SpikeTP2: ", SpikeTP2, " Min: ", SpikeTP2Min);
   if (hour >= 0)
      ScreenMessage = StringConcatenate(ScreenMessage, NL, "Maintain Connection: ", hour, ":", minute);
   if (hour2 >= 0)
      ScreenMessage = StringConcatenate(ScreenMessage, NL, "Maintain Connection2: ", hour2, ":", minute2);
   Comment(ScreenMessage);
}

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(id==CHARTEVENT_OBJECT_CLICK)
   {
      double LotsToClose;
      double AmountToClose=1;

      if(sparam == objectName+"BTNAll")
         Print("Closing All Positions!");
      else if(sparam == objectName+"BTN10")
         AmountToClose *= 0.10;
      else if(sparam == objectName+"BTN25")
         AmountToClose *= 0.25;
      else if(sparam == objectName+"BTN50")
         AmountToClose *= 0.50;

      ObjectSetInteger(0,sparam,OBJPROP_STATE,0);

      for (i=OrdersTotal(); i>=0; i--)
      {
         nothing = OrderSelect(i, SELECT_BY_POS);

         if (OrderSymbol()==Symbol() && (OrderType()==OP_BUY || OrderType()==OP_SELL))
         {
            LotsToClose = NormalizeDouble( AmountToClose*OrderLots(), 2);
            if( LotsToClose >= MarketInfo(Symbol(), MODE_LOTSTEP))
            {
               if(sparam != objectName+"BTNAll" && LotsToClose == OrderLots())
                  continue;
               nothing = OrderClose(OrderTicket(), LotsToClose, OrderClosePrice(), 1000, clrNONE);
            }
         }
      }
      
   }
}

void CreateObject(string name,ENUM_OBJECT obj_type,long x,long y,ushort width,ushort height,string txt,string font,ushort fntsize,color bgclr,color txtclr,color brdclr)
  {
   ObjectCreate(0,name,obj_type,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_LOWER);
   ObjectSetString(0,name,OBJPROP_TEXT,txt);
   ObjectSetString(0,name,OBJPROP_FONT,font);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,fntsize);
   ObjectSetInteger(0,name,OBJPROP_COLOR,txtclr);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_ZORDER,100);
   if(obj_type==OBJ_LABEL) return;
   ObjectSetInteger(0,name,OBJPROP_STATE,0);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,width);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,height);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bgclr);
   ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,brdclr);
   objN++;
  }