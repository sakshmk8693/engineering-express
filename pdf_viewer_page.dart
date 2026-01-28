import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Rotation ke liye
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class PdfViewerPage extends StatefulWidget {
  final String title;
  final String? driveFileId;
  final String? pdfId;

  const PdfViewerPage({
    super.key,
    required this.title,
    this.driveFileId,
    this.pdfId,
  });

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  File? file;
  bool loading = true;
  String errorMessage = '';

  // Header State
  bool _showHeader = true;
  int _viewMode = 0; // 0:Normal, 1:Invert(Night), 2:Dark(Eye Comfort)

  // 🔥 CONFIG
  final int watermarkCount = 8;
  final double watermarkOpacity = 0.12;
  String watermarkText = "Protected Content";

  // 🔐 SECURITY
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    // 🔄 ALLOW ROTATION (Landscape & Portrait)
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _fetchUserInfo();
    _secureLoadProcess();
  }

  @override
  void dispose() {
    // 🔄 RESET ROTATION (Wapas Portrait kar do jab back jaye)
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  Future<void> _fetchUserInfo() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        String info = "${user.userMetadata?['name'] ?? 'User'}\n${user.email ?? ''}\n${user.userMetadata?['phone'] ?? ''}";
        if(mounted) setState(() => watermarkText = info);
      }
    } catch (_) {}
  }

  // ... (BAAKI KA LOADING LOGIC SAME RAHEGA - Download/Decrypt) ...
  // Main niche Build method mein changes kar raha hoon

  // 🧠 MAIN LOADING LOGIC (Same as before)
  Future<void> _secureLoadProcess() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      String fileId = widget.pdfId ?? widget.title.hashCode.toString();
      final encryptedFile = File("${dir.path}/$fileId.enc");

      if (await encryptedFile.exists()) {
        await _decryptAndOpen(encryptedFile, fileId);
      } else {
        if (widget.driveFileId == null) throw Exception("File missing locally & no ID provided.");
        await _downloadAndEncrypt(encryptedFile, fileId);
      }
    } catch (e) {
      if(mounted) setState(() { errorMessage = "Error: $e"; loading = false; });
    }
  }

  Future<void> _downloadAndEncrypt(File targetFile, String fileId) async {
    try {
      String keyString = await _getOrGenerateKey(fileId);

      const String projectUrl = 'https://trwjnnufszkwyfbocrzm.supabase.co';
      final functionUrl = Uri.parse('$projectUrl/functions/v1/get-drive-file');

      final session = Supabase.instance.client.auth.currentSession;
      final headers = {
        'Authorization': 'Bearer ${session?.accessToken ?? ""}',
        'Content-Type': 'application/json',
      };

      final res = await http.post(
        functionUrl,
        headers: headers,
        body: '{"file_id": "${widget.driveFileId}"}',
      );

      if (res.statusCode != 200) throw Exception("Download Failed: ${res.statusCode}");

      final key = enc.Key.fromBase64(keyString);
      final iv = enc.IV.fromLength(16);
      final encrypter = enc.Encrypter(enc.AES(key));

      final encrypted = encrypter.encryptBytes(res.bodyBytes, iv: iv);
      final combined = [...iv.bytes, ...encrypted.bytes];
      await targetFile.writeAsBytes(combined);

      await _decryptAndOpen(targetFile, fileId);
    } catch (e) {
      throw Exception("Download/Encrypt Error: $e");
    }
  }

  Future<void> _decryptAndOpen(File encryptedFile, String fileId) async {
    try {
      String keyString = await _getKeySafe(fileId);
      final key = enc.Key.fromBase64(keyString);
      final fileBytes = await encryptedFile.readAsBytes();

      final ivBytes = fileBytes.sublist(0, 16);
      final dataBytes = fileBytes.sublist(16);

      final iv = enc.IV(ivBytes);
      final encrypter = enc.Encrypter(enc.AES(key));
      final decrypted = encrypter.decryptBytes(enc.Encrypted(dataBytes), iv: iv);

      final tempDir = await getTemporaryDirectory();
      final tempFile = File("${tempDir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.pdf");
      await tempFile.writeAsBytes(decrypted);

      if(mounted) setState(() { file = tempFile; loading = false; });
    } catch (e) {
      await encryptedFile.delete();
      throw Exception("Decryption Failed. Re-downloading...");
    }
  }

  Future<String> _getOrGenerateKey(String fileId) async {
    String? localKey = await _storage.read(key: "key_$fileId");
    if (localKey != null) return localKey;

    final deviceId = await _getDeviceId();
    final user = Supabase.instance.client.auth.currentUser;
    if(user == null) throw Exception("User not logged in");

    final dbRes = await Supabase.instance.client
        .from('user_pdf_keys')
        .select('encryption_key')
        .eq('user_id', user.id)
        .eq('pdf_id', fileId)
        .eq('device_id', deviceId)
        .maybeSingle();

    if (dbRes != null) {
      await _storage.write(key: "key_$fileId", value: dbRes['encryption_key']);
      return dbRes['encryption_key'];
    }

    final newKey = enc.Key.fromSecureRandom(32).base64;
    await Supabase.instance.client.from('user_pdf_keys').insert({
      'user_id': user.id, 'pdf_id': fileId, 'device_id': deviceId, 'encryption_key': newKey
    });
    await _storage.write(key: "key_$fileId", value: newKey);
    return newKey;
  }

  Future<String> _getKeySafe(String fileId) async {
    String? localKey = await _storage.read(key: "key_$fileId");
    if (localKey != null) return localKey;

    try {
      final connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult.contains(ConnectivityResult.none)) throw Exception("No Internet");
      return await _getOrGenerateKey(fileId);
    } catch (_) {
      throw Exception("Key missing & Offline.");
    }
  }

  Future<String> _getDeviceId() async {
    final info = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final android = await info.androidInfo;
      return "${android.id}_${android.model}";
    } else {
      final ios = await info.iosInfo;
      return ios.identifierForVendor ?? 'unknown_ios';
    }
  }

  // ================= 🔥 UPDATED UI STARTS HERE =================

  @override
  Widget build(BuildContext context) {
    // Mode 0: White, Mode 1: Black (Night), Mode 2: Dark Grey (Comfort)
    final bgColor = _viewMode == 0 ? Colors.white : (_viewMode == 1 ? Colors.black : const Color(0xFF1E1E1E));

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          if (loading) _buildLoading()
          else if (errorMessage.isNotEmpty) _buildError()
          else _buildFilteredPdfView(), // Gesture handling removed from here to separate Listener

          if (!loading && file != null) _buildWatermarkGrid(),

          // 🔥 HEADER ANIMATION
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            top: _showHeader ? 0 : -100, // Chupaane ka logic
            left: 0,
            right: 0,
            child: _buildCustomHeader(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredPdfView() {
    Widget pdfWidget = Listener(
      // 🔥 SCROLL DETECTION LOGIC
      onPointerMove: (details) {
        // Agar ungli niche ja rahi hai (Matlab page UPAR ja raha hai, padhne ke liye) -> Hide Header
        if (details.delta.dy < -5) {
          if (_showHeader) setState(() => _showHeader = false);
        }
        // Agar ungli upar ja rahi hai (Matlab page NICHE aa raha hai, wapas aane ke liye) -> Show Header
        else if (details.delta.dy > 5) {
          if (!_showHeader) setState(() => _showHeader = true);
        }
      },
      child: PDFView(
        filePath: file!.path,
        enableSwipe: true,
        swipeHorizontal: false, // Vertical scroll
        autoSpacing: false,
        pageFling: true, // Smooth fling enabled
        onError: (e) => setState(() => errorMessage = e.toString()),
        onPageChanged: (page, total) {}, // Optional: Page number track karne ke liye
      ),
    );

    // 🔥 COLOR MODES
    if (_viewMode == 1) { // High Contrast Night (Inverted)
      return ColorFiltered(
        // Standard Invert Matrix: White->Black, Text Black->White
        // Note: PDF me selective color change possible nahi hota bina re-rendering ke.
        // Ye best "Night Mode" hai jo text readable rakhta hai.
        colorFilter: const ColorFilter.matrix([
          -1,  0,  0, 0, 255,
          0, -1,  0, 0, 255,
          0,  0, -1, 0, 255,
          0,  0,  0, 1,   0,
        ]),
        child: pdfWidget,
      );
    } else if (_viewMode == 2) { // Eye Comfort (Sepia/Dark Dim)
      // Ye mode colors ko invert nahi karega, bas brightness kam karega
      // Red aur Blue apne asli rang mein rahenge, bas thode dark.
      return ColorFiltered(
        colorFilter: const ColorFilter.mode(
            Colors.black12, // Halka sa andhera
            BlendMode.darken
        ),
        child: pdfWidget,
      );
    }
    return pdfWidget; // Normal Mode
  }

  Widget _buildWatermarkGrid() {
    // Watermark color modes ke hisab se adjust hoga
    final textColor = _viewMode == 0
        ? Colors.black.withOpacity(watermarkOpacity)
        : Colors.white.withOpacity(watermarkOpacity + 0.05);

    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: Colors.transparent,
          child: LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = 2;
                int rows = (watermarkCount / crossAxisCount).ceil();
                double ratio = (constraints.maxWidth / crossAxisCount) / (constraints.maxHeight / rows);

                return GridView.builder(
                  itemCount: watermarkCount,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: ratio,
                  ),
                  itemBuilder: (context, index) {
                    return Center(
                      child: Transform.rotate(
                        angle: -0.5,
                        child: Text(
                          watermarkText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Tinos',
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    );
                  },
                );
              }
          ),
        ),
      ),
    );
  }

  Widget _buildCustomHeader() {
    return Container(
      height: 90,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, left: 10, right: 10, bottom: 10),
      decoration: BoxDecoration(
        // Header Color Logic
        color: _viewMode == 1 ? const Color(0xFF1E1E1E) : const Color(0xFF6C63FF), // Purple in normal/dark mode
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)],
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        children: [
          IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context)
          ),
          Expanded(
              child: Text(
                  widget.title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Tinos'
                  )
              )
          ),
          // Toggle Modes Button
          IconButton(
            tooltip: "Change View Mode",
            icon: Icon(
                _viewMode == 0 ? Icons.wb_sunny : (_viewMode == 1 ? Icons.nightlight_round : Icons.remove_red_eye),
                color: Colors.white
            ),
            onPressed: () {
              setState(() {
                _viewMode = (_viewMode + 1) % 3; // Cycle: 0 -> 1 -> 2 -> 0
              });
              // User feedback
              String modeName = _viewMode == 0 ? "Normal" : (_viewMode == 1 ? "Night (Inverted)" : "Eye Comfort");
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Mode: $modeName"), duration: const Duration(seconds: 1)));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.deepPurpleAccent, strokeWidth: 3),
          const SizedBox(height: 20),
          Text("Securing Content...", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Tinos', color: _viewMode==1?Colors.white:Colors.black)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 50),
          const SizedBox(height: 10),
          Text(errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontFamily: 'Tinos')),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: (){ setState(() { loading=true; errorMessage=''; }); _secureLoadProcess(); }, child: const Text("Retry", style: TextStyle(fontFamily: 'Tinos')))
        ],
      ),
    );
  }
}