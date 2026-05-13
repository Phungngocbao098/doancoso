// book_management_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui'; // Thư viện bắt buộc để xử lý hiệu ứng làm mờ ImageFilter

class BookManagementScreen extends StatefulWidget {
  const BookManagementScreen({super.key});

  @override
  State<BookManagementScreen> createState() => _BookManagementScreenState();
}

class _BookManagementScreenState extends State<BookManagementScreen> {
  List<dynamic> _books = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBooks();
  }

  // Lấy toàn bộ danh sách sách từ backend hệ thống
  Future<void> _fetchBooks() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final url = Uri.parse('http://10.0.2.2:8000/api/books');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _books = data;
            _isLoading = false;
          });
        }
      } else {
        _showSnackBar("Không thể tải danh sách sách từ server", Colors.redAccent);
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      _showSnackBar("Lỗi kết nối server: $e", Colors.redAccent);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Hàm gọi API xóa sách theo ID đã định danh chính xác
  Future<void> _deleteBook(int bookId, String title) async {
    final url = Uri.parse('http://10.0.2.2:8000/api/books/$bookId');
    try {
      final response = await http.delete(url);
      if (response.statusCode == 200 || response.statusCode == 204) {
        _showSnackBar("Đã xóa thành công sách: $title", Colors.greenAccent);
        _fetchBooks(); // Tải lại danh sách ngay lập tức để đồng bộ bộ nhớ
      } else {
        _showSnackBar("Xóa thất bại! Mã lỗi: ${response.statusCode}", Colors.redAccent);
      }
    } catch (e) {
      _showSnackBar("Lỗi khi kết nối xóa sách: $e", Colors.redAccent);
    }
  }

  // Hộp thoại xác nhận trước khi thực hiện xóa (Style Cao Cấp Glassmorphic)
  void _confirmDelete(int bookId, String title) {
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
              Text("Xác nhận xóa?", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            "Bạn có chắc chắn muốn xóa cuốn sách \"$title\" không?\nHành động này không thể hoàn tác.",
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("HỦY", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteBook(bookId, title);
              },
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 18),
              label: const Text("XÓA SÁCH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: backgroundColor.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
            "Quản Lý Kho Sách",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, letterSpacing: 0.5)
        ),
        backgroundColor: Colors.black.withOpacity(0.4),
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 24),
            tooltip: "Làm mới kho sách",
            onPressed: _fetchBooks,
          ),
        ],
      ),
      body: Stack(
        children: [
          // LỚP NỀN 1: HÌNH NỀN KHÔNG GIAN THƯ VIỆN
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1507842217343-583bb7270b66?q=80&w=1920&auto=format&fit=crop',
              fit: BoxFit.cover,
            ),
          ),

          // LỚP NỀN 2: PHỦ MÀU TỐI & LÀM MỜ NỀN NGHỆ THUẬT
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.75)),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(color: Colors.transparent),
            ),
          ),

          // LỚP 3: NỘI DUNG HIỂN THỊ CHÍNH
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                : _books.isEmpty
                ? Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[900]!.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.library_books_rounded, color: Colors.white.withOpacity(0.3), size: 54),
                    const SizedBox(height: 16),
                    const Text(
                      "Thư viện trống không!\nHãy thêm sách mới bằng nút Admin nhé.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.4, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            )
                : RefreshIndicator(
              color: Colors.orange,
              onRefresh: _fetchBooks,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                itemCount: _books.length,
                itemBuilder: (context, index) {
                  // Định danh tách biệt cục bộ theo đúng index của vòng lặp
                  final book = _books[index];
                  final int bookId = book['id'] ?? 0;
                  final String title = book['title'] ?? 'Không có tiêu đề';
                  final String author = book['author'] ?? 'Chưa rõ tác giả';
                  final String imageUrl = book['image_url'] ?? '';

                  final correctedImageUrl = imageUrl.replaceAll('localhost', '10.0.2.2');

                  return Container(
                    key: ValueKey(bookId), // ✨ THÊM KEY: Bắt buộc để Flutter phân biệt trạng thái riêng biệt của từng Item sách, tránh lỗi dính trạng thái bookmark cũ
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey[900]!.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orange.withOpacity(0.12),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: correctedImageUrl.isNotEmpty
                                  ? Image.network(
                                correctedImageUrl,
                                width: 55,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: 55,
                                  height: 80,
                                  color: Colors.black26,
                                  child: const Icon(Icons.broken_image_rounded, color: Colors.white24, size: 20),
                                ),
                              )
                                  : Container(
                                width: 55,
                                height: 80,
                                color: Colors.black26,
                                child: const Icon(Icons.book_rounded, color: Colors.white24, size: 20),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      letterSpacing: 0.3
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  "Tác giả: $author",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1),
                                  ),
                                  child: Text(
                                    "ID SÁCH: #$bookId",
                                    style: const TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          IconButton(
                            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 24),
                            tooltip: "Xóa sách khỏi kho",
                            onPressed: () => _confirmDelete(bookId, title),
                          ),
                        ],
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