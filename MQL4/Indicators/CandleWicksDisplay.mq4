#property copyright "Copyright © 2023, www.EarnForex.com"
#property link      "https://www.earnforex.com/metatrader-indicators/candle-wicks-length-display/"
#property version   "1.10"
#property strict
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
input color DisplayHighWickColorBullish = clrRed;
input color DisplayHighWickColorBearish = clrFireBrick;
input color DisplayLowWickColorBullish = clrLimeGreen;
input color DisplayLowWickColorBearish = clrGreen;
input int UpperWickLimit = 10; // UpperWickLimit in broker pips or % for alerts.
input int LowerWickLimit = 10; // LowerWickLimit in broker pips or % for alerts.
input bool WaitForClose = true; // WaitForClose - Wait for a candle to close before checking wicks' length?
// If > 0 and <= 100, displays length only for bars where Open & Close within top or bottom % of candle.
input int TopBottomPercent = 0; // TopBottomPercent: Body within top/bottom percentage part.
input bool LessThan = false; // LessThan: display wicks lower than DisplayWickLimit.
input bool SoundAlert = false;
input bool VisualAlert = false;
input bool EmailAlert = false;
input bool NotificationAlert = false;
input bool AlertOnLimit = false;
input bool AlertOnEqualTopBottomWicks = false;
input bool IgnoreAlertsOnFirstRun = true;
input string FontFace = "Verdana";
input int FontSize = 10;
input int MaxCandles = 500;
input bool UseRawPips = false; // UseRawPips: if true, will use points instead of pips.
input bool ShowAverageWickSize = false; // Show average wick size
input int AvgCandles = 50; // AvgBars: how many candles to calculate the average for.
input color AverageWickSizeColor = clrLightGray;
input ENUM_BASE_CORNER Corner = CORNER_LEFT_UPPER;
input int Distance_X = 3;
input int Distance_Y = 12;
input bool DrawTextAsBackground = false; // DrawTextAsBackground: if true, the text will be drawn as background.
input bool RemoveOldLabels = false; // RemoveOldLabels: Delete labels beyond MaxCandles?
input string ObjectPrefix = "CWLD-";

// Global variables.
datetime AlertDone; // Time of the bar of the last alert.
double Poin; // Traditional point value.
bool CanDoAlerts; // Fuse to prevent alerts on initialization or timeframe change.

void OnInit()
{
    if (ShowAverageWickSize)
    {
        // Average for upper wicks.
        ObjectCreate(ChartID(), ObjectPrefix + "Upper", OBJ_LABEL, 0, 0, 0);
        ObjectSetString(ChartID(), ObjectPrefix + "Upper", OBJPROP_TEXT, "");
        ObjectSetInteger(ChartID(), ObjectPrefix + "Upper", OBJPROP_FONTSIZE, FontSize);
        ObjectSetString(ChartID(), ObjectPrefix + "Upper", OBJPROP_FONT, FontFace);
        ObjectSetInteger(ChartID(), ObjectPrefix + "Upper", OBJPROP_COLOR, AverageWickSizeColor);
        ObjectSetInteger(ChartID(), ObjectPrefix + "Upper", OBJPROP_CORNER, Corner);
        ObjectSetInteger(ChartID(), ObjectPrefix + "Upper", OBJPROP_XDISTANCE, Distance_X);
        ObjectSetInteger(ChartID(), ObjectPrefix + "Upper", OBJPROP_YDISTANCE, Distance_Y);
        ObjectSetInteger(ChartID(), ObjectPrefix + "Upper", OBJPROP_BACK, DrawTextAsBackground);
        // Average for lower wicks.
        ObjectCreate(ChartID(), ObjectPrefix + "Lower", OBJ_LABEL, 0, 0, 0);
        ObjectSetString(ChartID(), ObjectPrefix + "Lower", OBJPROP_TEXT, "");
        ObjectSetInteger(ChartID(), ObjectPrefix + "Lower", OBJPROP_FONTSIZE, FontSize);
        ObjectSetString(ChartID(), ObjectPrefix + "Lower", OBJPROP_FONT, FontFace);
        ObjectSetInteger(ChartID(), ObjectPrefix + "Lower", OBJPROP_COLOR, AverageWickSizeColor);
        ObjectSetInteger(ChartID(), ObjectPrefix + "Lower", OBJPROP_CORNER, Corner);
        ObjectSetInteger(ChartID(), ObjectPrefix + "Lower", OBJPROP_XDISTANCE, Distance_X);
        ObjectSetInteger(ChartID(), ObjectPrefix + "Lower", OBJPROP_YDISTANCE, Distance_Y + 12);
        ObjectSetInteger(ChartID(), ObjectPrefix + "Lower", OBJPROP_BACK, DrawTextAsBackground);
        // Average for all wicks.
        ObjectCreate(ChartID(), ObjectPrefix + "All", OBJ_LABEL, 0, 0, 0);
        ObjectSetString(ChartID(), ObjectPrefix + "All", OBJPROP_TEXT, "");
        ObjectSetInteger(ChartID(), ObjectPrefix + "All", OBJPROP_FONTSIZE, FontSize);
        ObjectSetString(ChartID(), ObjectPrefix + "All", OBJPROP_FONT, FontFace);
        ObjectSetInteger(ChartID(), ObjectPrefix + "All", OBJPROP_COLOR, AverageWickSizeColor);
        ObjectSetInteger(ChartID(), ObjectPrefix + "All", OBJPROP_CORNER, Corner);
        ObjectSetInteger(ChartID(), ObjectPrefix + "All", OBJPROP_XDISTANCE, Distance_X);
        ObjectSetInteger(ChartID(), ObjectPrefix + "All", OBJPROP_YDISTANCE, Distance_Y + 24);
        ObjectSetInteger(ChartID(), ObjectPrefix + "All", OBJPROP_BACK, DrawTextAsBackground);
    }

    Poin = Point;
    // Checking for unconventional Point digits number.
    if ((!UseRawPips) && (((Point == 0.00001) || (Point == 0.001)))) Poin *= 10;
    if (!WaitForClose) CanDoAlerts = false;
    else CanDoAlerts = true;
}

void OnDeinit(const int reason)
{
    ObjectsDeleteAll(ChartID(), ObjectPrefix);
}

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
    // Redraw wick labels.
    if (id == CHARTEVENT_CHART_CHANGE) RedrawVisibleWickLabels();
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime& time[],
                const double& open[],
                const double& high[],
                const double& low[],
                const double& close[],
                const long& tick_volume[],
                const long& volume[],
                const int& spread[])
{
    string name, length;
    bool DoAlert = false;

    int counted_bars = IndicatorCounted();
    if (counted_bars > 0) counted_bars--;
    int limit = Bars - counted_bars;
    if ((MaxCandles != 0) && (limit > MaxCandles)) limit = MaxCandles;

    for (int i = 0; i < limit; i++)
    {
        if ((TopBottomPercent > 0) && (TopBottomPercent <= 100))
        {
            double percent = (High[i] - Low[i]) * TopBottomPercent / 100;
            if (!(((Open[i] >= NormalizeDouble(High[i] - percent, Digits)) && (Close[i] >= NormalizeDouble(High[i] - percent, Digits))) ||
                  ((Open[i] <= NormalizeDouble(Low[i]  + percent, Digits)) && (Close[i] <= NormalizeDouble(Low[i]  + percent, Digits))))) continue;
        }

        if ((Units == Percentage) && (High[i] == Low[i])) continue; // Avoid zero-divide error.

        // Upper wick length display.
        if (
            ((!LessThan) &&
            (((Units == Pips) && (NormalizeDouble(High[i] - MathMax(Open[i], Close[i]), _Digits) >= NormalizeDouble(DisplayWickLimit * Poin, _Digits)))
            ||
             ((Units == Percentage) && ((High[i] - MathMax(Open[i], Close[i])) / (High[i] - Low[i]) * 100 >= DisplayWickLimit)))) ||
            ((LessThan) &&
            (((Units == Pips) && (NormalizeDouble(High[i] - MathMax(Open[i], Close[i]), _Digits) <= NormalizeDouble(DisplayWickLimit * Poin, _Digits)))
            ||
             ((Units == Percentage) && ((High[i] - MathMax(Open[i], Close[i])) / (High[i] - Low[i]) * 100 <= DisplayWickLimit))))
        )
        {
            name = GenerateObjectName("Red-", Time[i]);
            if (Units == Pips) length = DoubleToString(MathRound((High[i] - MathMax(Open[i], Close[i])) / Poin), 0);
            else if (Units == Percentage) length = DoubleToString(MathRound((High[i] - MathMax(Open[i], Close[i])) / (High[i] - Low[i]) * 100), 0);
            if (ObjectFind(0, name) != -1) ObjectDelete(0, name);
            color object_color;
            if (Close[i] >= Open[i]) object_color = DisplayHighWickColorBullish;
            else object_color = DisplayHighWickColorBearish;
            if (object_color != clrNONE)
            {
                ObjectCreate(0, name, OBJ_TEXT, 0, Time[i], High[i]);
                ObjectSetString(0, name, OBJPROP_TEXT, length);
                ObjectSetInteger(0, name, OBJPROP_FONTSIZE, FontSize);
                ObjectSetString(0, name, OBJPROP_FONT, FontFace);
                ObjectSetInteger(0, name, OBJPROP_COLOR, object_color);
                int visible_bars = (int)ChartGetInteger(0, CHART_VISIBLE_BARS);
                int first_bar = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
                int last_bar = first_bar - visible_bars + 1;
                if ((i <= first_bar) && (i >= last_bar)) RedrawOneWickLabel(i, last_bar);
                ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_UPPER);
                ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
                ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
            }
        }
        else // Remove tick labels that are no longer needed.
        {
            name = GenerateObjectName("Red-", Time[i]);
            if (ObjectFind(0, name) != -1) ObjectDelete(0, name);
        }
        // Lower wick length display.
        if (
            ((!LessThan) &&
            (((Units == Pips) && (NormalizeDouble(MathMin(Open[i], Close[i]) - Low[i], _Digits) >= NormalizeDouble(DisplayWickLimit * Poin, _Digits)))
            ||
            ((Units == Percentage) && ((MathMin(Open[i], Close[i]) - Low[i]) / (High[i] - Low[i]) * 100 >= DisplayWickLimit)))) ||
            ((LessThan) &&
            (((Units == Pips) && (NormalizeDouble(MathMin(Open[i], Close[i]) - Low[i], _Digits) <= NormalizeDouble(DisplayWickLimit * Poin, _Digits)))
            ||
            ((Units == Percentage) && ((MathMin(Open[i], Close[i]) - Low[i]) / (High[i] - Low[i]) * 100 <= DisplayWickLimit))))
        )
        {
            name = GenerateObjectName("Green-", Time[i]);
            if (Units == Pips) length = DoubleToString(MathRound((MathMin(Open[i], Close[i]) - Low[i]) / Poin), 0);
            else if (Units == Percentage) length = DoubleToString(MathRound((MathMin(Open[i], Close[i]) - Low[i]) / (High[i] - Low[i]) * 100), 0);
            if (ObjectFind(0, name) != -1) ObjectDelete(0, name);
            color object_color;
            if (Close[i] >= Open[i]) object_color = DisplayLowWickColorBullish;
            else object_color = DisplayLowWickColorBearish;
            if (object_color != clrNONE)
            {
                ObjectCreate(0, name, OBJ_TEXT, 0, Time[i], Low[i]);
                ObjectSetString(0, name, OBJPROP_TEXT, length);
                ObjectSetInteger(0, name, OBJPROP_FONTSIZE, FontSize);
                ObjectSetString(0, name, OBJPROP_FONT, FontFace);
                ObjectSetInteger(0, name, OBJPROP_COLOR, object_color);
                ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_UPPER);
                ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
                ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
            }
        }
        else // Remove tick labels that are no longer needed.
        {
            name = GenerateObjectName("Green-", Time[i]);
            if (ObjectFind(0, name) != -1) ObjectDelete(0, name);
        }
    }

    if ((RemoveOldLabels) && (MaxCandles > 0)) ClearOldLabels();
    
    if (ShowAverageWickSize)
    {
        limit = Bars;
        if ((AvgCandles != 0) && (limit > AvgCandles)) limit = AvgCandles;
        double upper = 0;
        double lower = 0;
        for (int i = 0; i < limit; i++)
        {
            upper += High[i] - MathMax(Open[i], Close[i]);
            lower += MathMin(Open[i], Close[i]) - Low[i];
        }
        ObjectSetString(ChartID(), ObjectPrefix + "Upper", OBJPROP_TEXT, "Avg Upper: " + DoubleToString(upper / limit / Poin, 1));
        ObjectSetString(ChartID(), ObjectPrefix + "Lower", OBJPROP_TEXT, "Avg Lower: " + DoubleToString(lower / limit / Poin, 1));
        ObjectSetString(ChartID(), ObjectPrefix + "All", OBJPROP_TEXT, "Avg All: " + DoubleToString((upper + lower) / (limit * 2) / Poin, 1));
    }

    int index = 0;
    if (WaitForClose) index = 1;
    // Already sent an alert for this candle or ignoring the initial alert when attaching the indicator first time.
    // We probably also do not want the alert to sound on index = 0 when IgnoreAlertsOnFirstRun is false but we could
    // get out-of-nowhere alerts during chart data updates.
    if ((AlertDone == Time[index]) || ((counted_bars == 0) && ((IgnoreAlertsOnFirstRun) || (index == 0))))
    {
        // For the case of IgnoreAlertsOnFirstRun.
        if (index != 0) AlertDone = Time[index];
        return rates_total;
    }

    if ((Units == Percentage) && (High[index] == Low[index])) return rates_total; // Avoid zero-divide error.

    if (AlertOnLimit)
    {
        bool UpperPipsCondition = ((Units == Pips) && (((!LessThan) && (NormalizeDouble(High[index] - MathMax(Open[index], Close[index]), _Digits) >= NormalizeDouble(UpperWickLimit * Point(), _Digits))) || ((LessThan) && (NormalizeDouble(High[index] - MathMax(Open[index], Close[index]), _Digits) <= NormalizeDouble(UpperWickLimit * Point(), _Digits)))));
        bool UpperPercentageCondition = ((Units == Percentage) && (((!LessThan) && (High[index] - MathMax(Open[index], Close[index])) / (High[index] - Low[index]) * 100 >= UpperWickLimit) || ((LessThan) && (High[index] - MathMax(Open[index], Close[index])) / (High[index] - Low[index]) * 100 <= UpperWickLimit)));
        bool LowerPipsCondition = ((Units == Pips) && (((!LessThan) && (NormalizeDouble(MathMin(Open[index], Close[index]) - Low[index], _Digits) >= NormalizeDouble(LowerWickLimit * Point(), _Digits))) || ((LessThan) && (NormalizeDouble(MathMin(Open[index], Close[index]) - Low[index], _Digits) <= NormalizeDouble(LowerWickLimit * Point(), _Digits)))));
        bool LowerPercentageCondition = ((Units == Percentage) && (((!LessThan) && (MathMin(Open[index], Close[index]) - Low[index]) / (High[index] - Low[index]) * 100 >= LowerWickLimit) || ((LessThan) && (MathMin(Open[index], Close[index]) - Low[index]) / (High[index] - Low[index]) * 100 <= LowerWickLimit)));

        // Adjust for color == none disabling:
        if (((Close[index] >= Low[index]) && (DisplayHighWickColorBullish == clrNONE)) || ((Close[index] < Low[index]) && (DisplayHighWickColorBearish == clrNONE)))
        {
            UpperPipsCondition = false;
            UpperPercentageCondition = false;
        }
        if (((Close[index] >= Low[index]) && (DisplayLowWickColorBullish == clrNONE)) || ((Close[index] < Low[index]) && (DisplayLowWickColorBearish == clrNONE)))
        {
            LowerPipsCondition = false;
            LowerPercentageCondition = false;
        }

        if ((UpperPipsCondition) || (UpperPercentageCondition) || (LowerPipsCondition) || (LowerPercentageCondition))
            DoAlert = true;

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

            if (VisualAlert) Alert(Symbol() + " " + TimeToString(Time[index]) + " " + dir + " " + units + " wick limit reached!");
            if (SoundAlert) PlaySound("alert.wav");
            if (EmailAlert) SendMail("CandleWick Alert", Symbol() + " " + TimeToString(Time[index]) + " " + dir + " " + units + " - wick limit reached!");
            if (NotificationAlert) SendNotification(Symbol() + " " + TimeToString(Time[index]) + " " + dir + " " + units + " - wick limit reached!");
            AlertDone = Time[index];
        }
    }

    if (AlertOnEqualTopBottomWicks)
    {
        bool EqualWicksCondition = (High[index] - MathMax(Open[index], Close[index]) == MathMin(Open[index], Close[index]) - Low[index]);
    
        if ((EqualWicksCondition) && (CanDoAlerts))
        {
            if (ObjectFind(ChartID(), GenerateObjectName("Green-", Time[index])) < 0) return rates_total; // No object means that the limit conditions aren't satisfied, so no alert is needed.
            if (VisualAlert) Alert(Symbol() + " " + TimeToString(Time[index]) + " Upper wick equals lower wick!");
            if (SoundAlert) PlaySound("alert.wav");
            if (EmailAlert) SendMail("CandleWick Alert", Symbol() + " " + TimeToString(Time[index]) + " Upper wick equals lower wick!");
            if (NotificationAlert) SendNotification(Symbol() + " " + TimeToString(Time[index]) + " " " Upper wick equals lower wick!");
            AlertDone = Time[index];
        }
    }

    CanDoAlerts = true;

    return rates_total;
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
    double p;
    string length, name;

    name = GenerateObjectName("Red-", Time[i]);
    if (ObjectFind(0, name) == -1) return;
    // Needed only for y; x is used as a dummy.
    ChartTimePriceToXY(0, 0, Time[last_bar], High[i], x, y);
    // Get the height of the text based on font and its size. Negative because OS-dependent, *10 because set in 1/10 of pt.
    TextSetFont(FontFace, FontSize * -10);
    length = DoubleToString(MathRound((High[i] - MathMax(Open[i], Close[i])) / Poin), 0);
    TextGetSize(length, w, h);
    ChartXYToTimePrice(0, x, y - h - 2, cw, t, p);
    ObjectSetDouble(0, name, OBJPROP_PRICE, p);
}

string GenerateObjectName(const string prefix, const datetime time)
{
    return(ObjectPrefix + prefix + TimeToString(time));
}

void ClearOldLabels()
{
    if (MaxCandles >= iBars(Symbol(), Period())) return; // Nothing to delete yet.
    
    int objects_total = ObjectsTotal(0, -1, OBJ_TEXT);
    
    for (int i = objects_total - 1; i >= 0; i--)
    {
        string object_name = ObjectName(0, i, -1, OBJ_TEXT);
        datetime object_time = (datetime)ObjectGetInteger(0, object_name, OBJPROP_TIME, 0);
        if (object_time <= Time[MaxCandles]) ObjectDelete(0, object_name);
    }
}
//+------------------------------------------------------------------+