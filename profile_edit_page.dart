import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui'; // For Colors
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../main.dart';
import '../home_page.dart';
import 'profile_page.dart';
import '../login_page.dart' hide DynamicSkyBackground;

class ProfileEditPage extends StatefulWidget {
  final bool isFirstTime;
  const ProfileEditPage({super.key, this.isFirstTime = false});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  // Controllers
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final phoneController = TextEditingController();
  final dobController = TextEditingController();

  // Selection
  String gender = "Male";
  String? selectedCourse;
  String? selectedBranch;
  String? selectedYear;
  String? selectedSemester;

  // Image Logic
  String? serverImageUrl;
  XFile? pickedFile;
  Uint8List? webImageBytes;
  bool isImageRemoved = false;

  bool isLoading = true;
  bool isSaving = false;
  bool isSavedSuccess = false;

  // Message Queue
  final List<Map<String, dynamic>> _messageQueue = [];
  bool _isDisplayingMessage = false;

  // Animations
  late AnimationController _bounceController;
  late Animation<double> _bounceAnim;
  late AnimationController _logoController;
  late Animation<double> _logoScaleAnim;
  late AnimationController _sunMoonAnimController;

  // Lists
  final List<String> courses = ["B.Tech", "M.Tech", "BCA", "MCA", "Diploma"];
  final List<String> branches = ["CSE", "IT", "ECE", "ME", "CE", "AI & DS"];
  final List<String> years = ["1st Year", "2nd Year", "3rd Year", "4th Year"];

  @override
  void initState() {
    super.initState();
    loadUserData();

    _bounceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _bounceAnim = Tween<double>(begin: 1.0, end: 1.1).animate(CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut));

    _logoController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _logoScaleAnim = Tween<double>(begin: 0.95, end: 1.05).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeInOut));

    _sunMoonAnimController = AnimationController(vsync: this, duration: const Duration(seconds: 1));
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _logoController.dispose();
    _sunMoonAnimController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    dobController.dispose();
    super.dispose();
  }

  // ================= MESSAGE LOGIC =================
  void showTopMessage(String msg, {bool isError = false}) {
    _messageQueue.add({'msg': msg, 'isError': isError});
    if (!_isDisplayingMessage) _processMessageQueue();
  }

  void _processMessageQueue() async {
    if (_messageQueue.isEmpty) { _isDisplayingMessage = false; return; }
    _isDisplayingMessage = true;
    final currentItem = _messageQueue.removeAt(0);
    if (!mounted) return;

    showDialog(
      context: context, barrierDismissible: false, barrierColor: Colors.transparent,
      builder: (context) {
        return Align(
          alignment: Alignment.topCenter,
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.only(top: 60, left: 20, right: 20),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(color: currentItem['isError'] ? Colors.redAccent : Colors.green, borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))]),
              child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(currentItem['isError'] ? Icons.error_outline : Icons.check_circle, color: Colors.white), const SizedBox(width: 10), Flexible(child: Text(currentItem['msg'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: "Tinos"), textAlign: TextAlign.center))]),
            ),
          ),
        );
      },
    );
    await Future.delayed(const Duration(seconds: 3));
    if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    await Future.delayed(const Duration(seconds: 1));
    _processMessageQueue();
  }

  // 🔥 HELPER: SAFE ERROR MESSAGE TRANSLATOR
  // Ye function technical errors ko sundar English mein convert karta hai
  String _getFriendlyErrorMessage(Object e) {
    String errorStr = e.toString().toLowerCase();

    if (errorStr.contains('socketexception') || errorStr.contains('network') || errorStr.contains('failed host lookup')) {
      return "No Internet Connection. Please check your WiFi/Data.";
    }
    if (errorStr.contains('timeout')) {
      return "Server took too long to respond. Try again.";
    }
    if (errorStr.contains('postgrestexception')) {
      return "Database Error. Please try again later.";
    }
    // Generic
    return "Something went wrong. Please try again.";
  }

  // ================= LOAD DATA =================
  Future<void> loadUserData() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final data = await supabase.from('profiles').select().eq('id', user.id).maybeSingle();
      if (mounted) {
        setState(() {
          String full = data?['full_name'] ?? user.userMetadata?['full_name'] ?? "";
          List<String> parts = full.trim().split(" ");
          if (parts.isNotEmpty) firstNameController.text = parts[0];
          if (parts.length > 1) lastNameController.text = parts.sublist(1).join(" ");
          phoneController.text = (data?['phone'] ?? "").replaceFirst("+91", "");

          if (data != null) {
            serverImageUrl = data['profile_image'];
            gender = data['gender'] ?? "Male";
            selectedCourse = data['course'];
            selectedBranch = data['branch'];
            selectedYear = data['year'];
            selectedSemester = data['semester'];
            dobController.text = data['dob'] ?? "";
          }

          if (firstNameController.text.isEmpty || phoneController.text.isEmpty || selectedCourse == null || selectedBranch == null || selectedYear == null || selectedSemester == null) {
            showTopMessage("Please update your profile details 📝", isError: false);
          }
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        // 🔥 Error Handling Added Here
        showTopMessage(_getFriendlyErrorMessage(e), isError: true);
      }
    }
  }

  List<String> getSemesters() {
    if (selectedYear == "1st Year") return ["1st Sem", "2nd Sem"];
    if (selectedYear == "2nd Year") return ["3rd Sem", "4th Sem"];
    if (selectedYear == "3rd Year") return ["5th Sem", "6th Sem"];
    if (selectedYear == "4th Year") return ["7th Sem", "8th Sem"];
    return [];
  }

  // ================= IMAGE LOGIC =================
  Future<void> pickImage(bool fromCamera) async {
    try {
      final picked = await ImagePicker().pickImage(source: fromCamera ? ImageSource.camera : ImageSource.gallery);
      if (picked != null) {
        if (!picked.path.toLowerCase().endsWith('.jpg') && !picked.path.toLowerCase().endsWith('.jpeg') && !picked.path.toLowerCase().endsWith('.png')) {
          showTopMessage("Invalid Format! Use JPG/PNG", isError: true);
          return;
        }
        Uint8List? bytes;
        if (kIsWeb) bytes = await picked.readAsBytes();
        setState(() {
          pickedFile = picked;
          webImageBytes = bytes;
          isImageRemoved = false;
        });
      }
    } catch (e) {
      showTopMessage("Could not pick image.", isError: true);
    }
  }

  void _removePhoto() {
    setState(() {
      pickedFile = null;
      webImageBytes = null;
      serverImageUrl = null;
      isImageRemoved = true;
    });
    Navigator.pop(context);
  }

  void showImageSourceDialog() {
    bool hasImage = pickedFile != null || serverImageUrl != null;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))
        ),
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('Camera', style: TextStyle(color: Colors.black)),
              onTap: () { Navigator.pop(context); pickImage(true); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.purple),
              title: const Text('Gallery', style: TextStyle(color: Colors.black)),
              onTap: () { Navigator.pop(context); pickImage(false); },
            ),
            if (hasImage)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                onTap: _removePhoto,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> deleteOldImage(String? url) async {
    if (url == null || url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      final fileName = uri.pathSegments.last;
      await supabase.storage.from('profile-images').remove([fileName]);
    } catch (e) {
      debugPrint("Err delete: $e");
      // Silent fail is fine here, but logging is good
    }
  }

  // ================= SAVE PROFILE =================
  Future<void> saveProfile() async {
    String fName = firstNameController.text.trim();
    String lName = lastNameController.text.trim();
    String phone = phoneController.text.trim();

    // Validations
    if (fName.isEmpty) { showTopMessage("First Name is mandatory!", isError: true); return; }
    if (phone.isEmpty) { showTopMessage("Phone Number is mandatory!", isError: true); return; }
    if (phone.length != 10 || int.tryParse(phone) == null) { showTopMessage("Phone must be 10 digits (0-9 only)", isError: true); return; }

    if (selectedCourse == null || selectedBranch == null || selectedYear == null || selectedSemester == null) {
      showTopMessage("Please complete course details", isError: true);
      return;
    }

    setState(() => isSaving = true);
    final user = supabase.auth.currentUser;
    if (user == null) {
      showTopMessage("Session Expired. Login again.", isError: true);
      setState(() => isSaving = false);
      return;
    }

    try {
      String? finalImageUrl = serverImageUrl;

      // Handle Image: Upload New or Remove
      if (isImageRemoved) {
        final oldData = await supabase.from('profiles').select('profile_image').eq('id', user.id).maybeSingle();
        await deleteOldImage(oldData?['profile_image']);
        finalImageUrl = null;
      } else if (pickedFile != null) {
        final oldData = await supabase.from('profiles').select('profile_image').eq('id', user.id).maybeSingle();
        await deleteOldImage(oldData?['profile_image']);

        final fileName = "profile_${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg";
        if (kIsWeb) {
          await supabase.storage.from('profile-images').uploadBinary(fileName, webImageBytes!);
        } else {
          final dir = await getTemporaryDirectory();
          final targetPath = p.join(dir.path, "$fileName.jpg");
          var result = await FlutterImageCompress.compressAndGetFile(pickedFile!.path, targetPath, quality: 70, minWidth: 600, minHeight: 600);
          if (result != null) await supabase.storage.from('profile-images').upload(fileName, File(result.path));
        }
        finalImageUrl = supabase.storage.from('profile-images').getPublicUrl(fileName);
      }

      await supabase.from('profiles').upsert({
        'id': user.id,
        'full_name': "$fName $lName".trim(),
        'phone': "+91$phone",
        'gender': gender,
        'course': selectedCourse,
        'branch': selectedBranch,
        'year': selectedYear,
        'semester': selectedSemester,
        'dob': dobController.text.trim(),
        'profile_image': finalImageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });

      setState(() { isSaving = false; isSavedSuccess = true; });
      _bounceController.repeat(reverse: true);
      showTopMessage("Profile Saved Successfully! 🎉");

    } catch (e) {
      setState(() => isSaving = false);
      // 🔥 Error Handling Applied Here too
      showTopMessage(_getFriendlyErrorMessage(e), isError: true);
    }
  }

  // ================= MAIN UI =================
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : Colors.black87;

        double sunSize = 90.0;
        double moonSize = 70.0;
        double toggleTop = 60.0;
        double toggleRight = 20.0;

        return Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isDark
                          ? [const Color(0xFF01011B), const Color(0xFF090739), Colors.black]
                          : [const Color(0xFF87CEEB), const Color(0xFFB0E0E6), const Color(0xFFE0F7FA)],
                    ),
                  ),
                  child: StarBackground(isDark: isDark),
                ),
              ),

              LayoutBuilder(
                builder: (context, constraints) {
                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 50),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight - 100),
                        child: _buildMobileLayout(isDark, textColor),
                      ),
                    ),
                  );
                },
              ),

              Positioned(
                top: toggleTop,
                right: toggleRight,
                child: GestureDetector(
                  onTap: () {
                    themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
                  },
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 800),
                    transitionBuilder: (child, anim) => RotationTransition(turns: anim, child: ScaleTransition(scale: anim, child: child)),
                    child: isDark
                        ? Image.asset('assets/moon.png', key: const ValueKey('moon'), width: moonSize, height: moonSize)
                        : Image.asset('assets/sun.png', key: const ValueKey('sun'), width: sunSize, height: sunSize),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileLayout(bool isDark, Color textColor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 550), child: _buildGlassFormCard(isDark, textColor)),
      ],
    );
  }

  Widget _buildGlassFormCard(bool isDark, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF000000).withOpacity(0.5) : Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: isDark ? Colors.white12 : Colors.white.withOpacity(0.5), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 30, offset: const Offset(0, 10))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            const CircularProgressIndicator(color: Colors.orange)
          else if (!isSavedSuccess)
            _buildInputFields(isDark, textColor)
          else
            _buildSuccessView(isDark, textColor),
        ],
      ),
    );
  }

  Widget _buildInputFields(bool isDark, Color textColor) {
    String initials = "";
    if (firstNameController.text.isNotEmpty) initials += firstNameController.text[0];
    if (lastNameController.text.isNotEmpty) initials += lastNameController.text[0];

    return Column(
      children: [
        GestureDetector(
          onTap: showImageSourceDialog,
          child: Stack(
            children: [
              CircleAvatar(
                radius: 55,
                backgroundColor: isDark ? Colors.white10 : Colors.grey.shade300,
                backgroundImage: (webImageBytes != null)
                    ? MemoryImage(webImageBytes!)
                    : (pickedFile != null ? FileImage(File(pickedFile!.path)) : (serverImageUrl != null ? NetworkImage(serverImageUrl!) : null) as ImageProvider?),
                child: (pickedFile == null && serverImageUrl == null && webImageBytes == null)
                    ? Text(initials.toUpperCase(), style: TextStyle(fontSize: 35, fontWeight: FontWeight.bold, color: textColor))
                    : null,
              ),
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),

        Row(children: [
          Expanded(child: input(firstNameController, "First Name", isDark, isName: true, max: 12)),
          const SizedBox(width: 10),
          Expanded(child: input(lastNameController, "Last Name", isDark, isName: true, max: 12)),
        ]),
        const SizedBox(height: 15),
        input(phoneController, "Phone (+91)", isDark, isPhone: true, max: 10),
        const SizedBox(height: 15),

        Row(children: ["Male", "Female", "Other"].map((g) => Expanded(
          child: GestureDetector(
            onTap: () => setState(() => gender = g),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: gender == g ? Colors.orange : (isDark ? Colors.white10 : Colors.black12), borderRadius: BorderRadius.circular(10)),
              alignment: Alignment.center,
              child: Text(g, style: TextStyle(color: gender == g ? Colors.white : textColor, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
        )).toList()),

        const SizedBox(height: 15),
        Row(children: [
          Expanded(child: _buildGlassDropdown(value: selectedCourse, items: courses, hint: "Course", onChanged: (v) => setState(() => selectedCourse = v), isDark: isDark)),
          const SizedBox(width: 10),
          Expanded(child: _buildGlassDropdown(value: selectedBranch, items: branches, hint: "Branch", onChanged: (v) => setState(() => selectedBranch = v), isDark: isDark)),
        ]),
        const SizedBox(height: 15),
        Row(children: [
          Expanded(child: _buildGlassDropdown(value: selectedYear, items: years, hint: "Year", onChanged: (v) => setState(() { selectedYear = v; selectedSemester = null; }), isDark: isDark)),
          const SizedBox(width: 10),
          Expanded(child: _buildGlassDropdown(value: selectedSemester, items: getSemesters(), hint: "Semester", onChanged: (v) => setState(() => selectedSemester = v), isDark: isDark)),
        ]),
        const SizedBox(height: 15),

        GestureDetector(
          onTap: () async {
            DateTime? d = await showDatePicker(context: context, initialDate: DateTime(2005), firstDate: DateTime(1990), lastDate: DateTime.now());
            if(d!=null) setState(() => dobController.text = "${d.year}-${d.month}-${d.day}");
          },
          child: AbsorbPointer(child: input(dobController, "DOB (Optional)", isDark, icon: Icons.calendar_month)),
        ),

        const SizedBox(height: 30),

        GestureDetector(
          onTap: isSaving ? null : saveProfile,
          child: Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: const LinearGradient(colors: [Colors.redAccent, Colors.orangeAccent])),
            child: isSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Save Profile", style: TextStyle(fontFamily: "Tinos", color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView(bool isDark, Color textColor) {
    return Column(
      children: [
        const Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent, size: 80),
        const SizedBox(height: 10),
        Text("Profile Saved!", style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: "Tinos")),
        const SizedBox(height: 30),
        LayoutBuilder(builder: (context, constraints) {
          bool isTight = constraints.maxWidth < 300;
          List<Widget> buttons = [
            ScaleTransition(
              scale: _bounceAnim,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ProfilePage())),
                style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.white10 : Colors.indigoAccent, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                icon: Icon(Icons.person, color: isDark ? textColor : Colors.white),
                label: Text("View Profile", style: TextStyle(color: isDark ? textColor : Colors.white)),
              ),
            ),
            ScaleTransition(
              scale: _bounceAnim,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomePage()), (route) => false),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12)),
                icon: const Icon(Icons.home, color: Colors.white),
                label: const Text("Home", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ];
          return isTight ? Column(children: [buttons[0], const SizedBox(height: 15), buttons[1]]) : Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: buttons);
        })
      ],
    );
  }

  Widget input(TextEditingController c, String label, bool isDark, {bool isName=false, bool isPhone=false, int? max, IconData? icon}) {
    return TextField(
      controller: c, maxLength: max,
      onChanged: (val) { if (isName) setState(() {}); },
      keyboardType: isPhone ? TextInputType.number : TextInputType.text,
      inputFormatters: [
        if(isName) FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
        if(isPhone) FilteringTextInputFormatter.digitsOnly
      ],
      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontFamily: "Tinos"),
      decoration: InputDecoration(
          counterText: "", labelText: label,
          labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
          filled: true, fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          suffixIcon: icon != null ? Icon(icon, color: Colors.grey) : null
      ),
    );
  }

  Widget _buildGlassDropdown({required String? value, required List<String> items, required String hint, required Function(String?) onChanged, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value, hint: Text(hint, style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontFamily: "Tinos")),
          icon: Icon(Icons.arrow_drop_down, color: isDark ? Colors.white70 : Colors.black87), isExpanded: true,
          dropdownColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontFamily: "Tinos", fontSize: 15),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ================= STARS ONLY BACKGROUND =================
class StarBackground extends StatefulWidget {
  final bool isDark;
  const StarBackground({super.key, required this.isDark});
  @override
  State<StarBackground> createState() => _StarBackgroundState();
}

class _StarBackgroundState extends State<StarBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (!widget.isDark) return const SizedBox();
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => CustomPaint(painter: StarPainter(_controller.value)),
    );
  }
}

class StarPainter extends CustomPainter {
  final double animationValue;
  static final List<Offset> stars = List.generate(60, (index) => Offset(Random().nextDouble() * 500, Random().nextDouble() * 900));
  static final List<double> randomOffsets = List.generate(60, (index) => Random().nextDouble() * pi * 2);
  StarPainter(this.animationValue);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    for (int i = 0; i < stars.length; i++) {
      double opacity = 0.3 + 0.5 * sin((animationValue * 2 * pi) + randomOffsets[i]).abs();
      paint.color = Colors.white.withOpacity(opacity);
      // 🔥 FIX: Modulo logic for consistent positioning
      double dx = stars[i].dx % size.width;
      double dy = stars[i].dy % size.height;
      canvas.drawCircle(Offset(dx, dy), 1.5, paint);
    }
  }
  @override
  bool shouldRepaint(covariant StarPainter oldDelegate) => true;
}