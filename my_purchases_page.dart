import '../main.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notes_page.dart';
import '../home_page.dart';

class MyPurchasesPage extends StatefulWidget {
  const MyPurchasesPage({super.key});

  @override
  State<MyPurchasesPage> createState() => _MyPurchasesPageState();
}

class _MyPurchasesPageState extends State<MyPurchasesPage> with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  List<Map<String, dynamic>> combinedLibrary = [];
  int giftCount = 0;

  // --- Animations ---
  late AnimationController _bgLogoCtrl;
  late Animation<double> _bgLogoScale;
  late AnimationController _logoPulseCtrl;
  late Animation<double> _logoScale;

  @override
  void initState() {
    super.initState();
    fetchMyLibrary();

    _bgLogoCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(reverse: true);
    _bgLogoScale = Tween<double>(begin: 1.0, end: 1.1).animate(CurvedAnimation(parent: _bgLogoCtrl, curve: Curves.easeInOut));

    _logoPulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _logoScale = Tween<double>(begin: 0.90, end: 1.10).animate(CurvedAnimation(parent: _logoPulseCtrl, curve: Curves.easeInOut));
  }

  Future<void> fetchMyLibrary() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 1️⃣ Fetch Purchased Unit IDs
      final purchases = await supabase
          .from('purchases')
          .select('unit_id')
          .eq('user_id', user.id)
          .eq('payment_status', 'success');

      final purchasedIds = purchases.map((p) => p['unit_id']).toSet();

      // 2️⃣ Fetch Access Control Info (Gifts + Locks + Reasons)
      final accessEntries = await supabase
          .from('student_access_control')
          .select('unit_id, access_status, lock_reason')
          .eq('user_id', user.id);

      // Map banao easy lookup ke liye: {unit_id: {status: 'LOCKED', reason: '...'}}
      final accessMap = {
        for (var entry in accessEntries)
          entry['unit_id']: entry
      };

      // 3️⃣ Combine ALL Unit IDs (Purchased + Gifted/Locked)
      final allUnitIds = {...purchasedIds, ...accessMap.keys}.toList();

      if (allUnitIds.isEmpty) {
        if(mounted) setState(() { isLoading = false; combinedLibrary = []; giftCount = 0; });
        return;
      }

      // 4️⃣ Fetch Unit Details
      final unitsData = await supabase.from('units').select().inFilter('id', allUnitIds);

      // 5️⃣ Fetch Subject Details
      final subjectIds = unitsData.map((u) => u['subject_id']).toSet().toList();
      final subjectsData = await supabase.from('subjects').select().inFilter('id', subjectIds);

      // 6️⃣ Merge Data
      final List<Map<String, dynamic>> finalResult = [];
      int tempGiftCount = 0;

      for (var subject in subjectsData) {
        final subjectUnits = unitsData.where((u) => u['subject_id'] == subject['id']).toList();
        final List<Map<String, dynamic>> processedUnits = [];

        for (var unit in subjectUnits) {
          String unitId = unit['id'];

          // Check Status from Access Map
          var accessInfo = accessMap[unitId];
          bool isLocked = accessInfo != null && accessInfo['access_status'] == 'LOCKED';
          String lockReason = accessInfo != null ? (accessInfo['lock_reason'] ?? "Contact Admin") : "";

          // Gift Logic: Agar purchased nahi hai, par access map mein hai (aur locked nahi hai)
          bool isPurchased = purchasedIds.contains(unitId);
          bool isGift = !isPurchased && (accessInfo != null);

          if (isGift) tempGiftCount++;

          processedUnits.add({
            ...unit,
            'is_gift': isGift,
            'is_locked': isLocked,
            'lock_reason': lockReason,
            'is_purchased': isPurchased
          });
        }

        if (processedUnits.isNotEmpty) {
          finalResult.add({'subject': subject, 'units': processedUnits});
        }
      }

      if(mounted) {
        setState(() {
          combinedLibrary = finalResult;
          giftCount = tempGiftCount;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Library Fetch Error: $e");
      if(mounted) setState(() => isLoading = false);
    }
  }

  void showGiftSummary(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: const Text("My Gifts 🎁", style: TextStyle(fontFamily: 'Tinos')),
        content: Text("You have received $giftCount special gift units! They are highlighted in Purple.",
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontFamily: 'Tinos')),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Awesome"))],
      ),
    );
  }

  @override
  void dispose() {
    _bgLogoCtrl.dispose();
    _logoPulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {

        final isDark = currentMode == ThemeMode.dark;
        final bgColor = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF5F7FA);
        final textColor = isDark ? Colors.white : const Color(0xFF2D3436);
        final subTextColor = isDark ? Colors.white60 : Colors.grey.shade600;
        final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        final borderColor = isDark ? Colors.white12 : Colors.grey.shade200;
        final bgLogoImage = isDark ? "assets/WApplogo.png" : "assets/Applogo.png";

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
                  bottom: 10, left: 0, right: 0,
                  child: IgnorePointer(
                    child: SizedBox(
                      height: size.height * 0.40,
                      child: ScaleTransition(scale: _bgLogoScale, child: Opacity(opacity: 0.04, child: Image.asset(bgLogoImage, fit: BoxFit.contain, alignment: Alignment.bottomCenter))),
                    ),
                  ),
                ),
                Column(
                  children: [
                    _buildTopBar(context, isDark, textColor, borderColor),
                    _buildPersonalHeader(context, isDark, textColor, bgLogoImage),
                    Expanded(
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
                          : combinedLibrary.isEmpty
                          ? _buildEmptyState(context, textColor, subTextColor)
                          : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 50),
                        physics: const BouncingScrollPhysics(),
                        itemCount: combinedLibrary.length,
                        itemBuilder: (context, index) {
                          return _buildSubjectCard(combinedLibrary[index], isDark, textColor, cardColor, borderColor);
                        },
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

  // --- WIDGETS ---
  Widget _buildTopBar(BuildContext context, bool isDark, Color textColor, Color borderColor) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, left: 15, right: 15, bottom: 15),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : Colors.white,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: Icon(Icons.arrow_back_ios_new, size: 20, color: textColor), onPressed: () => Navigator.pop(context)),
          const Text("My Library 📚", style: TextStyle(fontFamily: 'Tinos', fontSize: 20, fontWeight: FontWeight.bold)),
          Row(
            children: [
              if (giftCount > 0) IconButton(onPressed: () => showGiftSummary(context, isDark), icon: const Icon(Icons.card_giftcard, color: Colors.purpleAccent), tooltip: "My Gifts"),
              IconButton(icon: const Icon(Icons.home_rounded, size: 26, color: Color(0xFF6C63FF)), onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildPersonalHeader(BuildContext context, bool isDark, Color textColor, String logoAsset) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Welcome back,", style: TextStyle(color: isDark ? Colors.grey : Colors.grey.shade700, fontSize: 14)),
            const SizedBox(height: 5),
            Text("Your Learning\nHub 🎓", style: TextStyle(color: textColor, fontSize: 28, fontWeight: FontWeight.bold, height: 1.1)),
          ]),
          GestureDetector(
            onTap: () { themeNotifier.value = themeNotifier.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark; },
            child: ScaleTransition(
              scale: _logoScale,
              child: Container(
                height: 70, width: 70,
                decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? const Color(0xFF1E1E1E) : Colors.white, boxShadow: [BoxShadow(color: isDark ? Colors.purple.withOpacity(0.2) : Colors.grey.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))], border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100)),
                padding: const EdgeInsets.all(12),
                child: Image.asset("assets/logo.png", fit: BoxFit.contain),
              ),
            ),
          )
        ],
      ),
    );
  }

  // 🔥 UPDATED CARD (Handles Locked/Gifted/Purchased Visuals & Logic)
  Widget _buildSubjectCard(Map<String, dynamic> item, bool isDark, Color textColor, Color cardColor, Color borderColor) {
    final subject = item['subject'];
    final units = item['units'] as List;

    return Container(
      margin: const EdgeInsets.only(bottom: 25),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: borderColor), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 8))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFF6C63FF).withOpacity(0.08), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: cardColor, shape: BoxShape.circle), child: Icon(Icons.bookmark, color: const Color(0xFF6C63FF), size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Text(subject['name'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor))),
            ]),
          ),
          ListView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), padding: const EdgeInsets.all(12),
            itemCount: units.length,
            itemBuilder: (context, idx) {
              final unit = units[idx];
              final bool isLocked = unit['is_locked'] ?? false;
              final bool isGift = unit['is_gift'] ?? false;
              final String lockReason = unit['lock_reason'] ?? "";

              // Determine Style based on Status
              Color statusColor = isLocked
                  ? Colors.red
                  : (isGift ? Colors.purpleAccent : Colors.green);

              Color btnColor = isLocked
                  ? Colors.redAccent
                  : (isGift ? Colors.purple : const Color(0xFF6C63FF));

              String statusText = isLocked
                  ? "LOCKED 🚫"
                  : (isGift ? "GIFTED 🎁" : "OWNED ✅");

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isLocked
                      ? (isDark ? Colors.red.withOpacity(0.1) : Colors.red.withOpacity(0.05))
                      : (isGift ? (isDark ? Colors.deepPurple.withOpacity(0.2) : Colors.purple.withOpacity(0.05)) : (isDark ? Colors.black26 : Colors.grey.shade50)),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                        isLocked ? Icons.lock : (isGift ? Icons.card_giftcard : Icons.check_circle_rounded),
                        color: statusColor, size: 24
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(statusText, style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold)),
                          Text(unit['name'], style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: btnColor, foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        elevation: 4,
                      ),
                      child: Text(isLocked ? "Locked" : "Study", style: const TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        // 🔥🔥 LOCK CHECK 🔥🔥
                        if (isLocked) {
                          showDialog(
                            context: context,
                            builder: (c) => AlertDialog(
                              backgroundColor: Colors.red.shade50,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              title: const Row(children: [Icon(Icons.gpp_bad, color: Colors.red), SizedBox(width: 10), Text("Access Denied", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))]),
                              content: Text(lockReason, style: const TextStyle(color: Colors.black, fontSize: 15, fontFamily: 'Tinos')),
                              actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("Close", style: TextStyle(color: Colors.red)))],
                            ),
                          );
                        } else {
                          // Open Notes
                          Navigator.push(context, MaterialPageRoute(builder: (_) => NotesPage(unitId: unit['id'])));
                        }
                      },
                    )
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, Color textColor, Color subTextColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Opacity(opacity: 0.8, child: Image.asset("assets/logo.png", height: 100, color: Colors.grey.shade400)),
          const SizedBox(height: 20),
          Text("Your library is empty", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 10),
          Text("Looks like you haven't enrolled in any courses yet.", textAlign: TextAlign.center, style: TextStyle(color: subTextColor, fontSize: 16)),
          const SizedBox(height: 40),
          SizedBox(width: double.infinity, height: 55, child: ElevatedButton.icon(onPressed: () { Navigator.of(context).popUntil((route) => route.isFirst); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 8), icon: const Icon(Icons.explore_rounded), label: const Text("Explore Branches", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))))
        ]),
      ),
    );
  }
}