import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'main_screen.dart';
import 'explore_screen.dart'; // Đồng bộ để bắt biến static authTargetAction

class AuthScreen extends StatefulWidget {
  // Giữ nguyên constructor const ở đây vì định nghĩa class hoàn toàn hợp lệ
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final userCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool isLogin = true;

  @override
  void initState() {
    super.initState();
    // Kiểm tra tín hiệu chuyển tab Đăng ký/Đăng nhập ngay khi màn hình vừa được khởi tạo
    _checkAuthTargetAction();
  }

  // Tự động chuyển đổi giao diện dựa trên biến static được set từ explore_screen.dart
  void _checkAuthTargetAction() {
    if (ExploreScreen.authTargetAction != null) {
      setState(() {
        if (ExploreScreen.authTargetAction == 'register') {
          isLogin = false; // Chuyển giao diện sang Đăng Ký
        } else if (ExploreScreen.authTargetAction == 'login') {
          isLogin = true;  // Chuyển giao diện sang Đăng Nhập
        }
      });
      // Reset flag ngay lập tức sau khi xử lý xong để tránh lặp lại trạng thái ngoài ý muốn
      ExploreScreen.authTargetAction = null;
    }
  }

  // Xử lý logic Đăng nhập / Đăng ký qua API Backend
  Future<void> authAction() async {
    final String username = userCtrl.text.trim();
    final String password = passCtrl.text.trim();
    final String path = isLogin ? 'login' : 'register';

    if (username.isEmpty || password.isEmpty) {
      _showMsg("Vui lòng nhập đầy đủ thông tin!");
      return;
    }

    try {
      final res = await http.post(
        Uri.parse('http://10.0.2.2:8000/api/$path'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": username, "password": password}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        if (isLogin) {
          // Lấy quyền Admin từ API trả về (Mặc định là false nếu key không tồn tại)
          bool isAdmin = data['is_admin'] ?? false;

          if (mounted) {
            _showMsg("Đăng nhập thành công!");
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => MainScreen(
                  username: username,
                  isAdmin: isAdmin, // Truyền trực tiếp quyền Admin sang MainScreen
                ),
              ),
            );
          }
        } else {
          _showMsg("Đăng ký thành công! Hãy đăng nhập.");
          setState(() => isLogin = true);
          userCtrl.clear();
          passCtrl.clear();
        }
      } else {
        // Trích xuất thông báo chi tiết lỗi từ FastAPI/Backend nếu có
        final errorData = jsonDecode(res.body);
        final errorMsg = errorData['detail'] ?? "Tài khoản hoặc mật khẩu không chính xác!";
        _showMsg(errorMsg);
      }
    } catch (e) {
      _showMsg("Lỗi kết nối Server Backend!");
    }
  }

  void _showMsg(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  @override
  void dispose() {
    userCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Màu chủ đạo: Xanh dương cho Đăng nhập, Cam đất cho Đăng ký
    Color mainColor = isLogin ? const Color(0xFF3861A5) : const Color(0xFFE67E22);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: NetworkImage('https://picsum.photos/id/1010/800/1200'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          color: Colors.black.withOpacity(0.5),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(25),
              child: Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: mainColor.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                        isLogin ? "Đăng Nhập" : "Đăng Ký",
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)
                    ),
                    const SizedBox(height: 30),
                    _buildField(userCtrl, "Tên đăng nhập", Icons.person_outline),
                    const SizedBox(height: 15),
                    _buildField(passCtrl, "Mật khẩu", Icons.lock_outline, isPass: true),
                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                          onPressed: authAction,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          child: Text(
                            isLogin ? "ĐĂNG NHẬP" : "ĐĂNG KÝ",
                            style: TextStyle(color: mainColor, fontWeight: FontWeight.bold, fontSize: 16),
                          )
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => setState(() => isLogin = !isLogin),
                      child: Text(
                          isLogin ? "Chưa có tài khoản? Đăng ký" : "Đã có tài khoản? Đăng nhập",
                          style: const TextStyle(color: Colors.white)
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController c, String h, IconData i, {bool isPass = false}) {
    return TextField(
      controller: c,
      obscureText: isPass,
      decoration: InputDecoration(
        hintText: h,
        prefixIcon: Icon(i, color: Colors.grey[700]),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}