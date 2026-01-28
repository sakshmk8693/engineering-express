import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math'; // Random messages ke liye
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../main.dart';
import 'pdf_viewer_page.dart';

// 🔥🔥 1. GLOBAL DOWNLOAD MANAGER (WITH FAKE PROGRESS & FUNNY MESSAGES) 🔥🔥
class DownloadManager {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal();

  // ID -> Progress (0.0 to 1.0)
  final ValueNotifier<Map<String, double>> progressNotifier = ValueNotifier({});
  // ID -> Status ('downloading', 'error', 'success', 'cancelled')
  final ValueNotifier<Map<String, String>> statusNotifier = ValueNotifier({});
  // ID -> Current Funny Message
  final ValueNotifier<Map<String, String>> messageNotifier = ValueNotifier({});

  // Internal Trackers
  final Map<String, bool> _cancelTokens = {};
  final Map<String, Timer> _simulationTimers = {}; // Fake progress timer
  final Map<String, Timer> _messageTimers = {};    // Message changer timer

  // 🤖 FUNNY MESSAGES LIST
  final List<String> _funnyMessages = [
    "Ruko jara, sabar karo... ✋",
    "Engine garam ho raha hai... 🔥",
    "Data chus raha hu server se... 📡",
    "Notes dhoondne pataal lok ja raha hu... 🧐",
    "Bas ho hi gaya samjho... ⏳",
    "Wifi hai ya padosi ka hotspot? 😂",
    "Sabr ka fal 'PDF' hota hai... 🍎",
    "Bhaag mat jana, abhi aaya... 🏃‍♂️",
    "Bhari file hai, time to lagega na... 🐘",
    "Ye lo, ek aur percent badh gaya... 📈",
    "Download ho raha hai, phone mat hilaana! 📱",
    "Chalo chai pi lo tab tak... ☕"
  ];

  Future<void> startDownload(
      String pdfDbId,
      String driveId,
      SupabaseClient supabase,
      FlutterSecureStorage storage,
      Function(String) onComplete
      ) async {
    if (statusNotifier.value[pdfDbId] == 'downloading') return;

    // Reset State
    _updateStatus(pdfDbId, 'downloading');
    _updateProgress(pdfDbId, 0.05); // Start with 5%
    _updateMessage(pdfDbId, "Starting engines... 🚀");
    _cancelTokens[pdfDbId] = false;

    // 🚀 START SIMULATION (Fake Progress & Messages)
    _startSimulation(pdfDbId);

    try {
      // 1. Prepare Request
      const String projectUrl = 'https://trwjnnufszkwyfbocrzm.supabase.co';
      final functionUrl = Uri.parse('$projectUrl/functions/v1/get-drive-file');
      final session = supabase.auth.currentSession;

      final request = http.Request('POST', functionUrl);
      request.headers.addAll({
        'Authorization': 'Bearer ${session?.accessToken ?? ""}',
        'Content-Type': 'application/json',
      });
      request.body = jsonEncode({"file_id": driveId});

      final streamedResponse = await request.send();

      if (streamedResponse.statusCode != 200) {
        throw "Server Error: ${streamedResponse.statusCode}";
      }

      // Note: Hum real progress ignore kar rahe hain kyunki server size nahi bhejta.
      // Humara fake timer visual sambhal lega.

      List<int> fileBytes = [];
      await for (var chunk in streamedResponse.stream) {
        if (_cancelTokens[pdfDbId] == true) {
          _stopSimulation(pdfDbId);
          _updateStatus(pdfDbId, 'cancelled');
          _updateProgress(pdfDbId, 0.0);
          return;
        }
        fileBytes.addAll(chunk);
      }

      // 3. Encrypt & Save
      final keyString = await _getOrGenerateKey(driveId, supabase, storage);
      final key = enc.Key.fromBase64(keyString);
      final iv = enc.IV.fromLength(16);
      final encrypter = enc.Encrypter(enc.AES(key));

      final bytesList = Uint8List.fromList(fileBytes);
      final encrypted = encrypter.encryptBytes(bytesList, iv: iv);
      final combined = [...iv.bytes, ...encrypted.bytes];

      final dir = await getApplicationDocumentsDirectory();
      final file = File("${dir.path}/$driveId.enc");
      await file.writeAsBytes(combined);

      // ✅ SUCCESS: Stop fake timer and jump to 100%
      _stopSimulation(pdfDbId);
      _updateStatus(pdfDbId, 'success');
      _updateProgress(pdfDbId, 1.0);
      _updateMessage(pdfDbId, "Download Complete! 🎉");
      onComplete(pdfDbId);

    } catch (e) {
      debugPrint("Download Error: $e");
      _stopSimulation(pdfDbId);
      _updateStatus(pdfDbId, 'error');
      _updateProgress(pdfDbId, 0.0);
      _updateMessage(pdfDbId, "Failed. Try again ❌");
    }
  }

  // 🎭 FAKE PROGRESS LOGIC
  void _startSimulation(String id) {
    // 1. Progress Timer (Increments smoothly to 90% over ~60-90 seconds)
    // 0.01 (1%) every 800ms -> 100% in 80 seconds
    _simulationTimers[id] = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      double current = progressNotifier.value[id] ?? 0.0;
      if (current < 0.90) { // Max fake progress 90%
        _updateProgress(id, current + 0.01);
      }
    });

    // 2. Message Timer (Changes text every 4 seconds)
    _messageTimers[id] = Timer.periodic(const Duration(seconds: 4), (timer) {
      final randomMsg = _funnyMessages[Random().nextInt(_funnyMessages.length)];
      _updateMessage(id, randomMsg);
    });
  }

  void _stopSimulation(String id) {
    _simulationTimers[id]?.cancel();
    _messageTimers[id]?.cancel();
    _simulationTimers.remove(id);
    _messageTimers.remove(id);
  }

  void cancelDownload(String pdfDbId) {
    _cancelTokens[pdfDbId] = true;
    _stopSimulation(pdfDbId);
    _updateStatus(pdfDbId, 'cancelled');
    _updateProgress(pdfDbId, 0.0);
  }

  // Helpers
  void _updateProgress(String id, double progress) {
    final newMap = Map<String, double>.from(progressNotifier.value);
    newMap[id] = progress;
    progressNotifier.value = newMap;
  }
  void _updateStatus(String id, String status) {
    final newMap = Map<String, String>.from(statusNotifier.value);
    newMap[id] = status;
    statusNotifier.value = newMap;
  }
  void _updateMessage(String id, String msg) {
    final newMap = Map<String, String>.from(messageNotifier.value);
    newMap[id] = msg;
    messageNotifier.value = newMap;
  }

  Future<String> _getOrGenerateKey(String fileId, SupabaseClient supabase, FlutterSecureStorage storage) async {
    // (Same Logic as before - removed for brevity, assuming you have it)
    // Agar pura code copy kar rahe ho to bata dena, main ye function wapas daal dunga.
    // SHORT VERSION FOR CONTEXT:
    String? localKey = await storage.read(key: "key_$fileId");
    if (localKey != null) return localKey;
    final info = DeviceInfoPlugin();
    String deviceId = Platform.isAndroid ? "${(await info.androidInfo).id}_${(await info.androidInfo).model}" : "ios_device";
    final user = supabase.auth.currentUser!;
    final dbRes = await supabase.from('user_pdf_keys').select('encryption_key').eq('user_id', user.id).eq('pdf_id', fileId).eq('device_id', deviceId).maybeSingle();
    if (dbRes != null) { await storage.write(key: "key_$fileId", value: dbRes['encryption_key']); return dbRes['encryption_key']; }
    final newKey = enc.Key.fromSecureRandom(32).base64;
    await supabase.from('user_pdf_keys').insert({'user_id': user.id, 'pdf_id': fileId, 'device_id': deviceId, 'encryption_key': newKey});
    await storage.write(key: "key_$fileId", value: newKey);
    return newKey;
  }
}

// 🔥🔥 2. UI PART (Notes Page) 🔥🔥
class NotesPage extends StatefulWidget {
  final String unitId;
  const NotesPage({super.key, required this.unitId});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  final _storage = const FlutterSecureStorage();
  final _downloadManager = DownloadManager(); // Instance

  Map<String, dynamic>? unit;
  List<Map<String, dynamic>> pdfs = [];
  bool loading = true;
  Map<String, bool> localStatus = {};

  YoutubePlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _fetchContent();
  }

  Future<void> _fetchContent() async {
    // (Fetch Logic Same as before)
    try {
      final unitRes = await supabase.from('units').select().eq('id', widget.unitId).maybeSingle();
      final pdfRes = await supabase.from('unit_pdfs').select().eq('unit_id', widget.unitId).order('created_at');
      pdfs = List<Map<String, dynamic>>.from(pdfRes);
      unit = unitRes;
      await _checkLocalFiles();
      // Video logic...
      if(mounted) setState(() => loading = false);
    } catch (e) {
      if(mounted) setState(() => loading = false);
    }
  }

  Future<void> _checkLocalFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    for (var pdf in pdfs) {
      final fileId = pdf['pdf_url'];
      final file = File("${dir.path}/$fileId.enc");
      if (await file.exists()) localStatus[pdf['id']] = true;
      else localStatus[pdf['id']] = false;
    }
    if(mounted) setState(() {});
  }

  @override
  void dispose() {
    _videoController?.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
        valueListenable: themeNotifier,
        builder: (context, currentMode, child) {
          final isDark = currentMode == ThemeMode.dark;
          final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
          final textColor = isDark ? Colors.white : const Color(0xFF2D3436);
          final topBarColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

          // (YouTube Player Builder Code - Same as before)
          return Scaffold(
              backgroundColor: bgColor,
              appBar: AppBar(
                backgroundColor: topBarColor,
                leading: IconButton(icon: Icon(Icons.arrow_back_ios_new, color: textColor), onPressed: ()=> Navigator.pop(context)),
                title: Text(unit?['name'] ?? "Notes", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
              ),
              body: loading ? const Center(child: CircularProgressIndicator()) :
              ListView.builder(
                padding: const EdgeInsets.only(bottom: 50),
                itemCount: pdfs.length,
                itemBuilder: (context, index) {
                  return _buildLiveDownloadCard(pdfs[index], isDark, textColor);
                },
              )
          );
        }
    );
  }

  Widget _buildLiveDownloadCard(Map<String, dynamic> pdf, bool isDark, Color textColor) {
    final dbId = pdf['id'];
    final driveId = pdf['pdf_url'];
    final title = pdf['title'];

    return ValueListenableBuilder<Map<String, String>>(
      valueListenable: _downloadManager.statusNotifier,
      builder: (context, statusMap, _) {
        final status = statusMap[dbId] ?? 'idle';
        final isDownloadedLocal = localStatus[dbId] ?? false;

        // Auto-refresh UI on success
        if (status == 'success' && !isDownloadedLocal) {
          localStatus[dbId] = true;
        }

        final isCurrentlyDownloading = status == 'downloading';
        final showOpenButton = (localStatus[dbId] == true);

        return ValueListenableBuilder<Map<String, double>>(
          valueListenable: _downloadManager.progressNotifier,
          builder: (context, progressMap, _) {
            final progress = progressMap[dbId] ?? 0.0;
            final percentage = (progress * 100).toInt();

            // 🔥 Listen to Funny Messages
            return ValueListenableBuilder<Map<String, String>>(
                valueListenable: _downloadManager.messageNotifier,
                builder: (context, messageMap, _) {
                  final currentMessage = messageMap[dbId] ?? "Preparing...";

                  final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: showOpenButton ? Colors.green.withOpacity(0.1) : Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                              child: Icon(showOpenButton ? Icons.check_circle : Icons.cloud_download, color: showOpenButton ? Colors.green : Colors.blue, size: 24),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15)),

                                // 🔥 MESSAGES LOGIC
                                if (isCurrentlyDownloading) ...[
                                  const SizedBox(height: 4),
                                  Text("$currentMessage ($percentage%)", style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
                                ] else if (!showOpenButton)
                                  Text("Tap download to save", style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 12)),

                                if (status == 'error')
                                  const Text("Failed. Tap to retry.", style: TextStyle(color: Colors.red, fontSize: 12)),
                              ]),
                            ),

                            // BUTTONS
                            if (showOpenButton)
                              ElevatedButton(
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PdfViewerPage(title: title, pdfId: driveId))),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                child: const Text("Open", style: TextStyle(color: Colors.white)),
                              )
                            else if (isCurrentlyDownloading)
                              IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => _downloadManager.cancelDownload(dbId))
                            else
                              ElevatedButton(
                                onPressed: () => _downloadManager.startDownload(dbId, driveId, supabase, _storage, (id) { if(mounted) setState(() { localStatus[id] = true; }); }),
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
                                child: const Text("Download", style: TextStyle(color: Colors.white)),
                              )
                          ],
                        ),

                        // 🔥 FAKE SMOOTH PROGRESS BAR
                        if (isCurrentlyDownloading)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: Colors.grey[300],
                                color: const Color(0xFF6C63FF),
                                minHeight: 5, borderRadius: BorderRadius.circular(5)
                            ),
                          )
                      ],
                    ),
                  );
                }
            );
          },
        );
      },
    );
  }
}