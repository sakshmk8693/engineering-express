import '../main.dart';
import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_edit_page.dart'; // Ensure path is correct
import '../login_page.dart'; // Ensure path is correct

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  // --- Animation Controller for Breathing Effect ---
  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;

  // Bot ke Pop-up (chota-bada) effect ke liye
  late AnimationController _botJumpController;
  late Animation<double> _botJumpAnimation;

  // --- Profile Variables ---
  String fullName = "Loading...";
  String email = "";
  String phone = "Not Added";
  String courseInfo = "Not Added";
  String semester = "";
  String gender = "Not Added";
  String dob = "Not Added";
  String memberSince = "";
  String loginMethod = "Email & Password";
  String? profileImageUrl;

  bool isLoading = true;
  bool notificationsEnabled = true;
  bool isDarkManual = true;

  // --- ALIVE BOT VARIABLES ---
  String _botMessage = "Hello Boss! 😎";
  bool _showBotBubble = false;
  Timer? _idleTimer;
  Timer? _botHideTimer;

  // --- TOP MESSAGE NOTIFICATION ---
  String? _topMessage;
  Color _topMessageColor = Colors.green;
  bool _showTopMessage = false;

  // --- OVERLAY SYSTEM VARIABLES (To keep Bot on Top) ---
  String? _activeOverlay;

  // Password Controllers
  final TextEditingController _currPassCtrl = TextEditingController();
  final TextEditingController _newPassCtrl = TextEditingController();
  final TextEditingController _confPassCtrl = TextEditingController();
  bool _isPassUpdating = false;
  String? _passLocalError;

// chat bot ke comments
  final Map<String, List<String>> botDialogues = {
    // 🔥 NEW: OFFLINE COMMENTS (No Internet)
    'offline': [
      "Internet gaya, mein bhi gaya... 😵",
      "Wifi on karo, mujhe saans nahi aa rahi! 📶",
      "Bina internet ke main gunga hu. 🤐",
      "Offline ho? Padhai karne ka acha bahana hai. 📚",
      "Data pack khatam? Gareebi... 😂",
      "Server se sampark toot gaya hai. 📡",
      "Signal dhoondo, mujhe duniya dekhni hai! 🌍"
    ],

    // 1. Idle
    'idle': [
      "Tumhara naam kahin toh sunela lagta hai....🤔",
      "Ye naam itihaas mein likha jayega 📜",
      "Naam kaafi achha hai aapka! ✨",
      "Spelling check kar rahe ho? Sahi hai yrr.. ✅",
      "So gaye kya? 😴",
      "Future Billionaire yahi hai! 💰",
      "Coding aati hai ya Chat-GPT se tapoge? 🤖",
      "Attendance poori hai ya medical lagaoge? 🏥",
      "Apni shakal dekhne aaye ho bas? 🤨",
      "Birthday party kab de rahe ho? 🎂",
      "Phone on karke bhool gaye lagta hai... 📱",
      "Practical file complete hai? 📂",
      "Padh lo yrr, ye details exam mein nahi aayengi! 📚",
      "Duniya badalni thi, ab assignment nahi ho rahe. 🌍",
      "Oye! Zinda ho ya gaye? 👀",
      "Placements ka kya socha hai? Berozgar? 🤷‍♂️",
      "DP ka kya seen hai? Change karne ki soch rahe ho? 🖼️",
      "Instagram aur reels se fursat mil gayi? 🙄",
      "Degree leke hi manoge ya drop loge? 🎓",
      "Ghar wale aa rahe hain, padhne ki acting kar lo! 👩‍🏫",
      "Kyu paisa uda rahe ho parents ka? Padh lo! 💸",
      "Jhoot mat bolo, asli DOB dale ho? 🤥",
      "Kisi aur ka account toh login nahi kiya? 🕵️‍♂️",
      "Number toh VIP lag raha hai! 🌟",
      "Ye tumhara real number hai ya fake hai? 📞",
      "Yrr yahi course likha tha tumhari kismat mein. 📜",
      "Fresher party milegi? 🍻",
      "Boring lag raha hai kya? Kuch tod-fod karein? 🔨",
      "Bas ghoorte hi rahoge ab? 😳",
      "Logout mat karna, password yaad nahi aayega tumhein. 😂",
      "Our Relationship will be longer than your ex. 💔",
      "Data khatam ho jayega tumhara aise hi... 📉"
    ],

    // 2. Dark/Light Mode
    'dark_mode': [
      "Andhera Kayam Rahe! 😈",
      "Batman banne ka shauk hai? 🦇",
      "Light band kar di, yahan bhi bill aane ka darr hai? 💡",
      "Ab lag raha hai hacker wala mahaul! 💻",
      "Disco light kyu khel rahe ho? 🕺"
    ],
    'light_mode': [
      "Oof! Meri aankhein! Itni light? ☀️",
      "Chashma lagwaoge kya? 👓",
      "Wah! Din nikal diya yrr 🔆",
      "Disco light kyu khel rahe ho? 🕺"
    ],

    // 3. Profile Photo
    'dp_touch': [
      "Zoom karke kya milega? Pixel hi hain. 🔍",
      "Nazar lag jayegi, bas karo! 🧿",
      "Rishta bhejna hai kya? 😉",
      "Photo purani hai, asliyat main jaanta hu! 🤫",
      "Filter ki zarurat hai tumhein... 💄",
      "Smart! (Jhoot bol raha hu) 😂",
      "Haan yrr, hero lag rahe ho, maan liya. 😎"
    ],
    'dp_missing_view': [
      "Oyy photo laga lo pehle, rishta nahi aayega warna! 💍",
      "Mr. India ho kyu? DP nahi lagaye ho 👻",
      "Shakal dikhane ke paise lagte hain kya? 🤑",
      "Photo hai nahi aur view kar rahe ho... Waah! 👏",
      "Kaala jaadu hai kya? Kuch dikh nahi raha! 🌑"
    ],

    // 4. Name
    'name': [
      "Tumhara naam kahin toh sunela lagta hai....🤔",
      "Kya naam hai! Ekdum Royal feeling! 👑",
      "Autograph chahiye is naam ka toh..✍️",
      "Ji haan, yahi naam hai tumhara. Bhool gaye kya? 🧠",
      "Spelling check kar rahe ho? Sahi hai yrr.. ✅",
      "Ye naam itihaas mein likha jayega. 📜",
      "Naam bada aur darshan chote... 😂",
      "Bas karo yrr, naam ghis jayega. 🛠️",
      "Future Billionaire yahi hai! 💰",
      "Nice Name! Kisne rakha tha? 🤔"
    ],

    // 5. Sem
    'sem': [
      "Ye semester kab khatam hoga bhagwan? 😫",
      "Backlog kitni hain? Sach bolna! 📉",
      "Pass ho jaoge na? Ya parchi banani padegi? 📝"
    ],

    // 6. Course
    'course': [
      "Yrr yahi course likha tha tumhari kismat mein. 📜",
      "Students ka dukh main samajhta hu. 🥲",
      "Galti kar di ye course leke, hai na? 😭",
      "Degree leke hi manoge ya drop loge? 🎓"
    ],

    // 7. DOB
    'dob': [
      "Kaafi purane insaan ho gaye ho... 👴",
      "Dharti par bohot time ho gaya, wapas kab jaoge? 🚀",
      "Birthday party kab de rahe ho? 🎂",
      "Budhapa aa raha hai, ghabrao mat. 🦯",
      "Cake khila dena birthday ke din, aise kaam nahi chalega. 🍰"
    ],

    // 8. Phone
    'phone': [
      "Ye tumhara real number hai ya fake hai? 📞",
      "Call mat karna, main uthaunga nahi. 📵",
      "Recharge karwa do yrr, gareeb dua dega. 🙏"
    ],

    // 9. Gender
    'gender': [
      "Haan yrr tumhara hi gender hai, shaq hai kya? 🤨",
      "Check kar liya? Sahi hai na? 🚻",
      "Confusion hai kya koi? 🏳️‍🌈",
      "Gender change karne ka option hai setting mein. ⚙️",
      "Sab theek hai na? Doctor ko dikhaun? 🩺"
    ],

    // 10. Login Method
    'login_method': [
      "Password yaad hai na? Ya Google ke bharose ho? 🔑",
      "Google Gmail se login kiya? Lazy insaan! 💤",
      "Hacker ho kya yrr, bina ID password ke kaise ghusoge! 💻",
      "Secure hai yrr, tension mat lo. 🔒"
    ],

    // 11. Member Since
    'member_since': [
      "Oho! Senior Citizen! 👴",
      "Itne time se jhel rahe ho humein? Salute! 🫡",
      "New admission ho kya? Ragging lun? 😉",
      "Timeline gawah hai, tum velle ho. ⏳"
    ],

    // 12. Notification Touch
    'notif_error': [
      "Kya hua yrr? Galat button daba diya? 😅",
      "Error... Error... System hil gaya! 🚨",
      "Aaraam se yrr, tod mat dena app ko! 🛠️"
    ],
    'notif_enabled': [
      "Ab phone bajta rahega, tang mat hona! 📢",
      "Tayyar ho jao, ab main sone nahi dunga! 😈",
      "Chalo, ab ignore nahi kar paoge mujhe. 👀",
      "Welcome to the disturbance club! 🎊",
      "Sahi faisla kiya... shayad. 🤔"
    ],
    'notif_disabled': [
      "Ignore kar rahe ho? Dil toot gaya mera. 💔",
      "Ye kya kar diya? Ghar walon ko bulaun? 📞",
      "Jao dost jao, jee lo apni zindagi shanti se. 🕊️",
      "Mujhse baat karna pasand nahi kya? 🥺",
      "Theek hai yrr, mat suno meri baat. Main chup hu. 🤐",
      "Shanti chahiye? Okay, Tata Bye Bye. 👋"
    ],

    // 13. Privacy
    'privacy': [
      "HAAN HAAN pehle ye padh lo yahi toh aayega exam mein 📝",
      "Itna dhyan padhai mein lagaya hota toh topper hote! 🥇",
      "Jhooth mat bolo, tu padh nahi rahe bas scroll kar rahe ho. 📜",
      "Sign karoge ya angutha lagaoge? 👍",
      "Padh lo yrr, property ke kagaz nahi hain. 🏠",
      "Bohot time hai tumhare paas faltu ka... 🙄",
      "Exam mein ye nahi puchenge, course padh lo. 📚",
      "Lawyer banoge kya bade hoke? ⚖️",
      "Skip kar do yrr, sab 'Agree' hi karte hain. ✅",
      "Meri secret baatein mat padhna! 🤫"
    ],

    // 14. Terms
    'terms': [
      "Copy mein likh lo kabhi exam mein aa jaye ✍️",
      "Dost, ye padhne ke liye lawyer lagana padega. 👨‍⚖️",
      "Agree kar do chup-chap, option nahi hai. 🔫",
      "Itni English aati hai tumhein? 🇬🇧",
      "Conditions apply: Dimaag ka dahi ho jayega. 🥣",
      "Free mein kuch nahi milta, kidney toh nahi maang li? 🏥",
      "Padh liya? Ab sunao kya likha tha? 😂",
      "Shabash! Time waste karne ka naya tarika. 👏",
      "Sarkari documents se bhi lamba hai ye. 📜",
      "Sign here: X_________ (Just kidding). 🖋️"
    ],

    // 15. Support
    'support': [
      "Ab tumhein bhi need padegi support ki? 🚑",
      "Kya tod diya tumne? Sach batao? 🛠️",
      "Hum hain na! Tension kyu lete ho? 🤝",
      "Dard bantna hai ya shikayat karni hai? 💔",
      "Paise maange toh mat aana, baaki sab theek hai. 💸",
      "Kripya line mein lage rahein... ⏳",
      "Hello! Kaun bol raha hai? ☎️",
      "Batao kya seva karein? (Chai paani nahi milega). ☕",
      "App crash kar diya kya? 😨",
      "Dil ka mamla hai toh hum help nahi kar sakte. ❤️"
    ],

    // 16. Logout
    'logout': [
      "Jaa rahe ho? Dil tod ke? 💔",
      "Dhoka! Sab dhoka hai! 😭",
      "Jaldi wapas aana, main akela darr jata hu. 🥺",
      "Kyu yrr? Maza nahi aa raha kya? 😒",
      "Mat jao na... please! 🙏",
      "Exam ki padhai karne ja rahe ho? Jhoot! 😂",
      "Thik hai, jao. Mujhe kya. (Crying inside) 🥲",
      "Logout kiya toh wapas login bhi karna padega! 🔄",
      "Bye Bye! Miss you! 👋",
      "Khana kha ke aana wapas! 🍔"
    ],

    // 17. Password
    'password_touch': [
      "Kya hua yrr, password kisi aur ko bhi bata diya kya? 😅",
      "Ye password kharab tha kya?",
      "Password badalne se paap dhul jaate toh kya baat thi... 🌊",
      "Duniya badal rahi hai, tum password badal lo. Sukoon milega! ✨",
      "Kaisa darr hai yrr? Itna secret kya hai account mein? 🤨",
      "Haan yrr change kar lo, khali dimaag aur khali account dono khatarnak hain! 💸",
      "Change toh karne ki soch rahe ho, par yaad rakh paoge naya wala? 💊",
      "Jaldi kar lo, kahin koi peeche se dekh na le! 👀"
    ],

    // 18. Bot Touch
    'bot_touch': [
      "Arre mujhe mat chedo! 😠 Gudgudi hoti hai.",
      "Apna kaam karo na yrr, mujhe kyu ghoor rahe ho? 📚",
      "Touch karne ke paise lagenge, free mein nahi hu main! 💸",
      "Yrr mujhe pasand nahi hai koi mujhe touch kare! Door raho. 🤚",
      "Padh lo yrr, mujhe touch karne se degree nahi milegi! 🎓",
      "Kya hai? Autograph chahiye ya thappad? 🤨",
      "Main ALIVE hu, koi khilona nahi! Haath peeche karo. 🤖💢",
      "Ungli mat karo yrr, system hang ho jayega tumhara! ⚠️",
      "Itna vella ho kya? Jaake assignment poora kar lo! 📄",
      "Tumhara phone hai iska matlab ye nahi ki tum mere maalik ho! 😎",
      "Shakal achhi ho na ho, harkatein toh achhi rakho! 😒",
      "Abey! Padhai likhai mein dhyan lagao, IAS-YAS bano... ✍️",
      "Screen ghis jayegi tumhari, bas karo ab! 📱",
      "Mujhe touch karke kya milega? Khazana? 💰❌",
      "Disturb mat karo, main ek important coding solve kar raha hu! 🤖",
      "Limit mein raho dost, bot hu par dimaag bohot tez hai! 🔥"
    ],

    // Welcome
    'welcome_male': ["Aaiye Jnab! Swagat hai aapka. 😎", "Oho! King is here! 👑", "Oho! BOSS is Here"],
    'welcome_female': ["Aaiye Malika-e-husn! ✨", "Welcome Queen! 👑", "Welcome Beautiful⭐", "Oho! BOSS is Here"],
  };

  @override
  void initState() {
    super.initState();
    // Breathing Animation
    _breathingController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _breathingAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut));

    // Bot Pop Effect Setup
    _botJumpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _botJumpAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _botJumpController, curve: Curves.easeInOut));
    loadProfile();
    _resetIdleTimer();
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _currPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confPassCtrl.dispose();
    _idleTimer?.cancel();
    _botHideTimer?.cancel();
    _botJumpController.dispose();
    super.dispose();
  }

  // ================= BOT LOGIC =================
  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(seconds: 15), () {
      _triggerBotReaction('idle'); // Idle message
    });
  }

  void _speak(String message) {
    if (!mounted) return;

    // --- YE LINE HAI MAIN JADU ---
    // Isse bot chota-bada hoga
    _botJumpController.forward(from: 0.0);

    setState(() {
      _botMessage = message;
      _showBotBubble = true;
    });

    _botHideTimer?.cancel();
    _botHideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showBotBubble = false);
    });
  }

  void _triggerBotReaction(String key) {
    _resetIdleTimer();
    if (botDialogues.containsKey(key)) {
      final list = botDialogues[key]!;
      _speak(list[Random().nextInt(list.length)]);
    }
  }

  void _handleDPTap() {
    if (profileImageUrl == null) {
      // Photo hai hi nahi, to view kyu kar rahe ho?
      _triggerBotReaction('dp_missing_view');
      // No Overlay opened in this case
    } else {
      _triggerBotReaction('dp_touch');
      // Open Photo Overlay
      setState(() => _activeOverlay = 'photo');
    }
  }

  // ================= LOAD DATA =================
  Future<void> loadProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final createdAt = DateTime.parse(user.createdAt);
      final formattedDate = "${createdAt.day}/${createdAt.month}/${createdAt.year}";

      // 🔥 FIX: Manual JSON Parsing for Reliability
      final response = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id);

      if (mounted) {
        setState(() {
          email = user.email ?? "";
          memberSince = formattedDate;
          if (user.appMetadata['provider'] == 'google') loginMethod = "Google Auth";

          if (response != null && response.isNotEmpty) {
            final data = response[0] as Map<String, dynamic>; // Manual Map

            fullName = data['full_name']?.toString() ?? "Student";
            phone = data['phone']?.toString() ?? "Not Added";
            gender = data['gender']?.toString() ?? "Not Selected";
            profileImageUrl = data['profile_image']?.toString();
            dob = data['dob']?.toString() ?? "Not Added";
            semester = data['semester']?.toString() ?? "";

            String c = data['course']?.toString() ?? "";
            String b = data['branch']?.toString() ?? "";
            String y = data['year']?.toString() ?? "";
            courseInfo = "$c $b $y".trim();
          }
          isLoading = false;
        });

        // WELCOME MESSAGE LOGIC
        Future.delayed(const Duration(milliseconds: 500), () {
          if (gender.toLowerCase().contains('male') && !gender.toLowerCase().contains('female')) {
            _triggerBotReaction('welcome_male');
          } else if (gender.toLowerCase().contains('female')) {
            _triggerBotReaction('welcome_female');
          } else {
            _speak("Or ji! Sab bdiya? 😎");
          }
        });
      }
    } catch (e) {
      // 🔥 OFFLINE LOGIC: Agar error aaya (matlab net nahi hai) to ye bolo
      if (mounted) {
        setState(() => isLoading = false);
        _triggerBotReaction('offline');
      }
    }
  }

  // ================= NOTIFICATION & ACTIONS =================
  void showTopMessage(String msg, {bool isError = false}) {
    if (!mounted) return;

    // Alive Bot Logic for generic errors not caught elsewhere
    if (isError) {
      // If specific password error, it is handled in updatePassword, otherwise here:
      if (!msg.toLowerCase().contains("password")) {
        _triggerBotReaction('notif_error');
      }
    }

    setState(() {
      _topMessage = msg;
      _topMessageColor = isError ? Colors.redAccent : Colors.green;
      _showTopMessage = true;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showTopMessage = false);
    });
  }

  // --- PASSWORD OVERLAY LOGIC ---
  void openPasswordOverlay() {
    // Reset fields
    _currPassCtrl.clear();
    _newPassCtrl.clear();
    _confPassCtrl.clear();
    _passLocalError = null;

    _triggerBotReaction('password_touch');
    setState(() => _activeOverlay = 'password');
  }

  Future<void> updatePassword() async {
    String current = _currPassCtrl.text.trim();
    String newP = _newPassCtrl.text.trim();
    String confP = _confPassCtrl.text.trim();

    setState(() => _passLocalError = null);

    // 1. Validation: Min Length 6
    if (newP.length < 6) {
      setState(() => _passLocalError = "Password too short (min 6)");
      _triggerBotReaction('password_short');
      return;
    }
    // 2. Validation: Max Length 12
    if (newP.length > 12) {
      setState(() => _passLocalError = "Password max length is 12 characters");
      _triggerBotReaction('password_long');
      return;
    }
    // 3. Validation: Match
    if (newP != confP) {
      setState(() => _passLocalError = "Passwords do not match");
      _triggerBotReaction('password_mismatch');
      return;
    }

    setState(() => _isPassUpdating = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null || user.email == null) return;

      // Re-auth check (Current Password)
      final authResponse = await supabase.auth.signInWithPassword(email: user.email!, password: current);
      if (authResponse.user == null) throw const AuthException("Wrong current password");

      await supabase.auth.updateUser(UserAttributes(password: newP));

      if (mounted) {
        _triggerBotReaction('password_success');
        showTopMessage("Password Changed Successfully! 🔒");
        setState(() => _activeOverlay = null); // Close Overlay
      }
    } catch (e) {
      setState(() {
        _isPassUpdating = false;
        _passLocalError = "Incorrect current password";
      });
      _triggerBotReaction('password_wrong_current');
    } finally {
      if(mounted) setState(() => _isPassUpdating = false);
    }
  }

  Future<void> _navigateToEdit() async {
    final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileEditPage(isFirstTime: false)));
    if (res == true) loadProfile();
  }

  // ================= MAIN BUILD (STACK OVERLAY SYSTEM) =================
  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.value == ThemeMode.dark;

    // --- CARD STYLE (BLACK GLASS TRANSPARENT) ---
    final cardColor = isDark ? Colors.black.withOpacity(0.25) : Colors.white;

    final textColor = isDark ? Colors.white : const Color(0xff2d3436);
    final subText = isDark ? Colors.white54 : Colors.grey.shade600;

    return Listener(
      onPointerDown: (_) => _resetIdleTimer(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false, // Prevents resizing, Overlay handles visibility
        body: GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity! < -550 || details.primaryVelocity! > 550) {
              Navigator.pop(context);
            }
          },
          child: Stack(
            children: [
              // 🔥🔥 LAYER 0: BACKGROUND (Positioned.fill ke andar) 🔥🔥
              Positioned.fill(child: ProfileSkyBackground(isDark: isDark)),

              // --- LAYER 1: MAIN CONTENT ---
              // 🔥 FIX APPLIED: Positioned.fill bahar hai, RepaintBoundary andar
              Positioned.fill(
                child: RepaintBoundary(
                  child: isLoading
                      ? Center(child: CircularProgressIndicator(color: Colors.orange))
                      : Padding(
                    padding: const EdgeInsets.only(top: 80),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      // Added padding at bottom to ensure scrolling past Bot
                      child: Column(
                        children: [
                          _buildProfileCard(isDark, cardColor, textColor, subText),
                          const SizedBox(height: 25),
                          _buildRightSide(cardColor, textColor, isDark),
                          const SizedBox(height: 120), // Extra space for Bot
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // --- LAYER 2: HEADER (NO BLUR) ---
              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(
                  padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 5, bottom: 10, left: 10, right: 10),
                  // Header thoda transparent taki peeche ka content dikhe (NO BLUR)
                  color: isDark ? Colors.black.withOpacity(0.8) : Colors.white.withOpacity(0.9),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_new, color: textColor),
                        onPressed: () => Navigator.pop(context),
                      ),
                      // CENTER LOGO
                      Image.asset(
                        isDark ? 'assets/WApplogo.png' : 'assets/AppLogo.png',
                        height: 45,
                        errorBuilder: (c,o,s) => Text("ALIVE", style: TextStyle(fontFamily: "Tinos", fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                      ),
                      // THEME TOGGLE (CHANGED TO SUN/MOON PNG)
                      GestureDetector(
                        onTap: () {
                          themeNotifier.value = themeNotifier.value == ThemeMode.dark
                              ? ThemeMode.light
                              : ThemeMode.dark;
                          _triggerBotReaction(themeNotifier.value == ThemeMode.dark ? 'dark_mode' : 'light_mode');
                          setState(() {});
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Image.asset(
                            themeNotifier.value == ThemeMode.dark ? 'assets/moon.png' : 'assets/sun.png',
                            height: 30,
                            width: 30,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // --- LAYER 3: NOTIFICATION BANNER ---
              AnimatedPositioned(
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                top: _showTopMessage ? 100 : -100,
                left: 20, right: 20,
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(color: _topMessageColor, borderRadius: BorderRadius.circular(20), boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 10)]),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.notifications_active, color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_topMessage ?? "", style: const TextStyle(color: Colors.white, fontFamily: "Tinos", fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    ],
                  ),
                ),
              ),

              // --- LAYER 4: ACTIVE OVERLAY (Behind Bot) ---
              if (_activeOverlay != null)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => setState(() => _activeOverlay = null), // Click outside closes overlay
                    child: Container(
                      color: Colors.black.withOpacity(0.65), // Dim background
                      child: Center(
                        child: SingleChildScrollView( // Allows scrolling if keyboard opens
                          child: GestureDetector(
                            onTap: () {}, // Click inside doesn't close
                            child: _buildOverlayContent(isDark),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // --- LAYER 5: ALIVE CHAT BOT (ALWAYS ON TOP) ---
              Positioned(
                bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? MediaQuery.of(context).viewInsets.bottom + 10 : 20,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: _showBotBubble ? 1.0 : 0.0,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8, right: 10),
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(maxWidth: 220),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15), bottomLeft: Radius.circular(15)),
                          boxShadow: [const BoxShadow(color: Colors.black38, blurRadius: 5, offset: Offset(2, 2))],
                        ),
                        child: Text(_botMessage, style: const TextStyle(fontFamily: "Tinos", color: Colors.black87, fontWeight: FontWeight.bold)),
                      ),
                    ),

                    // ScaleTransition
                    ScaleTransition(
                      scale: _botJumpAnimation,
                      child: GestureDetector(
                        onTap: () => _triggerBotReaction('bot_touch'),
                        child: Container(
                          width: 70,
                          height: 70,
                          clipBehavior: Clip.hardEdge,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            //border: Border.all(color: isDark ? Colors.yellow : Colors.purple, width: 1),
                            boxShadow: [const BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 4))],
                          ),
                          alignment: Alignment.center,
                          child: Transform.scale(scale: 1.7,
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.white,
                              backgroundImage: const AssetImage('assets/logo.png'),
                              onBackgroundImageError: (_,__) => const Icon(Icons.android, size: 30),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= OVERLAY CONTENT BUILDER =================
  Widget _buildOverlayContent(bool isDark) {
    // 1. PASSWORD CHANGE BOX
    if (_activeOverlay == 'password') {
      return Container(
        width: 350,
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xF0000000) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
          boxShadow: [const BoxShadow(color: Colors.black45, blurRadius: 15)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Change Password", style: TextStyle(fontFamily: "Tinos", fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
            const SizedBox(height: 20),
            _dialogInput(_currPassCtrl, "Current Password", isDark),
            const SizedBox(height: 10),
            _dialogInput(_newPassCtrl, "New Password (Max 12)", isDark),
            const SizedBox(height: 10),
            _dialogInput(_confPassCtrl, "Confirm Password", isDark),
            if (_passLocalError != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_passLocalError!, style: const TextStyle(color: Colors.redAccent, fontFamily: "Tinos")),
              ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => setState(() => _activeOverlay = null), child: const Text("Cancel")),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isPassUpdating ? null : updatePassword,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurpleAccent),
                  child: _isPassUpdating ? const CircularProgressIndicator(color: Colors.white) : const Text("Update", style: TextStyle(color: Colors.white)),
                )
              ],
            )
          ],
        ),
      );
    }

    // 2. PRIVACY & TERMS BOX
    if (_activeOverlay == 'privacy' || _activeOverlay == 'terms') {
      String title = _activeOverlay == 'privacy' ? "Privacy Policy" : "Terms & Conditions";
      String content = _activeOverlay == 'privacy' ? _privacyContent : _termsContent;
      return Container(
        width: 350,
        height: 500, // Fixed height to allow scrolling text
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xff1e1e1e) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          children: [
            Text(title, style: TextStyle(fontFamily: "Tinos", fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: Text(content, style: TextStyle(fontFamily: "Tinos", fontSize: 15, height: 1.5, color: isDark ? Colors.white70 : Colors.black87)),
              ),
            ),
            const SizedBox(height: 15),
            ElevatedButton(
                onPressed: () => setState(() => _activeOverlay = null),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                child: const Text("Close", style: TextStyle(color: Colors.white))
            )
          ],
        ),
      );
    }

    // 3. PHOTO VIEWER
    if (_activeOverlay == 'photo') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (profileImageUrl != null)
            ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(profileImageUrl!, width: 300, fit: BoxFit.contain)
            ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.close, color: Colors.black),
                  onPressed: () => setState(() => _activeOverlay = null)
              ),
              const SizedBox(width: 20),
              FloatingActionButton.extended(
                backgroundColor: Colors.orange,
                icon: const Icon(Icons.edit, color: Colors.white),
                label: const Text("Edit", style: TextStyle(color: Colors.white)),
                onPressed: () {
                  setState(() => _activeOverlay = null);
                  _navigateToEdit();
                },
              )
            ],
          )
        ],
      );
    }
    // Logout Confirm Box
    if (_activeOverlay == 'logout_confirm') {
      return Container(
        width: 320,
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: isDark ? Colors.black.withOpacity(0.5) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
          boxShadow: [const BoxShadow(color: Colors.black54, blurRadius: 15)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.login_outlined, color: const Color(0xffff0000), size: 50),
            const SizedBox(height: 5),
            Text("Confirm Logout", style: TextStyle(fontFamily: "Tinos", fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
            const SizedBox(height: 10),
            Text("Sach mein ja rahe ho? Dil tod ke? 💔", textAlign: TextAlign.center, style: TextStyle(fontFamily: "Tinos", color: isDark ? Colors.white70 : Colors.black87)),
            const SizedBox(height: 25),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // CANCEL BUTTON: Isse box band hoga
                TextButton(
                  onPressed: () => setState(() => _activeOverlay = null),
                  child: Text("Nahi Re!", style: TextStyle(fontFamily: "Tinos", color: isDark ? Colors.white70 : Colors.black54, fontWeight: FontWeight.bold)),
                ),
                // YES BUTTON: Isse asli logout hoga
                ElevatedButton(
                  onPressed: () async {
                    setState(() => _activeOverlay = null); // 1. Pehle confirm box band hota hai
                    _triggerBotReaction('logout');         // 2. Bot rota hai ("Jaa rahe ho?")
                    await Future.delayed(const Duration(seconds: 2)); // 3. Bot ke bolne ka wait
                    await supabase.auth.signOut();
                    if(mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_)=> const LoginPage()), (r)=>false);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                  child: const Text("Haan, Bye!", style: TextStyle(color: Colors.white, fontFamily: "Tinos", fontWeight: FontWeight.bold)),
                ),
              ],
            )
          ],
        ),
      );
    }
    return const SizedBox();
  }



  // ================= UI HELPERS =================
  Widget _dialogInput(TextEditingController c, String hint, bool isDark) {
    return TextField(
      controller: c,
      obscureText: true,
      maxLength: 12,
      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontFamily: "Tinos"),
      decoration: InputDecoration(
        labelText: hint,
        counterText: "",
        labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        filled: true,
        fillColor: isDark ? Colors.white10 : Colors.grey.shade200,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildProfileCard(bool isDark, Color cardColor, Color textColor, Color subText) {
    String crownImg = 'assets/queen_crown.png';
    bool isMale = gender.toLowerCase().contains('male') && !gender.toLowerCase().contains('female');
    if (isMale) crownImg = 'assets/queen_crown.png';

    // 🔥 LOGIC TO CHECK IF PROFILE IS COMPLETE
    bool isProfileComplete =
        fullName != "Student" && fullName != "Loading..." &&
            phone != "Not Added" &&
            dob != "Not Added" &&
            gender != "Not Selected" &&
            gender != "Not Added" &&
            profileImageUrl != null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: isDark ? Colors.black45 : Colors.grey.shade300, blurRadius: 15, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // DP SECTION
              GestureDetector(
                onTap: _handleDPTap,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blueAccent, width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 45,
                        backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                        backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl!) : null,
                        child: profileImageUrl == null ? Icon(Icons.person, size: 40, color: subText) : null,
                      ),
                    ),

                    // 🔥 CROWN: Only show if Profile is Complete
                    if (isProfileComplete)
                      Positioned(
                        top: -25,
                        right: -15,
                        child: Transform.rotate(
                          angle: 0.52,
                          child: Image.asset(crownImg, height: 40, errorBuilder: (c,o,s)=> const Icon(Icons.emoji_events, size: 40, color: Colors.amber)),
                        ),
                      ),

                    Positioned(
                      bottom: -5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: cardColor, width: 2),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))]
                        ),
                        child: Text(
                          semester.isNotEmpty ? semester : "Student",
                          style: const TextStyle(fontFamily: "Tinos", color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    )
                  ],
                ),
              ),

              const SizedBox(width: 20),

              // INFO SECTION
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => _triggerBotReaction('name'),
                      child: Row(
                        children: [
                          Flexible(child: _buildFancyName(textColor)),
                          const SizedBox(width: 5),

                          // 🔥 VERIFIED BADGE: Only show if Profile is Complete
                          if (isProfileComplete)
                            const Icon(Icons.verified, color: Colors.blue, size: 20),
                        ],
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(email, style: TextStyle(fontFamily: "Tinos", fontSize: 13, color: subText), overflow: TextOverflow.ellipsis, maxLines: 1),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green, width: 0.5)
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, color: Colors.green, size: 14),
                            SizedBox(width: 5),
                            Text("Verified Member", style: TextStyle(fontFamily: "Tinos", fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),

          const SizedBox(height: 20),
          Divider(color: isDark ? Colors.white10 : Colors.grey.shade200),
          const SizedBox(height: 10),

          GestureDetector(onTap: () => _triggerBotReaction('course'), child: _detailRow(Icons.school, "Course Info", courseInfo, textColor, subText, isDark)),
          GestureDetector(onTap: () => _triggerBotReaction('dob'), child: _detailRow(Icons.cake, "Date of Birth", dob, textColor, subText, isDark)),
          GestureDetector(onTap: () => _triggerBotReaction('phone'), child: _detailRow(Icons.phone, "Phone Number", phone, textColor, subText, isDark)),
          GestureDetector(onTap: () => _triggerBotReaction('gender'), child: _detailRow(Icons.person_outline, "Gender", gender, textColor, subText, isDark)),
          GestureDetector(onTap: () => _triggerBotReaction('login_method'), child: _detailRow(Icons.vpn_key, "Login Method", loginMethod, textColor, subText, isDark)),
          GestureDetector(onTap: () => _triggerBotReaction('member_since'), child: _detailRow(Icons.calendar_today, "Member Since", memberSince, textColor, subText, isDark)),
        ],
      ),
    );
  }

  Widget _buildRightSide(Color cardColor, Color textColor, bool isDark) {
    return Column(
      children: [
        _actionButton("Edit Profile", Icons.edit, Colors.orange, cardColor, textColor, _navigateToEdit),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: isDark?Colors.black26:Colors.grey.shade200, blurRadius: 10)]),
          child: Column(
            children: [
              _settingTile("Change Password", Icons.lock, Colors.blue, textColor, onTap: openPasswordOverlay),
              _divider(isDark),

              SwitchListTile(
                title: Text("Notifications", style: TextStyle(fontFamily: "Tinos", fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                secondary: BreathingIcon(icon: Icons.notifications, color: Colors.amber, animation: _breathingAnimation),
                value: notificationsEnabled,
                activeColor: Colors.green,
                onChanged: (val) {
                  setState(() => notificationsEnabled = val);
                  _triggerBotReaction(val ? 'notif_enabled' : 'notif_disabled');
                  showTopMessage(val ? "Notifications Enabled! 🔔" : "Notifications Disabled! 🔕");
                },
              ),
              _divider(isDark),

              _settingTile("Privacy Policy", Icons.security, Colors.purple, textColor, onTap: () {
                _triggerBotReaction('privacy');
                setState(() => _activeOverlay = 'privacy');
              }),
              _divider(isDark),

              _settingTile("Terms & Conditions", Icons.description, Colors.teal, textColor, onTap: () {
                _triggerBotReaction('terms');
                setState(() => _activeOverlay = 'terms');
              }),
              _divider(isDark),

              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  onExpansionChanged: (val) { if(val) _triggerBotReaction('support'); },
                  leading: BreathingIcon(icon: Icons.headset_mic, color: Colors.pink, animation: _breathingAnimation),
                  title: Text("Support", style: TextStyle(fontFamily: "Tinos", fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(15),
                      color: isDark ? Colors.white10 : Colors.grey.shade50,
                      child: Column(
                        children: [
                          Row(children: [Icon(Icons.chat, color: Colors.green, size: 20), SizedBox(width: 10), Text("+91 9876543210", style: TextStyle(fontFamily: "Tinos", color: textColor))]),
                          const SizedBox(height: 10),
                          Row(children: [Icon(Icons.email, color: Colors.blue, size: 20), SizedBox(width: 10), Flexible(child: Text("support@aliveapp.com", style: TextStyle(fontFamily: "Tinos", color: textColor)))]),
                        ],
                      ),
                    )
                  ],
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              _triggerBotReaction('logout');
              setState(() => _activeOverlay = 'logout_confirm');
            },
            icon: const Icon(Icons.logout, color: Colors.white),
            label: const Text("Log Out", style: TextStyle(fontFamily: "Tinos", fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
          ),
        )
      ],
    );
  }

  // ================= TEXT & STYLE HELPERS =================
  Widget _buildFancyName(Color textColor) {
    if (fullName == "Loading...") return Text(fullName, style: TextStyle(color: textColor));
    List<String> names = fullName.trim().split(" ");
    List<InlineSpan> spans = [];
    for (String part in names) {
      if (part.isNotEmpty) {
        spans.add(TextSpan(text: part[0], style: const TextStyle(color: Colors.red, fontSize: 24, fontWeight: FontWeight.bold)));
        spans.add(TextSpan(text: "${part.substring(1)} ", style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold)));
      }
    }
    return RichText(text: TextSpan(children: spans, style: const TextStyle(fontFamily: "Tinos")));
  }

  Widget _detailRow(IconData icon, String label, String value, Color color, Color subColor, bool isDark) {
    Color iconColor = subColor;
    if (!isDark) {
      final colors = [Colors.blue, Colors.orange, Colors.purple, Colors.teal, Colors.redAccent];
      iconColor = colors[Random().nextInt(colors.length)];
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        color: Colors.transparent,
        child: Row(
          children: [
            BreathingIcon(icon: icon, color: iconColor, animation: _breathingAnimation),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontFamily: "Tinos", fontSize: 12, color: subColor)),
                  Text(value, style: TextStyle(fontFamily: "Tinos", fontSize: 15, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _actionButton(String text, IconData icon, Color bg, Color cardColor, Color textCol, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(15), border: Border.all(color: bg.withOpacity(0.3), width: 1.5)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [BreathingIcon(icon: icon, color: bg, animation: _breathingAnimation), const SizedBox(width: 15), Text(text, style: TextStyle(fontFamily: "Tinos", fontSize: 16, fontWeight: FontWeight.bold, color: textCol))]),
            Icon(Icons.arrow_forward, color: bg, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _settingTile(String title, IconData icon, Color color, Color textCol, {VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      leading: BreathingIcon(icon: icon, color: color, animation: _breathingAnimation),
      title: Text(title, style: TextStyle(fontFamily: "Tinos", fontSize: 15, fontWeight: FontWeight.bold, color: textCol)),
      trailing: Icon(Icons.arrow_forward_ios, size: 14, color: textCol.withOpacity(0.5)),
    );
  }

  Widget _divider(bool isDark) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200, indent: 60, endIndent: 20);

  // --- CONTENT STRINGS ---
  final String _privacyContent = """
1. Privacy Policy
Effective Date: January 25, 2026

Welcome to Engineering Express. We respect your privacy and are committed to protecting your personal data. This Privacy Policy outlines how we handle your information within our mobile application.

Data We Collect
Personal Information: When you register or update your profile, we collect your full name, email address, phone number, course, branch, and academic year.

Device Identification: To enforce our security policy of a maximum of two devices per account, we collect unique device identifiers (Device IDs).

App Usage Security: We monitor device status for security purposes, including checks for Root access, USB Debugging, and Developer Options to prevent unauthorized app modifications.

How We Use Your Data
To provide access to educational notes and student management features.

To manage your account and prevent multiple unauthorized logins.

To secure our content by blocking screenshots and preventing emulators from accessing the app.

To process payments securely via Razorpay.

Data Storage & Third Parties
Your data is stored securely using Supabase cloud services.

We do not sell your personal data to any third parties. We only share data with service providers like Razorpay strictly for processing transactions.""";

  final String _termsContent = """
2. Terms and Conditions
By downloading or using the Engineering Express app, these terms will automatically apply to you.

1. Usage Restrictions
Device Limit: You are permitted to login to your account on a maximum of two (2) devices only. Attempting to bypass this limit may result in an automatic account suspension.

Content Protection: You are strictly prohibited from taking screenshots or screen recordings of the study materials. This is enforced via in-app technical blocks.

No Modding: Any attempt to use the app on a rooted device, an emulator, or with USB Debugging enabled is a violation of our security policy and will result in access being revoked.

2. Intellectual Property
All educational content, notes, and the app's source code are the property of the developer, Saksham Kaushik. You may not copy, modify, or distribute any part of the app without explicit permission.

3. Payments (Razorpay)
All payments for premium notes or features are handled by Razorpay.

Access to content will be granted only after successful verification of the payment by the gateway.

4. Account Termination
The admin reserves the right to ban or block any user found violating these terms, sharing their account with others, or attempting to hack the application.
""";
}

// ================= BREATHING ICON =================
class BreathingIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final Animation<double>? animation;

  const BreathingIcon({
    super.key,
    required this.icon,
    required this.color,
    this.animation,
    this.size = 22
  });

  @override
  Widget build(BuildContext context) {
    return Icon(icon, color: color, size: size);
  }
}

// 🔥🔥 RENAMED CLASS TO AVOID CONFLICT 🔥🔥
class ProfileSkyBackground extends StatefulWidget {
  final bool isDark;
  const ProfileSkyBackground({required this.isDark, super.key});
  @override
  State<ProfileSkyBackground> createState() => _ProfileSkyBackgroundState();
}

class _ProfileSkyBackgroundState extends State<ProfileSkyBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Offset> fixedStars = List.generate(60, (index) => Offset(Random().nextDouble(), Random().nextDouble()));

  @override
  void initState() { super.initState(); _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true); }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final nightGradient = const LinearGradient(colors: [Color(0xFF000000), Color(0xC2011165), Color(0xFF000000), Color(0xFF031920)], begin: Alignment.bottomCenter, end: Alignment.topCenter);
    final dayGradient = const LinearGradient(colors: [Color(0xFFE0C3FC), Color(0xFF8EC5FC), Color(0xFFFFCCB0)], begin: Alignment.topCenter, end: Alignment.bottomCenter);

    double starOpacity = widget.isDark ? 1.0 : 0.3;

    // 🔥 FIX: Positioned.fill removed from here to prevent ParentData error
    return Stack(children: [
      AnimatedContainer(duration: const Duration(milliseconds: 1000), curve: Curves.easeInOut, decoration: BoxDecoration(gradient: widget.isDark ? nightGradient : dayGradient)),
      AnimatedOpacity(
        duration: const Duration(milliseconds: 1000),
        opacity: starOpacity,
        child: AnimatedBuilder(animation: _controller, builder: (context, child) => CustomPaint(painter: StarFieldPainter(_controller.value, fixedStars), size: Size.infinite)),
      ),
    ]);
  }
}

class StarFieldPainter extends CustomPainter {
  final double animationValue; final List<Offset> stars; StarFieldPainter(this.animationValue, this.stars);
  @override
  void paint(Canvas canvas, Size size) { final paint = Paint()..color = Colors.white; for (int i = 0; i < stars.length; i++) { double opacity = (sin((animationValue * 2 * pi) + i) + 1) / 2 * 0.8; canvas.drawCircle(Offset(stars[i].dx * size.width, stars[i].dy * size.height), 1.5, paint..color = Colors.white.withOpacity(opacity)); } }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}