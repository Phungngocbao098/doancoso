// explore_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui'; // Thư viện bắt buộc để xử lý hiệu ứng làm mờ ImageFilter
import 'login_screen.dart';
import 'book_shelf_screen.dart'; // Import sang Kệ sách để chuyển trang nhanh

class ExploreScreen extends StatefulWidget {
  final String username;
  final bool isAdmin;

  const ExploreScreen({
    super.key,
    required this.username,
    this.isAdmin = false,
  });

  static String? authTargetAction;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> with TickerProviderStateMixin {
  // Bộ điều khiển phân tách Trang Chủ Sách và Cộng Đồng
  late TabController _mainTabController;

  List<dynamic> _posts = [];
  List<dynamic> _latestBooks = []; // Danh sách sách cho phần Trang chủ
  bool _isLoading = false;
  bool _isBookLoading = false;

  // Các biến xử lý bài đăng mới
  final TextEditingController _postController = TextEditingController();
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  // Bộ điều khiển Tab dành riêng cho Admin trong phân hệ Cộng đồng
  TabController? _adminTabController;

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 2, vsync: this);

    if (_isAdmin) {
      _adminTabController = TabController(length: 2, vsync: this);
      _adminTabController!.addListener(() {
        if (!_adminTabController!.indexIsChanging) {
          _fetchFeed();
        }
      });
    }
    _fetchFeed();
    _fetchExploreBooks(); // Tải song song danh sách sách mới cho Trang chủ
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    _adminTabController?.dispose();
    _postController.dispose();
    super.dispose();
  }

  bool get _isGuest {
    final userLower = widget.username.trim().toLowerCase();
    return userLower.isEmpty ||
        userLower == 'guest' ||
        userLower == 'null' ||
        userLower == 'khách' ||
        userLower == 'khach' ||
        userLower.contains('khach') ||
        userLower.contains('guest');
  }

  bool get _isAdmin {
    return widget.isAdmin || widget.username.trim().toLowerCase() == 'admin';
  }

  // Lấy dữ liệu sách đồng bộ trực tiếp từ endpoint bán sách cho giao diện Trang chủ
  Future<void> _fetchExploreBooks() async {
    if (!mounted) return;
    setState(() => _isBookLoading = true);

    final url = Uri.parse('http://10.0.2.2:8000/api/shop-books');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
            _latestBooks = data.take(4).toList(); // Lấy tối đa 4 cuốn mới nhất hiển thị ngoài trang chủ
            _isBookLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isBookLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isBookLoading = false);
      debugPrint("Lỗi tải sách tại trang chủ Khám Phá: $e");
    }
  }

  bool _checkGuestAndShowWarning() {
    if (_isGuest) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF121212),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.white10, width: 1),
            ),
            title: const Row(
              children: [
                Icon(Icons.lock_outline, color: Colors.orange),
                SizedBox(width: 10),
                Text("Yêu cầu tài khoản", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: const Text(
              "Bạn đang trải nghiệm với vai trò Khách. Vui lòng đăng nhập hoặc đăng ký tài khoản mới để sử dụng tính năng này!",
              style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Hủy", style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold)),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.orange, width: 1.5),
                  foregroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  ExploreScreen.authTargetAction = 'register';
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const AuthScreen()),
                        (route) => false,
                  );
                },
                child: const Text("Đăng ký", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 4),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  ExploreScreen.authTargetAction = 'login';
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const AuthScreen()),
                        (route) => false,
                  );
                },
                child: const Text("Đăng nhập", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );
      return true;
    }
    return false;
  }

  Future<void> _fetchFeed() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });

    String endpoint = 'posts';
    if (_isAdmin && _adminTabController != null && _adminTabController!.index == 1) {
      endpoint = 'pending';
    }

    final url = Uri.parse('http://10.0.2.2:8000/api/feed/$endpoint?current_user=${widget.username.trim()}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _posts = jsonDecode(utf8.decode(response.bodyBytes));
          });
        }
      }
    } catch (e) {
      _showSnackBar("Lỗi tải bản tin: $e", Colors.redAccent);
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> _pickImage() async {
    if (_checkGuestAndShowWarning()) return;
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile != null) {
      setState(() { _selectedImage = File(pickedFile.path); });
    }
  }

  Future<void> _submitPost() async {
    if (_checkGuestAndShowWarning()) return;
    if (_postController.text.trim().isEmpty && _selectedImage == null) {
      _showSnackBar("Nội dung hoặc hình ảnh không được bỏ trống!", Colors.orange);
      return;
    }

    final url = Uri.parse('http://10.0.2.2:8000/api/feed/posts');
    final request = http.MultipartRequest('POST', url);
    request.fields['username'] = widget.username.trim();
    request.fields['content'] = _postController.text.trim();

    if (_selectedImage != null) {
      request.files.add(await http.MultipartFile.fromPath('file', _selectedImage!.path));
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        _postController.clear();
        setState(() { _selectedImage = null; });
        _showSnackBar(_isAdmin ? "Đăng bài thành công!" : "Đăng bài thành công! Vui lòng chờ Admin duyệt.", Colors.green);
        _fetchFeed();
      }
    } catch (e) {
      _showSnackBar("Lỗi gửi bài viết: $e", Colors.red);
    }
  }

  Future<void> _approvePost(int postId) async {
    final url = Uri.parse('http://10.0.2.2:8000/api/feed/posts/$postId/approve?username=${widget.username.trim()}');
    try {
      final response = await http.put(url);
      if (response.statusCode == 200) {
        _showSnackBar("Đã duyệt bài viết thành công!", Colors.green);
        _fetchFeed();
      }
    } catch (e) {
      _showSnackBar("Lỗi kết nối duyệt: $e", Colors.red);
    }
  }

  Future<void> _deletePost(int postId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white10)),
        title: const Text("Xác nhận xóa", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text("Bạn có chắc chắn muốn xóa bài viết này không?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Hủy", style: TextStyle(color: Colors.white38))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Xóa ngay", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirm != true) return;

    final url = Uri.parse('http://10.0.2.2:8000/api/feed/posts/$postId?username=${widget.username.trim()}');
    try {
      final response = await http.delete(url);
      if (response.statusCode == 200) {
        _showSnackBar("Đã xóa bài đăng thành công!", Colors.orange);
        _fetchFeed();
      }
    } catch (e) {
      _showSnackBar("Lỗi kết nối xóa bài: $e", Colors.red);
    }
  }

  Future<void> _toggleLike(int postId) async {
    if (_checkGuestAndShowWarning()) return;
    final url = Uri.parse('http://10.0.2.2:8000/api/feed/posts/$postId/like?username=${widget.username.trim()}');
    try {
      final response = await http.post(url);
      if (response.statusCode == 200) _fetchFeed();
    } catch (e) {
      _showSnackBar("Lỗi kết nối: $e", Colors.red);
    }
  }

  void _showCommentBottomSheet(int postId, List<dynamic> comments) {
    if (_checkGuestAndShowWarning()) return;
    final TextEditingController commentCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[950],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 16, right: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Bình luận", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                      child: comments.isEmpty
                          ? const Center(child: Text("Chưa có bình luận nào. Hãy là người đầu tiên!", style: TextStyle(color: Colors.white30)))
                          : ListView.builder(
                        shrinkWrap: true,
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          final c = comments[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(c['username'], style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text(c['content'], style: const TextStyle(color: Colors.white70)),
                            trailing: Text(c['created_at'].toString().substring(11, 16), style: const TextStyle(color: Colors.white30, fontSize: 11)),
                          );
                        },
                      ),
                    ),
                    const Divider(color: Colors.white10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: commentCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(hintText: "Viết bình luận...", hintStyle: TextStyle(color: Colors.white30), border: InputBorder.none),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send, color: Colors.orange),
                          onPressed: () async {
                            if (commentCtrl.text.trim().isEmpty) return;
                            final url = Uri.parse('http://10.0.2.2:8000/api/feed/posts/$postId/comment?username=${widget.username.trim()}');
                            final response = await http.post(url, body: {"content": commentCtrl.text.trim()});
                            if (response.statusCode == 200) {
                              final newComment = jsonDecode(utf8.decode(response.bodyBytes));
                              setModalState(() { comments.add(newComment); });
                              commentCtrl.clear();
                              _fetchFeed();
                            }
                          },
                        )
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              );
            }
        );
      },
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text("KHÁM PHÁ CỘNG ĐỒNG", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)),
          backgroundColor: Colors.black,
          elevation: 0,
          // TAB BAR CHÍNH: Tách biệt Trang chủ sách bán và Bản tin cộng đồng
          bottom: TabBar(
            controller: _mainTabController,
            indicatorColor: Colors.orange,
            labelColor: Colors.orange,
            unselectedLabelColor: Colors.white38,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [
              Tab(text: "TRANG CHỦ MUA SÁCH"),
              Tab(text: "DIỄN ĐÀN CỘNG ĐỒNG"),
            ],
          ),
        ),
        body: Stack(
          children: [
            // ✨ 1. KHỐI NỀN MỜ PHÍA SAU ĐỒNG BỘ TOÀN DIỆN CHO CẢ 2 PHÂN HỆ TAB
            Positioned.fill(
              child: Image.network(
                'https://images.unsplash.com/photo-1507842217343-583bb7270b66?q=80&w=1920&auto=format&fit=crop',
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(child: Container(color: Colors.black.withOpacity(0.72))),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(color: Colors.transparent),
              ),
            ),

            // 2. KHỐI NỘI DUNG CHUYỂN TAB CHẠY TRÊN NỀN KÍNH MỜ
            TabBarView(
              controller: _mainTabController,
              children: [
                // ==================== PHẦN 1: GIAO DIỆN TRANG CHỦ BÁN SÁCH MỚI BỔ SUNG ====================
                RefreshIndicator(
                  color: Colors.orange,
                  onRefresh: _fetchExploreBooks,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04), // Đồng bộ trong suốt mờ kính
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Khám Phá Sách Mới Mỗi Ngày", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(height: 6),
                              const Text(
                                "Hệ thống vừa cập nhật các đầu sách công nghệ và kỹ năng số bản quyền cực hot tại gian hàng.",
                                style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("SÁCH MỚI TRÊN KỆ", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => BookShelfScreen(username: widget.username, isAdmin: widget.isAdmin)),
                                ).then((_) => _fetchExploreBooks());
                              },
                              child: const Row(
                                children: [
                                  Text("Xem gian hàng", style: TextStyle(color: Colors.white54, fontSize: 12)),
                                  SizedBox(width: 2),
                                  Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 10),
                                ],
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 8),
                        _isBookLoading
                            ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                            : _latestBooks.isEmpty
                            ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(40),
                          alignment: Alignment.center,
                          child: const Text("Chưa tìm thấy sách bán nào trên server!", style: TextStyle(color: Colors.white38, fontSize: 13)),
                        )
                            : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _latestBooks.length,
                          itemBuilder: (context, index) {
                            final book = _latestBooks[index];
                            String rawImgUrl = book['image_path'] ?? book['image_url'] ?? '';
                            String correctedImgUrl = rawImgUrl.replaceAll('localhost', '10.0.2.2');
                            final double price = double.tryParse(book['price'].toString()) ?? 0.0;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.04), // Sửa lỗi mờ kính chuẩn hệ thống tối giản
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withOpacity(0.06)),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: correctedImgUrl.isNotEmpty
                                      ? Image.network(
                                    correctedImgUrl,
                                    width: 45,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      width: 45, height: 60, color: Colors.black26,
                                      child: const Icon(Icons.broken_image_rounded, color: Colors.white24, size: 18),
                                    ),
                                  )
                                      : Container(width: 45, height: 60, color: Colors.black26, child: const Icon(Icons.book_rounded, color: Colors.white24, size: 18)),
                                ),
                                title: Text((book['title'] ?? 'Chưa đặt tên').toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text("Tác giả: ${book['author'] ?? 'Ẩn danh'}", style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                ),
                                trailing: Text(
                                  "${price.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} đ",
                                  style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => BookShelfScreen(username: widget.username, isAdmin: widget.isAdmin)),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // ==================== PHẦN 2: BẢN TIN DIỄN ĐÀN CỘNG ĐỒNG ====================
                RefreshIndicator(
                  color: Colors.orange,
                  onRefresh: _fetchFeed,
                  child: Column(
                    children: [
                      if (_isAdmin && _adminTabController != null)
                        Container(
                          color: Colors.black.withOpacity(0.3),
                          child: TabBar(
                            controller: _adminTabController,
                            indicatorColor: Colors.orange,
                            labelColor: Colors.orange,
                            unselectedLabelColor: Colors.white38,
                            tabs: const [
                              Tab(text: "Bảng tin chung"),
                              Tab(text: "Hộp chờ duyệt"),
                            ],
                          ),
                        ),
                      // Khu vực soạn bài viết nền mờ kính trong suốt đồng bộ
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withOpacity(0.06)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(backgroundColor: Colors.orange, radius: 18, child: Icon(Icons.person, color: Colors.white, size: 20)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _postController,
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                    onTap: () {
                                      if (_isGuest) {
                                        FocusScope.of(context).unfocus();
                                        _checkGuestAndShowWarning();
                                      }
                                    },
                                    readOnly: _isGuest,
                                    decoration: InputDecoration(
                                      hintText: "Bạn đang nghĩ gì về cuốn sách này?",
                                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                                IconButton(icon: const Icon(Icons.image_outlined, color: Colors.orange, size: 22), onPressed: _pickImage),
                              ],
                            ),
                            if (_selectedImage != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0), // ✨ Đã sửa: Sử dụng đúng EdgeInsets.only cho vertical padding
                                child: Stack(
                                  alignment: Alignment.topRight,
                                  children: [
                                    ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(_selectedImage!, height: 140, width: double.infinity, fit: BoxFit.cover)),
                                    Positioned(
                                      top: 4, right: 4,
                                      child: CircleAvatar(
                                        backgroundColor: Colors.black54, radius: 14,
                                        child: IconButton(
                                          padding: EdgeInsets.zero, icon: const Icon(Icons.close, color: Colors.white, size: 16),
                                          onPressed: () { setState(() { _selectedImage = null; }); },
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            const Divider(color: Colors.white12, height: 20),
                            Align(
                              alignment: Alignment.centerRight,
                              child: SizedBox(
                                height: 32,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 14)),
                                  onPressed: _submitPost,
                                  icon: const Icon(Icons.post_add, color: Colors.black, size: 16),
                                  label: const Text("Đăng bài", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                      // Danh sách bài viết cộng đồng mờ kính
                      Expanded(
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                            : _posts.isEmpty
                            ? const Center(child: Text("Bản tin trống hoặc không có bài viết chờ duyệt!", style: TextStyle(color: Colors.white30)))
                            : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                          itemCount: _posts.length,
                          itemBuilder: (context, index) {
                            final post = _posts[index];
                            final bool isPending = post['status'] == 'pending';
                            final String postAuthor = post['username'] ?? 'Ẩn danh';
                            final List<dynamic> comments = post['comments'] ?? [];
                            final bool isLiked = post['is_liked'] == true;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: isPending ? Colors.orange.withOpacity(0.25) : Colors.white.withOpacity(0.06)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: Colors.orange.withOpacity(0.15),
                                            radius: 18,
                                            child: Text(postAuthor.isNotEmpty ? postAuthor.substring(0, 1).toUpperCase() : 'U', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                                          ),
                                          const SizedBox(width: 10),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(postAuthor, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                              Text(post['created_at'] ?? '', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
                                            ],
                                          )
                                        ],
                                      ),
                                      if (_isAdmin || widget.username.trim() == postAuthor)
                                        IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20), onPressed: () => _deletePost(post['id'])),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  if (isPending)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                                      child: const Text("Đang chờ duyệt", style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                  if (post['content'] != null && post['content'].toString().trim().isNotEmpty)
                                    Text(post['content'], style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.4)),
                                  if (post['image_url'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 10.0), // ✨ Đã sửa: Thay đổi từ EdgeInsets.symmetric sang EdgeInsets.only để tránh lỗi tham số bottom
                                      child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(post['image_url'], width: double.infinity, fit: BoxFit.fitWidth, errorBuilder: (context, error, stackTrace) => const SizedBox.shrink())),
                                    ),
                                  const Divider(color: Colors.white10, height: 24),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      if (_isAdmin && isPending)
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
                                          onPressed: () => _approvePost(post['id']),
                                          icon: const Icon(Icons.check_circle_outline, size: 16),
                                          label: const Text("Duyệt bài", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        )
                                      else ...[
                                        TextButton.icon(
                                          onPressed: () => _toggleLike(post['id']),
                                          icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border_rounded, color: isLiked ? Colors.red : Colors.white54, size: 18),
                                          label: Text("${post['likes_count'] ?? 0} Thích", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                        ),
                                        TextButton.icon(
                                          onPressed: () => _showCommentBottomSheet(post['id'], comments),
                                          icon: const Icon(Icons.comment_outlined, color: Colors.white54, size: 17),
                                          label: Text("${comments.length} Bình luận", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                        ),
                                      ],
                                    ],
                                  )
                                ],
                              ),
                            );
                          },
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}