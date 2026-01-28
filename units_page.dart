import '../main.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notes_page.dart';
import 'purchase_page.dart';
import '../home_page.dart';

class UnitsPage extends StatefulWidget {
  final String subjectId;

  const UnitsPage({super.key, required this.subjectId});

  @override
  State<UnitsPage> createState() => _UnitsPageState();
}

class _UnitsPageState extends State<UnitsPage> with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  // --- Data Variables ---
  List<Map<String, dynamic>> units = [];
  List<Map<String, dynamic>> purchases = [];
  List<Map<String, dynamic>> accessControlList = []; // 🔥 Store Full Access Info
  String subjectName = "Loading...";
  bool _isLoading = true;

  // --- Animations ---
  late AnimationController _logoInnerCtrl;
  late Animation<double> _logoInnerScale;

  late AnimationController _bgLogoCtrl;
  late Animation<double> _bgLogoScale;

  late AnimationController _textPulseCtrl;
  late Animation<double> _textScaleAnim;

  @override
  void initState() {
    super.initState();
    _fetchData();

    _logoInnerCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _logoInnerScale = Tween<double>(begin: 0.90, end: 1.10).animate(CurvedAnimation(parent: _logoInnerCtrl, curve: Curves.easeInOut));

    _bgLogoCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(reverse: true);
    _bgLogoScale = Tween<double>(begin: 1.0, end: 1.1).animate(CurvedAnimation(parent: _bgLogoCtrl, curve: Curves.easeInOut));

    _textPulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _textScaleAnim = Tween<double>(begin: 1.0, end: 1.15).animate(CurvedAnimation(parent: _textPulseCtrl, curve: Curves.easeInOut));
  }

  Future<void> _fetchData() async {
    try {
      final subjectRes = await supabase.from('subjects').select('name').eq('id', widget.subjectId).single();
      final unitsRes = await supabase.from('units').select().eq('subject_id', widget.subjectId).order('order_index');

      final user = supabase.auth.currentUser;
      List<Map<String, dynamic>> purchasesRes = [];
      List<Map<String, dynamic>> accessRes = [];

      if (user != null) {
        // 1. Purchases Check
        final pData = await supabase.from('purchases').select('unit_id').eq('user_id', user.id);
        purchasesRes = List<Map<String, dynamic>>.from(pData);

        // 2. 🔥 Access Control Check (For Lock Status, Gifts & REASON)
        final aData = await supabase.from('student_access_control').select('unit_id, access_status, lock_reason').eq('user_id', user.id);
        accessRes = List<Map<String, dynamic>>.from(aData);
      }

      if (mounted) {
        setState(() {
          subjectName = subjectRes['name'] ?? "Subject Units";
          units = List<Map<String, dynamic>>.from(unitsRes);
          purchases = purchasesRes;
          accessControlList = accessRes;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🔥 HELPER: Get Access Info (Crash Proof Logic)
  Map<String, dynamic> getUnitStatus(String unitId) {
    // 1. Check Purchases (Safely using Loop)
    bool isPurchased = false;
    for (var p in purchases) {
      if (p['unit_id'].toString() == unitId.toString()) {
        isPurchased = true;
        break;
      }
    }

    // 2. Check Access Control (Safely using Loop)
    Map<String, dynamic>? accessEntry;
    for (var a in accessControlList) {
      if (a['unit_id'].toString() == unitId.toString()) {
        accessEntry = a;
        break;
      }
    }

    // 🔥 LOGIC: Gift vs Purchase vs Lock
    // Agar Access Control mein entry hai aur status LOCKED hai -> Locked
    bool isLocked = (accessEntry != null && accessEntry['access_status'] == 'LOCKED');

    // Reason uthao (agar locked hai)
    String lockReason = accessEntry?['lock_reason'] ?? "Access to this unit has been restricted by Admin.";

    // Gifted tabhi manenge jab Purchased NA ho aur Access Control mein ho (aur Locked na ho to better hai, par display ke liye logic alag hai)
    bool isGifted = (accessEntry != null) && !isPurchased;

    // Access tabhi milega jab (Purchased HO ya Gifted HO) aur Locked NA HO
    bool hasAccess = (isPurchased || accessEntry != null);

    return {
      'hasAccess': hasAccess,
      'isGifted': isGifted,
      'isLocked': isLocked,
      'lockReason': lockReason,
      'isPurchased': isPurchased // UI ke liye flag
    };
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
    // Laptop view logic removed. Always treating as mobile.

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        final isDark = currentMode == ThemeMode.dark;
        final bgColor = isDark ? Colors.black : const Color(0xFFF5F7FA);
        final textColor = isDark ? Colors.white : const Color(0xFF2D3436);
        final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        final borderColor = isDark ? Colors.white10 : Colors.black12;
        final bgLogo = isDark ? "assets/WApplogo.png" : "assets/Applogo.png";
        final quoteBgStart = isDark ? const Color(0xFF2C0000) : const Color(0xFFEEF2FF);
        final quoteBgEnd = isDark ? Colors.black : Colors.white;

        return Theme(
          data: Theme.of(context).copyWith(
            textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Tinos', bodyColor: textColor),
            iconTheme: IconThemeData(color: textColor),
          ),
          child: Scaffold(
            backgroundColor: bgColor,
            body: Stack(
              children: [
                Positioned(
                  bottom: 50, left: 0, right: 0,
                  child: GestureDetector(
                    onTap: () { themeNotifier.value = themeNotifier.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark; },
                    child: SizedBox(
                      height: size.height * 0.40,
                      child: ScaleTransition(scale: _bgLogoScale, child: Opacity(opacity: 0.05, child: Image.asset(bgLogo, fit: BoxFit.contain, alignment: Alignment.bottomCenter))),
                    ),
                  ),
                ),
                Column(
                  children: [
                    _buildFixedTopBar(context, isDark, textColor),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            _buildHeroHeader(context, isDark, textColor, quoteBgStart, quoteBgEnd, borderColor),
                            _isLoading
                                ? const Padding(padding: EdgeInsets.all(50), child: Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF))))
                                : units.isEmpty
                                ? Padding(padding: const EdgeInsets.all(50), child: Center(child: Text("No units added yet.", style: TextStyle(color: textColor))))
                                : LayoutBuilder(
                              builder: (context, constraints) {
                                double screenWidth = constraints.maxWidth;
                                // 🔥 UPDATED: Always Mobile View (1 Column)
                                int crossAxisCount = 1;
                                double padding = 20; double spacing = 15;
                                double cardWidth = (screenWidth - (padding * 2) - (spacing * (crossAxisCount - 1))) / crossAxisCount;
                                double imageHeight = cardWidth / (16/9);
                                double totalCardHeight = imageHeight + 120;

                                return GridView.builder(
                                  padding: EdgeInsets.symmetric(horizontal: padding, vertical: 20),
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: crossAxisCount, crossAxisSpacing: spacing, mainAxisSpacing: spacing, mainAxisExtent: totalCardHeight),
                                  itemCount: units.length,
                                  itemBuilder: (context, index) {
                                    return _buildUnitCard(units[index], index, isDark, cardColor, textColor);
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

  Widget _buildFixedTopBar(BuildContext context, bool isDark, Color textColor) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, left: 10, right: 10, bottom: 10),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF121212) : Colors.white, border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12, width: 1)), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))]),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        IconButton(icon: Icon(Icons.arrow_back_ios_new, size: 22, color: textColor), onPressed: () => Navigator.pop(context)),
        // Always using Mobile Title Logic
        Expanded(child: Center(child: _buildDynamicTitle(subjectName, textColor))),
        IconButton(icon: const Icon(Icons.home_rounded, size: 26, color: Color(0xFF6C63FF)), onPressed: () { Navigator.of(context).popUntil((route) => route.isFirst); })
      ]),
    );
  }

  // Simplified for Mobile View
  Widget _buildDynamicTitle(String subjectText, Color textColor) {
    List<InlineSpan> spans = []; spans.addAll(_generateFancySpans(subjectText, textColor));
    // Laptop-specific "By Engineering Express" text removed
    return RichText(maxLines: 1, overflow: TextOverflow.ellipsis, text: TextSpan(style: const TextStyle(fontFamily: 'Tinos'), children: spans));
  }

  List<TextSpan> _generateFancySpans(String text, Color textColor) {
    List<String> words = text.trim().toLowerCase().split(" "); List<TextSpan> result = [];
    for (String word in words) { if (word.isNotEmpty) { String firstChar = word[0].toUpperCase(); String rest = word.length > 1 ? word.substring(1) : ""; result.add(TextSpan(text: firstChar, style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 20, fontWeight: FontWeight.bold))); result.add(TextSpan(text: "$rest ", style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold))); } }
    return result;
  }

  Widget _buildHeroHeader(BuildContext context, bool isDark, Color textColor, Color bgStart, Color bgEnd, Color borderColor) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.fromLTRB(20, 15, 20, 25),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [bgStart, bgEnd], begin: Alignment.topCenter, end: Alignment.bottomCenter), borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)), boxShadow: [BoxShadow(color: isDark ? Colors.black : const Color(0xFF6C63FF).withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(child: Text("Master this subject \nUnit by Unit! 🎯", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textColor, height: 1.2, fontFamily: "Tinos"))),
          const SizedBox(width: 15),
          // Always showing Mobile Logo
          GestureDetector(onTap: () { themeNotifier.value = themeNotifier.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark; setState(() {}); }, child: ScaleTransition(scale: _logoInnerScale, child: Image.asset("assets/logo.png", height: 100, width: 100, fit: BoxFit.contain))),
        ]),
        const SizedBox(height: 20),
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: borderColor)), child: Row(children: [const Icon(Icons.emoji_events, color: Colors.amber, size: 24), const SizedBox(width: 12), Expanded(child: Text("Complete all units to unlock full potential!", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)))]))
      ]),
    );
  }

  // ================= 🔥 UPDATED UNIT CARD LOGIC =================
  Widget _buildUnitCard(Map<String, dynamic> unit, int index, bool isDark, Color cardColor, Color textColor) {
    // 1. Get Status Info
    Map<String, dynamic> status = getUnitStatus(unit['id'].toString());
    bool hasAccess = status['hasAccess'];
    bool isGifted = status['isGifted'];
    bool isLocked = status['isLocked'];
    String lockReason = status['lockReason'] ?? "";
    bool isPurchased = status['isPurchased'];

    bool isFree = (unit['price'] == null || unit['price'] == 0);
    // Access tabhi maana jayega jab Free ho ya DB se Access mila ho
    bool isUnlocked = isFree || hasAccess;

    return Container(
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // IMAGE 16:9
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  unit['image_url'] != null ? Image.network(unit['image_url'], fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey.shade100, child: const Icon(Icons.broken_image))) : Container(color: Colors.grey.shade100, child: const Icon(Icons.menu_book, size: 50, color: Colors.grey)),

                  // 🔥 Status Badge Logic
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isLocked ? Colors.red : (isGifted ? Colors.purple : (isPurchased ? Colors.blue : (isUnlocked ? Colors.green : Colors.black87))),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(isLocked ? Icons.lock : (isUnlocked ? Icons.check_circle : Icons.lock_outline), color: Colors.white, size: 10),
                          const SizedBox(width: 4),
                          Text(
                            isLocked ? "LOCKED 🚫" : (isGifted ? "GIFTED 🎁" : (isPurchased ? "OWNED ✅" : (isUnlocked ? "UNLOCKED" : "LOCKED"))),
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),

          // CONTENT
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildFancyName(unit['name'] ?? "Unit", textColor),

                  // BUTTONS ROW
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 36,
                          child: isUnlocked
                              ? ElevatedButton.icon(
                            onPressed: () {
                              // 🔥🔥 THE MAIN LOGIC 🔥🔥
                              if (isLocked) {
                                // 🔒 Show Locked Dialog with ADMIN REASON
                                showDialog(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    backgroundColor: Colors.red.shade50,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                    title: const Row(children: [Icon(Icons.gpp_bad, color: Colors.red), SizedBox(width: 10), Text("Access Denied", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))]),
                                    content: Text(lockReason, style: const TextStyle(color: Colors.black,fontSize: 15, fontFamily: 'Tinos')),
                                    actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("Close", style: TextStyle(color: Colors.red)))],
                                  ),
                                );
                              } else {
                                // ✅ Open Normally
                                Navigator.push(context, MaterialPageRoute(builder: (_) => NotesPage(unitId: unit['id'])));
                              }
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: isLocked ? Colors.red : const Color(0xFF10B981), foregroundColor: Colors.white, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            icon: Icon(isLocked ? Icons.lock : Icons.play_arrow_rounded, size: 16),
                            label: ScaleTransition(
                              scale: _textScaleAnim,
                              child: Text(isLocked ? "Locked" : "Open", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                          )
                              : ElevatedButton.icon(
                            onPressed: () async {
                              final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => PurchasePage(unitId: unit['id'], subjectId: widget.subjectId, price: unit['price'])));
                              if (result == true) { _fetchData(); if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Success! Unit Unlocked 🔓"))); }
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), foregroundColor: Colors.white, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            icon: const Icon(Icons.shopping_cart_outlined, size: 16),
                            label: ScaleTransition(
                              scale: _textScaleAnim,
                              child: Text("₹${unit['price']}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFancyName(String text, Color textColor) {
    List<String> words = text.trim().toLowerCase().split(" "); List<InlineSpan> spans = [];
    for (String word in words) { if (word.isNotEmpty) { String firstChar = word[0].toUpperCase(); String rest = word.length > 1 ? word.substring(1) : ""; spans.add(TextSpan(text: firstChar, style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 17, fontWeight: FontWeight.bold))); spans.add(TextSpan(text: "$rest ", style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold))); } }
    return RichText(maxLines: 2, overflow: TextOverflow.ellipsis, text: TextSpan(style: const TextStyle(fontFamily: 'Tinos'), children: spans));
  }
}