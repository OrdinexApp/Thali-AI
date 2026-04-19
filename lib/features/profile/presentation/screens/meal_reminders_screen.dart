import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/animated_gradient_background.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../services/meal_reminders_controller.dart';

class MealRemindersScreen extends ConsumerWidget {
  const MealRemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(mealRemindersControllerProvider);
    final controller = ref.read(mealRemindersControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Meal Reminders',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: AnimatedGradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Stay consistent',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "We'll nudge you at meal times so nothing slips through.",
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),
                _buildEnableCard(context, settings, controller),
                const SizedBox(height: 18),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: settings.enabled ? 1 : 0.45,
                  child: IgnorePointer(
                    ignoring: !settings.enabled,
                    child: Column(
                      children: [
                        _buildTimeRow(
                          context,
                          icon: Icons.wb_sunny_rounded,
                          color: AppColors.warning,
                          label: 'Breakfast',
                          time: settings.breakfast,
                          onPick: (t) => controller.setBreakfast(t),
                        ),
                        const SizedBox(height: 12),
                        _buildTimeRow(
                          context,
                          icon: Icons.restaurant_rounded,
                          color: AppColors.cyan,
                          label: 'Lunch',
                          time: settings.lunch,
                          onPick: (t) => controller.setLunch(t),
                        ),
                        const SizedBox(height: 12),
                        _buildTimeRow(
                          context,
                          icon: Icons.nightlight_round,
                          color: AppColors.violet,
                          label: 'Dinner',
                          time: settings.dinner,
                          onPick: (t) => controller.setDinner(t),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnableCard(
    BuildContext context,
    MealRemindersSettings settings,
    MealRemindersController controller,
  ) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.emerald.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: AppColors.emerald,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily reminders',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Three nudges a day at your set times',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: settings.enabled,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.emerald,
            inactiveTrackColor: AppColors.surfaceLight,
            inactiveThumbColor: AppColors.textTertiary,
            onChanged: (value) async {
              HapticFeedback.selectionClick();
              final result = await controller.setEnabled(value);
              if (!result && value && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Notifications permission denied. Enable it in Settings to use reminders.',
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRow(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required TimeOfDay time,
    required ValueChanged<TimeOfDay> onPick,
  }) {
    return InkWell(
      onTap: () async {
        HapticFeedback.selectionClick();
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              timePickerTheme: const TimePickerThemeData(
                backgroundColor: AppColors.surface,
                hourMinuteTextColor: AppColors.textPrimary,
                dayPeriodTextColor: AppColors.textPrimary,
                dialBackgroundColor: AppColors.surfaceLight,
                dialHandColor: AppColors.emerald,
                entryModeIconColor: AppColors.emerald,
              ),
              colorScheme: const ColorScheme.dark(
                primary: AppColors.emerald,
                onPrimary: Colors.white,
                surface: AppColors.surface,
                onSurface: AppColors.textPrimary,
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) onPick(picked);
      },
      borderRadius: BorderRadius.circular(18),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              time.format(context),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
