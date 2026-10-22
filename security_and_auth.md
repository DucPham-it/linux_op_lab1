# MỞ RỘNG NHÓM 3: BẢO MẬT VÀ QUẢN LÝ QUYỀN TRUY CẬP
## Security, TLS Encryption, Authentication & Access Control (RBAC)
**Môi trường áp dụng:** KVM/libvirt · `mon-server` (Debian 12) & `mon-target` (Debian 12) · Lab #10

---

## MỤC LỤC
1. [Đặt vấn đề và Rủi ro An ninh trong Hệ thống Giám sát](#1-đặt-vấn-đề-và-rủi-ro-an-ninh-trong-hệ-thống-giám-sát)
2. [Triển khai Mã hóa TLS/HTTPS với Nginx Reverse Proxy](#2-triển-khai-mã-hóa-tlshttps-với-nginx-reverse-proxy)
   - 2.1. Khởi tạo Chứng chỉ SSL/TLS tự ký chuẩn OpenSSL
   - 2.2. Cấu hình Nginx Virtual Host làm Reverse Proxy tập trung
   - 2.3. Bắt buộc chuyển hướng HTTPS và Thiết lập Security Headers
3. [Xác thực và Phân quyền Truy cập (Authentication & RBAC)](#3-xác-thực-và-phân-quyền-truy-cập-authentication--rbac)
   - 3.1. Kích hoạt Web Basic Auth bảo vệ Prometheus và Node Exporter
   - 3.2. Quản lý Quyền người dùng (RBAC) trong Grafana
   - 3.3. Tích hợp Đăng nhập tập trung (OAuth2/GitHub SSO) trên Grafana
4. [Bảo vệ TSDB Admin API và Thiết lập Tường lửa Hạ tầng](#4-bảo-vệ-tsdb-admin-api-và-thiết-lập-tường-lửa-hạ-tầng)
   - 4.1. Khóa các Endpoint nhạy cảm của Prometheus TSDB
   - 4.2. Thiết lập Tường lửa UFW/Iptables trên `mon-target`
   - 4.3. Cô lập Cổng dịch vụ nội bộ trên `mon-server`
5. [Kịch bản Demo Thực tế Từng bước](#5-kịch-bản-demo-thực-tế-từng-bước)
   - Demo 1: Kiểm chứng Mã hóa HTTPS và Chuyển hướng HTTP sang HTTPS
   - Demo 2: Kiểm chứng Xác thực Basic Auth bảo vệ Endpoint Prometheus
   - Demo 3: Kiểm chứng Tường lửa cô lập Node Exporter trước truy cập lạ
6. [Bảng Kiểm tra An ninh Toàn diện (Security Hardening Checklist)](#6-bảng-kiểm-tra-an-ninh-toàn-diện-security-hardening-checklist)

---

## 1. ĐẶT VẤN ĐỀ VÀ RỦI RO AN NINH TRONG HỆ THỐNG GIÁM SÁT

Hầu hết các tài liệu cài đặt Prometheus, Grafana và Node Exporter cơ bản đều chạy trên giao thức HTTP bản rõ (plaintext) không có lớp bảo vệ. Trong môi trường hạ tầng doanh nghiệp, điều này dẫn đến các lỗ hổng nghiêm trọng:

1. **Rò rỉ Thông tin Hạ tầng (Information Disclosure):** Node Exporter (`:9100`) công khai toàn bộ kiến trúc nhân OS, tên tiến trình, dung lượng đĩa, danh sách network interface và lưu lượng mạng. Kẻ tấn công có thể dễ dàng quét cổng để thu thập thông tin trinh sát phục vụ tấn công sâu hơn.
2. **Nghe lén dữ liệu truyền thông (Eavesdropping & Sniffing):** Dữ liệu giám sát và thông tin xác thực (token, mật khẩu đăng nhập Grafana) truyền qua mạng nội bộ mà không được mã hóa TLS rất dễ bị bắt gói tin qua các kỹ thuật ARP Spoofing hoặc packet sniffing.
3. **Phá hoại dữ liệu qua API không được bảo vệ (Unauthenticated Destruction):** Nếu Prometheus vô tình bật flag `--web.enable-admin-api`, bất kỳ ai có kết nối mạng tới port `9090` đều có thể gửi lệnh HTTP POST để xóa sạch toàn bộ cơ sở dữ liệu lịch sử (`/api/v1/admin/tsdb/delete_series`) mà không cần mật khẩu.
4. **Leo thang đặc quyền giao diện:** Mặc định Grafana cho phép người dùng tự do đăng ký tài khoản mới (`allow_sign_up = true`) hoặc cho phép xem dashboard ẩn danh (anonymous access), dẫn đến mất kiểm soát phân quyền.

Tài liệu này hướng dẫn chi tiết cách siết chặt an ninh toàn diện cho cả 2 máy ảo `mon-server` và `mon-target`.

---

## 2. TRIỂN KHAI MÃ HÓA TLS/HTTPS VỚI NGINX REVERSE PROXY

Thay vì cấu hình TLS riêng rẽ cho từng dịch vụ (Prometheus, Alertmanager, Grafana), giải pháp chuẩn kiến trúc là đặt một **Nginx Reverse Proxy** ở lớp ngoài cùng của `mon-server`. Nginx sẽ chịu trách nhiệm giải mã SSL/TLS (SSL Termination), áp dụng các chính sách bảo mật HTTP, và điều hướng lưu lượng an toàn về các tiến trình chạy ở cổng nội bộ `127.0.0.1`.

```text
Trình duyệt Quản trị viên (Client)
             │
             │ HTTPS (Port 443 - Mã hóa TLS 1.3)
             ▼
┌────────────────────────────────────────────────────────┐
│             Nginx Reverse Proxy (mon-server)           │
│   • SSL Termination (Chứng chỉ TLS)                    │
│   • Chuyển hướng tự động HTTP (Port 80) -> HTTPS (443)  │
│   • Bộ lọc Security Headers (HSTS, X-Frame-Options)   │
└───────┬────────────────────────┬───────────────────────┘
        │                        │
        │ HTTP Cục bộ            │ HTTP Cục bộ
        ▼                        ▼
┌───────────────────────┐ ┌────────────────────────┐
│  Grafana Dashboard    │ │   Prometheus & Alerts  │
│  (127.0.0.1:3000)     │ │   (127.0.0.1:9090)     │
└───────────────────────┘ └────────────────────────┘
```

### 2.1. Khởi tạo Chứng chỉ SSL/TLS tự ký chuẩn OpenSSL
Thực hiện trên `mon-server`:

```bash
# 1. Cài đặt Nginx và OpenSSL
sudo apt update && sudo apt install -y nginx openssl

# 2. Tạo thư mục chứa chứng chỉ bảo mật
sudo mkdir -p /etc/nginx/ssl
sudo chmod 700 /etc/nginx/ssl

# 3. Tạo cặp khóa Private Key và Certificate tự ký chuẩn 2048-bit (thời hạn 365 ngày)
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/monitoring.key \
  -out /etc/nginx/ssl/monitoring.crt \
  -subj "/C=VN/ST=HoChiMinh/L=HoChiMinh/O=LinuxOpsGroup5/CN=mon-server.internal"

# 4. Phân quyền chỉ người dùng root/nginx được phép đọc file khóa riêng tư
sudo chmod 600 /etc/nginx/ssl/monitoring.key
sudo chmod 644 /etc/nginx/ssl/monitoring.crt
```

### 2.2. Cấu hình Nginx Virtual Host làm Reverse Proxy tập trung
Tạo file cấu hình tại `/etc/nginx/sites-available/monitoring.conf`:

```nginx
# 1. Chuyển hướng toàn bộ lưu lượng HTTP (Port 80) sang HTTPS (Port 443)
server {
    listen 80;
    server_name mon-server.internal 192.168.122.54;
    return 301 https://$host$request_uri;
}

# 2. Máy chủ HTTPS chính (Port 443)
server {
    listen 443 ssl http2;
    server_name mon-server.internal 192.168.122.54;

    # Cấu hình chứng chỉ SSL
    ssl_certificate /etc/nginx/ssl/monitoring.crt;
    ssl_certificate_key /etc/nginx/ssl/monitoring.key;

    # Các thuật toán mã hóa hiện đại và an toàn
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5:!RC4;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;

    # Thiết lập các tiêu chuẩn Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Định tuyến mặc định tới Grafana Dashboard (Port 3000)
    location / {
        proxy_pass http://127.0.0.1:3000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;

        # Hỗ trợ kết nối WebSocket cho Grafana Live alerts
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # Định tuyến tới Prometheus TSDB (Port 9090)
    location /prometheus/ {
        proxy_pass http://127.0.0.1:9090/prometheus/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }

    # Định tuyến tới Alertmanager UI (Port 9093)
    location /alertmanager/ {
        proxy_pass http://127.0.0.1:9093/alertmanager/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}
```

### 2.3. Cập nhật đường dẫn cơ sở (Web Route Prefix) cho các dịch vụ
Để Prometheus và Alertmanager hoạt động mượt mà sau đường dẫn con `/prometheus/` và `/alertmanager/`:

1. **Trên Prometheus:** Sửa tham số khởi chạy trong `/etc/systemd/system/prometheus.service`:
   ```bash
   --web.listen-address="127.0.0.1:9090" \
   --web.route-prefix="/prometheus/" \
   --web.external-url="https://192.168.122.54/prometheus/"
   ```
2. **Trên Alertmanager:** Sửa tham số trong `/etc/systemd/system/alertmanager.service`:
   ```bash
   --web.listen-address="127.0.0.1:9093" \
   --web.route-prefix="/alertmanager/" \
   --web.external-url="https://192.168.122.54/alertmanager/"
   ```

Kích hoạt cấu hình Nginx:
```bash
sudo ln -sf /etc/nginx/sites-available/monitoring.conf /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl daemon-reload
sudo systemctl restart prometheus alertmanager nginx
```

---

## 3. XÁC THỰC VÀ PHÂN QUYỀN TRUY CẬP (AUTHENTICATION & RBAC)

### 3.1. Kích hoạt Web Basic Auth bảo vệ Prometheus và Node Exporter
Prometheus hỗ trợ cấu hình xác thực Native Basic Auth trực tiếp thông qua file cấu hình `web.yml`.

1. **Cài đặt tiện ích tạo mật khẩu mã hóa:**
   ```bash
   sudo apt install -y apache2-utils
   ```

2. **Tạo file băm mật khẩu chuẩn bcrypt:**
   ```bash
   # Tạo mật khẩu cho tài khoản admin của Prometheus
   # Khi được hỏi, nhập mật khẩu an toàn (ví dụ: AdminStrongPass2026!)
   htpasswd -B -C 10 -c /etc/prometheus/web_auth.htpasswd admin
   ```

3. **Tạo file cấu hình web `/etc/prometheus/web.yml`:**
   ```yaml
   basic_auth_users:
     # Mở file /etc/prometheus/web_auth.htpasswd và copy chuỗi hash vào đây:
     admin: "$2y$10$gQk819D234...MÃ_HASH_BCRYPT_TỪ_FILE..."
   ```

4. **Khai báo file web config trong Prometheus service:**
   Thêm cờ `--web.config.file=/etc/prometheus/web.yml` vào file `/etc/systemd/system/prometheus.service`.

5. **Áp dụng tương tự cho Node Exporter trên `mon-target`:**
   Tạo `/etc/prometheus/node_exporter_web.yml` trên `mon-target` chứa user `scraper` kèm hash mật khẩu, sau đó khởi chạy exporter với cờ `--web.config.file=/etc/prometheus/node_exporter_web.yml`.
   
   Trong `prometheus.yml` trên `mon-server`, khai báo thông tin đăng nhập khi cào dữ liệu:
   ```yaml
   scrape_configs:
     - job_name: "node_exporter"
       basic_auth:
         username: "scraper"
         password: "ScraperStrongPassword2026!"
       static_configs:
         - targets: ["192.168.122.38:9100"]
   ```

### 3.2. Quản lý Quyền người dùng (RBAC) trong Grafana
Mở file `/etc/grafana/grafana.ini` và siết chặt các tham số bảo mật:

```ini
[users]
# Cấm người lạ tự đăng ký tài khoản mới qua form web
allow_sign_up = false
# Tự động gán quyền Viewer khi tạo tài khoản mới thay vì Editor
auto_assign_org_role = Viewer

[auth.anonymous]
# Vô hiệu hóa tính năng xem dashboard không cần đăng nhập
enabled = false

[security]
# Không cho phép nhúng Dashboard vào iframe của website ngoài (chống Clickjacking)
allow_embedding = false
# Đổi cookie name tránh nhận diện nền tảng
cookie_secure = true
cookie_samesite = strict
```

**Mô hình Phân quyền Vai trò (RBAC) trong Grafana:**
* **Admin (Quản trị viên hạ tầng):** Quản lý kết nối Data Sources, thêm sửa xóa thành viên, cập nhật cài đặt bảo mật và phân quyền hệ thống.
* **Editor (Kỹ sư phát triển/Vận hành):** Được phép tạo mới, chỉnh sửa PromQL panels, lưu Dashboard, tạo cảnh báo đồ thị (Alerting), nhưng không có quyền cấu hình Data Source hay phân quyền user.
* **Viewer (Khách hàng/Quản lý cấp cao):** Chỉ xem đồ thị thời gian thực, lọc biến (variables), xem trạng thái hệ thống; hoàn toàn bị cấm chỉnh sửa hay xem cấu hình bảo mật.

### 3.3. Tích hợp Đăng nhập tập trung (OAuth2/GitHub SSO) trên Grafana
Thay vì quản lý mật khẩu riêng lẻ, tích hợp cơ chế đăng nhập một lần (Single Sign-On) qua GitHub Organization. Chỉnh sửa `/etc/grafana/grafana.ini`:

```ini
[auth.github]
enabled = true
allow_sign_up = true
client_id = YOUR_GITHUB_CLIENT_ID
client_secret = YOUR_GITHUB_CLIENT_SECRET
scopes = user:email,read:org
auth_url = https://github.com/login/oauth/authorize
token_url = https://github.com/login/oauth/access_token
api_url = https://api.github.com/user
allowed_organizations = YOUR_ORGANIZATION_NAME
role_attribute_path = contains(groups[*], '@YOUR_ORG/devops') && 'Admin' || 'Viewer'
```
Khởi động lại Grafana: `sudo systemctl restart grafana-server`.

---

## 4. BẢO VỆ TSDB ADMIN API VÀ THIẾT LẬP TƯỜNG LỬA HẠ TẦNG

### 4.1. Khóa các Endpoint nhạy cảm của Prometheus TSDB
1. **Tuyệt đối KHÔNG sử dụng flag `--web.enable-admin-api`** trên môi trường Production trừ khi đang thực hiện bảo trì đặc biệt. Nếu không có flag này, các cuộc tấn công HTTP POST nhằm xóa dữ liệu TSDB đều sẽ bị từ chối với mã lỗi `403 Forbidden`.
2. Kiểm tra lại tham số khởi chạy của Prometheus trong systemd và chắc chắn rằng cờ này đã bị xóa bỏ.

### 4.2. Thiết lập Tường lửa UFW trên `mon-target`
Máy mục tiêu `mon-target` chỉ phục vụ mục đích đo đạc dữ liệu hạ tầng cho duy nhất một máy chủ giám sát. Do đó, toàn bộ các cổng ngoài cổng SSH bắt buộc phải đóng, và cổng `:9100` chỉ mở duy nhất cho IP của `mon-server` (`192.168.122.54`):

```bash
# Thực hiện trên mon-target
sudo apt install -y ufw

# 1. Đặt chính sách mặc định: Khóa toàn bộ kết nối đi vào, cho phép đi ra
sudo ufw default deny incoming
sudo ufw default allow outgoing

# 2. Cho phép SSH từ máy Host quản trị
sudo ufw allow 22/tcp comment "Allow SSH from Management"

# 3. Chỉ cho phép DUY NHẤT mon-server truy cập vào cổng Node Exporter 9100
sudo ufw allow from 192.168.122.54 to any port 9100 proto tcp comment "Allow Node Exporter only from mon-server"

# 4. Kích hoạt tường lửa
sudo ufw enable
sudo ufw status verbose
```

### 4.3. Cô lập Cổng dịch vụ nội bộ trên `mon-server`
Trên máy `mon-server`, các dịch vụ Grafana, Prometheus và Alertmanager chỉ được phép lắng nghe trên địa chỉ loopback nội bộ (`127.0.0.1`), không bind ra cổng card mạng công khai `0.0.0.0`:

```bash
# Thực hiện trên mon-server
# 1. Kiểm tra danh sách cổng đang lắng nghe:
sudo ss -tulpn | grep -E '3000|9090|9093'

# Đảm bảo các cổng trên hiển thị:
# 127.0.0.1:3000   (Grafana)
# 127.0.0.1:9090   (Prometheus)
# 127.0.0.1:9093   (Alertmanager)

# 2. Cấu hình UFW trên mon-server:
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp comment "Allow SSH"
sudo ufw allow 80/tcp comment "Allow HTTP (Redirect to HTTPS)"
sudo ufw allow 443/tcp comment "Allow HTTPS Reverse Proxy"
sudo ufw enable
```

---

## 5. KỊCH BẢN DEMO THỰC TẾ TỪNG BƯỚC

### Demo 1: Kiểm chứng Mã hóa HTTPS và Tự động Redirect từ HTTP
1. Mở trình duyệt và truy cập: `http://192.168.122.54`
2. **Hiện tượng quan sát:** 
   * Trình duyệt ngay lập tức được điều hướng (301 Moved Permanently) sang địa chỉ `https://192.168.122.54`.
   * Nhấp vào biểu tượng ổ khóa cạnh thanh địa chỉ để xem chi tiết chứng chỉ SSL/TLS tự ký do `mon-server.internal` phát hành.
   * Giao diện Grafana hiển thị hoàn toàn bảo mật qua cổng 443 mà không cần mở cổng 3000 ra ngoài mạng.

### Demo 2: Kiểm chứng Xác thực Basic Auth bảo vệ Endpoint Prometheus
1. Từ máy Host hoặc máy tính khác, gửi yêu cầu `curl` tới đường dẫn Prometheus mà không truyền thông tin đăng nhập:
   ```bash
   curl -k -i https://192.168.122.54/prometheus/api/v1/targets
   ```
2. **Hiện tượng quan sát:** Máy chủ trả về mã lỗi `HTTP/1.1 401 Unauthorized`.
3. Gửi lại yêu cầu kèm thông tin xác thực đã tạo:
   ```bash
   curl -k -u admin:AdminStrongPass2026! https://192.168.122.54/prometheus/api/v1/targets
   ```
4. **Hiện tượng quan sát:** Máy chủ trả về `HTTP/1.1 200 OK` kèm toàn bộ dữ liệu targets dưới dạng JSON.

### Demo 3: Kiểm chứng Tường lửa cô lập Node Exporter trước truy cập lạ
1. Từ máy `mon-server` (`192.168.122.54`), kiểm tra kết nối tới Exporter trên `mon-target`:
   ```bash
   curl -I http://192.168.122.38:9100/metrics
   ```
   **Kết quả:** Trả về `HTTP/1.1 200 OK` (Thành công do IP đã được cấp phép trong UFW).
2. Từ một máy ảo khác (ví dụ `web-vm` có IP `192.168.122.10`) hoặc máy Host, thử cào dữ liệu:
   ```bash
   curl --connect-timeout 3 -I http://192.168.122.38:9100/metrics
   ```
   **Kết quả:** Lệnh bị treo và báo lỗi `Connection timed out` hoặc `Connection refused`. Toàn bộ gói tin bị UFW chặn đứng ở tầng firewall của `mon-target`.

---

## 6. BẢNG KIỂM TRA AN NINH TOÀN DIỆN (SECURITY HARDENING CHECKLIST)

| Hạng mục kiểm tra | Trạng thái khuyến nghị | Cách kiểm chứng nhanh |
| :--- | :---: | :--- |
| **Giao thức truyền thông** | Bắt buộc 100% HTTPS (TLS 1.2/1.3) | `curl -I http://<IP>` trả về HTTP 301 sang HTTPS |
| **Bảo vệ Cổng nội bộ** | Port 3000, 9090, 9093 chỉ bind `127.0.0.1` | `ss -tulpn` không hiển thị `0.0.0.0:9090` |
| **Bảo vệ Node Exporter** | Cổng 9100 chỉ mở cho duy nhất IP `mon-server` | Thử `curl` từ máy thứ ba bị timeout |
| **Tài khoản Grafana** | Tắt `allow_sign_up`, tắt anonymous | Đăng xuất, không thấy nút Register tài khoản mới |
| **Quyền Admin API TSDB** | Vô hiệu hóa `--web.enable-admin-api` | `curl -X POST /api/v1/admin/tsdb/delete_series` bị 403 |
| **Bảo vệ Khóa Private Key** | File key Nginx đặt quyền `600` thuộc root | `ls -la /etc/nginx/ssl/monitoring.key` là `-rw-------` |
