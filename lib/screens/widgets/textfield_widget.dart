import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:traceability_app/themes/theme_color.dart';

import 'package:traceability_app/themes/app_tokens.dart';

class TextFieldWidget extends StatelessWidget {
  final String hintText;

  /// Optional floating label. When provided, label floats above the field on
  /// focus / when filled — keeping context visible while user types.
  final String? labelText;

  final String errorMessage;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextEditingController dataController;
  final Function(String)? onChange;
  final bool? obscure;

  // Preferred
  final TextInputType? keyboardType;

  // Back-compat alias for older code that uses `textInputType`
  final TextInputType? textInputType;

  final List<TextInputFormatter>? inputFormatters;
  final bool readOnly;
  final VoidCallback? onTap;
  final int? maxLines;
  final int? minLines;
  final TextInputAction? textInputAction;
  final TextAlign? textAlign;
  final bool autofocus;

  const TextFieldWidget({
    super.key,
    required this.hintText,
    required this.errorMessage,
    this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    required this.dataController,
    this.onChange,
    this.obscure,
    this.keyboardType,
    this.textInputType, // ← alias
    this.inputFormatters,
    this.readOnly = false,
    this.onTap,
    this.maxLines,
    this.minLines,
    this.textInputAction,
    this.textAlign,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveKeyboardType = keyboardType ?? textInputType;
    final hasError = errorMessage.isNotEmpty;

    final OutlineInputBorder baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.md),
      borderSide: BorderSide(
        color: Colors.grey.shade300,
        width: 1,
      ),
    );

    final OutlineInputBorder focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.md),
      borderSide: const BorderSide(
        color: ThemeColor.darkestGreen,
        width: 1.5,
      ),
    );

    final OutlineInputBorder errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.md),
      borderSide: const BorderSide(
        color: ThemeColor.lightRed,
        width: 1.2,
      ),
    );

    return TextField(
      controller: dataController,
      obscureText: obscure ?? false,
      keyboardType: effectiveKeyboardType,
      inputFormatters: inputFormatters,
      readOnly: readOnly,
      onTap: onTap,
      maxLines: obscure == true ? 1 : (maxLines ?? 1),
      minLines: minLines,
      textInputAction: textInputAction,
      textAlign: textAlign ?? TextAlign.start,
      autofocus: autofocus,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey.shade500),
        labelStyle: TextStyle(color: Colors.grey.shade700),
        floatingLabelStyle: const TextStyle(color: ThemeColor.darkestGreen),
        floatingLabelBehavior:
            labelText == null ? FloatingLabelBehavior.never : FloatingLabelBehavior.auto,
        filled: true,
        fillColor: Colors.grey.shade50,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.md,
        ),
        errorText: hasError ? errorMessage : null,
        border: baseBorder,
        enabledBorder: baseBorder,
        focusedBorder: focusedBorder,
        errorBorder: errorBorder,
        focusedErrorBorder: errorBorder,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
      onChanged: onChange,
    );
  }
}
