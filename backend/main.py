import os
import time
from fastapi import FastAPI, HTTPException, UploadFile, File, Form, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import BaseModel, field_validator
import pymysql
import uvicorn
import uuid
from typing import Optional, List, Union

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- BỘ GHI LOG CHI TIẾT LỖI 422 (HỖ TRỢ DEBUG CỰC NHANH) ---
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request, exc):
    print("\n" + "="*50)
    print(">>> [LỖI ĐỊNH DẠNG 422 - UNPROCESSABLE CONTENT] <<<")
    print("Dữ liệu gửi từ Flutter lên không khớp với cấu trúc Schema của Backend!")
    for error in exc.errors():
        # Lấy tên trường bị lỗi
        field_path = " -> ".join([str(loc) for loc in error['loc']])
        print(f"❌ Lỗi tại trường: '{field_path}'")
        print(f"   - Chi tiết: {error['msg']}")
        print(f"   - Kiểu lỗi: {error['type']}")
    print("Payload thực tế nhận được:")
    print(exc.body)
    print("="*50 + "\n")
    return JSONResponse(
        status_code=422,
        content={"detail": exc.errors(), "body": exc.body},
    )

# --- CẤU HÌNH LƯU TRỮ FILE TĨNH ---
UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

# Cấu hình mở cổng truy cập các file tĩnh (bao gồm ảnh bìa sách, pdf, mp3, avatar, và ảnh bài đăng...)
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")


DB_CONFIG = {
    "host": "localhost",
    "user": "root",
    "password": "123456",
    "database": "ebook_app",
    "autocommit": True
}

def get_connection():
    return pymysql.connect(**DB_CONFIG, cursorclass=pymysql.cursors.DictCursor)

# --- MODEL DATA (PYDANTIC) ---
class UserAuth(BaseModel):
    username: str
    password: str

# Model hỗ trợ toggle bookmark (Đã bổ sung trường note tùy chọn)
class BookmarkInput(BaseModel):
    username: str
    book_id: int
    page_number: int
    note: Optional[str] = ""  # Nhận nội dung ghi chú từ Flutter gửi lên


# --- [TỐI ƯU HÓA] MODEL CHO HỆ THỐNG ĐƠN HÀNG (TRÁNH LỖI 422) ---
class OrderItemInput(BaseModel):
    book_id: int
    quantity: int
    price: float

    # Tự động chuyển đổi nếu Flutter gửi nhầm dạng chuỗi (String)
    @field_validator('book_id', mode='before')
    def parse_book_id(cls, v):
        if isinstance(v, (str, float)):
            return int(float(v))
        return v

    @field_validator('quantity', mode='before')
    def parse_quantity(cls, v):
        if isinstance(v, (str, float)):
            return int(float(v))
        return v

    @field_validator('price', mode='before')
    def parse_price(cls, v):
        if isinstance(v, str):
            return float(v.replace(',', '').strip())
        return v

class CheckoutInput(BaseModel):
    username: str
    full_name: str
    phone: str
    address: str
    total_amount: float
    items: List[OrderItemInput]

    # Tự động ép kiểu total_amount về float nếu Flutter gửi sang dạng String
    @field_validator('total_amount', mode='before')
    def parse_total_amount(cls, v):
        if isinstance(v, str):
            return float(v.replace(',', '').strip())
        return v

class UpdateOrderStatusInput(BaseModel):
    order_id: int
    status: str  # pending, shipping, completed, cancelled


# --- 1. KHỞI TẠO & TỰ ĐỘNG CẬP NHẬT DATABASE ---
def init_db():
    conn = get_connection()
    cursor = conn.cursor()

    # Bảng books (Chứa thông tin sách đọc/nghe và các link file tĩnh cục bộ)
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS books (
            id INT AUTO_INCREMENT PRIMARY KEY,
            title VARCHAR(255) NOT NULL,
            author VARCHAR(255),
            content TEXT,
            audio_url VARCHAR(500),
            image_url VARCHAR(500),
            pdf_url VARCHAR(500)
        )
    ''')

    # BẢNG: shop_books (Chứa thông tin của Kệ Sách Bán độc lập)
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS shop_books (
            id INT AUTO_INCREMENT PRIMARY KEY,
            title VARCHAR(255) NOT NULL,
            author VARCHAR(255) NOT NULL,
            price DECIMAL(10, 2) NOT NULL,
            image_path VARCHAR(500),
            description TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    print(">>> [Hệ thống] Khởi tạo bảng shop_books thành công!")

    # Tự động nâng cấp bảng books nếu chưa có pdf_url
    try:
        cursor.execute("""
            SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_SCHEMA = 'ebook_app' AND TABLE_NAME = 'books' AND COLUMN_NAME = 'pdf_url'
        """)
        if not cursor.fetchone():
            cursor.execute("ALTER TABLE books ADD COLUMN pdf_url VARCHAR(500) AFTER image_url")
            print(">>> [Hệ thống] Đã tự động nâng cấp bảng books: Thêm cột 'pdf_url'!")
    except Exception as db_err:
        print(f">>> Lỗi nâng cấp bảng books: {db_err}")


    # Bảng users
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INT AUTO_INCREMENT PRIMARY KEY,
            username VARCHAR(100) UNIQUE NOT NULL,
            password VARCHAR(100) NOT NULL,
            is_admin BOOLEAN DEFAULT FALSE,
            full_name VARCHAR(255),
            avatar_url VARCHAR(500)
        )
    ''')

    # TỰ ĐỘNG NÂNG CẤP BẢNG users: THÊM full_name & avatar_url NẾU CHƯA CÓ
    try:
        cursor.execute("""
            SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_SCHEMA = 'ebook_app' AND TABLE_NAME = 'users' AND COLUMN_NAME = 'full_name'
        """)
        if not cursor.fetchone():
            cursor.execute("ALTER TABLE users ADD COLUMN full_name VARCHAR(255) AFTER is_admin")
            print(">>> [Hệ thống] Đã tự động nâng cấp bảng users: Thêm cột 'full_name'!")

        cursor.execute("""
            SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_SCHEMA = 'ebook_app' AND TABLE_NAME = 'users' AND COLUMN_NAME = 'avatar_url'
        """)
        if not cursor.fetchone():
            cursor.execute("ALTER TABLE users ADD COLUMN avatar_url VARCHAR(500) AFTER full_name")
            print(">>> [Hệ thống] Đã tự động nâng cấp bảng users: Thêm cột 'avatar_url'!")
    except Exception as db_err:
        print(f">>> Lỗi nâng cấp bảng users: {db_err}")


    # --- BẢNG LƯU TRỮ BOOKMARK ---
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS bookmarks (
            id INT AUTO_INCREMENT PRIMARY KEY,
            username VARCHAR(100) NOT NULL,
            book_id INT NOT NULL,
            page_number INT NOT NULL,
            note TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY unique_user_book_page (username, book_id, page_number),
            FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
        )
    ''')

    # TỰ ĐỘNG NÂNG CẤP BẢNG bookmarks: Thêm cột 'note' nếu chưa có
    try:
        cursor.execute("""
            SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_SCHEMA = 'ebook_app' AND TABLE_NAME = 'bookmarks' AND COLUMN_NAME = 'note'
        """)
        if not cursor.fetchone():
            cursor.execute("ALTER TABLE bookmarks ADD COLUMN note TEXT AFTER page_number")
            print(">>> [Hệ thống] Đã tự động nâng cấp bảng bookmarks: Thêm cột 'note' thành công!")
    except Exception as db_err:
        print(f">>> Lỗi nâng cấp bảng bookmarks: {db_err}")

    print(">>> [Hệ thống] Khởi tạo bảng bookmarks thành công!")


    # ===================================================================
    # KHỞI TẠO CÁC BẢNG CHO TÍNH NĂNG KHÁM PHÁ (NEWS FEED)
    # ===================================================================

    # 1. Bảng posts (Có bổ sung trường status cho cơ chế kiểm duyệt)
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS posts (
            id INT AUTO_INCREMENT PRIMARY KEY,
            username VARCHAR(100) NOT NULL,
            content TEXT NOT NULL,
            image_url VARCHAR(500),
            status VARCHAR(50) DEFAULT 'pending',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')

    # TỰ ĐỘNG NÂNG CẤP BẢNG posts: Thêm cột 'status' nếu bảng đã có sẵn từ trước
    try:
        cursor.execute("""
            SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_SCHEMA = 'ebook_app' AND TABLE_NAME = 'posts' AND COLUMN_NAME = 'status'
        """)
        if not cursor.fetchone():
            cursor.execute("ALTER TABLE posts ADD COLUMN status VARCHAR(50) DEFAULT 'pending' AFTER image_url")
            print(">>> [Hệ thống] Đã tự động nâng cấp bảng posts: Thêm cột kiểm duyệt 'status'!")
    except Exception as db_err:
        print(f">>> Lỗi nâng cấp bảng posts: {db_err}")

    # 2. Bảng likes (Lượt thích bài viết)
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS likes (
            id INT AUTO_INCREMENT PRIMARY KEY,
            post_id INT NOT NULL,
            username VARCHAR(100) NOT NULL,
            UNIQUE KEY unique_user_post_like (username, post_id),
            FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE
        )
    ''')

    # 3. Bảng comments (Bình luận bài viết)
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS comments (
            id INT AUTO_INCREMENT PRIMARY KEY,
            post_id INT NOT NULL,
            username VARCHAR(100) NOT NULL,
            content TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE
        )
    ''')

    # --- [BỔ SUNG BẢNG MỚI] QUẢN LÝ ĐƠN HÀNG (ORDERS & ORDER_ITEMS) ---
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS orders (
            id INT AUTO_INCREMENT PRIMARY KEY,
            username VARCHAR(100) NOT NULL,
            full_name VARCHAR(255) NOT NULL,
            phone VARCHAR(50) NOT NULL,
            address TEXT NOT NULL,
            total_amount DECIMAL(10, 2) NOT NULL,
            status VARCHAR(50) DEFAULT 'pending',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')

    cursor.execute('''
        CREATE TABLE IF NOT EXISTS order_items (
            id INT AUTO_INCREMENT PRIMARY KEY,
            order_id INT NOT NULL,
            book_id INT NOT NULL,
            quantity INT NOT NULL,
            price DECIMAL(10, 2) NOT NULL,
            FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
            FOREIGN KEY (book_id) REFERENCES shop_books(id) ON DELETE CASCADE
        )
    ''')
    print(">>> [Hệ thống] Khởi tạo các bảng Quản lý đơn hàng thành công!")


    # TỰ ĐỘNG TẠO TÀI KHOẢN ADMIN MẶC ĐỊNH
    cursor.execute("SELECT * FROM users WHERE username = 'admin'")
    admin_exist = cursor.fetchone()
    if not admin_exist:
        cursor.execute(
            "INSERT INTO users (username, password, is_admin, full_name) VALUES (%s, %s, %s, %s)",
            ("admin", "123", True, "Quản trị viên")
        )
        print(">>> Đã khởi tạo tài khoản admin mặc định thành công!")

    cursor.close()
    conn.close()

# Chạy khởi tạo Database tự động khi khởi động server
init_db()


# --- 2. CÁC API HỆ THỐNG ---

# API Đăng ký tài khoản thường
@app.post("/api/register")
def register(user: UserAuth):
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "INSERT INTO users (username, password, is_admin, full_name) VALUES (%s, %s, FALSE, %s)",
            (user.username, user.password, user.username)
        )
        return {"status": "success", "message": "Đăng ký thành công!"}
    except Exception as e:
        raise HTTPException(status_code=400, detail="Tên tài khoản đã tồn tại hoặc lỗi dữ liệu!")
    finally:
        conn.close()

# API Đăng nhập
@app.post("/api/login")
def login(user: UserAuth):
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute(
        "SELECT id, username, is_admin, full_name, avatar_url FROM users WHERE username = %s AND password = %s",
        (user.username, user.password)
    )
    row = cursor.fetchone()
    conn.close()

    if row:
        is_admin_bool = True if row['is_admin'] == 1 else False
        return {
            "status": "success",
            "message": "Đăng nhập thành công",
            "username": row['username'],
            "is_admin": is_admin_bool,
            "full_name": row['full_name'] if row['full_name'] else row['username'],
            "avatar_url": row['avatar_url'] if row['avatar_url'] else ""
        }
    else:
        raise HTTPException(status_code=401, detail="Sai tài khoản hoặc mật khẩu")


# --- API CẬP NHẬT THÔNG TIN CÁ NHÂN (HỌ TÊN & AVATAR VẬT LÝ) ---
@app.post("/api/user/update_profile")
async def update_profile(
    username: str = Form(...),
    full_name: str = Form(...),
    avatar_file: UploadFile = File(None)
):
    conn = get_connection()
    cursor = conn.cursor()

    try:
        cursor.execute("SELECT id, avatar_url FROM users WHERE username = %s", (username,))
        user = cursor.fetchone()

        if not user:
            conn.close()
            raise HTTPException(status_code=404, detail="Không tìm thấy người dùng này!")

        new_avatar_url = user['avatar_url']
        if avatar_file and avatar_file.filename:
            ext = os.path.splitext(avatar_file.filename)[1].lower()
            safe_filename = f"avatar_{user['id']}_{int(time.time())}{ext}"
            file_path = os.path.join(UPLOAD_DIR, safe_filename)

            with open(file_path, "wb") as buffer:
                buffer.write(avatar_file.file.read())

            new_avatar_url = f"http://10.0.2.2:8000/uploads/{safe_filename}"

            if user['avatar_url'] and "/uploads/avatar_" in user['avatar_url']:
                try:
                    old_filename = user['avatar_url'].split("/uploads/")[-1]
                    old_file_path = os.path.join(UPLOAD_DIR, old_filename)
                    if os.path.exists(old_file_path):
                        os.remove(old_file_path)
                except Exception as file_err:
                    print(f">>> Cảnh báo lỗi xóa avatar cũ: {file_err}")

        cursor.execute(
            "UPDATE users SET full_name = %s, avatar_url = %s WHERE username = %s",
            (full_name, new_avatar_url, username)
        )
        conn.close()

        return {
            "status": "success",
            "message": "Cập nhật hồ sơ cá nhân thành công!",
            "full_name": full_name,
            "avatar_url": new_avatar_url
        }

    except Exception as e:
        if conn:
            conn.close()
        print(">>> LỖI CẬP NHẬT PROFILE:", str(e))
        raise HTTPException(status_code=500, detail=f"Lỗi hệ thống: {str(e)}")


# API Lấy danh sách tất cả các sách (Để đọc/nghe)
@app.get("/api/books")
def get_all_books():
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM books")
    books = cursor.fetchall()
    conn.close()
    return books


# API ADMIN: Thêm sách và Tải tệp tin vật lý (Đọc/Nghe)
@app.post("/api/admin/add_book")
async def add_book(
    username: str = Form(...),
    title: str = Form(...),
    author: str = Form(...),
    image_file: UploadFile = File(...),
    pdf_file: UploadFile = File(None),
    audio_file: UploadFile = File(None)
):
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("SELECT is_admin FROM users WHERE username = %s", (username,))
    admin = cursor.fetchone()

    if not admin or not admin['is_admin']:
        conn.close()
        raise HTTPException(status_code=403, detail="Không có quyền Admin!")

    def save_uploaded_file(upload_file: UploadFile) -> str:
        if not upload_file or not upload_file.filename:
            return ""
        ext = os.path.splitext(upload_file.filename)[1].lower()
        safe_filename = f"file_{int(time.time() * 1000)}{ext}"
        file_path = os.path.join(UPLOAD_DIR, safe_filename)
        with open(file_path, "wb") as buffer:
            buffer.write(upload_file.file.read())
        return f"http://10.0.2.2:8000/uploads/{safe_filename}"

    try:
        image_url = save_uploaded_file(image_file)
        pdf_url = save_uploaded_file(pdf_file) if pdf_file else ""
        audio_url = save_uploaded_file(audio_file) if audio_file else ""

        sql = """
            INSERT INTO books (title, author, image_url, pdf_url, audio_url)
            VALUES (%s, %s, %s, %s, %s)
        """
        cursor.execute(sql, (title, author, image_url, pdf_url, audio_url))
        conn.close()
        return {"status": "success", "message": "Tải tệp tin và lưu cơ sở dữ liệu thành công!"}

    except Exception as e:
        if conn:
            conn.close()
        print(">>> LỖI THỰC THI TRÊN SERVER:", str(e))
        raise HTTPException(status_code=500, detail=f"Lỗi hệ thống: {str(e)}")


# API ADMIN XÓA SÁCH VÀ FILE VẬT LÝ (Đọc/Nghe)
@app.delete("/api/books/{book_id}")
def delete_book(book_id: int):
    conn = get_connection()
    cursor = conn.cursor()

    try:
        cursor.execute("SELECT image_url, pdf_url, audio_url FROM books WHERE id = %s", (book_id,))
        book = cursor.fetchone()

        if not book:
            conn.close()
            raise HTTPException(status_code=404, detail="Không tìm thấy sách yêu cầu xóa trên hệ thống!")

        def delete_physical_file(file_url: str):
            if not file_url:
                return
            try:
                filename = file_url.split("/uploads/")[-1]
                file_path = os.path.join(UPLOAD_DIR, filename)
                if os.path.exists(file_path):
                    os.remove(file_path)
            except Exception as file_err:
                print(f">>> Lỗi dọn dẹp file vật lý: {file_err}")

        delete_physical_file(book.get('image_url', ''))
        delete_physical_file(book.get('pdf_url', ''))
        delete_physical_file(book.get('audio_url', ''))

        cursor.execute("DELETE FROM books WHERE id = %s", (book_id,))
        conn.close()
        return {"status": "success", "message": "Đã xóa sách thành công!"}

    except Exception as e:
        if conn:
            conn.close()
        raise HTTPException(status_code=500, detail=f"Lỗi hệ thống: {str(e)}")


# ===================================================================
# --- 2.5 CÁC API CHO KỆ SÁCH BÁN (SHOPPING SHOP) ĐỘC LẬP ---
# ===================================================================

# A. LẤY TOÀN BỘ SÁCH BÁN Ở KỆ SÁCH (GET /api/shop-books)
@app.get("/api/shop-books")
def get_shop_books():
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM shop_books ORDER BY id DESC")
        books = cursor.fetchall()
        for book in books:
            book['price'] = float(book['price'])
        return books
    except Exception as e:
        print(">>> LỖI LẤY KỆ SÁCH BÁN:", str(e))
        raise HTTPException(status_code=500, detail=f"Lỗi hệ thống: {str(e)}")
    finally:
        conn.close()

# B. ĐĂNG BÁN SÁCH MỚI (POST /api/shop-books)
@app.post("/api/shop-books")
async def add_shop_book(
    title: str = Form(...),
    author: str = Form(...),
    price: float = Form(...),
    description: str = Form(""),
    file: UploadFile = File(...)
):
    conn = get_connection()
    cursor = conn.cursor()
    try:
        ext = os.path.splitext(file.filename)[1].lower()
        safe_filename = f"shop_book_{int(time.time() * 1000)}{ext}"
        file_path = os.path.join(UPLOAD_DIR, safe_filename)

        with open(file_path, "wb") as buffer:
            buffer.write(file.file.read())

        image_url = f"http://10.0.2.2:8000/uploads/{safe_filename}"

        sql = """
            INSERT INTO shop_books (title, author, price, image_path, description)
            VALUES (%s, %s, %s, %s, %s)
        """
        cursor.execute(sql, (title.strip(), author.strip(), price, image_url, description.strip()))
        conn.close()

        return {"status": "success", "message": "Đăng bán sách thành công!", "image_path": image_url}
    except Exception as e:
        if conn:
            conn.close()
        print(">>> LỖI ĐĂNG BÁN SÁCH GIAN HÀNG:", str(e))
        raise HTTPException(status_code=500, detail=f"Lỗi máy chủ: {str(e)}")

# C. XÓA SÁCH KHỎI KỆ BÁN (DELETE /api/shop-books/{book_id})
@app.delete("/api/shop-books/{book_id}")
def delete_shop_book(book_id: int):
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT image_path FROM shop_books WHERE id = %s", (book_id,))
        book = cursor.fetchone()

        if not book:
            conn.close()
            raise HTTPException(status_code=404, detail="Không tìm thấy sách bán để xóa!")

        image_path = book.get('image_path')
        if image_path:
            try:
                filename = image_path.split("/uploads/")[-1]
                file_path = os.path.join(UPLOAD_DIR, filename)
                if os.path.exists(file_path):
                    os.remove(file_path)
            except Exception as file_err:
                print(f">>> Lỗi dọn dẹp file ảnh bìa sách bán cũ: {file_err}")

        cursor.execute("DELETE FROM shop_books WHERE id = %s", (book_id,))
        conn.close()
        return {"status": "success", "message": "Đã xóa sách khỏi kệ bán thành công!"}
    except HTTPException as he:
        raise he
    except Exception as e:
        if conn:
            conn.close()
        print(">>> LỖI XÓA SÁCH GIAN HÀNG:", str(e))
        raise HTTPException(status_code=500, detail=f"Lỗi máy chủ: {str(e)}")


# ===================================================================
# --- HỆ THỐNG API QUẢN LÝ ĐƠN HÀNG (CHECKOUT) ---
# ===================================================================

# 1. API Đặt Hàng (POST /api/orders/checkout)
@app.post("/api/orders/checkout")
def checkout_order(data: CheckoutInput):
    conn = get_connection()
    cursor = conn.cursor()
    try:
        # Lưu thông tin đơn hàng tổng quát
        order_sql = """
            INSERT INTO orders (username, full_name, phone, address, total_amount, status)
            VALUES (%s, %s, %s, %s, %s, 'pending')
        """
        cursor.execute(order_sql, (data.username, data.full_name, data.phone, data.address, data.total_amount))
        order_id = cursor.lastrowid

        # Lưu chi tiết từng cuốn sách được mua trong giỏ hàng
        for item in data.items:
            item_sql = """
                INSERT INTO order_items (order_id, book_id, quantity, price)
                VALUES (%s, %s, %s, %s)
            """
            cursor.execute(item_sql, (order_id, item.book_id, item.quantity, item.price))

        return {
            "status": "success",
            "message": "Đặt hàng thành công!",
            "order_id": order_id
        }
    except Exception as e:
        print(">>> LỖI XỬ LÝ ĐẶT HÀNG:", str(e))
        raise HTTPException(status_code=500, detail=f"Lỗi hệ thống: {str(e)}")
    finally:
        conn.close()


# 2. API Lấy lịch sử đơn hàng của User (GET /api/orders/history/{username})
@app.get("/api/orders/history/{username}")
def get_user_order_history(username: str):
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM orders WHERE username = %s ORDER BY id DESC", (username,))
        orders = cursor.fetchall()

        for order in orders:
            order['total_amount'] = float(order['total_amount'])

            # Kết bảng để lấy chi tiết sách đã mua trong đơn hàng này
            items_sql = """
                SELECT oi.*, sb.title, sb.image_path, sb.author
                FROM order_items oi
                JOIN shop_books sb ON oi.book_id = sb.id
                WHERE oi.order_id = %s
            """
            cursor.execute(items_sql, (order['id'],))
            items = cursor.fetchall()
            for item in items:
                item['price'] = float(item['price'])

            order['items'] = items

        return orders
    except Exception as e:
        print(">>> LỖI LẤY LỊCH SỬ ĐƠN HÀNG:", str(e))
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()


# 3. API Lấy toàn bộ đơn hàng (Dành cho Admin - GET /api/orders/admin/all)
@app.get("/api/orders/admin/all")
def get_all_orders_for_admin(current_user: str):
    if current_user.strip().lower() != "admin":
        raise HTTPException(status_code=403, detail="Chỉ có quản trị viên mới có quyền xem danh sách đơn hàng!")

    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM orders ORDER BY id DESC")
        orders = cursor.fetchall()

        for order in orders:
            order['total_amount'] = float(order['total_amount'])

            items_sql = """
                SELECT oi.*, sb.title, sb.image_path, sb.author
                FROM order_items oi
                JOIN shop_books sb ON oi.book_id = sb.id
                WHERE oi.order_id = %s
            """
            cursor.execute(items_sql, (order['id'],))
            items = cursor.fetchall()
            for item in items:
                item['price'] = float(item['price'])
            order['items'] = items

        return orders
    except Exception as e:
        print(">>> LỖI LẤY ĐƠN HÀNG ADMIN:", str(e))
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()


# 4. API Cập nhật trạng thái đơn hàng (Dành cho Admin - PUT /api/orders/admin/status)
@app.put("/api/orders/admin/status")
def update_order_status(data: UpdateOrderStatusInput, current_user: str):
    if current_user.strip().lower() != "admin":
        raise HTTPException(status_code=403, detail="Chỉ có quản trị viên mới có quyền cập nhật trạng thái đơn hàng!")

    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "UPDATE orders SET status = %s WHERE id = %s",
            (data.status, data.order_id)
        )
        return {"status": "success", "message": f"Cập nhật trạng thái đơn sang '{data.status}' thành công!"}
    except Exception as e:
        print(">>> LỖI CẬP NHẬT TRẠNG THÁI ĐƠN HÀNG:", str(e))
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()


# ===================================================================
# --- CÁC API HỆ THỐNG KHÁC (ADMIN USERS, BOOKMARKS...) ---
# ===================================================================

@app.get("/api/admin/users")
def get_all_users():
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT id, username, is_admin, full_name, avatar_url FROM users ORDER BY id DESC")
        users = cursor.fetchall()
        for user in users:
            user['is_admin'] = True if user['is_admin'] == 1 else False
        return users
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Lỗi hệ thống: {str(e)}")
    finally:
        conn.close()

@app.delete("/api/admin/users/{user_id}")
def delete_user(user_id: int):
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT username, is_admin FROM users WHERE id = %s", (user_id,))
        user = cursor.fetchone()

        if not user:
            raise HTTPException(status_code=404, detail="Không tìm thấy người dùng này!")

        if user['username'] == 'admin':
            raise HTTPException(status_code=400, detail="Không thể xóa tài khoản Admin mặc định!")

        cursor.execute("DELETE FROM users WHERE id = %s", (user_id,))
        return {"status": "success", "message": f"Đã xóa tài khoản '{user['username']}' thành công!"}
    except HTTPException as he:
        raise he
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Lỗi hệ thống: {str(e)}")
    finally:
        conn.close()

@app.post("/api/bookmarks/toggle")
def toggle_bookmark(data: BookmarkInput):
    user_raw = data.username.strip()
    user_lower = user_raw.lower()

    if not user_lower or user_lower in ["guest", "anonymous", "null", "undefined"] or "khách" in user_lower or "khach" in user_lower:
        raise HTTPException(
            status_code=403,
            detail="Tài khoản khách không có quyền sử dụng tính năng đánh dấu trang!"
        )

    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT id FROM users WHERE username = %s", (user_raw,))
        db_user = cursor.fetchone()
        if not db_user:
            raise HTTPException(
                status_code=403,
                detail="Tài khoản này không tồn tại trong hệ thống. Vui lòng đăng nhập!"
            )

        cursor.execute(
            "SELECT id FROM bookmarks WHERE username = %s AND book_id = %s AND page_number = %s",
            (user_raw, data.book_id, data.page_number)
        )
        existing = cursor.fetchone()

        if existing:
            cursor.execute("DELETE FROM bookmarks WHERE id = %s", (existing['id'],))
            return {"status": "removed", "message": f"Đã hủy đánh dấu trang {data.page_number}"}
        else:
            cursor.execute(
                "INSERT INTO bookmarks (username, book_id, page_number, note) VALUES (%s, %s, %s, %s)",
                (user_raw, data.book_id, data.page_number, data.note)
            )
            return {"status": "added", "message": f"Đã đánh dấu trang {data.page_number} thành công!"}
    except HTTPException as he:
        raise he
    except Exception as e:
        print(">>> LỖI TOGGLE BOOKMARK:", str(e))
        raise HTTPException(status_code=500, detail=f"Lỗi hệ thống: {str(e)}")
    finally:
        conn.close()

@app.get("/api/bookmarks/{username}")
def get_user_bookmarks(username: str):
    user_raw = username.strip()
    user_lower = user_raw.lower()

    if not user_lower or user_lower in ["guest", "anonymous", "null", "undefined"] or "khách" in user_lower or "khach" in user_lower:
        raise HTTPException(
            status_code=403,
            detail="Tài khoản khách không thể xem dữ liệu đánh dấu trang!"
        )

    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT id FROM users WHERE username = %s", (user_raw,))
        db_user = cursor.fetchone()
        if not db_user:
            raise HTTPException(
                status_code=403,
                detail="Tài khoản này không hợp lệ hoặc không tồn tại!"
            )

        sql = """
            SELECT b.id as bookmark_id, b.book_id, b.page_number, b.note, b.created_at,
                   s.title as book_title, s.author as book_author, s.image_url, s.pdf_url
            FROM bookmarks b
            JOIN books s ON b.book_id = s.id
            WHERE b.username = %s
            ORDER BY b.created_at DESC
        """
        cursor.execute(sql, (user_raw,))
        bookmarks = cursor.fetchall()
        return bookmarks
    except HTTPException as he:
        raise he
    except Exception as e:
        print(">>> LỖI LẤY DANH SÁCH BOOKMARK:", str(e))
        raise HTTPException(status_code=500, detail=f"Lỗi hệ thống: {str(e)}")
    finally:
        conn.close()


# ===================================================================
# --- CÁC API TÍNH NĂNG KHÁM PHÁ (NEWS FEED) ---
# ===================================================================

@app.post("/api/feed/posts")
async def create_feed_post(
    username: str = Form(...),
    content: str = Form(...),
    file: UploadFile = File(None)
):
    conn = get_connection()
    cursor = conn.cursor()
    image_url = ""
    initial_status = "approved" if username.strip().lower() == "admin" else "pending"

    try:
        if file and file.filename:
            ext = os.path.splitext(file.filename)[1].lower()
            unique_filename = f"post_{uuid.uuid4().hex}_{int(time.time())}{ext}"
            file_path = os.path.join(UPLOAD_DIR, unique_filename)

            with open(file_path, "wb") as buffer:
                buffer.write(file.file.read())

            image_url = f"http://10.0.2.2:8000/uploads/{unique_filename}"

        cursor.execute(
            "INSERT INTO posts (username, content, image_url, status) VALUES (%s, %s, %s, %s)",
            (username.strip(), content.strip(), image_url if image_url else None, initial_status)
        )
        conn.close()

        msg = "Đăng bài viết thành công!" if initial_status == "approved" else "Đăng bài viết thành công! Vui lòng chờ Admin duyệt."
        return {"status": "success", "message": msg}
    except Exception as e:
        if conn:
            conn.close()
        print(">>> LỖI ĐĂNG BÀI VIẾT KHÁM PHÁ:", str(e))
        raise HTTPException(status_code=500, detail=f"Lỗi hệ thống: {str(e)}")


@app.get("/api/feed/posts")
def get_feed_posts(current_user: str):
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM posts WHERE status = 'approved' ORDER BY created_at DESC")
        posts = cursor.fetchall()

        result = []
        for post in posts:
            post_id = post['id']

            cursor.execute("SELECT COUNT(*) as cnt FROM likes WHERE post_id = %s", (post_id,))
            likes_count = cursor.fetchone()['cnt']

            cursor.execute(
                "SELECT id FROM likes WHERE post_id = %s AND username = %s",
                (post_id, current_user.strip())
            )
            is_liked = cursor.fetchone() is not None

            cursor.execute(
                "SELECT id, username, content, created_at FROM comments WHERE post_id = %s ORDER BY created_at ASC",
                (post_id,)
            )
            comments = cursor.fetchall()

            formatted_comments = []
            for comment in comments:
                formatted_comments.append({
                    "id": comment['id'],
                    "username": comment['username'],
                    "content": comment['content'],
                    "created_at": comment['created_at'].strftime("%Y-%m-%d %H:%M:%S")
                })

            result.append({
                "id": post['id'],
                "username": post['username'],
                "content": post['content'],
                "image_url": post['image_url'],
                "status": post['status'],
                "created_at": post['created_at'].strftime("%Y-%m-%d %H:%M:%S"),
                "likes_count": likes_count,
                "is_liked": is_liked,
                "comments": formatted_comments
            })

        return result
    except Exception as e:
        print(">>> LỖI LẤY BẢN TIN KHÁM PHÁ:", str(e))
        raise HTTPException(status_code=500, detail=f"Lỗi hệ thống: {str(e)}")
    finally:
        conn.close()


@app.get("/api/feed/pending")
def get_pending_posts(current_user: str):
    if current_user.strip().lower() != "admin":
        raise HTTPException(status_code=403, detail="Chỉ tài khoản Admin mới có quyền truy cập hộp thư chờ duyệt!")

    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM posts WHERE status = 'pending' ORDER BY created_at DESC")
        posts = cursor.fetchall()

        result = []
        for post in posts:
            post_id = post['id']

            cursor.execute("SELECT COUNT(*) as cnt FROM likes WHERE post_id = %s", (post_id,))
            likes_count = cursor.fetchone()['cnt']

            cursor.execute("SELECT id FROM likes WHERE post_id = %s AND username = %s", (post_id, current_user.strip()))
            is_liked = cursor.fetchone() is not None

            cursor.execute("SELECT id, username, content, created_at FROM comments WHERE post_id = %s ORDER BY created_at ASC", (post_id,))
            comments = cursor.fetchall()
            formatted_comments = [{
                "id": c['id'],
                "username": c['username'],
                "content": c['content'],
                "created_at": c['created_at'].strftime("%Y-%m-%d %H:%M:%S")
            } for c in comments]

            result.append({
                "id": post['id'],
                "username": post['username'],
                "content": post['content'],
                "image_url": post['image_url'],
                "status": post['status'],
                "created_at": post['created_at'].strftime("%Y-%m-%d %H:%M:%S"),
                "likes_count": likes_count,
                "is_liked": is_liked,
                "comments": formatted_comments
            })

        return result
    except Exception as e:
        print(">>> LỖI LẤY DANH SÁCH CHỜ DUYỆT:", str(e))
        raise HTTPException(status_code=500, detail=f"Lỗi hệ thống: {str(e)}")
    finally:
        conn.close()


@app.put("/api/feed/posts/{post_id}/approve")
def approve_feed_post(post_id: int, username: str):
    if username.strip().lower() != "admin":
        raise HTTPException(status_code=403, detail="Bạn không có quyền duyệt bài viết này!")

    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT id FROM posts WHERE id = %s", (post_id,))
        post = cursor.fetchone()
        if not post:
            raise HTTPException(status_code=404, detail="Không tìm thấy bài viết yêu cầu duyệt!")

        cursor.execute("UPDATE posts SET status = 'approved' WHERE id = %s", (post_id,))
        conn.close()
        return {"status": "success", "message": "Bài viết đã được duyệt công khai!"}
    except Exception as e:
        if conn:
            conn.close()
        print(">>> LỖI DUYỆT BÀI VIẾT:", str(e))
        raise HTTPException(status_code=500, detail=f"Lỗi hệ thống: {str(e)}")


@app.delete("/api/feed/posts/{post_id}")
def delete_feed_post(post_id: int, username: str):
    conn = get_connection()
    cursor = conn.cursor()
    user_strip = username.strip()

    try:
        cursor.execute("SELECT username, image_url FROM posts WHERE id = %s", (post_id,))
        post = cursor.fetchone()
        if not post:
            conn.close()
            raise HTTPException(status_code=404, detail="Không tìm thấy bài viết cần xóa!")

        if user_strip.lower() != "admin" and post['username'] != user_strip:
            conn.close()
            raise HTTPException(status_code=403, detail="Bạn không có quyền xóa bài đăng của người khác!")

        image_url = post.get('image_url')
        if image_url:
            try:
                filename = image_url.split("/uploads/")[-1]
                file_path = os.path.join(UPLOAD_DIR, filename)
                if os.path.exists(file_path):
                    os.remove(file_path)
            except Exception as file_err:
                print(f">>> Lỗi dọn dẹp ảnh bài đăng: {file_err}")

        cursor.execute("DELETE FROM posts WHERE id = %s", (post_id,))
        conn.close()
        return {"status": "success", "message": "Đã xóa bài đăng thành công!"}
    except HTTPException as he:
        raise he
    except Exception as e:
        if conn:
            conn.close()
        print(">>> LỖI XÓA BÀI VIẾT:", str(e))
        raise HTTPException(status_code=500, detail=f"Lỗi hệ thống: {str(e)}")


@app.post("/api/feed/posts/{post_id}/like")
def toggle_feed_like(post_id: int, username: str):
    conn = get_connection()
    cursor = conn.cursor()
    user_strip = username.strip()

    try:
        cursor.execute(
            "SELECT id FROM likes WHERE post_id = %s AND username = %s",
            (post_id, user_strip)
        )
        like_record = cursor.fetchone()

        if like_record:
            cursor.execute("DELETE FROM likes WHERE id = %s", (like_record['id'],))
            conn.close()
            return {"status": "unliked", "message": "Đã bỏ thích bài viết thành công!"}
        else:
            cursor.execute(
                "INSERT INTO likes (post_id, username) VALUES (%s, %s)",
                (post_id, user_strip)
            )
            conn.close()
            return {"status": "liked", "message": "Đã thích bài viết thành công!"}
    except Exception as e:
        if conn:
            conn.close()
        print(">>> LỖI TOGGLE LIKE BÀI VIẾT:", str(e))
        raise HTTPException(status_code=500, detail=f"Lỗi hệ thống: {str(e)}")


@app.post("/api/feed/posts/{post_id}/comment")
def add_feed_comment(post_id: int, username: str, content: str = Form(...)):
    if not content.strip():
        raise HTTPException(status_code=400, detail="Bình luận không được phép để trống!")

    conn = get_connection()
    cursor = conn.cursor()
    user_strip = username.strip()

    try:
        cursor.execute(
            "INSERT INTO comments (post_id, username, content) VALUES (%s, %s, %s)",
            (post_id, user_strip, content.strip())
        )

        last_id = cursor.lastrowid
        cursor.execute(
            "SELECT id, username, content, created_at FROM comments WHERE id = %s",
            (last_id,)
        )
        new_comment = cursor.fetchone()
        conn.close()

        return {
            "id": new_comment['id'],
            "username": new_comment['username'],
            "content": new_comment['content'],
            "created_at": new_comment['created_at'].strftime("%Y-%m-%d %H:%M:%S")
        }
    except Exception as e:
        if conn:
            conn.close()
        print(">>> LỖI GỬI BÌNH LUẬN KHÁM PHÁ:", str(e))
        raise HTTPException(status_code=500, detail=f"Lỗi hệ thống: {str(e)}")


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)