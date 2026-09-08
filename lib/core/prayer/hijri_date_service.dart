import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/date_key.dart';

/// A single day's Hijri date, in both languages (the API returns both in
/// one response, so there's no reason to fetch twice).
class HijriDate {
  final int day;
  final String monthAr;
  final String monthEn;
  final int year;

  const HijriDate({
    required this.day,
    required this.monthAr,
    required this.monthEn,
    required this.year,
  });
}

class HijriDateException implements Exception {}

/// Converts a Gregorian date to Hijri via aladhan.com's calendar API — the
/// same provider behind this app's adhan audio. This is *not* computed
/// locally: the standard arithmetic/"tabular" Hijri calendar was tried
/// first and checked against this API for several 2026 dates, and
/// disagreed on half of them by a day or more (Umm al-Qura follows
/// astronomical/administrative adjustments a fixed formula can't
/// reproduce) — wrong on a religious date is worse than a network
/// dependency, so this fetches the authoritative conversion instead.
class HijriDateService {
  HijriDateService(this._prefs);

  final SharedPreferences _prefs;
  final Map<String, HijriDate> _cache = {};

  String _prefsKey(DateTime date) => 'hijri.${dateKey(date)}';

  Future<HijriDate> fetch(DateTime date) async {
    final key = dateKey(date);
    final cached = _cache[key];
    if (cached != null) return cached;

    final stored = _prefs.getString(_prefsKey(date));
    if (stored != null) {
      final parsed = _decode(stored);
      if (parsed != null) {
        _cache[key] = parsed;
        return parsed;
      }
    }

    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final uri = Uri.parse(
      'https://api.aladhan.com/v1/gToH/$dd-$mm-${date.year}',
    );

    http.Response response;
    try {
      response = await http.get(uri).timeout(const Duration(seconds: 10));
    } catch (_) {
      throw HijriDateException();
    }
    if (response.statusCode != 200) throw HijriDateException();

    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final hijri = (body['data'] as Map<String, dynamic>)['hijri'] as Map<String, dynamic>;
      final month = hijri['month'] as Map<String, dynamic>;
      final result = HijriDate(
        day: int.parse(hijri['day'] as String),
        monthAr: month['ar'] as String,
        monthEn: month['en'] as String,
        year: int.parse(hijri['year'] as String),
      );
      _cache[key] = result;
      await _prefs.setString(_prefsKey(date), _encode(result));
      return result;
    } catch (_) {
      throw HijriDateException();
    }
  }

  static String _encode(HijriDate d) => '${d.day}|${d.monthAr}|${d.monthEn}|${d.year}';

  static HijriDate? _decode(String raw) {
    final parts = raw.split('|');
    if (parts.length != 4) return null;
    final day = int.tryParse(parts[0]);
    final year = int.tryParse(parts[3]);
    if (day == null || year == null) return null;
    return HijriDate(day: day, monthAr: parts[1], monthEn: parts[2], year: year);
  }
}
