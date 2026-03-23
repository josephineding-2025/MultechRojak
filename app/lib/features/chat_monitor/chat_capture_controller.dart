import 'dart:convert';
import 'dart:io';

import 'package:screen_capturer/screen_capturer.dart';

class ChatCaptureController {
  ChatCaptureController();

  String? _previousFrame;

  Future<bool> ensureCaptureAccess() async {
    if (!Platform.isMacOS) {
      return true;
    }

    final allowed = await screenCapturer.isAccessAllowed();
    if (allowed) {
      return true;
    }

    await screenCapturer.requestAccess();
    return screenCapturer.isAccessAllowed();
  }

  void reset() {
    _previousFrame = null;
  }

  Future<String?> captureCurrentFrame() async {
    final captured = await screenCapturer.capture(
      mode: CaptureMode.screen,
      copyToClipboard: true,
      silent: true,
    );
    final imageBytes = captured?.imageBytes;
    if (imageBytes == null || imageBytes.isEmpty) {
      return null;
    }

    return base64Encode(imageBytes);
  }

  Future<String?> captureChangedFrame() async {
    final nextFrame = await captureCurrentFrame();
    if (nextFrame == null) {
      return null;
    }
    if (nextFrame == _previousFrame) {
      return null;
    }

    _previousFrame = nextFrame;
    return nextFrame;
  }
}
