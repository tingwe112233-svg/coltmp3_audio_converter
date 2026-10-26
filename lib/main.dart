import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/car_tape_converter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ColtMP3 Audio Converter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF59E0B),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<PlatformFile> _selectedFiles = [];
  int _currentConvertingIndex = 0;
  String _selectedBitrate = '192';
  bool _isConverting = false;
  bool _cancelRequested = false;
  bool _isPlaying = false;
  String? _currentlyPlayingPath;
  String _statusMessage = 'Pilih hingga 100 file audio lokal (WAV, M4A, OPUS, FLAC, MP3) dari HP Anda.';
  final List<String> _convertedFiles = [];

  final List<String> _bitrates = ['128', '192', '256', '320'];

  @override
  void initState() {
    super.initState();
    _requestStoragePermissions();
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });
  }

  Future<void> _requestStoragePermissions() async {
    if (Platform.isAndroid) {
      await [
        Permission.storage,
        Permission.audio,
        Permission.notification,
        Permission.manageExternalStorage,
      ].request();
    }
  }

  Future<void> _pickAudioFiles() async {
    if (_isConverting) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      await _audioPlayer.stop();
      List<PlatformFile> validFiles = result.files.where((f) => f.path != null).toList();

      if (validFiles.length > 100) {
        validFiles = validFiles.sublist(0, 100);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maksimal 100 lagu dipilih. File selebihnya diabaikan otomatis.'),
              backgroundColor: Colors.amber,
            ),
          );
        }
      }

      setState(() {
        _selectedFiles = validFiles;
        _currentConvertingIndex = 0;
        _statusMessage = '${_selectedFiles.length} file dipilih. Siap dikonversi ke MP3 CBR.';
      });
    }
  }

  Future<void> _togglePreview(String path) async {
    try {
      if (_isPlaying && _currentlyPlayingPath == path) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.stop();
        await _audioPlayer.setFilePath(path);
        _currentlyPlayingPath = path;
        await _audioPlayer.play();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Gagal memutar pratinjau audio: $e';
        });
      }
    }
  }

  Future<void> _startBulkConversion() async {
    if (_selectedFiles.isEmpty || _isConverting) return;

    setState(() {
      _isConverting = true;
      _cancelRequested = false;
      _currentConvertingIndex = 0;
      _statusMessage = 'Mulai mengonversi ${_selectedFiles.length} file...';
    });

    int successCount = 0;
    int failCount = 0;

    for (int i = 0; i < _selectedFiles.length; i++) {
      if (_cancelRequested) {
        break;
      }

      final file = _selectedFiles[i];
      if (file.path == null) continue;

      if (mounted) {
        setState(() {
          _currentConvertingIndex = i;
          _statusMessage = 'Memproses [${i + 1}/${_selectedFiles.length}]: ${file.name}';
        });
      }

      final res = await CarTapeAudioConverter.convertToCarTapeMp3(
        inputPath: file.path!,
        bitrateKbps: _selectedBitrate,
        onProgress: (_) {},
      );

      if (!mounted) return;

      if (res.success) {
        successCount++;
        setState(() {
          if (!_convertedFiles.contains(res.outputPath)) {
            _convertedFiles.insert(0, res.outputPath);
          }
        });
      } else {
        failCount++;
      }
    }

    if (mounted) {
      setState(() {
        _isConverting = false;
        if (_cancelRequested) {
          _statusMessage = 'Konversi dibatalkan. ($successCount berhasil, $failCount gagal)';
        } else {
          _statusMessage = 'Selesai! $successCount lagu berhasil, $failCount gagal dikonversi.';
        }
      });
    }
  }

  Future<void> _cancelConversion() async {
    if (_isConverting) {
      setState(() {
        _cancelRequested = true;
        _statusMessage = 'Membatalkan proses konversi...';
      });
      await CarTapeAudioConverter.cancelCurrentSession();
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double totalProgress = _selectedFiles.isEmpty
        ? 0.0
        : (_currentConvertingIndex + (_isConverting ? 0.5 : 1.0)) / _selectedFiles.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ColtMP3 Audio Converter'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '1. Pilih File Audio (Maks 100)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      if (_selectedFiles.isNotEmpty)
                        Chip(
                          label: Text(
                            '${_selectedFiles.length} Lagu',
                            style: const TextStyle(fontSize: 12, color: Colors.amber),
                          ),
                          backgroundColor: const Color(0xFF0F172A),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_selectedFiles.isEmpty)
                    const Text(
                      'Belum ada file dipilih',
                      style: TextStyle(color: Colors.white70),
                    )
                  else
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        itemCount: _selectedFiles.length,
                        itemBuilder: (context, index) {
                          final file = _selectedFiles[index];
                          final isCurrent = _isConverting && index == _currentConvertingIndex;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isCurrent ? const Color(0xFF0F172A) : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isCurrent ? Icons.sync : Icons.audio_file,
                                  size: 16,
                                  color: isCurrent ? Colors.amber : Colors.white54,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${index + 1}. ${file.name}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isCurrent ? Colors.amber : Colors.white70,
                                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isConverting ? null : _pickAudioFiles,
                      icon: const Icon(Icons.folder_open),
                      label: Text(_selectedFiles.isEmpty
                          ? 'Pilih File Audio dari HP (Masal)'
                          : 'Ganti Pilihan File Audio'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '2. Standar Tape Mobil (44.1 kHz · Stereo · CBR)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedBitrate,
                    decoration: const InputDecoration(
                      labelText: 'Pilih Kualitas Bitrate (Constant Bitrate)',
                      border: OutlineInputBorder(),
                    ),
                    items: _bitrates
                        .map((b) => DropdownMenuItem(
                              value: b,
                              child: Text('$b kbps CBR ${b == "320" ? "(Kualitas Tinggi)" : b == "128" ? "(Standar Hemat)" : ""}'),
                            ))
                        .toList(),
                    onChanged: _isConverting
                        ? null
                        : (val) {
                            if (val != null) setState(() => _selectedBitrate = val);
                          },
                  ),
                  const SizedBox(height: 16),
                  if (_isConverting) ...[
                    LinearProgressIndicator(
                      value: totalProgress.clamp(0.0, 1.0),
                      backgroundColor: Colors.white12,
                      color: Colors.amber,
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: (_selectedFiles.isEmpty || _isConverting)
                                ? null
                                : _startBulkConversion,
                            icon: _isConverting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.tune),
                            label: Text(_isConverting
                                ? 'Mengonversi (${_currentConvertingIndex + 1}/${_selectedFiles.length})...'
                                : 'Konversi ${_selectedFiles.isNotEmpty ? "(${_selectedFiles.length})" : ""} ke MP3 Tape Mobil'),
                          ),
                        ),
                      ),
                      if (_isConverting) ...[
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          onPressed: _cancelConversion,
                          icon: const Icon(Icons.stop, color: Colors.redAccent),
                          tooltip: 'Batal Konversi',
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _statusMessage,
                    style: const TextStyle(fontSize: 13, color: Colors.amberAccent),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_convertedFiles.isNotEmpty) ...[
              Text(
                'Hasil Konversi (${_convertedFiles.length} Lagu di Download/ColtDiesel_MP3)',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ..._convertedFiles.map(
                (filePath) {
                  final isThisPlaying = _isPlaying && _currentlyPlayingPath == filePath;
                  return Card(
                    child: ListTile(
                      title: Text(
                        filePath.split('/').last,
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(filePath, style: const TextStyle(fontSize: 11)),
                      trailing: IconButton(
                        icon: Icon(
                          isThisPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                          color: Colors.amber,
                        ),
                        onPressed: () => _togglePreview(filePath),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
