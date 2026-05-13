// main_screen.dart
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'package:path_provider/path_provider.dart';

// --- IMPORT CÁC MÀN HÌNH LIÊN QUAN ---
import 'pdf_viewer_screen.dart';
import 'profile_screen.dart';
import 'explore_screen.dart';
import 'book_shelf_screen.dart';
import 'cart_screen.dart';

// --- 1. CLASS MODEL BOOK ---
class Book {
  final int id;
  final String title;
  final String author;
  final String imageUrl;
  final String pdfUrl;
  final String audioUrl;
  final String description;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.imageUrl,
    required this.pdfUrl,
    required this.audioUrl,
    this.description = "",
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] ?? 0,
      title: json['title'] ?? 'Không có tiêu đề',
      author: json['author'] ?? 'Chưa rõ tác giả',
      imageUrl: json['image_url'] ?? '',
      pdfUrl: json['pdf_url'] ?? '',
      audioUrl: json['audio_url'] ?? '',
      description: json['description'] ?? '',
    );
  }
}

// --- 2. WIDGET TRANG CHỦ HIỂN THỊ DANH SÁCH THEO BỐ CỤC MỚI CÓ HÌNH NỀN SÁNG ĐẸP ---
class HomeScreen extends StatefulWidget {
  final String username;

  const HomeScreen({super.key, required this.username});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Book> books = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchBooks();
  }

  Future<void> fetchBooks() async {
    final url = Uri.parse('http://10.0.2.2:8000/api/books');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            books = data.map((json) => Book.fromJson(json)).toList();
            isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      print("Lỗi kết nối API: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.orange),
      );
    }

    final readingBooks = books.where((b) => b.pdfUrl.isNotEmpty).toList();
    final audioBooks = books.where((b) => b.audioUrl.isNotEmpty).toList();

    return RefreshIndicator(
      color: Colors.orange,
      onRefresh: fetchBooks,
      child: Stack(
        children: [
          // 1. LỚP NỀN KHÔNG GIAN THƯ VIỆN RÕ NÉT HƠN
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1507842217343-583bb7270b66?q=80&w=1000&auto=format&fit=crop',
              fit: BoxFit.cover,
            ),
          ),

          // 2. LỚP PHỦ LÀM MỜ VÀ NỀN TỐI NHẸ (Giảm opacity từ 0.75 xuống 0.4 giúp sáng hơn rất nhiều)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: Container(
                color: Colors.black.withOpacity(0.4),
              ),
            ),
          ),

          // 3. LỚP NỘI DUNG CHÍNH NỔI BẬT TRÊN NỀN SÁNG
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ==================== 1. BANNER THIẾT KẾ RỰC RỠ, NỔI BẬT ====================
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFA040), Color(0xFFFF6600), Color(0xFF903000)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: 15,
                          top: 15,
                          bottom: 15,
                          child: Opacity(
                            opacity: 0.3,
                            child: const Icon(
                                Icons.headset_rounded,
                                size: 130,
                                color: Colors.white
                            ),
                          ),
                        ),
                        Positioned(
                          right: 60,
                          top: 35,
                          child: Container(
                            width: 55,
                            height: 55,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                              gradient: const LinearGradient(colors: [Colors.orange, Colors.orangeAccent]),
                              boxShadow: [BoxShadow(color: Colors.orangeAccent.withOpacity(0.6), blurRadius: 20)],
                            ),
                            child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 28),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.local_fire_department, color: Colors.white, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        "XU HƯỚNG ĐỌC SÁCH NĂM 2026",
                                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    "Không Gian Tri Thức Số",
                                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Hàng ngàn đầu sách PDF & Audio\nchất lượng cao đang chờ bạn.",
                                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11, height: 1.4),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text("Khám phá ngay", style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                                    SizedBox(width: 4),
                                    Icon(Icons.arrow_forward_ios_rounded, color: Colors.orangeAccent, size: 10),
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                        Positioned(
                          bottom: 12,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(width: 12, height: 4, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2))),
                              const SizedBox(width: 4),
                              Container(width: 4, height: 4, decoration: BoxDecoration(color: Colors.white54, shape: BoxShape.circle)),
                              const SizedBox(width: 4),
                              Container(width: 4, height: 4, decoration: BoxDecoration(color: Colors.white54, shape: BoxShape.circle)),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),

                  // ==================== 2. DANH MỤC: SÁCH ĐỌC ĐƯỢC YÊU THÍCH ====================
                  if (readingBooks.isNotEmpty) ...[
                    _buildSectionTitle("SÁCH ĐỌC ĐƯỢC YÊU THÍCH", Icons.star_rounded),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: readingBooks.length > 2 ? 2 : readingBooks.length,
                      itemBuilder: (context, index) {
                        return _buildVerticalBookRow(context, readingBooks[index], isAudio: false);
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ==================== 3. DANH MỤC: AUDIO SÁCH NỔI BẬT ====================
                  if (audioBooks.isNotEmpty) ...[
                    _buildSectionTitle("AUDIO SÁCH NỔI BẬT", Icons.headset_rounded),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: audioBooks.length > 2 ? 2 : audioBooks.length,
                      itemBuilder: (context, index) {
                        return _buildVerticalBookRow(context, audioBooks[index], isAudio: true);
                      },
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ==================== 4. DANH MỤC PHỔ BIẾN ====================
                  _buildSectionTitle("DANH MỤC PHỔ BIẾN", null),
                  SizedBox(
                    height: 50,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(left: 16, right: 8),
                      children: [
                        _buildCategoryChip("Phát triển\nbản thân", Icons.psychology_outlined),
                        _buildCategoryChip("Kinh doanh\n- Đầu tư", Icons.trending_up_rounded),
                        _buildCategoryChip("Sức khỏe\n- Tâm lý", Icons.favorite_border_rounded),
                        _buildCategoryChip("Tiểu thuyết\n- Văn học", Icons.palette_outlined),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData? icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) Icon(icon, color: Colors.orangeAccent, size: 18),
              if (icon != null) const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
              ),
            ],
          ),
          Text(
            "Xem tất cả >",
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
          ),
        ],
      ),
    );
  }

  // THẺ HIỂN THỊ SÁCH HÀNG DỌC ĐÃ ĐƯỢC SỬA LỖI ĐÚNG THAM SỐ CỦA COLUMN
  Widget _buildVerticalBookRow(BuildContext context, Book book, {required bool isAudio}) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookDetailScreen(book: book, username: widget.username),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 95,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: book.imageUrl.isNotEmpty
                        ? Image.network(
                      book.imageUrl.replaceAll('localhost', '10.0.2.2'),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[900], child: const Icon(Icons.broken_image, color: Colors.white30)),
                    )
                        : Container(color: Colors.grey[900], child: const Icon(Icons.image, color: Colors.white30)),
                  ),
                ),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: CircleAvatar(
                    radius: 15,
                    backgroundColor: Colors.white.withOpacity(0.8),
                    child: Icon(
                      isAudio ? Icons.play_arrow_rounded : Icons.bookmark_border_rounded,
                      color: Colors.orange,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                // ✨ ĐÃ SỬA LỖI TẠI ĐÂY: Sử dụng đúng tham số crossAxisAlignment của Column
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    book.author,
                    style: const TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  if (book.description.isNotEmpty)
                    Text(
                      book.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11, height: 1.4),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(isAudio ? Icons.analytics_outlined : Icons.bookmark_outline_rounded, color: Colors.orangeAccent, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        isAudio ? "7h 21m" : "Đã lưu",
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, IconData icon) {
    return Container(
      width: 135,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.orangeAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

// --- 3. MÀN HÌNH CHI TIẾT SÁCH ---
class BookDetailScreen extends StatelessWidget {
  final Book book;
  final String username;

  const BookDetailScreen({
    super.key,
    required this.book,
    required this.username,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(book.title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Center(
              child: Container(
                height: 300,
                width: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 5))
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: book.imageUrl.isNotEmpty
                      ? Image.network(book.imageUrl.replaceAll('localhost', '10.0.2.2'), fit: BoxFit.cover)
                      : Container(color: Colors.grey[800], child: const Icon(Icons.image, size: 80, color: Colors.white24)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              book.title,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "Tác giả: ${book.author}",
              style: const TextStyle(color: Colors.white70, fontSize: 16, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 20),
            if (book.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  book.description,
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 30),

            if (book.pdfUrl.isNotEmpty)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.menu_book, color: Colors.white),
                label: const Text("Đọc Sách PDF", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                onPressed: () {
                  final correctedPdfUrl = book.pdfUrl.replaceAll('localhost', '10.0.2.2');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PdfViewerScreen(
                        pdfUrl: correctedPdfUrl,
                        bookTitle: book.title,
                        bookId: book.id,
                        username: username,
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 16),

            if (book.audioUrl.isNotEmpty)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[900],
                  foregroundColor: Colors.orangeAccent,
                  side: const BorderSide(color: Colors.orangeAccent, width: 1.5),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.audiotrack, color: Colors.orangeAccent),
                label: const Text("Nghe Audio MP3", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SimpleAudioPlayerScreen(book: book),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

// --- 4. TRÌNH PHÁT SÁCH AUDIO PLAYER ---
class SimpleAudioPlayerScreen extends StatefulWidget {
  final Book book;
  const SimpleAudioPlayerScreen({super.key, required this.book});

  @override
  State<SimpleAudioPlayerScreen> createState() => _SimpleAudioPlayerScreenState();
}

class _SimpleAudioPlayerScreenState extends State<SimpleAudioPlayerScreen> {
  late AudioPlayer _audioPlayer;
  bool isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isLoading = true;
  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
  }

  Future<void> _initAudioPlayer() async {
    _audioPlayer = AudioPlayer();
    _audioPlayer.onPlayerStateChanged.listen((state) { if (mounted) setState(() => isPlaying = state == PlayerState.playing); });
    _audioPlayer.onDurationChanged.listen((newDuration) { if (mounted) setState(() => _duration = newDuration); });
    _audioPlayer.onPositionChanged.listen((newPosition) { if (mounted) setState(() => _position = newPosition); });
    try {
      await _audioPlayer.setSource(UrlSource(widget.book.audioUrl.replaceAll('localhost', '10.0.2.2')));
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = e.toString(); });
    }
  }

  @override
  void dispose() { _audioPlayer.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[950],
      appBar: AppBar(title: const Text("Trình Phát Sách Nói", style: TextStyle(color: Colors.white)), backgroundColor: Colors.transparent, elevation: 0),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: widget.book.imageUrl.isNotEmpty ? Image.network(widget.book.imageUrl.replaceAll('localhost', '10.0.2.2'), height: 240, width: 240, fit: BoxFit.cover) : Container(height: 240, width: 240, color: Colors.grey[800], child: const Icon(Icons.music_note, size: 80, color: Colors.orange)),
            ),
            const SizedBox(height: 30),
            Text(widget.book.title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            Text(widget.book.author, style: const TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 40),
            if (_isLoading) const CircularProgressIndicator(color: Colors.orangeAccent)
            else if (_errorMessage.isNotEmpty) Text("Lỗi: $_errorMessage", style: const TextStyle(color: Colors.redAccent)),
            Slider(
              min: 0, max: _duration.inMilliseconds.toDouble() > 0 ? _duration.inMilliseconds.toDouble() : 1.0,
              value: _position.inMilliseconds.toDouble().clamp(0.0, _duration.inMilliseconds.toDouble() > 0 ? _duration.inMilliseconds.toDouble() : 1.0),
              activeColor: Colors.orangeAccent, inactiveColor: Colors.white24,
              onChanged: (value) async { await _audioPlayer.seek(Duration(milliseconds: value.toInt())); },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(icon: const Icon(Icons.replay_10, size: 36, color: Colors.white), onPressed: () async { final p = _position - const Duration(seconds: 10); await _audioPlayer.seek(p < Duration.zero ? Duration.zero : p); }),
                const SizedBox(width: 20),
                CircleAvatar(radius: 35, backgroundColor: Colors.orangeAccent, child: IconButton(icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, size: 36, color: Colors.white), onPressed: () async { if (isPlaying) { await _audioPlayer.pause(); } else { await _audioPlayer.resume(); } })),
                const SizedBox(width: 20),
                IconButton(icon: const Icon(Icons.forward_10, size: 36, color: Colors.white), onPressed: () async { final p = _position + const Duration(seconds: 10); await _audioPlayer.seek(p > _duration ? _duration : p); }),
              ],
            )
          ],
        ),
      ),
    );
  }
}

// --- 5. CLASS CHÍNH MAIN SCREEN ĐIỀU HƯỚNG ---
class MainScreen extends StatefulWidget {
  final String username;
  final bool isAdmin;

  const MainScreen({super.key, required this.username, this.isAdmin = false});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = [
      HomeScreen(username: widget.username),
      BookShelfScreen(username: widget.username, isAdmin: widget.isAdmin),
      ExploreScreen(username: widget.username, isAdmin: widget.isAdmin),
      ProfileScreen(username: widget.username, isAdmin: widget.isAdmin),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: _currentIndex == 0
            ? AppBar(
          title: const Text(
              "Thư Viện Sách & Audio",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5, fontFamily: 'serif')
          ),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 22),
              onPressed: () {},
            ),
          ],
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.black,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
        )
            : null,
        body: IndexedStack(
          index: _currentIndex,
          children: tabs,
        ),
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: Colors.black,
          selectedItemColor: Colors.orangeAccent,
          unselectedItemColor: Colors.white60,
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: "Trang chủ"),
            BottomNavigationBarItem(icon: Icon(Icons.library_books_rounded), label: "Kệ sách"),
            BottomNavigationBarItem(icon: Icon(Icons.explore_rounded), label: "Khám phá"),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: "Cá nhân"),
          ],
        ),
      ),
    );
  }
}