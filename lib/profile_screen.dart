// profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// --- IMPORT CÁC MÀN HÌNH HỆ THỐNG ---
import 'admin_screen.dart';
import 'book_management_screen.dart';
import 'user_management_screen.dart';
import 'pdf_viewer_screen.dart';        // Trình xem PDF để nhảy trang bookmark
import 'admin_order_screen.dart';       // Giao diện duyệt đơn của Admin
import 'user_order_history_screen.dart'; // Giao diện lịch sử đơn của User

class ProfileScreen extends StatefulWidget {
  final String username;
  final bool isAdmin;

  const ProfileScreen({
    super.key,
    required this.username,
    this.isAdmin = false,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String _displayName;
  String _avatarUrl = "";
  bool _isUpdating = false;

  // Map lưu trữ Bookmark đã gom nhóm theo tên sách
  Map<String, List<dynamic>> _groupedBookmarks = {};
  bool _isLoadingBookmarks = true;

  // Kiểm tra xem tài khoản hiện tại có phải là tài khoản Khách (Guest) hay không
  bool get _isGuest {
    final userLower = widget.username.trim().toLowerCase();
    return userLower == 'guest' || userLower.isEmpty;
  }

  @override
  void initState() {
    super.initState();
    _displayName = _isGuest ? "Khách trải nghiệm" : widget.username;

    if (!_isGuest) {
      _loadProfileData();
      _fetchAndGroupBookmarks(); // Chỉ tải bookmark nếu KHÔNG phải là khách
    } else {
      _isLoadingBookmarks = false;
    }
  }

  // Tải dữ liệu hồ sơ cá nhân của người dùng
  Future<void> _loadProfileData() async {
    if (_isGuest) return;
    final url = Uri.parse('http://10.0.2.2:8000/api/admin/users');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> users = jsonDecode(utf8.decode(response.bodyBytes));
        final currentUser = users.firstWhere(
              (u) => u['username'] == widget.username,
          orElse: () => null,
        );

        if (currentUser != null && mounted) {
          setState(() {
            _displayName = currentUser['full_name'] ?? widget.username;
            _avatarUrl = currentUser['avatar_url'] ?? "";
          });
        }
      }
    } catch (e) {
      debugPrint("Không thể đồng bộ hồ sơ cá nhân: $e");
    }
  }

  // Tải danh sách bookmark từ API và tự động gom nhóm theo book_title
  Future<void> _fetchAndGroupBookmarks() async {
    if (_isGuest) return; // Bảo vệ: Khách thì không được phép gọi API này
    if (!mounted) return;
    setState(() => _isLoadingBookmarks = true);

    final String formattedUsername = widget.username.trim();
    final url = Uri.parse('http://10.0.2.2:8000/api/bookmarks/$formattedUsername');

    debugPrint("=== ĐANG KHỞI CHẠY LẤY BOOKMARK ===");
    debugPrint("Đường dẫn API gọi tới: $url");

    try {
      final response = await http.get(url);
      debugPrint("Mã phản hồi HTTP Status Code: ${response.statusCode}");

      if (response.statusCode == 200) {
        final List<dynamic> rawList = jsonDecode(utf8.decode(response.bodyBytes));

        debugPrint("DỮ LIỆU BOOKMARK NHẬN VỀ THÀNH CÔNG: $rawList");

        // Thuật toán gom nhóm Bookmark theo Tên Sách (book_title) phòng thủ cao
        Map<String, List<dynamic>> tempGroup = {};
        for (var item in rawList) {
          final String bookTitle = item['book_title'] ?? item['bookTitle'] ?? 'Sách Chưa Đặt Tên';

          if (!tempGroup.containsKey(bookTitle)) {
            tempGroup[bookTitle] = [];
          }
          tempGroup[bookTitle]!.add(item);
        }

        if (mounted) {
          setState(() {
            _groupedBookmarks = tempGroup;
            _isLoadingBookmarks = false;
          });
          debugPrint("Gom nhóm hoàn tất! Số lượng đầu sách đã lưu: ${_groupedBookmarks.keys.length}");
        }
      } else {
        debugPrint("Lỗi phản hồi API: Nhận mã trạng thái ${response.statusCode}");
        if (mounted) setState(() => _isLoadingBookmarks = false);
      }
    } catch (e) {
      debugPrint("Lỗi kết nối nghiêm trọng hoặc lỗi cú pháp JSON: $e");
      if (mounted) setState(() => _isLoadingBookmarks = false);
    }
    debugPrint("=== KẾT THÚC TIẾN TRÌNH LẤY BOOKMARK ===");
  }

  // API Cập nhật profile (Upload văn bản & Avatar file mới)
  Future<void> _updateProfile(String newName, File? imageFile) async {
    if (_isGuest) {
      _showSnackBar("Tài khoản khách không thể sửa thông tin!", Colors.orange);
      return;
    }
    setState(() => _isUpdating = true);
    final url = Uri.parse('http://10.0.2.2:8000/api/user/update_profile');

    try {
      var request = http.MultipartRequest('POST', url);
      request.fields['username'] = widget.username;
      request.fields['full_name'] = newName;

      if (imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('avatar_file', imageFile.path),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _displayName = data['full_name'];
          _avatarUrl = data['avatar_url'] ?? "";
        });
        _showSnackBar("Cập nhật thông tin cá nhân thành công!", Colors.green);
      } else {
        _showSnackBar("Không thể lưu thông tin lên máy chủ!", Colors.redAccent);
      }
    } catch (e) {
      _showSnackBar("Lỗi kết nối: $e", Colors.redAccent);
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  // Mở Dialog chỉnh sửa thông tin cá nhân & Ảnh đại diện
  void _showEditProfileDialog() {
    if (_isGuest) {
      _showSnackBar("Vui lòng đăng nhập để chỉnh sửa thông tin cá nhân!", Colors.orange);
      return;
    }
    final TextEditingController nameController = TextEditingController(text: _displayName);
    File? selectedImage;
    final ImagePicker picker = ImagePicker();

    showDialog(
      context: context,
      barrierDismissible: !_isUpdating,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                "Chỉnh sửa hồ sơ",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final XFile? image = await picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 70,
                        );
                        if (image != null) {
                          setDialogState(() {
                            selectedImage = File(image.path);
                          });
                        }
                      },
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 45,
                            backgroundColor: Colors.grey[800],
                            backgroundImage: selectedImage != null
                                ? FileImage(selectedImage!) as ImageProvider
                                : (_avatarUrl.isNotEmpty
                                ? NetworkImage(_avatarUrl) as ImageProvider
                                : const NetworkImage('https://i.pravatar.cc/150?img=11')),
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Tên hiển thị",
                        labelStyle: const TextStyle(color: Colors.orange),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white24),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.orange),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isUpdating ? null : () => Navigator.pop(context),
                  child: const Text("HỦY", style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isUpdating
                      ? null
                      : () async {
                    if (nameController.text.trim().isEmpty) {
                      _showSnackBar("Vui lòng nhập tên hiển thị!", Colors.redAccent);
                      return;
                    }
                    Navigator.pop(context);
                    await _updateProfile(nameController.text.trim(), selectedImage);
                  },
                  child: const Text("LƯU", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Hình nền phủ mờ phía sau
        Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: NetworkImage('https://picsum.photos/id/1010/800/1200'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Container(color: Colors.black.withOpacity(0.65)),
        SafeArea(
          child: RefreshIndicator(
            color: Colors.orange,
            onRefresh: () async {
              if (!_isGuest) {
                await _loadProfileData();
                await _fetchAndGroupBookmarks();
              }
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 15),

                  // ================= KHU VỰC THÔNG TIN TÀI KHOẢN =================
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.grey[800],
                              backgroundImage: _avatarUrl.isNotEmpty
                                  ? NetworkImage(_avatarUrl) as ImageProvider
                                  : const NetworkImage('https://i.pravatar.cc/150?img=11'),
                            ),
                            if (!_isGuest) // Chỉ hiển thị nút sửa cho tài khoản đã đăng nhập
                              GestureDetector(
                                onTap: _showEditProfileDialog,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Colors.orange,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.edit, color: Colors.white, size: 16),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Text(
                          _displayName,
                          style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: widget.isAdmin ? Colors.redAccent.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: widget.isAdmin ? Colors.redAccent : Colors.orange,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            widget.isAdmin ? "QUẢN TRỊ VIÊN (ADMIN)" : "THÀNH VIÊN",
                            style: TextStyle(
                              color: widget.isAdmin ? Colors.redAccent : Colors.orange,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _isGuest
                              ? "Hãy đăng nhập để lưu trữ hành trình đọc sách của riêng bạn"
                              : "Đọc sách là cách tốt nhất để mở cửa tri thức",
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  if (_isUpdating)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 20.0),
                        child: CircularProgressIndicator(color: Colors.orange),
                      ),
                    ),

                  // ================= KHU VỰC PHÂN QUYỀN ĐƠN HÀNG =================
                  const Text(
                    "GIAO DỊCH & MUA SẮM",
                    style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 8),

                  if (widget.isAdmin) ...[
                    Card(
                      color: Colors.black.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.redAccent.withOpacity(0.3), width: 1),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.receipt_long, color: Colors.redAccent, size: 26),
                        title: const Text(
                          "Quản Lý Đơn Hàng Mua Sách",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: const Text(
                          "Duyệt, gửi hàng hoặc hủy đơn hàng từ người dùng",
                          style: TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AdminOrderScreen()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (!_isGuest && !widget.isAdmin) ...[
                    Card(
                      color: Colors.black.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.orange.withOpacity(0.3), width: 1),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.history_edu, color: Colors.orange, size: 26),
                        title: const Text(
                          "Đơn Hàng Đã Đặt",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: const Text(
                          "Theo dõi tiến độ đơn hàng và trạng thái vận chuyển",
                          style: TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UserOrderHistoryScreen(username: widget.username),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ================= KHU VỰC ĐÁNH DẤU TRANG GOM NHÓM CHIA MỤC =================
                  const Row(
                    children: [
                      Icon(Icons.bookmarks_rounded, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "Trang sách đã đánh dấu",
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ĐIỀU KIỆN PHÂN QUYỀN KHÁCH VÀ TÀI KHOẢN THƯỜNG
                  _isGuest
                      ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1.5),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.lock_outline_rounded, color: Colors.orange, size: 48),
                        const SizedBox(height: 12),
                        const Text(
                          "Tính năng giới hạn",
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "Bạn đang dùng tài khoản khách trải nghiệm. Vui lòng đăng nhập để kích hoạt và sử dụng chức năng lưu trang sách.",
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          ),
                          onPressed: () {
                            Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
                          },
                          icon: const Icon(Icons.login_rounded, color: Colors.white),
                          label: const Text(
                            "ĐĂNG NHẬP NGAY",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        )
                      ],
                    ),
                  )
                      : _isLoadingBookmarks
                      ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(color: Colors.orange),
                    ),
                  )
                      : _groupedBookmarks.isEmpty
                      ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.bookmark_border, color: Colors.white38, size: 40),
                        SizedBox(height: 8),
                        Text(
                          "Bạn chưa đánh dấu trang sách nào!",
                          style: TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                      : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _groupedBookmarks.keys.length,
                    itemBuilder: (context, index) {
                      final bookTitle = _groupedBookmarks.keys.elementAt(index);
                      final bookmarks = _groupedBookmarks[bookTitle]!;

                      return Card(
                        color: Colors.black.withOpacity(0.6),
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.orange.withOpacity(0.3), width: 1),
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            initiallyExpanded: true,
                            collapsedIconColor: Colors.white54,
                            iconColor: Colors.orange,
                            title: Row(
                              children: [
                                const Icon(Icons.menu_book_rounded, color: Colors.orange, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    bookTitle.toUpperCase(),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        letterSpacing: 0.5
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(left: 26.0, top: 2),
                              child: Text(
                                "Đã đánh dấu: ${bookmarks.length} trang",
                                style: TextStyle(color: Colors.orange[300], fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            children: bookmarks.map((item) {
                              final int pageNum = item['page_number'] ?? item['page_index'] ?? 1;
                              final int bookId = item['book_id'] ?? 0;
                              final String pdfUrl = item['pdf_url'] ?? '';
                              final String note = item['note'] ?? item['notes'] ?? '';

                              return Container(
                                decoration: const BoxDecoration(
                                    border: Border(top: BorderSide(color: Colors.white12, width: 0.5))
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  title: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.bookmark_added_rounded, color: Colors.amber, size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Trang số $pageNum",
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600
                                        ),
                                      ),
                                      const Spacer(),
                                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 12),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 6.0),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                          color: Colors.black45,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.white10, width: 0.5)
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.edit_note_rounded, color: Colors.orange, size: 16),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              note.trim().isNotEmpty ? note : "Không có ghi chú cho trang này.",
                                              style: TextStyle(
                                                  color: note.trim().isNotEmpty ? Colors.white70 : Colors.white30,
                                                  fontSize: 11,
                                                  fontStyle: note.trim().isNotEmpty ? FontStyle.normal : FontStyle.italic
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  onTap: () async {
                                    if (pdfUrl.isEmpty) {
                                      _showSnackBar("Sách không có định dạng PDF để hiển thị!", Colors.redAccent);
                                      return;
                                    }

                                    final String correctedPdfUrl = pdfUrl.replaceAll('localhost', '10.0.2.2');

                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PdfViewerScreen(
                                          pdfUrl: correctedPdfUrl,
                                          bookTitle: bookTitle,
                                          bookId: bookId,
                                          username: widget.username,
                                          initialPage: pageNum - 1,
                                        ),
                                      ),
                                    );
                                    _fetchAndGroupBookmarks();
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 30),

                  // ================= QUẢN TRỊ VIÊN PHÂN QUYỀN SYSTEM =================
                  if (widget.isAdmin) ...[
                    const Text(
                      "QUẢN TRỊ HỆ THỐNG",
                      style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 12),

                    // 1. Nút Thêm Sách Mới (AdminScreen)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.grey[900]!.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.orange.withOpacity(0.25), width: 1),
                        boxShadow: [
                          BoxShadow(color: Colors.orange.withOpacity(0.05), blurRadius: 10, spreadRadius: 1),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: Colors.black.withOpacity(0.25),
                          child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.amber, size: 24),
                        ),
                        title: const Text("Quản trị hệ thống (Admin)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text("Thêm sách mới lên hệ thống máy chủ", style: TextStyle(color: Colors.white54, fontSize: 11)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white30),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => AdminScreen(adminUsername: widget.username)),
                          );
                        },
                      ),
                    ),

                    // 2. Nút Quản Lý Kho Sách (BookManagementScreen)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.grey[900]!.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.25), width: 1),
                        boxShadow: [
                          BoxShadow(color: Colors.redAccent.withOpacity(0.05), blurRadius: 10, spreadRadius: 1),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: Colors.black.withOpacity(0.25),
                          child: const Icon(Icons.library_books_rounded, color: Colors.redAccent, size: 22),
                        ),
                        title: const Text("Quản Lý Kho Sách", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text("Hiển thị danh sách, xem nền PR và gỡ sách khỏi hệ thống", style: TextStyle(color: Colors.white54, fontSize: 11)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white30),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const BookManagementScreen()),
                          );
                        },
                      ),
                    ),

                    // 3. Nút Quản Lý Người Dùng (UserManagementScreen)
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.grey[900]!.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.blueAccent.withOpacity(0.25), width: 1),
                        boxShadow: [
                          BoxShadow(color: Colors.blueAccent.withOpacity(0.05), blurRadius: 10, spreadRadius: 1),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: Colors.black.withOpacity(0.25),
                          child: const Icon(Icons.supervised_user_circle_rounded, color: Colors.blueAccent, size: 24),
                        ),
                        title: const Text("Quản Lý Tài Khoản", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text("Hiển thị danh sách và phân quyền người dùng hệ thống", style: TextStyle(color: Colors.white54, fontSize: 11)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white30),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const UserManagementScreen()),
                          );
                        },
                      ),
                    ),
                  ],

                  // ================= NÚT ĐĂNG XUẤT / ĐĂNG NHẬP KHÁCH =================
                  Container(
                    decoration: BoxDecoration(
                      color: _isGuest ? Colors.greenAccent.withOpacity(0.05) : Colors.redAccent.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _isGuest ? Colors.greenAccent.withOpacity(0.2) : Colors.redAccent.withOpacity(0.2),
                          width: 1
                      ),
                    ),
                    child: ListTile(
                      leading: Icon(
                        _isGuest ? Icons.login_rounded : Icons.logout_rounded,
                        color: _isGuest ? Colors.greenAccent : Colors.redAccent,
                        size: 22,
                      ),
                      title: Text(
                        _isGuest ? "Đăng Nhập Tài Khoản" : "Đăng Xuất Hệ Thống",
                        style: TextStyle(
                            color: _isGuest ? Colors.greenAccent : Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14
                        ),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: _isGuest ? Colors.greenAccent : Colors.redAccent,
                      ),
                      onTap: () => Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}