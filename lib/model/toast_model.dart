import 'package:flutter/material.dart';

class ToastUtil {
  static void showCustomToast(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned.fill( // 填充整个屏幕
        child: Align(
          alignment: Alignment.center, // 水平+垂直居中
          child: Material(
            borderRadius: BorderRadius.circular(8),
            color: Colors.black54,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 2)).then((_) => overlayEntry.remove());
  }
}