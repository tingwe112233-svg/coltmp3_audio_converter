import 'dart:io';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:path/path.dart' as p;

class ConversionResult {
  final bool success;
  final String outputPath;
  final String message;

  ConversionResult({
    required this.success,
    required this.outputPath,
    required this.message,
  });
}

class CarTapeAudioConverter {
  /// Mengonversi file audio apa pun (m4a, wav, flac, ogg, opus, aac, mp3 VBR)
  /// menjadi MP3 murni yang 100% terbaca di Head Unit / Tape Mobil Box Colt Diesel:
  /// - Codec: libmp3lame
  /// - Sample Rate: 44100 Hz
  /// - Channels: 2 (Stereo Joint/Standard)
  /// - Bitrate Mode: Strict CBR (Constant Bitrate) tanpa header VBR/Xing
  /// - Tagging: ID3v2.3 (kompatibel chip decoder hardware lama)
  static Future<ConversionResult> convertToCarTapeMp3({
    required String inputPath,
    required String bitrateKbps,
    required void Function(double progressPercent) onProgress,
  }) async {
    try {
      final inputFile = File(inputPath);
      if (!await inputFile.exists()) {
        return ConversionResult(
          success: false,
          outputPath: '',
          message: 'File sumber tidak ditemukan di penyimpanan.',
        );
      }

      // Simpan ke folder Download/ColtDiesel_MP3 agar mudah disalin ke Flashdisk OTG
      final outDir = Directory('/storage/emulated/0/Download/ColtDiesel_MP3');
      if (!await outDir.exists()) {
        await outDir.create(recursive: true);
      }

      // Bersihkan karakter aneh/emoji pada nama file
      final rawBaseName = p.basenameWithoutExtension(inputPath);
      final cleanName = rawBaseName
          .replaceAll(RegExp(r'[^a-zA-Z0-9_\- ]'), '')
          .trim()
          .replaceAll(RegExp(r'\s+'), '_');
      final safeName = cleanName.isEmpty ? 'TRACK_${DateTime.now().millisecondsSinceEpoch}' : cleanName;
      final outputPath = p.join(outDir.path, '${safeName}_${bitrateKbps}kbps_CBR.mp3');

      FFmpegKitConfig.enableStatisticsCallback((stats) {
        final timeMs = stats.getTime();
        if (timeMs > 0) {
          onProgress((timeMs / 1000.0));
        }
      });

      final args = <String>[
        '-y',
        '-i',
        inputPath,
        '-vn',
        '-acodec',
        'libmp3lame',
        '-ar',
        '44100',
        '-ac',
        '2',
        '-b:a',
        '${bitrateKbps}k',
        '-minrate',
        '${bitrateKbps}k',
        '-maxrate',
        '${bitrateKbps}k',
        '-bufsize',
        '${int.parse(bitrateKbps) * 2}k',
        '-write_id3v2', '1',
        '-id3v2_version', '3',
        '-write_xing', '0',
        outputPath,
      ];

      final session = await FFmpegKit.executeWithArguments(args);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        return ConversionResult(
          success: true,
          outputPath: outputPath,
          message: 'Berhasil dikonversi ke MP3 CBR $bitrateKbps kbps (44.1kHz Stereo).',
        );
      } else {
        final logs = await session.getAllLogsAsString();
        return ConversionResult(
          success: false,
          outputPath: '',
          message: 'Konversi gagal: ${logs ?? "Unknown FFmpeg error"}',
        );
      }
    } catch (e) {
      return ConversionResult(
        success: false,
        outputPath: '',
        message: 'Terjadi kesalahan sistem: $e',
      );
    }
  }
}
