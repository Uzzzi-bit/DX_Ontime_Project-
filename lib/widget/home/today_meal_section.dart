import 'package:flutter/material.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'dart:convert';
import '../../utils/responsive_helper.dart';

class TodayMealSection extends StatelessWidget {
  const TodayMealSection({
    super.key,
    required this.meals,
    required this.onMealTap,
  });

  final List<Map<String, dynamic>> meals;
  final ValueChanged<String> onMealTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '오늘의 추천 식단',
          style: TextStyle(
            fontSize: ResponsiveHelper.fontSize(context, 16),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: const Color(0xFF000000),
          ),
        ),
        SizedBox(height: ResponsiveHelper.height(context, 0.015)),
        Container(
          padding: ResponsiveHelper.padding(context, all: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: const Color(0xFFF0ECE4),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(ResponsiveHelper.width(context, 0.029)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SizedBox(
            height: ResponsiveHelper.height(context, 0.19),
            child: Center(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: meals.length,
                separatorBuilder: (_, __) => SizedBox(width: ResponsiveHelper.width(context, 0.043)),
                itemBuilder: (context, index) {
                  final meal = meals[index];
                  return Bounceable(
                    onTap: () => onMealTap(meal['id'] as String),
                    child: _MealCard(
                      meal: meal,
                      onTap: () => onMealTap(meal['id'] as String),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.meal,
    required this.onTap,
  });

  final Map<String, dynamic> meal;
  final VoidCallback onTap;

  /// 이미지 경로에 따라 적절한 위젯을 반환하는 헬퍼 함수
  Widget _buildMealImage(String imagePath, Color backgroundColor, BuildContext context) {
    if (imagePath.isEmpty) {
      return Container(
        width: ResponsiveHelper.width(context, 0.187),
        height: ResponsiveHelper.width(context, 0.187),
        decoration: BoxDecoration(
          color: backgroundColor.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.restaurant_menu,
          size: ResponsiveHelper.fontSize(context, 35),
          color: const Color(0xFF49454F),
        ),
      );
    }

    // Data URL 처리 (base64)
    if (imagePath.startsWith('data:image/')) {
      try {
        final base64String = imagePath.split(',')[1];
        final imageBytes = base64Decode(base64String);
        return Image.memory(
          imageBytes,
          width: ResponsiveHelper.width(context, 0.187),
          height: ResponsiveHelper.width(context, 0.187),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: ResponsiveHelper.width(context, 0.187),
              height: ResponsiveHelper.width(context, 0.187),
              decoration: BoxDecoration(
                color: backgroundColor.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.restaurant_menu,
                size: ResponsiveHelper.fontSize(context, 35),
                color: const Color(0xFF49454F),
              ),
            );
          },
        );
      } catch (e) {
        return Container(
          width: ResponsiveHelper.width(context, 0.187),
          height: ResponsiveHelper.width(context, 0.187),
          decoration: BoxDecoration(
            color: backgroundColor.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.restaurant_menu,
            size: ResponsiveHelper.fontSize(context, 35),
            color: const Color(0xFF49454F),
          ),
        );
      }
    }

    // 네트워크 URL 처리 (http/https)
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return Image.network(
        imagePath,
        width: ResponsiveHelper.width(context, 0.187),
        height: ResponsiveHelper.width(context, 0.187),
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: ResponsiveHelper.width(context, 0.187),
            height: ResponsiveHelper.width(context, 0.187),
            decoration: BoxDecoration(
              color: backgroundColor.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: ResponsiveHelper.width(context, 0.187),
            height: ResponsiveHelper.width(context, 0.187),
            decoration: BoxDecoration(
              color: backgroundColor.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.restaurant_menu,
              size: ResponsiveHelper.fontSize(context, 35),
              color: const Color(0xFF49454F),
            ),
          );
        },
      );
    }

    // Asset 이미지 처리
    return Image.asset(
      imagePath,
      width: ResponsiveHelper.width(context, 0.187),
      height: ResponsiveHelper.width(context, 0.187),
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: ResponsiveHelper.width(context, 0.187),
          height: ResponsiveHelper.width(context, 0.187),
          decoration: BoxDecoration(
            color: backgroundColor.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.restaurant_menu,
            size: ResponsiveHelper.fontSize(context, 35),
            color: const Color(0xFF49454F),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = Color(meal['backgroundColor'] as int);
    final tags = meal['tags'] as List<String>;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ResponsiveHelper.width(context, 0.053)),
      child: Container(
        width: ResponsiveHelper.width(context, 0.269),
        height: ResponsiveHelper.height(context, 0.19),
        decoration: BoxDecoration(
          color: backgroundColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(ResponsiveHelper.width(context, 0.053)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: ResponsiveHelper.padding(context, horizontal: 8, vertical: 8),
              child: Text(
                meal['name'] as String,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: ResponsiveHelper.fontSize(context, 10),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: const Color(0xFF49454F),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(500),
                  child: _buildMealImage(
                    meal['imagePath'] as String,
                    backgroundColor,
                    context,
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: ResponsiveHelper.width(context, 0.021)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveHelper.width(context, 0.021),
                      vertical: ResponsiveHelper.height(context, 0.005),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(ResponsiveHelper.width(context, 0.08)),
                    ),
                    child: Text(
                      '${meal['calories']} kcal',
                      style: TextStyle(
                        fontSize: ResponsiveHelper.fontSize(context, 8),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        color: const Color(0xFF49454F),
                      ),
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.height(context, 0.005)),
                  Wrap(
                    spacing: ResponsiveHelper.width(context, 0.011),
                    runSpacing: ResponsiveHelper.height(context, 0.005),
                    children: tags.map((tag) {
                      return Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveHelper.width(context, 0.016),
                          vertical: ResponsiveHelper.height(context, 0.002),
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFF49454F).withOpacity(0.5),
                          ),
                          borderRadius: BorderRadius.circular(ResponsiveHelper.width(context, 0.027)),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: ResponsiveHelper.fontSize(context, 7),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                            color: const Color(0xFF49454F),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            SizedBox(height: ResponsiveHelper.height(context, 0.01)),
          ],
        ),
      ),
    );
  }
}
