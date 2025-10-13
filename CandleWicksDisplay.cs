// -------------------------------------------------------------------------------
//   Displays the candle wicks' length above and below the candles.
//   Alerts when the candle's wick (shadow) reaches a certain length.
//   You can choose whether to use pips or %.
//   Press Shift+C to hide/show labels.
//   
//   Version 1.11
//   Copyright 2025, EarnForex.com
//   https://www.earnforex.com/indicators/candle-wicks-length-display/
// -------------------------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using cAlgo.API;
using cAlgo.API.Internals;

namespace cAlgo.Indicators
{
    [Indicator(IsOverlay = true, AccessRights = AccessRights.None)]
    public class CandleWicksLengthDisplay : Indicator
    {
        // Enum for units selection.
        public enum PipsPerc
        {
            Pips,
            Percentage
        }

        [Parameter("Units", DefaultValue = PipsPerc.Pips, Group = "Main")]
        public PipsPerc Units { get; set; }

        [Parameter("Display Wick Limit", DefaultValue = 5, MinValue = 0, Group = "Main")]
        public int DisplayWickLimit { get; set; }

        [Parameter("Display High Wick Color Bullish", DefaultValue = "Red", Group = "Main")]
        public Color DisplayHighWickColorBullish { get; set; }

        [Parameter("Display High Wick Color Bearish", DefaultValue = "FireBrick", Group = "Main")]
        public Color DisplayHighWickColorBearish { get; set; }

        [Parameter("Display Low Wick Color Bullish", DefaultValue = "LimeGreen", Group = "Main")]
        public Color DisplayLowWickColorBullish { get; set; }

        [Parameter("Display Low Wick Color Bearish", DefaultValue = "Green", Group = "Main")]
        public Color DisplayLowWickColorBearish { get; set; }

        [Parameter("Top Bottom Percent", DefaultValue = 0, MinValue = 0, MaxValue = 100, Group = "Main")]
        public int TopBottomPercent { get; set; }

        [Parameter("Less Than", DefaultValue = false, Group = "Main")]
        public bool LessThan { get; set; }

        [Parameter("Sound Alert", DefaultValue = false, Group = "Alerts")]
        public bool SoundAlert { get; set; }

        [Parameter("Visual Alert", DefaultValue = false, Group = "Alerts")]
        public bool VisualAlert { get; set; }

        [Parameter("Email Alert", DefaultValue = false, Group = "Alerts")]
        public bool EmailAlert { get; set; }

        [Parameter("Email Address", DefaultValue = "example@example.com", Group = "Alerts")]
        public string EmailAddress { get; set; }

        [Parameter("Alert On Limit", DefaultValue = false, Group = "Alerts")]
        public bool AlertOnLimit { get; set; }

        [Parameter("Upper Wick Limit", DefaultValue = 10, MinValue = 0, Group = "Alerts")]
        public int UpperWickLimit { get; set; }

        [Parameter("Lower Wick Limit", DefaultValue = 10, MinValue = 0, Group = "Alerts")]
        public int LowerWickLimit { get; set; }

        [Parameter("Alert On Equal Top Bottom Wicks", DefaultValue = false, Group = "Alerts")]
        public bool AlertOnEqualTopBottomWicks { get; set; }

        [Parameter("Ignore Alerts On First Run", DefaultValue = true, Group = "Alerts")]
        public bool IgnoreAlertsOnFirstRun { get; set; }

        [Parameter("Wait For Close", DefaultValue = true, Group = "Alerts")]
        public bool WaitForClose { get; set; }

        [Parameter("Font Face", DefaultValue = "Verdana", Group = "Font")]
        public string FontFace { get; set; }

        [Parameter("Font Size", DefaultValue = 18, MinValue = 5, MaxValue = 50, Group = "Font")]
        public int FontSize { get; set; }

        [Parameter("Max Candles", DefaultValue = 500, MinValue = 0, Group = "Miscellaneous")]
        public int MaxCandles { get; set; }

        [Parameter("Use Raw Pips", DefaultValue = false, Group = "Miscellaneous")]
        public bool UseRawPips { get; set; }

        [Parameter("Show Average Wick Size", DefaultValue = false, Group = "Miscellaneous")]
        public bool ShowAverageWickSize { get; set; }

        [Parameter("Average Candles", DefaultValue = 50, MinValue = 1, Group = "Miscellaneous")]
        public int AvgCandles { get; set; }

        [Parameter("Average Wick Size Color", DefaultValue = "LightGray", Group = "Miscellaneous")]
        public Color AverageWickSizeColor { get; set; }

        [Parameter("Remove Old Labels", DefaultValue = false, Group = "Miscellaneous")]
        public bool RemoveOldLabels { get; set; }

        [Parameter("Object Prefix", DefaultValue = "CWLD-", Group = "Miscellaneous")]
        public string ObjectPrefix { get; set; }

        // Global variables.
        private DateTime alertDone;
        private double poin;
        private bool canDoAlerts;
        private bool hidden = false;
        private int rates_total = 0;
        private Dictionary<string, ChartText> wickLabels = new Dictionary<string, ChartText>();
        private ChartStaticText averageWickText;

        protected override void Initialize()
        {
            // Initialize point value.
            poin = Symbol.PipSize;
            if (UseRawPips)
            {
                poin = Symbol.TickSize;
            }

            // Initialize alert capability.
            canDoAlerts = WaitForClose;

            // Create average wick size labels if needed.
            if (ShowAverageWickSize)
            {
                averageWickText = Chart.DrawStaticText(ObjectPrefix + "Average", "", VerticalAlignment.Top, HorizontalAlignment.Left, AverageWickSizeColor);
                averageWickText.FontSize = FontSize;
                averageWickText.FontFamily = FontFace;
            }

            // Subscribe to key events for show/hide functionality.
            Chart.KeyDown += OnChartKeyDown;

            // Set alertDone to avoid initial alerts if configured.
            if (IgnoreAlertsOnFirstRun && Bars.ClosePrices.Count > 0)
            {
                int alertIndex = WaitForClose && Bars.ClosePrices.Count > 1 ? 
                                Bars.ClosePrices.Count - 2 : 
                                Bars.ClosePrices.Count - 1;
                if (alertIndex >= 0)
                {
                    alertDone = Bars.OpenTimes[alertIndex];
                }
            }

            rates_total = Bars.ClosePrices.Count;
        }

        public override void Calculate(int index)
        {
            if (IsLastBar) rates_total = Bars.ClosePrices.Count; // Otherwise reports incorrect value.
            
            // Determine the bar to check (current or previous based on WaitForClose).
            int checkIndex = index;
            
            if (WaitForClose && IsLastBar)
            {
                checkIndex = index - 1;
                if (checkIndex < 0) return;
            }

            // Check if this bar is within MaxCandles limit.
            int barsFromEnd = rates_total - 1 - index;

            if (MaxCandles > 0 && barsFromEnd >= MaxCandles)
            {
                return;
            }

            // Process wick display for bars within the limit.
            ProcessWickDisplay(index);

            // Process alerts only for the most recent bar.
            if (IsLastBar)
            {
                ProcessAlerts(checkIndex);
            }

            // Update average wick sizes on the current bar.
            if (ShowAverageWickSize && IsLastBar)
            {
                CalculateAverageWicks();
            }

            // Clean up old labels if needed.
            if (RemoveOldLabels && MaxCandles > 0 && IsLastBar)
            {
                ClearOldLabels();
            }
        }

        private void ProcessWickDisplay(int index)
        {
            // Check if we should skip this bar based on TopBottomPercent.
            if (TopBottomPercent > 0 && TopBottomPercent <= 100)
            {
                double range = Bars.HighPrices[index] - Bars.LowPrices[index];
                double percent = range * TopBottomPercent / 100.0;
                
                bool topCondition = (Bars.OpenPrices[index] >= Bars.HighPrices[index] - percent) && 
                                   (Bars.ClosePrices[index] >= Bars.HighPrices[index] - percent);
                bool bottomCondition = (Bars.OpenPrices[index] <= Bars.LowPrices[index] + percent) && 
                                       (Bars.ClosePrices[index] <= Bars.LowPrices[index] + percent);
                
                if (!(topCondition || bottomCondition))
                {
                    RemoveWickLabels(index);
                    return;
                }
            }

            // Avoid division by zero for percentage calculations.
            if (Units == PipsPerc.Percentage && Bars.HighPrices[index] == Bars.LowPrices[index])
            {
                RemoveWickLabels(index);
                return;
            }

            // Process upper wick.
            ProcessUpperWick(index);

            // Process lower wick.
            ProcessLowerWick(index);
        }

        private void ProcessUpperWick(int index)
        {
            double upperWick = Bars.HighPrices[index] - Math.Max(Bars.OpenPrices[index], Bars.ClosePrices[index]);
            double upperWickValue = Units == PipsPerc.Pips ? upperWick / poin : 
                                   (Bars.HighPrices[index] - Bars.LowPrices[index]) != 0 ? 
                                   upperWick / (Bars.HighPrices[index] - Bars.LowPrices[index]) * 100 : 0;

            bool shouldDisplay = (!LessThan && upperWickValue >= DisplayWickLimit) || 
                                (LessThan && upperWickValue <= DisplayWickLimit);

            string labelName = ObjectPrefix + "Red-" + Bars.OpenTimes[index].ToString("yyyy.MM.dd HH:mm:ss");

            if (shouldDisplay)
            {
                Color wickColor = Bars.ClosePrices[index] >= Bars.OpenPrices[index] ? 
                                 DisplayHighWickColorBullish : 
                                 DisplayHighWickColorBearish;

                if (wickColor != Color.Transparent)
                {
                    // Format with 1 decimal for pips, no decimals for raw pips (points) or percentage.
                    string wickText = (Units == PipsPerc.Pips && !UseRawPips) ? 
                                     upperWickValue.ToString("F1") : 
                                     Math.Round(upperWickValue).ToString("0");
                    
                    if (!wickLabels.ContainsKey(labelName))
                    {
                        var text = Chart.DrawText(labelName, wickText, index, Bars.HighPrices[index], wickColor);
                        text.VerticalAlignment = VerticalAlignment.Top;
                        text.HorizontalAlignment = HorizontalAlignment.Center;
                        text.FontSize = FontSize;
                        text.FontFamily = FontFace;
                        wickLabels[labelName] = text;
                    }
                    else
                    {
                        wickLabels[labelName].Text = wickText;
                        wickLabels[labelName].Y = Bars.HighPrices[index];
                        wickLabels[labelName].Color = wickColor;
                    }
                }
            }
            else if (wickLabels.ContainsKey(labelName))
            {
                Chart.RemoveObject(labelName);
                wickLabels.Remove(labelName);
            }
        }

        private void ProcessLowerWick(int index)
        {
            double lowerWick = Math.Min(Bars.OpenPrices[index], Bars.ClosePrices[index]) - Bars.LowPrices[index];
            double lowerWickValue = Units == PipsPerc.Pips ? lowerWick / poin : 
                                   (Bars.HighPrices[index] - Bars.LowPrices[index]) != 0 ? 
                                   lowerWick / (Bars.HighPrices[index] - Bars.LowPrices[index]) * 100 : 0;

            bool shouldDisplay = (!LessThan && lowerWickValue >= DisplayWickLimit) || 
                                (LessThan && lowerWickValue <= DisplayWickLimit);

            string labelName = ObjectPrefix + "Green-" + Bars.OpenTimes[index].ToString("yyyy.MM.dd HH:mm:ss");

            if (shouldDisplay)
            {
                Color wickColor = Bars.ClosePrices[index] >= Bars.OpenPrices[index] ? 
                                 DisplayLowWickColorBullish : 
                                 DisplayLowWickColorBearish;

                if (wickColor != Color.Transparent)
                {
                    // Format with 1 decimal for pips, no decimals for raw pips (points) or percentage.
                    string wickText = (Units == PipsPerc.Pips && !UseRawPips) ? 
                                     lowerWickValue.ToString("F1") : 
                                     Math.Round(lowerWickValue).ToString("0");
                    
                    if (!wickLabels.ContainsKey(labelName))
                    {
                        var text = Chart.DrawText(labelName, wickText, index, Bars.LowPrices[index], wickColor);
                        text.VerticalAlignment = VerticalAlignment.Bottom;
                        text.HorizontalAlignment = HorizontalAlignment.Center;
                        text.FontSize = FontSize;
                        text.FontFamily = FontFace;
                        wickLabels[labelName] = text;
                    }
                    else
                    {
                        wickLabels[labelName].Text = wickText;
                        wickLabels[labelName].Y = Bars.LowPrices[index];
                        wickLabels[labelName].Color = wickColor;
                    }
                }
            }
            else if (wickLabels.ContainsKey(labelName))
            {
                Chart.RemoveObject(labelName);
                wickLabels.Remove(labelName);
            }
        }

        private void RemoveWickLabels(int index)
        {
            string upperLabelName = ObjectPrefix + "Red-" + Bars.OpenTimes[index].ToString("yyyy.MM.dd HH:mm:ss");
            string lowerLabelName = ObjectPrefix + "Green-" + Bars.OpenTimes[index].ToString("yyyy.MM.dd HH:mm:ss");

            if (wickLabels.ContainsKey(upperLabelName))
            {
                Chart.RemoveObject(upperLabelName);
                wickLabels.Remove(upperLabelName);
            }

            if (wickLabels.ContainsKey(lowerLabelName))
            {
                Chart.RemoveObject(lowerLabelName);
                wickLabels.Remove(lowerLabelName);
            }
        }

        private void ProcessAlerts(int index)
        {
            // Check if we've already alerted for this candle.
            if (alertDone == Bars.OpenTimes[index])
            {
                return;
            }

            // Avoid division by zero.
            if (Units == PipsPerc.Percentage && Bars.HighPrices[index] == Bars.LowPrices[index])
            {
                return;
            }

            bool doAlert = false;
            string alertMessage = "";

            if (AlertOnLimit)
            {
                double upperWick = Bars.HighPrices[index] - Math.Max(Bars.OpenPrices[index], Bars.ClosePrices[index]);
                double lowerWick = Math.Min(Bars.OpenPrices[index], Bars.ClosePrices[index]) - Bars.LowPrices[index];

                bool upperTriggered = false;
                bool lowerTriggered = false;

                if (Units == PipsPerc.Pips)
                {
                    upperTriggered = (!LessThan && upperWick / poin >= UpperWickLimit) ||
                                    (LessThan && upperWick / poin <= UpperWickLimit);
                    lowerTriggered = (!LessThan && lowerWick / poin >= LowerWickLimit) ||
                                    (LessThan && lowerWick / poin <= LowerWickLimit);
                }
                else if (Units == PipsPerc.Percentage)
                {
                    double range = Bars.HighPrices[index] - Bars.LowPrices[index];
                    upperTriggered = (!LessThan && (upperWick / range * 100) >= UpperWickLimit) ||
                                    (LessThan && (upperWick / range * 100) <= UpperWickLimit);
                    lowerTriggered = (!LessThan && (lowerWick / range * 100) >= LowerWickLimit) ||
                                    (LessThan && (lowerWick / range * 100) <= LowerWickLimit);
                }

                // Check color settings.
                bool isBullish = Bars.ClosePrices[index] >= Bars.OpenPrices[index];
                if ((isBullish && DisplayHighWickColorBullish == Color.Transparent) || 
                    (!isBullish && DisplayHighWickColorBearish == Color.Transparent))
                {
                    upperTriggered = false;
                }
                if ((isBullish && DisplayLowWickColorBullish == Color.Transparent) || 
                    (!isBullish && DisplayLowWickColorBearish == Color.Transparent))
                {
                    lowerTriggered = false;
                }

                if (upperTriggered || lowerTriggered)
                {
                    string dir = "";
                    if (upperTriggered) dir = "Upper";
                    if (lowerTriggered)
                    {
                        if (dir == "Upper") dir += "+";
                        dir += "Lower";
                    }

                    string units = Units == PipsPerc.Pips ? "pips" : "%";
                    alertMessage = string.Format("{0} {1} - {2} wick limit reached!", Symbol.Name, Bars.OpenTimes[index], dir, units);
                    doAlert = true;
                }
            }

            if (AlertOnEqualTopBottomWicks && !doAlert)
            {
                double upperWick = Bars.HighPrices[index] - Math.Max(Bars.OpenPrices[index], Bars.ClosePrices[index]);
                double lowerWick = Math.Min(Bars.OpenPrices[index], Bars.ClosePrices[index]) - Bars.LowPrices[index];

                if (Math.Abs(upperWick - lowerWick) < Symbol.TickSize)
                {
                    // Check if labels exist (meaning display conditions are met).
                    string labelName = ObjectPrefix + "Green-" + Bars.OpenTimes[index].ToString("yyyy.MM.dd HH:mm:ss");
                    if (wickLabels.ContainsKey(labelName))
                    {
                        alertMessage = string.Format("{0} {1} - Upper wick equals lower wick!", Symbol.Name, Bars.OpenTimes[index]);
                        doAlert = true;
                    }
                }
            }

            if (doAlert && canDoAlerts)
            {
                if (VisualAlert)
                {
                    Notifications.ShowPopup("Candle Wicks Length Display Alert", alertMessage, PopupNotificationState.Information);
                    Print(alertMessage);
                }

                if (SoundAlert)
                {
                    Notifications.PlaySound(SoundType.Announcement);
                }

                if (EmailAlert)
                {
                    Notifications.SendEmail(EmailAddress, EmailAddress, "Candle Wicks Length Display Alert", alertMessage);
                }

                alertDone = Bars.OpenTimes[index];
                canDoAlerts = true;
            }
        }

        private void CalculateAverageWicks()
        {
            // Determine the number of bars to use for average calculation.
            int availableBars = Bars.ClosePrices.Count;
            int limit = AvgCandles;
            
            // Limit to available bars.
            if (limit > availableBars)
                limit = availableBars;
            
            // Respect MaxCandles limit if set.
            if (MaxCandles > 0 && limit > MaxCandles)
                limit = MaxCandles;

            if (limit <= 0) return;

            double upperSum = 0;
            double lowerSum = 0;
            
            // Calculate from the most recent bars.
            int startIndex = Bars.ClosePrices.Count - limit;

            for (int i = startIndex; i < Bars.ClosePrices.Count; i++)
            {
                upperSum += Bars.HighPrices[i] - Math.Max(Bars.OpenPrices[i], Bars.ClosePrices[i]);
                lowerSum += Math.Min(Bars.OpenPrices[i], Bars.ClosePrices[i]) - Bars.LowPrices[i];
            }

            double upperAvg = upperSum / limit / poin;
            double lowerAvg = lowerSum / limit / poin;
            double allAvg = (upperSum + lowerSum) / (limit * 2) / poin;

            if (averageWickText != null)
            {
                // Always use 1 decimal for averages since they can have fractional values.
                averageWickText.Text = string.Format("Avg Upper: {0:F1}\nAvg Lower: {1:F1}\nAvg All: {2:F1}", 
                                                     upperAvg, lowerAvg, allAvg);
            }
        }

        private void ClearOldLabels()
        {
            if (MaxCandles <= 0 || MaxCandles >= Bars.ClosePrices.Count) return;

            var labelsToRemove = new List<string>();
            int oldestAllowedIndex = Bars.ClosePrices.Count - MaxCandles;
            
            foreach (var kvp in wickLabels)
            {
                DateTime date_time = kvp.Value.Time;
                // Remove if before the oldest allowed index.
                if (date_time < Bars.OpenTimes[oldestAllowedIndex])
                {
                    labelsToRemove.Add(kvp.Key);
                }
            }

            foreach (string labelName in labelsToRemove)
            {
                Chart.RemoveObject(labelName);
                wickLabels.Remove(labelName);
            }
        }

        private void OnChartKeyDown(ChartKeyboardEventArgs args)
        {
            // Check for Shift+C to toggle visibility.
            if (args.Key == Key.C && args.ShiftKey)
            {
                hidden = !hidden;
                
                // Toggle all wick labels.
                foreach (var kvp in wickLabels)
                {
                    kvp.Value.IsHidden = hidden;
                }

                // Toggle average text if it exists.
                if (ShowAverageWickSize && averageWickText != null)
                {
                    averageWickText.IsHidden = hidden;
                }
            }
        }

        public void Terminate()
        {
            // Clean up all objects.
            foreach (var labelName in wickLabels.Keys.ToList())
            {
                Chart.RemoveObject(labelName);
            }
            wickLabels.Clear();

            if (averageWickText != null) 
            {
                Chart.RemoveObject(ObjectPrefix + "Average");
            }
        }
    }
}