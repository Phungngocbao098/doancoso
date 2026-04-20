import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui'; // Thư viện để làm hiệu ứng mờ kính (blur)

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final userCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final rePassCtrl = TextEditingController(); // Cho Đăng ký
  bool isLogin = true; // Chuyển đổi giữa Đăng nhập & Đăng ký
  bool agreeTerms = false; // Checkbox cho Đăng ký

  // Hàm xử lý API (Giữ nguyên logic của bạn)
  Future<void> authAction() async {
    final path = isLogin ? 'login' : 'register';
    if (!isLogin && passCtrl.text != rePassCtrl.text) {
      _showSnack("Mật khẩu nhập lại không khớp!");
      return;
    }
    if (!isLogin && !agreeTerms) {
      _showSnack("Bạn cần đồng ý với điều khoản sử dụng!");
      return;
    }

    try {
      final res = await http.post(
        Uri.parse('http://10.0.2.2:8000/api/$path'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": userCtrl.text, "password": passCtrl.text}),
      );

      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 200) {
        if (isLogin) {
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          setState(() => isLogin = true);
          _showSnack("Đăng ký thành công! Hãy đăng nhập.");
        }
      } else {
        _showSnack(data['detail'] ?? "Lỗi xảy ra");
      }
    } catch (e) {
      _showSnack("Không thể kết nối đến Server");
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    // Định nghĩa màu sắc theo ảnh mẫu (Cam cho Đăng ký, Xanh cho Đăng nhập)
    Color mainColor = isLogin ? const Color(0xFF3861A5) : const Color(0xFFE67E22);
    Color buttonColor = isLogin ? const Color(0xFF1E3C72) : const Color(0xFFD35400);

    return Scaffold(
      body: Container(
        // 1. Ảnh nền (giống ảnh mẫu)
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: NetworkImage('https://picsum.photos/id/1010/800/1200'), // Thay bằng link ảnh thực tế nếu có
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          color: Colors.black.withOpacity(0.4), // Lớp phủ tối
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(25),
              // 2. Thẻ Glassmorphism (Kính mờ)
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5), // Hiệu ứng mờ
                  child: Container(
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: mainColor.withOpacity(0.85), // Màu nền thẻ bán trong suốt
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 3. Tiêu đề
                        Text(
                          isLogin ? "Đăng Nhập" : "Đăng Ký",
                          style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          isLogin ? "Chào mừng trở lại!\nĐăng nhập để tiếp tục." : "Tạo tài khoản mới để đọc\nsách & nghe audiobook!",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 35),

                        // 4. Các ô nhập liệu (Style giống ảnh mẫu)
                        _buildInput(controller: userCtrl, hint: "Địa chỉ email", icon: Icons.email_outlined),
                        const SizedBox(height: 18),
                        _buildInput(controller: passCtrl, hint: "Mật khẩu", icon: Icons.lock_outline, isPass: true),

                        // Ô nhập lại mật khẩu cho Đăng ký
                        if (!isLogin) ...[
                          const SizedBox(height: 18),
                          _buildInput(controller: rePassCtrl, hint: "Nhập lại mật khẩu", icon: Icons.lock_reset, isPass: true),
                          const SizedBox(height: 15),
                          // Checkbox điều khoản (Đăng ký)
                          Row(
                            children: [
                              Checkbox(
                                value: agreeTerms,
                                activeColor: Colors.white,
                                checkColor: buttonColor,
                                side: const BorderSide(color: Colors.white),
                                onChanged: (v) => setState(() => agreeTerms = v!),
                              ),
                              const Text("Tôi đồng ý với Điều khoản sử dụng", style: TextStyle(color: Colors.white70, fontSize: 13)),
                            ],
                          ),
                        ],

                        if (isLogin) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(onPressed: () {}, child: const Text("Quên mật khẩu?", style: TextStyle(color: Colors.white70))),
                          ),
                        ],

                        const SizedBox(height: 25),

                        // 5. Nút chính (Đỏ sậm/Cam sậm, bo góc)
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: authAction,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: buttonColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              elevation: 8,
                            ),
                            child: Text(
                              isLogin ? "Đăng Nhập" : "Đăng Ký",
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // 6. Chuyển đổi giữa Đăng nhập/Đăng ký
                        GestureDetector(
                          onTap: () => setState(() => isLogin = !isLogin),
                          child: Text(
                            isLogin ? "Chưa có tài khoản? Đăng Ký" : "Bạn đã có tài khoản? Đăng Nhập",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Widget bổ trợ để xây dựng ô nhập liệu đẹp
  Widget _buildInput({required TextEditingController controller, required String hint, required IconData icon, bool isPass = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9), // Đục gần như trắng
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPass,
        style: const TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.grey),
          suffixText: isPass ? "••••" : null, // Mẹo nhỏ giống ảnh mẫu
          suffixStyle: const TextStyle(color: Colors.grey),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}