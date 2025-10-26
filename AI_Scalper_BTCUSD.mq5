//+------------------------------------------------------------------+
//|                                          AI_Scalper_BTCUSD.mq5   |
//|                                  Copyright 2025, Your Name Here  |
//|                                          https://www.mql5.com    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Name Here"
#property link      "https://www.mql5.com"
#property version   "3.09"
#property strict
#property description "AI Scalper EA v3.09 for BTCUSD M1: Fixed SL/TP price levels"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>

//+------------------------------------------------------------------+
//| Structures and Enumerations                                      |
//+------------------------------------------------------------------+
struct AI_Decision
{
   string action;
   double confidence;
   double slPrice;
   double tpPrice;
   string modelName;
   string rawResponse;
};

enum ENUM_AI_VOTE_MODE
{
   VOTE_MAJORITY,     // Majority Vote (>50%)
   VOTE_UNANIMOUS,    // All AIs must agree
   VOTE_THRESHOLD     // Custom threshold percentage
};

enum ENUM_SLTP_MODE
{
   MODE_FIXED_PIPS,   // Fixed pips from entry
   MODE_PERCENTAGE,   // Percentage of entry price
   MODE_ATR_SWING,    // ATR-based calculation
   MODE_AI_REC        // AI recommended levels
};

enum ENUM_LOT_MODE
{
   LOT_FIXED,         // Fixed lot size
   LOT_RISK_BASED,    // Risk percentage per trade
   LOT_PERCENT_BALANCE // Percentage of balance
};

enum ENUM_VOLATILITY_LEVEL
{
   VOL_LOW,
   VOL_MEDIUM,
   VOL_HIGH
};

enum ENUM_TREND_MODE
{
   TREND_UP,
   TREND_DOWN,
   TREND_SIDEWAYS
};

enum ENUM_TRAILING_MODE
{
   TRAIL_OFF,
   TRAIL_PIPS,
   TRAIL_PERCENT
};

enum ENUM_ADDITIONAL_TP
{
   ADD_TP_NONE,
   ADD_TP_H1,
   ADD_TP_H4
};

enum ENUM_BREAKEVEN_MODE
{
   BE_OFF,
   BE_PIPS,
   BE_PERCENT
};

//+------------------------------------------------------------------+
//| Input Parameters - Optimized for BTCUSD                         |
//+------------------------------------------------------------------+
// API Settings
input string   OpenRouterAPIKey = "sk-or-v1-xxx";           // OpenRouter API Key
input bool     UseFreeModels = true;                        // Use Free Models
input string   FreeModelNames = "meta-llama/llama-3.2-3b-instruct:free;google/gemma-2-9b-it:free;qwen/qwen-2.5-7b-instruct:free;meta-llama/llama-3.1-8b-instruct:free;mistralai/mistral-7b-instruct:free"; // Free Model Names (semicolon-separated)
input string   PaidModelNames = "openai/gpt-4o-mini;anthropic/claude-3-haiku;openai/gpt-3.5-turbo";  // Paid Model Names (semicolon-separated)
input int      NumAIs = 5;                                   // Number of AIs to use (1-10)
input bool     AutoFallbackModels = true;                   // Auto-fallback to working models
input int      MaxFallbackAttempts = 10;                    // Maximum fallback attempts

// Voting and Signal Settings
input ENUM_AI_VOTE_MODE VoteMode = VOTE_MAJORITY;           // Voting Mode
input double   VoteThreshold = 0.6;                          // Vote Threshold (0-1)
input double   MinConfidence = 0.5;                          // Minimum Average Confidence

// SL/TP Settings - Optimized for BTC
input ENUM_SLTP_MODE SLMode = MODE_FIXED_PIPS;              // Stop Loss Mode
input ENUM_SLTP_MODE TPMode = MODE_FIXED_PIPS;              // Take Profit Mode
input double   FixedSLPips = 20.0;                          // Fixed SL in Pips (BTC optimized)
input double   FixedTPPips = 30.0;                          // Fixed TP in Pips (BTC optimized)
input double   PercentRisk = 0.5;                           // Percent Risk for SL
input double   PercentProfit = 0.75;                        // Percent Profit for TP
input double   ATRMultiplierSL = 1.5;                       // ATR Multiplier for SL
input double   ATRMultiplierTP = 2.0;                       // ATR Multiplier for TP

// Risk Management
input double   RiskPercent = 1.0;                           // Risk Percent per Trade
input double   BalancePercent = 2.0;                        // Balance Percent for Exposure
input double   LotSize = 0.01;                              // Fixed Lot Size
input ENUM_LOT_MODE LotMode = LOT_FIXED;                   // Lot Sizing Mode

// Filter Settings - Optimized for BTC volatility
input double   MaxSpreadPips = 25.0;                        // Maximum Spread in Pips (BTC optimized)
input int      AvgSpreadPeriod = 5;                         // Average Spread Period
input int      ATRPeriod = 14;                              // ATR Period
input double   MinVolatility = 5.0;                         // Minimum Volatility in Pips
input double   MaxVolatility = 1500.0;                      // Maximum Volatility in Pips (BTC optimized)
input int      BBPeriod = 20;                               // Bollinger Bands Period
input double   BBDeviation = 2.0;                           // Bollinger Bands Deviation
input double   BBMinWidth = 10.0;                           // BB Minimum Width in Pips
input double   BBMaxWidth = 3000.0;                         // BB Maximum Width in Pips (BTC optimized)

// Trading Settings
input int      MagicNumber = 12345;                         // Magic Number
input int      BarsToSend = 3;                              // Number of Bars to Send to AI (max 3 for size)
input bool     TradeOnlyOnePosition = true;                 // Trade Only One Position at a Time

// Additional Settings
input ENUM_VOLATILITY_LEVEL VolLevel = VOL_MEDIUM;          // Default Volatility Level
input bool     EnableTrendFilter = true;                    // Enable Trend Filter
input int      TrendMAPeriod = 50;                          // Trend MA Period
input ENUM_TRAILING_MODE TrailingMode = TRAIL_PIPS;        // Trailing Mode
input double   TrailingStart = 20.0;                        // Trailing Start (pips/%) - BTC optimized
input double   TrailingStop = 10.0;                         // Trailing Stop (pips/%) - BTC optimized
input double   TrailingStep = 2.0;                          // Trailing Step (pips/%) - BTC optimized
input ENUM_BREAKEVEN_MODE BreakevenMode = BE_PIPS;         // Breakeven Mode
input double   BreakevenTrigger = 15.0;                     // Breakeven Trigger (pips/%) - BTC optimized
input ENUM_ADDITIONAL_TP AdditionalTPMode = ADD_TP_NONE;   // Additional TP Mode
input bool     ShowDashboard = true;                        // Show Dashboard
input bool     UseWeightedSLTP = true;                      // Use Weighted SL/TP (vs Max Confidence)
input double   SLTPFallbackBuffer = 5.0;                    // SL/TP Fallback Buffer (pips) - BTC optimized

// Debug Settings
input bool     TestMode = false;                            // Test Mode (httpbin.org)
input bool     EnableDebugLogs = true;                      // Enable Debug Logs
input bool     ShowDetailedResponses = true;                // Show Detailed AI Responses

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
datetime lastBarTime;
int atrHandle, bbHandle, maHandle;
double atrBuffer[];
string openRouterURL = "https://openrouter.ai/api/v1/chat/completions";
double spreadHistory[100];
int spreadIndex = 0;
string lastAdvice = "NONE";
double lastConfidence = 0.0;
string selectedModelNames = "";
double pipSize;
string workingModels[];
int workingModelCount = 0;
AI_Decision lastDecisions[];
string blacklistedModels[];
int blacklistCount = 0;

CTrade trade;
CPositionInfo position;
CSymbolInfo symbolInfo;

// Updated list of verified working free models
string fallbackFreeModels[] = {
   "meta-llama/llama-3.1-8b-instruct:free",
   "meta-llama/llama-3.2-1b-instruct:free",
   "mistralai/mistral-7b-instruct:free",
   "mistralai/ministral-8b:free",
   "mistralai/ministral-3b:free",
   "qwen/qwen-2.5-7b-instruct:free",
   "qwen/qwen-2.5-3b-instruct:free",
   "qwen/qwen-2.5-coder-7b-instruct:free",
   "google/gemma-2-9b-it:free",
   "google/gemma-2-2b-it:free",
   "liquid/lfm-40b:free",
   "nousresearch/hermes-3-llama-3.1-405b:free",
   "openchat/openchat-7b:free",
   "gryphe/mythomax-l2-13b:free",
   "undi95/toppy-m-7b:free",
   "neversleep/llama-3.1-lumimaid-8b:free",
   "sophosympatheia/midnight-rose-70b:free",
   "sao10k/l3.1-euryale-70b:free",
   "meta-llama/llama-3.1-70b-instruct:free",
   "nvidia/llama-3.1-nemotron-70b-instruct:free",
   "inflection/inflection-3-pi:free",
   "thedrummer/rocinante-12b:free",
   "eva-unit-01/eva-llama-3.33-70b:free",
   "cognitivecomputations/dolphin-llama-3.1-8b:free",
   "01-ai/yi-large:free"
};

//+------------------------------------------------------------------+
//| Helper Functions - String Conversions                            |
//+------------------------------------------------------------------+
string VolatilityLevelToString(ENUM_VOLATILITY_LEVEL level)
{
   switch(level)
   {
      case VOL_LOW:    return "LOW";
      case VOL_MEDIUM: return "MEDIUM";
      case VOL_HIGH:   return "HIGH";
      default:         return "UNKNOWN";
   }
}

string TrendModeToString(ENUM_TREND_MODE trend)
{
   switch(trend)
   {
      case TREND_UP:       return "UP";
      case TREND_DOWN:     return "DOWN";
      case TREND_SIDEWAYS: return "SIDEWAYS";
      default:             return "UNKNOWN";
   }
}

string OrderTypeToString(ENUM_ORDER_TYPE type)
{
   return (type == ORDER_TYPE_BUY) ? "BUY" : "SELL";
}

//+------------------------------------------------------------------+
//| JSON Escape Function                                             |
//+------------------------------------------------------------------+
string JsonEscape(string s)
{
   string result = s;
   StringReplace(result, "\\", "\\\\");
   StringReplace(result, "\"", "\\\"");
   StringReplace(result, "\n", "\\n");
   StringReplace(result, "\r", "\\r");
   StringReplace(result, "\t", "\\t");
   return result;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Symbol validation
   string sym = _Symbol;
   if(sym != "XAUUSD" && sym != "BTCUSD")
   {
      Alert("EA designed for XAUUSD or BTCUSD only!");
      return INIT_FAILED;
   }

   // Timeframe validation
   if(_Period != PERIOD_M1)
   {
      Alert("EA designed for M1 timeframe only!");
      return INIT_FAILED;
   }

   // Symbol info initialization
   if(!symbolInfo.Name(_Symbol))
   {
      Alert("Failed to initialize symbol info!");
      return INIT_FAILED;
   }

   // Set pip size - BTCUSD typically uses 1.0 for pip (not 0.01)
   pipSize = (sym == "XAUUSD") ? 0.1 : 1.0;

   // API key validation
   string trimmedKey = OpenRouterAPIKey;
   StringTrimLeft(trimmedKey);
   StringTrimRight(trimmedKey);

   if(StringLen(trimmedKey) < 10)
   {
      Alert("API key too short!");
      return INIT_FAILED;
   }

   if(StringSubstr(trimmedKey, 0, 9) != "sk-or-v1-" && !TestMode)
   {
      Print("WARNING: API key doesn't start with 'sk-or-v1-'. Check if correct!");
   }

   // Validate NumAIs
   if(NumAIs < 1 || NumAIs > 10)
   {
      Alert("NumAIs must be between 1 and 10!");
      return INIT_FAILED;
   }

   // Model setup
   selectedModelNames = UseFreeModels ? FreeModelNames : PaidModelNames;

   // Test mode URL override
   if(TestMode)
   {
      openRouterURL = "https://httpbin.org/post";
      Print("TEST MODE: Using httpbin.org for header verification");
   }

   // Initialize indicators
   atrHandle = iATR(_Symbol, _Period, ATRPeriod);
   bbHandle = iBands(_Symbol, _Period, BBPeriod, 0, BBDeviation, PRICE_CLOSE);
   maHandle = iMA(_Symbol, _Period, TrendMAPeriod, 0, MODE_SMA, PRICE_CLOSE);

   if(atrHandle == INVALID_HANDLE || bbHandle == INVALID_HANDLE || maHandle == INVALID_HANDLE)
   {
      Alert("Failed to create indicators!");
      return INIT_FAILED;
   }

   // Set arrays as series
   ArraySetAsSeries(atrBuffer, true);

   // Initialize spread history
   ArrayInitialize(spreadHistory, 0);

   // Trading setup
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(10); // Increased for BTC volatility
   trade.SetTypeFilling(ORDER_FILLING_IOC);

   // Log initialization
   if(EnableDebugLogs)
   {
      Print("AI Scalper EA v3.09 initialized for BTCUSD");
      Print("API Key prefix: ", StringSubstr(trimmedKey, 0, 15), "...");
      Print("Using ", UseFreeModels ? "FREE" : "PAID", " models");
      Print("Selected models: ", selectedModelNames);
      Print("Auto-fallback enabled: ", AutoFallbackModels);
      Print("Total fallback models available: ", ArraySize(fallbackFreeModels));
      Print("Requesting decisions from ", NumAIs, " AIs");
      Print("Pip size: ", pipSize);
      Print("Point size: ", _Point);
   }

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
   if(bbHandle != INVALID_HANDLE) IndicatorRelease(bbHandle);
   if(maHandle != INVALID_HANDLE) IndicatorRelease(maHandle);
   Comment("");
}

//+------------------------------------------------------------------+
//| Count positions with our magic number                            |
//+------------------------------------------------------------------+
int CountMyPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Magic() == MagicNumber && position.Symbol() == _Symbol)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Calculate average spread                                         |
//+------------------------------------------------------------------+
double CalculateAvgSpread(int period)
{
   double sum = 0;
   int count = 0;
   for(int i = 0; i < period && i < 100; i++)
   {
      int idx = (spreadIndex - i + 100) % 100;
      if(spreadHistory[idx] > 0)
      {
         sum += spreadHistory[idx];
         count++;
      }
   }
   return (count > 0) ? sum / count : 0;
}

//+------------------------------------------------------------------+
//| Check volatility conditions - Enhanced for crypto                |
//+------------------------------------------------------------------+
bool IsVolatilityOK()
{
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) != 1) return false;

   double upper[], lower[];
   ArraySetAsSeries(upper, true);
   ArraySetAsSeries(lower, true);
   if(CopyBuffer(bbHandle, 1, 0, 1, upper) != 1) return false;
   if(CopyBuffer(bbHandle, 2, 0, 1, lower) != 1) return false;

   double bbWidth = upper[0] - lower[0];

   // Convert to pips for comparison
   double atrPips = atr[0] / pipSize;
   double bbWidthPips = bbWidth / pipSize;

   // Debug output
   if(EnableDebugLogs)
   {
      Print("Volatility Check:");
      Print("  ATR: ", DoubleToString(atr[0], _Digits), " (", DoubleToString(atrPips, 1), " pips)");
      Print("  ATR Range: ", MinVolatility, " - ", MaxVolatility, " pips");
      Print("  BB Width: ", DoubleToString(bbWidth, _Digits), " (", DoubleToString(bbWidthPips, 1), " pips)");
      Print("  BB Range: ", BBMinWidth, " - ", BBMaxWidth, " pips");
   }

   // Compare in pips
   bool atrOK = (atrPips >= MinVolatility && atrPips <= MaxVolatility);
   bool bbOK = (bbWidthPips >= BBMinWidth && bbWidthPips <= BBMaxWidth);

   if(EnableDebugLogs)
   {
      Print("  ATR OK: ", atrOK);
      Print("  BB OK: ", bbOK);
      Print("  Overall Volatility OK: ", (atrOK && bbOK));
   }

   return (atrOK && bbOK);
}

//+------------------------------------------------------------------+
//| Get current trend                                                |
//+------------------------------------------------------------------+
ENUM_TREND_MODE GetTrend()
{
   double ma[];
   ArraySetAsSeries(ma, true);
   if(CopyBuffer(maHandle, 0, 0, 2, ma) != 2) return TREND_SIDEWAYS;

   double close = symbolInfo.Bid();

   if(close > ma[0] && ma[0] > ma[1])
      return TREND_UP;
   else if(close < ma[0] && ma[0] < ma[1])
      return TREND_DOWN;
   else
      return TREND_SIDEWAYS;
}

//+------------------------------------------------------------------+
//| Get volatility level - Optimized for crypto                      |
//+------------------------------------------------------------------+
ENUM_VOLATILITY_LEVEL GetVolatilityLevel()
{
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) != 1) return VOL_MEDIUM;

   double atrPips = atr[0] / pipSize;

   // Adjusted thresholds for BTCUSD volatility
   if(_Symbol == "BTCUSD")
   {
      if(atrPips < 20) return VOL_LOW;
      else if(atrPips < 50) return VOL_MEDIUM;
      else return VOL_HIGH;
   }
   else // XAUUSD
   {
      if(atrPips < 5) return VOL_LOW;
      else if(atrPips < 15) return VOL_MEDIUM;
      else return VOL_HIGH;
   }
}

//+------------------------------------------------------------------+
//| Calculate additional TP based on higher timeframe                |
//+------------------------------------------------------------------+
double CalculateAdditionalTP(bool isBuy)
{
   ENUM_TIMEFRAMES tf = (AdditionalTPMode == ADD_TP_H1) ? PERIOD_H1 : PERIOD_H4;
   double close[];
   ArraySetAsSeries(close, true);

   if(CopyClose(_Symbol, tf, 0, 1, close) != 1)
      return 0;

   double current = isBuy ? symbolInfo.Ask() : symbolInfo.Bid();
   double projection = current + (isBuy ? 1 : -1) * 1.5 * MathAbs(close[0] - current);

   return projection;
}

//+------------------------------------------------------------------+
//| Modify position SL/TP                                            |
//+------------------------------------------------------------------+
bool ModifyPosition(ulong ticket, double newSL, double newTP)
{
   if(!position.SelectByTicket(ticket)) return false;

   // Normalize prices
   newSL = NormalizeDouble(newSL, _Digits);
   newTP = NormalizeDouble(newTP, _Digits);

   trade.PositionModify(ticket, newSL, newTP);

   if(EnableDebugLogs)
   {
      Print("Modified position ", ticket, " SL: ", newSL, " TP: ", newTP,
            " Result: ", trade.ResultRetcode());
   }

   return (trade.ResultRetcode() == TRADE_RETCODE_DONE);
}

//+------------------------------------------------------------------+
//| Open trade with proper price levels                              |
//+------------------------------------------------------------------+
bool OpenTrade(ENUM_ORDER_TYPE type, double lot, double sl, double tp)
{
   double price = (type == ORDER_TYPE_BUY) ? symbolInfo.Ask() : symbolInfo.Bid();

   // Normalize all prices
   price = NormalizeDouble(price, _Digits);
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);

   // Validate stops
   double minStopLevel = symbolInfo.StopsLevel() * _Point;
   double minStopLevelPips = minStopLevel / pipSize;

   if(minStopLevel > 0)
   {
      if(type == ORDER_TYPE_BUY)
      {
         if(sl > 0 && price - sl < minStopLevel)
         {
            sl = price - minStopLevel - pipSize;
            Print("Adjusted SL to minimum stop level: ", sl);
         }
         if(tp > 0 && tp - price < minStopLevel)
         {
            tp = price + minStopLevel + pipSize;
            Print("Adjusted TP to minimum stop level: ", tp);
         }
      }
      else // SELL
      {
         if(sl > 0 && sl - price < minStopLevel)
         {
            sl = price + minStopLevel + pipSize;
            Print("Adjusted SL to minimum stop level: ", sl);
         }
         if(tp > 0 && price - tp < minStopLevel)
         {
            tp = price - minStopLevel - pipSize;
            Print("Adjusted TP to minimum stop level: ", tp);
         }
      }
   }

   bool result = trade.PositionOpen(_Symbol, type, lot, price, sl, tp,
                                   "AI Scalper v3.09");

   if(EnableDebugLogs)
   {
      Print("Opening ", OrderTypeToString(type), " Lot: ", lot,
            " Price: ", price, " SL: ", sl, " TP: ", tp,
            " Result: ", trade.ResultRetcode());
      if(trade.ResultRetcode() != TRADE_RETCODE_DONE)
      {
         Print("Error: ", trade.ResultRetcodeDescription());
      }
   }

   return result;
}

//+------------------------------------------------------------------+
//| Prepare enhanced prompt for AI with BTC context                 |
//+------------------------------------------------------------------+
string PreparePrompt()
{
   double ask = symbolInfo.Ask();
   double bid = symbolInfo.Bid();
   double spread = (ask - bid) / _Point;
   double spreadPips = spread * _Point / pipSize;

   double atr[];
   ArraySetAsSeries(atr, true);
   CopyBuffer(atrHandle, 0, 0, 1, atr);
   double atrPips = atr[0] / pipSize;

   // Calculate suggested SL/TP levels for AI - BTC optimized (as actual prices)
   double suggestSL_Buy = bid - (FixedSLPips * pipSize);
   double suggestTP_Buy = bid + (FixedTPPips * pipSize);
   double suggestSL_Sell = ask + (FixedSLPips * pipSize);
   double suggestTP_Sell = ask - (FixedTPPips * pipSize);

   // Enhanced prompt with clearer instructions for crypto trading
   string prompt = "Trading signal for BTCUSD M1 scalping:\n";
   prompt += "Current: Bid=" + DoubleToString(bid, _Digits) + " Ask=" + DoubleToString(ask, _Digits) + "\n";
   prompt += "Spread=" + DoubleToString(spreadPips, 1) + " pips, ATR=" + DoubleToString(atrPips, 1) + " pips\n";

   // Add recent price movement
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, _Period, 0, 3, rates);
   if(copied >= 3)
   {
      double move1 = (rates[0].close - rates[1].close) / pipSize;
      double move2 = (rates[1].close - rates[2].close) / pipSize;
      prompt += "Recent moves: " + DoubleToString(move2, 1) + "p -> " + DoubleToString(move1, 1) + "p\n";

      // Add volume info for crypto
      double vol1 = rates[0].real_volume;
      double vol2 = rates[1].real_volume;
      prompt += "Volume trend: " + ((vol1 > vol2) ? "increasing" : "decreasing") + "\n";
   }

   prompt += "\nProvide crypto trading signal in EXACT format:\n";
   prompt += "ACTION:BUY|CONFIDENCE:0.8|SL:" + DoubleToString(suggestSL_Buy, _Digits) +
             "|TP:" + DoubleToString(suggestTP_Buy, _Digits) + "\n";
   prompt += "OR\n";
   prompt += "ACTION:SELL|CONFIDENCE:0.8|SL:" + DoubleToString(suggestSL_Sell, _Digits) +
             "|TP:" + DoubleToString(suggestTP_Sell, _Digits) + "\n";
   prompt += "OR\n";
   prompt += "ACTION:HOLD|CONFIDENCE:0.0|SL:0|TP:0\n";
   prompt += "\nREPLY WITH ONE LINE ONLY IN EXACT FORMAT ABOVE. SL and TP must be PRICE LEVELS, not pips!";

   return prompt;
}

//+------------------------------------------------------------------+
//| Check if model is blacklisted                                    |
//+------------------------------------------------------------------+
bool IsModelBlacklisted(string model)
{
   for(int i = 0; i < blacklistCount; i++)
   {
      if(blacklistedModels[i] == model)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Add model to blacklist                                           |
//+------------------------------------------------------------------+
void AddToBlacklist(string model)
{
   ArrayResize(blacklistedModels, blacklistCount + 1);
   blacklistedModels[blacklistCount] = model;
   blacklistCount++;
}

//+------------------------------------------------------------------+
//| Get AI decision from single model with error handling            |
//+------------------------------------------------------------------+
string GetAIDecision(string prompt, string modelName, bool &success)
{
   success = false;

   // Skip if blacklisted
   if(IsModelBlacklisted(modelName))
   {
      if(EnableDebugLogs)
         Print("Skipping blacklisted model: ", modelName);
      return "ACTION:HOLD|CONFIDENCE:0.0|SL:0|TP:0";
   }

   string trimmedKey = OpenRouterAPIKey;
   StringTrimLeft(trimmedKey);
   StringTrimRight(trimmedKey);

   // Prepare headers
   string headers = "Content-Type: application/json\r\n";
   headers += "Authorization: Bearer " + trimmedKey + "\r\n";

   // Prepare compact body with crypto-specific system message
   string escapedPrompt = JsonEscape(prompt);

   string body = "{";
   body += "\"model\":\"" + modelName + "\",";
   body += "\"messages\":[";
   body += "{\"role\":\"system\",\"content\":\"You are a cryptocurrency trading AI specializing in BTCUSD scalping. Always provide SL and TP as PRICE LEVELS (e.g., 67123.45), NOT as pips or relative values. Respond ONLY with the exact format requested.\"},";
   body += "{\"role\":\"user\",\"content\":\"" + escapedPrompt + "\"}";
   body += "],";
   body += "\"max_tokens\":60,";
   body += "\"temperature\":0.1";
   body += "}";

   // Prepare request
   char postData[];
   char result[];
   string resultHeaders;

   StringToCharArray(body, postData, 0, StringLen(body), CP_UTF8);
   ArrayResize(postData, ArraySize(postData) - 1);

   ResetLastError();
   int res = WebRequest("POST", openRouterURL, headers, 30000, postData, result, resultHeaders);

   if(res != 200)
   {
      if(EnableDebugLogs)
      {
         Print("Model ", modelName, " failed with HTTP ", res);
      }

      // Add to blacklist if it's a persistent error
      if(res == 404 || res == 400)
      {
         AddToBlacklist(modelName);
         Print("Added ", modelName, " to blacklist");
      }

      return "ACTION:HOLD|CONFIDENCE:0.0|SL:0|TP:0";
   }

   success = true;

   // Parse response
   string response = CharArrayToString(result, 0, ArraySize(result), CP_UTF8);

   // Test mode handling
   if(TestMode)
   {
      double testPrice = symbolInfo.Bid();
      return "ACTION:BUY|CONFIDENCE:0.8|SL:" + DoubleToString(testPrice - 20*pipSize, _Digits) +
             "|TP:" + DoubleToString(testPrice + 30*pipSize, _Digits);
   }

   // Find content in response
   int contentPos = StringFind(response, "\"content\":");
   if(contentPos == -1)
   {
      if(EnableDebugLogs)
         Print("No content found in response from ", modelName);
      return "ACTION:HOLD|CONFIDENCE:0.0|SL:0|TP:0";
   }

   int startPos = StringFind(response, "\"", contentPos + 10);
   if(startPos == -1) return "ACTION:HOLD|CONFIDENCE:0.0|SL:0|TP:0";

   int endPos = startPos + 1;
   while(endPos < StringLen(response))
   {
      if(StringSubstr(response, endPos, 1) == "\"" &&
         StringSubstr(response, endPos - 1, 1) != "\\")
         break;
      endPos++;
   }

   string content = StringSubstr(response, startPos + 1, endPos - startPos - 1);

   // Unescape
   StringReplace(content, "\\n", "\n");
   StringReplace(content, "\\\"", "\"");
   StringReplace(content, "\\\\", "\\");

   StringTrimLeft(content);
   StringTrimRight(content);

   // Extract the ACTION line if multiple lines
   if(StringFind(content, "ACTION:") >= 0)
   {
      int actionStart = StringFind(content, "ACTION:");
      int lineEnd = StringFind(content, "\n", actionStart);
      if(lineEnd > actionStart)
         content = StringSubstr(content, actionStart, lineEnd - actionStart);
      else if(actionStart > 0)
         content = StringSubstr(content, actionStart);
   }

   if(ShowDetailedResponses)
   {
      string modelShort = modelName;
      int slashPos = StringFind(modelShort, "/");
      if(slashPos > 0)
         modelShort = StringSubstr(modelShort, slashPos + 1, 20);
      Print(modelShort, " response: ", content);
   }

   return content;
}

//+------------------------------------------------------------------+
//| Parse AI decision string with complete SL/TP extraction          |
//+------------------------------------------------------------------+
void ParseAIDecision(string decStr, AI_Decision &dec)
{
   dec.action = "HOLD";
   dec.confidence = 0.0;
   dec.slPrice = 0;
   dec.tpPrice = 0;
   dec.rawResponse = decStr;

   // Handle empty or invalid responses
   if(StringLen(decStr) < 10)
   {
      return;
   }

   // Convert to uppercase for easier parsing
   string upperStr = decStr;
   StringToUpper(upperStr);

   // Parse ACTION
   if(StringFind(upperStr, "ACTION:BUY") >= 0)
      dec.action = "BUY";
   else if(StringFind(upperStr, "ACTION:SELL") >= 0)
      dec.action = "SELL";
   else
      dec.action = "HOLD";

   // Parse CONFIDENCE
   int confPos = StringFind(upperStr, "CONFIDENCE:");
   if(confPos >= 0)
   {
      string tempStr = StringSubstr(decStr, confPos + 11, 10);
      string numStr = "";

      for(int i = 0; i < StringLen(tempStr); i++)
      {
         string ch = StringSubstr(tempStr, i, 1);
         if((ch >= "0" && ch <= "9") || ch == ".")
            numStr += ch;
         else if(StringLen(numStr) > 0)
            break;
      }

      dec.confidence = StringToDouble(numStr);
      if(dec.confidence < 0) dec.confidence = 0;
      if(dec.confidence > 1) dec.confidence = 1;
   }
   else if(dec.action != "HOLD")
   {
      dec.confidence = 0.7; // Default confidence for BUY/SELL
   }

   // Parse SL
   int slPos = StringFind(upperStr, "SL:");
   if(slPos >= 0)
   {
      string tempStr = StringSubstr(decStr, slPos + 3, 15);
      string numStr = "";

      for(int i = 0; i < StringLen(tempStr); i++)
      {
         string ch = StringSubstr(tempStr, i, 1);
         if((ch >= "0" && ch <= "9") || ch == ".")
            numStr += ch;
         else if(StringLen(numStr) > 0)
            break;
      }

      dec.slPrice = StringToDouble(numStr);
   }

   // Parse TP
   int tpPos = StringFind(upperStr, "TP:");
   if(tpPos >= 0)
   {
      string tempStr = StringSubstr(decStr, tpPos + 3, 15);
      string numStr = "";

      for(int i = 0; i < StringLen(tempStr); i++)
      {
         string ch = StringSubstr(tempStr, i, 1);
         if((ch >= "0" && ch <= "9") || ch == ".")
            numStr += ch;
         else if(StringLen(numStr) > 0)
            break;
      }

      dec.tpPrice = StringToDouble(numStr);
   }

   // Validate and apply defaults if needed - BTC optimized
   if(dec.action == "BUY" || dec.action == "SELL")
   {
      double currentPrice = (dec.action == "BUY") ? symbolInfo.Ask() : symbolInfo.Bid();

      // Check if AI gave reasonable price levels
      bool slValid = false;
      bool tpValid = false;

      if(dec.action == "BUY")
      {
         slValid = (dec.slPrice > 0 && dec.slPrice < currentPrice &&
                   (currentPrice - dec.slPrice) >= 5 * pipSize &&
                   (currentPrice - dec.slPrice) <= 100 * pipSize);
         tpValid = (dec.tpPrice > 0 && dec.tpPrice > currentPrice &&
                   (dec.tpPrice - currentPrice) >= 5 * pipSize &&
                   (dec.tpPrice - currentPrice) <= 200 * pipSize);
      }
      else // SELL
      {
         slValid = (dec.slPrice > 0 && dec.slPrice > currentPrice &&
                   (dec.slPrice - currentPrice) >= 5 * pipSize &&
                   (dec.slPrice - currentPrice) <= 100 * pipSize);
         tpValid = (dec.tpPrice > 0 && dec.tpPrice < currentPrice &&
                   (currentPrice - dec.tpPrice) >= 5 * pipSize &&
                   (currentPrice - dec.tpPrice) <= 200 * pipSize);
      }

      // Apply defaults if invalid
      if(!slValid)
      {
         if(dec.action == "BUY")
            dec.slPrice = currentPrice - FixedSLPips * pipSize;
         else
            dec.slPrice = currentPrice + FixedSLPips * pipSize;
      }

      if(!tpValid)
      {
         if(dec.action == "BUY")
            dec.tpPrice = currentPrice + FixedTPPips * pipSize;
         else
            dec.tpPrice = currentPrice - FixedTPPips * pipSize;
      }
   }
}

//+------------------------------------------------------------------+
//| Check if model has been tried                                    |
//+------------------------------------------------------------------+
bool IsModelTried(string model, string &triedModels[], int triedCount)
{
   for(int i = 0; i < triedCount; i++)
   {
      if(triedModels[i] == model)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Get decisions from multiple AIs with enhanced fallback          |
//+------------------------------------------------------------------+
void GetMultiAIDecisions(string prompt, AI_Decision &decisions[], string modelList)
{
   // Initialize decisions array
   ArrayResize(decisions, 0);
   ArrayResize(lastDecisions, 0);

   // Split model list
   string models[];
   int modelCount = StringSplit(modelList, ';', models);

   // Track all tried models
   string triedModels[];
   int triedCount = 0;

   // Track working models
   ArrayResize(workingModels, 0);
   workingModelCount = 0;

   int successCount = 0;
   int fallbackIndex = 0;
   int totalAttempts = 0;
   int targetAIs = NumAIs;

   Print("\n=== GATHERING AI DECISIONS ===");
   Print("Target: ", targetAIs, " AI responses");

   // Try primary models first
   for(int i = 0; i < modelCount && successCount < targetAIs && totalAttempts < MaxFallbackAttempts; i++)
   {
      string model = models[i];
      StringTrimLeft(model);
      StringTrimRight(model);

      if(StringLen(model) > 0 && !IsModelBlacklisted(model))
      {
         Print("Querying AI ", successCount + 1, ": ", model);

         // Add to tried models
         ArrayResize(triedModels, triedCount + 1);
         triedModels[triedCount] = model;
         triedCount++;
         totalAttempts++;

         bool success = false;
         string response = GetAIDecision(prompt, model, success);

         if(success)
         {
            AI_Decision tempDec;
            tempDec.modelName = model;
            ParseAIDecision(response, tempDec);

            // Only add if we got a valid response
            if(tempDec.confidence > 0 || tempDec.action == "HOLD")
            {
               ArrayResize(decisions, successCount + 1);
               decisions[successCount] = tempDec;

               string modelShort = model;
               int slashPos = StringFind(modelShort, "/");
               if(slashPos > 0)
                  modelShort = StringSubstr(modelShort, slashPos + 1, 15);

               Print("✓ ", modelShort, " => ", tempDec.action,
                     " (Conf:", DoubleToString(tempDec.confidence * 100, 0), "%",
                     " SL:", DoubleToString(tempDec.slPrice, _Digits),
                     " TP:", DoubleToString(tempDec.tpPrice, _Digits), ")");

               successCount++;

               // Add to working models
               ArrayResize(workingModels, workingModelCount + 1);
               workingModels[workingModelCount] = model;
               workingModelCount++;
            }
         }
      }
   }

   // Use fallback models if needed
   if(successCount < targetAIs && AutoFallbackModels)
   {
      Print("Need ", targetAIs - successCount, " more responses. Trying fallback models...");

      while(successCount < targetAIs && fallbackIndex < ArraySize(fallbackFreeModels) &&
            totalAttempts < MaxFallbackAttempts)
      {
         string fallbackModel = fallbackFreeModels[fallbackIndex];
         fallbackIndex++;

         if(!IsModelTried(fallbackModel, triedModels, triedCount) && !IsModelBlacklisted(fallbackModel))
         {
            Print("Trying fallback: ", fallbackModel);

            // Add to tried models
            ArrayResize(triedModels, triedCount + 1);
            triedModels[triedCount] = fallbackModel;
            triedCount++;
            totalAttempts++;

            bool success = false;
            string response = GetAIDecision(prompt, fallbackModel, success);

            if(success)
            {
               AI_Decision tempDec;
               tempDec.modelName = fallbackModel;
               ParseAIDecision(response, tempDec);

               if(tempDec.confidence > 0 || tempDec.action == "HOLD")
               {
                  ArrayResize(decisions, successCount + 1);
                  decisions[successCount] = tempDec;

                  string modelShort = fallbackModel;
                  int slashPos = StringFind(modelShort, "/");
                  if(slashPos > 0)
                     modelShort = StringSubstr(modelShort, slashPos + 1, 15);

                  Print("✓ ", modelShort, " => ", tempDec.action,
                        " (Conf:", DoubleToString(tempDec.confidence * 100, 0), "%",
                        " SL:", DoubleToString(tempDec.slPrice, _Digits),
                        " TP:", DoubleToString(tempDec.tpPrice, _Digits), ")");

                  successCount++;

                  // Add to working models
                  ArrayResize(workingModels, workingModelCount + 1);
                  workingModels[workingModelCount] = fallbackModel;
                  workingModelCount++;
               }
            }
         }
      }
   }

   // Copy to lastDecisions for dashboard
   if(successCount > 0)
   {
      ArrayResize(lastDecisions, successCount);
      for(int i = 0; i < successCount; i++)
      {
         lastDecisions[i] = decisions[i];
      }
   }

   Print("Successfully collected ", successCount, " AI responses");
   Print("=== END AI DECISIONS ===\n");
}

//+------------------------------------------------------------------+
//| Vote on AI decisions with detailed analysis                      |
//+------------------------------------------------------------------+
string VoteDecisions(AI_Decision &decisions[])
{
   int buyCount = 0, sellCount = 0, holdCount = 0;
   double buyConfSum = 0, sellConfSum = 0;
   double totalConf = 0;
   int validCount = 0;

   int decisionCount = ArraySize(decisions);
   if(decisionCount == 0) return "HOLD";

   Print("=== VOTING ANALYSIS ===");
   Print("Total responses: ", decisionCount);

   // Count votes and calculate confidence
   for(int i = 0; i < decisionCount; i++)
   {
      if(decisions[i].action == "BUY")
      {
         buyCount++;
         buyConfSum += decisions[i].confidence;
      }
      else if(decisions[i].action == "SELL")
      {
         sellCount++;
         sellConfSum += decisions[i].confidence;
      }
      else
      {
         holdCount++;
      }

      if(decisions[i].confidence > 0)
      {
         totalConf += decisions[i].confidence;
         validCount++;
      }
   }

   double avgConf = (validCount > 0) ? totalConf / validCount : 0;
   double buyAvgConf = (buyCount > 0) ? buyConfSum / buyCount : 0;
   double sellAvgConf = (sellCount > 0) ? sellConfSum / sellCount : 0;

   Print("Votes: BUY=", buyCount, " (avg conf ", DoubleToString(buyAvgConf * 100, 1), "%)");
   Print("      SELL=", sellCount, " (avg conf ", DoubleToString(sellAvgConf * 100, 1), "%)");
   Print("      HOLD=", holdCount);
   Print("Overall Average Confidence: ", DoubleToString(avgConf * 100, 1), "%");
   Print("Minimum Required: ", DoubleToString(MinConfidence * 100, 1), "%");

   // Check minimum confidence
   if(avgConf < MinConfidence)
   {
      Print("Decision: HOLD (confidence too low)");
      Print("=== END VOTING ===\n");
      return "HOLD";
   }

   string decision = "HOLD";

   // Apply voting mode
   switch(VoteMode)
   {
      case VOTE_MAJORITY:
         if(buyCount > decisionCount / 2) decision = "BUY";
         else if(sellCount > decisionCount / 2) decision = "SELL";
         Print("Majority vote (>50%): ", decision);
         break;

      case VOTE_UNANIMOUS:
         if(buyCount == decisionCount) decision = "BUY";
         else if(sellCount == decisionCount) decision = "SELL";
         Print("Unanimous vote: ", decision);
         break;

      case VOTE_THRESHOLD:
      {
         double buyPct = (double)buyCount / decisionCount;
         double sellPct = (double)sellCount / decisionCount;
         Print("Buy percentage: ", DoubleToString(buyPct * 100, 1), "%");
         Print("Sell percentage: ", DoubleToString(sellPct * 100, 1), "%");
         Print("Threshold: ", DoubleToString(VoteThreshold * 100, 1), "%");

         if(buyPct >= VoteThreshold) decision = "BUY";
         else if(sellPct >= VoteThreshold) decision = "SELL";
         break;
      }
   }

   Print("*** FINAL DECISION: ", decision, " ***");
   Print("=== END VOTING ===\n");

   return decision;
}

//+------------------------------------------------------------------+
//| Calculate adaptive SL/TP - BTC optimized                         |
//+------------------------------------------------------------------+
void CalculateAdaptiveSLTP(bool isBuy, double &sl, double &tp,
                          double aiSL, double aiTP, double entry, double pipSizeParam)
{
   double atr[];
   ArraySetAsSeries(atr, true);
   CopyBuffer(atrHandle, 0, 0, 1, atr);

   // Calculate SL (as price level, not pips)
   switch(SLMode)
   {
      case MODE_AI_REC:
         sl = aiSL;
         break;
      case MODE_FIXED_PIPS:
         sl = isBuy ? entry - FixedSLPips * pipSizeParam : entry + FixedSLPips * pipSizeParam;
         break;
      case MODE_PERCENTAGE:
         sl = isBuy ? entry * (1 - PercentRisk / 100) : entry * (1 + PercentRisk / 100);
         break;
      case MODE_ATR_SWING:
         sl = isBuy ? entry - ATRMultiplierSL * atr[0] : entry + ATRMultiplierSL * atr[0];
         break;
   }

   // Calculate TP (as price level, not pips)
   switch(TPMode)
   {
      case MODE_AI_REC:
         tp = aiTP;
         break;
      case MODE_FIXED_PIPS:
         tp = isBuy ? entry + FixedTPPips * pipSizeParam : entry - FixedTPPips * pipSizeParam;
         break;
      case MODE_PERCENTAGE:
         tp = isBuy ? entry * (1 + PercentProfit / 100) : entry * (1 - PercentProfit / 100);
         break;
      case MODE_ATR_SWING:
         tp = isBuy ? entry + ATRMultiplierTP * atr[0] : entry - ATRMultiplierTP * atr[0];
         break;
   }
}

//+------------------------------------------------------------------+
//| Calculate dynamic lot size                                      |
//+------------------------------------------------------------------+
double CalculateDynamicLot(double entry, double slPrice)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   double lot = 0;

   switch(LotMode)
   {
      case LOT_FIXED:
         lot = LotSize;
         break;

      case LOT_RISK_BASED:
         {
            double riskAmount = balance * RiskPercent / 100;
            double slPoints = MathAbs(entry - slPrice) / _Point;
            if(slPoints > 0 && tickValue > 0)
            {
               lot = riskAmount / (slPoints * tickValue);
            }
         }
         break;

      case LOT_PERCENT_BALANCE:
         {
            double exposure = balance * BalancePercent / 100;
            double contractSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
            if(contractSize > 0 && entry > 0)
            {
               lot = exposure / (contractSize * entry);
            }
         }
         break;
   }

   // Normalize lot
   if(lot < minLot) lot = minLot;
   if(lot > maxLot) lot = maxLot;
   lot = MathFloor(lot / lotStep) * lotStep;

   return lot;
}

//+------------------------------------------------------------------+
//| Manage open positions with crypto-specific adjustments          |
//+------------------------------------------------------------------+
void ManagePositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Magic() != MagicNumber || position.Symbol() != _Symbol)
            continue;

         double openPrice = position.PriceOpen();
         double currentSL = position.StopLoss();
         double currentTP = position.TakeProfit();
         double currentPrice = (position.PositionType() == POSITION_TYPE_BUY) ?
                              symbolInfo.Bid() : symbolInfo.Ask();

         double profitPips = (position.PositionType() == POSITION_TYPE_BUY) ?
                            (currentPrice - openPrice) / pipSize :
                            (openPrice - currentPrice) / pipSize;

         // Breakeven logic
         if(BreakevenMode != BE_OFF && profitPips > 0)
         {
            double beTrigger = (BreakevenMode == BE_PIPS) ?
                              BreakevenTrigger :
                              openPrice * BreakevenTrigger / 100 / pipSize;

            if(profitPips >= beTrigger && currentSL != openPrice)
            {
               ModifyPosition(position.Ticket(), openPrice, currentTP);
            }
         }

         // Trailing stop logic
         if(TrailingMode != TRAIL_OFF && profitPips >= TrailingStart)
         {
            double trailStop = (TrailingMode == TRAIL_PIPS) ?
                              TrailingStop :
                              openPrice * TrailingStop / 100 / pipSize;

            double newSL = (position.PositionType() == POSITION_TYPE_BUY) ?
                          currentPrice - trailStop * pipSize :
                          currentPrice + trailStop * pipSize;

            double slDiff = (position.PositionType() == POSITION_TYPE_BUY) ?
                           newSL - currentSL : currentSL - newSL;

            if(slDiff >= TrailingStep * pipSize)
            {
               ModifyPosition(position.Ticket(), newSL, currentTP);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Update dashboard with complete AI information                    |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   if(!ShowDashboard) return;

   double ask = symbolInfo.Ask();
   double bid = symbolInfo.Bid();
   double spread = (ask - bid) / _Point;
   double spreadPips = spread * _Point / pipSize;

   ENUM_VOLATILITY_LEVEL volLevel = GetVolatilityLevel();
   ENUM_TREND_MODE trend = GetTrend();

   double atr[];
   ArraySetAsSeries(atr, true);
   CopyBuffer(atrHandle, 0, 0, 1, atr);
   double atrPips = atr[0] / pipSize;

   string dash = "";
   dash += "=== AI SCALPER v3.09 BTCUSD ===\n";
   dash += "Symbol: " + _Symbol + " | Timeframe: M1\n";
   dash += "Bid: " + DoubleToString(bid, _Digits) + " | Ask: " + DoubleToString(ask, _Digits) + "\n";
   dash += "Trend: " + TrendModeToString(trend) + " | ";
   dash += "Volatility: " + VolatilityLevelToString(volLevel) + "\n";
   dash += "ATR: " + DoubleToString(atrPips, 1) + "p | ";
   dash += "Spread: " + DoubleToString(spreadPips, 1) + "p\n";
   dash += "------------------------\n";
   dash += "VOTE RESULT: " + lastAdvice + " (" +
           DoubleToString(lastConfidence * 100, 1) + "%)\n";

   // Show individual AI decisions with SL/TP
   if(ArraySize(lastDecisions) > 0)
   {
      dash += "AI Responses (" + IntegerToString(ArraySize(lastDecisions)) + "):\n";

      int buyVotes = 0, sellVotes = 0, holdVotes = 0;

      for(int i = 0; i < ArraySize(lastDecisions) && i < 10; i++)
      {
         string modelShort = lastDecisions[i].modelName;
         int slashPos = StringFind(modelShort, "/");
         if(slashPos > 0)
            modelShort = StringSubstr(modelShort, slashPos + 1, 12);

         dash += IntegerToString(i+1) + ". " + modelShort + ": " +
                lastDecisions[i].action + " " +
                DoubleToString(lastDecisions[i].confidence * 100, 0) + "%";

         if(lastDecisions[i].action != "HOLD" && lastDecisions[i].slPrice > 0 && lastDecisions[i].tpPrice > 0)
         {
            double slPips = 0, tpPips = 0;
            if(lastDecisions[i].action == "BUY")
            {
               slPips = (bid - lastDecisions[i].slPrice) / pipSize;
               tpPips = (lastDecisions[i].tpPrice - bid) / pipSize;
            }
            else
            {
               slPips = (lastDecisions[i].slPrice - ask) / pipSize;
               tpPips = (ask - lastDecisions[i].tpPrice) / pipSize;
            }

            dash += " SL:" + DoubleToString(slPips, 1) + "p TP:" + DoubleToString(tpPips, 1) + "p";
         }

         dash += "\n";

         if(lastDecisions[i].action == "BUY") buyVotes++;
         else if(lastDecisions[i].action == "SELL") sellVotes++;
         else holdVotes++;
      }

      dash += "Votes: B=" + IntegerToString(buyVotes) +
              " S=" + IntegerToString(sellVotes) +
              " H=" + IntegerToString(holdVotes) + "\n";
   }

   dash += "------------------------\n";
   dash += "Positions: " + IntegerToString(CountMyPositions()) + " | ";
   dash += "Working AIs: " + IntegerToString(workingModelCount) + "/" + IntegerToString(NumAIs) + "\n";
   dash += "Risk: " + DoubleToString(RiskPercent, 1) + "% | ";
   dash += "SL/TP Mode: " + (SLMode == MODE_AI_REC ? "AI" : "Fixed") + "\n";

   if(blacklistCount > 0)
      dash += "Blacklisted models: " + IntegerToString(blacklistCount) + "\n";

   if(TestMode) dash += "*** TEST MODE ***\n";

   Comment(dash);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check for new bar
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   bool isNewBar = (currentBarTime != lastBarTime);

   if(isNewBar)
   {
      lastBarTime = currentBarTime;

      // Check position limit
      if(TradeOnlyOnePosition && CountMyPositions() > 0)
      {
         UpdateDashboard();
         ManagePositions();
         return;
      }

      // Update spread history
      double currentSpread = (symbolInfo.Ask() - symbolInfo.Bid()) / _Point;
      spreadHistory[spreadIndex] = currentSpread;
      spreadIndex = (spreadIndex + 1) % 100;

      double avgSpread = CalculateAvgSpread(AvgSpreadPeriod);
      double avgSpreadPips = avgSpread * _Point / pipSize;
      bool spreadOK = (avgSpreadPips <= MaxSpreadPips);

      // Check filters
      ENUM_TREND_MODE trend = GetTrend();
      bool volOK = IsVolatilityOK();

      Print("\n========== NEW BAR ANALYSIS ==========");
      Print("Time: ", TimeToString(currentBarTime));
      Print("Market: ", _Symbol, " Bid:", DoubleToString(symbolInfo.Bid(), _Digits),
            " Ask:", DoubleToString(symbolInfo.Ask(), _Digits));
      Print("Spread: ", DoubleToString(avgSpreadPips, 1),
            " pips (Max allowed: ", DoubleToString(MaxSpreadPips, 1), ")");
      Print("Spread OK: ", spreadOK ? "Yes" : "No");
      Print("Trend: ", TrendModeToString(trend));
      Print("Volatility OK: ", volOK ? "Yes" : "No");

      // Prepare prompt and get AI decisions
      string prompt = PreparePrompt();

      AI_Decision decisions[];
      GetMultiAIDecisions(prompt, decisions, selectedModelNames);

      // Vote on decisions
      string vote = VoteDecisions(decisions);

      // Calculate average confidence
      double totalConf = 0;
      int validCount = 0;
      for(int i = 0; i < ArraySize(decisions); i++)
      {
         if(decisions[i].confidence > 0)
         {
            totalConf += decisions[i].confidence;
            validCount++;
         }
      }
      double avgConf = (validCount > 0) ? totalConf / validCount : 0;

      lastAdvice = vote;
      lastConfidence = avgConf;

      // Process signal if not HOLD
      if(vote != "HOLD")
      {
         Print("\n*** TRADE SIGNAL DETECTED: ", vote, " ***");

         bool isBuy = (vote == "BUY");
         double entry = isBuy ? symbolInfo.Ask() : symbolInfo.Bid();

         // Calculate weighted or max confidence SL/TP from agreeing AIs
         double aiSL = 0, aiTP = 0;
         int agreeCount = 0;

         Print("Calculating SL/TP from AI recommendations...");

         if(UseWeightedSLTP)
         {
            double slSum = 0, tpSum = 0, confSum = 0;
            for(int i = 0; i < ArraySize(decisions); i++)
            {
               if(decisions[i].action == vote && decisions[i].confidence > 0)
               {
                  if(decisions[i].slPrice > 0 && decisions[i].tpPrice > 0)
                  {
                     slSum += decisions[i].slPrice * decisions[i].confidence;
                     tpSum += decisions[i].tpPrice * decisions[i].confidence;
                     confSum += decisions[i].confidence;
                     agreeCount++;

                     string modelShort = decisions[i].modelName;
                     int slashPos = StringFind(modelShort, "/");
                     if(slashPos > 0)
                        modelShort = StringSubstr(modelShort, slashPos + 1, 15);

                     Print("  ", modelShort, " suggests SL:", decisions[i].slPrice,
                           " TP:", decisions[i].tpPrice,
                           " (weight:", DoubleToString(decisions[i].confidence, 2), ")");
                  }
               }
            }
            if(confSum > 0)
            {
               aiSL = slSum / confSum;
               aiTP = tpSum / confSum;
               Print("Weighted average: SL=", aiSL, " TP=", aiTP);
            }
         }
         else
         {
            // Use max confidence AI's SL/TP
            double maxConf = 0;
            string bestModel = "";
            for(int i = 0; i < ArraySize(decisions); i++)
            {
               if(decisions[i].action == vote && decisions[i].confidence > maxConf)
               {
                  if(decisions[i].slPrice > 0 && decisions[i].tpPrice > 0)
                  {
                     maxConf = decisions[i].confidence;
                     aiSL = decisions[i].slPrice;
                     aiTP = decisions[i].tpPrice;
                     bestModel = decisions[i].modelName;
                     agreeCount++;
                  }
               }
            }
            if(StringLen(bestModel) > 0)
            {
               int slashPos = StringFind(bestModel, "/");
               if(slashPos > 0)
                  bestModel = StringSubstr(bestModel, slashPos + 1, 20);
               Print("Using highest confidence AI (", bestModel, "): SL=", aiSL, " TP=", aiTP);
            }
         }

         // Calculate final SL/TP
         double finalSL = 0, finalTP = 0;
         CalculateAdaptiveSLTP(isBuy, finalSL, finalTP, aiSL, aiTP, entry, pipSize);

         // Validate and fallback if needed - BTC specific validation
         if(isBuy)
         {
            if(finalSL >= entry || finalSL <= 0)
               finalSL = entry - (FixedSLPips + SLTPFallbackBuffer) * pipSize;
            if(finalTP <= entry || finalTP <= 0)
               finalTP = entry + (FixedTPPips + SLTPFallbackBuffer) * pipSize;

            // Additional sanity check for BTC
            double slDist = (entry - finalSL) / pipSize;
            double tpDist = (finalTP - entry) / pipSize;

            if(slDist < 5) finalSL = entry - 10 * pipSize;  // Minimum 10 pips SL
            if(tpDist < 5) finalTP = entry + 15 * pipSize;  // Minimum 15 pips TP
            if(slDist > 100) finalSL = entry - 50 * pipSize; // Maximum 50 pips SL
            if(tpDist > 150) finalTP = entry + 75 * pipSize; // Maximum 75 pips TP
         }
         else
         {
            if(finalSL <= entry || finalSL <= 0)
               finalSL = entry + (FixedSLPips + SLTPFallbackBuffer) * pipSize;
            if(finalTP >= entry || finalTP <= 0)
               finalTP = entry - (FixedTPPips + SLTPFallbackBuffer) * pipSize;

            // Additional sanity check for BTC
            double slDist = (finalSL - entry) / pipSize;
            double tpDist = (entry - finalTP) / pipSize;

            if(slDist < 5) finalSL = entry + 10 * pipSize;  // Minimum 10 pips SL
            if(tpDist < 5) finalTP = entry - 15 * pipSize;  // Minimum 15 pips TP
            if(slDist > 100) finalSL = entry + 50 * pipSize; // Maximum 50 pips SL
            if(tpDist > 150) finalTP = entry - 75 * pipSize; // Maximum 75 pips TP
         }

         // Apply additional TP if enabled
         if(AdditionalTPMode != ADD_TP_NONE && TPMode != MODE_AI_REC)
         {
            double addTP = CalculateAdditionalTP(isBuy);
            if(addTP > 0) finalTP = addTP;
         }

         // Calculate lot size
         double lot = CalculateDynamicLot(entry, finalSL);

         // Normalize all prices
         finalSL = NormalizeDouble(finalSL, _Digits);
         finalTP = NormalizeDouble(finalTP, _Digits);

         Print("\nTrade Parameters:");
         Print("  Entry: ", entry);
         Print("  Stop Loss: ", finalSL, " (",
               DoubleToString(MathAbs(entry - finalSL) / pipSize, 1), " pips)");
         Print("  Take Profit: ", finalTP, " (",
               DoubleToString(MathAbs(finalTP - entry) / pipSize, 1), " pips)");
         Print("  Lot Size: ", lot);
         Print("  Risk/Reward: 1:",
               DoubleToString(MathAbs(finalTP - entry) / MathAbs(entry - finalSL), 1));

         // Check trend filter
         bool trendOK = !EnableTrendFilter ||
                       (isBuy && trend == TREND_UP) ||
                       (!isBuy && trend == TREND_DOWN);

         Print("\nFilter Status:");
         Print("  Spread OK: ", spreadOK);
         Print("  Volatility OK: ", volOK);
         Print("  Trend OK: ", trendOK);

         // Execute trade if all filters pass
         if(spreadOK && volOK && trendOK)
         {
            if(OpenTrade(isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, lot, finalSL, finalTP))
            {
               Print("\n*** TRADE EXECUTED SUCCESSFULLY ***");
               Print("Direction: ", vote, " | Confidence: ", DoubleToString(avgConf * 100, 1), "%");
               Print("Used ", workingModelCount, " AI models for decision");
            }
         }
         else
         {
            string rejectReason = "\n*** TRADE REJECTED ***\nReasons: ";
            if(!spreadOK) rejectReason += "High-Spread ";
            if(!volOK) rejectReason += "Bad-Volatility ";
            if(!trendOK) rejectReason += "Wrong-Trend ";
            Print(rejectReason);
         }
      }
      else
      {
         Print("\nNo trade signal - Decision: HOLD");
      }

      Print("======================================\n");
   }

   // Always update dashboard and manage positions
   UpdateDashboard();
   ManagePositions();
}
//+------------------------------------------------------------------+
