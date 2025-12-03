import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/color_palette.dart';
import '../service/storage_service.dart';
import '../repository/image_repository.dart';
import '../model/image_model.dart';
import '../api/can_eat_api.dart';
import '../api/ai_chat_api.dart';
import '../api/member_api_service.dart';

class ChatMessage {
  final bool isUser;
  final String text;
  final String? imagePath;
  final DateTime timestamp;

  ChatMessage({
    required this.isUser,
    required this.text,
    this.imagePath,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class ChatScreen extends StatefulWidget {
  final String? initialText;
  final String? initialImagePath;

  const ChatScreen({
    super.key,
    this.initialText,
    this.initialImagePath,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _canEatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final ImagePicker _imagePicker = ImagePicker();
  final AiChatApiService _chatApiService = AiChatApiService();
  final MemberApiService _memberApiService = MemberApiService.instance;
  bool _isLoading = false;
  bool _isInitialized = false;

  // 사용자 정보
  String? _userNickname;
  int? _currentPregWeek;
  String? _conditions;
  String? _allergies;
  bool _hasGestationalDiabetes = false;

  // 임산부 음식 섭취 가능 여부 확인 관련 상태
  CanEatResponse? _lastCanEatResult;
  bool _isCheckingCanEat = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();

    // 홈 화면에서 전달받은 초기 메시지 추가
    if (widget.initialText != null || widget.initialImagePath != null) {
      _messages.add(
        ChatMessage(
          isUser: true,
          text: widget.initialText ?? '',
          imagePath: widget.initialImagePath,
        ),
      );

      // 초기 이미지가 있으면 업로드 및 AI 분석
      if (widget.initialImagePath != null) {
        _uploadImage(File(widget.initialImagePath!));
        _sendImageToAI(File(widget.initialImagePath!));
      } else if (widget.initialText != null && widget.initialText!.isNotEmpty) {
        _sendMessageToAI(widget.initialText!);
      }
    }
  }

  /// 임신 주차 자동 계산 (dueDate 기반)
  /// dueDate로부터 현재 날짜까지의 주차를 자동으로 계산
  /// 1주일이 지나면 자동으로 +1 증가
  int _calculatePregWeek(DateTime? dueDate) {
    if (dueDate == null) return 0;

    final now = DateTime.now();
    // 임신 기간은 보통 280일 (40주)
    // 임신 시작일 = dueDate - 280일
    final pregnancyStartDate = dueDate.subtract(const Duration(days: 280));

    // 현재 날짜와 임신 시작일의 차이를 주차로 계산
    final daysSinceStart = now.difference(pregnancyStartDate).inDays;
    final currentWeek = (daysSinceStart ~/ 7) + 1; // 1주차부터 시작

    return currentWeek.clamp(1, 40);
  }

  /// 채팅 초기화 (사용자 정보 로드)
  Future<void> _initializeChat() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('사용자가 로그인하지 않았습니다.');
        _userNickname = '사용자';
        _currentPregWeek = 12;
        _isInitialized = true;
        return;
      }

      // 사용자 정보 가져오기
      try {
        // 건강 정보 가져오기 (dueDate, pregWeek, allergies 등)
        final healthInfo = await _memberApiService.getHealthInfo(user.uid);

        _userNickname = healthInfo['nickname']?.toString() ?? '사용자';

        final dueDateStr = healthInfo['dueDate'];
        DateTime? dueDate;

        if (dueDateStr != null) {
          dueDate = DateTime.tryParse(dueDateStr.toString());
        }

        // 주차 자동 계산 (dueDate 기반)
        if (dueDate != null) {
          _currentPregWeek = _calculatePregWeek(dueDate);
        } else {
          // dueDate가 없으면 저장된 pregWeek 사용
          _currentPregWeek = healthInfo['pregWeek'] as int? ?? 12;
        }

        // 알레르기 정보
        if (healthInfo['allergies'] is List) {
          _allergies = (healthInfo['allergies'] as List).join(', ');
        } else if (healthInfo['allergies'] is String) {
          _allergies = healthInfo['allergies'] as String;
        }

        // 임신성 당뇨
        _hasGestationalDiabetes = healthInfo['hasGestationalDiabetes'] ?? false;

        // 진단/질환 정보
        _conditions = _hasGestationalDiabetes ? '임신성 당뇨' : '없음';

        _isInitialized = true;
      } catch (e) {
        debugPrint('사용자 정보 로드 실패: $e');
        // 정보가 없어도 기본값으로 진행
        _userNickname = '사용자';
        _currentPregWeek = 12;
        _conditions = '없음';
        _allergies = '';
        _isInitialized = true;
      }
    } catch (e) {
      debugPrint('채팅 초기화 실패: $e');
      _userNickname = '사용자';
      _currentPregWeek = 12;
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _canEatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 대화 히스토리 생성 (FastAPI에 전달할 형식)
  List<Map<String, String>> _buildChatHistory() {
    final history = <Map<String, String>>[];
    for (final msg in _messages) {
      history.add({
        'role': msg.isUser ? 'user' : 'assistant',
        'content': msg.text,
      });
    }
    return history;
  }

  /// 텍스트 메시지를 AI에게 전송 (FastAPI 사용)
  Future<void> _sendMessageToAI(String message) async {
    if (!_isInitialized) {
      await _initializeChat();
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 대화 히스토리 생성 (현재 메시지 제외)
      final chatHistory = _buildChatHistory();

      final response = await _chatApiService.sendMessage(
        nickname: _userNickname ?? '사용자',
        week: _currentPregWeek ?? 12,
        conditions: _conditions,
        allergies: _allergies,
        hasGestationalDiabetes: _hasGestationalDiabetes,
        userMessage: message,
        chatHistory: chatHistory,
      );

      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              isUser: false,
              text: response,
            ),
          );
          _isLoading = false;
        });

        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('AI 채팅 오류: $e');
      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              isUser: false,
              text: '죄송합니다. 응답을 생성하는 중 오류가 발생했습니다. 다시 시도해주세요.',
            ),
          );
          _isLoading = false;
        });
      }
    }
  }

  /// 이미지를 AI에게 전송하여 분석 (can-eat API 사용)
  Future<void> _sendImageToAI(File imageFile) async {
    if (!_isInitialized) {
      await _initializeChat();
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 이미지는 can-eat API를 사용하여 분석
      // 이미지 설명을 텍스트로 변환 (실제로는 이미지 분석 필요)
      final query = '이 음식이 임신 중에 안전한지 분석해주세요.';

      final canEatResult = await fetchCanEatResult(
        query,
        nickname: _userNickname,
        week: _currentPregWeek,
        conditions: _conditions,
      );

      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              isUser: false,
              text: '${canEatResult.headline}\n\n${canEatResult.reason}',
            ),
          );
          _isLoading = false;
        });

        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('이미지 분석 오류: $e');
      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              isUser: false,
              text: '죄송합니다. 이미지 분석 중 오류가 발생했습니다. 다시 시도해주세요.',
            ),
          );
          _isLoading = false;
        });
      }
    }
  }

  /// 스크롤을 맨 아래로
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleImagePicker() async {
    final result = await showDialog<ImageSource>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('카메라로 촬영'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('앨범에서 선택'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  '취소',
                  style: TextStyle(color: ColorPalette.primary200),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result != null) {
      try {
        final XFile? image = await _imagePicker.pickImage(source: result);
        if (image != null && mounted) {
          final imageFile = File(image.path);
          setState(() {
            _messages.add(
              ChatMessage(
                isUser: true,
                text: '',
                imagePath: image.path,
              ),
            );
          });

          // 이미지 업로드 (백그라운드)
          _uploadImage(imageFile);

          // AI에게 이미지 분석 요청
          _sendImageToAI(imageFile);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('이미지 선택 중 오류가 발생했습니다: $e')),
          );
        }
      }
    }
  }

  /// 이미지를 Firebase Storage에 업로드하고 Firestore에 저장합니다.
  Future<void> _uploadImage(File imageFile) async {
    try {
      final storageService = StorageService();
      final imageRepository = ImageRepository();

      // 1. Firebase Storage에 이미지 업로드
      final imageUrl = await storageService.uploadImage(
        imageFile: imageFile,
        folder: 'chat_images',
      );

      // 2. Firestore에 이미지 정보 저장
      await imageRepository.saveImageWithUrl(
        imageUrl: imageUrl,
        imageType: ImageType.chat,
        source: ImageSourceType.aiChat,
      );

      // TODO: [AI] AI 분석 결과가 나오면 updateIngredientInfo()로 ingredient_info 업데이트
    } catch (e) {
      // 업로드 실패는 조용히 처리 (사용자 경험을 위해)
      debugPrint('이미지 업로드 실패: $e');
    }
  }

  Future<void> _onCheckCanEat() async {
    final text = _canEatController.text.trim();
    if (text.isEmpty) return;

    if (!_isInitialized) {
      await _initializeChat();
    }

    setState(() {
      _isCheckingCanEat = true;
      _lastCanEatResult = null;
    });

    final result = await fetchCanEatResult(
      text,
      nickname: _userNickname,
      week: _currentPregWeek,
      conditions: _conditions,
    );
    if (!mounted) return;

    setState(() {
      _isCheckingCanEat = false;
      _lastCanEatResult = result;
    });
  }

  void _handleSendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty && _messages.isEmpty) return;

    setState(() {
      _messages.add(
        ChatMessage(
          isUser: true,
          text: text,
        ),
      );
      _textController.clear();
    });

    // AI에게 메시지 전송 (사용자 이름은 AI 응답에 포함되도록 컨텍스트로 전달)
    _sendMessageToAI(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/');
          },
          icon: const Icon(Icons.keyboard_backspace, color: ColorPalette.text100),
        ),
        title: const Text(
          '먹어도 되나요?',
          style: TextStyle(
            color: ColorPalette.text100,
            fontSize: 20,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ColorPalette.primary100.withOpacity(0.15),
              ColorPalette.gradientGreenMid.withOpacity(0.12),
              ColorPalette.primary100.withOpacity(0.18),
              ColorPalette.gradientGreen.withOpacity(0.1),
              ColorPalette.primary100.withOpacity(0.15),
            ],
            stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 임산부 음식 섭취 가능 여부 확인 UI
              Container(
                padding: const EdgeInsets.fromLTRB(24, 80, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '이 음식, 먹어도 될까요?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: ColorPalette.text100,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: ColorPalette.bg100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: ColorPalette.bg300),
                            ),
                            child: TextField(
                              controller: _canEatController,
                              decoration: const InputDecoration(
                                hintText: '예: 연어롤 먹어도 돼?',
                                hintStyle: TextStyle(
                                  color: ColorPalette.text300,
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 12),
                              ),
                              style: const TextStyle(
                                fontSize: 14,
                                color: ColorPalette.text100,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isCheckingCanEat ? null : _onCheckCanEat,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColorPalette.primary100,
                            foregroundColor: ColorPalette.text100,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isCheckingCanEat
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(ColorPalette.text100),
                                  ),
                                )
                              : const Text(
                                  '확인',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_lastCanEatResult != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _lastCanEatResult!.headline,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: ColorPalette.text100,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _lastCanEatResult!.reason,
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: ColorPalette.text100,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  itemCount: _messages.length + (_isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length && _isLoading) {
                      return _buildAIMessage('답변을 생성하고 있습니다...', isLoading: true);
                    }
                    return _buildMessage(_messages[index]);
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Bounceable(
                        onTap: () {},
                        child: InkWell(
                          onTap: _handleImagePicker,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: ColorPalette.bg200,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.add,
                              color: ColorPalette.text100,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: ColorPalette.bg100,
                            borderRadius: BorderRadius.circular(27.5),
                            border: Border.all(color: ColorPalette.bg300),
                          ),
                          child: TextField(
                            controller: _textController,
                            decoration: const InputDecoration(
                              hintText: '궁금한 음식/약을 물어보세요',
                              hintStyle: TextStyle(
                                color: ColorPalette.text300,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.5,
                              ),
                              border: InputBorder.none,
                            ),
                            style: const TextStyle(
                              fontSize: 14,
                              color: ColorPalette.text100,
                            ),
                            maxLines: null,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _handleSendMessage(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Bounceable(
                        onTap: () {},
                        child: InkWell(
                          onTap: _handleSendMessage,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 45,
                            height: 45,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: ColorPalette.primary100,
                            ),
                            child: const Icon(
                              Icons.send,
                              color: ColorPalette.text100,
                              size: 20,
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
        ),
      ),
    );
  }

  Widget _buildMessage(ChatMessage message) {
    if (message.isUser) {
      return _buildUserMessage(message);
    } else {
      return _buildAIMessage(message.text);
    }
  }

  Widget _buildUserMessage(ChatMessage message) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 사용자 이름 표시 (있는 경우)
            if (_userNickname != null && (message.text.isNotEmpty || message.imagePath != null))
              Padding(
                padding: const EdgeInsets.only(bottom: 4, right: 8),
                child: Text(
                  _userNickname!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: ColorPalette.text200,
                  ),
                ),
              ),
            if (message.imagePath != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                constraints: const BoxConstraints(maxWidth: 200),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(message.imagePath!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
            if (message.text.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxWidth: 250),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: ColorPalette.bg200,
                  borderRadius: BorderRadius.circular(message.imagePath != null ? 10 : 25),
                ),
                child: Text(
                  message.text,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w300,
                    color: ColorPalette.text100,
                    letterSpacing: 0.5,
                    height: 1.2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIMessage(String text, {bool isLoading = false}) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 33,
              height: 33,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFBCE7F0),
              ),
              child: const Icon(
                Icons.smart_toy,
                color: Color(0xFF0F0F0F),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 280),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                    color: isLoading ? ColorPalette.text300 : ColorPalette.text100,
                    letterSpacing: 0.5,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
