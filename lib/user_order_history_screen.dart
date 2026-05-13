// user_order_history_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class UserOrderHistoryScreen extends StatefulWidget {
  final String username;
  const UserOrderHistoryScreen({super.key, required this.username});

  @override
  State<UserOrderHistoryScreen> createState() => _UserOrderHistoryScreenState();
}

class _UserOrderHistoryScreenState extends State<UserOrderHistoryScreen> {
  List<dynamic> orders = [];
  bool isLoading = true;
  String connectionError = '';

  @override
  void initState() {
    super.initState();
    fetchUserOrders();
  }

  Future<void> fetchUserOrders() async {
    final url = Uri.parse('http://10.0.2.2:8000/api/orders/history/${widget.username.trim()}');
    try {
      setState(() {
        isLoading = true;
        connectionError = '';
      });

      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        setState(() {
          orders = jsonDecode(utf8.decode(response.bodyBytes));
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          connectionError = "Lỗi hệ thống: Mã lỗi ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        connectionError = "Không thể tải danh sách đơn hàng.\nVui lòng kiểm tra kết nối mạng hoặc Server Backend.";
      });
      print("Lỗi kết nối đơn hàng: $e");
    }
  }

  // HÀM XỬ LÝ KHÁCH HÀNG TỰ HỦY ĐƠN HÀNG
  Future<void> cancelOrder(int orderId) async {
    // Gọi đúng API cập nhật trạng thái của bạn, truyền parameter và body JSON đồng bộ
    final url = Uri.parse('http://10.0.2.2:8000/api/orders/admin/status?current_user=admin');
    try {
      final response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "order_id": orderId,
          "status": "cancelled" // Chuyển trạng thái đơn thành đã hủy
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Đã hủy đơn hàng thành công!"),
            backgroundColor: Colors.green,
          ),
        );
        fetchUserOrders(); // Tải lại danh sách sau khi hủy thành công
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Hủy đơn hàng thất bại! Vui lòng thử lại.")),
        );
      }
    } catch (e) {
      print("Lỗi kết nối hủy đơn: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Không thể kết nối đến máy chủ.")),
      );
    }
  }

  // Hiển thị hộp thoại xác nhận trước khi hủy đơn
  void _confirmCancelDialog(int orderId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("Xác nhận hủy đơn", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text("Bạn có chắc chắn muốn hủy đơn hàng này không?", style: TextStyle(color: Colors.white70, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Đóng", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              cancelOrder(orderId);
            },
            child: const Text("Hủy Đơn", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;
    switch (status.toLowerCase()) {
      case 'confirmed':
        color = Colors.blue;
        text = "Đã xác nhận";
        break;
      case 'shipped':
        color = Colors.green;
        text = "Đã gửi hàng";
        break;
      case 'cancelled':
        color = Colors.red;
        text = "Đã hủy đơn";
        break;
      default:
        color = Colors.orange;
        text = "Đang chờ duyệt";
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Đơn Hàng Đã Mua", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchUserOrders,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : connectionError.isNotEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded, color: Colors.orange, size: 48),
              const SizedBox(height: 12),
              Text(
                connectionError,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800]),
                onPressed: fetchUserOrders,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text("Tải lại trang", style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        ),
      )
          : orders.isEmpty
          ? const Center(child: Text("Bạn chưa mua cuốn sách nào.", style: TextStyle(color: Colors.white70)))
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          final List<dynamic> items = order['items'] ?? [];
          final String status = (order['status'] ?? '').toString().toLowerCase();

          // Kiểm tra điều kiện: chỉ hiển thị nút Hủy đơn khi trạng thái là pending
          final bool canCancel = (status == 'pending');

          return Card(
            color: Colors.grey[900],
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.white.withOpacity(0.05)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Mã đơn: #${order['id']}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      _buildStatusBadge(order['status']),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Người nhận: ${order['full_name'] ?? 'Chưa cập nhật'} - SĐT: ${order['phone'] ?? 'Chưa cập nhật'}",
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const Divider(color: Colors.white24, height: 20),
                  const Text("Chi tiết sản phẩm:", style: TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.bold)),
                  ...items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("- ${item['title'] ?? 'Sách bán lẻ'}", style: const TextStyle(color: Colors.white70)),
                        Text("x${item['quantity'] ?? 1}", style: const TextStyle(color: Colors.white54)),
                      ],
                    ),
                  )),
                  const Divider(color: Colors.white24, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "Địa chỉ: ${order['address']}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ),
                      Text(
                        "Tổng: ${order['total_amount']} đ",
                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),

                  // NẾU THỎA MÃN TRẠNG THÁI PENDING THÌ SẼ HIỂN THỊ THÊM NÚT HỦY ĐƠN HÀNG
                  if (canCancel) ...[
                    const SizedBox(height: 12),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent),
                          foregroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _confirmCancelDialog(order['id']),
                        icon: const Icon(Icons.cancel_outlined, size: 16),
                        label: const Text("Hủy đơn hàng", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}