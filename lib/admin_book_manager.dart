import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AdminBookManager extends StatefulWidget {
  final String username;
  const AdminBookManager({super.key, required this.username});

  @override
  State<AdminBookManager> createState() => _AdminBookManagerState();
}

class _AdminBookManagerState extends State<AdminBookManager> {
  List<dynamic> _books = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchBooks();
  }

  // Lấy danh sách sách từ API độc lập
  Future<void> _fetchBooks() async {
    setState(() => _isLoading = true);
    final url = Uri.parse('http://10.0.2.2:8000/api/shop-books');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          _books = jsonDecode(utf8.decode(response.bodyBytes));
        });
      }
    } catch (e) {
      _showSnackBar("Lỗi kết nối server lấy danh sách!", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Xóa sách khỏi gian hàng
  Future<void> _deleteBook(int bookId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Xác nhận xóa sách bán", style: TextStyle(color: Colors.white)),
        content: const Text("Sách này sẽ bị gỡ khỏi gian hàng bán và không ảnh hưởng tới sách đọc nghe ở trang chủ!", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Hủy")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Xóa ngay", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final url = Uri.parse('http://10.0.2.2:8000/api/shop-books/$bookId');
    try {
      final response = await http.delete(url);
      if (response.statusCode == 200) {
        _showSnackBar("Đã gỡ sách khỏi gian hàng thành công!", Colors.orange);
        _fetchBooks();
      } else {
        _showSnackBar("Không thể xóa sách trên Server!", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Lỗi kết nối khi xóa!", Colors.red);
    }
  }

  // Mở BottomSheet thêm sách mới (Đã tối ưu hóa State và báo lỗi chi tiết)
  void _openAddBookSheet() {
    final titleCtrl = TextEditingController();
    final authorCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    File? selectedImg;
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF181818),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        // Sử dụng StatefulBuilder để quản lý cập nhật giao diện chọn ảnh bên trong BottomSheet
        return StatefulBuilder(
          builder: (context, setModalState) {

            // Hàm chọn ảnh từ thư viện
            Future<void> pickImg() async {
              try {
                final picked = await picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 80,
                );
                if (picked != null) {
                  // PHẢI dùng setModalState để cập nhật UI hiển thị ảnh lập tức
                  setModalState(() {
                    selectedImg = File(picked.path);
                  });
                }
              } catch (e) {
                _showSnackBar("Lỗi khi mở thư viện ảnh: $e", Colors.red);
              }
            }

            // Hàm xử lý gửi dữ liệu lên server khi bấm "Đăng bán"
            Future<void> submitBook() async {
              // Báo lỗi chi tiết từng trường để Admin dễ debug kiểm tra
              if (titleCtrl.text.trim().isEmpty) {
                _showSnackBar("Vui lòng nhập Tên sách!", Colors.orange);
                return;
              }
              if (authorCtrl.text.trim().isEmpty) {
                _showSnackBar("Vui lòng nhập Tác giả!", Colors.orange);
                return;
              }
              if (priceCtrl.text.trim().isEmpty) {
                _showSnackBar("Vui lòng nhập Giá sách!", Colors.orange);
                return;
              }
              if (double.tryParse(priceCtrl.text.trim()) == null) {
                _showSnackBar("Giá sách phải là một số hợp lệ!", Colors.orange);
                return;
              }
              if (selectedImg == null) {
                _showSnackBar("Vui lòng chọn Ảnh bìa cho sách!", Colors.orange);
                return;
              }

              final url = Uri.parse('http://10.0.2.2:8000/api/shop-books');
              final req = http.MultipartRequest('POST', url);

              req.fields['title'] = titleCtrl.text.trim();
              req.fields['author'] = authorCtrl.text.trim();
              req.fields['price'] = priceCtrl.text.trim();
              req.fields['description'] = descCtrl.text.trim();
              req.files.add(await http.MultipartFile.fromPath('file', selectedImg!.path));

              try {
                // Hiển thị vòng xoay tải lúc đang upload dữ liệu
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.orange)),
                );

                final streamedRes = await req.send();
                final res = await http.Response.fromStream(streamedRes);

                Navigator.pop(context); // Đóng hộp thoại xoay tải (Loading)

                if (res.statusCode == 200) {
                  _showSnackBar("Đã đăng bán sách thành công!", Colors.green);
                  Navigator.pop(context); // Đóng Bottom Sheet
                  _fetchBooks(); // Tải lại danh sách sách quản lý ngoài màn hình chính
                } else {
                  _showSnackBar("Server từ chối yêu cầu (Lỗi ${res.statusCode})", Colors.red);
                }
              } catch (e) {
                Navigator.pop(context); // Đóng hộp thoại xoay tải
                _showSnackBar("Lỗi kết nối tải sách lên backend: $e", Colors.red);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 20, left: 20, right: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      "ĐĂNG BÁN SÁCH MỚI",
                      style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    _buildInput(titleCtrl, "Tên sách *", Icons.book),
                    const SizedBox(height: 10),
                    _buildInput(authorCtrl, "Tác giả *", Icons.person),
                    const SizedBox(height: 10),
                    _buildInput(priceCtrl, "Giá bán (VNĐ) *", Icons.monetization_on, isNumber: true),
                    const SizedBox(height: 10),
                    _buildInput(descCtrl, "Mô tả sách", Icons.description, maxLines: 2),
                    const SizedBox(height: 15),

                    // Khung Chọn ảnh
                    GestureDetector(
                      onTap: pickImg,
                      child: Container(
                        height: 130,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selectedImg == null ? Colors.white12 : Colors.orange.withOpacity(0.5),
                          ),
                        ),
                        child: selectedImg == null
                            ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, color: Colors.orange, size: 36),
                            SizedBox(height: 5),
                            Text("Tải ảnh bìa sách lên *", style: TextStyle(color: Colors.white38, fontSize: 12)),
                          ],
                        )
                            : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(selectedImg!, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),

                    // Nút xác nhận gửi đi
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 3,
                        ),
                        onPressed: submitBook, // Kích hoạt sự kiện đăng bán
                        child: const Text("ĐĂNG BÁN SÁCH", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
                    const SizedBox(height: 25),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSnackBar(String m, Color c) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        backgroundColor: c,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Quản Lý Sách Bán", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.orange), onPressed: _fetchBooks),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : _books.isEmpty
          ? const Center(child: Text("Không có sách bán nào!", style: TextStyle(color: Colors.white38)))
          : ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: _books.length,
        itemBuilder: (context, index) {
          final book = _books[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    book['image_path'] ?? 'https://picsum.photos/100/150',
                    width: 60,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 60, height: 80, color: Colors.grey[900],
                      child: const Icon(Icons.broken_image, color: Colors.white24),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(book['title'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text("Tác giả: ${book['author']}", style: const TextStyle(color: Colors.white38, fontSize: 12)),
                      const SizedBox(height: 6),
                      Text("${book['price']} đ", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => _deleteBook(book['id']),
                )
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.black,
        onPressed: _openAddBookSheet,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Widget _buildInput(TextEditingController ctrl, String hint, IconData icon, {bool isNumber = false, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white30),
        prefixIcon: Icon(icon, color: Colors.orange, size: 20),
        filled: true,
        fillColor: Colors.white10,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}