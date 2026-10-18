# HƯỚNG DẪN THIẾT LẬP HỆ THỐNG GIÁM SÁT VÀ CẢNH BÁO TỰ ĐỘNG (PROMETHEUS, GRAFANA & ALERTMANAGER)

---

## 1. TẠI SAO CẦN DÙNG HỆ THỐNG CẢNH BÁO TỰ ĐỘNG (ALERTING)?

Trong vận hành hệ thống máy chủ Linux Web Server, giám sát (Monitoring) đơn thuần qua các bảng biểu Grafana chỉ giúp ta nhìn thấy trạng thái quá khứ và hiện tại. Tuy nhiên, **không một kỹ sư vận hành nào có thể ngồi nhìn màn hình giám sát 24/7**.

### Các vấn đề khi không có hệ thống Cảnh báo (Alerting):
1. **Phản ứng bị động:** Chỉ phát hiện sự cố khi người dùng (khách hàng) phàn nàn rằng website bị chậm hoặc sập.
2. **Lãng phí thời gian:** Kỹ sư phải kiểm tra thủ công từng chỉ số (CPU, RAM, Ổ cứng, SSL, HTTP Status) để tìm lỗi.
3. **Cảnh báo ảo và ngợp thông báo (Alert Fatigue):** Nếu không có bộ điều phối, khi 1 sự cố nhỏ xảy ra có thể kéo theo hàng trăm email báo lỗi gửi về cùng lúc làm trôi mất thông tin quan trọng.

### Vai trò của Hệ thống Alerting 3 Lớp (Prometheus + Alertmanager + Receiver):
* **Phát hiện chủ động (Proactive Detection):** Hệ thống tự động đánh giá chỉ số theo chu kỳ (mỗi 5s/15s) và phát hiện bất thường ngay khi nó mới chớm xuất hiện.
* **Xử lý thông minh (Filtering & Grouping):** Alertmanager giúp gom các cảnh báo liên quan thành 1 thông báo duy nhất, ngắt cảnh báo khi bảo trì (Silencing), và gửi tới đúng kênh liên lạc (Telegram, Email, Slack).
* **Thông báo thời gian thực (Real-time Notification):** Gửi báo động trực tiếp về điện thoại/máy tính của đội ngũ vận hành qua Telegram Bot ngay trong vòng vài giây.

---

## 2. LỘ TRÌNH ĐÀO TẠO TỔNG QUAN: PROMETHEUS & GRAFANA

```text
PHẦN I: PROMETHEUS NỀN TẢNG & KHUÔN KHỔ THU THẬP DỮ LIỆU
  ├── Chuyên đề (01): Install Prometheus (Kiến trúc TSDB, Service Systemd)
  ├── Chuyên đề (02): Enable Auth and HTTPS (Bảo mật Web UI bằng TLS & Basic Auth)
  ├── Chuyên đề (03): Add Monitoring Target (Thu thập chỉ số phần cứng qua Node Exporter)
  └── Chuyên đề (04): Add Monitoring Target Win (Mở rộng thu thập chỉ số máy chủ Windows)

PHẦN II: GIÁM SÁT TỪ BÊN NGOÀI & HỆ THỐNG CẢNH BÁO
  ├── Chuyên đề (05): Set Alert Notification (Cài đặt Alertmanager & Tích hợp Telegram Bot)
  └── Chuyên đề (07): Set Blackbox Exporter (Giám sát HTTP Status, SSL Expiry, Ping)

PHẦN III: TRỰC QUAN HÓA VỚI GRAFANA
  └── Chuyên đề (06): Visualize on Grafana (Import Dashboard Node Exporter 1860 & Blackbox 7587)
```

---

## 3. THỰC HÀNH TỪNG BƯỚC: THIẾT LẬP CẢNH BÁO TELEGRAM (DETAILED STEP-BY-STEP)

---

### BƯỚC 1: TẠO TELEGRAM BOT VÀ LẤY CHAT ID

1. Mở ứng dụng Telegram, tìm kiếm user **`@BotFather`**.
2. Gửi lệnh `/newbot` -> Nhập tên Bot -> Nhập Username cho Bot (kết thúc bằng `_bot`).
3. Sao chép chuỗi **HTTP API Token** được cấp (Ví dụ: `7123456789:AAFxxx...`).
4. Tìm kiếm Bot bạn vừa tạo, bấm **Start** và gửi một tin nhắn bất kỳ (ví dụ: "Hello").
5. Tìm kiếm user **`@userinfobot`**, bấm **Start** để lấy chuỗi **Id** tài khoản cá nhân của bạn (Ví dụ: `123456789`).

---

### BƯỚC 2: CÀI ĐẶT VÀ CẤU HÌNH ALERTMANAGER

#### 1. Tạo User hệ thống và Thư mục lưu trữ:
```bash
sudo useradd --no-create-home --shell /bin/false alertmanager
sudo mkdir /etc/alertmanager
sudo mkdir /var/lib/alertmanager
```
* **Giải thích:** Tạo tài khoản dịch vụ không có quyền truy cập terminal (`/bin/false`) để đảm bảo an toàn bảo mật cho máy chủ Linux.

#### 2. Tải và Cài đặt Binary Alertmanager:
```bash
cd /tmp
wget https://github.com/prometheus/alertmanager/releases/download/v0.27.0/alertmanager-0.27.0.linux-amd64.tar.gz
tar -xvf alertmanager-0.27.0.linux-amd64.tar.gz
cd alertmanager-0.27.0.linux-amd64

sudo mv alertmanager /usr/local/bin/
sudo mv amtool /usr/local/bin/
```

#### 3. Cấu hình Alertmanager gửi tin nhắn về Telegram (`/etc/alertmanager/alertmanager.yml`):
```bash
sudo nano /etc/alertmanager/alertmanager.yml
```

Dán nội dung cấu hình sau:
```yaml
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname', 'instance', 'severity']
  group_wait: 5s         # Thời gian chờ gom các cảnh báo xảy ra cùng lúc
  group_interval: 10s    # Cập nhật thông báo sau mỗi 10s
  repeat_interval: 2h    # Lặp lại thông báo sau 2 tiếng nếu chưa khắc phục
  receiver: 'telegram-bot'

receivers:
  - name: 'telegram-bot'
    telegram_configs:
      - bot_token: '7123456789:AAFxxx...'  # Thay bằng Token từ BotFather
        chat_id: 123456789                  # Thay bằng Chat ID từ userinfobot
        parse_mode: 'HTML'
        message: |
          <b>{{ if eq .Status "firing" }}🔥 CANH BÁO SỰ CỐ {{ else }}✅ SỰ CỐ ĐÃ KHẮC PHỤC {{ end }}</b>

          <b>Cảnh báo:</b> {{ .CommonAnnotations.summary }}
          <b>Mức độ:</b> <code>{{ .CommonLabels.severity }}</code>
          <b>Đối tượng:</b> <code>{{ .CommonLabels.instance }}</code>

          <b>Chi tiết:</b> {{ .CommonAnnotations.description }}
          <b>Thời gian:</b> {{ .StartsAt.Format "15:04:05 02/01/2006" }}
```

#### 4. Phân quyền và Tạo Systemd Service:
```bash
sudo chown -R alertmanager:alertmanager /etc/alertmanager /var/lib/alertmanager
sudo chown alertmanager:alertmanager /usr/local/bin/alertmanager /usr/local/bin/amtool
```

Tạo file dịch vụ Systemd:
```bash
sudo nano /etc/systemd/system/alertmanager.service
```

Dán nội dung:
```ini
[Unit]
Description=Alertmanager for Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=alertmanager
Group=alertmanager
Type=simple
ExecStart=/usr/local/bin/alertmanager \
    --config.file=/etc/alertmanager/alertmanager.yml \
    --storage.path=/var/lib/alertmanager/

Restart=always

[Install]
WantedBy=multi-user.target
```

Khởi chạy dịch vụ Alertmanager:
```bash
sudo systemctl daemon-reload
sudo systemctl start alertmanager
sudo systemctl enable alertmanager
```

---

### BƯỚC 3: THIẾT LẬP THỜI GIAN QUÉT VÀ QUY TẮC CẢNH BÁO (ALERT RULES)

#### 1. Cập nhật chu kỳ quét trong `prometheus.yml` để Demo đáp ứng tức thì:
```bash
sudo nano /etc/prometheus/prometheus.yml
```

Cập nhật 2 thông số ở đầu file:
```yaml
global:
  scrape_interval: 5s       # Thu thập dữ liệu mỗi 5 giây
  evaluation_interval: 5s   # Đánh giá luật cảnh báo mỗi 5 giây

alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - 'localhost:9093'

rule_files:
  - '/etc/prometheus/alert_rules.yml'
```
* **Tại sao làm vậy?** Mặc định `evaluation_interval` là `1m` (60 giây), khiến việc đếm ngược PENDING chuyển sang FIRING bị trễ. Đặt `5s` giúp hệ thống phản ứng ngay lập tức khi chạy Demo.

#### 2. Tạo file quy tắc cảnh báo `/etc/prometheus/alert_rules.yml`:
```bash
sudo nano /etc/prometheus/alert_rules.yml
```

Dán nội dung các quy tắc chuẩn xác sau:
```yaml
groups:
  - name: WebServerInfrastructureAlerts
    rules:
      # Kịch bản 1: Máy chủ/Dịch vụ bị sập
      - alert: ServiceDown
        expr: up == 0
        for: 5s
        labels:
          severity: CRITICAL
        annotations:
          summary: "Dịch vụ {{ $labels.job }} ngắt kết nối!"
          description: "Target {{ $labels.instance }} đã không thể kết nối."

      # Kịch bản 2: Tải RAM vượt ngưỡng 70%
      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 70
        for: 5s
        labels:
          severity: WARNING
        annotations:
          summary: "Cảnh báo dung lượng RAM vượt ngưỡng 70%!"
          description: "Mức sử dụng RAM hiện tại là {{ $value | printf \"%.2f\" }}%."
```

#### 3. Phân quyền, Kiểm tra cú pháp và Khởi động lại Prometheus:
```bash
sudo chown prometheus:prometheus /etc/prometheus/alert_rules.yml

# Kiểm tra cú pháp bằng promtool
promtool check config /etc/prometheus/prometheus.yml
promtool check rules /etc/prometheus/alert_rules.yml

# Khởi động lại dịch vụ
sudo systemctl restart prometheus
```

---

## 4. KỊCH BẢN THỰC HÀNH DEMO SỰ CỐ (XÁC MINH HOẠT ĐỘNG)

### KỊCH BẢN 1: DEMO MÁY CHỦ SẬP (SERVICE DOWN)

1. **Thực thi lệnh tắt dịch vụ Node Exporter:**
   ```bash
   sudo systemctl stop node_exporter
   ```
2. **Diễn biến:**
   * Mở giao diện Prometheus UI (`https://<IP>:9090/alerts`).
   * Sau **1 - 5 giây**: Rule `ServiceDown` chuyển sang màu vàng **`PENDING`**.
   * Sau **5 giây tiếp theo** (do `for: 5s`): Rule chuyển sang màu đỏ **`FIRING`**.
   * Telegram báo chuông tin nhắn: **🔥 CANH BÁO SỰ CỐ** - Dịch vụ node_exporter ngắt kết nối.
3. **Phục hồi sự cố:**
   ```bash
   sudo systemctl start node_exporter
   ```
   * Telegram gửi tiếp tin nhắn: **✅ SỰ CỐ ĐÃ KHẮC PHỤC**.

---

### KỊCH BẢN 2: DEMO GIẢ LẬP QUÁ TẢI RAM (RESOURCE STRESS TEST)

#### 1. Kiểm tra % RAM thực tế hiện tại:
Truy cập Prometheus UI (`https://<IP>:9090/graph`), gõ câu lệnh PromQL:
```promql
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100
```
*(Nếu kết quả hiển thị ~69%, ta cần ép RAM tăng thêm khoảng 800MB - 1000MB để vượt mốc 70%)*.

#### 2. Thực thi lệnh ép tải RAM chuẩn xác:
Sử dụng công cụ `stress` cấp phát **1000MB (1GB)** trên **1 tiến trình đơn (`--vm 1`)** để tránh bị tính năng OOM Killer của Linux can thiệp:
```bash
stress --vm 1 --vm-bytes 1000M --timeout 90s
```

#### 3. Diễn biến quan sát:
* Trong lúc lệnh `stress` đang chạy, quay lại Web UI bấm **Execute** lại câu lệnh PromQL, bạn sẽ thấy con số nhảy vọt lên **~85%**.
* Vào tab **Alerts (`https://<IP>:9090/alerts`)**:
  * **0 - 5 giây:** Rule `HighMemoryUsage` chuyển màu vàng **`PENDING`**.
  * **Sau 5 giây:** Rule chuyển màu đỏ rực **`FIRING`**.
* Telegram nổ thông báo: **🔥 CANH BÁO SỰ CỐ** - Mức sử dụng RAM hiện tại là `85.24%`.
* Hết **90 giây**, lệnh `stress` kết thúc, RAM giải phóng về mức bình thường, Telegram gửi tin nhắn **✅ SỰ CỐ ĐÃ KHẮC PHỤC**.

---

## 5. LƯU Ý KHI VẬN HÀNH ALERTS

1. **Luôn kiểm tra dung lượng còn lại trước khi chạy Stress:** Dùng lệnh `free -m` để xem cột `available`. Không đặt thông số `--vm-bytes` vượt quá lượng RAM `available` hiện có để tránh làm sập tiến trình.
2. **Mẹo Nạp lại cấu hình nhanh (Zero-downtime Reload):**
   Thay vì restart toàn bộ service, bạn có thể gửi phương thức POST đến API của Prometheus:
   ```bash
   curl -k -u admin:MatKhauCuaBan -X POST https://localhost:9090/-/reload
   ```
3. **Mẹo tạo "Silence" khi bảo trì máy chủ:** Trên giao diện Alertmanager (`http://<IP>:9093`), bạn bấm vào nút **New Silence** để tạo bộ lọc tắt cảnh báo tạm thời cho một IP hoặc Tên miền cụ thể trong khoảng thời gian bảo trì, tránh gửi tin nhắn rác về Telegram.