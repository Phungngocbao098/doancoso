from fastapi import FastAPI, HTTPException
import sqlite3
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn

app = FastAPI()

# 1. Cấu hình CORS - Cho phép Flutter (máy ảo/máy thật) truy cập API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

DB_NAME = "books.db"

# 2. Model dữ liệu để nhận từ Flutter
class UserAuth(BaseModel):
    username: str
    password: str

# 3. Khởi tạo Database
def init_db():
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()

    # Tạo bảng sách
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS books (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            author TEXT,
            content TEXT,
            audio_url TEXT,
            image_url TEXT
        )
    ''')

    # Tạo bảng Users
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password TEXT NOT NULL
        )
    ''')

    # Thêm dữ liệu mẫu nếu bảng sách trống
    cursor.execute("SELECT COUNT(*) FROM books")
    if cursor.fetchone()[0] == 0:
        sample_books = [
            ("Dế Mèn Phiêu Lưu Ký", "Tô Hoài",
             "Tôi sống độc lập từ thuở bé. Ấy là tục lệ lâu đời trong họ hàng nhà dế chúng tôi...",
             "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
             "https://picsum.photos/seed/demen/400/600"),
            ("Số Đỏ", "Vũ Trọng Phụng",
             "Cái xã hội này thật là phong hóa suy đồi... Xuân Tóc Đỏ bắt đầu sự nghiệp...",
             "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3",
             "https://picsum.photos/seed/sodo/400/600")
        ]
        cursor.executemany(
            "INSERT INTO books (title, author, content, audio_url, image_url) VALUES (?, ?, ?, ?, ?)",
            sample_books
        )

    conn.commit()
    conn.close()

# Chạy khởi tạo DB ngay khi start server
init_db()

# --- 4. API ĐĂNG KÝ ---
@app.post("/api/register")
def register(user: UserAuth):
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()
    try:
        # Kiểm tra không để trống
        if not user.username or not user.password:
            raise HTTPException(status_code=400, detail="Tài khoản và mật khẩu không được để trống")

        cursor.execute("INSERT INTO users (username, password) VALUES (?, ?)", (user.username, user.password))
        conn.commit()
        return {"status": "success", "message": "Đăng ký thành công!"}
    except sqlite3.IntegrityError:
        # Lỗi này xảy ra khi username đã tồn tại (UNIQUE)
        raise HTTPException(status_code=400, detail="Tên tài khoản này đã được sử dụng")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Lỗi hệ thống: {str(e)}")
    finally:
        conn.close()

# --- 5. API ĐĂNG NHẬP ---
@app.post("/api/login")
def login(user: UserAuth):
    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row # Trả về dạng dictionary
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM users WHERE username = ? AND password = ?", (user.username, user.password))
        row = cursor.fetchone()

        if row:
            user_data = dict(row)
            # Không nên trả password về client vì lý do bảo mật
            del user_data['password']
            return {"status": "success", "message": "Đăng nhập thành công", "user": user_data}
        else:
            raise HTTPException(status_code=401, detail="Sai tài khoản hoặc mật khẩu")
    finally:
        conn.close()

# --- 6. API LẤY DANH SÁCH SÁCH ---
@app.get("/api/books")
def get_all_books():
    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM books")
        books = [dict(row) for row in cursor.fetchall()]
        return books
    finally:
        conn.close()

# --- 7. CHẠY SERVER ---
if __name__ == "__main__":
    # Host 0.0.0.0 để các thiết bị khác trong Wi-Fi có thể truy cập
    uvicorn.run(app, host="0.0.0.0", port=8000)