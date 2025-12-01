import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../widget/bottom_bar_widget.dart';

class HealthInfoScreen extends StatefulWidget {
  const HealthInfoScreen({super.key});

  @override
  State<HealthInfoScreen> createState() => _HealthInfoScreenState();
}

class _HealthInfoScreenState extends State<HealthInfoScreen> {
  final List<String> _birthYears = List.generate(56, (index) => (1970 + index).toString()).reversed.toList();
  final List<int> _pregnancyWeeks = List.generate(40, (index) => index + 1);
  final List<String> _allergyOptions = [
    '난류',
    '우유',
    '메밀',
    '땅콩',
    '대두',
    '밀',
    '잣',
    '호두',
    '게',
    '새우',
    '오징어',
    '고등어',
    '조개류',
  ];

  final TextEditingController _heightController = TextEditingController(text: '162');
  final TextEditingController _weightController = TextEditingController(text: '60');

  String? _selectedBirthYear;
  int _selectedWeek = 20;
  bool _hasGestationalDiabetes = false;
  DateTime? _expectedDueDate = DateTime.now().add(const Duration(days: 120));
  final Set<String> _selectedAllergies = {'우유', '땅콩'};

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  // 🔹 저장 버튼 눌렀을 때 Firestore에 쓰기
  Future<void> _handleSave() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인 정보가 없습니다.')),
        );
        return;
      }
      final uid = user.uid;

      final birthYear = _selectedBirthYear != null ? int.tryParse(_selectedBirthYear!) : null;
      final height = double.tryParse(_heightController.text.trim());
      final weight = double.tryParse(_weightController.text.trim());
      final pregWeek = _selectedWeek;
      final dueDate = _expectedDueDate;

      if (birthYear == null || height == null || weight == null || dueDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('필수 정보를 모두 입력해 주세요.')),
        );
        return;
      }

      final allergies = _selectedAllergies.toList();

      await FirebaseFirestore.instance
          .collection('PREGNANCY')
          .doc(uid) // 👈 로그인한 사용자 기준으로 한 명당 한 문서
          .set({
            'birthYear': birthYear,
            'heightCm': height,
            'weightKg': weight,
            'dueDate': Timestamp.fromDate(dueDate),
            'pregWeek': pregWeek,
            'gestationalDiabetes': _hasGestationalDiabetes,
            'allergies': allergies,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('건강 정보가 저장되었습니다.')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.of(context).pop();
            } else {
              Navigator.pushReplacementNamed(context, '/');
            }
          },
          icon: const Icon(Icons.keyboard_backspace),
        ),
        title: Text(
          '건강 정보 입력',
          style: theme.textTheme.bodyMedium,
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E1E1E)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '건강 정보 입력',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1D1B20),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '정확한 추천을 위해 아래 정보를 입력해 주세요.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF49454F),
                ),
              ),
              const SizedBox(height: 24),
              _buildDropdownSection(
                label: '출생연도',
                value: _selectedBirthYear,
                hint: '연도를 선택하세요',
                options: _birthYears,
                onChanged: (value) {
                  setState(() {
                    _selectedBirthYear = value;
                  });
                },
              ),
              const SizedBox(height: 24),
              _buildNumberField(
                label: '키',
                controller: _heightController,
                suffixText: 'cm',
              ),
              const SizedBox(height: 16),
              _buildNumberField(
                label: '몸무게',
                controller: _weightController,
                suffixText: 'kg',
              ),
              const SizedBox(height: 24),
              _buildDatePickerCard(context),
              const SizedBox(height: 24),
              _buildDropdownSection(
                label: '임신 주차',
                value: '$_selectedWeek주차',
                hint: null,
                options: _pregnancyWeeks.map((w) => '$w주차').toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedWeek = int.parse(value.replaceAll('주차', ''));
                  });
                },
              ),
              const SizedBox(height: 24),
              _buildSwitchSection(),
              const SizedBox(height: 24),
              _buildAllergySection(theme),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _handleSave,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF5BB5C8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('저장하기'),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomBarWidget(currentRoute: '/healthinfo'),
    );
  }

  Widget _buildDropdownSection({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    String? hint,
  }) {
    return _SectionCard(
      label: label,
      child: DropdownButtonFormField<String>(
        value: options.contains(value) ? value : null,
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFFF7F2FA),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        hint: hint != null ? Text(hint) : null,
        items: options
            .map(
              (option) => DropdownMenuItem(
                value: option,
                child: Text(option),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildNumberField({
    required String label,
    required TextEditingController controller,
    required String suffixText,
  }) {
    return _SectionCard(
      label: label,
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFFF7F2FA),
          suffixText: suffixText,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
      ),
    );
  }

  Widget _buildDatePickerCard(BuildContext context) {
    final dateText = _expectedDueDate != null
        ? '${_expectedDueDate!.year}.${_expectedDueDate!.month.toString().padLeft(2, '0')}.${_expectedDueDate!.day.toString().padLeft(2, '0')}'
        : '날짜를 선택하세요';

    return _SectionCard(
      label: '출산 예정일',
      child: ListTile(
        tileColor: const Color(0xFFF7F2FA),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(dateText),
        trailing: IconButton(
          icon: const Icon(Icons.calendar_today_outlined),
          onPressed: () async {
            final today = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: _expectedDueDate ?? today,
              firstDate: today.subtract(const Duration(days: 30)),
              lastDate: today.add(const Duration(days: 365)),
            );
            if (picked != null) {
              setState(() {
                _expectedDueDate = picked;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildSwitchSection() {
    return _SectionCard(
      label: '임신성 당뇨 여부',
      child: SwitchListTile.adaptive(
        value: _hasGestationalDiabetes,
        onChanged: (value) {
          setState(() => _hasGestationalDiabetes = value);
        },
        title: const Text('현재 임신성 당뇨 진단을 받으셨나요?'),
        tileColor: const Color(0xFFF7F2FA),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }

  Widget _buildAllergySection(ThemeData theme) {
    return _SectionCard(
      label: '식품 알러지 정보',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in _allergyOptions)
            FilterChip(
              selected: _selectedAllergies.contains(option),
              label: Text(option),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedAllergies.add(option);
                  } else {
                    _selectedAllergies.remove(option);
                  }
                });
              },
              selectedColor: const Color(0xFF5BB5C8).withOpacity(0.15),
              checkmarkColor: const Color(0xFF5BB5C8),
            ),
          ActionChip(
            avatar: const Icon(Icons.add, size: 16),
            label: const Text('직접 입력'),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('직접 입력 기능은 준비 중입니다.')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E1E1E),
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
