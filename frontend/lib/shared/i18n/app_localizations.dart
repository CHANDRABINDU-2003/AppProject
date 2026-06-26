/// Lightweight, app-wide string table (English only).
///
/// Why not `flutter_localizations` / generated ARB files? For this app a small,
/// dependency-free table keeps things simple: [AppLocalizations.t] looks a key
/// up in the table.
///
/// Usage in a widget:  `Text(tr("nav.weather"))`
///
/// Static translation table + lookup.
class AppLocalizations {
  AppLocalizations._();

  /// Translate [key]; falls back to the raw key when unknown.
  static String t(String key) => _strings[key] ?? key;

  static const Map<String, String> _strings = {
      // ── Generic ──
      "app.tagline": "Smart farming",
      "common.cancel": "Cancel",
      "common.close": "Close",
      "common.retry": "Retry",
      "common.enable": "Enable",
      "common.error": "Error",
      "common.loading": "Loading…",
      "common.save": "Save",
      "common.book": "Book",
      "common.today": "Today",

      // ── Navigation (farmer) ──
      "nav.home": "Home",
      "nav.overview": "Overview",
      "nav.crops": "My Crops",
      "nav.disease": "Disease Detection",
      "nav.fertilizer": "Fertilizer Recommendation",
      "nav.weatherAlerts": "Weather & Alerts",
      "nav.sellers": "Nearby Sellers",
      "nav.marketplace": "Marketplace",
      "nav.community": "Community",
      "nav.consult": "Consult Analyst",
      "nav.analytics": "Analytics",
      "nav.askAi": "Ask AI",
      // (legacy keys kept for any remaining references)
      "nav.market": "Market",
      "nav.alerts": "Alerts",
      "nav.assistant": "Assistant",
      "nav.history": "History",

      // ── Overview / smart tools ──
      "overview.welcome": "Welcome back",
      "overview.snapshot": "Here's a snapshot of your farm activity.",
      "tools.title": "Smart tools",
      "tools.weather": "Weather dashboard",
      "tools.weatherSub": "Temperature, rain, humidity and wind.",
      "tools.analytics": "Farm analytics",
      "tools.analyticsSub": "Crops, health and revenue at a glance.",
      "tools.consult": "Consult analyst",
      "tools.consultSub": "Book a consultation with the analyst.",

      // ── Weather ──
      "weather.title": "Weather dashboard",
      "weather.subtitle": "Current conditions and a 3-day outlook for your farm.",
      "weather.temperature": "Temperature",
      "weather.rain": "Rain probability",
      "weather.humidity": "Humidity",
      "weather.wind": "Wind speed",
      "weather.forecast": "3-day forecast",
      "weather.unavailable":
          "Location unavailable. Allow location access to see the weather for your farm.",

      // ── Crop calendar ──
      "calendar.title": "Crop calendar",
      "calendar.subtitle": "Pick a crop and sowing date to plan your season.",
      "calendar.crop": "Crop",
      "calendar.sowingDate": "Sowing date",
      "calendar.generate": "Generate calendar",
      "calendar.stage": "Stage",
      "calendar.date": "Date",
      "calendar.empty": "Choose a crop and sowing date, then generate your plan.",

      // ── Analytics ──
      "analytics.title": "Farm analytics",
      "analytics.subtitle": "Your farming activity at a glance.",
      "analytics.totalCrops": "Total crops",
      "analytics.healthyCrops": "Healthy crops",
      "analytics.diseasedCrops": "Diseased crops",
      "analytics.sales": "Marketplace orders",
      "analytics.revenue": "Revenue",
      "analytics.revenueOverTime": "Revenue over time",
      "analytics.noRevenue": "Log crops with a price and quantity to see revenue.",
      "analytics.cropYieldTrend": "Crop yield trend",
      "analytics.diseaseTrend": "Disease trend",
      "analytics.fertilizerUsage": "Fertilizer usage",
      "analytics.monthlyProduction": "Monthly production",
      "analytics.noData": "Log some crop history to see this chart.",
      "analytics.noDisease": "No disease checks recorded yet.",

      // ── Appointments (consult the analyst) ──
      "appt.title": "Consult analyst",
      "appt.subtitle": "Book a consultation with the analyst.",
      "appt.selectDate": "Select date",
      "appt.selectTime": "Select time",
      "appt.problem": "Describe your problem",
      "appt.problemHint": "What issue are you facing?",
      "appt.topic": "Topic (optional)",
      "appt.topicHint": "What would you like to discuss?",
      "appt.book": "Book consultation",
      "appt.mine": "My appointments",
      "appt.none": "No appointments yet.",
      "appt.booked": "Consultation booked.",
      "appt.with": "With",
      "appt.cancel": "Cancel",
      "appt.confirm": "Confirm",
      "appt.complete": "Complete",
      "appt.statusPending": "Pending",
      "appt.statusConfirmed": "Confirmed",
      "appt.statusCompleted": "Completed",
      "appt.statusCancelled": "Cancelled",

      // ── AI assistant (focused question modes) ──
      "assistant.title": "AI assistant",
      "assistant.modeFarming": "Farming question",
      "assistant.modeDisease": "Disease question",
      "assistant.modeFertilizer": "Fertilizer question",
      "assistant.greetFarming":
          "Ask me anything about crops, soil, seasons or general farming.",
      "assistant.greetDisease":
          "Describe the symptoms and I'll help identify the crop disease and treatment.",
      "assistant.greetFertilizer":
          "Tell me your crop and soil and I'll suggest the right fertilizer.",
      "assistant.hintFarming": "e.g. When should I sow rice in my region?",
      "assistant.hintDisease": "e.g. My tomato leaves have brown spots — what is it?",
      "assistant.hintFertilizer": "e.g. Which fertilizer suits maize in sandy soil?",
      "assistant.unavailable": "Assistant unavailable",
  };
}

/// Shorthand used throughout the UI: `tr("nav.weather")`.
String tr(String key) => AppLocalizations.t(key);
