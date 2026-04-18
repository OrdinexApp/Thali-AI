import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/animated_gradient_background.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../services/providers.dart';
import '../widgets/calorie_ring.dart';
import '../widgets/meal_history_tile.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _takePhoto() async {
    HapticFeedback.mediumImpact();
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (photo != null && mounted) _onPhotoPicked(photo.path);
  }

  Future<void> _pickFromGallery() async {
    HapticFeedback.lightImpact();
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (photo != null && mounted) _onPhotoPicked(photo.path);
  }

  void _onPhotoPicked(String path) {
    ref.read(selectedImagePathProvider.notifier).state = path;
    ref.read(analysisProvider.notifier).reset();
    ref.read(detectionProvider.notifier).reset();
    ref.read(detectionProvider.notifier).detectItems(path);
    Navigator.pushNamed(context, '/question');
  }

  @override
  Widget build(BuildContext context) {
    final todayCalories = ref.watch(todayCaloriesProvider);
    final todayMeals = ref.watch(todayMealsProvider);
    final dailyGoal = ref.watch(dailyCalorieGoalProvider);

    return AnimatedGradientBackground(
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader()
                        .animate()
                        .fadeIn(duration: 700.ms)
                        .slideY(begin: -0.15, end: 0, curve: Curves.easeOut),
                    const SizedBox(height: 28),
                    _buildCalorieCard(todayCalories, dailyGoal)
                        .animate()
                        .fadeIn(duration: 700.ms, delay: 100.ms)
                        .slideY(begin: 0.08, end: 0, curve: Curves.easeOut),
                    const SizedBox(height: 20),
                    _buildScanCTA()
                        .animate()
                        .fadeIn(duration: 700.ms, delay: 200.ms)
                        .slideY(begin: 0.08, end: 0, curve: Curves.easeOut),
                    const SizedBox(height: 36),
                    _buildSectionHeader('Recent meals', 'View all')
                        .animate()
                        .fadeIn(duration: 700.ms, delay: 300.ms),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            _buildMealsList(todayMeals),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textTertiary.withValues(alpha: 0.9),
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 4),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFF8FAFC), Color(0xFFCBD5E1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: const Text(
                  'Thali',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -1.5,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildIconButton(Icons.notifications_none_rounded, AppColors.textSecondary),
      ],
    );
  }

  Widget _buildIconButton(IconData icon, Color color) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      borderRadius: 16,
      showTopHighlight: true,
      child: Icon(icon, color: color, size: 22),
    );
  }

  // ── Calorie Card ──────────────────────────────────────────────────────────

  Widget _buildCalorieCard(AsyncValue<double> todayCalories, int dailyGoal) {
    final consumed = todayCalories.valueOrNull ?? 0;
    final goal = dailyGoal.toDouble();
    final remaining = goal - consumed;
    final progress = goal == 0 ? 0.0 : (consumed / goal).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.emerald.withValues(alpha: 0.1),
            blurRadius: 40,
            offset: const Offset(0, 16),
            spreadRadius: -8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.surfaceLight.withValues(alpha: 0.8),
                  AppColors.surface.withValues(alpha: 0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.glassBorder,
                width: 0.8,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Ring
                    CalorieRing(consumed: consumed, target: goal, size: 110),
                    const SizedBox(width: 24),
                    // Numbers
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TODAY',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.8,
                              color: AppColors.textTertiary.withValues(alpha: 0.85),
                            ),
                          ),
                          const SizedBox(height: 8),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '${consumed.toInt()}',
                                  style: const TextStyle(
                                    fontSize: 42,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -2,
                                    height: 1,
                                  ),
                                ),
                                const TextSpan(
                                  text: ' kcal',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.emerald,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildRemainingPill(remaining),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Progress bar
                _buildProgressBar(progress),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '0 kcal',
                      style: TextStyle(fontSize: 11, color: AppColors.textTertiary.withValues(alpha: 0.7), fontWeight: FontWeight.w500),
                    ),
                    Text(
                      'Goal: ${goal.toInt()} kcal',
                      style: const TextStyle(fontSize: 11, color: AppColors.textTertiary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRemainingPill(double remaining) {
    final isOver = remaining < 0;
    final color = isOver ? AppColors.error : AppColors.emerald;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 7),
          Text(
            isOver
                ? '${remaining.abs().toInt()} kcal over'
                : '${remaining.toInt()} kcal left',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(double progress) {
    return SizedBox(
      height: 5,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Stack(
          children: [
            Container(color: AppColors.surfaceMid),
            FractionallySizedBox(
              widthFactor: progress,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppColors.emeraldGradient,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x4422C55E),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Scan CTA ──────────────────────────────────────────────────────────────

  Widget _buildScanCTA() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.emerald.withValues(alpha: 0.2),
            blurRadius: 48,
            offset: const Offset(0, 20),
            spreadRadius: -8,
          ),
          BoxShadow(
            color: AppColors.cyan.withValues(alpha: 0.1),
            blurRadius: 64,
            offset: const Offset(0, 28),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A4A2E), Color(0xFF0E3340)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              // Top highlight line
              Positioned(
                top: 0,
                left: 32,
                right: 32,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.25),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
              // Subtle dot pattern
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.emerald.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Positioned(
                left: -40,
                bottom: -30,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.cyan.withValues(alpha: 0.04),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon + badge
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: AppColors.emeraldGradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.emerald.withValues(alpha: 0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.camera_alt_rounded,
                              color: Colors.black, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI-POWERED',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.8,
                                color: AppColors.emerald.withValues(alpha: 0.85),
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Instant Analysis',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Photograph your thali and get a complete nutritional breakdown in seconds.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.55,
                        color: Colors.white.withValues(alpha: 0.72),
                        letterSpacing: 0.05,
                      ),
                    ),
                    const SizedBox(height: 22),
                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildPrimaryButton(
                            icon: Icons.camera_alt_rounded,
                            label: 'Take Photo',
                            onTap: _takePhoto,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: _buildSecondaryButton(
                            icon: Icons.photo_library_rounded,
                            label: 'Gallery',
                            onTap: _pickFromGallery,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: AppColors.emeraldGradient),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.emerald.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.black, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 17),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section header ────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, String action) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          action,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.emerald,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }

  // ── Meals list ────────────────────────────────────────────────────────────

  Widget _buildMealsList(AsyncValue<List<dynamic>> todayMeals) {
    return todayMeals.when(
      data: (meals) {
        if (meals.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildEmptyState(),
            ).animate().fadeIn(duration: 600.ms, delay: 400.ms),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: MealHistoryTile(meal: meals[index])
                  .animate()
                  .fadeIn(duration: 500.ms, delay: Duration(milliseconds: 300 + index * 80))
                  .slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
            ),
            childCount: meals.length,
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(48),
            child: CircularProgressIndicator(
              color: AppColors.emerald,
              strokeWidth: 2,
            ),
          ),
        ),
      ),
      error: (_, __) => const SliverToBoxAdapter(
        child: Center(child: Text('Error loading meals', style: TextStyle(color: AppColors.error))),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          decoration: BoxDecoration(
            color: AppColors.glassBackground,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.glassBorder, width: 0.8),
          ),
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.emerald.withValues(alpha: 0.12),
                      AppColors.cyan.withValues(alpha: 0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.emerald.withValues(alpha: 0.2)),
                ),
                child: Icon(
                  Icons.restaurant_menu_rounded,
                  size: 28,
                  color: AppColors.emerald.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'No meals tracked yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Scan your thali to instantly see calories\nand a full nutrition breakdown.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.textTertiary.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
