/// A stable, sortable "YYYY-MM-DD" string for [date]'s calendar day —
/// used as a SharedPreferences key suffix wherever progress needs to reset
/// naturally at midnight (azkar, the worship tracker, "read today") without
/// an explicit daily-reset job: storage just keys off today's date.
String dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
