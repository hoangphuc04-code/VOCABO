import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

/// SttService — wrapper tập trung cho speech_to_text v7.x
///
/// Giải quyết các vấn đề phổ biến:
/// - onStatus callback để biết khi nào STT thực sự dừng
/// - partialResults: true để Android trả về kết quả liên tục
/// - cancelOnError: true để tự dừng khi lỗi
/// - Tự động reset _isListening khi STT tự dừng (timeout, error)
class SttService {
  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _available = false;
  bool _isListening = false;

  bool get isAvailable => _available;
  bool get isListening => _isListening;

  /// Khởi tạo STT — gọi 1 lần trong initState
  /// [onStatusChange] được gọi khi trạng thái thay đổi (listening/notListening/done)
  Future<bool> initialize({
    void Function(String status)? onStatusChange,
    void Function(SpeechRecognitionError error)? onError,
  }) async {
    _available = await _stt.initialize(
      onStatus: (status) {
        // Khi STT tự dừng (timeout, done, notListening) → reset flag
        if (status == 'notListening' || status == 'done') {
          _isListening = false;
        }
        onStatusChange?.call(status);
      },
      onError: (error) {
        _isListening = false;
        onError?.call(error);
      },
      debugLogging: false,
    );
    return _available;
  }

  /// Bắt đầu nghe
  /// [localeId] — 'en_US' hoặc 'en_GB'
  /// [listenFor] — thời gian tối đa nghe
  /// [pauseFor] — thời gian im lặng để tự dừng
  /// [onResult] — callback khi có kết quả (partial + final)
  /// [onDone] — callback khi STT kết thúc (dù có kết quả hay không)
  Future<bool> startListening({
    String localeId = 'en_US',
    Duration listenFor = const Duration(seconds: 8),
    Duration pauseFor = const Duration(seconds: 2),
    required void Function(String words, bool isFinal) onResult,
    void Function()? onDone,
  }) async {
    if (!_available || _isListening) return false;
    _isListening = true;

    final started = await _stt.listen(
      localeId: localeId,
      listenFor: listenFor,
      pauseFor: pauseFor,
      partialResults: true,       // Quan trọng: nhận kết quả liên tục trên Android
      cancelOnError: true,        // Tự dừng khi lỗi
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
      ),
      onResult: (SpeechRecognitionResult result) {
        final words = result.recognizedWords.trim();
        if (result.finalResult) {
          _isListening = false;
          onResult(words, true);
          onDone?.call();
        } else if (words.isNotEmpty) {
          onResult(words, false);
        }
      },
    );

    if (!started) {
      _isListening = false;
    }
    return started;
  }

  /// Dừng nghe thủ công
  Future<void> stopListening() async {
    if (!_isListening) return;
    await _stt.stop();
    _isListening = false;
  }

  /// Hủy nghe (không lấy kết quả)
  Future<void> cancelListening() async {
    await _stt.cancel();
    _isListening = false;
  }

  /// Dọn dẹp
  void dispose() {
    _stt.cancel();
  }
}
