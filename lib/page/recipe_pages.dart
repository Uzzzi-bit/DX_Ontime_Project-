import 'package:flutter/material.dart';
import '../widget/bottom_bar_widget.dart';
import '../theme/color_palette.dart';
import 'oven_pages.dart';

// [API] 실제 서버 응답과 유사한 형태의 데이터 모델
class RecipeData {
  final String title;
  final String fullTitle;
  final String imagePath;
  final List<String> ingredients;
  final List<String> cookingSteps;
  final String tip;
  final bool isOvenAvailable;
  final String? ovenMode; // 구이, 오븐, 열풍, 스팀, 전자레인지, 복합
  final int? ovenTimeMinutes; // 분 단위

  RecipeData({
    required this.title,
    required this.fullTitle,
    required this.imagePath,
    required this.ingredients,
    required this.cookingSteps,
    required this.tip,
    required this.isOvenAvailable,
    this.ovenMode,
    this.ovenTimeMinutes,
  });
}

class RecipeScreen extends StatefulWidget {
  const RecipeScreen({super.key});

  @override
  State<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends State<RecipeScreen> {
  int _selectedMenuIndex = 0;

  // [API] 사용자 이름과 추천 시간대는 추후 로그인 정보 및 서버 시간으로 대체
  final String _userName = '김레제';

  // [API] Mock Data - 실제 서버 응답과 유사한 형태
  final List<RecipeData> _recipes = [
    RecipeData(
      title: '간장 닭봉 구이',
      fullTitle: '저염 간장 닭봉(닭다리)구이',
      imagePath: 'assets/image/sample_food.png',
      ingredients: [
        '닭봉 500g',
        '간장 2큰술',
        '올리브오일 1큰술',
        '마늘 3쪽',
        '생강 1조각',
      ],
      cookingSteps: [
        '1. 닭봉을 깨끗이 씻어 물기를 제거합니다.',
        '2. 간장, 올리브오일, 다진 마늘, 생강을 섞어 양념장을 만듭니다.',
        '3. 닭봉에 양념장을 발라 30분간 재워둡니다.',
        '4. 예열된 오븐에 180도에서 20분간 구워줍니다.',
        '5. 뒤집어서 10분 더 구워 완성합니다.',
      ],
      tip: '임산부를 위한 덜 달고 덜 짜게 구성한 레시피 입니다.\n곁들이는 반찬은 오이무침, 데친 브로콜리, 찐감자 처럼\n담백한게 좋아요',
      isOvenAvailable: true,
      ovenMode: '구이',
      ovenTimeMinutes: 20,
    ),
    RecipeData(
      title: '냉메밀',
      fullTitle: '냉메밀',
      imagePath: 'assets/image/sample_food.png',
      ingredients: [
        '메밀면 200g',
        '물 1L',
        '다시마 1장',
        '간장 2큰술',
        '설탕 1작은술',
      ],
      cookingSteps: [
        '1. 물에 다시마를 넣고 끓여 육수를 만듭니다.',
        '2. 메밀면을 끓는 물에 넣어 3분간 삶습니다.',
        '3. 찬물에 헹궈 식힙니다.',
        '4. 간장과 설탕을 섞어 양념장을 만듭니다.',
        '5. 면에 양념장을 넣고 곁들여 완성합니다.',
      ],
      tip: '시원한 냉메밀은 여름철 입맛을 돋우는 좋은 메뉴입니다.\n면을 너무 오래 삶지 않도록 주의하세요.',
      isOvenAvailable: false,
    ),
    RecipeData(
      title: '미역국',
      fullTitle: '미역국',
      imagePath: 'assets/image/sample_food.png',
      ingredients: [
        '마른 미역 20g',
        '소고기 100g',
        '물 1L',
        '참기름 1큰술',
        '간장 1큰술',
      ],
      cookingSteps: [
        '1. 마른 미역을 찬물에 불려 부드럽게 만듭니다.',
        '2. 소고기를 잘게 썰어 참기름에 볶습니다.',
        '3. 물을 넣고 끓기 시작하면 미역을 넣습니다.',
        '4. 간장으로 간을 맞추고 10분간 끓입니다.',
        '5. 완성합니다.',
      ],
      tip: '미역국은 출산 후 회복에 좋은 음식입니다.\n너무 짜지 않게 간을 맞추는 것이 중요합니다.',
      isOvenAvailable: false,
    ),
  ];

  String _getRecommendationMessage() {
    final hour = DateTime.now().hour;
    // [API] 사용자 이름과 추천 시간대는 추후 로그인 정보 및 서버 시간으로 대체
    if (hour >= 11 && hour < 14) {
      return '$_userName 님을 위한\n점심으로 추천하는 메뉴 입니다';
    } else if (hour >= 17 && hour < 21) {
      return '$_userName 님을 위한\n저녁으로 추천하는 메뉴 입니다';
    } else {
      return '$_userName 님을 위한\n추천 메뉴 입니다';
    }
  }

  void _navigateToOven() {
    final selectedRecipe = _recipes[_selectedMenuIndex];
    if (selectedRecipe.isOvenAvailable) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OvenScreen(
            recipeName: selectedRecipe.fullTitle,
            ovenMode: selectedRecipe.ovenMode ?? '구이',
            ovenTimeMinutes: selectedRecipe.ovenTimeMinutes ?? 20,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedRecipe = _recipes[_selectedMenuIndex];

    return Scaffold(
      backgroundColor: ColorPalette.bg100,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back,
            color: ColorPalette.text100,
          ),
        ),
        title: const Text(
          'AI 추천식단',
          style: TextStyle(
            color: ColorPalette.text100,
            fontSize: 20,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            // 추천 멘트
            Center(
              child: Text(
                _getRecommendationMessage(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: ColorPalette.text100,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // 메뉴 선택 탭
            Row(
              children: List.generate(_recipes.length, (index) {
                final recipe = _recipes[index];
                final isSelected = index == _selectedMenuIndex;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedMenuIndex = index;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? ColorPalette.primary100 : ColorPalette.bg100,
                        border: Border.all(
                          color: isSelected ? ColorPalette.primary100 : ColorPalette.primary100.withOpacity(0.5),
                        ),
                        borderRadius: BorderRadius.circular(23),
                      ),
                      child: Text(
                        recipe.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ColorPalette.text200,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            // 메뉴 사진
            Container(
              width: double.infinity,
              height: 141,
              decoration: BoxDecoration(
                color: const Color(0xFFD9D9D9),
                borderRadius: BorderRadius.circular(11),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Image.asset(
                  selectedRecipe.imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Text(
                        '메뉴 사진',
                        style: TextStyle(
                          color: ColorPalette.text100,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 레시피 섹션
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: ColorPalette.bg300),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '레시피',
                    style: TextStyle(
                      color: ColorPalette.text100,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    selectedRecipe.fullTitle,
                    style: const TextStyle(
                      color: ColorPalette.text100,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 재료 섹션
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: ColorPalette.bg300),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '재료',
                    style: TextStyle(
                      color: ColorPalette.text100,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...selectedRecipe.ingredients.map(
                    (ingredient) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• $ingredient',
                        style: const TextStyle(
                          color: ColorPalette.text100,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 조리 방법 섹션
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: ColorPalette.bg300),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '조리 방법',
                    style: TextStyle(
                      color: ColorPalette.text100,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...selectedRecipe.cookingSteps.map(
                    (step) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        step,
                        style: const TextStyle(
                          color: ColorPalette.text100,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // 팁 섹션
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '💡',
                  style: TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    selectedRecipe.tip,
                    style: const TextStyle(
                      color: Color(0xFF000000),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                      height: 1.7,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            // 광파오븐 버튼 (오븐 사용 가능한 경우만 표시)
            if (selectedRecipe.isOvenAvailable) ...[
              const Center(
                child: Text(
                  '광파오븐으로 레시피를 보낼까요?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF0F0F0F),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: _navigateToOven,
                  child: const Text(
                    '광파오븐으로 보내기',
                    style: TextStyle(
                      color: ColorPalette.primary200,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: const BottomBarWidget(currentRoute: '/recipe'),
    );
  }
}
