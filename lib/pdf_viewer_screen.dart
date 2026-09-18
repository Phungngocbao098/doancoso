// pdf_viewer_screen.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

class PdfViewerScreen extends StatefulWidget {
  final String pdfUrl; // URL file PDF online từ server FastAPI
  final String bookTitle;
  final int bookId;
  final String username;
  final int initialPage;

  const PdfViewerScreen({
    super.key,
    required this.pdfUrl,
    required this.bookTitle,
    required this.bookId,
    required this.username,
    this.initialPage = 0,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  int _totalPages = 0;
  int _currentPage = 0;
  bool _isReady = false;
  String _errorMessage = '';
  PDFViewController? _pdfViewController; // Bộ điều khiển chuyển trang PDF

  String? _localPdfPath; // Đường dẫn lưu trữ file PDF tạm thời trên điện thoại
  bool _isBookmarked = false; // Trạng thái đã lưu bookmark trang này hay chưa
  final TextEditingController _noteController = TextEditingController();

  // Biến cờ hiệu để đảm bảo chỉ tự động nhảy trang đúng 1 lần duy nhất lúc mở sách
  bool _hasJumpedToInitialPage = false;

  // Hàm loại bỏ dấu tiếng Việt để đối sánh chuỗi tài khoản khách chính xác hơn
  String _removeDiacritics(String str) {
    const withDiacritics = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';
    const withoutDiacritics = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyydAAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';
    for (int i = 0; i < withDiacritics.length; i++) {
      str = str.replaceAll(withDiacritics[i], withoutDiacritics[i]);
    }
    return str;
  }

  // Thuộc tính kiểm tra xem User hiện tại có phải là khách hay không
  bool get _isGuest {
    final userLower = widget.username.trim().toLowerCase();
    final userNoSign = _removeDiacritics(userLower);
    return userLower.isEmpty ||
        userLower == 'null' ||
        userLower == 'undefined' ||
        userLower == 'guest' ||
        userNoSign.contains('khach');
  }

  @override
  void initState() {
    super.initState();
    // ✨ ĐÃ SỬA CHẶN CỨNG RANGEERROR: Đảm bảo trang khởi tạo ban đầu không bị âm
    _currentPage = widget.initialPage < 0 ? 0 : widget.initialPage;

    // Tải file PDF từ URL về bộ nhớ cache của thiết bị
    _downloadAndInitPdf();
  }

  // Tải file PDF online lưu thành file local tạm thời để tránh lỗi hiển thị trực tiếp từ URL
  Future<void> _downloadAndInitPdf() async {
    try {
      final url = widget.pdfUrl;
      if (!url.startsWith('http')) {
        if (mounted) {
          setState(() {
            _localPdfPath = url;
            _isReady = true;
          });
        }
        return;
      }

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/book_${widget.bookId}_temp.pdf');
        await file.writeAsBytes(response.bodyBytes, flush: true);

        if (mounted) {
          setState(() {
            _localPdfPath = file.path;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = "Không thể tải sách từ hệ thống (Mã lỗi: ${response.statusCode})";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Lỗi xử lý tệp tin: $e";
        });
      }
    }
  }

  // ✨ ĐÃ SỬA TOÀN DIỆN CHỐNG NULL: Kiểm tra trạng thái bookmark an toàn tuyệt đối
  Future<void> _checkBookmarkStatus() async {
    if (_isGuest || !mounted || _totalPages <= 0) return;

    // Chụp lại giá trị trang tại thời điểm gọi hàm để tránh bị lệch pha bất đồng bộ khi vuốt nhanh
    final int snapshotPage = _currentPage;
    if (snapshotPage < 0 || snapshotPage >= _totalPages) return;

    final url = Uri.parse('http://10.0.2.2:8000/api/bookmarks/${widget.username.trim()}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic>? bookmarks = jsonDecode(utf8.decode(response.bodyBytes));
        if (bookmarks == null) return;

        // So sánh bằng giá trị trang đã chụp cứng an toàn và dùng toán tử bọc lót chống dính Null phần tử
        final isExist = bookmarks.any((item) {
          if (item == null) return false;
          final int bId = item['book_id'] ?? 0;
          final int pNum = item['page_number'] ?? 0;
          return bId == widget.bookId && pNum == (snapshotPage + 1);
        });

        if (mounted && _currentPage == snapshotPage) {
          setState(() {
            _isBookmarked = isExist;
          });
        }
      }
    } catch (e) {
      debugPrint("Lỗi kiểm tra bookmark: $e");
    }
  }

  // Hàm ép nhảy trang an toàn bọc lót nhiều tầng
  void _safeJumpToInitialPage() async {
    if (_hasJumpedToInitialPage || _pdfViewController == null) return;

    // Trì hoãn một chút cho UI ổn định hẳn
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted && _totalPages > 0) {
      // Giới hạn trang nhảy tới phải nằm trong khoảng hợp lệ từ [0 đến _totalPages - 1]
      int targetPage = widget.initialPage;
      if (targetPage < 0) targetPage = 0;
      if (targetPage >= _totalPages) targetPage = _totalPages - 1;

      if (targetPage >= 0 && targetPage < _totalPages) {
        await _pdfViewController?.setPage(targetPage);
        setState(() {
          _currentPage = targetPage;
        });
      }
      setState(() {
        _hasJumpedToInitialPage = true;
      });

      // Sau khi nhảy trang thành công và có _totalPages cụ thể mới đi check bookmark
      if (!_isGuest) {
        _checkBookmarkStatus();
      }
    }
  }

  // ===================================================================
  // HỘP THOẠI THÔNG BÁO CHO TÀI KHOẢN KHÁCH & ĐIỀU HƯỚNG SANG ĐĂNG KÝ
  // ===================================================================
  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.orange, width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.lock_person_rounded, color: Colors.orange, size: 26),
              SizedBox(width: 10),
              Text(
                "Yêu cầu đăng nhập",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: const Text(
            "Bạn cần đăng nhập tài khoản để sử dụng tính năng đánh dấu trang và ghi chú sách này.",
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pushNamed(context, '/register');
              },
              child: const Text(
                "Đăng ký ngay?",
                style: TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                  fontSize: 13,
                ),
              ),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Hủy", style: TextStyle(color: Colors.white54)),
                ),
                const SizedBox(width: 4),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
                  },
                  child: const Text(
                    "Đăng nhập",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // Hàm gọi API xử lý đánh dấu trang sách gửi lên FastAPI Server
  Future<void> _toggleBookmarkOnServer(String noteText) async {
    if (!mounted || _totalPages <= 0 || _currentPage < 0 || _currentPage >= _totalPages) return;
    final url = Uri.parse('http://10.0.2.2:8000/api/bookmarks/toggle');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": widget.username.trim(),
          "book_id": widget.bookId,
          "page_number": _currentPage + 1,
          "note": noteText,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _isBookmarked = (data != null && data['status'] == 'added');
          });
        }
        _showSnackBar(
          data?['message'] ?? "Thao tác thành công!",
          _isBookmarked ? Colors.green : Colors.orange,
        );
      } else {
        _showSnackBar("Không thể thực hiện yêu cầu trên máy chủ!", Colors.redAccent);
      }
    } catch (e) {
      _showSnackBar("Lỗi kết nối máy chủ: $e", Colors.redAccent);
    }
  }

  // Hộp thoại lưu ghi chú hoặc xác nhận hủy bookmark
  void _showBookmarkNoteDialog() {
    _noteController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          _isBookmarked ? "Hủy đánh dấu trang?" : "Đánh dấu trang ${_currentPage + 1}",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: _isBookmarked
            ? const Text("Bạn có muốn gỡ trang này khỏi danh sách đã lưu không?", style: TextStyle(color: Colors.white70))
            : TextField(
          controller: _noteController,
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: "Nhập ghi chú nhỏ cho trang này (tùy chọn)...",
            hintStyle: TextStyle(color: Colors.white30, fontSize: 13),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("HỦY", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _isBookmarked ? Colors.redAccent : Colors.orange,
            ),
            onPressed: () {
              final note = _noteController.text.trim();
              Navigator.pop(context);
              _toggleBookmarkOnServer(note);
            },
            child: Text(
              _isBookmarked ? "XÓA" : "XÁC NHẬN",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.bookTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
        ),
        backgroundColor: Colors.grey[900],
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
              _isBookmarked ? Icons.bookmark_added_rounded : Icons.bookmark_border_rounded,
              color: _isBookmarked ? Colors.amber : Colors.white70,
              size: 26,
            ),
            onPressed: () {
              if (_isGuest) {
                _showLoginRequiredDialog();
                return;
              }
              _showBookmarkNoteDialog();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          if (_localPdfPath != null)
            PDFView(
              filePath: _localPdfPath!,
              onRender: (pages) {
                if (mounted) {
                  setState(() {
                    _totalPages = pages ?? 0;
                    _isReady = true;
                  });
                  _safeJumpToInitialPage();
                }
              },
              onError: (error) {
                if (mounted) {
                  setState(() {
                    _errorMessage = error.toString();
                  });
                }
              },
              onViewCreated: (pdfViewController) {
                _pdfViewController = pdfViewController;
                _safeJumpToInitialPage();
              },
              onPageChanged: (page, total) {
                // ✨ ĐÃ SỬA CHẶN CỨNG LỖI OVER-SCROLL KHI VUỐT TAY TẠI TRANG CUỐI
                if (page != null && mounted && _totalPages > 0) {
                  if (page >= 0 && page < _totalPages) {
                    setState(() {
                      _currentPage = page;
                    });
                    if (!_isGuest) {
                      _checkBookmarkStatus(); // Chạy cực kỳ an toàn vì đã có snapshot bảo vệ bên trong
                    }
                  }
                }
              },
            ),
          if (!_isReady && _errorMessage.isEmpty)
            const Center(child: CircularProgressIndicator(color: Colors.orange)),
          if (_errorMessage.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "Không thể hiển thị tài liệu: $_errorMessage",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _isReady && _totalPages > 0
          ? Container(
        height: 55,
        color: Colors.grey[900],
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Nút bấm lùi về trang trước
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 18),
              onPressed: _currentPage > 0
                  ? () {
                final targetPage = _currentPage - 1;
                if (targetPage >= 0) {
                  _pdfViewController?.setPage(targetPage);
                }
              }
                  : null,
            ),
            Text(
              "Trang ${_currentPage + 1} / $_totalPages",
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            // ✨ ĐÃ SỬA CHẶN CHỈ MỤC NÚT NEXT VÀ PHÒNG NGỪA TOTALPAGES TRỐNG
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 18),
              onPressed: _currentPage < (_totalPages - 1)
                  ? () {
                final targetPage = _currentPage + 1;
                if (targetPage < _totalPages) {
                  _pdfViewController?.setPage(targetPage);
                }
              }
                  : null,
            ),
          ],
        ),
      )
          : null,
    );
  }
}