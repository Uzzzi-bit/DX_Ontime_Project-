import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../theme/color_palette.dart';
import 'recipe_pages.dart'; // OvenSettings import를 위해

class OvenScreen extends StatefulWidget {
  final RecipeData? recipe; // Recipe 객체 (선택적)
  final OvenSettings? initialSettings; // 초기 오븐 설정 (선택적)

  const OvenScreen({
    super.key,
    this.recipe,
    this.initialSettings,
  });

  @override
  State<OvenScreen> createState() => _OvenScreenState();
}

class _OvenScreenState extends State<OvenScreen> {
  // 모드 목록 (Figma 디자인 기준)
  final List<String> _modeList = [
    '전자레인지',
    '오븐',
    '에어 프라이',
    '해동',
    '스팀 전자레인지',
    '에어수비드',
  ];

  String _selectedMode = '전자레인지';
  int _minutes = 1;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    // 초기 설정값 적용
    if (widget.initialSettings != null) {
      _selectedMode = widget.initialSettings!.mode;
      // 시간 파싱 (예: "20분" 또는 "1분 30초" 형식 처리)
      _parseTime(widget.initialSettings!.time);
    } else if (widget.recipe?.ovenSettings != null) {
      _selectedMode = widget.recipe!.ovenSettings!.mode;
      _parseTime(widget.recipe!.ovenSettings!.time);
    }
  }

  // 시간 파싱 함수: "20분" 또는 "1분 30초" 형식 처리
  void _parseTime(String timeString) {
    // "1분 30초" 형식 처리
    final fullTimeMatch = RegExp(r'(\d+)분\s*(\d+)초').firstMatch(timeString);
    if (fullTimeMatch != null) {
      _minutes = int.tryParse(fullTimeMatch.group(1) ?? '0') ?? 0;
      _seconds = int.tryParse(fullTimeMatch.group(2) ?? '0') ?? 0;
      return;
    }

    // "20분" 형식 처리
    final minutesMatch = RegExp(r'(\d+)분').firstMatch(timeString);
    if (minutesMatch != null) {
      _minutes = int.tryParse(minutesMatch.group(1) ?? '1') ?? 1;
      _seconds = 0;
      return;
    }

    // "30초" 형식 처리
    final secondsMatch = RegExp(r'(\d+)초').firstMatch(timeString);
    if (secondsMatch != null) {
      _minutes = 0;
      _seconds = int.tryParse(secondsMatch.group(1) ?? '0') ?? 0;
      return;
    }

    // 기본값
    _minutes = 1;
    _seconds = 0;
  }

  void _showTimePicker() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _TimePickerDialog(
          initialMinutes: _minutes,
          initialSeconds: _seconds,
          onTimeSelected: (int minutes, int seconds) {
            setState(() {
              _minutes = minutes;
              _seconds = seconds;
            });
          },
        );
      },
    );
  }

  void _sendToOven() {
    // [API] 실제 IoT 기기 연동 시, 이 값을 디바이스 전송 패킷으로 변환 필요
    String? temperature;
    if (widget.initialSettings != null) {
      temperature = widget.initialSettings!.temperature;
    } else if (widget.recipe?.ovenSettings != null) {
      temperature = widget.recipe!.ovenSettings!.temperature;
    }

    print('오븐으로 전송: 모드=$_selectedMode, 온도=$temperature, 시간=${_minutes}분 ${_seconds}초');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$_selectedMode 모드로 ${_minutes}분 ${_seconds}초 설정을 전송했습니다!'),
        duration: const Duration(seconds: 2),
      ),
    );

    // 페이지 닫기
    Navigator.pop(context);
  }

  String _getRecipeName() {
    if (widget.recipe != null) {
      return widget.recipe!.fullTitle;
    }
    return '레시피';
  }

  @override
  Widget build(BuildContext context) {
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
          '광파오븐',
          style: TextStyle(
            color: ColorPalette.text100,
            fontSize: 24,
            fontWeight: FontWeight.w900,
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
            // 오븐 이미지 (모드 선택 위에 표시)
            Center(
              child: Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Image.asset(
                    'assets/image/oven2.png',
                    width: 104,
                    height: 104,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: const Color(0xFFECE6F0),
                        child: const Icon(
                          Icons.microwave,
                          size: 48,
                          color: ColorPalette.text100,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 현재 선택된 모드 텍스트
            Text(
              _selectedMode,
              style: const TextStyle(
                color: ColorPalette.text100,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),
            // 모드 선택 Chip 그룹 (가로 스크롤)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ..._modeList.map((mode) {
                    final isSelected = mode == _selectedMode;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedMode = mode;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? ColorPalette.primary100 : Colors.transparent,
                            border: Border.all(
                              color: ColorPalette.primary100,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              mode,
                              style: TextStyle(
                                color: isSelected ? const Color(0xFF0F0F0F) : const Color(0xFF49454F),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  // 편집 Chip
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: ColorPalette.primary100,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit,
                            size: 18,
                            color: Color(0xFF49454F),
                          ),
                          SizedBox(width: 4),
                          Text(
                            '편집',
                            style: TextStyle(
                              color: Color(0xFF49454F),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // 요리 시간 영역
            GestureDetector(
              onTap: _showTimePicker,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: ColorPalette.bg200,
                  border: Border.all(color: const Color(0xFFE8E8E8)),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Column(
                  children: [
                    // 모래시계 아이콘
                    Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Image.asset(
                          'assets/image/hourglass.png',
                          width: 104,
                          height: 104,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.access_time,
                              size: 48,
                              color: ColorPalette.text100,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '요리 시간',
                      style: TextStyle(
                        color: ColorPalette.text100,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$_minutes분 $_seconds초',
                      style: const TextStyle(
                        color: ColorPalette.text100,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            // 레시피 이름
            Text(
              _getRecipeName(),
              style: const TextStyle(
                color: ColorPalette.text100,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 32),
            // 오븐에 전송 버튼
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _sendToOven,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF5BB5C8),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(33),
                  ),
                ),
                child: const Text(
                  '오븐에 전송',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

// 시간 선택 팝업 다이얼로그
class _TimePickerDialog extends StatefulWidget {
  final int initialMinutes;
  final int initialSeconds;
  final Function(int minutes, int seconds) onTimeSelected;

  const _TimePickerDialog({
    required this.initialMinutes,
    required this.initialSeconds,
    required this.onTimeSelected,
  });

  @override
  State<_TimePickerDialog> createState() => _TimePickerDialogState();
}

class _TimePickerDialogState extends State<_TimePickerDialog> {
  late FixedExtentScrollController _minutesController;
  late FixedExtentScrollController _secondsController;
  late int _selectedMinutes;
  late int _selectedSeconds;

  @override
  void initState() {
    super.initState();
    _selectedMinutes = widget.initialMinutes;
    _selectedSeconds = widget.initialSeconds;
    _minutesController = FixedExtentScrollController(initialItem: _selectedMinutes);
    _secondsController = FixedExtentScrollController(initialItem: _selectedSeconds);
  }

  @override
  void dispose() {
    _minutesController.dispose();
    _secondsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '요리 시간 설정',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: ColorPalette.text100,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 분 선택
                SizedBox(
                  width: 100,
                  height: 200,
                  child: CupertinoPicker(
                    scrollController: _minutesController,
                    itemExtent: 40,
                    onSelectedItemChanged: (int index) {
                      setState(() {
                        _selectedMinutes = index;
                      });
                    },
                    children: List<Widget>.generate(60, (int index) {
                      return Center(
                        child: Text(
                          '$index',
                          style: const TextStyle(
                            fontSize: 24,
                            color: ColorPalette.text100,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const Text(
                  '분',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: ColorPalette.text100,
                  ),
                ),
                const SizedBox(width: 32),
                // 초 선택
                SizedBox(
                  width: 100,
                  height: 200,
                  child: CupertinoPicker(
                    scrollController: _secondsController,
                    itemExtent: 40,
                    onSelectedItemChanged: (int index) {
                      setState(() {
                        _selectedSeconds = index;
                      });
                    },
                    children: List<Widget>.generate(60, (int index) {
                      return Center(
                        child: Text(
                          '$index',
                          style: const TextStyle(
                            fontSize: 24,
                            color: ColorPalette.text100,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const Text(
                  '초',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: ColorPalette.text100,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    '취소',
                    style: TextStyle(
                      color: ColorPalette.text200,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton(
                  onPressed: () {
                    widget.onTimeSelected(_selectedMinutes, _selectedSeconds);
                    Navigator.pop(context);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF5BB5C8),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '확인',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
