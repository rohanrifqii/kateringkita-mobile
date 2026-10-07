import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import '../core/app_text_styles.dart';

/// Input kode OTP. Secara visual berupa [length] kotak, tetapi secara
/// teknis hanya SATU TextField tersembunyi. Dengan begitu paste, backspace,
/// dan autofill SMS/email (oneTimeCode) bekerja native tanpa logika
/// perpindahan fokus manual antar kotak.
class OtpInput extends StatefulWidget {
  final int length;
  final bool hasError;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;

  const OtpInput({
    super.key,
    this.length = 6,
    this.hasError = false,
    this.onChanged,
    this.onCompleted,
  });

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChange);
    _focusNode.addListener(() => setState(() {}));
  }

  void _handleTextChange() {
    setState(() {});
    final text = _controller.text;
    widget.onChanged?.call(text);
    if (text.length == widget.length) widget.onCompleted?.call(text);
  }

  void _requestKeyboard() {
    _focusNode.requestFocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.show');
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _controller.text;
    final activeIndex = text.length.clamp(0, widget.length - 1);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _requestKeyboard,
      child: Stack(
        children: [
          Row(
            children: List.generate(widget.length, (i) {
              final isFilled = i < text.length;
              final isActive = _focusNode.hasFocus && i == activeIndex;

              Color borderColor = AppColors.cardBorder;
              if (widget.hasError) {
                borderColor = AppColors.danger;
              } else if (isActive) {
                borderColor = AppColors.blue;
              }

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: borderColor,
                        width: isActive ? 1.8 : 1,
                      ),
                    ),
                    child: isFilled
                        ? Text(
                            text[i],
                            style: AppTextStyles.h3.copyWith(fontSize: 20),
                          )
                        : (isActive
                            ? Container(
                                width: 1.5,
                                height: 22,
                                color: AppColors.blue,
                              )
                            : null),
                  ),
                ),
              );
            }),
          ),
          // TextField tersembunyi yang menampung input sebenarnya.
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                maxLength: widget.length,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                enableInteractiveSelection: false,
                showCursor: false,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}