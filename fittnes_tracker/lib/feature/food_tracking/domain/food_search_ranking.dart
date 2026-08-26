/// Relevance ranking for food search results.
///
/// This lived as seven private methods inside `_FoodAddScreenState`, a 1,582-
/// line widget with no test coverage at all. Nothing about it needs a
/// `BuildContext`, a database or a widget tree: it takes a query and a name
/// and returns an integer. It was untested only because of where it sat.
///
/// That matters more here than in most extractions, because this is the kind
/// of code where a wrong answer is *plausible* rather than obviously broken.
/// A Levenshtein bound that is off by one, a diacritic missing from the fold
/// map, a penalty that makes "Ei" rank below "Eierlikör" — each produces a
/// result list that looks fine and is simply worse, and no compiler, analyzer
/// or widget test has anything to say about any of them. The only thing that
/// can is an assertion about the ordering itself.
///
/// Scores are **lower-is-better**, and the bands are deliberately far apart so
/// a tie inside one band never crosses another: exact 0, single-token 1,
/// prefix 5+, word-boundary 15, first-token 20/30, later-token 40/50, fuzzy
/// 100+, substring 200+, no match [noMatch].
library;

/// Returned when a name does not match the query at all. Large enough that it
/// can be used as a sentinel *and* sorted with the rest without a special case.
const int noMatch = 1000000;

/// Lowercase and trim. Names arrive from three sources (the local database,
/// Open Food Facts and the BLS import) with three capitalisation habits.
String normalizeQuery(String s) => s.toLowerCase().trim();

const Map<String, String> _diacritics = {
  // German
  'ä': 'a', 'ö': 'o', 'ü': 'u', 'ß': 'ss',
  // French
  'à': 'a', 'â': 'a', 'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ç': 'c',
  'æ': 'ae', 'œ': 'oe',
  // Spanish/Portuguese
  'á': 'a', 'ã': 'a', 'í': 'i', 'ó': 'o', 'õ': 'o', 'ú': 'u', 'ñ': 'n',
  // Nordic
  'å': 'a',
  // General accents
  'ì': 'i', 'î': 'i', 'ï': 'i',
  'ò': 'o', 'ô': 'o',
  'ù': 'u', 'û': 'u',
};

/// Folds accents so a query typed on a keyboard without them still matches.
/// `ß` folds to `ss` rather than `s` — the German pair is a real equivalence,
/// not an accent, and folding it to a single `s` would put "Weißbrot" one
/// edit further from "weissbrot" than from an unrelated word.
String removeDiacritics(String s) {
  var result = s;
  _diacritics.forEach((key, value) {
    result = result.replaceAll(key, value);
  });
  return result;
}

/// Splits on anything that is not a letter or digit. The class keeps the
/// accented characters so this stays usable on un-folded text too.
List<String> tokenize(String s) {
  return s
      .split(RegExp(r'[^a-z0-9äöüßàáâãäåèéêëìíîïòóôõöùúûüñç]+'))
      .where((t) => t.isNotEmpty)
      .toList();
}

/// Edit distance, used only to catch typos in the fuzzy band.
int levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  final m = a.length, n = b.length;
  final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));

  for (var i = 0; i <= m; i++) {
    dp[i][0] = i;
  }
  for (var j = 0; j <= n; j++) {
    dp[0][j] = j;
  }

  for (var i = 1; i <= m; i++) {
    for (var j = 1; j <= n; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      dp[i][j] = [
        dp[i - 1][j] + 1,
        dp[i][j - 1] + 1,
        dp[i - 1][j - 1] + cost,
      ].reduce((a, b) => a < b ? a : b);
    }
  }
  return dp[m][n];
}

/// Scores one name against one query. Lower is better; [noMatch] is no match.
int nameScore(String query, String name) {
  final qRaw = normalizeQuery(query);
  final nRaw = normalizeQuery(name);

  if (qRaw.isEmpty || nRaw.isEmpty) return noMatch;

  final q = removeDiacritics(qRaw);
  final n = removeDiacritics(nRaw);

  if (q == n) return 0;

  final nTokens = tokenize(n);
  final qTokens = tokenize(q);

  if (qTokens.isEmpty || nTokens.isEmpty) return noMatch;

  final queryTerm = qTokens.first;

  if (nTokens.length == 1 && nTokens.first == queryTerm) return 1;

  if (n.startsWith(q)) {
    final lengthDiff = n.length - q.length;
    // Short queries need a steep penalty so "Ei" doesn't rank
    // equally with "Eis" or "Eierlikör".
    final penalty = q.length <= 3 ? lengthDiff * 8 : lengthDiff ~/ 5;
    return 5 + penalty;
  }

  if (n.contains(' $q') || n.contains('-$q')) return 15;

  if (nTokens.first == queryTerm) {
    return 20 + (nTokens.length - 1) * 5;
  }

  if (nTokens.first.startsWith(queryTerm)) {
    return 30 +
        (nTokens.first.length - queryTerm.length) +
        (nTokens.length - 1) * 5;
  }

  for (int i = 1; i < nTokens.length; i++) {
    if (nTokens[i] == queryTerm) return 40 + i * 5;
  }

  for (int i = 1; i < nTokens.length; i++) {
    if (nTokens[i].startsWith(queryTerm)) {
      return 50 + (nTokens[i].length - queryTerm.length) + i * 5;
    }
  }

  if (queryTerm.length >= 3) {
    // BLS names are long and comma-qualified (e.g. "Fettsäure C22:6 n-3
    // all-cis (Docosahexaensäure)"), so fuzzy matching needs more than the
    // first 3 tokens to find a hit anywhere in the name.
    final tokensToCheck = nTokens.take(6);
    for (int idx = 0; idx < tokensToCheck.length; idx++) {
      final token = tokensToCheck.elementAt(idx);
      final lenDiff = (token.length - queryTerm.length).abs();
      if (lenDiff <= 2) {
        final dist = levenshtein(token, queryTerm);
        if (dist <= 2) {
          return 100 + (dist * 20) + lenDiff + idx * 10;
        }
      }
    }
  }

  if (queryTerm.length >= 4) {
    final tokensToCheck = nTokens.take(6);
    for (int idx = 0; idx < tokensToCheck.length; idx++) {
      final token = tokensToCheck.elementAt(idx);
      if (token.contains(queryTerm)) {
        return 200 + (token.length - queryTerm.length) + idx * 20;
      }
    }
  }

  return noMatch;
}

/// Scores a result against whichever name field the query actually
/// matches best. Verified items carry both `_name_en` and `_name_de`
/// (the display name alone is locale-pinned via `product_name`, so a
/// German query that only matches `nameDe` would otherwise score against
/// the English name when the app locale is English, and vice versa).
int bestNameScore(String query, Map<String, dynamic> item) {
  final candidates = <String>{
    itemName(item),
    if (item['_name_en'] is String) item['_name_en'] as String,
    if (item['_name_de'] is String) item['_name_de'] as String,
  }..removeWhere((s) => s.isEmpty);
  if (candidates.isEmpty) return noMatch;
  var best = noMatch;
  for (final name in candidates) {
    final score = nameScore(query, name);
    if (score < best) best = score;
  }
  return best;
}

/// Extract the display name from a search result item.
///
/// `brands` is the last resort rather than a peer of the name keys: Open Food
/// Facts has entries whose only populated text is the brand, and showing
/// "Barilla" beats showing an empty row — but preferring it over a real name
/// would label every product with its manufacturer.
String itemName(dynamic item) {
  if (item is Map) {
    for (final k in ['product_name', 'name', 'title', 'label']) {
      final v = item[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    final brands = item['brands'];
    if (brands != null && brands.toString().trim().isNotEmpty) {
      return brands.toString();
    }
    return '';
  }
  try {
    final v = item.name;
    return v?.toString() ?? '';
  } catch (_) {
    return '';
  }
}
