import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/animated_gradient_background.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/neon_button.dart';
import '../../../../features/history/data/models/meal_model.dart';
import '../../../../services/providers.dart';
import '../widgets/macro_chart.dart';
import '../widgets/food_item_tile.dart';
import '../widgets/health_score_card.dart';

class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final analysisState = ref.watch(analysisProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedGradientBackground(
        child: SafeArea(
          bottom: false,
          child: _buildContent(analysisState),
        ),
      ),
    );
  }

  Widget _buildContent(AnalysisState state) {
    switch (state.status) {
      case AnalysisStatus.loading:
      case AnalysisStatus.idle:
        return _buildLoadingState();
      case AnalysisStatus.success:
        return _buildSuccessState(state.result!);
      case AnalysisStatus.error:
        return _buildErrorState(
          state.error ?? "Couldn't analyze your meal right now. Please try again.",
        );
    }
  }

  // ── Loading ───────────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildPulsingOrb()
                .animate(onPlay: (c) => c.repeat())
                .shimmer(duration: 1800.ms, color: AppColors.emerald.withValues(alpha: 0.25)),
            const SizedBox(height: 44),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: AppColors.emeraldGradient,
              ).createShader(bounds),
              child: const Text(
                'Analyzing your\nthali',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -1,
                  height: 1.2,
                ),
              ),
            ).animate().fadeIn(duration: 700.ms, delay: 100.ms),
            const SizedBox(height: 16),
            Text(
              'Detecting food items and calculating\nnutrition from Indian food databases.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: AppColors.textTertiary.withValues(alpha: 0.9),
              ),
            ).animate().fadeIn(duration: 700.ms, delay: 200.ms),
            const SizedBox(height: 40),
            _buildLoadingSteps().animate().fadeIn(duration: 700.ms, delay: 350.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildPulsingOrb() {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.emerald.withValues(alpha: 0.05),
            ),
          ),
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.emerald.withValues(alpha: 0.07),
              border: Border.all(color: AppColors.emerald.withValues(alpha: 0.18), width: 1),
            ),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.emerald.withValues(alpha: 0.18),
                  AppColors.cyan.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: AppColors.emerald.withValues(alpha: 0.3), width: 1),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: AppColors.emerald, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSteps() {
    final steps = ['Detecting food items', 'Estimating portions', 'Calculating nutrition'];
    return Column(
      children: steps.asMap().entries.map((e) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: AppColors.emerald.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                e.value,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textTertiary.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Success ───────────────────────────────────────────────────────────────

  Widget _buildSuccessState(MealAnalysis meal) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Hero calorie section
        SliverToBoxAdapter(
          child: _buildHero(meal)
              .animate()
              .fadeIn(duration: 600.ms)
              .slideY(begin: 0.04, end: 0, curve: Curves.easeOut),
        ),
        // Cards section
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              HealthScoreCard(score: meal.healthScore, tip: meal.healthTip)
                  .animate()
                  .fadeIn(duration: 600.ms, delay: 100.ms)
                  .slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
              const SizedBox(height: 16),
              MacroChart(meal: meal)
                  .animate()
                  .fadeIn(duration: 600.ms, delay: 150.ms)
                  .slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
              const SizedBox(height: 28),
              _buildFoodItemsHeader(meal.items.length)
                  .animate()
                  .fadeIn(duration: 600.ms, delay: 200.ms),
              const SizedBox(height: 14),
            ]),
          ),
        ),
        // Food items
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => FoodItemTile(item: meal.items[index])
                  .animate()
                  .fadeIn(duration: 400.ms, delay: Duration(milliseconds: 250 + index * 60))
                  .slideY(begin: 0.05, end: 0, curve: Curves.easeOut),
              childCount: meal.items.length,
            ),
          ),
        ),
        // Footer
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildMealMeta(meal)
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 400.ms),
              const SizedBox(height: 20),
              NeonButton(
                text: _saving ? 'Saving...' : 'Save Meal',
                icon: Icons.bookmark_add_rounded,
                isLoading: _saving,
                onPressed: _onSaveMeal,
              ).animate().fadeIn(duration: 600.ms, delay: 450.ms).slideY(begin: 0.08, end: 0),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: _onScanAnother,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: const Text(
                    'Scan another thali',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ).animate().fadeIn(duration: 600.ms, delay: 500.ms),
            ]),
          ),
        ),
      ],
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────────────

  Widget _buildHero(MealAnalysis meal) {
    return Stack(
      children: [
        // Photo background (local file path during analysis, signed URL after refresh)
        if (meal.imagePath != null)
          SizedBox(
            height: 300,
            width: double.infinity,
            child: _heroImage(meal.imagePath!),
          )
        else
          Container(
            height: 300,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0E2218), Color(0xFF071520)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        // Gradient overlay — top for app bar
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.35, 0.65, 1.0],
                colors: [
                  Colors.black.withValues(alpha: 0.65),
                  Colors.black.withValues(alpha: 0.2),
                  Colors.black.withValues(alpha: 0.5),
                  AppColors.background,
                ],
              ),
            ),
          ),
        ),
        // App bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 17),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: const Text(
                        'Nutrition Analysis',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => HapticFeedback.lightImpact(),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: Icon(Icons.share_rounded,
                            color: Colors.white.withValues(alpha: 0.9), size: 18),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Bottom calorie overlay
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: _buildCalorieBadge(meal),
          ),
        ),
      ],
    );
  }

  Widget _buildCalorieBadge(MealAnalysis meal) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.black.withValues(alpha: 0.55),
                Colors.black.withValues(alpha: 0.4),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 0.8),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: AppColors.emeraldGradient,
                    ).createShader(bounds),
                    child: Text(
                      '${meal.totalCalories.toInt()}',
                      style: const TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -3,
                        height: 1,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8, left: 6),
                    child: Text(
                      'kcal',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: AppColors.emerald,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildMacroPill('Protein', '${meal.totalProtein.toInt()}g', AppColors.cyan),
                  _buildMacroPill('Carbs', '${meal.totalCarbs.toInt()}g', AppColors.warning),
                  _buildMacroPill('Fat', '${meal.totalFat.toInt()}g', AppColors.error),
                  _buildMacroPill('Fiber', '${meal.totalFiber.toInt()}g', AppColors.neonGreen),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMacroPill(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color.withValues(alpha: 0.95),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.55),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }

  // ── Food items header ─────────────────────────────────────────────────────

  Widget _buildFoodItemsHeader(int count) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(
          child: Text(
            'Food items',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.emerald.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.emerald.withValues(alpha: 0.25)),
          ),
          child: Text(
            '$count items',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.emerald,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ],
    );
  }

  // ── Meal meta ─────────────────────────────────────────────────────────────

  Widget _buildMealMeta(MealAnalysis meal) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final date = '${meal.timestamp.day} ${months[meal.timestamp.month - 1]}';
    final hour = meal.timestamp.hour;
    final mealLabel = hour < 11 ? 'Breakfast' : hour < 15 ? 'Lunch' : hour < 18 ? 'Snack' : 'Dinner';

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      borderRadius: 18,
      showTopHighlight: true,
      child: Row(
        children: [
          _buildMetaChip(Icons.restaurant_rounded, mealLabel, AppColors.cyan),
          _buildMetaDivider(),
          _buildMetaChip(Icons.calendar_today_rounded, date, AppColors.textSecondary),
        ],
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String text, Color color) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color.withValues(alpha: 0.85)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaDivider() {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: AppColors.glassBorder,
    );
  }

  // ── Error ─────────────────────────────────────────────────────────────────

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.error.withValues(alpha: 0.08),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.error_outline_rounded,
                  color: AppColors.error, size: 38),
            ),
            const SizedBox(height: 28),
            const Text(
              "Couldn't analyze your meal",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textTertiary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'We never show estimated calories you might mistake for real.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
                height: 1.5,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 36),
            NeonButton(
              text: 'Try Again',
              icon: Icons.refresh_rounded,
              onPressed: _onRetryAnalysis,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
              child: const Text(
                'Go back',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onRetryAnalysis() {
    HapticFeedback.mediumImpact();
    ref.read(analysisProvider.notifier).retry();
  }

  Widget _heroImage(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(path, fit: BoxFit.cover);
    }
    return Image.file(File(path), fit: BoxFit.cover);
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void _onSaveMeal() async {
    if (_saving) return;
    HapticFeedback.heavyImpact();
    setState(() => _saving = true);

    try {
      await ref.read(analysisProvider.notifier).saveMeal();
      ref.invalidate(mealHistoryProvider);
      ref.invalidate(todayCaloriesProvider);
      ref.invalidate(todayMealsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  color: AppColors.emerald, size: 20),
              SizedBox(width: 12),
              Text('Meal saved!',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
            ],
          ),
          backgroundColor: AppColors.surfaceLight,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16),
          elevation: 0,
        ),
      );
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e, st) {
      debugPrint('[SaveMeal] failed: $e');
      debugPrintStack(stackTrace: st, label: '[SaveMeal]');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline_rounded,
                  color: AppColors.error, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Couldn't save your meal. Please try again.",
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.surfaceLight,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16),
          elevation: 0,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _onScanAnother() {
    HapticFeedback.lightImpact();
    ref.read(analysisProvider.notifier).reset();
    Navigator.popUntil(context, (route) => route.isFirst);
  }
}
