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
  String? _selectedFilePath;
  String? _selectedFileName;
  String _selectedBitrate = '192';
  bool _isConverting = false;
  bool _isPlaying = false;
  String _statusMessage = 'Pilih file audio lokal (WAV, M4A, OPUS, FLAC, MP3) dari HP Anda.';
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
      ].request();
    }
  }

  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      await _audioPlayer.stop();
      setState(() {
        _selectedFilePath = result.files.single.path!;
        _selectedFileName = result.files.single.name;
        _statusMessage = 'File siap dipratinjau atau dikonversi ke MP3 CBR.';
      });
    }
  }

  Future<void> _togglePreview(String path) async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.setFilePath(path);
        await _audioPlayer.play();
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Gagal memutar pratinjau audio: $e';
      });
    }
  }

  Future<void> _startConversion() async {
    if (_selectedFilePath == null || _isConverting) return;

    setState(() {
      _isConverting = true;
      _statusMessage = 'Mengonversi dengan FFmpeg (libmp3lame 44100Hz Stereo CBR)...';
    });

    final res = await CarTapeAudioConverter.convertToCarTapeMp3(
      inputPath: _selectedFilePath!,
      bitrateKbps: _selectedBitrate,
      onProgress: (secondsEncoded) {
        if (mounted) {
          setState(() {
            _statusMessage =
                'Memproses audio: ${secondsEncoded.toStringAsFixed(1)} detik terkonversi...';
          });
        }
      },
    );

    if (!mounted) return;
    setState(() {
      _isConverting = false;
      _statusMessage = res.message;
      if (res.success) {
        _convertedFiles.insert(0, res.outputPath);
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  const Text(
                    '1. Pilih File Audio Lokal',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedFileName ?? 'Belum ada file dipilih',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isConverting ? null : _pickAudioFile,
                          icon: const Icon(Icons.folder_open),
                          label: const Text('Pilih Audio dari HP'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_selectedFilePath != null)
                        OutlinedButton.icon(
                          onPressed: () => _togglePreview(_selectedFilePath!),
                          icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                          label: Text(_isPlaying ? 'Pause' : 'Play'),
                        ),
                    ],
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
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: (_selectedFilePath == null || _isConverting)
                          ? null
                          : _startConversion,
                      icon: _isConverting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.tune),
                      label: Text(_isConverting ? 'Mengonversi...' : 'Konversi ke MP3 Tape Mobil'),
                    ),
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
              const Text(
                'Hasil Konversi (Folder Download/ColtDiesel_MP3)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ..._convertedFiles.map(
                (filePath) => Card(
                  child: ListTile(
                    title: Text(
                      filePath.split('/').last,
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(filePath, style: const TextStyle(fontSize: 11)),
                    trailing: IconButton(
                      icon: const Icon(Icons.play_circle_fill),
                      onPressed: () => _togglePreview(filePath),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
