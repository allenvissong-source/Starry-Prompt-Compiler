// Lexical recall for world-info entries: tokenization + Okapi BM25.
//
// Why this exists: the matcher's keyword paths are `haystack.contains(needle)`
// and, for whole-word mode, `\b<needle>\b`. Neither works for Chinese. Measured
// on the real Kalabiyou assets, both failure directions are live:
//
//   * missed recall — the entry about Michele's father declares the key
//     「米雪儿的父亲」, so a user asking「你父亲怎么了」matches nothing: the
//     five-character string simply is not in the probe, and no amount of
//     re-ranking helps because the entry never becomes a candidate;
//   * false recall — 19 of the bundled entries carry keys of one or two
//     characters, so「塔罗牌好玩吗」fires 科摩斯塔 (key 「塔」) and「我信你」
//     fires 信.
//
// This module addresses the first direction only, as an *additional* candidate
// channel. Author-declared keys keep their exact-match semantics: that is the
// mental model SillyTavern users have, and a probabilistic score must not
// override an explicit instruction.
//
// No dependencies and no I/O, per this package's constraints: the tokenizer is
// hand-rolled rather than dictionary-based (see [tokenizeForRecall]).

import 'dart:math' as math;

/// Okapi BM25 term-frequency saturation. 1.2 is the standard default.
const double _k1 = 1.2;

/// Okapi BM25 length normalization. 0.75 is the standard default.
const double _b = 0.75;

/// Splits text into the tokens recall matches on.
///
/// Exists so the segmentation strategy is replaceable without touching the
/// ranker or the matcher. The default [BigramRecallTokenizer] is deliberately
/// dictionary-free, which costs precision on short Chinese keys: measured on the
/// bundled assets, a one-character key like 「塔」 fires inside 「塔罗牌」, and
/// bigrams cannot tell that 「塔」 is the tail of 「科摩斯塔」. The three
/// zero-dependency alternatives each lose more than they gain (see
/// `starry-dsh-plugin/CONTRACT.md` §3.7), so raising precision eventually means
/// supplying a word list — which is a *tokenizer* concern and nothing else.
/// Hence this seam.
///
/// Implementations must be deterministic: the same input always yields the same
/// tokens in the same order, or `resolve` stops being byte-for-byte
/// reproducible.
abstract interface class RecallTokenizer {
  List<String> tokenize(String text);
}

/// The default [RecallTokenizer]: CJK to bigrams, Latin to whole words.
///
/// See [tokenizeForRecall] for the segmentation rules and the reasoning behind
/// them.
class BigramRecallTokenizer implements RecallTokenizer {
  const BigramRecallTokenizer();

  @override
  List<String> tokenize(String text) => tokenizeForRecall(text);
}

/// Splits [text] into recall tokens.
///
/// Two token families, produced from the same pass so mixed-script text yields
/// both:
///
///   * **CJK → bigrams.** Adjacent-character pairs within each unbroken CJK run
///     (「父亲怎么」→ 父亲, 亲怎, 怎么). A lone CJK character in a run of one
///     degrades to that character itself, so single-character keys still index.
///   * **Latin/digits → whole words, lower-cased.** Preserves the existing
///     word-ish behavior for keys like `P.U.S.` and `Scissors`.
///
/// Everything else (punctuation, whitespace, symbols) is a separator and is
/// dropped.
///
/// Bigrams rather than dictionary segmentation is a deliberate trade. A real
/// segmenter (jieba and friends) is more precise, but needs either a native
/// dependency or a bundled word list — too heavy for an on-device injection
/// service, and this package may not do I/O at all. Bigrams also happen to fit
/// the dominant failure case: 「米雪儿的父亲」 and 「父亲」 share the 父亲
/// bigram, so a substring relationship survives without a dictionary.
///
/// Deterministic: same input always yields the same list in the same order.
List<String> tokenizeForRecall(String text) {
  if (text.isEmpty) return const <String>[];

  final tokens = <String>[];
  final run = StringBuffer();
  var runIsCjk = false;

  void flush() {
    if (run.isEmpty) return;
    final value = run.toString();
    run.clear();
    if (runIsCjk) {
      if (value.length == 1) {
        // No pair available; index the character itself so single-character keys
        // are not silently unindexable.
        tokens.add(value);
      } else {
        for (var i = 0; i + 1 < value.length; i++) {
          tokens.add(value.substring(i, i + 2));
        }
      }
    } else {
      tokens.add(value.toLowerCase());
    }
  }

  for (final rune in text.runes) {
    final isCjk = _isCjk(rune);
    final isWordish = _isWordish(rune);
    if (!isCjk && !isWordish) {
      flush();
      continue;
    }
    if (run.isNotEmpty && isCjk != runIsCjk) {
      flush();
    }
    runIsCjk = isCjk;
    run.writeCharCode(rune);
  }
  flush();

  return List<String>.unmodifiable(tokens);
}

/// True when [rune] is a CJK ideograph or a Japanese kana.
///
/// Deliberately narrow: only scripts that are written without spaces need
/// bigram treatment. Latin, Cyrillic and Greek keep word tokenization.
bool _isCjk(int rune) {
  return (rune >= 0x4E00 && rune <= 0x9FFF) || // CJK Unified Ideographs
      (rune >= 0x3400 && rune <= 0x4DBF) || // Ext A
      (rune >= 0xF900 && rune <= 0xFAFF) || // Compatibility Ideographs
      (rune >= 0x3040 && rune <= 0x30FF) || // Hiragana + Katakana
      (rune >= 0x20000 && rune <= 0x2A6DF); // Ext B
}

/// True when [rune] may be part of a Latin-style word token.
///
/// The non-ASCII range is an allow-list of letter blocks rather than "everything
/// above U+00C0": that catch-all also swallowed general punctuation, so 「…」
/// (U+2026) became a token of its own.
bool _isWordish(int rune) {
  if (rune >= 0x30 && rune <= 0x39) return true; // 0-9
  if (rune >= 0x41 && rune <= 0x5A) return true; // A-Z
  if (rune >= 0x61 && rune <= 0x7A) return true; // a-z
  if (rune == 0x5F) return true; // underscore
  if (rune >= 0xC0 && rune <= 0x024F) return true; // Latin-1 Supp + Ext A/B
  if (rune >= 0x0370 && rune <= 0x03FF) return true; // Greek
  if (rune >= 0x0400 && rune <= 0x04FF) return true; // Cyrillic
  if (rune >= 0x0530 && rune <= 0x058F) return true; // Armenian
  if (rune >= 0x0590 && rune <= 0x05FF) return true; // Hebrew
  if (rune >= 0x0600 && rune <= 0x06FF) return true; // Arabic
  if (rune >= 0x0E00 && rune <= 0x0E7F) return true; // Thai
  if (rune >= 0x1100 && rune <= 0x11FF) return true; // Hangul Jamo
  if (rune >= 0xAC00 && rune <= 0xD7AF) return true; // Hangul Syllables
  return false;
}

/// One scored document: which entry, how well it matched, and via which key.
class RecallHit {
  const RecallHit({
    required this.documentId,
    required this.score,
    this.bestKey,
  });

  /// The entry id this document was built from.
  final String documentId;

  /// BM25 score. Higher is more relevant; comparable only within one query.
  final double score;

  /// The entry key that contributed most to the score, when any key did.
  ///
  /// Reported so a host can explain *why* an entry was injected. It is never an
  /// identity — dedupe always uses the entry's own uid, because next turn a
  /// different key may be the strongest contributor.
  final String? bestKey;
}

/// A document in the BM25 corpus: an entry's searchable text plus its keys.
class RecallDocument {
  const RecallDocument({
    required this.id,
    required this.text,
    this.keys = const <String>[],
  });

  final String id;

  /// Free text to index (typically comment + content).
  final String text;

  /// The entry's keys, indexed alongside [text] and used to fill
  /// [RecallHit.bestKey].
  final List<String> keys;
}

/// Ranks [documents] against [query] with Okapi BM25.
///
/// Plain BM25, not BM25+ or BM25F: field weighting and long-document penalties
/// are already expressed downstream by `tier` and `insertionOrder` in budget
/// admission, and modeling them twice would let the two mechanisms disagree.
///
/// The corpus is exactly the documents passed in — that is, one request's
/// entries. IDF therefore depends only on this request, so a repeated request
/// scores identically and `resolve` stays byte-for-byte deterministic. Nothing
/// is cached or persisted.
///
/// **A raw score is not a relevance verdict.** Measured on the bundled assets,
/// the score ranges of wanted and unwanted recall overlap completely:
///
/// ```
/// 「欧泊是干什么的」 → 欧泊 entry           0.727   (wanted)
/// 「晚饭吃什么」     → father entry        2.198   (junk, via 什么)
/// 「你父亲怎么了」   → father entry        3.525   (wanted)
/// ```
///
/// No absolute floor separates those, because BM25 scores are not comparable
/// across queries: the junk hit wins on a function-word bigram appearing in a
/// long body, while the wanted hit is a short exact key. Callers must therefore
/// gate on [RecallHit.bestKey] — see [WorldInfoRecallOptions.requireKeyOverlap]
/// — and treat the score only as a ranking signal among already-eligible hits.
class Bm25Ranker {
  const Bm25Ranker({this.tokenizer = const BigramRecallTokenizer()});

  /// How text is split before scoring.
  ///
  /// Defaults to [BigramRecallTokenizer], so omitting it reproduces the previous
  /// behavior exactly.
  final RecallTokenizer tokenizer;

  /// Returns hits scoring above zero, highest first.
  ///
  /// Ties break on [RecallDocument.id] so the order is total and reproducible
  /// rather than dependent on input order.
  ///
  /// When [requireKeyOverlap] is set, documents whose keys share no token with the
  /// query are never *scored*, which is what keeps this affordable: tokenizing
  /// every body on every turn cost 35ms at 1100 entries against a 300ms
  /// end-to-end budget, versus ~5ms when only eligible bodies are counted. Keys
  /// are short, so screening on them first is nearly free. Results are unchanged,
  /// because the caller would have dropped a null-`bestKey` hit anyway.
  ///
  /// Corpus statistics (`documentFrequency`, `averageLength`, `documentCount`)
  /// still span **all** documents, not the survivors. Scoping them to the
  /// survivors makes a document's score depend on how many unrelated documents
  /// were screened out — measured, one entry scored 0.42 alone but 0.288 within
  /// its full binding, straddling the default floor. Relevance must not change
  /// because another book was bound alongside.
  List<RecallHit> rank({
    required String query,
    required List<RecallDocument> documents,
    bool requireKeyOverlap = false,
  }) {
    if (documents.isEmpty) return const <RecallHit>[];
    final queryTokens = tokenizer.tokenize(query).toSet();
    if (queryTokens.isEmpty) return const <RecallHit>[];

    // Screen on keys first when the caller will demand key overlap anyway.
    final bestKeys = <String, String?>{};
    final candidates = <RecallDocument>[];
    for (final document in documents) {
      final bestKey = _bestKey(document: document, queryTokens: queryTokens);
      if (requireKeyOverlap && bestKey == null) continue;
      bestKeys[document.id] = bestKey;
      candidates.add(document);
    }
    if (candidates.isEmpty) return const <RecallHit>[];

    // Term frequencies for candidates only; corpus statistics for everything.
    final termFrequencies = <String, Map<String, int>>{};
    final lengths = <String, int>{};
    final documentFrequency = <String, int>{};
    var totalLength = 0;

    for (final document in documents) {
      final raw = '${document.keys.join(' ')} ${document.text}';
      final isCandidate = bestKeys.containsKey(document.id);

      // Corpus statistics need every document, but only coarsely, so they avoid
      // the expensive path: document frequency asks "does this query term occur
      // here at all", which a substring test answers, and length is approximated
      // by character count.
      //
      // A containment test is a slight superset of tokenization (a Latin term can
      // match inside a longer word; a CJK bigram cannot, since a separator
      // between the two characters breaks both alike). The effect is confined to
      // IDF weighting — a ranking nuance among already-eligible hits — and never
      // to eligibility, which `bestKey` decides. Paying full tokenization here to
      // sharpen a weight would cost the 30ms this exists to avoid.
      totalLength += raw.length;
      for (final term in queryTokens) {
        if (!raw.contains(term)) continue;
        documentFrequency[term] = (documentFrequency[term] ?? 0) + 1;
      }

      if (!isCandidate) continue;
      final tokens = tokenizer.tokenize(raw);
      final counts = <String, int>{};
      for (final token in tokens) {
        counts[token] = (counts[token] ?? 0) + 1;
      }
      termFrequencies[document.id] = counts;
      // Candidate length uses the same character yardstick as `averageLength`,
      // so the normalization ratio compares like with like.
      lengths[document.id] = raw.length;
    }

    final documentCount = documents.length;
    final averageLength = totalLength / documentCount;

    final hits = <RecallHit>[];
    for (final document in candidates) {
      final counts = termFrequencies[document.id]!;
      final length = lengths[document.id]!;
      var score = 0.0;
      for (final term in queryTokens) {
        final frequency = counts[term] ?? 0;
        if (frequency == 0) continue;
        final df = documentFrequency[term] ?? 0;
        // Standard BM25 IDF with the +0.5 smoothing, floored at zero: a term
        // present in every document contributes nothing rather than going
        // negative and penalizing documents for containing it. That floor is
        // what stops a broad word like 「世界」 (in most Kalabiyou entries) from
        // dominating the ranking.
        final idf = math.max(
          0.0,
          math.log((documentCount - df + 0.5) / (df + 0.5) + 1),
        );
        if (idf == 0.0) continue;
        final normalized =
            frequency *
            (_k1 + 1) /
            (frequency + _k1 * (1 - _b + _b * length / averageLength));
        score += idf * normalized;
      }
      if (score <= 0) continue;
      hits.add(
        RecallHit(
          documentId: document.id,
          score: score,
          bestKey: bestKeys[document.id],
        ),
      );
    }

    hits.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.documentId.compareTo(b.documentId);
    });
    return List<RecallHit>.unmodifiable(hits);
  }

  /// Picks the key sharing the most tokens with the query.
  ///
  /// Ties go to the key declared first, so the choice is stable for a given
  /// entry and query.
  String? _bestKey({
    required RecallDocument document,
    required Set<String> queryTokens,
  }) {
    String? best;
    var bestOverlap = 0;
    for (final key in document.keys) {
      final tokens = tokenizer.tokenize(key);
      if (tokens.isEmpty) continue;
      final overlap = tokens.where(queryTokens.contains).length;
      if (overlap > bestOverlap) {
        bestOverlap = overlap;
        best = key;
      }
    }
    return best;
  }
}
