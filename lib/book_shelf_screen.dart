// book_shelf_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'admin_book_manager.dart';
import 'cart_screen.dart';

class BookShelfScreen extends StatefulWidget {
  final String username;
  final bool isAdmin;

  const BookShelfScreen({
    super.key,
    required this.username,
    this.isAdmin = false,
  });

  @override
  State<BookShelfScreen> createState() => _BookShelfScreenState();
}

class _BookShelfScreenState extends State<BookShelfScreen> {
  List<dynamic> _books = [];
  List<dynamic> _cart = [];
  bool _isLoading = false;

  String selectedCategory = "Tất cả";
  final TextEditingController _searchController = TextEditingController();

  final List<String> categories = [
    "Tất cả",
    "Kinh doanh",
    "Kỹ năng",
    "Tâm lý",
    "Nuôi dạy con",
    "Sức khỏe"
  ];

  @override
  void initState() {
    super.initState();
    _fetchBooks();
  }

  bool get _isGuest {
    final userLower = widget.username.trim().toLowerCase();
    return userLower.isEmpty || userLower == 'guest' || userLower.contains('khach');
  }

  bool get _isAdmin {
    return widget.isAdmin || widget.username.trim().toLowerCase() == 'admin';
  }

  Future<void> _fetchBooks() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final url = Uri.parse('http://10.0.2.2:8000/api/shop-books');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _books = jsonDecode(utf8.decode(response.bodyBytes));
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
        _showSnackBar("Không thể tải danh sách từ server (Mã: ${response.statusCode})", Colors.redAccent);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showSnackBar("Lỗi kết nối server bán sách!", Colors.redAccent);
    }
  }

  void _addToCart(dynamic book) {
    if (_isGuest) {
      _showSnackBar("Khách vui lòng đăng nhập để mua sách!", Colors.orangeAccent);
      return;
    }

    setState(() {
      int index = _cart.indexWhere((item) => item['id'] == book['id']);
      if (index >= 0) {
        _cart[index]['quantity'] = (_cart[index]['quantity'] ?? 1) + 1;
      } else {
        // ✨ ĐÃ SỬA TẠI ĐÂY: Ép kiểu an toàn khi đưa giá vào giỏ hàng
        final num rawPrice = book['price'] ?? 0;
        _cart.add({
          'id': book['id'],
          'title': book['title'],
          'price': rawPrice.toInt(),
          'image_path': book['image_path'] ?? book['image_url'],
          'quantity': 1
        });
      }
    });

    _showSnackBar("Đã thêm '${book['title']}' vào giỏ hàng!", Colors.greenAccent);
  }

  int get _cartItemCount {
    int count = 0;
    for (var item in _cart) {
      count += (item['quantity'] ?? 1) as int;
    }
    return count;
  }

  void _showSnackBar(String m, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: c,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredBooks = _books.where((book) {
      final title = (book['title'] ?? '').toString().toLowerCase();
      final author = (book['author'] ?? '').toString().toLowerCase();
      final category = (book['category'] ?? 'Khác').toString();
      final searchTxt = _searchController.text.toLowerCase();

      final matchesSearch = title.contains(searchTxt) || author.contains(searchTxt);
      final matchesCategory = selectedCategory == "Tất cả" || category == selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "GIAN HÀNG SÁCH NGÔI SAO",
          style: TextStyle(
            color: Color(0xFFFFD700),
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 0.5,
            fontFamily: 'serif',
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFFFFD700)),
            tooltip: "Làm mới gian hàng",
            onPressed: _fetchBooks,
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined, color: Color(0xFFFFD700)),
                tooltip: "Giỏ hàng của bạn",
                onPressed: () {
                  if (_isGuest) {
                    _showSnackBar("Khách vui lòng đăng nhập để sử dụng giỏ hàng!", Colors.orangeAccent);
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CartScreen(
                        username: widget.username,
                        cartItems: _cart,
                        onCartUpdated: (updatedCart) {
                          setState(() {
                            _cart = updatedCart;
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
              if (_cartItemCount > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(color: Colors.black45, blurRadius: 4, offset: const Offset(0, 2))
                      ],
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$_cartItemCount',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
            ],
          ),
          if (_isAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 4.0),
              child: IconButton(
                icon: const Icon(Icons.settings_suggest_rounded, color: Color(0xFFFFD700), size: 22),
                tooltip: "Quản lý sách bán",
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AdminBookManager(username: widget.username),
                    ),
                  );
                  _fetchBooks();
                },
              ),
            )
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1507842217343-583bb7270b66?q=80&w=1000&auto=format&fit=crop',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
              child: Container(
                color: Colors.black.withOpacity(0.55),
              ),
            ),
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {});
                          },
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: "Tìm sách, tác giả, chủ đề...",
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
                            prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.4), size: 20),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.tune_rounded, color: const Color(0xFFFFB040).withOpacity(0.8), size: 18),
                          const SizedBox(width: 6),
                          Text(
                            "Bộ lọc",
                            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 16, right: 8),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isSelected = cat == selectedCategory;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedCategory = cat;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFFFA040).withOpacity(0.2)
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? const Color(0xFFFFA040) : Colors.white12,
                            width: isSelected ? 1.2 : 1.0,
                          ),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: isSelected ? const Color(0xFFFFA040) : Colors.white70,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                    : filteredBooks.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.storefront_outlined, size: 64, color: Colors.white30),
                      const SizedBox(height: 14),
                      Text(
                        _books.isEmpty
                            ? "Gian hàng hiện tại chưa có sách bán!"
                            : "Không tìm thấy kết quả phù hợp!",
                        style: const TextStyle(color: Colors.white38, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                )
                    : RefreshIndicator(
                  color: Colors.orange,
                  onRefresh: _fetchBooks,
                  child: GridView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.63,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    itemCount: filteredBooks.length,
                    itemBuilder: (context, index) {
                      final book = filteredBooks[index];
                      return _buildBookGridCard(book);
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBookGridCard(dynamic book) {
    String rawImgUrl = book['image_path'] ?? book['image_url'] ?? '';
    String correctedImgUrl = rawImgUrl.replaceAll('localhost', '10.0.2.2');

    // ✨ ĐÃ SỬA LỖI ÉP KIỂU TẠI ĐÂY: Dùng kiểu 'num' hứng trước, sau đó gọi '.toInt()' để phòng ngừa lỗi double
    final num rawPrice = book['price'] ?? 0;
    final int priceInt = rawPrice.toInt();
    final String formattedPrice = "${priceInt.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} đ";

    int reviewCount = (book['id'] ?? 1) * 73 % 200 + 45;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                child: correctedImgUrl.isNotEmpty
                    ? Image.network(
                  correctedImgUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[900],
                    child: const Icon(Icons.broken_image_rounded, color: Colors.white24, size: 36),
                  ),
                )
                    : Container(
                  color: Colors.grey[900],
                  child: const Icon(Icons.book_rounded, color: Colors.white24, size: 36),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book['title'] ?? 'Chưa có tiêu đề',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  "Tác giả: ${book['author'] ?? 'Ẩn danh'}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFFFB040), size: 12),
                    const Icon(Icons.star_rounded, color: Color(0xFFFFB040), size: 12),
                    const Icon(Icons.star_rounded, color: Color(0xFFFFB040), size: 12),
                    const Icon(Icons.star_rounded, color: Color(0xFFFFB040), size: 12),
                    const Icon(Icons.star_rounded, color: Color(0xFFFFB040), size: 12),
                    const SizedBox(width: 4),
                    Text(
                      "($reviewCount)",
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        formattedPrice,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFFFFB040),
                            fontWeight: FontWeight.bold,
                            fontSize: 13
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _addToCart(book),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFFB040).withOpacity(0.6), width: 1.0),
                          color: const Color(0xFFFFB040).withOpacity(0.03),
                        ),
                        child: const Text(
                          "MUA",
                          style: TextStyle(
                              color: Color(0xFFFFB040),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}