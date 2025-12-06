import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/color_palette.dart';
import '../../utils/responsive_helper.dart';

class EatCheckSection extends StatelessWidget {
  const EatCheckSection({
    super.key,
    required this.controller,
    required this.onSubmit,
    required this.onImageSelected,
    this.selectedImageFile,
    this.onRemoveImage,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final ValueChanged<XFile> onImageSelected;
  final XFile? selectedImageFile;
  final VoidCallback? onRemoveImage;

  Widget _buildImagePreview(BuildContext context, String imagePath) {
    try {
      final file = File(imagePath);
      if (!file.existsSync()) {
        return _buildErrorWidget(context);
      }
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorWidget(context);
        },
      );
    } catch (e) {
      return _buildErrorWidget(context);
    }
  }

  Widget _buildErrorWidget(BuildContext context) {
    return Container(
      width: double.infinity,
      height: ResponsiveHelper.height(context, 0.247),
      color: Colors.grey[300],
      child: Icon(
        Icons.broken_image,
        size: ResponsiveHelper.fontSize(context, 50),
        color: Colors.grey,
      ),
    );
  }

  void _showImagePicker(BuildContext context) {
    debugPrint('➕ [EatCheckSection] 이미지 선택 다이얼로그 표시');
    final rootContext = context; // 다이얼로그 종료 후에도 유효한 상위 컨텍스트 보관
    showDialog(
      context: rootContext,
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
                onTap: () async {
                  debugPrint('➕ [EatCheckSection] 카메라 선택 탭');
                  Navigator.pop(rootContext);
                  try {
                    final ImagePicker picker = ImagePicker();
                    debugPrint('📷 [EatCheckSection] 카메라 이미지 선택 시작');
                    // 미리보기용으로는 품질을 낮추지 않고 원본을 사용 (전송 시 원본 화질 유지)
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.camera,
                      // imageQuality를 설정하지 않아 원본 화질 유지
                    );
                    debugPrint('📷 [EatCheckSection] 카메라 이미지 선택 결과: ${image?.path ?? "null"}');
                    if (image != null) {
                      debugPrint('📷 [EatCheckSection] onImageSelected 호출: ${image.path}');
                      onImageSelected(image);
                      debugPrint('📷 [EatCheckSection] onImageSelected 호출 완료');
                    } else {
                      debugPrint('⚠️ [EatCheckSection] 이미지가 null');
                    }
                  } catch (e) {
                    debugPrint('❌ [EatCheckSection] 카메라 오류: $e');
                    ScaffoldMessenger.of(rootContext).showSnackBar(
                      SnackBar(
                        content: Text('카메라 오류: ${e.toString()}'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('앨범에서 선택'),
                onTap: () async {
                  debugPrint('➕ [EatCheckSection] 앨범 선택 탭');
                  Navigator.pop(rootContext);
                  try {
                    final ImagePicker picker = ImagePicker();
                    debugPrint('📷 [EatCheckSection] 앨범 이미지 선택 시작');
                    // 미리보기용으로는 품질을 낮추지 않고 원본을 사용 (전송 시 원본 화질 유지)
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.gallery,
                      // imageQuality를 설정하지 않아 원본 화질 유지
                    );
                    debugPrint('📷 [EatCheckSection] 앨범 이미지 선택 결과: ${image?.path ?? "null"}');
                    if (image != null) {
                      debugPrint('📷 [EatCheckSection] onImageSelected 호출: ${image.path}');
                      onImageSelected(image);
                      debugPrint('📷 [EatCheckSection] onImageSelected 호출 완료');
                    } else {
                      debugPrint('⚠️ [EatCheckSection] 이미지가 null');
                    }
                  } catch (e) {
                    debugPrint('❌ [EatCheckSection] 앨범 오류: $e');
                    ScaffoldMessenger.of(rootContext).showSnackBar(
                      SnackBar(
                        content: Text('앨범 오류: ${e.toString()}'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
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
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            '먹어도 되나요?',
            style: TextStyle(
              fontSize: ResponsiveHelper.fontSize(context, 16),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: const Color(0xFF0F0F0F),
            ),
          ),
        ),
        SizedBox(height: ResponsiveHelper.height(context, 0.015)),
        // 선택된 이미지 미리보기
        if (selectedImageFile != null) ...[
          Container(
            margin: EdgeInsets.only(bottom: ResponsiveHelper.height(context, 0.015)),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(ResponsiveHelper.width(context, 0.032)),
                  child: SizedBox(
                    width: double.infinity,
                    height: ResponsiveHelper.height(context, 0.247),
                    child: _buildImagePreview(context, selectedImageFile!.path),
                  ),
                ),
                // 삭제 버튼
                Positioned(
                  top: 8,
                  right: 8,
                  child: InkWell(
                    onTap: onRemoveImage,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: ResponsiveHelper.width(context, 0.085),
                      height: ResponsiveHelper.width(context, 0.085),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: ResponsiveHelper.fontSize(context, 20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        Container(
          padding: EdgeInsets.symmetric(horizontal: ResponsiveHelper.width(context, 0.053)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ResponsiveHelper.width(context, 0.147)),
            border: Border.all(color: const Color(0xFFF0ECE4)),
          ),
          child: Row(
            children: [
              Bounceable(
                onTap: () {
                  debugPrint('➕ [EatCheckSection] + 버튼 탭 (Bounceable)');
                },
                child: InkWell(
                  onTap: () {
                    debugPrint('➕ [EatCheckSection] + 버튼 탭 (InkWell) -> 이미지 피커 호출');
                    _showImagePicker(context);
                  },
                  borderRadius: BorderRadius.circular(ResponsiveHelper.width(context, 0.021)),
                  child: Container(
                    width: ResponsiveHelper.width(context, 0.075),
                    height: ResponsiveHelper.width(context, 0.075),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFBCE7F0),
                    ),
                    child: Icon(
                      Icons.add,
                      size: ResponsiveHelper.fontSize(context, 18),
                      color: const Color(0xFF0F0F0F),
                    ),
                  ),
                ),
              ),
              SizedBox(width: ResponsiveHelper.width(context, 0.032)),
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: '궁금한 음식/약을 물어보세요',
                    hintStyle: TextStyle(
                      color: const Color(0xFFDADADA),
                      fontSize: ResponsiveHelper.fontSize(context, 14),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                    border: InputBorder.none,
                  ),
                  style: TextStyle(
                    fontSize: ResponsiveHelper.fontSize(context, 14),
                  ),
                  onSubmitted: (_) => onSubmit(),
                ),
              ),
              SizedBox(width: ResponsiveHelper.width(context, 0.032)),
              Bounceable(
                onTap: () {},
                child: InkWell(
                  onTap: onSubmit,
                  borderRadius: BorderRadius.circular(ResponsiveHelper.width(context, 0.021)),
                  child: Container(
                    width: ResponsiveHelper.width(context, 0.075),
                    height: ResponsiveHelper.width(context, 0.075),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFBCE7F0),
                    ),
                    child: Icon(
                      Icons.send,
                      size: ResponsiveHelper.fontSize(context, 16),
                      color: const Color(0xFF0F0F0F),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
