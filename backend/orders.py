from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import json
# Import kết nối từ database.py để tránh lỗi import vòng lặp
from database import get_connection

router = APIRouter(
    prefix="/api/orders",
    tags=["Đơn hàng & Giỏ hàng"]
)

# --- MODEL DỮ LIỆU ĐẦU VÀO (Đã đồng bộ 100% với Flutter) ---
class CheckoutInput(BaseModel):
    username: str
    full_name: str       # Thêm trường Họ tên người nhận
    phone: str           # Đổi từ phone_number -> phone cho đồng bộ
    address: str
    payment_method: str
    items: list
    total_amount: float  # Đổi từ total_price -> total_amount cho đồng bộ

class StatusUpdateInput(BaseModel):
    status: str  # confirmed, shipped, cancelled

# --- HÀM TỰ ĐỘNG KHỞI TẠO BẢNG ORDERS ---
# Đã cập nhật cấu trúc bảng để bổ sung full_name, đồng bộ phone và total_amount
def init_orders_table():
    conn = get_connection()
    cursor = conn.cursor()
    try:
        # 1. Tạo bảng nếu chưa tồn tại (Cấu trúc chuẩn mới)
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS orders (
                id INT AUTO_INCREMENT PRIMARY KEY,
                username VARCHAR(100) NOT NULL,
                full_name VARCHAR(255) NOT NULL,
                phone VARCHAR(20) NOT NULL,
                address TEXT NOT NULL,
                payment_method VARCHAR(100) NOT NULL,
                items JSON NOT NULL,
                total_amount DECIMAL(10, 2) NOT NULL,
                status VARCHAR(50) DEFAULT 'pending', -- pending, confirmed, shipped, cancelled
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ''')
        conn.commit()

        # 2. BƯỚC AN TOÀN: Tự động cập nhật cột nếu bạn đã có bảng orders cũ trong DB
        cursor.execute("SHOW COLUMNS FROM orders LIKE 'full_name'")
        if not cursor.fetchone():
            print(">>> [Hệ thống orders] Đang bổ sung cột 'full_name' vào bảng orders cũ...")
            cursor.execute("ALTER TABLE orders ADD COLUMN full_name VARCHAR(255) NOT NULL AFTER username")
            conn.commit()

        cursor.execute("SHOW COLUMNS FROM orders LIKE 'phone'")
        if not cursor.fetchone():
            print(">>> [Hệ thống orders] Đang nâng cấp cột 'phone_number' -> 'phone'...")
            cursor.execute("ALTER TABLE orders CHANGE COLUMN phone_number phone VARCHAR(20) NOT NULL")
            conn.commit()

        cursor.execute("SHOW COLUMNS FROM orders LIKE 'total_amount'")
        if not cursor.fetchone():
            print(">>> [Hệ thống orders] Đang nâng cấp cột 'total_price' -> 'total_amount'...")
            cursor.execute("ALTER TABLE orders CHANGE COLUMN total_price total_amount DECIMAL(10, 2) NOT NULL")
            conn.commit()

        print(">>> [Hệ thống orders] Khởi tạo & Cập nhật bảng 'orders' thành công!")
    except Exception as e:
        print(f">>>> [Hệ thống orders] Lỗi khởi tạo/cập nhật bảng: {e}")
    finally:
        cursor.close()
        conn.close()

# Chạy khởi tạo/cập nhật cấu trúc bảng
init_orders_table()


# --- API 1: ĐẶT HÀNG (Dành cho User - Đã đồng bộ trường mới) ---
@router.post("/checkout")
def checkout_order(data: CheckoutInput):
    user_raw = data.username.strip()

    if not user_raw or user_raw.lower() in ["guest", "anonymous"] or "khách" in user_raw.lower():
        raise HTTPException(
            status_code=403,
            detail="Tài khoản khách không thể đặt mua hàng! Vui lòng đăng nhập hệ thống."
        )

    if not data.items:
        raise HTTPException(status_code=400, detail="Giỏ hàng trống, không thể đặt hàng!")

    conn = get_connection()
    cursor = conn.cursor()
    try:
        items_json = json.dumps(data.items, ensure_ascii=False)

        sql = """
            INSERT INTO orders (username, full_name, phone, address, payment_method, items, total_amount, status)
            VALUES (%s, %s, %s, %s, %s, %s, %s, 'pending')
        """
        cursor.execute(sql, (
            user_raw,
            data.full_name.strip(),
            data.phone.strip(),
            data.address.strip(),
            data.payment_method,
            items_json,
            data.total_amount
        ))
        conn.commit()

        # Lấy ID của đơn hàng vừa tạo để trả về cho Flutter (nếu cần dùng hiển thị)
        order_id = cursor.lastrowid

        return {
            "status": "success",
            "message": "Đặt hàng thành công! Đơn hàng của bạn đang chờ phê duyệt.",
            "order_id": order_id
        }
    except Exception as e:
        print(">>> LỖI LOGIC ĐẶT HÀNG:", str(e))
        raise HTTPException(status_code=500, detail=f"Lỗi hệ thống: {str(e)}")
    finally:
        cursor.close()
        conn.close()


# --- API 2: XEM LỊCH SỬ ĐƠN HÀNG CÁ NHÂN (Dành cho User theo dõi) ---
@router.get("/user/{username}")
def get_user_orders(username: str):
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        sql = """
            SELECT id, full_name, phone, address, payment_method, items, total_amount, status, created_at
            FROM orders
            WHERE username = %s
            ORDER BY id DESC
        """
        cursor.execute(sql, (username.strip(),))
        orders = cursor.fetchall()
        for order in orders:
            if isinstance(order['items'], str):
                order['items'] = json.loads(order['items'])
            order['total_amount'] = float(order['total_amount'])
        return orders
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()
        conn.close()


# --- API 3: LẤY TOÀN BỘ ĐƠN HÀNG (Dành cho Admin quản lý) ---
@router.get("/all")
def get_all_orders_for_admin():
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        sql = """
            SELECT id, username, full_name, phone, address, payment_method, items, total_amount, status, created_at
            FROM orders
            ORDER BY id DESC
        """
        cursor.execute(sql)
        orders = cursor.fetchall()
        for order in orders:
            if isinstance(order['items'], str):
                order['items'] = json.loads(order['items'])
            order['total_amount'] = float(order['total_amount'])
        return orders
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()
        conn.close()


# --- API 4: CẬP NHẬT TRẠNG THÁI ĐƠN HÀNG (Dành cho Admin cập nhật) ---
@router.put("/{order_id}/status")
def update_order_status(order_id: int, data: StatusUpdateInput):
    allowed_statuses = ["pending", "confirmed", "shipped", "cancelled"]
    status_lower = data.status.strip().lower()

    if status_lower not in allowed_statuses:
        raise HTTPException(status_code=400, detail="Trạng thái đơn hàng không hợp lệ!")

    conn = get_connection()
    cursor = conn.cursor()
    try:
        # Kiểm tra xem đơn hàng có tồn tại hay không
        cursor.execute("SELECT id FROM orders WHERE id = %s", (order_id,))
        if not cursor.fetchone():
            raise HTTPException(status_code=404, detail="Không tìm thấy đơn hàng này!")

        sql = "UPDATE orders SET status = %s WHERE id = %s"
        cursor.execute(sql, (status_lower, order_id))
        conn.commit()
        return {
            "status": "success",
            "message": f"Đã cập nhật trạng thái đơn hàng sang: {status_lower}"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()
        conn.close()