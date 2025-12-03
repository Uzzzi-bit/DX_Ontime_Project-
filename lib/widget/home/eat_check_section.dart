import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/color_palette.dart';

class EatCheckSection extends StatelessWidget {
  const EatCheckSection({
    super.key,
    required this.controller,
    required this.onSubmit,
    required this.onImageSelected,
    this.selectedImagePath,
    this.onRemoveImage,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final ValueChanged<XFile> onImageSelected;
  final String? selectedImagePath;
  final VoidCallback? onRemoveImage;

  Widget _buildImagePreview(String imagePath) {
    try {
      final file = File(imagePath);
      if (!file.existsSync()) {
        return _buildErrorWidget();
      }
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorWidget();
        },
      );
    } catch (e) {
      return _buildErrorWidget();
    }
  }

  Widget _buildErrorWidget() {
    return Container(
      width: double.infinity,
      height: 200,
      color: Colors.grey[300],
      child: const Icon(
        Icons.broken_image,
        size: 50,
        color: Colors.grey,
      ),
    );
  }

  void _showImagePicker(BuildContext context) {
    showDialog(
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
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final ImagePicker picker = ImagePicker();
                    // 미리보기용으로는 품질을 낮추지 않고 원본을 사용 (전송 시 원본 화질 유지)
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.camera,
                      // imageQuality를 설정하지 않아 원본 화질 유지
                    );
                    if (image != null && context.mounted) {
                      onImageSelected(image);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('카메라 오류: ${e.toString()}'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('앨범에서 선택'),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final ImagePicker picker = ImagePicker();
                    // 미리보기용으로는 품질을 낮추지 않고 원본을 사용 (전송 시 원본 화질 유지)
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.gallery,
                      // imageQuality를 설정하지 않아 원본 화질 유지
                    );
                    if (image != null && context.mounted) {
                      onImageSelected(image);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('앨범 오류: ${e.toString()}'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
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
        const Center(
          child: Text(
            '먹어도 되나요?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: Color(0xFF0F0F0F),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 선택된 이미지 미리보기
        if (selectedImagePath != null) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 200,
                    child: _buildImagePreview(selectedImagePath!),
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
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(55),
            border: Border.all(color: const Color(0xFFF0ECE4)),
          ),
          child: Row(
            children: [
              Bounceable(
                onTap: () {},
                child: InkWell(
                  onTap: () => _showImagePicker(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFBCE7F0),
                    ),
                    child: const Icon(
                      Icons.add,
                      size: 18,
                      color: Color(0xFF0F0F0F),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: '궁금한 음식/약을 물어보세요',
                    hintStyle: TextStyle(
                      color: Color(0xFFDADADA),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => onSubmit(),
                ),
              ),
              const SizedBox(width: 12),
              Bounceable(
                onTap: () {},
                child: InkWell(
                  onTap: onSubmit,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFBCE7F0),
                    ),
                    child: const Icon(
                      Icons.send,
                      size: 16,
                      color: Color(0xFF0F0F0F),
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
