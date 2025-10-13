bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

