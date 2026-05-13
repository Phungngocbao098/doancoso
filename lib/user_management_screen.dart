// user_management_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<dynamic> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  // Gọi API lấy danh sách tài khoản từ server FastAPI
  Future<void> _fetchUsers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final url = Uri.parse('http://10.0.2.2:8000/api/admin/users');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _users = data;
            _isLoading = false;
          });
        }
      } else {
        _showSnackBar("Không thể lấy danh sách người dùng", Colors.redAccent);
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      _showSnackBar("Lỗi kết nối máy chủ: $e", Colors.redAccent);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Gọi API thực hiện xóa tài khoản người dùng theo ID
  Future<void> _deleteUser(int userId, String username) async {
    final url = Uri.parse('http://10.0.2.2:8000/api/admin/users/$userId');
    try {
      final response = await http.delete(url);
      final responseData = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        _showSnackBar("Đã xóa tài khoản: $username", Colors.greenAccent);
        _fetchUsers(); // Tải lại danh sách sau khi xóa thành công để đồng bộ bộ nhớ
      } else {
        String errMsg = responseData['detail'] ?? "Xóa thất bại!";
        _showSnackBar(errMsg, Colors.redAccent);
      }
    } catch (e) {
      _showSnackBar("Lỗi khi kết nối xóa tài khoản: $e", Colors.redAccent);
    }
  }

  // Hộp thoại Glassmorphic xác nhận trước khi thực hiện xóa tài khoản
  void _confirmDelete(int userId, String username) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[950]!.withOpacity(0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.redAccent.withOpacity(0.3), width: 1),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 26),
              SizedBox(width: 10),
              Text(
                "Xác nhận xóa?",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            "Bạn có chắc chắn muốn xóa tài khoản \"$username\" khỏi hệ thống không?\nHành động này không thể hoàn tác.",
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("HỦY", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteUser(userId, username);
              },
              child: const Text("XÓA TÀI KHOẢN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Quản Lý Tài Khoản", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.black.withOpacity(0.4),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: "Làm mới danh sách",
            onPressed: _fetchUsers,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Ảnh nền kết nối mạng lưới công nghệ cao tạo không gian PR đồng bộ cực nghệ
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1521737604893-d14cc237f11d?q=80&w=1920&auto=format&fit=crop',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(child: Container(color: Colors.black.withOpacity(0.75))),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(color: Colors.transparent),
            ),
          ),

          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                : _users.isEmpty
                ? Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[900]!.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.supervised_user_circle_rounded, color: Colors.white38, size: 48),
                    SizedBox(height: 12),
                    Text(
                      "Hệ thống chưa có người dùng nào đăng ký!",
                      style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            )
                : RefreshIndicator(
              color: Colors.orange,
              onRefresh: _fetchUsers,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _users.length,
                itemBuilder: (context, index) {
                  final user = _users[index];
                  final int userId = user['id'] ?? 0;
                  final String username = user['username'] ?? 'Không tên';
                  final bool isUserAdmin = user['is_admin'] ?? false;

                  // Xử lý đọc link avatar an toàn từ Server
                  String avatarUrl = user['avatar_url'] ?? "";
                  if (avatarUrl.contains('localhost')) {
                    avatarUrl = avatarUrl.replaceAll('localhost', '10.0.2.2');
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey[900]!.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: isUserAdmin
                            ? Colors.amber.withOpacity(0.3)
                            : Colors.white.withOpacity(0.08),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        )
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.black.withOpacity(0.3),
                        backgroundImage: avatarUrl.isNotEmpty
                            ? NetworkImage(avatarUrl) as ImageProvider
                            : null,
                        child: avatarUrl.isEmpty
                            ? Icon(
                          isUserAdmin ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
                          color: isUserAdmin ? Colors.amber : Colors.orange,
                          size: 24,
                        )
                            : null,
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              username,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isUserAdmin)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.amber.withOpacity(0.4), width: 1),
                              ),
                              child: const Text(
                                "ADMIN",
                                style: TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          "Mã định danh ID: #$userId",
                          style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ),
                      // Nếu là tài khoản quản trị viên gốc mang tên 'admin', ẩn hoàn toàn nút xóa để tránh xoá nhầm
                      trailing: username.trim().toLowerCase() == 'admin'
                          ? null
                          : IconButton(
                        icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 24),
                        tooltip: "Gỡ tài khoản này",
                        onPressed: () => _confirmDelete(userId, username),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}