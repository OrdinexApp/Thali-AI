import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../services/gemini_service.dart';
import '../../../../services/quantity_parser.dart';

// ─── Public entry point ─────────────────────────────────────────────────────

class ItemEditSheet extends StatefulWidget {
  final DetectedItem item;
  final void Function(DetectedItem updated) onConfirm;

  const ItemEditSheet({
    super.key,
    required this.item,
    required this.onConfirm,
  });

  static Future<void> show(
    BuildContext context, {
    required DetectedItem item,
    required void Function(DetectedItem updated) onConfirm,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ItemEditSheet(item: item, onConfirm: onConfirm),
    );
  }

  @override
  State<ItemEditSheet> createState() => _ItemEditSheetState();
}

// ─── Adaptive preset chips per unit ─────────────────────────────────────────

/// Returns named presets for a volumetric/small-unit mode. Piece mode is
/// handled separately by the stepper; multiplier mode by the multiplier chips.
List<_Preset> _presetsFor(QuantityUnit unit) {
  switch (unit) {
    case QuantityUnit.bowl:
      return const [
        _Preset(0.5, QuantityUnit.bowl, '½ bowl'),
        _Preset(1, QuantityUnit.bowl, '1 small bowl'),
        _Preset(1, QuantityUnit.bowl, '1 bowl'),
        _Preset(1, QuantityUnit.bowl, '1 big bowl'),
        _Preset(2, QuantityUnit.bowl, '2 bowls'),
      ];
    case QuantityUnit.plate:
      return const [
        _Preset(0.25, QuantityUnit.plate, '¼ plate'),
        _Preset(0.5, QuantityUnit.plate, '½ plate'),
        _Preset(1, QuantityUnit.plate, '1 plate'),
        _Preset(1.5, QuantityUnit.plate, '1½ plates'),
        _Preset(2, QuantityUnit.plate, '2 plates'),
      ];
    case QuantityUnit.serving:
      return const [
        _Preset(0.5, QuantityUnit.serving, '½ serving'),
        _Preset(1, QuantityUnit.serving, '1 small serving'),
        _Preset(1, QuantityUnit.serving, '1 serving'),
        _Preset(1, QuantityUnit.serving, '1 big serving'),
        _Preset(2, QuantityUnit.serving, '2 servings'),
      ];
    case QuantityUnit.cup:
      return const [
        _Preset(0.5, QuantityUnit.cup, '½ cup'),
        _Preset(1, QuantityUnit.cup, '1 small cup'),
        _Preset(1, QuantityUnit.cup, '1 cup'),
        _Preset(1, QuantityUnit.cup, '1 glass'),
        _Preset(2, QuantityUnit.cup, '2 cups'),
      ];
    case QuantityUnit.tbsp:
      return const [
        _Preset(0.5, QuantityUnit.tbsp, '½ tbsp'),
        _Preset(1, QuantityUnit.tbsp, '1 tbsp'),
        _Preset(2, QuantityUnit.tbsp, '2 tbsp'),
        _Preset(3, QuantityUnit.tbsp, '3 tbsp'),
      ];
    case QuantityUnit.tsp:
      return const [
        _Preset(0.5, QuantityUnit.tsp, '½ tsp'),
        _Preset(1, QuantityUnit.tsp, '1 tsp'),
        _Preset(2, QuantityUnit.tsp, '2 tsp'),
        _Preset(1, QuantityUnit.tbsp, '1 tbsp'),
      ];
    case QuantityUnit.ml:
      return const [
        _Preset(100, QuantityUnit.ml, '100ml'),
        _Preset(150, QuantityUnit.ml, '150ml'),
        _Preset(200, QuantityUnit.ml, '200ml'),
        _Preset(300, QuantityUnit.ml, '300ml'),
        _Preset(500, QuantityUnit.ml, '500ml'),
      ];
    case QuantityUnit.gram:
      return const [
        _Preset(50, QuantityUnit.gram, '50g'),
        _Preset(100, QuantityUnit.gram, '100g'),
        _Preset(150, QuantityUnit.gram, '150g'),
        _Preset(200, QuantityUnit.gram, '200g'),
      ];
    case QuantityUnit.piece:
    case QuantityUnit.multiplier:
      return const []; // Handled by stepper / multiplier chips.
  }
}

/// Universal portion-multiplier chips shown at the bottom of every sheet.
/// Same semantics as Cal AI / Foodvisor: "more or less than what AI saw".
const _multipliers = <double>[0.5, 1.0, 1.5, 2.0, 3.0];

class _Preset {
  final double count;
  final QuantityUnit unit;
  final String label;
  const _Preset(this.count, this.unit, this.label);
}

// ─── State ──────────────────────────────────────────────────────────────────

class _ItemEditSheetState extends State<ItemEditSheet> {
  late TextEditingController _nameController;
  late TextEditingController _customQtyController;
  late String _cookingStyle;
  bool _editingName = false;

  /// Current quantity — lives as ([count], [unit]). Rendered on save.
  late double _count;
  late QuantityUnit _unit;

  /// Remember Gemini's original count so we can show the
  /// "AI saw 3 — tap − if less" hint on countable items.
  late double _aiCount;

  /// Selected multiplier (1× means no override). Applied independently of
  /// the primary count/unit — this is the universal escape hatch.
  double _multiplier = 1.0;

  static const _cookingStyles = [
    _StyleOption('Home', Icons.home_rounded, 'Normal homemade'),
    _StyleOption('Restaurant', Icons.restaurant_rounded, 'Rich, more butter/oil'),
    _StyleOption('Less Oil', Icons.water_drop_outlined, 'Light preparation'),
    _StyleOption('Diet', Icons.eco_rounded, 'Minimal oil, steamed'),
  ];

  @override
  void initState() {
    super.initState();
    _count = widget.item.count;
    _unit = widget.item.unit;
    _aiCount = widget.item.count;
    _cookingStyle = widget.item.cookingStyle;
    _nameController = TextEditingController(text: widget.item.name);
    _customQtyController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _customQtyController.dispose();
    super.dispose();
  }

  bool get _showCookingStyle => widget.item.needsCookingStyle;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomPad),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: AppColors.glassBorder, width: 0.8)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textTertiary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                _buildNameHeader(),
                const SizedBox(height: 24),

                // Adaptive primary control
                _buildLabel('QUANTITY'),
                const SizedBox(height: 12),
                _buildPrimaryQuantityControl(),
                const SizedBox(height: 14),
                _buildCustomQuantityField(),
                const SizedBox(height: 20),

                // Universal portion multiplier (always visible)
                _buildLabel('PORTION'),
                const SizedBox(height: 10),
                _buildMultiplierRow(),
                const SizedBox(height: 24),

                if (_showCookingStyle) ...[
                  _buildLabel('COOKING STYLE'),
                  const SizedBox(height: 10),
                  _buildCookingStyleRow(),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      _cookingStyles.firstWhere((s) => s.label == _cookingStyle).description,
                      style: TextStyle(fontSize: 11, color: AppColors.textTertiary.withValues(alpha: 0.9)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                _buildConfirmButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Adaptive primary control ──────────────────────────────────────────────

  Widget _buildPrimaryQuantityControl() {
    if (_unit == QuantityUnit.piece) return _buildPieceStepper();
    if (_unit == QuantityUnit.multiplier) return _buildMultiplierOnlyMode();
    return _buildPresetChips();
  }

  /// Big inline stepper for discretely countable items (idli, vada, roti, …).
  Widget _buildPieceStepper() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _stepperButton(
              icon: Icons.remove_rounded,
              enabled: _count > 1,
              onTap: () => _bumpCount(-1),
            ),
            const SizedBox(width: 24),
            SizedBox(
              width: 90,
              child: Column(
                children: [
                  Text(
                    _count == _count.roundToDouble()
                        ? _count.toInt().toString()
                        : _count.toStringAsFixed(1),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      color: AppColors.emerald,
                      height: 1,
                      letterSpacing: -2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _count == 1 ? 'piece' : 'pieces',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            _stepperButton(
              icon: Icons.add_rounded,
              enabled: _count < 20,
              onTap: () => _bumpCount(1),
            ),
          ],
        ),
        if (_aiCount > 1) ...[
          const SizedBox(height: 8),
          Text(
            'AI saw ${_aiCount.toInt()} — tap − or + if wrong',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary.withValues(alpha: 0.85),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  Widget _stepperButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.emerald.withValues(alpha: 0.15)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: enabled
                ? AppColors.emerald.withValues(alpha: 0.35)
                : Colors.transparent,
          ),
        ),
        child: Icon(
          icon,
          size: 26,
          color: enabled ? AppColors.emerald : AppColors.textTertiary,
        ),
      ),
    );
  }

  void _bumpCount(int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      _count = (_count + delta).clamp(1, 20).toDouble();
      _customQtyController.clear();
    });
  }

  /// Chips for named presets (bowls, plates, tbsp, ml, …).
  Widget _buildPresetChips() {
    final presets = _presetsFor(_unit);
    if (presets.isEmpty) return _buildMultiplierOnlyMode();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: presets.map((p) {
        final selected = _unit == p.unit &&
            (_count - p.count).abs() < 0.001 &&
            _customQtyController.text.trim().isEmpty;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _count = p.count;
              _unit = p.unit;
              _customQtyController.clear();
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.emerald.withValues(alpha: 0.15)
                  : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? AppColors.emerald : AppColors.glassBorder,
                width: selected ? 1.5 : 0.8,
              ),
            ),
            child: Text(
              p.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.emerald : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Shown when we couldn't infer any meaningful unit from Gemini.
  /// Falls back to a universal "how much" question that works for any food.
  Widget _buildMultiplierOnlyMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'We couldn\'t figure out a natural unit for this item.\n'
          'Use the portion below to tell us how much you had '
          'relative to what the AI estimated.',
          style: TextStyle(
            fontSize: 12,
            height: 1.5,
            color: AppColors.textTertiary.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }

  // ── Universal portion multiplier ──────────────────────────────────────────

  Widget _buildMultiplierRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: _multipliers.map((m) {
        final selected = (_multiplier - m).abs() < 0.01;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _multiplier = m);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.cyan.withValues(alpha: 0.15)
                  : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.cyan : AppColors.glassBorder,
                width: selected ? 1.5 : 0.8,
              ),
            ),
            child: Text(
              _formatMultiplier(m),
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? AppColors.cyan : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatMultiplier(double m) {
    if (m == m.roundToDouble()) return '${m.toInt()}×';
    return '${m.toStringAsFixed(1)}×';
  }

  // ── Name header ───────────────────────────────────────────────────────────

  Widget _buildNameHeader() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: AppColors.emeraldGradient),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.restaurant_rounded, color: Colors.black, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _editingName
              ? _buildNameField()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nameController.text,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _editingName = true);
                        Future.delayed(const Duration(milliseconds: 50), () {
                          _nameController.selection = TextSelection(
                            baseOffset: 0,
                            extentOffset: _nameController.text.length,
                          );
                        });
                      },
                      child: const Text(
                        'Tap to edit name',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.cyan,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return TextField(
      controller: _nameController,
      autofocus: true,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: 'Item name',
        hintStyle: const TextStyle(color: AppColors.textTertiary),
        filled: true,
        fillColor: AppColors.surfaceLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.emerald, width: 1.5),
        ),
        suffixIcon: IconButton(
          icon: const Icon(Icons.check_rounded, color: AppColors.emerald, size: 20),
          onPressed: () {
            HapticFeedback.selectionClick();
            setState(() => _editingName = false);
          },
        ),
      ),
      onSubmitted: (_) => setState(() => _editingName = false),
      textCapitalization: TextCapitalization.words,
    );
  }

  // ── Custom free-form input ────────────────────────────────────────────────

  Widget _buildCustomQuantityField() {
    return TextField(
      controller: _customQtyController,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      keyboardType: TextInputType.text,
      textCapitalization: TextCapitalization.none,
      decoration: InputDecoration(
        hintText: 'Or type a custom amount (e.g. "5 pieces", "2 cups")',
        hintStyle: TextStyle(
          color: AppColors.textTertiary.withValues(alpha: 0.7),
          fontSize: 12,
        ),
        filled: true,
        fillColor: AppColors.surfaceLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.emerald, width: 1.2),
        ),
      ),
    );
  }

  // ── Cooking style ─────────────────────────────────────────────────────────

  Widget _buildCookingStyleRow() {
    return Row(
      children: _cookingStyles.map((style) {
        final selected = _cookingStyle == style.label;
        final isLast = style.label == _cookingStyles.last.label;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _cookingStyle = style.label);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(right: isLast ? 0 : 8),
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.emerald.withValues(alpha: 0.12)
                    : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: selected ? AppColors.emerald : AppColors.glassBorder,
                  width: selected ? 1.5 : 0.8,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(style.icon,
                      size: 20,
                      color: selected ? AppColors.emerald : AppColors.textTertiary),
                  const SizedBox(height: 5),
                  Text(
                    style.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? AppColors.emerald : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Confirm ───────────────────────────────────────────────────────────────

  Widget _buildConfirmButton() {
    return GestureDetector(
      onTap: _onConfirm,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: AppColors.emeraldGradient),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.emerald.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_rounded, color: Colors.black, size: 20),
            SizedBox(width: 8),
            Text(
              'Confirm Item',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textTertiary,
        letterSpacing: 1.5,
      ),
    );
  }

  void _onConfirm() {
    HapticFeedback.heavyImpact();
    final finalName = _nameController.text.trim().isEmpty
        ? widget.item.name
        : _nameController.text.trim();

    // Precedence: custom typed text > selected primary control > original.
    final custom = _customQtyController.text.trim();
    double effectiveCount = _count;
    QuantityUnit effectiveUnit = _unit;
    String effectiveQty;

    if (custom.isNotEmpty) {
      final parsed = QuantityParser.parse(custom);
      effectiveCount = parsed.count;
      effectiveUnit = parsed.unit;
      effectiveQty = custom;
    } else {
      effectiveQty = QuantityParser.format(_count, _unit);
    }

    // Apply the universal multiplier on top. Bake it into the count so
    // downstream calorie math doesn't need a separate field.
    if ((_multiplier - 1.0).abs() > 0.01) {
      effectiveCount = effectiveCount * _multiplier;
      effectiveQty =
          '${effectiveQty.isEmpty ? "" : "$effectiveQty "}(${_formatMultiplier(_multiplier)})';
    }

    widget.onConfirm(
      widget.item.copyWith(
        name: finalName,
        estimatedQuantity: effectiveQty,
        count: effectiveCount,
        unit: effectiveUnit,
        cookingStyle: _cookingStyle,
        confirmed: true,
      ),
    );
    Navigator.pop(context);
  }
}

class _StyleOption {
  final String label;
  final IconData icon;
  final String description;

  const _StyleOption(this.label, this.icon, this.description);
}
