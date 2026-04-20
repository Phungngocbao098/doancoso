import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';

void main() {
  runApp(const BookApp());
}

class BookApp extends StatelessWidget {
  const BookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sách & AudioBook',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.orange,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      initialRoute: '/welcome',
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/login': (context) => const AuthScreen(),
      },
    );
  }
}

// --- 1. MÀN HÌNH CHÀO MỪNG (WELCOME) ---
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage('https://picsum.photos/id/1010/800/1200'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(color: Colors.black.withOpacity(0.4)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  const Text("Chào Mừng Đến Với", style: TextStyle(color: Colors.white, fontSize: 18)),
                  const Text(
                    "Sách & AudioBook",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black45, blurRadius: 10)],
                    ),
                  ),
                  const Text("Đọc sách & Nghe sách mọi lúc mọi nơi", style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const Spacer(),
                  _buildWelcomeBtn(
                    context,
                    title: "Đăng Nhập",
                    subtitle: "Đăng nhập để tiếp tục",
                    color: Colors.orange.shade800,
                    onTap: () => Navigator.pushNamed(context, '/login'),
                  ),
                  const SizedBox(height: 15),
                  _buildWelcomeBtn(
                    context,
                    title: "Đăng Ký",
                    subtitle: "Tạo tài khoản mới",
                    color: Colors.blue.shade700,
                    onTap: () => Navigator.pushNamed(context, '/login'),
                  ),
                  const SizedBox(height: 40),
                  const Text("Hoặc đăng nhập nhanh với:", style: TextStyle(color: Colors.white, fontSize: 12)),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _socialIcon(Icons.facebook, Colors.blue),
                      const SizedBox(width: 25),
                      _socialIcon(Icons.g_mobiledata, Colors.red),
                      const SizedBox(width: 25),
                      _socialIcon(Icons.chat_bubble, Colors.blueAccent),
                    ],
                  ),
                  const SizedBox(height: 30),
                  TextButton(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const BookListScreen(username: "Khách")),
                    ),
                    child: const Text("Tiếp tục với tư cách Khách >", style: TextStyle(color: Colors.white, fontSize: 15)),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeBtn(BuildContext context, {required String title, required String subtitle, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
        ),
        child: Row(
          children: [
            const Icon(Icons.person, color: Colors.white, size: 30),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _socialIcon(IconData icon, Color color) {
    return CircleAvatar(backgroundColor: Colors.white, radius: 22, child: Icon(icon, color: color, size: 35));
  }
}

// --- 2. MÀN HÌNH ĐĂNG NHẬP/ĐĂNG KÝ (GIỮ NGUYÊN) ---
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final userCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final rePassCtrl = TextEditingController();
  bool isLogin = true;

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Column(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 60),
              SizedBox(height: 10),
              Text("Đăng ký thành công!", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text("Vui lòng đăng nhập để tiếp tục.", textAlign: TextAlign.center),
          actions: [
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () {
                  Navigator.pop(context);
                  setState(() => isLogin = true);
                },
                child: const Text("ĐĂNG NHẬP NGAY", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> authAction() async {
    final String username = userCtrl.text.trim();
    final String password = passCtrl.text.trim();
    final String path = isLogin ? 'login' : 'register';

    if (username.isEmpty || password.isEmpty) {
      _showMsg("Vui lòng không để trống thông tin!");
      return;
    }

    try {
      final res = await http.post(
        Uri.parse('http://10.0.2.2:8000/api/$path'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": username, "password": password}),
      );

      if (res.statusCode == 200) {
        if (isLogin) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => BookListScreen(username: username)),
          );
        } else {
          _showSuccessDialog();
        }
      } else {
        _showMsg("Thông tin không chính xác!");
      }
    } catch (e) {
      _showMsg("Lỗi kết nối Server!");
    }
  }

  void _showMsg(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    Color mainColor = isLogin ? const Color(0xFF3861A5) : const Color(0xFFE67E22);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(image: NetworkImage('https://picsum.photos/id/1010/800/1200'), fit: BoxFit.cover),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            color: Colors.black.withOpacity(0.4),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(25),
                child: Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: mainColor.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Column(
                    children: [
                      Text(isLogin ? "Đăng Nhập" : "Đăng Ký", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 30),
                      _buildField(userCtrl, "Tên đăng nhập", Icons.person_outline),
                      const SizedBox(height: 15),
                      _buildField(passCtrl, "Mật khẩu", Icons.lock_outline, isPass: true),
                      const SizedBox(height: 25),
                      _buildField(rePassCtrl, "Nhập lại mật khẩu", Icons.lock_reset, isPass: true), // Đã thêm rePass theo logic của bạn
                      const SizedBox(height: 25),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(onPressed: authAction, child: Text(isLogin ? "ĐĂNG NHẬP" : "ĐĂNG KÝ")),
                      ),
                      TextButton(
                        onPressed: () => setState(() => isLogin = !isLogin),
                        child: Text(isLogin ? "Chưa có tài khoản? Đăng ký" : "Đã có tài khoản? Đăng nhập", style: const TextStyle(color: Colors.white)),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController c, String h, IconData i, {bool isPass = false}) {
    return TextField(
      controller: c,
      obscureText: isPass,
      decoration: InputDecoration(
        hintText: h,
        prefixIcon: Icon(i),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }
}

// --- 3. MÀN HÌNH CHÍNH (HOME VÀ KỆ SÁCH ĐÃ CẬP NHẬT) ---
class BookListScreen extends StatefulWidget {
  final String username;
  const BookListScreen({super.key, required this.username});

  @override
  State<BookListScreen> createState() => _BookListScreenState();
}

class _BookListScreenState extends State<BookListScreen> {
  List books = [];
  int _currentIndex = 0;

  Future<void> fetchBooks() async {
    try {
      final res = await http.get(Uri.parse('http://10.0.2.2:8000/api/books'));
      if (res.statusCode == 200) {
        setState(() { books = json.decode(utf8.decode(res.bodyBytes)); });
      }
    } catch (e) { debugPrint("Lỗi tải sách: $e"); }
  }

  @override
  void initState() {
    super.initState();
    fetchBooks();
  }

  @override
  Widget build(BuildContext context) {
    // Danh sách các Widget tương ứng với các tab
    final List<Widget> _tabs = [
      _buildHomeContent(),
      _buildBookShelfContent(), // <--- SỬA CHỖ NÀY ĐỂ HIỆN KỆ SÁCH
      const Center(child: Text("Khám phá đang phát triển", style: TextStyle(color: Colors.white))),
      ProfileScreen(username: widget.username),
    ];

    return Scaffold(
      body: _tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.white54,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Trang chủ"),
          BottomNavigationBarItem(icon: Icon(Icons.library_books), label: "Kệ sách"),
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: "Khám phá"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Cá nhân"),
        ],
      ),
    );
  }

  Widget _buildHomeContent() {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: NetworkImage('https://picsum.photos/id/1010/800/1200'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Container(color: Colors.black.withOpacity(0.6)),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(radius: 25, backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=11')),
                        const SizedBox(width: 12),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 20, color: Colors.white),
                            children: [
                              const TextSpan(text: "Xin Chào, "),
                              TextSpan(
                                text: widget.username,
                                style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                              ),
                              const TextSpan(text: "!"),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Icon(Icons.notifications_none, color: Colors.white, size: 28),
                  ],
                ),
                const SizedBox(height: 30),
                const Text("Đang Nghe", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                _buildListeningCard(),
                const SizedBox(height: 30),
                const Text("Sách & Audiobook Đề Xuất", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 0.7,
                  ),
                  itemCount: books.length,
                  itemBuilder: (ctx, i) => _buildBookItem(books[i]),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- PHẦN KỆ SÁCH ĐÃ CẬP NHẬT THEO YÊU CẦU ---
  Widget _buildBookShelfContent() {
    return Stack(
      children: [
        // Giữ hình nền từ Welcome, nhưng làm tối hơn để nổi bật sách
        Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: NetworkImage('https://picsum.photos/id/1010/800/1200'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Container(color: Colors.black.withOpacity(0.75)), // Tăng độ mờ

        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  "Kệ Sách Của Tôi",
                  style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, // 3 cột để hình sách to hơn
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 25,
                    childAspectRatio: 0.6, // Tỷ lệ thon gọn cho bìa sách
                  ),
                  itemCount: books.length,
                  itemBuilder: (ctx, i) {
                    return Column(
                      children: [
                        Expanded(child: _buildBookItem(books[i])), // Hình sách vuông bo cạnh
                        const SizedBox(height: 8),
                        Text(
                          books[i]['title'],
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListeningCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network('https://picsum.photos/id/1/200/200', width: 60, height: 60, fit: BoxFit.cover),
          ),
          const SizedBox(width: 15),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Đắc Nhân Tâm", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text("10:24 / 2h 23m", style: TextStyle(color: Colors.white70, fontSize: 12)),
                SizedBox(height: 8),
                LinearProgressIndicator(value: 0.4, color: Colors.orange, backgroundColor: Colors.white24),
              ],
            ),
          ),
          const Icon(Icons.pause_circle_filled, color: Colors.white, size: 40),
        ],
      ),
    );
  }

  // --- HÀM VẼ HÌNH SÁCH VUÔNG BO CẠNH ĐẸP TO ---
  Widget _buildBookItem(Map book) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => DetailScreen(book: book))),
      child: AspectRatio(
        aspectRatio: 1 / 1, // <--- ÉP HÌNH VUÔNG
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15), // <--- BO CẠNH
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 4), // Tạo hiệu ứng đổ bóng
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: CachedNetworkImage(
              imageUrl: book['image_url'],
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: Colors.white12, child: const Center(child: CircularProgressIndicator(color: Colors.orange))),
              errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.red),
            ),
          ),
        ),
      ),
    );
  }
}

// --- 4. MÀN HÌNH CHI TIẾT (GIỮ NGUYÊN) ---
class DetailScreen extends StatefulWidget {
  final Map book;
  const DetailScreen({super.key, required this.book});
  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final _player = AudioPlayer();
  bool isPlaying = false;

  @override
  void dispose() { _player.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.book['title']), backgroundColor: Colors.orangeAccent),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CachedNetworkImage(imageUrl: widget.book['image_url'], height: 300),
              ),
            ),
            const SizedBox(height: 25),
            ElevatedButton.icon(
              onPressed: () async {
                if (isPlaying) { await _player.pause(); }
                else { await _player.play(UrlSource(widget.book['audio_url'])); }
                setState(() => isPlaying = !isPlaying);
              },
              icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, size: 30),
              label: Text(isPlaying ? "TẠM DỪNG" : "NGHE AUDIOBOOK"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(widget.book['content'], textAlign: TextAlign.justify, style: const TextStyle(fontSize: 16, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

// --- 5. MÀN HÌNH CÁ NHÂN (PROFILE) (GIỮ NGUYÊN) ---
class ProfileScreen extends StatelessWidget {
  final String username;
  const ProfileScreen({super.key, required this.username});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: NetworkImage('https://picsum.photos/id/1010/800/1200'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Container(color: Colors.black.withOpacity(0.6)),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Center(
                  child: Column(
                    children: [
                      const CircleAvatar(radius: 50, backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=11')),
                      const SizedBox(height: 15),
                      Text(username, style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
                      const Text("Đọc sách là cách tốt nhất để mở cửa tri thức", style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 15),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                        child: const Text("Chỉnh Sửa Hồ Sơ", style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    _buildSmallBox(Icons.book, "Ebook của tôi", "25 cuốn", const Color(0xFF3861A5)),
                    const SizedBox(width: 15),
                    _buildSmallBox(Icons.headphones, "Audiobook của tôi", "15 quyển", const Color(0xFFE67E22)),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    _buildSmallBox(Icons.favorite, "Mục yêu thích", "32 mục", const Color(0xFF2C3E50)),
                    const SizedBox(width: 15),
                    _buildSmallBox(Icons.list, "Danh sách của tôi", "3 danh sách", const Color(0xFF8E44AD)),
                  ],
                ),
                const SizedBox(height: 30),
                _buildActivitySection(),
                const SizedBox(height: 30),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                  title: const Text("Đăng Xuất", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.redAccent),
                  onTap: () => Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSmallBox(IconData icon, String title, String sub, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: color.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 30),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            Text(sub, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildActivitySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Hoạt Động Của Bạn", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          _buildActivityRow(Icons.timer, "Thời gian đã nghe", "2 giờ 15 phút"),
          const Divider(color: Colors.white10),
          _buildActivityRow(Icons.menu_book, "Thời gian đọc sách", "3 giờ 40 phút"),
        ],
      ),
    );
  }

  Widget _buildActivityRow(IconData icon, String text, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [Icon(icon, color: Colors.orange, size: 20), const SizedBox(width: 10), Text(text, style: const TextStyle(color: Colors.white70))]),
          Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}