// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

/// Centralized Speech-to-Text service for the app.
/// Uses singleton pattern so the STT engine is shared across screens.
class SttService {
  SttService._internal();
  static final SttService _instance = SttService._internal();
  factory SttService() => _instance;

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;

  // Callbacks
  void Function(String text, bool isFinal)? onResult;
  void Function()? onListeningStarted;
  void Function()? onListeningStopped;
  void Function(String error)? onError;

  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;

  /// Initialize the STT engine. Returns true if available.
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      _isInitialized = await _speech.initialize(
        onError: _handleError,
        onStatus: _handleStatus,
        debugLogging: false,
      );
      debugPrint('🎙️ STT initialized: $_isInitialized');
      return _isInitialized;
    } catch (e) {
      debugPrint('🎙️ STT init error: $e');
      return false;
    }
  }

  /// Start listening for speech. [localeId] defaults to 'en_US'.
  Future<void> startListening({String localeId = 'en_US'}) async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) {
        onError?.call(
          'Speech recognition not available. Mikrofon ve konuşma tanıma izinlerini kontrol edin.',
        );
        return;
      }
    }

    final hasPermission = await _speech.hasPermission;
    if (!hasPermission) {
      onError?.call(
        'Mikrofon izni verilmedi. Ayarlar > Duck > Mikrofon ve Konuşma Tanıma izinlerini açın.',
      );
      return;
    }

    if (_isListening) {
      await stopListening();
      await Future.delayed(const Duration(milliseconds: 200));
    }

    try {
      _isListening = true;
      onListeningStarted?.call();

      await _speech.listen(
        onResult: _handleResult,
        localeId: localeId,
        listenMode: stt.ListenMode.confirmation,
        cancelOnError: false,
        partialResults: true,
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
      );

      debugPrint('🎙️ STT listening started (locale: $localeId)');
    } catch (e) {
      debugPrint('🎙️ STT listen error: $e');
      _isListening = false;
      onError?.call('Failed to start listening: $e');
      onListeningStopped?.call();
    }
  }

  /// Stop listening for speech.
  Future<void> stopListening() async {
    if (!_isListening) return;
    try {
      await _speech.stop();
    } catch (e) {
      debugPrint('🎙️ STT stop error: $e');
    }
    _isListening = false;
    onListeningStopped?.call();
  }

  /// Cancel listening without processing results.
  Future<void> cancelListening() async {
    if (!_isListening) return;
    try {
      await _speech.cancel();
    } catch (e) {
      debugPrint('🎙️ STT cancel error: $e');
    }
    _isListening = false;
    onListeningStopped?.call();
  }

  void _handleResult(SpeechRecognitionResult result) {
    final text = result.recognizedWords;
    final isFinal = result.finalResult;
    debugPrint('🎙️ STT result: "$text" (final: $isFinal)');
    onResult?.call(text, isFinal);

    if (isFinal) {
      _isListening = false;
      onListeningStopped?.call();
    }
  }

  void _handleError(SpeechRecognitionError error) {
    debugPrint(
      '🎙️ STT error: ${error.errorMsg} (permanent: ${error.permanent})',
    );
    if (error.permanent) {
      _isListening = false;
      onError?.call(error.errorMsg);
      onListeningStopped?.call();
    }
  }

  void _handleStatus(String status) {
    debugPrint('🎙️ STT status: $status');
    if (status == 'done' || status == 'notListening') {
      _isListening = false;
      onListeningStopped?.call();
    }
  }

  /// Get available locales.
  Future<List<stt.LocaleName>> getLocales() async {
    if (!_isInitialized) await initialize();
    return _speech.locales();
  }

  /// Clean up callbacks.
  void clearCallbacks() {
    onResult = null;
    onListeningStarted = null;
    onListeningStopped = null;
    onError = null;
  }
}
