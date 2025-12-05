import 'package:flutter/material.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widget/bottom_bar_widget.dart';
import '../theme/color_palette.dart';
import '../api/member_api_service.dart';
import 'oven_pages.dart';

// 오븐 설정 데이터 모델
class OvenSettings {
  final String mode; // 예: 오븐, 에어프라이어, 전자레인지
  final String temperature; // 예: 180도
  final String time; // 예: 20분

  OvenSettings({
    required this.mode,
    required this.temperature,
    required this.time,
  });
}

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
  final OvenSettings? ovenSettings; // 파싱된 오븐 설정 (null 가능)
  final int calories; // 칼로리
  final List<String> tags; // 대표 영양소 태그

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
    this.ovenSettings,
    required this.calories,
    required this.tags,
  });

  /// AI 백엔드에서 내려준 JSON을 RecipeData 객체로 변환하는 생성자
  factory RecipeData.fromJson(Map<String, dynamic> json) {
    // List<String>으로 안전하게 변환하는 헬퍼
    List<String> toStringList(dynamic value) {
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      return const [];
    }

    final cookingSteps = toStringList(json['cookingSteps']);
    final isOvenAvailable = json['isOvenAvailable'] as bool? ?? false;
    final ovenMode = json['ovenMode'] as String?;
    final ovenTimeMinutes = (json['ovenTimeMinutes'] as num?)?.toInt();

    // AI가 제공한 오븐 정보가 있으면 ovenSettings 생성
    OvenSettings? ovenSettings;
    if (isOvenAvailable && ovenMode != null && ovenTimeMinutes != null) {
      // cookingSteps에서 온도 정보 추출 시도
      final stepsText = cookingSteps.join(' ');
      final tempReg = RegExp(r'(\d{1,3})(도|℃)');
      final tempMatch = tempReg.firstMatch(stepsText);
      final temperature = tempMatch?.group(0) ?? '180도';

      // 오븐 모드 정규화
      String normalizedMode = ovenMode;
      final modeMap = {
        '오븐': '오븐',
        '전자레인지': '전자레인지',
        '해동': '해동',
        '에어프라이': '에어 프라이',
        '스팀전자레인지': '스팀 전자레인지',
        '에어수비드': '에어수비드',
      };
      if (modeMap.containsKey(ovenMode)) {
        normalizedMode = modeMap[ovenMode]!;
      }

      ovenSettings = OvenSettings(
        mode: normalizedMode,
        temperature: temperature,
        time: '${ovenTimeMinutes}분',
      );
    } else if (isOvenAvailable && cookingSteps.isNotEmpty) {
      // AI가 오븐 정보를 제공하지 않았지만 isOvenAvailable이 true면
      // cookingSteps에서 파싱 시도
      ovenSettings = _parseOvenSettingsFromSteps(cookingSteps);
    }

    return RecipeData(
      title: json['title'] as String? ?? '',
      fullTitle: json['fullTitle'] as String? ?? '',
      imagePath: json['imagePath'] as String? ?? '',
      ingredients: toStringList(json['ingredients']),
      cookingSteps: cookingSteps,
      tip: json['tip'] as String? ?? '',
      isOvenAvailable: isOvenAvailable,
      ovenMode: ovenMode,
      ovenTimeMinutes: ovenTimeMinutes,
      ovenSettings: ovenSettings,
      calories: (json['calories'] as num?)?.toInt() ?? 0,
      tags: toStringList(json['tags']).sublist(0, 3),
    );
  }

  /// cookingSteps에서 오븐 설정을 파싱하는 헬퍼 함수
  static OvenSettings? _parseOvenSettingsFromSteps(List<String> steps) {
    String fullText = steps.join(' ');
    final modeReg = RegExp(r'(전자레인지|오븐|에어프라이어?|해동|스팀\s*전자레인지|에어수비드|광파오븐)');
    final modeMatches = modeReg.allMatches(fullText);

    for (final modeMatch in modeMatches) {
      final mode = modeMatch.group(0)!;
      final modeStart = modeMatch.start;
      final searchStart = (modeStart - 20).clamp(0, fullText.length);
      final searchEnd = (modeStart + 100).clamp(0, fullText.length);
      final contextText = fullText.substring(searchStart, searchEnd);

      final tempReg = RegExp(r'(\d{1,3})(도|℃)');
      final tempMatch = tempReg.firstMatch(contextText);

      String? timeStr;
      if (tempMatch != null) {
        final tempEnd = tempMatch.end;
        final timeContext = contextText.substring(tempEnd);
        final timeReg = RegExp(r'(\d{1,3})분');
        final timeMatch = timeReg.firstMatch(timeContext);
        if (timeMatch != null) {
          timeStr = timeMatch.group(0);
        }
      } else {
        final timeReg = RegExp(r'(\d{1,3})분');
        final timeMatch = timeReg.firstMatch(contextText);
        if (timeMatch != null) {
          timeStr = timeMatch.group(0);
        }
      }

      if (timeStr != null) {
        // 모드 이름 정규화
        String normalizeMode(String mode) {
          String normalized = mode.replaceAll(RegExp(r'\s+'), '');
          final modeMap = {
            '에어프라이어': '에어 프라이',
            '에어프라이': '에어 프라이',
            '스팀전자레인지': '스팀 전자레인지',
            '전자레인지': '전자레인지',
            '오븐': '오븐',
            '해동': '해동',
            '에어수비드': '에어수비드',
            '광파오븐': '전자레인지',
          };
          if (modeMap.containsKey(normalized)) {
            return modeMap[normalized]!;
          }
          for (final entry in modeMap.entries) {
            if (normalized.contains(entry.key) || entry.key.contains(normalized)) {
              return entry.value;
            }
          }
          return mode;
        }

        String normalizedMode = normalizeMode(mode);
        return OvenSettings(
          mode: normalizedMode,
          temperature: tempMatch?.group(0) ?? '180도',
          time: timeStr,
        );
      }
    }
    return null;
  }
}

class RecipeScreen extends StatefulWidget {
  final int? initialMenuIndex; // 초기 선택할 메뉴 인덱스
  final List<RecipeData>? initialRecipes; // AI에서 받아온 레시피가 있으면 사용

  const RecipeScreen({
    super.key,
    this.initialMenuIndex,
    this.initialRecipes,
  });

  @override
  State<RecipeScreen> createState() => _RecipeScreenState();

  // 레시피 리스트를 외부에서 접근할 수 있도록 static getter 제공
  static List<RecipeData> getRecommendedRecipes() {
    return _RecipeScreenState._getRecipes();
  }

  // 최신 AI 레시피를 저장하는 정적 변수 (전역 상태)
  static List<RecipeData>? _latestAiRecipes;

  // 최신 AI 레시피를 설정하는 정적 메서드
  static void setLatestAiRecipes(List<RecipeData> recipes) {
    _latestAiRecipes = recipes;
    debugPrint('✅ [RecipeScreen] 최신 AI 레시피 저장: ${recipes.length}개');
  }

  // 최신 AI 레시피를 가져오는 정적 메서드
  static List<RecipeData>? getLatestAiRecipes() {
    return _latestAiRecipes;
  }
}

class _RecipeScreenState extends State<RecipeScreen> with WidgetsBindingObserver {
  late int _selectedMenuIndex;
  late List<RecipeData> _recipes;
  String _userName = '사용자'; // 기본값

  @override
  void initState() {
    super.initState();
    // 생명주기 관찰자 등록
    WidgetsBinding.instance.addObserver(this);
    // 초기 메뉴 인덱스가 전달되면 사용, 없으면 0 (첫 번째 메뉴)
    _selectedMenuIndex = widget.initialMenuIndex ?? 0;
    // AI에서 레시피가 넘어오면 그걸 사용, 아니면 전역 상태에서 가져오기, 없으면 기존 목 데이터 사용
    _recipes = widget.initialRecipes ?? RecipeScreen.getLatestAiRecipes() ?? RecipeScreen.getRecommendedRecipes();
    debugPrint('✅ [RecipeScreen] 초기화: 레시피 ${_recipes.length}개 로드');
    if (_recipes.isNotEmpty) {
      debugPrint('  - 첫 번째 레시피: ${_recipes[0].title}');
    }
    // 사용자 닉네임 로드
    _loadUserNickname();
  }

  @override
  void dispose() {
    // 생명주기 관찰자 해제
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // 앱이 포그라운드로 돌아올 때 최신 레시피 확인
    if (state == AppLifecycleState.resumed) {
      _checkForLatestRecipes();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 화면이 활성화될 때마다 최신 AI 레시피 확인
    _checkForLatestRecipes();
  }

  /// 최신 AI 레시피를 확인하고 업데이트하는 헬퍼 메서드
  void _checkForLatestRecipes() {
    final latestRecipes = RecipeScreen.getLatestAiRecipes();
    if (latestRecipes != null && latestRecipes.isNotEmpty) {
      // 최신 레시피가 있고 현재 레시피와 다르면 업데이트
      bool needsUpdate = false;
      if (_recipes.length != latestRecipes.length) {
        needsUpdate = true;
      } else if (_recipes.isNotEmpty && latestRecipes.isNotEmpty) {
        // 첫 번째 레시피의 제목이나 다른 속성을 비교
        if (_recipes[0].title != latestRecipes[0].title || _recipes[0].fullTitle != latestRecipes[0].fullTitle) {
          needsUpdate = true;
        }
      }

      if (needsUpdate) {
        debugPrint('🔄 [RecipeScreen] 최신 AI 레시피 감지: ${latestRecipes.length}개');
        if (mounted) {
          setState(() {
            _recipes = latestRecipes;
            // 선택된 메뉴 인덱스가 범위를 벗어나면 0으로 초기화
            if (_selectedMenuIndex >= _recipes.length) {
              _selectedMenuIndex = 0;
            }
          });
        }
      }
    }
  }

  @override
  void didUpdateWidget(RecipeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 새로운 레시피가 전달되면 업데이트
    if (widget.initialRecipes != null && widget.initialRecipes != oldWidget.initialRecipes) {
      debugPrint('🔄 [RecipeScreen] 새로운 AI 레시피 업데이트: ${widget.initialRecipes!.length}개');
      setState(() {
        _recipes = widget.initialRecipes!;
        // 선택된 메뉴 인덱스가 범위를 벗어나면 0으로 초기화
        if (_selectedMenuIndex >= _recipes.length) {
          _selectedMenuIndex = 0;
        }
      });
    }
  }

  /// 사용자 닉네임을 API에서 가져옵니다.
  Future<void> _loadUserNickname() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('⚠️ [RecipeScreen] 로그인된 사용자가 없습니다.');
        return;
      }

      String? nickname;

      // 1) 먼저 register_member API에서 닉네임 가져오기 (건강정보가 없어도 회원 정보는 있음)
      try {
        final memberInfo = await MemberApiService.instance.registerMember(
          user.uid,
          email: user.email,
        );
        debugPrint('🔍 [RecipeScreen] register_member 응답: $memberInfo');

        nickname = memberInfo['nickname'] as String?;
        debugPrint('✅ [RecipeScreen] register_member에서 닉네임: $nickname');
      } catch (e) {
        debugPrint('⚠️ [RecipeScreen] register_member 호출 실패: $e');
      }

      // 2) 회원 정보에서 닉네임을 못 가져왔으면 건강정보에서 시도
      if (nickname == null || nickname.isEmpty) {
        try {
          final healthInfo = await MemberApiService.instance.getHealthInfo(user.uid);
          debugPrint('🔍 [RecipeScreen] 건강 정보 API 응답: $healthInfo');

          // nickname 필드 확인 (다양한 가능한 필드명 체크)
          nickname =
              healthInfo['nickname'] as String? ??
              healthInfo['user_nickname'] as String? ??
              healthInfo['name'] as String?;

          debugPrint('🔍 [RecipeScreen] 건강정보에서 추출된 닉네임: $nickname');
        } catch (e) {
          debugPrint('⚠️ [RecipeScreen] 건강 정보 로드 실패 (건강정보 없음): $e');
        }
      }

      if (mounted) {
        setState(() {
          _userName = nickname?.isNotEmpty == true ? nickname! : '사용자';
        });
      }

      debugPrint('✅ [RecipeScreen] 최종 사용자 닉네임: $_userName');
    } catch (e) {
      debugPrint('⚠️ [RecipeScreen] 사용자 닉네임 로드 실패 (기본값 사용): $e');
      // 기본값 '사용자'는 이미 설정되어 있음
    }
  }

  // 레시피 데이터 생성 함수 (static으로 분리)
  static List<RecipeData> _getRecipes() {
    // 모드 이름 정규화 함수
    String normalizeMode(String mode) {
      String normalized = mode.replaceAll(RegExp(r'\s+'), '');
      final modeMap = {
        '에어프라이어': '에어 프라이',
        '에어프라이': '에어 프라이',
        '스팀전자레인지': '스팀 전자레인지',
        '전자레인지': '전자레인지',
        '오븐': '오븐',
        '해동': '해동',
        '에어수비드': '에어수비드',
        '광파오븐': '전자레인지',
      };
      if (modeMap.containsKey(normalized)) {
        return modeMap[normalized]!;
      }
      for (final entry in modeMap.entries) {
        if (normalized.contains(entry.key) || entry.key.contains(normalized)) {
          return entry.value;
        }
      }
      return mode;
    }

    // 스마트 파싱 로직 (Fake AI) - 정규표현식으로 조리법에서 오븐 설정 추출
    OvenSettings? parseOvenSettings(List<String> steps) {
      String fullText = steps.join(" ");
      final modeReg = RegExp(r'(전자레인지|오븐|에어프라이어?|해동|스팀\s*전자레인지|에어수비드|광파오븐)');
      final modeMatches = modeReg.allMatches(fullText);

      for (final modeMatch in modeMatches) {
        final mode = modeMatch.group(0)!;
        final modeStart = modeMatch.start;
        final searchStart = (modeStart - 20).clamp(0, fullText.length);
        final searchEnd = (modeStart + 100).clamp(0, fullText.length);
        final contextText = fullText.substring(searchStart, searchEnd);

        final tempReg = RegExp(r'(\d{1,3})(도|℃)');
        final tempMatch = tempReg.firstMatch(contextText);

        String? timeStr;
        if (tempMatch != null) {
          final tempEnd = tempMatch.end;
          final timeContext = contextText.substring(tempEnd);
          final timeReg = RegExp(r'(\d{1,3})분');
          final timeMatch = timeReg.firstMatch(timeContext);
          if (timeMatch != null) {
            timeStr = timeMatch.group(0);
          }
        } else {
          final timeReg = RegExp(r'(\d{1,3})분');
          final timeMatch = timeReg.firstMatch(contextText);
          if (timeMatch != null) {
            timeStr = timeMatch.group(0);
          }
        }

        if (timeStr != null) {
          String normalizedMode = normalizeMode(mode);
          return OvenSettings(
            mode: normalizedMode,
            temperature: tempMatch?.group(0) ?? '0도',
            time: timeStr,
          );
        }
      }
      return null;
    }

    return [
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
        ovenSettings: parseOvenSettings([
          '1. 닭봉을 깨끗이 씻어 물기를 제거합니다.',
          '2. 간장, 올리브오일, 다진 마늘, 생강을 섞어 양념장을 만듭니다.',
          '3. 닭봉에 양념장을 발라 30분간 재워둡니다.',
          '4. 예열된 오븐에 180도에서 20분간 구워줍니다.',
          '5. 뒤집어서 10분 더 구워 완성합니다.',
        ]),
        calories: 350,
        tags: ['단백질', '비타민'],
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
        ovenSettings: parseOvenSettings([
          '1. 물에 다시마를 넣고 끓여 육수를 만듭니다.',
          '2. 메밀면을 끓는 물에 넣어 3분간 삶습니다.',
          '3. 찬물에 헹궈 식힙니다.',
          '4. 간장과 설탕을 섞어 양념장을 만듭니다.',
          '5. 면에 양념장을 넣고 곁들여 완성합니다.',
        ]),
        calories: 400,
        tags: ['단백질', '미네랄'],
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
        ovenSettings: parseOvenSettings([
          '1. 마른 미역을 찬물에 불려 부드럽게 만듭니다.',
          '2. 소고기를 잘게 썰어 참기름에 볶습니다.',
          '3. 물을 넣고 끓기 시작하면 미역을 넣습니다.',
          '4. 간장으로 간을 맞추고 10분간 끓입니다.',
          '5. 완성합니다.',
        ]),
        calories: 150,
        tags: ['철분', '칼슘'],
      ),
    ];
  }

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

  // TODO: [API] 오븐 화면으로 이동하는 기능 (필요시 사용)
  // void _navigateToOven() {
  //   final selectedRecipe = _recipes[_selectedMenuIndex];
  //   if (selectedRecipe.isOvenAvailable) {
  //     Navigator.push(
  //       context,
  //       MaterialPageRoute(
  //         builder: (context) => OvenScreen(
  //           recipeName: selectedRecipe.fullTitle,
  //           ovenMode: selectedRecipe.ovenMode ?? '구이',
  //           ovenTimeMinutes: selectedRecipe.ovenTimeMinutes ?? 20,
  //         ),
  //       ),
  //     );
  //   }
  // }

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
            fontWeight: FontWeight.w700,
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // 닉네임 길이에 따라 폰트 크기 동적 조정
                  final nameLength = _userName.length;
                  double fontSize = 20;

                  // 닉네임이 길면 폰트 크기 조정
                  if (nameLength > 8) {
                    fontSize = 18;
                  }
                  if (nameLength > 12) {
                    fontSize = 16;
                  }
                  if (nameLength > 16) {
                    fontSize = 14;
                  }

                  return Text(
                    _getRecommendationMessage(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ColorPalette.text100,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                      height: 1.5,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            // 메뉴 선택 탭
            Row(
              children: List.generate(_recipes.length, (index) {
                final recipe = _recipes[index];
                final isSelected = index == _selectedMenuIndex;
                return Expanded(
                  child: Bounceable(
                    onTap: () {},
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
            // 칼로리 및 영양소 태그 섹션
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    '${selectedRecipe.calories} kcal',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                      color: Color(0xFF49454F),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: selectedRecipe.tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFF49454F).withOpacity(0.5),
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                          color: Color(0xFF49454F),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
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
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '💡',
                    style: TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      selectedRecipe.tip,
                      textAlign: TextAlign.center,
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
            ),
            const SizedBox(height: 32),
            // 광파오븐 버튼 (파싱된 오븐 설정이 있을 때만 표시)
            if (selectedRecipe.ovenSettings != null) ...[
              const Center(
                child: Text(
                  '광파오븐으로 레시피를 보낼까요?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ColorPalette.text100,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Bounceable(
                  onTap: () {},
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OvenScreen(
                            recipe: selectedRecipe,
                            initialSettings: selectedRecipe.ovenSettings,
                          ),
                        ),
                      );
                    },
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
