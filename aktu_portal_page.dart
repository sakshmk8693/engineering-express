import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../main.dart'; // Theme notifier ke liye

// 🔥 Naya Browser Class (Result ke loop se bachne ke liye)
class MyChromeBrowser extends ChromeSafariBrowser {
  @override
  void onOpened() => debugPrint("Chrome Browser Opened");
  @override
  void onClosed() => debugPrint("Chrome Browser Closed");
}

class AktuPortalPage extends StatefulWidget {
  final String initialUrl;
  final String title;

  const AktuPortalPage({super.key, required this.title, required this.initialUrl});

  @override
  State<AktuPortalPage> createState() => _AktuPortalPageState();
}

class _AktuPortalPageState extends State<AktuPortalPage> {
  InAppWebViewController? _webViewController;
  final MyChromeBrowser _browser = MyChromeBrowser();
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    // 🔥 Agar "RESULT" hai, to bina der kiye Chrome Tab kholo
    if (widget.title.toUpperCase().contains("RESULT")) {
      _openChromeTab(widget.initialUrl);
    }
  }

  // 🔥 ERROR-FREE CHROME TAB SETTINGS
  Future<void> _openChromeTab(String url) async {
    try {
      await _browser.open(
        url: WebUri(url),
        settings: ChromeSafariBrowserSettings(
          // 🛠️ Maine saare problematic parameters (shareable, displayMode) hata diye hain.
          // Ye version-safe settings hain:
          showTitle: true,
          toolbarBackgroundColor: const Color(0xFF1E1E1E),
          enableUrlBarHiding: true,
        ),
      );
      // Jab user "Done" dabaye, to humein wapas HomePage par jana chahiye
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Browser Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🪙 RESULT ke liye sirf Sikka dikhao kyunki browser alag window mein khulega
    if (widget.title.toUpperCase().contains("RESULT")) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CoinFlipLoader()),
      );
    }

    // 📜 NOTICES ke liye standard WebView
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        final isDark = currentMode == ThemeMode.dark;
        final textColor = isDark ? Colors.white : Colors.black87;

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            elevation: 0,
            centerTitle: true,
            title: Text(widget.title, style: TextStyle(fontFamily: 'Tinos', fontWeight: FontWeight.bold, color: textColor)),
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: textColor),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Stack(
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(widget.initialUrl)),
                onWebViewCreated: (controller) => _webViewController = controller,
                onLoadStart: (c, u) => setState(() => isLoading = true),
                onLoadStop: (c, u) => setState(() => isLoading = false),
              ),
              if (isLoading)
                Container(
                    color: isDark ? const Color(0xFF121212) : Colors.white,
                    child: const Center(child: CoinFlipLoader())
                ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------
// 🪙 COIN LOADER (Engineering Express & AKTU Sikka)
// ---------------------------------------------------------
class CoinFlipLoader extends StatefulWidget {
  const CoinFlipLoader({super.key});
  @override State<CoinFlipLoader> createState() => _CoinFlipLoaderState();
}
class _CoinFlipLoaderState extends State<CoinFlipLoader> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override void initState() {
    super.initState();
    _c = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this)..repeat();
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        // Sikka ghumne par kounsi side dikhegi
        bool showFront = _c.value < 0.25 || _c.value > 0.75;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..setEntry(3, 2, 0.002)..rotateY(_c.value * 2 * 3.14159),
          child: Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(
                    image: AssetImage(showFront ? "assets/logo.png" : "assets/AKTU.png")
                )
            ),
          ),
        );
      },
    );
  }
}