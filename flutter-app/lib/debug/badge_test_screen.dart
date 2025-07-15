import 'package:flutter/material.dart';
import '../../models/user_badge.dart';
import '../../components/user_badge_chip.dart';
import '../../constants/app_design_tokens.dart';
import '../../styles/text_styles.dart';

class BadgeTestScreen extends StatelessWidget {
  const BadgeTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Badge Test Screen'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Badge Display Test',
              style: AppTextStyles.headlineMedium,
            ),
            const SizedBox(height: 16),
            
            // Test individual emojis
            Text(
              'Individual Emojis:',
              style: AppTextStyles.headlineSmall,
            ),
            const SizedBox(height: 8),
            
            // Test direct emoji display
            Row(
              children: [
                Text('🍽️', style: TextStyle(fontSize: 24)),
                SizedBox(width: 8),
                Text('🐌', style: TextStyle(fontSize: 24)),
                SizedBox(width: 8),
                Text('⚡', style: TextStyle(fontSize: 24)),
                SizedBox(width: 8),
                Text('🥗', style: TextStyle(fontSize: 24)),
                SizedBox(width: 8),
                Text('📸', style: TextStyle(fontSize: 24)),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Test all badges from UserBadge model
            Text(
              'All Badges from Model:',
              style: AppTextStyles.headlineSmall,
            ),
            const SizedBox(height: 8),
            
            // Loop through all categories
            ...UserBadge.allCategories.map((category) {
              final badges = UserBadge.getBadgesByCategory(category);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    category,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppDesignTokens.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Show badges as text
                  ...badges.map((badge) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        // Direct emoji
                        Text(
                          badge.emoji,
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 12),
                        // Badge name
                        Expanded(
                          child: Text(
                            '${badge.name} - ${badge.description}',
                            style: AppTextStyles.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  )),
                  
                  const SizedBox(height: 12),
                  
                  // Show badges as chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: badges.map((badge) => UserBadgeChip(
                      badgeId: badge.id,
                    )).toList(),
                  ),
                ],
              );
            }).toList(),
            
            const SizedBox(height: 32),
            
            // Test problematic scenarios
            Text(
              'Debug Information:',
              style: AppTextStyles.headlineSmall,
            ),
            const SizedBox(height: 8),
            
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Badges: ${UserBadge.allBadges.length}'),
                  Text('Total Categories: ${UserBadge.allCategories.length}'),
                  Text('Categories: ${UserBadge.allCategories.join(", ")}'),
                  const SizedBox(height: 8),
                  Text('Platform: ${Theme.of(context).platform}'),
                  Text('Text Scale Factor: ${MediaQuery.of(context).textScaleFactor}'),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}