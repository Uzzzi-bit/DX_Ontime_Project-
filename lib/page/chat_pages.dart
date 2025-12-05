import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/color_palette.dart';
import '../service/storage_service.dart';
import '../repository/image_repository.dart';
import '../model/image_model.dart';
import '../api/chat_api.dart';
import '../api/ai_chat_api_service.dart';
import '../api/member_api_service.dart';
import '../api/image_api_service.dart';
import '../utils/responsive_helper.dart';

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
  final FocusNode _textFieldFocusNode = FocusNode();
  final List<ChatMessage> _messages = [];
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = false;
  XFile? _selectedImageFile; // 선택된 이미지 파일 (전송 전까지 보관)

  // DB 저장을 위한 변수들
  String? _currentMemberId;
  int? _currentSessionId;
  String? _lastUploadedImageDocId; // 마지막으로 업로드된 이미지의 Firestore doc ID
  int? _lastUploadedImagePk; // 마지막으로 업로드된 이미지의 Django DB image_pk (IMAGES 테이블의 id)

  // 사용자 정보 (채팅 API 호출용)
  String _userNickname = '사용자';
  int _pregnancyWeek = 12;
  String _conditions = '없음';

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      // Firebase 사용자 정보 가져오기
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('⚠️ [ChatScreen] 로그인된 사용자가 없습니다.');
        return;
      }

      _currentMemberId = user.uid;
      debugPrint('✅ [ChatScreen] 사용자 ID 로드: $_currentMemberId');

      // 사용자 건강 정보 로드 (채팅 API 호출용)
      await _loadUserHealthInfo();

      // 이전 세션 로드 (활성 세션이 있으면 사용, 없으면 가장 최근 종료된 세션 사용)
      await _loadPreviousChat();

      // 세션이 없으면 새로 생성
      if (_currentSessionId == null) {
        await _createSession();
      }

      // 홈 화면에서 전달받은 초기 메시지 추가
      if (widget.initialText != null || widget.initialImagePath != null) {
        final initialMessage = ChatMessage(
          isUser: true,
          text: widget.initialText ?? '',
          imagePath: widget.initialImagePath,
        );

        if (mounted) {
          setState(() {
            _messages.add(initialMessage);
          });
        }

        // 초기 메시지를 DB에 저장
        if (_currentSessionId != null && _currentMemberId != null) {
          await _saveMessageToDb(
            type: 'user',
            content: widget.initialText ?? '',
            imagePath: widget.initialImagePath,
          );
        }

        // 초기 이미지가 있으면 업로드
        if (widget.initialImagePath != null) {
          final imgFile = File(widget.initialImagePath!);
          await _uploadImage(imgFile);

          // 이미지 분석 요청 (await로 기다림)
          await _sendRequestToAI(
            query: '이 음식 먹어도 되나요?',
            imageFile: XFile(widget.initialImagePath!),
          );
        } else if (widget.initialText != null && widget.initialText!.isNotEmpty) {
          // 텍스트만 있는 경우 (await로 기다림)
          await _sendRequestToAI(query: widget.initialText!);
        }
      }
    } catch (e) {
      debugPrint('❌ [ChatScreen] 초기화 실패: $e');
    }
  }

  Future<void> _createSession() async {
    if (_currentMemberId == null) return;

    try {
      debugPrint('🔄 [ChatScreen] 새 세션 생성 중...');
      final result = await AiChatApiService.instance.createSession(_currentMemberId!);
      _currentSessionId = result['session_id'] as int;
      debugPrint('✅ [ChatScreen] 세션 생성 완료: session_id=$_currentSessionId');
    } catch (e) {
      debugPrint('❌ [ChatScreen] 세션 생성 실패: $e');
    }
  }

  Future<void> _loadPreviousChat() async {
    if (_currentMemberId == null) return;

    try {
      debugPrint('🔄 [ChatScreen] 이전 채팅 로드 중...');
      final sessions = await AiChatApiService.instance.listSessions(_currentMemberId!);

      if (sessions.isEmpty) {
        debugPrint('ℹ️ [ChatScreen] 이전 세션이 없습니다.');
        return;
      }

      // 가장 최근 세션 찾기 (활성 세션이 있으면 우선, 없으면 가장 최근 종료된 세션)
      Map<String, dynamic>? activeSession;
      Map<String, dynamic>? latestEndedSession;

      for (final session in sessions) {
        if (session['ended_at'] == null) {
          // 활성 세션이 있으면 우선 사용
          activeSession = session;
          break;
        } else {
          // 종료된 세션 중 가장 최근 것 저장
          if (latestEndedSession == null) {
            latestEndedSession = session;
          }
        }
      }

      // 활성 세션이 있으면 사용, 없으면 가장 최근 종료된 세션 사용
      final targetSession = activeSession ?? latestEndedSession;

      if (targetSession != null) {
        _currentSessionId = targetSession['session_id'] as int;
        final isEnded = targetSession['ended_at'] != null;

        debugPrint('✅ [ChatScreen] 세션 발견: session_id=$_currentSessionId, ended=${isEnded ? "예" : "아니오"}');

        // 종료된 세션이면 재활성화
        if (isEnded) {
          debugPrint('🔄 [ChatScreen] 세션 재활성화 중...');
          await AiChatApiService.instance.reactivateSession(_currentSessionId!);
          debugPrint('✅ [ChatScreen] 세션 재활성화 완료');
        }

        // 세션의 메시지들 로드
        await _loadMessages(_currentSessionId!);
      } else {
        debugPrint('ℹ️ [ChatScreen] 로드할 세션이 없습니다.');
      }
    } catch (e) {
      debugPrint('❌ [ChatScreen] 이전 채팅 로드 실패: $e');
    }
  }

  Future<void> _loadMessages(int sessionId) async {
    try {
      final messages = await AiChatApiService.instance.getMessages(sessionId);
      debugPrint('🔄 [ChatScreen] 전체 메시지 ${messages.length}개 로드됨');

      // 오늘 날짜의 메시지만 필터링
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      final todayMessages = messages.where((msg) {
        final createdAt = DateTime.parse(msg['created_at'] as String);
        return createdAt.isAfter(todayStart) && createdAt.isBefore(todayEnd);
      }).toList();

      debugPrint('🔄 [ChatScreen] 오늘 날짜 메시지 ${todayMessages.length}개 필터링됨');

      // 이미지가 있는 메시지의 image_pk 수집
      final imagePks = todayMessages
          .where((msg) => msg['image_pk'] != null)
          .map((msg) => msg['image_pk'] as int)
          .toSet()
          .toList();

      // 이미지 URL 맵 생성 (image_pk -> image_url)
      Map<int, String> imageUrlMap = {};
      if (imagePks.isNotEmpty && _currentMemberId != null) {
        try {
          // 사용자의 모든 채팅 이미지 가져오기
          final images = await ImageApiService.instance.getImages(
            memberId: _currentMemberId!,
            imageType: 'chat',
          );

          // image_pk로 필터링하여 URL 맵 생성
          for (final img in images) {
            final imgId = img['id'] as int? ?? img['image_id'] as int?;
            final imgUrl = img['image_url'] as String?;
            if (imgId != null && imgUrl != null && imagePks.contains(imgId)) {
              imageUrlMap[imgId] = imgUrl;
            }
          }
          debugPrint('🖼️ [ChatScreen] 이미지 URL 맵 생성: ${imageUrlMap.length}개');
        } catch (e) {
          debugPrint('⚠️ [ChatScreen] 이미지 URL 로드 실패: $e');
        }
      }

      if (mounted) {
        setState(() {
          _messages.clear();
          for (final msg in todayMessages) {
            String? imagePath;
            final imagePk = msg['image_pk'] as int?;

            if (imagePk != null && imageUrlMap.containsKey(imagePk)) {
              imagePath = imageUrlMap[imagePk];
              debugPrint('🖼️ [ChatScreen] 이미지 URL 매핑: image_pk=$imagePk');
            }

            // 이미지가 있는 경우 텍스트는 표시하지 않음 (이미지만 표시)
            final content = msg['content'] as String;
            final finalText = (imagePath != null && content == '이미지') ? '' : content;

            _messages.add(
              ChatMessage(
                isUser: msg['type'] == 'user',
                text: finalText,
                imagePath: imagePath,
                timestamp: DateTime.parse(msg['created_at'] as String),
              ),
            );
          }
        });
      }
    } catch (e) {
      debugPrint('❌ [ChatScreen] 메시지 로드 실패: $e');
    }
  }

  Future<void> _saveMessageToDb({
    required String type,
    required String content,
    String? imagePath,
  }) async {
    if (_currentSessionId == null || _currentMemberId == null) {
      debugPrint('⚠️ [ChatScreen] 세션이나 사용자 ID가 없어 메시지를 저장할 수 없습니다.');
      return;
    }

    try {
      int? imagePk;
      if (imagePath != null) {
        // Django DB에 저장된 이미지 PK 사용
        imagePk = _lastUploadedImagePk;
        if (imagePk == null) {
          debugPrint('⚠️ [ChatScreen] 이미지 PK가 없습니다. 이미지 없이 메시지만 저장합니다.');
        } else {
          debugPrint('✅ [ChatScreen] 이미지 PK 사용: image_pk=$imagePk');
        }
      }

      debugPrint(
        '🔄 [ChatScreen] 메시지 DB 저장 중: type=$type, content=${content.substring(0, content.length > 50 ? 50 : content.length)}..., imagePk=$imagePk',
      );
      await AiChatApiService.instance.saveMessage(
        sessionId: _currentSessionId!,
        memberId: _currentMemberId!,
        type: type,
        content: content,
        imagePk: imagePk,
      );
      debugPrint('✅ [ChatScreen] 메시지 DB 저장 완료');

      // 메시지 저장 후 이미지 PK 초기화 (다음 메시지와 혼동 방지)
      _lastUploadedImagePk = null;
    } catch (e) {
      debugPrint('❌ [ChatScreen] 메시지 DB 저장 실패: $e');
    }
  }

  Future<void> _loadUserHealthInfo() async {
    if (_currentMemberId == null) return;

    try {
      // 먼저 register_member API에서 닉네임 가져오기 (건강정보가 없어도 회원 정보는 있음)
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final memberInfo = await MemberApiService.instance.registerMember(
            user.uid,
            email: user.email,
          );
          _userNickname = memberInfo['nickname'] as String? ?? '사용자';
          debugPrint('✅ [ChatScreen] register_member에서 닉네임: $_userNickname');
        } catch (e) {
          debugPrint('⚠️ [ChatScreen] register_member 호출 실패: $e');
        }
      }

      debugPrint('🔄 [ChatScreen] 사용자 건강 정보 로드 중...');
      try {
        final healthInfo = await MemberApiService.instance.getHealthInfo(_currentMemberId!);

        // 닉네임이 없으면 건강정보에서 가져오기
        if (_userNickname == '사용자' || _userNickname.isEmpty) {
          _userNickname = healthInfo['nickname'] as String? ?? '사용자';
        }
        _pregnancyWeek = healthInfo['pregnancy_week'] as int? ?? healthInfo['pregWeek'] as int? ?? 12;
        _conditions = healthInfo['conditions'] as String? ?? '없음';

        debugPrint('✅ [ChatScreen] 사용자 정보: nickname=$_userNickname, week=$_pregnancyWeek, conditions=$_conditions');
      } catch (e) {
        debugPrint('⚠️ [ChatScreen] 건강 정보 로드 실패 (닉네임은 이미 가져옴): $e');
        // 기본값은 이미 설정되어 있음 (_userNickname = '사용자', _pregnancyWeek = 12, _conditions = '없음')
      }
    } catch (e) {
      debugPrint('⚠️ [ChatScreen] 사용자 정보 로드 실패 (기본값 사용): $e');
    }
  }

  Future<void> _endSession() async {
    if (_currentSessionId == null) return;

    try {
      debugPrint('🔄 [ChatScreen] 세션 종료 중... session_id=$_currentSessionId');
      await AiChatApiService.instance.endSession(_currentSessionId!);
      debugPrint('✅ [ChatScreen] 세션 종료 완료: ended_at 설정됨');
    } catch (e) {
      debugPrint('❌ [ChatScreen] 세션 종료 실패: $e');
    }
  }

  @override
  void dispose() {
    // 키보드 포커스 해제 및 숨기기
    _textFieldFocusNode.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');

    _endSession();
    _textController.dispose();
    _scrollController.dispose();
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  String _getDefaultResponse(String query) {
    final lowerQuery = query.toLowerCase();

    if (lowerQuery.contains('연어') || lowerQuery.contains('생선') || lowerQuery.contains('회')) {
      return '연어와 생선류에 대한 안내\n\n임신 중에는 생선을 섭취할 때 주의가 필요해요. 연어는 오메가-3가 풍부해 좋지만, 생선회나 날생선은 식중독 위험이 있어 피하는 것이 좋습니다. 완전히 익힌 생선은 안전하게 드실 수 있어요.';
    } else if (lowerQuery.contains('커피') || lowerQuery.contains('카페인')) {
      return '커피와 카페인에 대한 안내\n\n임신 중 카페인은 하루 200mg 이하로 제한하는 것이 좋아요. 이는 일반적인 커피 1~2잔 정도에 해당합니다.';
    } else if (lowerQuery.contains('술') || lowerQuery.contains('알코올') || lowerQuery.contains('와인')) {
      return '알코올 섭취에 대한 안내\n\n임신 중에는 어떤 양의 알코올도 안전하지 않습니다. 태아의 발달에 영향을 줄 수 있어 완전히 피하는 것이 가장 좋아요.';
    } else {
      return '임산부 음식 섭취 안내\n\n임신 중에는 균형 잡힌 식단이 중요해요. 신선한 채소와 과일, 완전히 익힌 단백질을 드시는 것이 좋습니다. 구체적인 음식에 대한 질문이 있으시면 언제든 물어보세요!';
    }
  }

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

  /// [핵심 수정] Gemini API를 사용한 채팅 함수
  Future<void> _sendRequestToAI({required String query, XFile? imageFile}) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    // 요청 시작하자마자 스크롤 내려줌 (사용자 경험 향상)
    _scrollToBottom();

    try {
      // 이미지 파일 확인 및 로그
      if (imageFile != null) {
        debugPrint('🖼️ [ChatScreen] 이미지 파일 전달: path=${imageFile.path}, name=${imageFile.name}');
        final fileExists = await File(imageFile.path).exists();
        debugPrint('🖼️ [ChatScreen] 이미지 파일 존재 여부: $fileExists');
        if (!fileExists) {
          throw Exception('이미지 파일을 찾을 수 없습니다: ${imageFile.path}');
        }
      } else {
        debugPrint('📝 [ChatScreen] 텍스트만 전송 (이미지 없음)');
      }

      debugPrint('🔄 [ChatScreen] AI 요청 시작: query=$query, nickname=$_userNickname, week=$_pregnancyWeek');

      // Gemini API를 사용한 채팅 API 호출 (이미지 포함)
      final result = await fetchChatResponse(
        userMessage: query,
        nickname: _userNickname,
        week: _pregnancyWeek,
        conditions: _conditions,
        imageFile: imageFile, // 이미지 파일 전달
      );

      debugPrint(
        '✅ [ChatScreen] AI 응답 받음: ${result.message.substring(0, result.message.length > 50 ? 50 : result.message.length)}...',
      );

      if (!mounted) return;

      setState(() {
        _messages.add(ChatMessage(isUser: false, text: result.message));
      });

      // AI 응답을 DB에 저장
      await _saveMessageToDb(
        type: 'ai',
        content: result.message,
      );
    } catch (e) {
      debugPrint('❌ [ChatScreen] AI 응답 실패: $e');
      if (!mounted) return;

      // 에러 메시지를 사용자에게 표시
      String errorMessage;
      if (e.toString().contains('연결') || e.toString().contains('서버')) {
        errorMessage = 'AI 서버에 연결할 수 없습니다.\n\n서버가 실행 중인지 확인해주세요.\n(에뮬레이터: http://10.0.2.2:8001)';
      } else {
        errorMessage = 'AI 응답을 받는 중 오류가 발생했습니다.\n\n${e.toString()}';
      }

      setState(() {
        _messages.add(ChatMessage(isUser: false, text: errorMessage));
      });

      // 사용자에게 스낵바로도 알림
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'AI 응답 오류: ${e.toString().substring(0, e.toString().length > 50 ? 50 : e.toString().length)}...',
            ),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // 로딩 끝내고 스크롤 이동
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _handleImagePicker() async {
    final result = await showDialog<ImageSource>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                child: const Text('취소', style: TextStyle(color: ColorPalette.primary200)),
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
          // 이미지 선택 시 바로 전송하지 않고 변수에만 저장
          // 전송 버튼을 눌러야 실제로 전송됨
          setState(() {
            _selectedImageFile = image;
          });

          debugPrint('📷 [ChatScreen] 이미지 선택됨 (전송 대기): ${image.path}');
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

  Future<void> _uploadImage(File imageFile) async {
    try {
      final storageService = StorageService();
      final imageRepository = ImageRepository();
      final imageUrl = await storageService.uploadImage(
        imageFile: imageFile,
        folder: 'chat_images',
      );
      final docId = await imageRepository.saveImageWithUrl(
        imageUrl: imageUrl,
        imageType: ImageType.chat,
        source: ImageSourceType.aiChat,
      );
      _lastUploadedImageDocId = docId;

      // Django DB에 저장된 이미지 ID 가져오기
      // ImageRepository.saveImageWithUrl에서 이미 Django DB에 저장하지만,
      // 여기서는 직접 저장하여 image_pk를 확실히 가져옴
      try {
        if (_currentMemberId != null) {
          final imageApiService = ImageApiService.instance;
          final djangoImageResult = await imageApiService.saveImage(
            memberId: _currentMemberId!,
            imageUrl: imageUrl,
            imageType: 'chat', // ImageType.chat의 문자열 값
            source: 'ai_chat', // ImageSourceType.aiChat의 문자열 값
          );

          // Django 응답에서 image_id 또는 id 추출
          _lastUploadedImagePk = djangoImageResult['image_id'] as int? ?? djangoImageResult['id'] as int?;
          debugPrint('✅ [ChatScreen] Django 이미지 저장 완료: image_pk=$_lastUploadedImagePk');
        } else {
          debugPrint('⚠️ [ChatScreen] 사용자 ID가 없어 Django 이미지 저장을 건너뜁니다.');
          _lastUploadedImagePk = null;
        }
      } catch (e) {
        debugPrint('⚠️ [ChatScreen] Django 이미지 저장 실패 (Firestore는 성공): $e');
        _lastUploadedImagePk = null;
      }

      debugPrint('✅ [ChatScreen] 이미지 업로드 완료: docId=$docId, imagePk=$_lastUploadedImagePk');
    } catch (e) {
      debugPrint('❌ [ChatScreen] 이미지 업로드 실패: $e');
      _lastUploadedImagePk = null;
    }
  }

  Future<void> _handleSendMessage() async {
    final text = _textController.text.trim();
    // 텍스트와 이미지 중 하나라도 있어야 전송 가능
    if (text.isEmpty && _selectedImageFile == null) return;
    if (_isLoading) return;

    // 키보드 숨기기
    _textFieldFocusNode.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');

    // 선택된 이미지 파일 저장 (전송 전에 백업)
    final imageFileToSend = _selectedImageFile;
    final messageText = text.isEmpty ? '' : text;

    // UI에 메시지 추가
    setState(() {
      _messages.add(
        ChatMessage(
          isUser: true,
          text: messageText,
          imagePath: imageFileToSend?.path,
        ),
      );
      _textController.clear();
      _selectedImageFile = null; // 전송 후 초기화
    });

    _scrollToBottom();

    // Firebase 업로드 및 DB 저장
    if (imageFileToSend != null) {
      try {
        // Firebase 업로드
        await _uploadImage(File(imageFileToSend.path));

        // 이미지 메시지를 DB에 저장
        await _saveMessageToDb(
          type: 'user',
          content: messageText.isEmpty ? '' : messageText, // 텍스트가 있으면 함께 저장
          imagePath: imageFileToSend.path,
        );
      } catch (e) {
        debugPrint('❌ [ChatScreen] 이미지 업로드/저장 실패: $e');
      }
    } else {
      // 텍스트만 있는 경우 DB에 저장
      await _saveMessageToDb(
        type: 'user',
        content: messageText,
      );
    }

    // AI에게 전송 (텍스트와 이미지 함께)
    if (imageFileToSend != null) {
      // 이미지가 있으면 이미지와 함께 전송
      // 사용자가 입력한 텍스트가 있으면 그대로 사용, 없으면 기본 질문 사용
      final query = messageText.isEmpty ? '이 음식 먹어도 되나요?' : messageText;
      debugPrint('📤 [ChatScreen] 이미지와 텍스트 함께 전송: query="$query", hasImage=true');
      await _sendRequestToAI(
        query: query,
        imageFile: imageFileToSend,
      );
    } else {
      // 텍스트만 전송
      debugPrint('📤 [ChatScreen] 텍스트만 전송: query="$messageText"');
      await _sendRequestToAI(query: messageText);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (build 메서드는 기존과 동일, 변경 없음)
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
              Column(
                children: [
                  // 선택된 이미지 미리보기
                  if (_selectedImageFile != null)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ColorPalette.bg200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(_selectedImageFile!.path),
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '이미지가 선택되었습니다',
                              style: const TextStyle(
                                fontSize: 12,
                                color: ColorPalette.text200,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20, color: ColorPalette.text200),
                            onPressed: () {
                              setState(() {
                                _selectedImageFile = null;
                              });
                            },
                          ),
                        ],
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
                            onTap: _handleImagePicker,
                            child: Container(
                              width: ResponsiveHelper.width(context, 0.107),
                              height: ResponsiveHelper.width(context, 0.107),
                              decoration: BoxDecoration(
                                color: ColorPalette.bg200,
                                borderRadius: BorderRadius.circular(ResponsiveHelper.width(context, 0.053)),
                              ),
                              child: Icon(
                                Icons.add,
                                color: ColorPalette.text100,
                                size: ResponsiveHelper.fontSize(context, 24),
                              ),
                            ),
                          ),
                          SizedBox(width: ResponsiveHelper.width(context, 0.032)),
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
                                focusNode: _textFieldFocusNode,
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
                                onSubmitted: (_) {
                                  _textFieldFocusNode.unfocus();
                                  _handleSendMessage();
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Bounceable(
                            onTap: _isLoading ? null : _handleSendMessage,
                            child: Container(
                              width: ResponsiveHelper.width(context, 0.12),
                              height: ResponsiveHelper.width(context, 0.12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isLoading ? ColorPalette.primary100.withOpacity(0.5) : ColorPalette.primary100,
                              ),
                              child: _isLoading
                                  ? Center(
                                      child: SizedBox(
                                        width: ResponsiveHelper.width(context, 0.053),
                                        height: ResponsiveHelper.width(context, 0.053),
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(ColorPalette.text100),
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      Icons.send,
                                      color: ColorPalette.text100,
                                      size: ResponsiveHelper.fontSize(context, 20),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
                  child: _buildImageWidget(message.imagePath!),
                ),
              ),
            ],
            // 텍스트가 있으면 이미지와 함께 표시
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

  /// 이미지 경로가 URL인지 로컬 파일 경로인지 확인하여 적절한 위젯 반환
  Widget _buildImageWidget(String imagePath) {
    // URL인지 확인 (http:// 또는 https://로 시작)
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      // Firebase Storage URL인 경우
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: 200,
            height: 200,
            color: ColorPalette.bg200,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          debugPrint('❌ [ChatScreen] 네트워크 이미지 로드 실패: $error');
          return Container(
            width: 200,
            height: 200,
            color: ColorPalette.bg200,
            child: const Icon(Icons.broken_image, color: ColorPalette.text300),
          );
        },
      );
    } else {
      // 로컬 파일 경로인 경우
      return Image.file(
        File(imagePath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('❌ [ChatScreen] 로컬 이미지 로드 실패: $error');
          return Container(
            width: 200,
            height: 200,
            color: ColorPalette.bg200,
            child: const Icon(Icons.broken_image, color: ColorPalette.text300),
          );
        },
      );
    }
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), // 내부 여백 증가
                decoration: BoxDecoration(
                  color: Colors.white, // 흰색 배경을 바깥 컨테이너에 적용 (UI 버그 수정)
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(25),
                    bottomLeft: Radius.circular(25),
                    bottomRight: Radius.circular(25),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 15, // 폰트 사이즈 살짝 키움 (가독성)
                    fontWeight: FontWeight.w400, // 굵기 살짝 조정
                    color: isLoading ? ColorPalette.text300 : ColorPalette.text100,
                    letterSpacing: 0.5,
                    height: 1.4, // 줄간격 조정
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
