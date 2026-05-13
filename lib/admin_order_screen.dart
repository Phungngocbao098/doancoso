// admin_order_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AdminOrderScreen extends StatefulWidget {
  const AdminOrderScreen({super.key});

  @override
  State<AdminOrderScreen> createState() => _AdminOrderScreenState();
}

class _AdminOrderScreenState extends State<AdminOrderScreen> {
  List<dynamic> orders = [];
  bool isLoading = true;
  String connectionError = '';

  @override
  void initState() {
    super.initState();
    fetchOrders();
  }

  Future<void> fetchOrders() async {
    // Sửa đường dẫn đồng bộ và truyền thêm query parameter ?current_user=admin
    final url = Uri.parse('http://10.0.2.2:8000/api/orders/admin/all?current_user=admin');
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
          connectionError = "Lỗi máy chủ: Mã lỗi ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        connectionError = "Không thể kết nối đến Backend Server!";
      });
      print("Lỗi tải đơn hàng: $e");
    }
  }

  Future<void> updateStatus(int orderId, String newStatus) async {
    // Sửa đường dẫn update theo đúng main.py và truyền param xác thực
    final url = Uri.parse('http://10.0.2.2:8000/api/orders/admin/status?current_user=admin');
    try {
      final response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "order_id": orderId, // Gửi đúng trường theo UpdateOrderStatusInput
          "status": newStatus
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cập nhật trạng thái thành công!"), backgroundColor: Colors.green),
        );
        fetchOrders();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cập nhật thất bại!")),
        );
      }
    } catch (e) {
      print("Lỗi kết nối cập nhật trạng thái: $e");
    }
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
        text = "Đã xóa (Hủy)";
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

  void _showStatusDialog(int orderId, String currentStatus) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text("Cập nhật trạng thái đơn", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.blue),
                title: const Text("Xác nhận đơn hàng", style: TextStyle(color: Colors.white70)),
                onTap: () {
                  Navigator.pop(context);
                  updateStatus(orderId, 'confirmed');
                },
              ),
              ListTile(
                leading: const Icon(Icons.local_shipping, color: Colors.green),
                title: const Text("Đã gửi hàng đi", style: TextStyle(color: Colors.white70)),
                onTap: () {
                  Navigator.pop(context);
                  updateStatus(orderId, 'shipped');
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.red),
                title: const Text("Xóa / Hủy đơn", style: TextStyle(color: Colors.white70)),
                onTap: () {
                  Navigator.pop(context);
                  updateStatus(orderId, 'cancelled');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Quản Lý Đơn Hàng (Admin)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchOrders,
          )
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
              const Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 48),
              const SizedBox(height: 12),
              Text(
                connectionError,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800]),
                onPressed: fetchOrders,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text("Thử kết nối lại", style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        ),
      )
          : orders.isEmpty
          ? const Center(child: Text("Chưa có đơn hàng nào cần duyệt.", style: TextStyle(color: Colors.white70)))
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          final List<dynamic> items = order['items'] ?? [];
          return Card(
            color: Colors.grey[900],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Đơn hàng #${order['id']}",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      _buildStatusBadge(order['status']),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 20),
                  Text(
                    "Người nhận: ${order['full_name'] ?? 'Chưa cập nhật'} (${order['username']})",
                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text("Số điện thoại: ${order['phone'] ?? 'Chưa cập nhật'}", style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text("Địa chỉ: ${order['address']}", style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  const Text("Sản phẩm đã mua:", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                  ...items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Text(
                      "- ${item['title'] ?? 'Sách bán lẻ'} (x${item['quantity'] ?? 1})",
                      style: const TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  )),
                  const Divider(color: Colors.white24, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Tổng tiền: ${order['total_amount']} đ",
                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _showStatusDialog(order['id'], order['status']),
                        child: const Text("Cập nhật"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}