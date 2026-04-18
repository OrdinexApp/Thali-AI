/// Canonical unit of measure for a detected food item.
///
/// The [unit] comes from Gemini's structured detection output. If Gemini doesn't
/// emit a clean unit, [QuantityParser] derives one from the quantity string.
/// When no unit can be inferred we fall back to [QuantityUnit.multiplier] —
/// a universal "portion multiplier" mode used as a safety net.
enum QuantityUnit {
  piece,       // idli, roti, vada, samosa, dosa — discrete items
  bowl,        // dal, sabzi, curry — volumetric
  plate,       // thali, larger volumetric servings
  serving,     // generic volumetric
  cup,         // tea, measured rice
  tbsp,        // generous condiments
  tsp,         // small condiments, pickles
  ml,          // beverages
  gram,        // weighed foods
  multiplier,  // unknown unit — use 0.5× / 1× / 2× portion multiplier
}

/// Parsed quantity: the raw numeric count plus its inferred unit.
class ParsedQuantity {
  final double count;
  final QuantityUnit unit;
  const ParsedQuantity(this.count, this.unit);
}

/// Parses Gemini's free-form quantity strings like "3 pieces", "1 bowl", "200 ml"
/// into a structured ([count], [unit]) pair.
///
/// Order of checks matters: we look for the most specific markers first (pieces,
/// tbsp, tsp) before falling to broader ones (bowl, plate). If no unit
/// marker matches we return [QuantityUnit.multiplier] so the UI shows the
/// universal portion multiplier chips.
class QuantityParser {
  /// Extract the leading number from a string (supports `½`, `¼`, `3.5`, `2`).
  /// Defaults to `1.0` when no number is found.
  static double _extractCount(String qty) {
    if (qty.contains('½')) return 0.5;
    if (qty.contains('¼')) return 0.25;
    if (qty.contains('¾')) return 0.75;
    final match = RegExp(r'(\d+\.?\d*)').firstMatch(qty);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 1.0;
    }
    return 1.0;
  }

  /// Map a raw Gemini unit string (case-insensitive) to a [QuantityUnit].
  /// Returns `null` if the string doesn't match any known unit.
  static QuantityUnit? unitFromString(String? raw) {
    if (raw == null) return null;
    final s = raw.toLowerCase().trim();
    if (s.isEmpty) return null;
    switch (s) {
      case 'piece':
      case 'pieces':
      case 'pc':
      case 'pcs':
        return QuantityUnit.piece;
      case 'bowl':
      case 'bowls':
      case 'katori':
        return QuantityUnit.bowl;
      case 'plate':
      case 'plates':
      case 'thali':
        return QuantityUnit.plate;
      case 'serving':
      case 'servings':
      case 'portion':
      case 'portions':
        return QuantityUnit.serving;
      case 'cup':
      case 'cups':
      case 'glass':
      case 'glasses':
        return QuantityUnit.cup;
      case 'tbsp':
      case 'tablespoon':
      case 'tablespoons':
        return QuantityUnit.tbsp;
      case 'tsp':
      case 'teaspoon':
      case 'teaspoons':
        return QuantityUnit.tsp;
      case 'ml':
      case 'millilitre':
      case 'millilitres':
      case 'milliliter':
      case 'milliliters':
        return QuantityUnit.ml;
      case 'g':
      case 'gram':
      case 'grams':
        return QuantityUnit.gram;
      case 'multiplier':
      case 'unknown':
        return QuantityUnit.multiplier;
      default:
        return null;
    }
  }

  /// Parse a quantity string into a structured [ParsedQuantity].
  ///
  /// Falls back to [QuantityUnit.multiplier] when no known unit marker is present
  /// so the adaptive edit-sheet can still offer a meaningful control.
  static ParsedQuantity parse(String quantity) {
    final q = quantity.toLowerCase().trim();
    final count = _extractCount(q);

    if (q.isEmpty) return ParsedQuantity(count, QuantityUnit.multiplier);

    // Order matters — check most specific first.
    if (RegExp(r'\b(piece|pieces|pcs?)\b').hasMatch(q)) {
      return ParsedQuantity(count, QuantityUnit.piece);
    }
    if (RegExp(r'\b(tablespoons?|tbsps?)\b').hasMatch(q)) {
      return ParsedQuantity(count, QuantityUnit.tbsp);
    }
    if (RegExp(r'\b(teaspoons?|tsps?)\b').hasMatch(q)) {
      return ParsedQuantity(count, QuantityUnit.tsp);
    }
    // `\b` only fires between word and non-word chars, so "200ml" (digit→letter)
    // does not produce a boundary. Match ml attached to a digit explicitly.
    if (RegExp(r'(^|\W)mls?\b|\d\s*mls?\b|\bmillilit(re|er)s?\b').hasMatch(q)) {
      return ParsedQuantity(count, QuantityUnit.ml);
    }
    if (RegExp(r'\d\s*g\b|\bgrams?\b').hasMatch(q)) {
      return ParsedQuantity(count, QuantityUnit.gram);
    }
    if (RegExp(r'\b(katori|bowls?)\b').hasMatch(q)) {
      return ParsedQuantity(count, QuantityUnit.bowl);
    }
    if (RegExp(r'\b(thali|plates?)\b').hasMatch(q)) {
      return ParsedQuantity(count, QuantityUnit.plate);
    }
    if (RegExp(r'\b(cups?|glass(es)?)\b').hasMatch(q)) {
      return ParsedQuantity(count, QuantityUnit.cup);
    }
    if (RegExp(r'\b(servings?|portions?|handfuls?)\b').hasMatch(q)) {
      return ParsedQuantity(count, QuantityUnit.serving);
    }

    return ParsedQuantity(count, QuantityUnit.multiplier);
  }

  /// Render a ([count], [unit]) pair back into a human-readable string.
  /// Used when the user edits the stepper/chips and we need to re-serialize.
  static String format(double count, QuantityUnit unit) {
    final countStr = count == count.roundToDouble()
        ? count.toInt().toString()
        : count.toStringAsFixed(1);

    switch (unit) {
      case QuantityUnit.piece:
        return count == 1 ? '$countStr piece' : '$countStr pieces';
      case QuantityUnit.bowl:
        return count == 1 ? '$countStr bowl' : '$countStr bowls';
      case QuantityUnit.plate:
        return count == 1 ? '$countStr plate' : '$countStr plates';
      case QuantityUnit.serving:
        return count == 1 ? '$countStr serving' : '$countStr servings';
      case QuantityUnit.cup:
        return count == 1 ? '$countStr cup' : '$countStr cups';
      case QuantityUnit.tbsp:
        return '$countStr tbsp';
      case QuantityUnit.tsp:
        return '$countStr tsp';
      case QuantityUnit.ml:
        return '${countStr}ml';
      case QuantityUnit.gram:
        return '${countStr}g';
      case QuantityUnit.multiplier:
        return '${countStr}× portion';
    }
  }
}
