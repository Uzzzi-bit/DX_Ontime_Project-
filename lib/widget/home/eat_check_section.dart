import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class EatCheckSection extends StatelessWidget {
  const EatCheckSection({
    super.key,
    required this.controller,
    required this.onSubmit,
    required this.onImageSelected,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final ValueChanged<XFile> onImageSelected;

  void _showImagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('카메라로 촬영'),
              onTap: () async {
                Navigator.pop(context);
                final ImagePicker picker = ImagePicker();
                final XFile? image = await picker.pickImage(
                  source: ImageSource.camera,
                );
                if (image != null) {
                  onImageSelected(image);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('앨범에서 선택'),
              onTap: () async {
                Navigator.pop(context);
                final ImagePicker picker = ImagePicker();
                final XFile? image = await picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (image != null) {
                  onImageSelected(image);
                }
              },
            ),
          ],
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(55),
            border: Border.all(color: const Color(0xFFF0ECE4)),
          ),
          child: Row(
            children: [
              InkWell(
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
              InkWell(
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
            ],
          ),
        ),
      ],
    );
  }
}
