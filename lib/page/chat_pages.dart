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
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = false;

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

      // 초기 텍스트에 대한 AI 응답
      if (widget.initialText != null && widget.initialText!.isNotEmpty) {
        _fetchCanEatResponse(widget.initialText!);
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// AI 연결 전 고정 답변을 반환합니다.
  String _getDefaultResponse(String query) {
    // 사용자 입력을 기반으로 간단한 키워드 매칭
    final lowerQuery = query.toLowerCase();

    if (lowerQuery.contains('연어') || lowerQuery.contains('생선') || lowerQuery.contains('회')) {
      return '연어와 생선류에 대한 안내\n\n임신 중에는 생선을 섭취할 때 주의가 필요해요. 연어는 오메가-3가 풍부해 좋지만, 생선회나 날생선은 식중독 위험이 있어 피하는 것이 좋습니다. 완전히 익힌 생선은 안전하게 드실 수 있어요. 다만, 상어, 황새치, 참치 등 수은 함량이 높은 생선은 주의가 필요합니다.';
    } else if (lowerQuery.contains('커피') || lowerQuery.contains('카페인')) {
      return '커피와 카페인에 대한 안내\n\n임신 중 카페인은 하루 200mg 이하로 제한하는 것이 좋아요. 이는 일반적인 커피 1~2잔 정도에 해당합니다. 과도한 카페인 섭취는 저체중 출산이나 조산 위험을 높일 수 있으니 적당히 드시는 것이 좋습니다.';
    } else if (lowerQuery.contains('술') || lowerQuery.contains('알코올') || lowerQuery.contains('와인')) {
      return '알코올 섭취에 대한 안내\n\n임신 중에는 어떤 양의 알코올도 안전하지 않습니다. 알코올은 태아의 발달에 영향을 줄 수 있어 완전히 피하는 것이 가장 좋아요. 술, 와인, 맥주 등 모든 알코올 음료는 임신 기간 동안 금지됩니다.';
    } else if (lowerQuery.contains('치즈') || lowerQuery.contains('우유') || lowerQuery.contains('유제품')) {
      return '유제품 섭취에 대한 안내\n\n우유와 일반 치즈는 안전하게 드실 수 있어요. 다만, 생우유나 비살균 유제품, 부드러운 치즈(브리, 카망베르 등)는 리스테리아 감염 위험이 있어 피하는 것이 좋습니다. 완전히 익힌 치즈나 살균 처리된 유제품은 안전하게 드실 수 있어요.';
    } else if (lowerQuery.contains('날') || lowerQuery.contains('회') || lowerQuery.contains('생')) {
      return '날음식 섭취에 대한 안내\n\n임신 중에는 날음식이나 덜 익힌 음식을 피하는 것이 좋아요. 생선회, 육회, 날계란 등은 식중독이나 기생충 감염 위험이 있습니다. 모든 음식은 완전히 익혀서 드시는 것이 가장 안전합니다.';
    } else {
      // 일반적인 안내 메시지
      return '임산부 음식 섭취 안내\n\n임신 중에는 균형 잡힌 식단이 중요해요. 신선한 채소와 과일, 완전히 익힌 단백질(닭고기, 생선, 계란), 통곡물을 중심으로 드시는 것이 좋습니다. 생음식, 날음식, 비살균 유제품, 과도한 카페인, 알코올은 피하는 것이 좋아요. 구체적인 음식에 대한 질문이 있으시면 언제든 물어보세요!';
    }
  }

  Future<void> _fetchCanEatResponse(String query) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 3초 타임아웃 설정 - 연결이 안 되면 빠르게 고정 답변으로 전환
      final result = await fetchCanEatResult(query).timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          // 타임아웃 시 에러 응답 반환
          return CanEatResponse(
            status: 'error',
            headline: '분석에 실패했어요.',
            reason: '네트워크 상태를 확인하거나, 잠시 후 다시 시도해주세요.',
            targetType: '',
            itemName: '',
          );
        },
      );

      if (!mounted) return;

      // API가 연결되지 않았거나 에러가 발생한 경우 고정 답변 사용
      if (result.status == 'error') {
        final defaultResponse = _getDefaultResponse(query);
        setState(() {
          _messages.add(
            ChatMessage(
              isUser: false,
              text: defaultResponse,
            ),
          );
          _isLoading = false;
        });
      } else {
        // 정상 응답인 경우 headline과 reason을 합쳐서 AI 응답 메시지로 추가
        final responseText = '${result.headline}\n\n${result.reason}';
        setState(() {
          _messages.add(
            ChatMessage(
              isUser: false,
              text: responseText,
            ),
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      // 예외 발생 시에도 고정 답변 사용
      final defaultResponse = _getDefaultResponse(query);
      setState(() {
        _messages.add(
          ChatMessage(
            isUser: false,
            text: defaultResponse,
          ),
        );
        _isLoading = false;
      });
    }

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

          // 이미지에 대한 AI 응답은 기존 시뮬레이션 유지 (이미지 분석은 별도 API 필요)
          _fetchCanEatResponse('이미지 분석');
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

  void _handleSendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    if (_isLoading) return; // 로딩 중에는 중복 요청 방지

    // 사용자 메시지 추가
    setState(() {
      _messages.add(
        ChatMessage(
          isUser: true,
          text: text,
        ),
      );
      _textController.clear();
    });

    // can-eat API 호출
    _fetchCanEatResponse(text);

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
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 80, 24, 16),
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
                          onTap: _isLoading ? null : _handleSendMessage,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 45,
                            height: 45,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isLoading ? ColorPalette.primary100.withOpacity(0.5) : ColorPalette.primary100,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(ColorPalette.text100),
                                    ),
                                  )
                                : const Icon(
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
