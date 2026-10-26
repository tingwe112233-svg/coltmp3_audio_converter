import 'dart:io';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
  static Future<void> cancelCurrentSession() async {
    await FFmpegKit.cancel();
  }

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

      Directory outDir = Directory('/storage/emulated/0/Download/ColtDiesel_MP3');
      try {
        if (!await outDir.exists()) {
          await outDir.create(recursive: true);
        }
      } catch (_) {
        final appDir = await getExternalStorageDirectory();
        if (appDir != null) {
          outDir = Directory(p.join(appDir.path, 'ColtDiesel_MP3'));
          if (!await outDir.exists()) {
            await outDir.create(recursive: true);
          }
        }
      }

      final rawBaseName = p.basenameWithoutExtension(inputPath);
      final cleanName = rawBaseName
          .replaceAll(RegExp(r'[^a-zA-Z0-9_\- ]'), '')
          .trim()
          .replaceAll(RegExp(r'\s+'), '_');
      final safeName = cleanName.isEmpty
          ? 'TRACK_${DateTime.now().millisecondsSinceEpoch}'
          : cleanName;
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
        '-write_id3v2',
        '1',
        '-id3v2_version',
        '3',
        '-write_xing',
        '0',
        outputPath,
      ];

      final session = await FFmpegKit.executeWithArguments(args);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        return ConversionResult(
          success: true,
          outputPath: outputPath,
          message: 'Berhasil dikonversi ke MP3 CBR $bitrateKbps kbps.',
        );
      } else if (ReturnCode.isCancel(returnCode)) {
        return ConversionResult(
          success: false,
          outputPath: '',
          message: 'Konversi dibatalkan.',
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
