/// Standard Indian food nutrition values per typical serving.
/// Used as fallback when Gemini is unavailable and for validation.
/// Sources: IFCT 2017, NIN Hyderabad, USDA adapted for Indian preparations.
class IndianFoodDB {
  IndianFoodDB._();

  static const Map<String, FoodNutrition> database = {
    // Breads
    'roti': FoodNutrition('Roti / Chapati', 120, 3.5, 20.0, 3.5, 1.2, '1 piece (40g)'),
    'naan': FoodNutrition('Naan', 260, 7.0, 42.0, 7.5, 1.5, '1 piece (90g)'),
    'paratha': FoodNutrition('Plain Paratha', 220, 5.0, 30.0, 10.0, 1.8, '1 piece (60g)'),
    'aloo paratha': FoodNutrition('Aloo Paratha', 280, 6.0, 38.0, 12.0, 2.5, '1 piece (80g)'),
    'puri': FoodNutrition('Puri', 150, 3.0, 18.0, 8.0, 0.8, '1 piece (30g)'),
    'bhatura': FoodNutrition('Bhatura', 310, 6.5, 40.0, 14.0, 1.0, '1 piece (80g)'),
    'kulcha': FoodNutrition('Kulcha', 240, 6.0, 38.0, 7.0, 1.5, '1 piece (80g)'),
    'dosa': FoodNutrition('Plain Dosa', 170, 4.0, 28.0, 5.0, 1.0, '1 piece'),
    'masala dosa': FoodNutrition('Masala Dosa', 280, 5.5, 38.0, 12.0, 2.5, '1 piece'),
    'idli': FoodNutrition('Idli', 60, 2.0, 12.0, 0.5, 0.5, '1 piece (40g)'),
    'uttapam': FoodNutrition('Uttapam', 200, 5.0, 30.0, 6.0, 2.0, '1 piece'),
    'appam': FoodNutrition('Appam', 120, 2.5, 22.0, 2.5, 0.5, '1 piece'),

    // Rice
    'steamed rice': FoodNutrition('Steamed Rice', 200, 4.0, 44.0, 0.5, 0.6, '1 cup (150g)'),
    'rice': FoodNutrition('Rice', 200, 4.0, 44.0, 0.5, 0.6, '1 cup (150g)'),
    'jeera rice': FoodNutrition('Jeera Rice', 230, 4.5, 42.0, 5.0, 1.0, '1 cup (150g)'),
    'biryani': FoodNutrition('Veg Biryani', 320, 7.0, 48.0, 12.0, 2.5, '1 plate (200g)'),
    'chicken biryani': FoodNutrition('Chicken Biryani', 400, 18.0, 45.0, 16.0, 1.5, '1 plate (250g)'),
    'pulao': FoodNutrition('Veg Pulao', 250, 5.0, 40.0, 8.0, 2.0, '1 cup (180g)'),
    'lemon rice': FoodNutrition('Lemon Rice', 220, 4.0, 40.0, 5.0, 1.0, '1 cup (150g)'),
    'curd rice': FoodNutrition('Curd Rice', 230, 6.0, 38.0, 6.0, 0.5, '1 cup (180g)'),

    // Dals & Lentils
    'dal tadka': FoodNutrition('Dal Tadka', 180, 9.0, 24.0, 6.0, 4.5, '1 bowl (150ml)'),
    'dal': FoodNutrition('Dal', 160, 8.5, 22.0, 5.0, 4.0, '1 bowl (150ml)'),
    'dal makhani': FoodNutrition('Dal Makhani', 260, 10.0, 28.0, 12.0, 5.0, '1 bowl (150ml)'),
    'dal fry': FoodNutrition('Dal Fry', 190, 9.5, 24.0, 7.0, 4.5, '1 bowl (150ml)'),
    'chana dal': FoodNutrition('Chana Dal', 200, 10.0, 26.0, 6.0, 5.0, '1 bowl (150ml)'),
    'sambar': FoodNutrition('Sambar', 140, 6.0, 18.0, 5.0, 4.0, '1 bowl (150ml)'),
    'rasam': FoodNutrition('Rasam', 60, 2.0, 8.0, 2.5, 1.5, '1 bowl (150ml)'),
    'rajma': FoodNutrition('Rajma', 210, 10.0, 30.0, 6.0, 6.0, '1 bowl (150ml)'),
    'chole': FoodNutrition('Chole', 240, 10.0, 32.0, 8.0, 7.0, '1 bowl (150ml)'),
    'kadhi': FoodNutrition('Kadhi', 150, 5.0, 14.0, 8.0, 1.0, '1 bowl (150ml)'),

    // Vegetable curries
    'aloo gobi': FoodNutrition('Aloo Gobi', 160, 4.0, 22.0, 7.0, 3.5, '1 serving (120g)'),
    'palak paneer': FoodNutrition('Palak Paneer', 280, 14.0, 10.0, 20.0, 3.0, '1 bowl (150g)'),
    'paneer butter masala': FoodNutrition('Paneer Butter Masala', 350, 15.0, 14.0, 26.0, 2.0, '1 bowl (150g)'),
    'shahi paneer': FoodNutrition('Shahi Paneer', 340, 14.0, 12.0, 26.0, 1.5, '1 bowl (150g)'),
    'matar paneer': FoodNutrition('Matar Paneer', 300, 14.0, 16.0, 20.0, 3.0, '1 bowl (150g)'),
    'aloo matar': FoodNutrition('Aloo Matar', 180, 5.0, 24.0, 7.0, 3.5, '1 serving (120g)'),
    'bhindi masala': FoodNutrition('Bhindi Masala', 130, 3.5, 12.0, 8.0, 4.0, '1 serving (100g)'),
    'baingan bharta': FoodNutrition('Baingan Bharta', 150, 4.0, 12.0, 10.0, 5.0, '1 serving (120g)'),
    'mixed veg': FoodNutrition('Mixed Veg Curry', 140, 4.0, 16.0, 7.0, 4.0, '1 serving (120g)'),
    'malai kofta': FoodNutrition('Malai Kofta', 380, 10.0, 22.0, 28.0, 2.0, '1 serving (150g)'),
    'dum aloo': FoodNutrition('Dum Aloo', 240, 5.0, 28.0, 12.0, 3.0, '1 serving (150g)'),
    'mushroom masala': FoodNutrition('Mushroom Masala', 160, 5.0, 12.0, 10.0, 2.5, '1 serving (120g)'),

    // Non-veg curries
    'butter chicken': FoodNutrition('Butter Chicken', 380, 22.0, 12.0, 28.0, 1.5, '1 bowl (180g)'),
    'chicken curry': FoodNutrition('Chicken Curry', 280, 24.0, 10.0, 16.0, 2.0, '1 bowl (180g)'),
    'tandoori chicken': FoodNutrition('Tandoori Chicken', 220, 28.0, 4.0, 10.0, 0.5, '2 pieces (150g)'),
    'fish curry': FoodNutrition('Fish Curry', 220, 20.0, 8.0, 12.0, 1.0, '1 bowl (150g)'),
    'egg curry': FoodNutrition('Egg Curry', 240, 14.0, 10.0, 16.0, 1.5, '1 bowl (2 eggs)'),
    'keema': FoodNutrition('Keema', 300, 20.0, 8.0, 22.0, 1.5, '1 bowl (150g)'),
    'mutton curry': FoodNutrition('Mutton Curry', 320, 22.0, 8.0, 22.0, 1.0, '1 bowl (180g)'),

    // Accompaniments
    'raita': FoodNutrition('Raita', 65, 3.0, 5.0, 3.5, 0.2, '1 small bowl (80ml)'),
    'pickle': FoodNutrition('Pickle / Achar', 30, 0.5, 2.0, 2.5, 0.5, '1 tbsp'),
    'chutney': FoodNutrition('Chutney', 40, 1.0, 6.0, 1.5, 0.5, '2 tbsp'),
    'papad': FoodNutrition('Papad (roasted)', 50, 3.0, 8.0, 0.5, 1.0, '1 piece'),
    'papad fried': FoodNutrition('Papad (fried)', 90, 3.0, 8.0, 5.5, 1.0, '1 piece'),
    'salad': FoodNutrition('Green Salad', 25, 1.0, 4.0, 0.3, 1.5, '1 small bowl'),
    'onion salad': FoodNutrition('Onion Salad', 20, 0.5, 4.0, 0.1, 1.0, '1 serving'),
    'curd': FoodNutrition('Curd / Dahi', 80, 4.0, 6.0, 4.5, 0, '1 bowl (100g)'),

    // Snacks & Starters
    'samosa': FoodNutrition('Samosa', 260, 4.0, 28.0, 15.0, 2.0, '1 piece (80g)'),
    'pakora': FoodNutrition('Pakora', 180, 4.0, 16.0, 12.0, 1.5, '4-5 pieces'),
    'vada': FoodNutrition('Medu Vada', 170, 5.0, 18.0, 9.0, 2.0, '1 piece'),
    'pav bhaji': FoodNutrition('Pav Bhaji', 380, 10.0, 48.0, 16.0, 5.0, '1 plate'),

    // Sweets
    'gulab jamun': FoodNutrition('Gulab Jamun', 175, 3.0, 28.0, 6.0, 0.3, '2 pieces'),
    'kheer': FoodNutrition('Kheer', 200, 5.0, 30.0, 7.0, 0.5, '1 bowl (120ml)'),
    'jalebi': FoodNutrition('Jalebi', 150, 2.0, 22.0, 7.0, 0.2, '2 pieces'),
    'halwa': FoodNutrition('Halwa', 250, 3.0, 34.0, 12.0, 1.0, '1 serving (80g)'),
    'ladoo': FoodNutrition('Ladoo', 180, 3.0, 24.0, 9.0, 1.0, '1 piece (40g)'),
  };

  /// Look up food by name (case-insensitive, partial match)
  static FoodNutrition? lookup(String name) {
    final lower = name.toLowerCase().trim();

    // Exact match
    if (database.containsKey(lower)) return database[lower];

    // Partial match
    for (final entry in database.entries) {
      if (lower.contains(entry.key) || entry.key.contains(lower)) {
        return entry.value;
      }
    }

    // Match by display name
    for (final entry in database.values) {
      if (entry.name.toLowerCase().contains(lower) ||
          lower.contains(entry.name.toLowerCase())) {
        return entry;
      }
    }

    return null;
  }

  /// Apply cooking style multiplier to base nutrition
  static FoodNutrition applyStyle(FoodNutrition base, String cookingStyle) {
    switch (cookingStyle) {
      case 'Restaurant':
        return FoodNutrition(
          base.name,
          base.calories * 1.3,
          base.protein,
          base.carbs * 1.05,
          base.fat * 1.5,
          base.fiber,
          base.portion,
        );
      case 'Less Oil':
        return FoodNutrition(
          base.name,
          base.calories * 0.8,
          base.protein,
          base.carbs,
          base.fat * 0.6,
          base.fiber,
          base.portion,
        );
      case 'Diet':
        return FoodNutrition(
          base.name,
          base.calories * 0.65,
          base.protein * 1.05,
          base.carbs * 0.85,
          base.fat * 0.4,
          base.fiber * 1.1,
          base.portion,
        );
      default: // 'Home'
        return base;
    }
  }
}

class FoodNutrition {
  final String name;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final String portion;

  const FoodNutrition(
    this.name,
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.fiber,
    this.portion,
  );
}
