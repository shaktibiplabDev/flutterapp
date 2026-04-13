// custom_text_field.dart
import 'package:flutter/material.dart';

class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final VoidCallback? onEditingComplete;  // ✅ Already there
  final int? maxLines;
  final int? minLines;
  final bool enabled;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.onEditingComplete,  // ✅ Already there
    this.maxLines = 1,
    this.minLines,
    this.enabled = true,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late FocusNode _focusNode;
  bool _isFocused = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        obscureText: widget.obscureText,
        validator: (value) {
          final error = widget.validator?.call(value);
          setState(() {
            _hasError = error != null;
          });
          return error;
        },
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        onEditingComplete: widget.onEditingComplete,  // ✅ Added this line
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        enabled: widget.enabled,
        style: TextStyle(
          fontSize: 16,
          color: _hasError ? Colors.red.shade700 : Colors.grey.shade800,
        ),
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: TextStyle(
            color: _hasError
                ? Colors.red.shade400
                : _isFocused
                    ? const Color(0xFF1976D2)
                    : Colors.grey.shade500,
            fontWeight: _isFocused ? FontWeight.w500 : FontWeight.normal,
          ),
          prefixIcon: Icon(
            widget.prefixIcon,
            color: _hasError
                ? Colors.red.shade400
                : _isFocused
                    ? const Color(0xFF1976D2)
                    : Colors.grey.shade500,
            size: 22,
          ),
          suffixIcon: widget.suffixIcon,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: _hasError
                  ? Colors.red.shade200
                  : Colors.grey.shade300,
              width: 1,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.grey.shade200,
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFF1976D2),
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.red.shade200,
              width: 1,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.red.shade400,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          errorStyle: TextStyle(
            color: Colors.red.shade600,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}