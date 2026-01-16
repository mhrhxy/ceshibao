import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ToastUtil {
  static void showCustomToast(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned.fill( // 填充整个屏幕
        child: Align(
          alignment: Alignment.center, // 水平+垂直居中
          child: Material(
            borderRadius: BorderRadius.circular(8.r),
            color: Colors.black54,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Text(
                message,
                style: TextStyle(color: Colors.white, fontSize: 14.sp),
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