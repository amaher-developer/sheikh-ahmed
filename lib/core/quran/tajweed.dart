import 'package:flutter/material.dart';

/// One run of verse text, with the tajweed rule that applies to it.
class TajweedSpan {
  final String text;

  /// The rule's API class name, or null for plain text between rules.
  final String? rule;

  const TajweedSpan(this.text, [this.rule]);
}

/// A tajweed rule: what it is called, and the colour readers expect it in.
class TajweedRule {
  final String nameKey;
  final Color color;

  const TajweedRule({required this.nameKey, required this.color});
}

/// The colours are the ones used across published tajweed Mus'hafs and by
/// quran.com, not a palette chosen here. A reader who has learned tajweed
/// from a coloured Mus'haf reads these by colour before reading the label,
/// so inventing prettier ones would make the page harder to use, not easier.
const kTajweedRules = <String, TajweedRule>{
  'ham_wasl': TajweedRule(
    nameKey: 'tajweed.ham_wasl',
    color: Color(0xFF9E9E9E),
  ),
  'slnt': TajweedRule(nameKey: 'tajweed.slnt', color: Color(0xFF9E9E9E)),
  'laam_shamsiyah': TajweedRule(
    nameKey: 'tajweed.laam_shamsiyah',
    color: Color(0xFF9E9E9E),
  ),
  'madda_normal': TajweedRule(
    nameKey: 'tajweed.madda_normal',
    color: Color(0xFF537FFF),
  ),
  'madda_permissible': TajweedRule(
    nameKey: 'tajweed.madda_permissible',
    color: Color(0xFF4050FF),
  ),
  'madda_obligatory': TajweedRule(
    nameKey: 'tajweed.madda_obligatory',
    color: Color(0xFF2144C1),
  ),
  'madda_necessary': TajweedRule(
    nameKey: 'tajweed.madda_necessary',
    color: Color(0xFF000EBC),
  ),
  'qalaqah': TajweedRule(
    nameKey: 'tajweed.qalaqah',
    color: Color(0xFFDD0008),
  ),
  'ikhafa': TajweedRule(nameKey: 'tajweed.ikhafa', color: Color(0xFF9400A8)),
  'ikhafa_shafawi': TajweedRule(
    nameKey: 'tajweed.ikhafa_shafawi',
    color: Color(0xFFD500B7),
  ),
  'idgham_ghunnah': TajweedRule(
    nameKey: 'tajweed.idgham_ghunnah',
    color: Color(0xFF169200),
  ),
  'idgham_wo_ghunnah': TajweedRule(
    nameKey: 'tajweed.idgham_wo_ghunnah',
    color: Color(0xFF169200),
  ),
  'idgham_shafawi': TajweedRule(
    nameKey: 'tajweed.idgham_shafawi',
    color: Color(0xFF58B800),
  ),
  'iqlab': TajweedRule(nameKey: 'tajweed.iqlab', color: Color(0xFF26BFFD)),
  'ghunnah': TajweedRule(nameKey: 'tajweed.ghunnah', color: Color(0xFFFF7E1E)),
};

/// `end` is the ayah-number marker the API wraps like a rule. It is not one,
/// and colouring it would put a tajweed colour on a number.
const _notARule = {'end'};

final _tagPattern = RegExp(
  r'<tajweed\s+class=([a-z_]+)\s*>(.*?)</tajweed>',
  dotAll: true,
);

/// Splits the API's marked-up verse into coloured runs.
///
/// The markup is `<tajweed class=madda_normal>ـٰ</tajweed>` around *part of a
/// word* — which is why this cannot be applied to the printed page: there
/// every word is a single pre-shaped glyph, and half a glyph cannot take a
/// different colour. Rendering the verse from its ordinary Uthmani text is
/// the only place the rules can actually be shown.
List<TajweedSpan> parseTajweed(String markup) {
  final spans = <TajweedSpan>[];
  var index = 0;

  for (final match in _tagPattern.allMatches(markup)) {
    if (match.start > index) {
      spans.add(TajweedSpan(markup.substring(index, match.start)));
    }
    final rule = match.group(1);
    final text = match.group(2) ?? '';
    spans.add(
      TajweedSpan(
        text,
        rule != null && !_notARule.contains(rule) && kTajweedRules.containsKey(rule)
            ? rule
            : null,
      ),
    );
    index = match.end;
  }

  if (index < markup.length) {
    spans.add(TajweedSpan(markup.substring(index)));
  }

  // Any tag shape this pattern did not catch would otherwise reach the screen
  // as literal angle brackets in the middle of a verse.
  return [
    for (final s in spans)
      if (s.text.isNotEmpty)
        TajweedSpan(s.text.replaceAll(RegExp('<[^>]*>'), ''), s.rule),
  ].where((s) => s.text.isNotEmpty).toList();
}

/// The rules actually present in [spans], in the order they first appear —
/// so the legend explains this verse rather than listing all sixteen.
List<String> rulesIn(List<TajweedSpan> spans) {
  final seen = <String>[];
  for (final s in spans) {
    final rule = s.rule;
    if (rule != null && !seen.contains(rule)) seen.add(rule);
  }
  return seen;
}
