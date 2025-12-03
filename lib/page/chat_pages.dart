import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/color_palette.dart';
import '../service/storage_service.dart';
import '../repository/image_repository.dart';
import '../model/image_model.dart';
import '../api/can_eat_api.dart';

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
  bool _isLoading = false;

  // 임산부 음식 섭취 가능 여부 확인 관련 상태
  CanEatResponse? _lastCanEatResult;
  bool _isCheckingCanEat = false;

  @override
  void initState() {
    super.initState();
    // 홈 화면에서 전달받은 초기 메시지 추가
    if (widget.initialText != null || widget.initialImagePath != null) {
      _messages.add(
        ChatMessage(
          isUser: true,
          text: widget.initialText ?? '',
          imagePath: widget.initialImagePath,
        ),
      );

      // 초기 이미지가 있으면 업로드
      if (widget.initialImagePath != null) {
        _uploadImage(File(widget.initialImagePath!));
      }

      // AI 응답 시뮬레이션
      _simulateAIResponse();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _canEatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _simulateAIResponse() async {
    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      setState(() {
        _messages.add(
          ChatMessage(
            isUser: false,
            text: '네. 현재 임신 N주차인 김레제님에게 해당 음식은 먹어도 됩니다!',
          ),
        );
        _isLoading = false;
      });

      // 스크롤을 맨 아래로
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

          _simulateAIResponse();
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

    setState(() {
      _isCheckingCanEat = true;
      _lastCanEatResult = null;
    });

    final result = await fetchCanEatResult(text);
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

    _simulateAIResponse();

    // 스크롤을 맨 아래로
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
