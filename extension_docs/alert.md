# TÀI LIỆU BÁO CÁO HỆ THỐNG GIÁM SÁT VÀ BÁO ĐỘNG TỰ ĐỘNG
## PROMETHEUS, GRAFANA & ALERTMANAGER FOR LINUX WEB SERVER

---

## PHẦN 1: TỔNG QUAN HỆ THỐNG VÀ LÝ DO LỰA CHỌN

### 1.1. Đặt vấn đề và Mục tiêu
Trong quản trị vận hành Web Server (Apache/Nginx), việc chỉ theo dõi trạng thái thủ công hoặc xem biểu đồ thụ động (Monitoring) là chưa đủ. Một hệ thống chuẩn Production đòi hỏi khả năng **Quan sát toàn diện (Observability)** và **Báo động tự động theo thời gian thực (Real-time Alerting)**.

**Mục tiêu hệ thống:**
* Thu thập liên tục các chỉ số phần cứng (CPU, RAM, Disk, Network) và dịch vụ Web từ bên ngoài.
* Trực quan hóa dữ liệu theo thời gian thực trên Bảng điều khiển (Grafana Dashboard).
* Tự động phát hiện bất thường và gửi thông báo tức thì đến người quản trị qua Telegram Bot kèm thông tin chi tiết và mốc thời gian chính xác.

---

### 1.2. Kiến trúc Alerting 3 Lớp (3-tier Alerting Architecture)

```text
[ LỚP 1: DETECTION ]            [ LỚP 2: ROUTING ]            [ LỚP 3: NOTIFICATION ]
┌────────────────────┐          ┌──────────────────┐          ┌──────────────────────┐
│  Prometheus Server │ ───────► │   Alertmanager   │ ───────► │    Telegram Bot      │
│ (Đánh giá Rules)   │ (Firing) │ (Gom cụm, Filter)│(Webhook) │ (Báo động Real-time) │
└────────────────────┘          └──────────────────┘          └──────────────────────┘
```

1. **Lớp 1 - Prometheus (Detection Layer):** Định kỳ đánh giá các biểu thức PromQL. Nếu giá trị vượt ngưỡng và duy trì qua thời gian đệm `for`, Prometheus chuyển trạng thái cảnh báo sang `FIRING` và đẩy dữ liệu sang Alertmanager.
2. **Lớp 2 - Alertmanager (Routing & Processing Layer):**
   * **Grouping (Gom cụm):** Nhóm các cảnh báo cùng loại/cùng máy chủ để tránh "bão thông báo" (Alert Fatigue).
   * **Deduplication (Khử trùng lặp):** Tránh gửi lặp lại cùng một nội dung lỗi liên tục.
   * **Silencing (Tắt tạm thời):** Cho phép tạm ngắt cảnh báo trong khung giờ bảo trì hệ thống.
3. **Lớp 3 - Telegram Bot (Notification Layer):** Kênh liên lạc tức thì gửi tin nhắn cảnh báo dạng HTML trực tiếp tới điện thoại/máy tính của quản trị viên.

---

## PHẦN 2: NGUYÊN NHÂN VÀ CÁCH KHẮC PHỤC LỖI THỰC TẾ

### 2.1. Lỗi hiển thị rỗng biến `Thời gian` trên Telegram
* **Nguyên nhân:** Gọi biến thời gian ngoài phạm vi vòng lặp hoặc sai định dạng chuỗi của Go Template làm Alertmanager không render được chuỗi Timestamp.
* **Khắc phục:** Sử dụng vòng lặp `{{ range .Alerts }}` để duyệt từng alert đơn lẻ kết hợp hàm định dạng thời gian chuẩn của Go:
  $$\text{Cú pháp chuẩn: } \texttt{\{\{ .StartsAt.Local.Format "15:04:05 02/01/2006" \}\}}$$

### 2.2. Lỗi Xung đột cổng (Port Conflict) khi triển khai đa máy chủ
* **Nguyên nhân:** Máy chủ khác có thể đang chạy sẵn các ứng dụng khác chiếm dụng cổng mặc định.

**Danh sách cổng chuẩn và xung đột thường gặp:**

| Dịch vụ | Cổng chuẩn | Dịch vụ dễ gây xung đột | Cách khắc phục |
| :--- | :---: | :--- | :--- |
| **Grafana** | `3000` | Node.js, React Dev Server | Đổi `http_port = 3001` trong `/etc/grafana/grafana.ini` |
| **Prometheus** | `9090` | Cockpit Console, Java Apps | Đổi cờ `--web.listen-address="0.0.0.0:9091"` trong file service |
| **Alertmanager** | `9093` | Service Mesh/Monitoring cũ | Đổi cờ `--web.listen-address="0.0.0.0:9094"` trong file service |
| **Node Exporter**| `9100` | Tiến trình giám sát khác | Chặn/Đổi cổng qua UFW hoặc cờ `--web.listen-address` |

**Lệnh kiểm tra xung đột cổng trên Linux:**
```bash
sudo ss -tulpn | grep -E '3000|9090|9100|9093'
```

---

## PHẦN 3: HƯỚNG DẪN CẤU HÌNH THỰC HÀNH CHI TIẾT

#### Bước 1. Tạo User hệ thống và Thư mục lưu trữ:
```bash
sudo useradd --no-create-home --shell /bin/false alertmanager
sudo mkdir /etc/alertmanager
sudo mkdir /var/lib/alertmanager
```
* **Giải thích:** Tạo tài khoản dịch vụ không có quyền truy cập terminal (`/bin/false`) để đảm bảo an toàn bảo mật cho máy chủ Linux.

#### Bước 2. Tải và Cài đặt Binary Alertmanager:
```bash
cd /tmp
wget https://github.com/prometheus/alertmanager/releases/download/v0.27.0/alertmanager-0.27.0.linux-amd64.tar.gz
tar -xvf alertmanager-0.27.0.linux-amd64.tar.gz
cd alertmanager-0.27.0.linux-amd64

sudo mv alertmanager /usr/local/bin/
sudo mv amtool /usr/local/bin/
```


### Bước 3: Cấu hình Alertmanager kết nối Telegram (`/etc/alertmanager/alertmanager.yml`)

```bash
sudo nano /etc/alertmanager/alertmanager.yml
```

```yaml
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname', 'instance', 'severity']
  group_wait: 5s         # Chờ 5s để gom các cảnh báo phát sinh đồng thời
  group_interval: 10s    # Cập nhật thông báo sau mỗi 10s
  repeat_interval: 2h    # Lặp lại thông báo sau 2h nếu chưa sửa lỗi
  receiver: 'telegram-bot'

receivers:
  - name: 'telegram-bot'
    telegram_configs:
      - bot_token: 'YOUR_BOT_TOKEN'  # Thay Token Bot Telegram của bạn
        chat_id: YOUR_CHAT_ID        # Thay Chat ID của bạn
        parse_mode: 'HTML'
        message: |
          {{ range .Alerts }}
          <b>{{ if eq .Status "firing" }}🔥 CANH BÁO SỰ CỐ{{ else }}✅ SỰ CỐ ĐÃ KHẮC PHỤC{{ end }}</b>

          <b>Cảnh báo:</b> {{ .Annotations.summary }}
          <b>Mức độ:</b> <code>{{ .Labels.severity }}</code>
          <b>Đối tượng:</b> <code>{{ .Labels.instance }}</code>

          <b>Chi tiết:</b> {{ .Annotations.description }}
          <b>Thời gian:</b> <code>{{ .StartsAt.Local.Format "15:04:05 02/01/2006" }}</code>
          {{ end }}
```

**Kiểm tra cú pháp và Restart dịch vụ:**
```bash
amtool check-config /etc/alertmanager/alertmanager.yml
sudo systemctl restart alertmanager
```

---

### Bước 4: Thiết lập Quy tắc Cảnh báo (`/etc/prometheus/alert_rules.yml`)

```bash
sudo nano /etc/prometheus/alert_rules.yml
```

```yaml
groups:
  - name: WebServerInfrastructureAlerts
    rules:
      # Quy tắc 1: Máy chủ hoặc Dịch vụ ngắt kết nối
      - alert: ServiceDown
        expr: up == 0
        for: 5s
        labels:
          severity: CRITICAL
        annotations:
          summary: "Dịch vụ {{ $labels.job }} ngắt kết nối!"
          description: "Target {{ $labels.instance }} trên máy chủ đã ngừng hoạt động."

      # Quy tắc 2: Tải RAM cao bất thường (> 80%)
      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 80
        for: 5s
        labels:
          severity: WARNING
        annotations:
          summary: "Cảnh báo dung lượng RAM!"
          description: "Mức sử dụng RAM hiện tại là {{ $value | printf \"%.2f\" }}% (vượt ngưỡng 80%)."
```

---

### Bước 5: Cấu hình Prometheus Server (`/etc/prometheus/prometheus.yml`)

```bash
sudo nano /etc/prometheus/prometheus.yml
```

```yaml
global:
  scrape_interval: 5s       # Tần suất quét số liệu (5s cho demo)
  evaluation_interval: 5s  # Tần suất đánh giá quy tắc cảnh báo (5s cho demo)

alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - 'localhost:9093'

rule_files:
  - '/etc/prometheus/alert_rules.yml'

scrape_configs:
  - job_name: "prometheus"
    scrape_interval: 5s
    scheme: https
    tls_config:
      insecure_skip_verify: true
    basic_auth:
      username: "admin"
      password: "YOUR_PASSWORD"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "node_exporter"
    scrape_interval: 5s
    static_configs:
      - targets: ["localhost:9100"]
```

**Kiểm tra cú pháp và Nạp lại cấu hình:**
```bash
promtool check config /etc/prometheus/prometheus.yml
sudo systemctl restart prometheus
```

---

## PHẦN 4: SCRIPT TỰ ĐỘNG HÓA KIỂM THỬ (AUTO-STRESS DEMO)

Script Python tự động đo dung lượng RAM thực tế và ép tải chính xác theo tỉ lệ % mong muốn trong **180 giây** mà không làm sập hệ thống (OOM).

```bash
sudo apt update && sudo apt install -y python3-psutil stress
nano auto_stress.py
```

```python
#!/usr/bin/env python3
import sys
import subprocess
import psutil

def auto_stress(target_percent, duration=180):
    mem = psutil.virtual_memory()
    total_mb = mem.total / (1024 * 1024)
    used_mb = mem.used / (1024 * 1024)
    current_percent = mem.percent

    print(f"=== BÁO CÁO TRẠNG THÁI RAM BAN ĐẦU ===")
    print(f"Tổng RAM hệ thống : {total_mb:.2f} MB")
    print(f"RAM đang sử dụng   : {used_mb:.2f} MB ({current_percent:.2f}%)")
    print(f"Mức % RAM mục tiêu : {target_percent}%")

    if target_percent <= current_percent:
        print(f"[!] RAM hiện tại ({current_percent:.2f}%) đã >= mục tiêu ({target_percent}%). Không cần ép tải.")
        return

    target_used_mb = total_mb * (target_percent / 100.0)
    needed_mb = int(target_used_mb - used_mb)

    print(f"\n[+] Tính toán: Cần ép thêm khoảng {needed_mb} MB RAM trong {duration} giây.")

    cmd = ["stress", "--vm", "1", "--vm-bytes", f"{needed_mb}M", "--timeout", f"{duration}s"]
    print(f"[+] Đang chạy lệnh: {' '.join(cmd)}\n")
    
    try:
        subprocess.run(cmd, check=True)
    except KeyboardInterrupt:
        print("\n[*] Đã chủ động dừng kiểm thử.")
    except Exception as e:
        print(f"[!] Lỗi khi thực thi stress: {e}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Cách dùng: python3 auto_stress.py <Phần_Trăm_RAM_Mục_Tiêu> [Thời_Gian_Giây]")
        print("Ví dụ:     python3 auto_stress.py 85 180")
        sys.exit(1)

    target_pct = float(sys.argv[1])
    dur = int(sys.argv[2]) if len(sys.argv) > 2 else 180
    auto_stress(target_pct, dur)
```

---

## PHẦN 5: KỊCH BẢN 1 ROUND BÁO CÁO THỰC TẾ (DEMO SỰ CỐ 180S)

1. **Chạy kịch bản ép tải RAM 85% trong 180s:**
   ```bash
   python3 auto_stress.py 85 180
   ```
2. **Giai đoạn PENDING (0s - 5s):**
   * RAM nhảy vọt lên ~85%.
   * Prometheus UI (`https://<IP>:9090/alerts`) chuyển rule `HighMemoryUsage` sang **`PENDING`** màu vàng.
3. **Giai đoạn FIRING & Báo Telegram (5s - 10s):**
   * Rule chuyển sang **`FIRING`** màu đỏ.
   * Telegram nhận tin nhắn báo động:

   > **🔥 CANH BÁO SỰ CỐ**  
   > **Cảnh báo:** Cảnh báo dung lượng RAM!  
   > **Mức độ:** `WARNING`  
   > **Đối tượng:** `localhost:9100`  
   > **Chi tiết:** Mức sử dụng RAM hiện tại là 85.12% (vượt ngưỡng 80%).  
   > **Thời gian:** `10:08:15 19/10/2026`

4. **Giai đoạn Tự động Phục hồi - RESOLVED (Sau 180s):**
   * Hết 180s, lệnh `stress` kết thúc, RAM hạ về mức bình thường (~60%).
   * Telegram nhận tin nhắn phục hồi:

   > **✅ SỰ CỐ ĐÃ KHẮC PHỤC**  
   > **Cảnh báo:** Cảnh báo dung lượng RAM!  
   > **Mức độ:** `WARNING`  
   > **Đối tượng:** `localhost:9100`  
   > **Chi tiết:** Mức sử dụng RAM hiện tại là 60.15% (vượt ngưỡng 80%).  
   > **Thời gian:** `10:11:15 19/10/2026`

---

## PHẦN 6: KẾT LUẬN

Hệ thống giám sát và báo động tự động (**Prometheus, Grafana, Alertmanager, Telegram Bot**) đáp ứng trọn vẹn tiêu chí chuẩn Production:
1. **Quan sát toàn diện (Observability):** Giám sát đầy đủ cả hạ tầng nội tại và dịch vụ bên ngoài.
2. **Tức thì & Chính xác (Real-time & Accuracy):** Cảnh báo phát sinh sau vài giây, mốc thời gian hiển thị chính xác tới từng giây.
3. **Tự động hóa hoàn toàn (Automation):** Tự động tính toán ép tải thử nghiệm và tự động thông báo khi hệ thống phục hồi.