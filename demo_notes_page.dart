import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart'; // 🔥 Native Player
import '../main.dart';

class DemoNotesPage extends StatefulWidget {
  const DemoNotesPage({super.key});

  @override
  State<DemoNotesPage> createState() => _DemoNotesPageState();
}

class _DemoNotesPageState extends State<DemoNotesPage> {
  final supabase = Supabase.instance.client;

  // --- Controllers ---
  late YoutubePlayerController _ytController;
  final TextEditingController _searchCtrl = TextEditingController();

  // --- Data Variables ---
  List<Map<String, dynamic>> branches = [];
  List<Map<String, dynamic>> subjects = [];
  List<Map<String, dynamic>> demoList = [];

  // --- Selection State ---
  String? selectedBranchId;
  String? selectedSubjectId;

  // --- UI State ---
  bool isLoading = false;
  bool isPlayerReady = false;

  // Current Playing
  String? currentPlayingTitle;
  String? currentPlayingSubject;

  @override
  void initState() {
    super.initState();
    // 1. Player Init (Default Empty)
    _ytController = YoutubePlayerController(
      initialVideoId: '',
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        enableCaption: true,
        forceHD: false, // Mobile data bachane ke liye default SD
      ),
    );

    // 2. Load Branches for Dropdown
    fetchBranches();

    // 3. 🔥 Load ALL Demos initially (Taaki page khali na dikhe)
    fetchAllDemos();
  }

  @override
  void deactivate() {
    _ytController.pause();
    super.deactivate();
  }

  @override
  void dispose() {
    _ytController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ================= 🟢 DATA FETCHING =================

  Future<void> fetchBranches() async {
    try {
      final res = await supabase.from('branches').select('id, name').order('name');
      if (mounted) setState(() => branches = List<Map<String, dynamic>>.from(res));
    } catch (e) { debugPrint("Branch Error: $e"); }
  }

  Future<void> fetchSubjects(String branchId) async {
    // Branch select hote hi uske subjects lao
    try {
      final res = await supabase.from('subjects').select('id, name').eq('branch_id', branchId).order('name');
      if (mounted) setState(() => subjects = List<Map<String, dynamic>>.from(res));
    } catch (e) { debugPrint("Subject Error: $e"); }
  }

  // 🔥 1. FETCH ALL DEMOS (Default View)
  Future<void> fetchAllDemos() async {
    setState(() => isLoading = true);
    try {
      final res = await supabase
          .from('units')
          .select('id, name, demo_video_url, subjects(name, branches(name))') // Deep Fetch
          .not('demo_video_url', 'is', null) // Sirf jinke paas video hai
          .eq('is_active', true)
          .order('created_at', ascending: false) // Latest pehle
          .limit(50); // Performance ke liye limit

      if (mounted) {
        setState(() {
          demoList = List<Map<String, dynamic>>.from(res);
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("All Demos Error: $e");
      setState(() => isLoading = false);
    }
  }

  // 🔥 2. FETCH BY FILTER (Jab user dropdown select kare)
  Future<void> fetchDemosByFilter() async {
    if (selectedSubjectId == null) return;
    setState(() => isLoading = true);
    try {
      final res = await supabase
          .from('units')
          .select('id, name, demo_video_url, subjects(name, branches(name))')
          .eq('subject_id', selectedSubjectId!) // Filter by Subject
          .not('demo_video_url', 'is', null)
          .eq('is_active', true)
          .order('order_index');

      if (mounted) {
        setState(() {
          demoList = List<Map<String, dynamic>>.from(res);
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  // 🔥 3. GLOBAL SEARCH (Search button dabane par)
  Future<void> performSearch() async {
    String query = _searchCtrl.text.trim();
    if (query.isEmpty) {
      // Agar search khali hai to wapas sab dikhao
      fetchAllDemos();
      return;
    }

    // Keyboard chupao taaki overlap na ho
    FocusScope.of(context).unfocus();

    setState(() {
      isLoading = true;
      // Search ke time filters reset kar dete hain visual clarity ke liye
      selectedBranchId = null;
      selectedSubjectId = null;
    });

    try {
      // Pure database me Unit Name dhundo
      final res = await supabase
          .from('units')
          .select('id, name, demo_video_url, subjects(name, branches(name))')
          .not('demo_video_url', 'is', null)
          .ilike('name', '%$query%') // Case insensitive search
          .limit(20);

      if (mounted) {
        setState(() {
          demoList = List<Map<String, dynamic>>.from(res);
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() { demoList = []; isLoading = false; });
    }
  }

  // ================= 🎥 PLAYER LOGIC =================

  void playVideo(String url, String title, String subjectInfo) {
    String? videoId = YoutubePlayer.convertUrlToId(url);
    if (videoId != null) {
      setState(() {
        isPlayerReady = true;
        currentPlayingTitle = title;
        currentPlayingSubject = subjectInfo;
      });
      _ytController.load(videoId);
      _ytController.play();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("❌ Invalid Video Link")));
    }
  }

  // ================= 🎨 UI BUILD =================

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        final isDark = currentMode == ThemeMode.dark;
        final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
        final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black87;
        final accentColor = isDark ? Colors.cyanAccent : const Color(0xFF6C63FF);

        // 🔥 YoutubePlayerBuilder prevents overlap issues automatically
        return YoutubePlayerBuilder(
          player: YoutubePlayer(
            controller: _ytController,
            showVideoProgressIndicator: true,
            progressIndicatorColor: accentColor,
            progressColors: ProgressBarColors(playedColor: accentColor, handleColor: accentColor),
          ),
          builder: (context, player) {
            return Scaffold(
              backgroundColor: bgColor,
              appBar: AppBar(
                backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                elevation: 0,
                leading: IconButton(icon: Icon(Icons.arrow_back_ios_new, color: textColor), onPressed: () => Navigator.pop(context)),
                title: Text("Demo Lectures", style: TextStyle(fontFamily: 'Tinos', fontWeight: FontWeight.bold, color: textColor)),
              ),
              body: Column(
                children: [
                  // 1. VIDEO PLAYER SECTION
                  if (isPlayerReady) ...[
                    player,
                    Container(
                      width: double.infinity, padding: const EdgeInsets.all(12),
                      color: isDark ? Colors.black : Colors.white,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text("Now Playing:", style: TextStyle(color: accentColor, fontSize: 10, fontWeight: FontWeight.bold)),
                        Text(currentPlayingTitle ?? "", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontFamily: 'Tinos', fontSize: 16)),
                        Text(currentPlayingSubject ?? "", style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12)),
                      ]),
                    ),
                  ],

                  // 2. SEARCH & FILTERS (Scrollable to prevent overflow)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: cardColor, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                    child: Column(
                      children: [
                        // 🔍 SEARCH BAR + BUTTON
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                style: TextStyle(color: textColor),
                                // Allow Enter key to search
                                textInputAction: TextInputAction.search,
                                onSubmitted: (_) => performSearch(),
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9 ]'))],
                                decoration: InputDecoration(
                                  hintText: "Search Unit (e.g. Unit 1)",
                                  hintStyle: TextStyle(color: textColor.withOpacity(0.4)),
                                  filled: true,
                                  fillColor: isDark ? Colors.black : Colors.grey[100],
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // 🔥 SEARCH BUTTON
                            InkWell(
                              onTap: performSearch,
                              child: Container(
                                height: 48, width: 48,
                                decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(12)),
                                child: Icon(Icons.search, color: isDark ? Colors.black : Colors.white),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 15),

                        // 🔽 DROPDOWNS (Filters)
                        Row(children: [
                          // Year Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedBranchId,
                              isExpanded: true, // Fix overflow text
                              decoration: _dropDeco("Year", isDark),
                              dropdownColor: cardColor,
                              style: TextStyle(color: textColor, fontFamily: 'Tinos'),
                              items: branches.map((b) => DropdownMenuItem(value: b['id'].toString(), child: Text(b['name'], overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (val) {
                                setState(() { selectedBranchId = val; selectedSubjectId = null; subjects = []; });
                                fetchSubjects(val!);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Subject Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedSubjectId,
                              isExpanded: true,
                              decoration: _dropDeco("Subject", isDark),
                              dropdownColor: cardColor,
                              style: TextStyle(color: textColor, fontFamily: 'Tinos'),
                              items: subjects.map((s) => DropdownMenuItem(value: s['id'].toString(), child: Text(s['name'], overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (val) {
                                setState(() { selectedSubjectId = val; _searchCtrl.clear(); });
                                fetchDemosByFilter(); // Filter lagate hi fetch karo
                              },
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),

                  // 3. RESULTS LIST
                  Expanded(
                    child: isLoading
                        ? Center(child: CircularProgressIndicator(color: accentColor))
                        : demoList.isEmpty
                        ? _buildEmptyState(textColor)
                        : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      // Keyboard khulne par list niche se cut na ho
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: demoList.length,
                      itemBuilder: (context, index) {
                        final demo = demoList[index];

                        // Data Extraction (Handling Nested Data safely)
                        String subName = "Unknown Subject";
                        String branchName = "";
                        if (demo['subjects'] != null) {
                          subName = demo['subjects']['name'] ?? "";
                          if (demo['subjects']['branches'] != null) {
                            branchName = "(${demo['subjects']['branches']['name']})";
                          }
                        }

                        bool isPlaying = currentPlayingTitle == demo['name'];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                              color: isPlaying ? accentColor.withOpacity(0.1) : cardColor,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
                              border: Border.all(color: isPlaying ? accentColor : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)))
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: Container(
                              width: 50, height: 50,
                              decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                              child: Icon(Icons.play_circle_fill, color: accentColor, size: 30),
                            ),
                            title: Text(demo['name'], style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontFamily: 'Tinos')),
                            subtitle: Text("$subName $branchName", style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 12)),
                            trailing: ElevatedButton(
                                onPressed: () {
                                  FocusScope.of(context).unfocus();
                                  playVideo(demo['demo_video_url'], demo['name'], "$subName $branchName");
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: isDark ? Colors.black : Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                                child: const Text("Watch")
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _dropDeco(String hint, bool isDark) {
    return InputDecoration(labelText: hint, labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54), filled: true, fillColor: isDark ? Colors.black : Colors.grey[100], contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none));
  }

  Widget _buildEmptyState(Color textColor) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.video_library_outlined, size: 60, color: textColor.withOpacity(0.3)), const SizedBox(height: 15), Text("No Demos Found", style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Tinos')), const SizedBox(height: 5), Text("Try searching for 'Unit 1' or select 'All'", style: TextStyle(color: textColor.withOpacity(0.5)))]));
  }
}