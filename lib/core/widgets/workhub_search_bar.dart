import 'package:flutter/material.dart';
import '../theme/orbit_theme.dart';

/// Standard, unified search bar component styled consistently across all screens
/// following WhatsApp mobile clarity & Orbit workspace styling:
/// - Rounded 99px pill shape with subtle border and elevation
/// - Search leading icon
/// - Optional clear (x) button when text is present
/// - Optional trailing action widget (e.g. filter/tune button)
class WorkHubSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final String hintText;
  final Key? textFieldKey;
  final Widget? trailing;
  final bool autoFocus;

  const WorkHubSearchBar({
    super.key,
    required this.controller,
    this.focusNode,
    this.onChanged,
    this.onClear,
    this.hintText = 'Search...',
    this.textFieldKey,
    this.trailing,
    this.autoFocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: OrbitColors.cardSurface.withValues(alpha: .92),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: Colors.white.withValues(alpha: .85),
                width: 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D06244D),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                const Icon(
                  Icons.search_rounded,
                  color: OrbitColors.textMuted,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: textFieldKey,
                    controller: controller,
                    focusNode: focusNode,
                    autofocus: autoFocus,
                    onChanged: onChanged,
                    style: const TextStyle(
                      fontSize: 14,
                      color: OrbitColors.textNavy,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: hintText,
                      hintStyle: const TextStyle(
                        fontSize: 14,
                        color: OrbitColors.textMuted,
                        fontWeight: FontWeight.normal,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    if (value.text.isEmpty) return const SizedBox.shrink();
                    return GestureDetector(
                      onTap: () {
                        controller.clear();
                        onChanged?.call('');
                        onClear?.call();
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(
                          Icons.cancel_rounded,
                          size: 18,
                          color: OrbitColors.textMuted,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}
