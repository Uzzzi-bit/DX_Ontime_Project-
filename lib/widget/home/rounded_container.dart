import 'package:flutter/material.dart';

class RoundedContainer extends StatelessWidget {
  final Widget child;

  const RoundedContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(190), // ← 숫자 키우면 더 둥글, 줄이면 더 네모
        ),
      ),
      child: child,
    );
  }
}
