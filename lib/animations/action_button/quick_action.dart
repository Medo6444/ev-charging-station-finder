import 'package:flutter/material.dart';

class QuickAction {
  final IconData icon;
  final Color backgroundColor;
  final Color? iconColor;
  final Function() onTap;

  const QuickAction({
    required this.icon,
    this.backgroundColor = Colors.black87,
    this.iconColor,
    required this.onTap,
  });
}