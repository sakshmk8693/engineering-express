import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../payment/razorpay_bridge.dart';
import '../main.dart'; // ✅ Theme Master Switch

class PurchasePage extends StatefulWidget {
  final String unitId;
  final String subjectId;
  final int price;

  const PurchasePage({
    super.key,
    required this.unitId,
    required this.subjectId,
    required this.price,
  });

  @override
  State<PurchasePage> createState() => _PurchasePageState();
}

class _PurchasePageState extends State<PurchasePage> with TickerProviderStateMixin {
  late RazorpayBridge razorpay;
  final supabase = Supabase.instance.client;

  bool isLoading = false;
  bool isAgreed = false;

  // Animation for Floating Ticket
  late AnimationController _floatCtrl;
  late Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    razorpay = getRazorpay();
    razorpay.init(
      onSuccess: _handlePaymentSuccess,
      onFailure: _handlePaymentError,
      onExternalWallet: (args) {},
    );

    // Dheere-dheere hawa mein tairne wala effect
    _floatCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -5, end: 5).animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    razorpay.clear();
    super.dispose();
  }

  // --- PAYMENT LOGIC (Same) ---
  Future<void> startPayment() async {
    if (!isAgreed) {
      _showSnack("Please accept terms to proceed", Colors.amber);
      return;
    }
    final session = supabase.auth.currentSession;
    if (session == null) {
      _showSnack("Session expired", Colors.red);
      return;
    }
    setState(() => isLoading = true);
    try {
      final res = await supabase.functions.invoke('create-order', body: {"unitId": widget.unitId}, headers: {'Authorization': 'Bearer ${session.accessToken}'});
      final data = res.data;
      if (data == null || data['id'] == null) throw Exception("Failed");

      var options = {
        'key': "rzp_live_S2zXNewVx4ZLTb",
        'amount': int.parse(data['amount'].toString()),
        'currency': 'INR',
        'name': 'Engineering Express',
        'order_id': data['id'],
        'description': 'VIP Access',
        'theme': {'color': '#D4AF37'} // Metallic Gold
      };
      razorpay.open(options);
    } catch (e) {
      setState(() => isLoading = false);
      _showSnack("Error starting payment", Colors.red);
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      final session = supabase.auth.currentSession;
      await supabase.functions.invoke('verify-payment', body: {"unitId": widget.unitId, "subjectId": widget.subjectId, "paymentId": response.paymentId}, headers: {'Authorization': 'Bearer ${session!.accessToken}'});
      if (mounted) Navigator.pop(context, true);
    } catch (e) { _showSnack("Verify Failed", Colors.red); }
    finally { if (mounted) setState(() => isLoading = false); }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() => isLoading = false);
    _showSnack("Payment Cancelled", Colors.orange);
  }

  void _showSnack(String msg, Color color) {
    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating));
  }

  // ================= UI: THE GOLDEN PASS =================

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {

        final isDark = currentMode == ThemeMode.dark;

        // Deep Premium Background
        final bgGradient = isDark
            ? const RadialGradient(colors: [Color(0xFF2C3E50), Color(0xFF000000)], center: Alignment.center, radius: 1.5)
            : const RadialGradient(colors: [Color(0xFFFFFFFF), Color(0xFFDDE1E7)], center: Alignment.center, radius: 1.5);

        final ticketColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black87;
        final goldColor = const Color(0xFFD4AF37); // Metallic Gold

        return Scaffold(
          body: Container(
            height: double.infinity,
            width: double.infinity,
            decoration: BoxDecoration(gradient: bgGradient),
            child: Stack(
              children: [

                // 1. BACK BUTTON (Floating Top Left)
                Positioned(
                  top: 50, left: 20,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.black12,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white12)
                      ),
                      child: Icon(Icons.close, color: textColor, size: 22),
                    ),
                  ),
                ),

                // 2. CENTER TICKET (Floating)
                Center(
                  child: AnimatedBuilder(
                    animation: _floatAnim,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _floatAnim.value),
                        child: child,
                      );
                    },
                    child: Container(
                      width: size.width * 0.85, // 85% width
                      // height: Automatic (Fits content)
                      decoration: BoxDecoration(
                        color: ticketColor,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 30, offset: const Offset(0, 15)),
                          if (isDark) BoxShadow(color: goldColor.withOpacity(0.1), blurRadius: 20, spreadRadius: -5)
                        ],
                      ),
                      child: Stack(
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min, // Fits only content
                            children: [

                              // --- TICKET HEAD ---
                              Container(
                                padding: const EdgeInsets.all(30),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withOpacity(0.03) : const Color(0xFF6C63FF).withOpacity(0.05),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                                ),
                                child: Column(
                                  children: [
                                    Icon(Icons.stars_rounded, size: 50, color: goldColor),
                                    const SizedBox(height: 10),
                                    Text("PREMIUM ACCESS", style: TextStyle(fontFamily: 'Tinos', letterSpacing: 3, fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.grey : Colors.grey.shade600)),
                                    const SizedBox(height: 5),
                                    Text("₹${widget.price}", style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: textColor)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                          border: Border.all(color: goldColor),
                                          borderRadius: BorderRadius.circular(20)
                                      ),
                                      child: Text("365 DAYS VALIDITY", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: goldColor)),
                                    )
                                  ],
                                ),
                              ),

                              // --- DASHED LINE SEPARATOR ---
                              SizedBox(
                                height: 30,
                                child: Row(
                                  children: List.generate(20, (index) => Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 3),
                                      child: Container(height: 1, color: Colors.grey.withOpacity(0.3)),
                                    ),
                                  )),
                                ),
                              ),

                              // --- TICKET BODY (Features & Pay) ---
                              Padding(
                                padding: const EdgeInsets.fromLTRB(30, 0, 30, 30),
                                child: Column(
                                  children: [
                                    _buildFeatureLine("HD Premium Notes", isDark, textColor),
                                    const SizedBox(height: 12),
                                    _buildFeatureLine("Video Lectures", isDark, textColor),
                                    const SizedBox(height: 12),
                                    _buildFeatureLine("Ad-Free Experience", isDark, textColor),

                                    const SizedBox(height: 25),

                                    // Checkbox
                                    GestureDetector(
                                      onTap: () => setState(() => isAgreed = !isAgreed),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(isAgreed ? Icons.check_circle : Icons.radio_button_unchecked,
                                              size: 20, color: isAgreed ? goldColor : Colors.grey),
                                          const SizedBox(width: 8),
                                          Text("Accept Terms & Conditions", style: TextStyle(fontSize: 12, color: Colors.grey)),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 20),

                                    // PAY BUTTON
                                    SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: ElevatedButton(
                                        onPressed: isAgreed ? startPayment : null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isDark ? Colors.white : Colors.black,
                                          foregroundColor: isDark ? Colors.black : Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          elevation: 5,
                                        ),
                                        child: isLoading
                                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                            : const Text("CONFIRM & PAY", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // --- THE TICKET "CUTOUTS" (Magic Circles) ---
                          // Left Circle
                          Positioned(
                            top: 135, left: -15, // Adjusted based on header height
                            child: Container(
                              height: 30, width: 30,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF101318) : const Color(0xFFDDE1E7), // Matches Background Gradient Start
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          // Right Circle
                          Positioned(
                            top: 135, right: -15,
                            child: Container(
                              height: 30, width: 30,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF101318) : const Color(0xFFDDE1E7), // Matches Background Gradient Start
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeatureLine(String text, bool isDark, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.check, size: 16, color: const Color(0xFFD4AF37)),
        const SizedBox(width: 10),
        Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor.withOpacity(0.8))),
      ],
    );
  }
}