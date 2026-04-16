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

  Future<void> _takePhoto() async {
    HapticFeedback.mediumImpact();
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (photo != null && mounted) {
      _onPhotoPicked(photo.path);
    }
  }

  Future<void> _pickFromGallery() async {
    HapticFeedback.lightImpact();
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (photo != null && mounted) {
      _onPhotoPicked(photo.path);
    }
  }

  void _onPhotoPicked(String path) {
    ref.read(selectedImagePathProvider.notifier).state = path;
    ref.read(rotiCountProvider.notifier).state = 2;
    ref.read(analysisProvider.notifier).reset();
    ref.read(detectionProvider.notifier).reset();
    // Fire off Step 1 detection in the background
    ref.read(detectionProvider.notifier).detectItems(path);
    Navigator.pushNamed(context, '/question');
  }

  @override
  Widget build(BuildContext context) {
    final todayCalories = ref.watch(todayCaloriesProvider);
    final todayMeals = ref.watch(todayMealsProvider);
    final size = MediaQuery.of(context).size;

    return AnimatedGradientBackground(
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader()
                        .animate()
                        .fadeIn(duration: 600.ms)
                        .slideY(begin: -0.2, end: 0),
                    const SizedBox(height: 28),
                    _buildCalorieSummary(todayCalories, size)
                        .animate()
                        .fadeIn(duration: 600.ms, delay: 200.ms)
                        .slideY(begin: 0.1, end: 0),
                    const SizedBox(height: 28),
                    _buildScanButton()
                        .animate()
                        .fadeIn(duration: 600.ms, delay: 400.ms)
                        .scale(begin: const Offset(0.9, 0.9)),
                    const SizedBox(height: 28),
                    _buildRecentMealsHeader()
                        .animate()
                        .fadeIn(duration: 600.ms, delay: 500.ms),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            _buildMealsList(todayMeals),
            const SliverToBoxAdapter(
              child: SizedBox(height: 120),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: AppColors.emeraldGradient,
              ).createShader(bounds),
              child: const Text(
                'Thali',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Track your Indian meals',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        GlassCard(
          padding: const EdgeInsets.all(12),
          borderRadius: 16,
          child: const Icon(
            Icons.notifications_none_rounded,
            color: AppColors.cyan,
            size: 24,
          ),
        ),
      ],
    );
  }

  Widget _buildCalorieSummary(AsyncValue<double> todayCalories, Size size) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          CalorieRing(
            consumed: todayCalories.valueOrNull ?? 0,
            target: 2000,
            size: 100,
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Today's Intake",
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${(todayCalories.valueOrNull ?? 0).toInt()}',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -1,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text(
                        'kcal',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.emerald,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildMacroBar('Remaining', 2000 - (todayCalories.valueOrNull ?? 0)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroBar(String label, double value) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: value > 0 ? AppColors.emerald : AppColors.error,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ${value.toInt()} kcal',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildScanButton() {
    return GestureDetector(
      onTap: _takePhoto,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: AppColors.emeraldGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.emerald.withValues(alpha: 0.35),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Scan Your Thali',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Take a photo to analyze calories',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.7),
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildActionChip(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  onTap: _takePhoto,
                ),
                const SizedBox(width: 12),
                _buildActionChip(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  onTap: _pickFromGallery,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentMealsHeader() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Recent Meals',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          'View All',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.emerald,
          ),
        ),
      ],
    );
  }

  Widget _buildMealsList(AsyncValue<List<dynamic>> todayMeals) {
    return todayMeals.when(
      data: (meals) {
        if (meals.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GlassCard(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.restaurant_menu_rounded,
                      size: 48,
                      color: AppColors.textTertiary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No meals tracked today',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Scan your first thali to get started!',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 600.ms, delay: 600.ms),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final meal = meals[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: MealHistoryTile(meal: meal)
                    .animate()
                    .fadeIn(
                      duration: 400.ms,
                      delay: Duration(milliseconds: 600 + (index * 100)),
                    )
                    .slideX(begin: 0.1, end: 0),
              );
            },
            childCount: meals.length,
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(color: AppColors.emerald),
          ),
        ),
      ),
      error: (_, __) => const SliverToBoxAdapter(
        child: Center(child: Text('Error loading meals')),
      ),
    );
  }
}
