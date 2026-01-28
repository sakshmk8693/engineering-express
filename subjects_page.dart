import '../main.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'units_page.dart';
import '../home_page.dart'; // ✅ Import Home Page for Dark Mode Notifier

class SubjectsPage extends StatefulWidget {
  final String branchId;
  final String yearTitle;

  const SubjectsPage({
    super.key,
    required this.branchId,
    required this.yearTitle,
  });

  @override
  State<SubjectsPage> createState() => _SubjectsPageState();
}

class _SubjectsPageState extends State<SubjectsPage> with TickerProviderStateMixin {

  // --- Search Variables ---
  List<dynamic> _allSubjects = [];
  List<dynamic> _foundSubjects = [];
  bool _isLoading = true;

  // --- Animations ---
  late AnimationController _logoInnerCtrl;
  late Animation<double> _logoInnerScale;

  late AnimationController _bgLogoCtrl;
  late Animation<double> _bgLogoScale;

  // Text Pulse Animation
  late AnimationController _textPulseCtrl;
  late Animation<double> _textScaleAnim;

  @override
  void initState() {
    super.initState();
    _fetchSubjects();

    // 1. Logo Animation
    _logoInnerCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _logoInnerScale = Tween<double>(begin: 0.90, end: 1.10).animate(CurvedAnimation(parent: _logoInnerCtrl, curve: Curves.easeInOut));

    // 2. Background Breathing
    _bgLogoCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(reverse: true);
    _bgLogoScale = Tween<double>(begin: 1.0, end: 1.1).animate(CurvedAnimation(parent: _bgLogoCtrl, curve: Curves.easeInOut));

    // 3. Text Pulse
    _textPulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _textScaleAnim = Tween<double>(begin: 1.0, end: 1.15).animate(CurvedAnimation(parent: _textPulseCtrl, curve: Curves.easeInOut));
  }

  Future<void> _fetchSubjects() async {
    try {
      final response = await Supabase.instance.client
          .from('subjects')
          .select()
          .eq('branch_id', widget.branchId)
          .order('name');

      setState(() {
        _allSubjects = response;
        _foundSubjects = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Error fetching subjects: $e");
    }
  }

  void _runFilter(String enteredKeyword) {
    List<dynamic> results = [];
    if (enteredKeyword.isEmpty) {
      results = _allSubjects;
    } else {
      results = _allSubjects
          .where((subject) =>
          subject["name"].toLowerCase().contains(enteredKeyword.toLowerCase()))
          .toList();
    }
    setState(() {
      _foundSubjects = results;
    });
  }

  @override
  void dispose() {
    _logoInnerCtrl.dispose();
    _bgLogoCtrl.dispose();
    _textPulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    // 🔥 Dark Mode Listener
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        final isDark = currentMode == ThemeMode.dark;
        final bgColor = isDark ? Colors.black : const Color(0xFFF5F7FA);
        final textColor = isDark ? Colors.white : const Color(0xFF2D3436);
        final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        final borderColor = isDark ? Colors.white10 : Colors.black12;
        final bgLogo = isDark ? "assets/WApplogo.png" : "assets/Applogo.png";

        final searchFillColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;
        final searchHintColor = isDark ? Colors.grey : Colors.grey;

        return Theme(
          data: Theme.of(context).copyWith(
            textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Tinos', bodyColor: textColor),
            iconTheme: IconThemeData(color: textColor),
          ),
          child: Scaffold(
            backgroundColor: bgColor,
            body: Stack(
              children: [
                // ✅ BACKGROUND LOGO (Magic Button #1)
                Positioned(
                  bottom: 60,
                  left: 0, right: 0,
                  child: GestureDetector(
                    onTap: () {
                      // 🔥 Toggle Theme
                      themeNotifier.value = themeNotifier.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
                      },
                    child: SizedBox(
                      height: size.height * 0.35,
                      child: ScaleTransition(
                        scale: _bgLogoScale,
                        child: Opacity(
                          opacity: 0.05,
                          child: Image.asset(
                            bgLogo,
                            fit: BoxFit.contain,
                            alignment: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                Column(
                  children: [
                    // ✅ 1. FIXED TOP BAR
                    _buildFixedTopBar(context, isMobile, isDark, textColor),

                    // ✅ 2. SCROLLABLE AREA
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            // A. Quote Header (With Magic Button #2)
                            _buildQuoteHeader(context, isMobile, isDark, textColor, searchFillColor, searchHintColor, borderColor),

                            // B. The Grid
                            _isLoading
                                ? const Padding(
                              padding: EdgeInsets.all(50),
                              child: Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF))),
                            )
                                : _foundSubjects.isEmpty
                                ? Padding(
                              padding: const EdgeInsets.all(50),
                              child: Center(child: Text("No subjects found", style: TextStyle(fontSize: 16, color: textColor))),
                            )
                                : LayoutBuilder(
                              builder: (context, constraints) {
                                double screenWidth = constraints.maxWidth;

                                int crossAxisCount;
                                if (screenWidth < 600) {
                                  crossAxisCount = 1;
                                } else if (screenWidth < 1000) {
                                  crossAxisCount = 3;
                                } else {
                                  crossAxisCount = 6;
                                }

                                double padding = 20;
                                double spacing = 15;
                                double cardWidth = (screenWidth - (padding * 2) - (spacing * (crossAxisCount - 1))) / crossAxisCount;
                                double imageHeight = cardWidth / (16/9);
                                double totalCardHeight = imageHeight + 108;

                                return GridView.builder(
                                  padding: EdgeInsets.symmetric(horizontal: padding, vertical: 20),
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    crossAxisSpacing: spacing,
                                    mainAxisSpacing: spacing,
                                    mainAxisExtent: totalCardHeight,
                                  ),
                                  itemCount: _foundSubjects.length,
                                  itemBuilder: (context, index) {
                                    return _SubjectCard(
                                      subject: _foundSubjects[index],
                                      textScaleAnim: _textScaleAnim,
                                      isDark: isDark,
                                      cardColor: cardColor,
                                      textColor: textColor,
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ✅ HEADER
  Widget _buildFixedTopBar(BuildContext context, bool isMobile, bool isDark, Color textColor) {
    return Container(
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 10,
          left: 15, right: 15, bottom: 10
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12, width: 1)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, size: 22, color: textColor),
            onPressed: () => Navigator.pop(context),
          ),

          Expanded(
            child: Center(
              child: isMobile
                  ? // MOBILE
              Text(
                widget.yearTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    fontFamily: "Tinos"
                ),
              )
                  : // LAPTOP
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontFamily: 'Tinos', fontSize: 18, fontWeight: FontWeight.bold),
                  children: [
                    TextSpan(text: "${widget.yearTitle} By ", style: TextStyle(color: textColor)),
                    const TextSpan(text: "E", style: TextStyle(color: Color(0xFFD32F2F), fontSize: 22)),
                    TextSpan(text: "ngineering ", style: TextStyle(color: textColor)),
                    const TextSpan(text: "E", style: TextStyle(color: Color(0xFFD32F2F), fontSize: 22)),
                    TextSpan(text: "xpress", style: TextStyle(color: textColor)),
                  ],
                ),
              ),
            ),
          ),

          IconButton(
            icon: const Icon(Icons.home_rounded, size: 26, color: Color(0xFF6C63FF)),
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
    );
  }

  // ✅ QUOTE HEADER (With MAGIC BUTTON #2)
  Widget _buildQuoteHeader(BuildContext context, bool isMobile, bool isDark, Color textColor, Color searchFill, Color searchHint, Color borderColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 25),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF2A0361), Colors.black]
              : [const Color(0xFFEEF2FF), Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(color: isDark ? Colors.black : const Color(0xFF6C63FF).withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  "What do you want \nto learn today? 🚀",
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, color: textColor,
                      height: 1.2, fontFamily: "Tinos"
                  ),
                ),
              ),
              const SizedBox(width: 15),

              // ✅ LOGO IS NOW MAGIC THEME TOGGLE
              GestureDetector(
                onTap: () {
                  // 🔥 YE RAHA NAYA MAGIC CODE
                  themeNotifier.value = themeNotifier.value == ThemeMode.dark
                      ? ThemeMode.light
                      : ThemeMode.dark;

                  // Page refresh karne ke liye (agar zaroorat ho)
                  setState(() {});
                },
                child: isMobile
                    ? ScaleTransition(
                  scale: _logoInnerScale,
                  child: Image.asset("assets/logo.png", height: 100, width: 100, fit: BoxFit.contain),
                )
                    : Container(
                  width: 160,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 4))],
                    border: Border.all(color: borderColor),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ScaleTransition(
                        scale: _logoInnerScale,
                        child: Image.asset(isDark ? "assets/WApplogo.png" : "assets/Applogo.png", fit: BoxFit.contain),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // SEARCH BAR
          TextField(
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
            ],
            onChanged: (value) => _runFilter(value),
            style: TextStyle(fontFamily: "Tinos", color: textColor),
            decoration: InputDecoration(
              hintText: "Search subjects...",
              hintStyle: TextStyle(fontFamily: "Tinos", color: searchHint),
              prefixIcon: Icon(Icons.search, color: searchHint),
              filled: true,
              fillColor: searchFill,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final dynamic subject;
  final Animation<double> textScaleAnim;
  final bool isDark;
  final Color cardColor;
  final Color textColor;

  const _SubjectCard({
    required this.subject,
    required this.textScaleAnim,
    required this.isDark,
    required this.cardColor,
    required this.textColor,
  });

  // Helper Function for Fancy Text
  Widget _buildFancyName(String text) {
    List<String> words = text.toLowerCase().split(" ");
    List<InlineSpan> spans = [];

    for (String word in words) {
      if (word.isNotEmpty) {
        String firstChar = word[0].toUpperCase();
        String rest = word.substring(1);

        spans.add(TextSpan(
          text: firstChar,
          style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 17, fontWeight: FontWeight.bold),
        ));
        spans.add(TextSpan(
          text: "$rest ",
          style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
        ));
      }
    }

    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(fontFamily: 'Tinos'),
        children: spans,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // IMAGE SECTION (16:9)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: subject['image_url'] != null
                  ? Image.network(subject['image_url'], fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey.shade100, child: const Icon(Icons.broken_image)))
                  : Container(color: Colors.blueGrey.shade50),
            ),
          ),

          // CONTENT SECTION
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 1. FANCY SUBJECT NAME
                  _buildFancyName(subject['name'] ?? "Subject"),

                  // 2. FIXED BUTTON BOX
                  SizedBox(
                    width: double.infinity,
                    height: 36,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => UnitsPage(subjectId: subject['id'])));
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: EdgeInsets.zero
                      ),
                      child: ScaleTransition(
                        scale: textScaleAnim,
                        child: const Text("View Unit's", style: TextStyle(fontWeight: FontWeight.w600, fontFamily: "Tinos", fontSize: 13)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}