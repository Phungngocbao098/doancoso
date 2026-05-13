// admin_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';

class AdminScreen extends StatefulWidget {
  final String adminUsername;
  const AdminScreen({super.key, required this.adminUsername});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final titleCtrl = TextEditingController();
  final authorCtrl = TextEditingController();

  // Biến lưu trữ tệp tin vật lý sau khi chọn từ máy
  File? selectedImage;
  File? selectedPdf;
  File? selectedAudio;

  bool isUploading = false; // Trạng thái đang tải file lên server

  // Hàm xử lý chọn File từ bộ nhớ thiết bị chuẩn hóa cao
  Future<void> pickFile(String type) async {
    FileType fileType = FileType.any;
    List<String>? allowedExtensions;

    if (type == 'image') {
      fileType = FileType.image;
    } else if (type == 'pdf') {
      fileType = FileType.custom;
      allowedExtensions = ['pdf'];
    } else if (type == 'audio') {
      fileType = FileType.audio;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: fileType,
        allowedExtensions: allowedExtensions,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          if (type == 'image') {
            selectedImage = File(result.files.single.path!);
          } else if (type == 'pdf') {
            selectedPdf = File(result.files.single.path!);
          } else if (type == 'audio') {
            selectedAudio = File(result.files.single.path!);
          }
        });
      }
    } catch (e) {
      _showSnackBar("Lỗi khi chọn tệp tin từ máy!", Colors.redAccent);
    }
  }

  // Hàm gửi request dạng Multipart Form-Data lên Server FastAPI
  Future<void> uploadAndAddBook() async {
    // Kiểm tra tính hợp lệ: Tên sách và Ảnh bìa là bắt buộc
    if (titleCtrl.text.trim().isEmpty) {
      _showSnackBar("Vui lòng nhập Tên sách!", Colors.orangeAccent);
      return;
    }
    if (selectedImage == null) {
      _showSnackBar("Vui lòng chọn Ảnh bìa từ thiết bị!", Colors.orangeAccent);
      return;
    }

    setState(() => isUploading = true);

    final url = Uri.parse('http://10.0.2.2:8000/api/admin/add_book');
    var request = http.MultipartRequest('POST', url);

    // 1. Thêm các trường thông tin Text thông thường
    request.fields['username'] = widget.adminUsername;
    request.fields['title'] = titleCtrl.text.trim();
    request.fields['author'] = authorCtrl.text.trim();

    try {
      // 2. Đính kèm file Ảnh bìa (Bắt buộc)
      request.files.add(
        await http.MultipartFile.fromPath('image_file', selectedImage!.path),
      );

      // 3. Đính kèm file Sách PDF (Nếu có chọn)
      if (selectedPdf != null) {
        request.files.add(
          await http.MultipartFile.fromPath('pdf_file', selectedPdf!.path),
        );
      }

      // 4. Đính kèm file Audio MP3 (Nếu có chọn)
      if (selectedAudio != null) {
        request.files.add(
          await http.MultipartFile.fromPath('audio_file', selectedAudio!.path),
        );
      }

      // Thực hiện gửi request lên Backend
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        _showSnackBar("Đã tải tệp lên và thêm sách thành công!", Colors.green);
        if (mounted) {
          Navigator.pop(context); // Quay lại trang cá nhân
        }
      } else {
        _showSnackBar("Lỗi hệ thống Backend: ${response.statusCode}", Colors.redAccent);
      }
    } catch (e) {
      _showSnackBar("Không thể kết nối đến server backend!", Colors.redAccent);
    } finally { // Đã sửa hoàn chỉnh tại đây từ final -> finally
      setState(() => isUploading = false);
    }
  }

  void _showSnackBar(String text, [Color color = Colors.black87]) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    authorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Thêm Sách Hệ Thống", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.black.withOpacity(0.4),
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Hình nền thư viện phủ mờ phía sau tạo chiều sâu PR cao cấp
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1481627834876-b7833e8f5570?q=80&w=1920&auto=format&fit=crop',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(child: Container(color: Colors.black.withOpacity(0.7))),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(color: Colors.transparent),
            ),
          ),

          SafeArea(
            child: RefreshIndicator(
              color: Colors.orange,
              onRefresh: () async {
                setState(() {
                  titleCtrl.clear();
                  authorCtrl.clear();
                  selectedImage = null;
                  selectedPdf = null;
                  selectedAudio = null;
                });
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    // Thẻ kính mờ bao bọc toàn bộ form nhập liệu
                    Container(
                      padding: const EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        color: Colors.grey[900]!.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 15,
                            spreadRadius: 2,
                            offset: const Offset(0, 8),
                          )
                        ],
                      ),
                      child: Column(
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.note_add_rounded, color: Colors.orange, size: 24),
                              SizedBox(width: 8),
                              Text(
                                "THÔNG TIN VĂN BẢN",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(titleCtrl, 'Tên đầu sách', Icons.book_rounded),
                          _buildTextField(authorCtrl, 'Tên tác giả', Icons.person_rounded),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Divider(color: Colors.white10, height: 1),
                          ),

                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_circle_rounded, color: Colors.orange, size: 24),
                              SizedBox(width: 8),
                              Text(
                                "ĐÍNH KÈM TỆP TIN",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),

                          // 1. Nút chọn Ảnh bìa trực tiếp từ máy (Bắt buộc)
                          _buildFilePickerButton(
                            label: "Chọn Ảnh Bìa (Bắt buộc)",
                            file: selectedImage,
                            icon: Icons.image_rounded,
                            accentColor: Colors.orangeAccent,
                            onTap: () => pickFile('image'),
                          ),

                          // 2. Nút chọn file Sách PDF trực tiếp từ máy (Tùy chọn)
                          _buildFilePickerButton(
                            label: "Chọn tệp tin Sách PDF",
                            file: selectedPdf,
                            icon: Icons.picture_as_pdf_rounded,
                            accentColor: Colors.redAccent,
                            onTap: () => pickFile('pdf'),
                          ),

                          // 3. Nút chọn file Audio MP3 trực tiếp từ máy (Tùy chọn)
                          _buildFilePickerButton(
                            label: "Chọn tệp tin Audio MP3",
                            file: selectedAudio,
                            icon: Icons.audiotrack_rounded,
                            accentColor: Colors.blueAccent,
                            onTap: () => pickFile('audio'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Nút xử lý gửi dữ liệu lên Database phát sáng Neon đồng bộ
                    Container(
                      width: double.infinity,
                      height: 55,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          if (!isUploading)
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.25),
                              blurRadius: 15,
                              spreadRadius: 1,
                              offset: const Offset(0, 4),
                            )
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: isUploading ? null : uploadAndAddBook,
                        icon: isUploading
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.orange, strokeWidth: 2),
                        )
                            : const Icon(Icons.cloud_upload_rounded, color: Colors.black, size: 22),
                        label: Text(
                          isUploading ? "ĐANG TIẾN HÀNH ĐẨY FILE..." : "ĐẨY TRỰC TIẾP LÊN DATABASE",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black, letterSpacing: 0.5),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          disabledBackgroundColor: Colors.grey[800],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget vẽ TextBox nhập dữ liệu chuẩn Glassmorphism
  Widget _buildTextField(TextEditingController controller, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
            prefixIcon: Icon(icon, color: Colors.orange, size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          ),
        ),
      ),
    );
  }

  // Widget thiết kế khu vực chọn File thông minh đồng bộ Glassmorphism nửa trong suốt
  Widget _buildFilePickerButton({
    required String label,
    required File? file,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap
  }) {
    final bool isSelected = file != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? accentColor.withOpacity(0.08) : Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? accentColor.withOpacity(0.5) : Colors.white.withOpacity(0.08),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? accentColor : Colors.white38, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white60,
                          fontWeight: FontWeight.bold,
                          fontSize: 13
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isSelected ? file.path.split('/').last : "Chưa chọn tệp tin nào",
                      style: TextStyle(
                        color: isSelected ? accentColor : Colors.white24,
                        fontSize: 11,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isSelected ? Icons.check_circle_rounded : Icons.arrow_forward_ios_rounded,
                color: isSelected ? Colors.greenAccent : Colors.white12,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}