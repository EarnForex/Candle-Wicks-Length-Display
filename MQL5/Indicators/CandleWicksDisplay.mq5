#property copyright "Copyright © 2011-2021, www.EarnForex.com"
#property link      "https://www.earnforex.com/metatrader-indicators/candle-wicks-length-display/"
#property version   "1.08"
#property icon      "\\Files\\EF-Icon-64x64px.ico"

#property description "Displays the candle wicks' length above and below the candles."
#property description "Alerts when the candle's wick (shadow) reaches a certain length."
#property description "You can choose whether to use pips or %."
#property description "Email settings are under Tools->Options->Email."
#property description "Notifications settings are under Tools->Options->Notifications."

// The indicator uses only objects for display, but the line below is required for it to work.
#property indicator_chart_window
#property indicator_plots 0

enum PipsPerc
{
   Pips,
   Percentage
};

input PipsPerc Units = Pips; // Standard pips or percentage points.
input int DisplayWickLimit = 5; // DisplayWickLimit in standard pips or %.
input color DisplayHighWickColor = clrRed;
input color DisplayLowWickColor = clrLimeGreen;
input int UpperWickLimit = 10; // UpperWickLimit in broker pips or % for alerts.
input int LowerWickLimit = 10; // LowerWickLimit in broker pips or % for alerts.
input bool WaitForClose = true; // WaitForClose - Wait for a candle to close before checking wicks' length?
input bool SoundAlert = false;
input bool VisualAlert = false;
input bool EmailAlert = false;
input bool NotificationAlert = false;
input bool IgnoreAlertsOnFirstRun = true;
// If > 0 and <= 100, displays length only for bars where Open & Close within top or bottom % of candle.
input int TopBottomPercent = 0; // TopBottomPercent: Body within top/bottom percentage part.
input string FontFace = "Verdana";
input int FontSize = 10;
input int MaxBars = 500;
input bool UseRawPips = false; // UseRawPips: if true, will use points instead of pips.

// Global variables.
datetime AlertDone; // Time of the bar of the last alert.
double Poin; // Traditional point value.
bool CanDoAlerts; // Fuse to prevent alerts on initialization or timeframe change.

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
{
	Poin = _Point;
	//Checking for unconventional Point digits number
   if ((!UseRawPips) && (((_Point == 0.00001) || (_Point == 0.001)))) Poin *= 10;
   if (!WaitForClose) CanDoAlerts = false;
   else CanDoAlerts = true;
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "Red-", -1, OBJ_TEXT);
   ObjectsDeleteAll(0, "Green-", -1, OBJ_TEXT);
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   // Redraw wick labels.
   if (id == CHARTEVENT_CHART_CHANGE) RedrawVisibleWickLabels();
}

//+------------------------------------------------------------------+
//| CandleWicks                                                      |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &Time[],
                const double &Open[],
                const double &High[],
                const double &Low[],
                const double &Close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   ArraySetAsSeries(Time, true);
   ArraySetAsSeries(Open, true);
   ArraySetAsSeries(High, true);
   ArraySetAsSeries(Low, true);
   ArraySetAsSeries(Close, true);
   
   string name, length;
   bool DoAlert = false;
   int index = 0;
   
   if (WaitForClose) index = 1;
   
   int counted_bars = prev_calculated;
   if (counted_bars > 0) counted_bars--;
   int limit = rates_total - counted_bars;
   if ((MaxBars != 0) && (limit > MaxBars)) limit = MaxBars;

   for (int i = 0; i < limit; i++)
   {
      if ((TopBottomPercent > 0) && (TopBottomPercent <= 100))
      {
         double percent = (High[i] - Low[i]) * TopBottomPercent / 100;
         if (!(((Open[i] >= NormalizeDouble(High[i] - percent, _Digits)) && (Close[i] >= NormalizeDouble(High[i] - percent, _Digits))) ||
             ((Open[i] <= NormalizeDouble(Low[i] + percent, _Digits)) && (Close[i] <= NormalizeDouble(Low[i] + percent, _Digits))))) continue;
      }

      if ((Units == Percentage) && (High[i] == Low[i])) continue; // Avoid zero-divide error.

      // Upper wick length display.
      if (
         ((Units == Pips) && (NormalizeDouble(High[i] - MathMax(Open[i], Close[i]), _Digits) >= NormalizeDouble(DisplayWickLimit * Poin, _Digits)))
         ||
         ((Units == Percentage) && ((High[i] - MathMax(Open[i], Close[i])) / (High[i] - Low[i]) * 100 >= DisplayWickLimit))
         )
      {
         name = GenerateObjectName("Red-", Time[i]);
         if (Units == Pips) length = DoubleToString(MathRound((High[i] - MathMax(Open[i], Close[i])) / Poin), 0);
         else if (Units == Percentage) length = DoubleToString(MathRound((High[i] - MathMax(Open[i], Close[i])) / (High[i] - Low[i]) * 100), 0);
         if (ObjectFind(0, name) != -1) ObjectDelete(0, name);
         ObjectCreate(0, name, OBJ_TEXT, 0, Time[i], High[i]);
			ObjectSetString(0, name, OBJPROP_TEXT, length);
   		ObjectSetInteger(0, name, OBJPROP_FONTSIZE, FontSize);
		   ObjectSetString(0, name, OBJPROP_FONT, FontFace);
		   ObjectSetInteger(0, name, OBJPROP_COLOR, DisplayHighWickColor);
         int visible_bars = (int)ChartGetInteger(0, CHART_VISIBLE_BARS);
         int first_bar = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
         int last_bar = first_bar - visible_bars + 1;
         if ((i <= first_bar) && (i >= last_bar)) RedrawOneWickLabel(i, last_bar);
         ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_UPPER);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      }
      else // Remove tick labels that are no longer needed.
      {
         name = GenerateObjectName("Red-", Time[i]);
         if (ObjectFind(0, name) != -1) ObjectDelete(0, name);
      }
      // Lower wick length display.
      if (
         ((Units == Pips) && (NormalizeDouble(MathMin(Open[i], Close[i]) - Low[i], _Digits) >= NormalizeDouble(DisplayWickLimit * Poin, _Digits)))
         ||
         ((Units == Percentage) && ((MathMin(Open[i], Close[i]) - Low[i]) / (High[i] - Low[i]) * 100 >= DisplayWickLimit))
         )
      {
         name = GenerateObjectName("Green-", Time[i]);
         if (Units == Pips) length = DoubleToString(MathRound((MathMin(Open[i], Close[i]) - Low[i]) / Poin), 0);
         else if (Units == Percentage) length = DoubleToString(MathRound((MathMin(Open[i], Close[i]) - Low[i]) / (High[i] - Low[i]) * 100), 0);
         if (ObjectFind(0, name) != -1) ObjectDelete(0, name);
         ObjectCreate(0, name, OBJ_TEXT, 0, Time[i], Low[i]);
			ObjectSetString(0, name, OBJPROP_TEXT, length);
   		ObjectSetInteger(0, name, OBJPROP_FONTSIZE, FontSize);
		   ObjectSetString(0, name, OBJPROP_FONT, FontFace);
		   ObjectSetInteger(0, name, OBJPROP_COLOR, DisplayLowWickColor);
         ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_UPPER);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      }
      else // Remove tick labels that are no longer needed.
      {
         name = GenerateObjectName("Green-", Time[i]);
         if (ObjectFind(0, name) != -1) ObjectDelete(0, name);
      }
   }

   // Already sent an alert for this candle or ignoring the initial alert when attaching the indicator first time.
   // We probably also do not want the alert to sound on index = 0 when IgnoreAlertsOnFirstRun is false but we could
   // get out-of-nowhere alerts during chart data updates.
   if ((AlertDone == Time[index]) || ((counted_bars == 0) && ((IgnoreAlertsOnFirstRun) || (index == 0))))
   {
      // For the case of IgnoreAlertsOnFirstRun.
      if (index != 0) AlertDone = Time[index];
      return(rates_total);
   }
   
   if ((Units == Percentage) && (High[index] == Low[index])) return(rates_total); // Avoid zero-divide error.

   bool UpperPipsCondition = ((Units == Pips) && (NormalizeDouble(High[index] - MathMax(Open[index], Close[index]), _Digits) >= NormalizeDouble(UpperWickLimit * Point(), _Digits)));
   bool UpperPercentageCondition = ((Units == Percentage) && ((High[index] - MathMax(Open[index], Close[index])) / (High[index] - Low[index]) * 100 >= UpperWickLimit));
   bool LowerPipsCondition = ((Units == Pips) && (NormalizeDouble(MathMin(Open[index], Close[index]) - Low[index], _Digits) >= NormalizeDouble(LowerWickLimit * Point(), _Digits)));
   bool LowerPercentageCondition = ((Units == Percentage) && ((MathMin(Open[index], Close[index]) - Low[index]) / (High[index] - Low[index]) * 100 >= LowerWickLimit));
   if ((UpperPipsCondition) || (UpperPercentageCondition) || (LowerPipsCondition) || (LowerPercentageCondition))
      DoAlert = true;
   else CanDoAlerts = true;
      
   if ((DoAlert) && (CanDoAlerts))
   {
      string dir = "";
      if ((UpperPipsCondition) || (UpperPercentageCondition)) dir = "Upper";
      if ((LowerPipsCondition) || (LowerPercentageCondition))
      {
         if (dir == "Upper") dir += "+";
         dir += "Lower";
      }

      string units = "";
      if (Units == Pips) units = "pips";
      if (Units == Percentage) units = "%";

      if (VisualAlert) Alert(dir + " " + units + " wick limit reached!");
      if (SoundAlert) PlaySound("alert.wav");
      if (EmailAlert) SendMail("CandleWick Alert", Symbol() + " " + TimeToString(Time[index]) + " " + dir + " " + units + " - wick limit reached!");
      if (NotificationAlert) SendNotification(Symbol() + " " + TimeToString(Time[index]) + " " + dir + " " + units + " - wick limit reached!");
      AlertDone = Time[index];
   }
      
   return(rates_total);
}

// Required only for High wicks.
void RedrawVisibleWickLabels()
{
   int visible_bars = (int)ChartGetInteger(0, CHART_VISIBLE_BARS);
   int first_bar = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
   int last_bar = first_bar - visible_bars + 1;
   
   // Process all bars on the current screen.
   for (int i = first_bar; i >= last_bar; i--) RedrawOneWickLabel(i, last_bar);
}

void RedrawOneWickLabel(const int i, const int last_bar)
{
   int x, y, cw;
   uint w, h;
   datetime t;
   double p, high;
   string length, name;

   // For further use.
   high = iHigh(NULL, 0, i);

   name = GenerateObjectName("Red-", iTime(NULL, Period(), i));
   if (ObjectFind(0, name) == -1) return;
   // Needed only for y; x is used as a dummy.
   ChartTimePriceToXY(0, 0, iTime(NULL, Period(), last_bar), high, x, y);
   // Get the height of the text based on font and its size. Negative because OS-dependent, *10 because set in 1/10 of pt.
   TextSetFont(FontFace, FontSize * -10);
   length = DoubleToString(MathRound((high - MathMax(iOpen(NULL, 0, i), iClose(NULL, 0, i))) / Poin), 0);
   TextGetSize(length, w, h);

   // Normal shift of the text upward will result in negative Y coordinate and the price level will be moved down.
   // To work around this, we have to calculate the "price difference" of the necessary "pixel difference" (price height of h).
   // Then, add it to the High of the bar.
   if (y - (int)h - 2 < 0)
   {
      if (!ChartXYToTimePrice(0, x, y + h + 2, cw, t, p)) Print("Error: ", GetLastError());
      double diff = high - p;
      p = high + diff;
   }
   // Normal way.
   else ChartXYToTimePrice(0, x, y - h - 2, cw, t, p);

   ObjectSetDouble(0, name, OBJPROP_PRICE, p);
}

string GenerateObjectName(const string prefix, const datetime time)
{
   return(prefix + TimeToString(time));
}
//+------------------------------------------------------------------+