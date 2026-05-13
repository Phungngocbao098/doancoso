// cart_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';

class CartScreen extends StatefulWidget {
  final String username;
  final List<dynamic> cartItems;
  final Function(List<dynamic>) onCartUpdated;

  const CartScreen({
    super.key,
    required this.username,
    required this.cartItems,
    required this.onCartUpdated,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late List<dynamic> _localCart;
  final _formKey = GlobalKey<FormState>();

  // Bộ điều khiển Form giữ nguyên từ logic của bạn
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  String _selectedPayment = "Thanh toán khi nhận hàng (COD)";
  bool _isSubmitting = false;

  final List<String> _paymentMethods = [
    "Thanh toán khi nhận hàng (COD)",
    "Chuyển khoản Ngân hàng (MoMo/Banking)",
  ];

  @override
  void initState() {
    super.initState();
    // Đồng bộ map dữ liệu an toàn tránh lỗi kiểu dữ liệu
    _localCart = List.from(widget.cartItems.map((item) {
      return {
        'id': item['id'],
        'title': item['title'],
        'price': item['price'],
        'image_path': item['image_path'] ?? item['image_url'],
        'quantity': item['quantity'] ?? 1,
      };
    }));
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // Tính tổng tiền giỏ hàng (Kiểu double giữ nguyên theo Backend)
  double get _totalPrice {
    double total = 0;
    for (var item in _localCart) {
      double price = double.tryParse(item['price'].toString()) ?? 0;
      int qty = item['quantity'] ?? 1;
      total += price * qty;
    }
    return total;
  }

  // Định dạng hiển thị tiền tệ đẹp mắt (Ví dụ: 99.000 đ)
  String _formatPrice(double price) {
    return "${price.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} đ";
  }

  void _updateQuantity(int index, int delta) {
    setState(() {
      int newQty = (_localCart[index]['quantity'] ?? 1) + delta;
      if (newQty <= 0) {
        _localCart.removeAt(index);
      } else {
        _localCart[index]['quantity'] = newQty;
      }
    });
    widget.onCartUpdated(_localCart);
  }

  // Logic Gửi đơn hàng lên FastAPI Backend giữ nguyên 100% cấu trúc Payload của bạn
  Future<void> _processCheckout() async {
    if (_localCart.isEmpty) {
      _showSnackBar("Giỏ hàng của bạn đang trống!", Colors.orangeAccent);
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final url = Uri.parse('http://10.0.2.2:8000/api/orders/checkout');

    List<Map<String, dynamic>> itemsPayload = _localCart.map((item) {
      return {
        "book_id": int.tryParse(item['id'].toString()) ?? 0,
        "quantity": int.tryParse(item['quantity'].toString()) ?? 1,
        "price": double.tryParse(item['price'].toString()) ?? 0.0,
      };
    }).toList();

    final Map<String, dynamic> bodyData = {
      "username": widget.username,
      "full_name": _fullNameController.text.trim(),
      "phone": _phoneController.text.trim(),
      "address": _addressController.text.trim(),
      "total_amount": _totalPrice,
      "items": itemsPayload,
    };

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(bodyData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final res = jsonDecode(response.body);
        _showSnackBar(res['message'] ?? "Đặt hàng thành công!", Colors.greenAccent);

        setState(() {
          _localCart.clear();
        });
        widget.onCartUpdated(_localCart);

        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) Navigator.pop(context);
        });
      } else {
        print("Lỗi Backend trả về: ${response.body}");
        _showSnackBar("Giao dịch thất bại! Lỗi từ máy chủ.", Colors.redAccent);
      }
    } catch (e) {
      _showSnackBar("Không thể kết nối đến máy chủ thanh toán!", Colors.redAccent);
      print("Lỗi Checkout: $e");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String m, Color c) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: c,
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
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFFFD700)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Giỏ Hàng Của Bạn",
          style: TextStyle(
            color: Color(0xFFFFD700),
            fontWeight: FontWeight.bold,
            fontSize: 18,
            fontFamily: 'serif',
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // 1. Phông nền ảnh thư viện đồng bộ mờ kính nghệ thuật
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1507842217343-583bb7270b66?q=80&w=1000&auto=format&fit=crop',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
              child: Container(
                color: Colors.black.withOpacity(0.76),
              ),
            ),
          ),

          // 2. Nội dung chính hiển thị cuộn được
          _localCart.isEmpty
              ? const Center(
            child: Text(
              "Giỏ hàng rỗng! Hãy chọn cuốn sách bạn yêu thích.",
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          )
              : SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    "Sách Đã Chọn",
                    style: TextStyle(color: Color(0xFFFFB040), fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5)
                ),
                const SizedBox(height: 12),

                // Danh sách các mặt hàng (Item Cards) màu đen mờ kính
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _localCart.length,
                  itemBuilder: (context, index) {
                    final item = _localCart[index];
                    String imgUrl = (item['image_path'] ?? '').toString().replaceAll('localhost', '10.0.2.2');
                    double bookPrice = double.tryParse(item['price'].toString()) ?? 0.0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            // Ảnh bìa sách bo góc nhỏ gọn
                            Container(
                              width: 52,
                              height: 72,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: imgUrl.isNotEmpty
                                    ? Image.network(
                                  imgUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.grey[900],
                                    child: const Icon(Icons.broken_image_rounded, color: Colors.white24, size: 24),
                                  ),
                                )
                                    : Container(
                                  color: Colors.grey[900],
                                  child: const Icon(Icons.book_rounded, color: Colors.white24, size: 24),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Thông tin tiêu đề và giá tiền Việt Nam Đồng
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['title'] ?? 'Chưa cập nhật',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _formatPrice(bookPrice),
                                    style: const TextStyle(color: Color(0xFFFFB040), fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),

                            // Bộ tăng giảm số lượng (+ / -) màu Cam Ngôi Sao
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFFFFB040), size: 22),
                                  onPressed: () => _updateQuantity(index, -1),
                                ),
                                Text(
                                    "${item['quantity']}",
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFFFFB040), size: 22),
                                  onPressed: () => _updateQuantity(index, 1),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Divider(color: Colors.white12, height: 24),
                ),

                // Form điền thông tin Giao Hàng được thiết kế lại sang trọng
                const Text(
                    "Thông Tin Giao Hàng",
                    style: TextStyle(color: Color(0xFFFFB040), fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5)
                ),
                const SizedBox(height: 14),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _fullNameController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: "Họ và tên người nhận",
                          labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                          prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFFFFB040), size: 20),
                          enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white12), borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFFFB040)), borderRadius: BorderRadius.circular(12)),
                          errorBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.redAccent), borderRadius: BorderRadius.circular(12)),
                          focusedErrorBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.redAccent), borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        validator: (value) => (value == null || value.trim().isEmpty) ? "Vui lòng nhập tên người nhận" : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _phoneController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: "Số điện thoại nhận hàng",
                          labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                          prefixIcon: const Icon(Icons.phone_android_rounded, color: Color(0xFFFFB040), size: 20),
                          enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white12), borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFFFB040)), borderRadius: BorderRadius.circular(12)),
                          errorBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.redAccent), borderRadius: BorderRadius.circular(12)),
                          focusedErrorBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.redAccent), borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        validator: (value) => (value == null || value.trim().length < 9) ? "Vui lòng nhập SĐT hợp lệ" : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _addressController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: "Địa chỉ nhận hàng chi tiết",
                          labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                          prefixIcon: const Icon(Icons.location_on_outlined, color: Color(0xFFFFB040), size: 20),
                          enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white12), borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFFFB040)), borderRadius: BorderRadius.circular(12)),
                          errorBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.redAccent), borderRadius: BorderRadius.circular(12)),
                          focusedErrorBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.redAccent), borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        ),
                        validator: (value) => (value == null || value.trim().isEmpty) ? "Vui lòng nhập địa chỉ cụ thể" : null,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                const Text(
                    "Phương Thức Thanh Toán",
                    style: TextStyle(color: Color(0xFFFFB040), fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5)
                ),
                const SizedBox(height: 10),

                // Dropdown Chọn phương thức thanh toán mờ kính đẳng cấp
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    border: Border.all(color: Colors.white12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedPayment,
                      dropdownColor: Colors.grey[950],
                      isExpanded: true,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFFFFB040)),
                      items: _paymentMethods.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        if (newValue != null) {
                          setState(() => _selectedPayment = newValue);
                        }
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Tổng tiền thanh toán & Nút hành động đặt ở khối dưới
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Tổng thanh toán:", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                    Text(
                        _formatPrice(_totalPrice),
                        style: const TextStyle(color: Color(0xFFFFB040), fontSize: 22, fontWeight: FontWeight.bold)
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB040),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: _isSubmitting ? null : _processCheckout,
                    child: _isSubmitting
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                    )
                        : const Text(
                        "XÁC NHẬN ĐẶT HÀNG",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5)
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}