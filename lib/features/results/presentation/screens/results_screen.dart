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

class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  @override
  Widget build(BuildContext context) {
    final analysisState = ref.watch(analysisProvider);

    return Scaffold(
      body: AnimatedGradientBackground(
        child: SafeArea(
          child: _buildContent(analysisState),
        ),
      ),
    );
  }

  Widget _buildContent(AnalysisState state) {
    switch (state.status) {
      case AnalysisStatus.loading:
        return _buildLoadingState();
      case AnalysisStatus.success:
        return _buildSuccessState(state.result!);
      case AnalysisStatus.error:
        return _buildErrorState(state.error ?? 'Something went wrong');
      case AnalysisStatus.idle:
        return _buildLoadingState();
    }
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPulsingIcon()
              .animate(onPlay: (c) => c.repeat())
              .shimmer(
                duration: 1500.ms,
                color: AppColors.emerald.withValues(alpha: 0.3),
              ),
          const SizedBox(height: 32),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: AppColors.emeraldGradient,
            ).createShader(bounds),
            child: const Text(
              'Analyzing your thali...',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 600.ms),
          const SizedBox(height: 12),
          const Text(
            'AI is identifying food items\nand calculating nutrition',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textTertiary,
              height: 1.5,
            ),
          )
              .animate()
              .fadeIn(duration: 600.ms, delay: 200.ms),
        ],
      ),
    );
  }

  Widget _buildPulsingIcon() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.emerald.withValues(alpha: 0.1),
        border: Border.all(
          color: AppColors.emerald.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: const Icon(
        Icons.auto_awesome_rounded,
        color: AppColors.emerald,
        size: 44,
      ),
    );
  }

  Widget _buildSuccessState(MealAnalysis meal) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Column(
              children: [
                _buildAppBar()
                    .animate()
                    .fadeIn(duration: 400.ms),
                const SizedBox(height: 24),
                _buildCalorieHeader(meal)
                    .animate()
                    .fadeIn(duration: 600.ms, delay: 100.ms)
                    .slideY(begin: 0.1, end: 0),
                const SizedBox(height: 24),
                MacroChart(meal: meal)
                    .animate()
                    .fadeIn(duration: 600.ms, delay: 200.ms)
                    .scale(begin: const Offset(0.95, 0.95)),
                const SizedBox(height: 24),
                _buildFoodItemsHeader()
                    .animate()
                    .fadeIn(duration: 600.ms, delay: 300.ms),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: FoodItemTile(item: meal.items[index])
                    .animate()
                    .fadeIn(
                      duration: 400.ms,
                      delay: Duration(milliseconds: 400 + (index * 80)),
                    )
                    .slideX(begin: 0.05, end: 0),
              );
            },
            childCount: meal.items.length,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                NeonButton(
                  text: 'Save Meal',
                  icon: Icons.bookmark_add_rounded,
                  onPressed: _onSaveMeal,
                ).animate()
                    .fadeIn(duration: 600.ms, delay: 600.ms)
                    .slideY(begin: 0.1, end: 0),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _onScanAnother,
                  child: const Text(
                    'Scan Another Thali',
                    style: TextStyle(
                      color: AppColors.cyan,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ).animate()
                    .fadeIn(duration: 600.ms, delay: 700.ms),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar() {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
          child: GlassCard(
            padding: const EdgeInsets.all(10),
            borderRadius: 12,
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary,
              size: 18,
            ),
          ),
        ),
        const Spacer(),
        const Text(
          'Nutrition Analysis',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
          },
          child: GlassCard(
            padding: const EdgeInsets.all(10),
            borderRadius: 12,
            child: const Icon(
              Icons.share_rounded,
              color: AppColors.cyan,
              size: 18,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalorieHeader(MealAnalysis meal) {
    return GlassCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const Text(
            'TOTAL CALORIES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: AppColors.emeraldGradient,
            ).createShader(bounds),
            child: Text(
              '${meal.totalCalories.toInt()}',
              style: const TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1,
                letterSpacing: -3,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'kcal',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: AppColors.emerald,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMiniMacro('Protein', '${meal.totalProtein.toInt()}g',
                  AppColors.cyan),
              _divider(),
              _buildMiniMacro('Carbs', '${meal.totalCarbs.toInt()}g',
                  AppColors.warning),
              _divider(),
              _buildMiniMacro(
                  'Fat', '${meal.totalFat.toInt()}g', AppColors.error),
              _divider(),
              _buildMiniMacro('Fiber', '${meal.totalFiber.toInt()}g',
                  AppColors.neonGreen),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 32,
      color: AppColors.glassBorder,
    );
  }

  Widget _buildMiniMacro(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFoodItemsHeader() {
    return const Row(
      children: [
        Icon(Icons.restaurant_menu_rounded, color: AppColors.emerald, size: 20),
        SizedBox(width: 8),
        Text(
          'Food Items Detected',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.error.withValues(alpha: 0.1),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Analysis Failed',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 32),
            NeonButton(
              text: 'Try Again',
              icon: Icons.refresh_rounded,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _onSaveMeal() async {
    HapticFeedback.heavyImpact();
    await ref.read(analysisProvider.notifier).saveMeal();
    ref.invalidate(mealHistoryProvider);
    ref.invalidate(todayCaloriesProvider);
    ref.invalidate(todayMealsProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.emerald, size: 20),
              SizedBox(width: 12),
              Text(
                'Meal saved successfully!',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: AppColors.surfaceLight,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  void _onScanAnother() {
    HapticFeedback.lightImpact();
    ref.read(analysisProvider.notifier).reset();
    Navigator.popUntil(context, (route) => route.isFirst);
  }
}
