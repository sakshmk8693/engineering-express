import '../main.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'subjects_page.dart';
import 'profile_page.dart';
import '../home_page.dart';

class BranchesPage extends StatefulWidget {
  const BranchesPage({super.key});

  @override
  State<BranchesPage> createState() => _BranchesPageState();
}

class _BranchesPageState extends State<BranchesPage> with TickerProviderStateMixin {

  // --- Data Variables ---
  late Future<List<dynamic>> _branchesFuture;
  String? _profileImageUrl;

  // --- Animations ---
  late AnimationController _logoInnerCtrl;
  late Animation<double> _logoInnerScale;

  late AnimationController _bgLogoCtrl;
  late Animation<double> _bgLogoScale;

  // Icons Pulse Animation
  late AnimationController _iconPulseCtrl;
  late Animation<double> _iconScaleAnim;

  @override
  void initState() {
    super.initState();
    // 🔥 DATA FETCH LOGIC ALAG FUNCTION MEIN DALA (Retry ke liye)
    _refreshData();
    _loadUserProfile();

    // 1. Logo Animation
    _logoInnerCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _logoInnerScale = Tween<double>(begin: 0.95, end: 1.05).animate(CurvedAnimation(parent: _logoInnerCtrl, curve: Curves.easeInOut));

    // 2. Background Breathing
    _bgLogoCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(reverse: true);
    _bgLogoScale = Tween<double>(begin: 1.0, end: 1.1).animate(CurvedAnimation(parent: _bgLogoCtrl, curve: Curves.easeInOut));

    // 3. Icons Pulse
    _iconPulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _iconScaleAnim = Tween<double>(begin: 1.0, end: 1.2).animate(CurvedAnimation(parent: _iconPulseCtrl, curve: Curves.easeInOut));
  }

  // 🔥 NEW FUNCTION: Data Fetch karne ke liye
  void _refreshData() {
    setState(() {
      _branchesFuture = Supabase.instance.client
          .from('branches')
          .select()
          .order('name');
    });
  }

  Future<void> _loadUserProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('profile_image')
          .eq('id', user.id)
          .maybeSingle();

      if (mounted && res != null) {
        setState(() {
          _profileImageUrl = res['profile_image'];
        });
      }
    }
  }

  @override
  void dispose() {
    _logoInnerCtrl.dispose();
    _bgLogoCtrl.dispose();
    _iconPulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        final isDark = currentMode == ThemeMode.dark;
        final bgColor = isDark ? Colors.black : const Color(0xFFF5F7FA);
        final textColor = isDark ? Colors.white : const Color(0xFF2D3436);
        final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        final borderColor = isDark ? Colors.white10 : Colors.grey.shade100;
        final bgLogo = isDark ? "assets/WApplogo.png" : "assets/Applogo.png";

        return Theme(
          data: Theme.of(context).copyWith(
            textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Tinos', bodyColor: textColor),
            iconTheme: IconThemeData(color: textColor),
          ),
          child: Scaffold(
            backgroundColor: bgColor,
            body: Stack(
              children: [
                // ✅ BACKGROUND LOGO
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: GestureDetector(
                    onTap: () {
                      themeNotifier.value = themeNotifier.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
                    },
                    child: SizedBox(
                      height: size.height * 0.45,
                      child: ScaleTransition(
                        scale: _bgLogoScale,
                        child: Opacity(
                          opacity: 0.05,
                          child: Image.asset(bgLogo, fit: BoxFit.contain, alignment: Alignment.bottomCenter),
                        ),
                      ),
                    ),
                  ),
                ),

                Column(
                  children: [
                    // ✅ 1. FIXED TOP BAR
                    _buildFixedTopBar(context, isDark, textColor),

                    // ✅ 2. SCROLLABLE CONTENT
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildHeroHeader(context, isDark, textColor, cardColor, borderColor),

                            // 🔥 FUTURE BUILDER WITH ERROR HANDLING
                            FutureBuilder(
                              future: _branchesFuture,
                              builder: (context, snapshot) {
                                // 1. LOADING STATE
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Padding(
                                    padding: EdgeInsets.all(50.0),
                                    child: Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF))),
                                  );
                                }

                                // 2. ERROR STATE (Internet gya, ya server down)
                                if (snapshot.hasError) {
                                  return _buildErrorWidget(
                                    isDark,
                                    "Oops! Something went wrong.",
                                    "Please check your internet connection and try again.",
                                    Icons.wifi_off_rounded,
                                  );
                                }

                                final data = snapshot.data as List<dynamic>;

                                // 3. EMPTY STATE (Data hi nahi hai)
                                if (data.isEmpty) {
                                  return _buildErrorWidget(
                                    isDark,
                                    "No Branches Found",
                                    "It looks like no data has been added yet.",
                                    Icons.folder_open_rounded,
                                    showRetry: true, // Refresh button dikhana hai
                                  );
                                }

                                // 4. SUCCESS STATE
                                return LayoutBuilder(
                                  builder: (context, constraints) {
                                    int crossAxisCount = 1;
                                    double aspectRatio = 3.5;

                                    return GridView.builder(
                                      padding: const EdgeInsets.all(20),
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: crossAxisCount,
                                        childAspectRatio: aspectRatio,
                                        crossAxisSpacing: 15,
                                        mainAxisSpacing: 15,
                                      ),
                                      itemCount: data.length,
                                      itemBuilder: (context, index) {
                                        return _BranchCard(
                                          branch: data[index],
                                          index: index,
                                          iconScaleAnim: _iconScaleAnim,
                                          isDark: isDark,
                                          cardColor: cardColor,
                                          textColor: textColor,
                                          borderColor: borderColor,
                                        );
                                      },
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

  // ========================================================
  // 🔥 ERROR HANDLING WIDGET (RETRY BUTTON KE SATH)
  // ========================================================
  Widget _buildErrorWidget(bool isDark, String title, String subtitle, IconData icon, {bool showRetry = true}) {
    return Container(
      padding: const EdgeInsets.all(30),
      margin: const EdgeInsets.only(top: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Bada sa Icon
          Icon(icon, size: 60, color: Colors.grey.withOpacity(0.5)),
          const SizedBox(height: 15),

          // Error Title
          Text(
            title,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87
            ),
          ),
          const SizedBox(height: 8),

          // Error Subtitle
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: isDark ? Colors.white38 : Colors.black45),
          ),
          const SizedBox(height: 20),

          // RETRY BUTTON
          if (showRetry)
            ElevatedButton.icon(
              onPressed: () {
                // Button dabane par fir se data load hoga
                _refreshData();
              },
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text("Try Again", style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
              ),
            ),
        ],
      ),
    );
  }

  // ================= 1. FIXED TOP BAR =================
  Widget _buildFixedTopBar(BuildContext context, bool isDark, Color textColor) {
    return Container(
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 10,
          left: 15, right: 15, bottom: 15
      ),
      decoration: BoxDecoration(
          color: isDark ? const Color(0xFF000000) : Colors.white,
          border: Border(bottom: BorderSide(color: isDark ? Colors.red : Colors.deepPurpleAccent, width: 1)),
          boxShadow: [
            BoxShadow(color: Colors.black, blurRadius: 4, offset: const Offset(0, 2))
          ]
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
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                        fontFamily: 'Tinos',
                        fontSize: 22,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.bold
                    ),
                    children: [
                      const TextSpan(text: 'E', style: TextStyle(color: Color(0xFFFF0000), fontSize: 26)),
                      TextSpan(text: 'ngineering ', style: TextStyle(color: textColor)),
                      const TextSpan(text: 'E', style: TextStyle(color: Color(0xFFFF0000), fontSize: 26)),
                      TextSpan(text: 'xpress', style: TextStyle(color: textColor)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()))
                  .then((_) => _loadUserProfile());
            },
            child: Container(
              height: 40, width: 40,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade200,
                  border: Border.all(color: Colors.green, width: 2),
                  image: DecorationImage(
                    image: _profileImageUrl != null
                        ? NetworkImage(_profileImageUrl!)
                        : const AssetImage("assets/profile.png") as ImageProvider,
                    fit: BoxFit.cover,
                  )
              ),
            ),
          )
        ],
      ),
    );
  }

  // ================= 2. HERO HEADER =================
  Widget _buildHeroHeader(BuildContext context, bool isDark, Color textColor, Color cardColor, Color borderColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 25),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F172A), const Color(0xFF312E81), Colors.black]
              : [const Color(0xFFE0C3FC),  const Color(0xFFF1F5F9),const Color(0xFF8EC5FC)],
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Select Your \nAcademic Year 🎓",
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w800, color: textColor,
                          height: 1.2, fontFamily: "Tinos"
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text("Choose to view subjects", style: TextStyle(color: isDark ? Colors.white : Colors.deepOrangeAccent, fontSize: 13))
                  ],
                ),
              ),
              const SizedBox(width: 15),
              GestureDetector(
                onTap: () {
                  themeNotifier.value = themeNotifier.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
                  setState(() {});
                },
                child: ScaleTransition(
                  scale: _logoInnerScale,
                  child: Image.asset("assets/logo.png", height: 100, width: 100, fit: BoxFit.contain),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
                color: isDark ? Colors.black.withOpacity(0.5) : Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))
                ]
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: Color(0xFFFFF4E5), shape: BoxShape.circle),
                  child: const Icon(Icons.lightbulb, color: Colors.orange, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Did you know?", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                      Text("Engineers turn dreams into reality!", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
                    ],
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================= 3. BRANCH CARD =================
class _BranchCard extends StatelessWidget {
  final dynamic branch;
  final int index;
  final Animation<double> iconScaleAnim;
  final bool isDark;
  final Color cardColor;
  final Color textColor;
  final Color borderColor;

  const _BranchCard({
    required this.branch,
    required this.index,
    required this.iconScaleAnim,
    required this.isDark,
    required this.cardColor,
    required this.textColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFF6C63FF), const Color(0xFFFF6584),
      const Color(0xFF38B6FF), const Color(0xFFFFB800),
    ];
    final color = colors[index % colors.length];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SubjectsPage(branchId: branch['id'], yearTitle: branch['name']),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: isDark ? Colors.black : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: isDark ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.3), blurRadius: 0.5, offset: const Offset(0, 0.2))
            ],
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              ScaleTransition(
                scale: iconScaleAnim,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(Icons.school_rounded, color: color, size: 24),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(branch['name'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor, fontFamily: "Tinos")),
                    const SizedBox(height: 4),
                    Text("Tap to explore subjects", style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: isDark ? Colors.white24 : Colors.grey.shade300),
            ],
          ),
        ),
      ),
    );
  }
}