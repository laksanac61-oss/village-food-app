import 'package:flutter/services.dart';

/// Browsers only allow sound after a tap; elsewhere it is always allowed.
Future<bool> unlockSound() async => true;

void playChime() => SystemSound.play(SystemSoundType.alert);

void vibrate() => HapticFeedback.heavyImpact();

/// Puts "(n)" in front of the browser tab title; nothing to do outside the browser.
void setTitleCount(int count) {}

/// Asks the device not to dim the screen while the shop waits for orders. Returns whether it worked.
Future<bool> keepScreenOn(bool on) async => false;
