import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.label,
    this.placeholder,
    this.icon,
    this.controller,
    this.onChanged,
    this.obscure = false,
    this.hint,
    this.keyboardType,
    this.dense = false,
    this.suffixIcon,
  });

  final String? label;
  final String? placeholder;
  final IconData? icon;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  /// Password field with a show / hide toggle.
  final bool obscure;
  final String? hint;
  final TextInputType? keyboardType;

  /// Shorter field (used for the search box).
  final bool dense;

  /// Optional custom suffix widget (overrides the obscure toggle).
  final Widget? suffixIcon;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _hidden = widget.obscure;

  OutlineInputBorder _border(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: AppText.body(14, c.ink, weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: widget.controller,
          onChanged: widget.onChanged,
          obscureText: _hidden,
          keyboardType: widget.keyboardType,
          cursorColor: c.primary,
          style: AppText.body(15, c.ink),
          decoration: InputDecoration(
            hintText: widget.placeholder,
            hintStyle: AppText.body(15, AppColors.placeholder),
            filled: true,
            fillColor: c.surface,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: widget.dense ? 11 : 15,
            ),
            prefixIcon: widget.icon == null
                ? null
                : Icon(widget.icon, size: 20, color: c.muted),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 44, minHeight: 20),
            suffixIcon: widget.suffixIcon ??
                (widget.obscure
                    ? IconButton(
                        onPressed: () => setState(() => _hidden = !_hidden),
                        tooltip: _hidden ? 'Show password' : 'Hide password',
                        icon: Icon(
                          _hidden
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                          color: c.muted,
                        ),
                      )
                    : null),
            border: _border(c.line),
            enabledBorder: _border(c.line),
            focusedBorder: _border(c.primary, 1.5),
          ),
        ),
        if (widget.hint != null) ...[
          const SizedBox(height: 8),
          Text(widget.hint!, style: AppText.body(12.5, c.muted)),
        ],
      ],
    );
  }
}
