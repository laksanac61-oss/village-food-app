import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Browsers only allow sound after a tap; elsewhere it is always allowed.
Future<bool> unlockSound() async => true;

final _player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

/// Plays the same chime as the web app, through the media volume.
void playChime() => _player.play(AssetSource('sounds/new_order.wav')).catchError((_) {});

void vibrate() => HapticFeedback.heavyImpact();

/// Puts "(n)" in front of the browser tab title; nothing to do outside the browser.
void setTitleCount(int count) {}

/// Asks the device not to dim the screen while the shop waits for orders. Returns whether it worked.
Future<bool> keepScreenOn(bool on) async => false;
