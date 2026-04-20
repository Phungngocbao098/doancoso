import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController userController = TextEditingController();
  final TextEditingController passController = TextEditingController();
  bool isLogin = true; // Biến để chuyển đổi giữa Đăng nhập & Đăng ký

  Future<void> handleAuth() async {
    String url = isLogin ? 'login' : 'register';
    final response = await http.post(
      Uri.parse('http://10.0.2.2:8000/api/$url'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "username": userController.text,
        "password": passController.text,
      }),
    );

    final result = jsonDecode(response.body);
    if (isLogin && result['status'] == 'success') {
      // Đăng nhập thành công -> Chuyển vào màn hình Sách
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? result['status'])));
      if (!isLogin) setState(() => isLogin = true); // Đăng ký xong thì chuyển sang Đăng nhập
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(isLogin ? "ĐĂNG NHẬP" : "ĐĂNG KÝ", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            TextField(controller: userController, decoration: const InputDecoration(labelText: "Username")),
            TextField(controller: passController, decoration: const InputDecoration(labelText: "Password"), obscureText: true),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: handleAuth, child: Text(isLogin ? "Vào App" : "Tạo tài khoản")),
            TextButton(
              onPressed: () => setState(() => isLogin = !isLogin),
              child: Text(isLogin ? "Chưa có tài khoản? Đăng ký ngay" : "Đã có tài khoản? Đăng nhập"),
            )
          ],
        ),
      ),
    );
  }
}