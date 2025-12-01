import 'package:flutter/material.dart';
import '../theme/color_palette.dart';

enum _OvenMode {
  grilling, // 구이
  oven, // 오븐
  hotAir, // 열풍
  steam, // 스팀
  microwave, // 전자레인지
  combination, // 복합
}

class OvenScreen extends StatefulWidget {
  final String recipeName;
  final String ovenMode;
  final int ovenTimeMinutes;

  const OvenScreen({
    super.key,
    required this.recipeName,
    required this.ovenMode,
    required this.ovenTimeMinutes,
  });

  @override
  State<OvenScreen> createState() => _OvenScreenState();
}

class _OvenScreenState extends State<OvenScreen> {
  bool _isSent = false;
  int _minutes = 20;
  int _seconds = 0;

  // [API] 실제 IoT 기기 연동 시, 이 값을 디바이스 전송 패킷으로 변환 필요
  _OvenMode _currentMode = _OvenMode.grilling;

  @override
  void initState() {
    super.initState();
    // recipe_pages에서 받은 데이터로 초기화
    _minutes = widget.ovenTimeMinutes;
    _currentMode = _parseMode(widget.ovenMode);
  }

  _OvenMode _parseMode(String mode) {
    switch (mode) {
      case '구이':
        return _OvenMode.grilling;
      case '오븐':
        return _OvenMode.oven;
      case '열풍':
        return _OvenMode.hotAir;
      case '스팀':
        return _OvenMode.steam;
      case '전자레인지':
        return _OvenMode.microwave;
      case '복합':
        return _OvenMode.combination;
      default:
        return _OvenMode.grilling;
    }
  }

  String _getModeText(_OvenMode mode) {
    switch (mode) {
      case _OvenMode.grilling:
        return '구이';
      case _OvenMode.oven:
        return '오븐';
      case _OvenMode.hotAir:
        return '열풍';
      case _OvenMode.steam:
        return '스팀';
      case _OvenMode.microwave:
        return '전자레인지';
      case _OvenMode.combination:
        return '복합';
    }
  }

  void _cycleMode() {
    setState(() {
      switch (_currentMode) {
        case _OvenMode.grilling:
          _currentMode = _OvenMode.oven;
          break;
        case _OvenMode.oven:
          _currentMode = _OvenMode.hotAir;
          break;
        case _OvenMode.hotAir:
          _currentMode = _OvenMode.steam;
          break;
        case _OvenMode.steam:
          _currentMode = _OvenMode.microwave;
          break;
        case _OvenMode.microwave:
          _currentMode = _OvenMode.combination;
          break;
        case _OvenMode.combination:
          _currentMode = _OvenMode.grilling;
          break;
      }
    });
  }

  void _adjustTime(bool isMinutes, bool increase) {
    setState(() {
      if (isMinutes) {
        _minutes = (_minutes + (increase ? 1 : -1)).clamp(0, 99);
      } else {
        _seconds = (_seconds + (increase ? 1 : -1)).clamp(0, 59);
      }
    });
  }

  void _sendToOven() {
    // [API] 실제 IoT 기기 연동 시, 이 값을 디바이스 전송 패킷으로 변환 필요
    print('오븐으로 전송 명령 보냄: ${_getModeText(_currentMode)}, ${_minutes}분 ${_seconds}초');
    setState(() {
      _isSent = true;
    });
  }

  void _cancelSend() {
    setState(() {
      _isSent = false;
    });
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
            fontSize: 36,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                // 조리 모드 선택
                Row(
                  children: [
                    TextButton(
                      onPressed: _cycleMode,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(80, 40),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getModeText(_currentMode),
                            style: const TextStyle(
                              color: ColorPalette.text100,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: ColorPalette.text100,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // 요리 시간 섹션
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ColorPalette.bg100,
                    border: Border.all(color: ColorPalette.bg300),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '요리 시간',
                        style: TextStyle(
                          color: ColorPalette.text100,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 분 선택
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: ColorPalette.bg100,
                          border: Border.all(color: const Color(0xFFE8E8E8)),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () => _adjustTime(true, false),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  '${(_minutes - 1).clamp(0, 99)}',
                                  style: const TextStyle(
                                    color: ColorPalette.text100,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              '$_minutes',
                              style: const TextStyle(
                                color: Color(0xFF000000),
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '분',
                              style: TextStyle(
                                color: Color(0xFF000000),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: () => _adjustTime(true, true),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  '${(_minutes + 1).clamp(0, 99)}',
                                  style: const TextStyle(
                                    color: ColorPalette.text100,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 초 선택
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: ColorPalette.bg100,
                          border: Border.all(color: const Color(0xFFE8E8E8)),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () => _adjustTime(false, false),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  '${(_seconds - 1).clamp(0, 59)}',
                                  style: const TextStyle(
                                    color: ColorPalette.text100,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              '$_seconds',
                              style: const TextStyle(
                                color: Color(0xFF000000),
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '초',
                              style: TextStyle(
                                color: Color(0xFF000000),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: () => _adjustTime(false, true),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  '${(_seconds + 1).clamp(0, 59)}',
                                  style: const TextStyle(
                                    color: ColorPalette.text100,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // 레시피 이름
                Text(
                  widget.recipeName,
                  style: const TextStyle(
                    color: Color(0xFF0F0F0F),
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                // 오븐에 전송 버튼
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSent ? null : _sendToOven,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF585555),
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
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
          // 전송 완료 오버레이
          if (_isSent)
            Positioned.fill(
              child: Container(
                color: ColorPalette.bg100.withOpacity(0.95),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 그라데이션 원형 배경
                    Container(
                      width: 258,
                      height: 258,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            ColorPalette.gradientGreen.withOpacity(0.5),
                            ColorPalette.gradientGreenMid.withOpacity(0.5),
                            ColorPalette.primary100.withOpacity(0.5),
                          ],
                        ),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '전송 완료',
                              style: TextStyle(
                                color: ColorPalette.text100,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '오븐에서 \'시작\' 버튼을 누르세요.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: ColorPalette.text100,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 80),
                    // 레시피 이름
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              widget.recipeName,
                              style: const TextStyle(
                                color: ColorPalette.text100,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                                height: 1.5,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            color: Color(0xFF0F0F0F),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    // 전송 취소 버튼
                    SizedBox(
                      width: 135,
                      child: FilledButton(
                        onPressed: _cancelSend,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF585555),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(33),
                          ),
                        ),
                        child: const Text(
                          '전송 취소',
                          style: TextStyle(
                            color: ColorPalette.bg100,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
