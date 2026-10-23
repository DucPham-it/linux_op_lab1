# PRODUCTION ALERTING: HỆ THỐNG CẢNH BÁO TỰ ĐỘNG CHUYÊN NGHIỆP
## Tích hợp Prometheus, Alertmanager, Grafana & Telegram Bot trên Hạ tầng Linux

---

## MỤC LỤC
1. [Đặt vấn đề và Triết lý Production Alerting](#1-đặt-vấn-đề-và-triết-lý-production-alerting)
   - [1.1. Hiện tượng "Bão cảnh báo" (Alert Fatigue)](#11-hiện-tượng-bão-cảnh-báo-alert-fatigue)
   - [1.2. Bốn trụ cột của Production Alerting](#12-bốn-trụ-cột-của-production-alerting)
2. [Kiến trúc Cảnh báo 3 Lớp (3-Tier Alerting Architecture)](#2-kiến-trúc-cảnh-báo-3-lớp-3-tier-alerting-architecture)
3. [Thiết lập Môi trường Host đa nền tảng](#3-thiết-lập-môi-trường-host-đa-nền-tảng)
   - [3.1. Arch Linux Host (KVM/libvirt)](#31-arch-linux-host-kvmlibvirt)
   - [3.2. Fedora Host (KVM/libvirt)](#32-fedora-host-kvmlibvirt)
   - [3.3. Oracle VirtualBox Host (Dual NICs)](#33-oracle-virtualbox-host-dual-nics)
   - [3.4. Bảng đối chiếu chọn môi trường phù hợp](#34-bảng-đối-chiếu-chọn-môi-trường-phù-hợp)
4. [Quản lý Cổng và Khắc phục Xung đột Cổng (Port Conflicts)](#4-quản-lý-cổng-và-khắc-phục-xung-đột-cổng-port-conflicts)
5. [Cài đặt và Cấu hình Alertmanager toàn diện](#5-cài-đặt-và-cấu-hình-alertmanager-toàn-diện)
   - [5.1. Khởi tạo User và Systemd Service](#51-khởi-tạo-user-và-systemd-service)
   - [5.2. Cấu hình Alertmanager (`alertmanager.yml`)](#52-cấu-hình-alertmanager-alertmanageryml)
   - [5.3. Mẫu thông báo Telegram chuẩn HTML (`alert.tmpl`) và sửa lỗi Timestamp](#53-mẫu-thông-báo-telegram-chuẩn-html-alerttmpl-và-sửa-lỗi-timestamp)
6. [Thiết lập Alerting Rules trên Prometheus](#6-thiết-lập-alerting-rules-trên-prometheus)
   - [6.1. Quy tắc cảnh báo chuẩn hóa (`alert_rules.yml`)](#61-quy-tắc-cảnh-báo-chuẩn-hóa-alert_rulesyml)
   - [6.2. Liên kết Prometheus với Alertmanager (`prometheus.yml`)](#62-liên-kết-prometheus-với-alertmanager-prometheusyml)
7. [Bộ công cụ Tự động hóa Kiểm thử (Testing Tools)](#7-bộ-công-cụ-tự-động-hóa-kiểm-thử-testing-tools)
   - [7.1. Script ép RAM thông minh: `auto_stress.py`](#71-script-ép-ram-thông-minh-auto_stresspy)
   - [7.2. Lệnh ép tải CPU qua `stress-ng`](#72-lệnh-ép-tải-cpu-qua-stress-ng)
8. [Kịch bản Demo Thực tế từng bước](#8-kịch-bản-demo-thực-tế-từng-bước)
   - [Kịch bản 1: Ép tải RAM 85% & Vòng đời Alert (Pending ➔ Firing ➔ Resolved)](#kịch-bản-1-ép-tải-ram-85--vòng-đời-alert-pending--firing--resolved)
   - [Kịch bản 2: Cơ chế Triệt tiêu Cảnh báo (Alert Inhibition) khi Exporter chết](#kịch-bản-2-cơ-chế-triệt-tiêu-cảnh-báo-alert-inhibition-khi-exporter-chết)
9. [Mở rộng Production: Mô hình On-Call và Multi-team Routing](#9-mở-rộng-production-mô-hình-on-call-và-multi-team-routing)
10. [Gợi ý Báo cáo và Trình bày Seminar](#10-gợi-ý-báo-cáo-và-trình-bày-seminar)

---

## 1. ĐẶT VẤN ĐỀ VÀ TRIẾT LÝ PRODUCTION ALERTING

### 1.1. Hiện tượng "Bão cảnh báo" (Alert Fatigue)
Trong quản trị hệ thống Linux và dịch vụ Web (Nginx/Apache), cài đặt cảnh báo đơn giản chỉ gửi thông báo mỗi khi có một thông số vượt ngưỡng thường dẫn đến thảm họa vận hành:
* **Ngập lụt thông báo (Spamming):** Khi một sự cố xảy ra (ví dụ: máy chủ sập nguồn), hàng chục cảnh báo phụ lập tức kích hoạt: CPU mất kết nối, RAM không đọc được, Web service không phản hồi, Database connection timeout...
* **Mất ngữ cảnh (Context Loss):** Kỹ sư trực ban nhận hàng trăm tin nhắn dồn dập và không thể phân biệt đâu là nguyên nhân gốc (Root Cause) và đâu là triệu chứng kéo theo (Symptom).
* **Hội chứng chai lì cảnh báo (Alert Fatigue):** Vì có quá nhiều thông báo rác, người trực có xu hướng tắt âm thanh hoặc bỏ qua cảnh báo, dẫn đến việc sự cố nghiêm trọng thật sự bị phớt lờ.

### 1.2. Bốn trụ cột của Production Alerting
Hệ thống cảnh báo chuyên nghiệp giải quyết triệt để các vấn đề trên thông qua 4 trụ cột:
1. **Gom cụm (Grouping):** Tổng hợp nhiều cảnh báo có cùng tính chất hoặc cùng máy chủ vào duy nhất một tin nhắn thông báo (thông qua `group_by`).
2. **Triệt tiêu (Inhibition):** Tự động tắt hoặc ẩn các cảnh báo thứ cấp nếu cảnh báo gốc mức nghiêm trọng hơn đã được kích hoạt (ví dụ: nếu `NodeExporterDown` mức Critical đã nổ ra, tự động triệt tiêu cảnh báo `HighCPUUsage` hay `HighMemoryUsage` của chính máy đó).
3. **Chuẩn hóa Golden Signals:** Xây dựng quy tắc cảnh báo theo 4 tín hiệu vàng SRE (Latency, Traffic, Errors, Saturation) kết hợp gắn nhãn phân loại rõ ràng (`severity`, `team`, `service`, `runbook_url`).
4. **Định tuyến On-Call (Smart Routing):** Phân chia luồng cảnh báo theo mức độ: cảnh báo Warning gửi qua Telegram/Slack; cảnh báo Critical tự động gọi điện hoặc tạo ca trực qua PagerDuty/Opsgenie.

---

## 2. KIẾN TRÚC CẢNH BÁO 3 LỚP (3-TIER ALERTING ARCHITECTURE)

```text
[ LỚP 1: DETECTION ]             [ LỚP 2: ROUTING & PROCESSING ]        [ LỚP 3: NOTIFICATION ]
┌─────────────────────────┐       ┌───────────────────────────────┐      ┌─────────────────────────┐
│    Prometheus Server    │       │         Alertmanager          │      │     Telegram Bot        │
│                         │       │                               │      │   (Real-time Chat)      │
│ • Quét định kỳ PromQL   │──────►│ • Grouping (Gom nhóm)         │─────►├─────────────────────────┤
│ • Đánh giá ngưỡng (for) │(Firing│ • Deduplication (Lọc trùng lặp│      │    PagerDuty / Slack    │
│ • Trạng thái:           │)      │ • Inhibition (Triệt tiêu phụ) │      │     (On-Call Escalation)│
│   Pending / Firing      │       │ • Silencing (Tắt bảo trì)     │      │                         │
└─────────────────────────┘       └───────────────────────────────┘      └─────────────────────────┘
```

* **Lớp 1 - Detection (Prometheus):** Chịu trách nhiệm đo đạc và phát hiện. PromQL được chạy định kỳ theo `evaluation_interval`. Khi biểu thức đúng liên tục trong khoảng thời gian `for`, trạng thái cảnh báo chuyển từ `PENDING` sang `FIRING` và bắn payload JSON sang Alertmanager.
* **Lớp 2 - Routing & Processing (Alertmanager):** Bộ não xử lý thông báo. Tiếp nhận các cảnh báo `FIRING`, thực hiện gom cụm (`group_wait`, `group_interval`), kiểm tra điều kiện triệt tiêu (`inhibit_rules`), và chọn kênh tiếp nhận (`receiver`) tương ứng theo nhãn.
* **Lớp 3 - Notification (Telegram / Slack / PagerDuty):** Trực tiếp chuyển tải thông điệp định dạng giàu thông tin (HTML, Markdown) đến kỹ sư vận hành kèm hướng dẫn xử lý (Runbook URL).

---

## 3. THIẾT LẬP MÔI TRƯỜNG HOST ĐA NỀN TẢNG

Hệ thống lab yêu cầu 2 máy ảo:
* `mon-server` (1.5GB RAM, IP ví dụ: `192.168.122.54`): Cài đặt Prometheus + Alertmanager + Grafana.
* `mon-target` (512MB RAM, IP ví dụ: `192.168.122.89`): Cài đặt Node Exporter + công cụ ép tải `stress`/`stress-ng`.

Tùy vào hệ điều hành host đang sử dụng, bạn có thể triển khai môi trường theo một trong các phương án dưới đây.

### 3.1. Arch Linux Host (KVM/libvirt)
```bash
# 1. Cài đặt các gói ảo hóa và mạng
sudo pacman -Syu qemu-desktop libvirt virt-manager dnsmasq iptables-nft

# 2. Cấp quyền user hiện tại
sudo usermod -aG libvirt,kvm $USER

# 3. Kích hoạt libvirtd service
sudo systemctl enable --now libvirtd
newgrp libvirt

# 4. Kích hoạt mạng default ảo hóa
sudo virsh net-autostart default
sudo virsh net-start default
sudo virsh net-list --all

# 5. Nếu dùng firewalld, reload lại cấu hình
sudo firewall-cmd --reload
```

### 3.2. Fedora Host (KVM/libvirt)
```bash
# 1. Cài đặt nhóm gói virtualization
sudo dnf install @virtualization

# 2. Khởi chạy libvirtd
sudo systemctl enable --now libvirtd
sudo usermod -aG libvirt $USER

# 3. Mở firewall cho dịch vụ libvirt
sudo firewall-cmd --add-service=libvirt --permanent
sudo firewall-cmd --reload
newgrp libvirt

# 4. Kích hoạt mạng default
sudo virsh net-autostart default
sudo virsh net-start default

# 5. Kiểm tra hỗ trợ ảo hóa phần cứng
ls -la /dev/kvm
```

### 3.3. Oracle VirtualBox Host (Dual NICs)
Nếu bạn không dùng KVM/libvirt mà sử dụng VirtualBox trên Windows/Linux, cấu hình mạng 2 card mạng (Dual NICs) cho mỗi máy ảo:
* **Card 1 (Adapter 1):** Chế độ **NAT** (Cho phép máy ảo truy cập Internet tải package).
* **Card 2 (Adapter 2):** Chế độ **Host-only Adapter** (Gán mạng nội bộ giữa Host và các máy ảo, ví dụ dải `192.168.56.0/24`).

*Cài đặt tiện ích VirtualBox trên Host (Linux):*
```bash
# Arch Linux:
sudo pacman -S virtualbox virtualbox-host-modules-arch
sudo usermod -aG vboxusers $USER
sudo systemctl enable --now vboxservice

# Fedora Linux:
sudo dnf install VirtualBox VirtualBox-ExtensionPack
sudo usermod -aG vboxusers $USER
sudo systemctl enable --now vboxdrv
```

### 3.4. Bảng đối chiếu chọn môi trường phù hợp

| Tiêu chí | Arch + KVM/libvirt | Fedora + KVM/libvirt | VirtualBox |
| :--- | :--- | :--- | :--- |
| **Độ khớp bài Lab** | Chuẩn xác 100% | Rất cao (dùng chung libvirt) | Cần cấu hình mạng riêng biệt |
| **Hiệu năng VM** | Tối đa (Hardware KVM) | Tối đa (Hardware KVM) | Trung bình (Type-2 Hypervisor) |
| **Tiện lợi mạng** | `virbr0` tự cấp DHCP qua dnsmasq | `virbr0` tự cấp DHCP qua dnsmasq | Cần tự tạo Host-Only Adapter |
| **Khuyến nghị** | Dành cho người dùng Arch Linux | Dành cho máy RedHat/Fedora | Dành cho máy Windows/MacOS cũ |

---

## 4. QUẢN LÝ CỔNG VÀ KHẮC PHỤC XUNG ĐỘT CỔNG (PORT CONFLICTS)

Khi triển khai toàn bộ hệ thống giám sát trên máy chủ, việc xung đột cổng là một trong những lỗi phổ biến nhất.

### 4.1. Danh mục Cổng chuẩn và Ứng dụng cạnh tranh

| Dịch vụ | Cổng mặc định | Ứng dụng thường xung đột | Giải pháp xử lý |
| :--- | :---: | :--- | :--- |
| **Grafana** | `3000` | Node.js dev server, React, Ruby on Rails | Đổi `http_port = 3001` trong `/etc/grafana/grafana.ini` |
| **Prometheus** | `9090` | Cockpit Console, Java Web apps, Microservices | Đổi flag `--web.listen-address="0.0.0.0:9091"` trong file systemd |
| **Alertmanager**| `9093` | Phiên bản Alertmanager cũ, Service Mesh | Đổi flag `--web.listen-address="0.0.0.0:9094"` trong file systemd |
| **Node Exporter**| `9100` | Agent giám sát khác, Influx Telegraf | Đổi flag `--web.listen-address="0.0.0.0:9101"` |

### 4.2. Lệnh kiểm tra tiến trình đang chiếm dụng cổng
```bash
# Kiểm tra danh sách cổng đang lắng nghe:
sudo ss -tulpn | grep -E '3000|9090|9093|9100'

# Hoặc dùng lsof:
sudo lsof -i :9090
sudo lsof -i :9093
```

---

## 5. CÀI ĐẶT VÀ CẤU HÌNH ALERTMANAGER TOÀN DIỆN

Thực hiện trên máy **`mon-server`**.

### 5.1. Khởi tạo User và Systemd Service

```bash
# 1. Tạo user hệ thống không có quyền login shell để tăng cường bảo mật
sudo useradd --no-create-home --shell /bin/false alertmanager

# 2. Tạo các thư mục cấu hình và lưu trữ trạng thái
sudo mkdir -p /etc/alertmanager /var/lib/alertmanager
sudo chown -R alertmanager:alertmanager /etc/alertmanager /var/lib/alertmanager

# 3. Tải và cài đặt Alertmanager binary (nếu chưa có sẵn qua package manager)
# Trên Ubuntu/Debian có thể dùng: sudo apt install -y prometheus-alertmanager
```

Nếu cài đặt từ binary, tạo file dịch vụ systemd tại `/etc/systemd/system/alertmanager.service`:

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
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

### 5.2. Cấu hình Alertmanager (`alertmanager.yml`)

Mở file cấu hình Alertmanager tại `/etc/alertmanager/alertmanager.yml`:

```bash
sudo nano /etc/alertmanager/alertmanager.yml
```

Nội dung cấu hình chuẩn tích hợp **Grouping**, **Inhibition**, **Telegram Receiver**, và **Webhook/On-Call Routing**:

```yaml
global:
  resolve_timeout: 5m

# Nạp file giao diện mẫu thông báo
templates:
  - '/etc/alertmanager/alert.tmpl'

# Cấu hình định tuyến (Routing)
route:
  group_by: ['alertname', 'instance', 'job']
  group_wait: 10s       # Chờ 10s để gom các alert xảy ra cùng lúc
  group_interval: 1m     # Khoảng thời gian gửi đợt thông báo tiếp theo nếu có thay đổi
  repeat_interval: 1h    # Gửi lại cảnh báo nếu sự cố vẫn chưa được khắc phục
  receiver: 'telegram-receiver'
  routes:
    # Cảnh báo critical gửi đồng thời sang webhook/on-call và telegram
    - matchers:
        - severity="critical"
      receiver: 'telegram-receiver'
      continue: true
    - matchers:
        - severity="critical"
      receiver: 'incident-webhook'

# Danh sách đích nhận thông báo (Receivers)
receivers:
  - name: 'telegram-receiver'
    telegram_configs:
      - bot_token: 'YOUR_BOT_TOKEN_HERE'       # Thay bằng Bot Token từ @BotFather
        chat_id: YOUR_CHAT_ID_HERE             # Thay bằng Chat ID Telegram của bạn
        parse_mode: 'HTML'
        send_resolved: true                    # Bắt buộc: Gửi tin thông báo khi sự cố được khắc phục
        message: '{{ template "telegram.html" . }}'

  - name: 'incident-webhook'
    webhook_configs:
      - url: 'http://127.0.0.1:5001/alerts'   # Endpoint tiếp nhận của Webhook / PagerDuty gateway
        send_resolved: true

# Quy tắc triệt tiêu cảnh báo (Inhibition Rules)
# NGUYÊN TẮC: Khi NodeExporterDown (Critical) kích hoạt, triệt tiêu HighCPUUsage (Warning)
inhibit_rules:
  - source_matchers:
      - severity="critical"
      - alertname="NodeExporterDown"
    target_matchers:
      - severity="warning"
      - alertname="HighCPUUsage"
    equal: ['instance', 'job']
```

> [!IMPORTANT]
> **Giải thích cơ chế Triệt tiêu (`inhibit_rules`):**
> * Khi target chết, dịch vụ Node Exporter bị tắt, Prometheus sẽ nổ cảnh báo `NodeExporterDown` (mức `critical`).
> * Trước thời điểm đó, nếu CPU đang cao, cảnh báo `HighCPUUsage` (mức `warning`) có thể đang hoạt động.
> * Nhờ `inhibit_rules` với điều kiện khớp cặp `instance` và `job`, Alertmanager sẽ tự động dập tắt thông báo `HighCPUUsage`. Đội ngũ trực ban chỉ nhận đúng 1 thông báo lỗi gốc duy nhất: máy chủ/exporter đã dừng.

---

### 5.3. Mẫu thông báo Telegram chuẩn HTML (`alert.tmpl`) và sửa lỗi Timestamp

Tạo file mẫu tại `/etc/alertmanager/alert.tmpl`:

```bash
sudo nano /etc/alertmanager/alert.tmpl
```

Nội dung template chuẩn:

```gotemplate
{{ define "telegram.html" }}
{{ if eq .Status "firing" }}
<b>🚨 CANH BÁO SỰ CỐ HỆ THỐNG</b>
{{ else }}
<b>✅ SỰ CỐ ĐÃ ĐƯỢC KHẮC PHỤC</b>
{{ end }}
------------------------------------
{{ range .Alerts }}
<b>Cảnh báo:</b> <code>{{ .Labels.alertname }}</code>
<b>Mức độ:</b> <code>{{ .Labels.severity | toUpper }}</code>
<b>Dịch vụ:</b> {{ .Labels.job }}
<b>Đối tượng:</b> <code>{{ .Labels.instance }}</code>
<b>Thời gian:</b> <code>{{ .StartsAt.Local.Format "15:04:05 02/01/2006" }}</code>

<b>Chi tiết:</b> {{ .Annotations.description }}
{{ if .Annotations.runbook_url }}
🔗 <a href="{{ .Annotations.runbook_url }}">Tài liệu hướng dẫn khắc phục (Runbook)</a>
{{ end }}
------------------------------------
{{ end }}
{{ end }}
```

> [!TIP]
> **Cách khắc phục lỗi rỗng biến `Thời gian` trên Telegram:**
> * **Nguyên nhân cốt lõi:** Biến `.StartsAt` nằm bên trong từng phần tử của mảng danh sách `.Alerts`. Nếu gọi trực tiếp `{{ .StartsAt }}` ngoài vòng lặp, Alertmanager sẽ không truy xuất được dữ liệu và in ra giá trị rỗng. Ngoài ra, Go Template yêu cầu cú pháp định dạng thời gian tham chiếu chuẩn của ngôn ngữ Go (`15:04:05 02/01/2006`).
> * **Cú pháp chính xác:** Bọc trong vòng lặp `{{ range .Alerts }}` và gọi `{{ .StartsAt.Local.Format "15:04:05 02/01/2006" }}`.

Kiểm tra cú pháp cấu hình Alertmanager:
```bash
amtool check-config /etc/alertmanager/alertmanager.yml
sudo systemctl restart alertmanager
sudo systemctl status alertmanager
```

---

## 6. THIẾT LẬP ALERTING RULES TRÊN PROMETHEUS

### 6.1. Quy tắc cảnh báo chuẩn hóa (`alert_rules.yml`)

Tạo file quy tắc cảnh báo tại `/etc/prometheus/alert_rules.yml`:

```bash
sudo nano /etc/prometheus/alert_rules.yml
```

Nội dung rules:

```yaml
groups:
  - name: production_node_alerts
    rules:
      # 1. Cảnh báo Exporter hoặc Target chết (Availability - Critical)
      - alert: NodeExporterDown
        expr: up{job="node_exporter"} == 0
        for: 30s
        labels:
          severity: critical
          team: platform
          tier: infrastructure
        annotations:
          summary: "Node Exporter trên {{ $labels.instance }} mất kết nối"
          description: "Target {{ $labels.instance }} không phản hồi yêu cầu scrape metrics trong hơn 30 giây."
          runbook_url: "https://wiki.internal.net/ops/runbook/node-down"

      # 2. Cảnh báo quá tải CPU (Saturation - Warning)
      - alert: HighCPUUsage
        expr: 100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[1m])) * 100) > 80
        for: 1m
        labels:
          severity: warning
          team: platform
          tier: infrastructure
        annotations:
          summary: "Mức sử dụng CPU cao trên {{ $labels.instance }}"
          description: "Mức sử dụng CPU trên {{ $labels.instance }} hiện là {{ $value | printf \"%.2f\" }}% (vượt ngưỡng 80%)."
          runbook_url: "https://wiki.internal.net/ops/runbook/cpu-spike"

      # 3. Cảnh báo quá tải RAM (Saturation - Warning)
      # LƯU Ý QUAN TRỌNG: Dùng MemAvailable thay vì MemFree để phản ánh chính xác lượng RAM thực sự khả dụng
      - alert: HighMemoryUsage
        expr: 100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) > 80
        for: 1m
        labels:
          severity: warning
          team: platform
          tier: infrastructure
        annotations:
          summary: "Mức sử dụng RAM cao trên {{ $labels.instance }}"
          description: "Mức sử dụng RAM thực tế trên {{ $labels.instance }} đạt {{ $value | printf \"%.2f\" }}% (vượt ngưỡng 80%)."
          runbook_url: "https://wiki.internal.net/ops/runbook/high-ram"

      # 4. Cảnh báo sắp cạn kiệt dung lượng đĩa (Saturation - Warning)
      - alert: DiskSpaceLow
        expr: 100 - ((node_filesystem_avail_bytes{mountpoint="/"} * 100) / node_filesystem_size_bytes{mountpoint="/"}) > 85
        for: 1m
        labels:
          severity: warning
          team: platform
          tier: storage
        annotations:
          summary: "Dung lượng phân vùng root (/) sắp hết trên {{ $labels.instance }}"
          description: "Phân vùng root trên {{ $labels.instance }} đã sử dụng {{ $value | printf \"%.2f\" }}% (vượt ngưỡng 85%)."
          runbook_url: "https://wiki.internal.net/ops/runbook/disk-cleanup"
```

### 6.2. Liên kết Prometheus với Alertmanager (`prometheus.yml`)

Mở file `/etc/prometheus/prometheus.yml`:

```yaml
global:
  scrape_interval: 5s       # 5s cho demo để nhận diện metric nhanh
  evaluation_interval: 5s   # Đánh giá rules mỗi 5s

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
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "node_exporter"
    scrape_interval: 5s
    static_configs:
      - targets: ["192.168.122.89:9100"] # Thay bằng IP thực tế của mon-target
```

**Kiểm tra tính hợp lệ của cấu hình và rules:**
```bash
promtool check config /etc/prometheus/prometheus.yml
promtool check rules /etc/prometheus/alert_rules.yml
sudo systemctl restart prometheus
```

---

## 7. BỘ CÔNG CỤ TỰ ĐỘNG HÓA KIỂM THỬ (TESTING TOOLS)

Thực hiện trên máy **`mon-target`**.

### 7.1. Script ép RAM thông minh: `auto_stress.py`
Script [scripts/auto_stress.py](file:///home/archlinux/Projects/Linux/Seminar/linux_op_lab1/scripts/auto_stress.py) được thiết kế chuyên biệt để tự tính toán dung lượng RAM đang chiếm dụng, suy ra số MB cần ép thêm để vừa khít ngưỡng mong muốn (ví dụ 85%) mà **không bị nhân Linux Out-Of-Memory (OOM) Killer bắn hạ tiến trình**:

```bash
# Cài đặt thư viện bổ trợ trên Ubuntu (mon-target):
sudo apt update && sudo apt install -y python3-psutil stress
```

Chạy script với cú pháp:
```bash
# Cú pháp: python3 auto_stress.py <Phần_Trăm_RAM> [Thời_Gian_Giây]
python3 scripts/auto_stress.py 85 180
```

### 7.2. Lệnh ép tải CPU qua `stress-ng`
```bash
# Cài đặt stress-ng:
sudo apt install -y stress-ng

# Ép 100% 1 core CPU trong 180 giây:
stress-ng --cpu 1 --timeout 180s
```

---

## 8. KỊCH BẢN DEMO THỰC TẾ TỪNG BƯỚC

### Kịch bản 1: Ép tải RAM 85% & Vòng đời Alert (Pending ➔ Firing ➔ Resolved)

#### Bước 1: Kích hoạt ép tải trên `mon-target`
```bash
python3 scripts/auto_stress.py 85 180
```
Script sẽ tính toán lượng RAM đang có sẵn và chỉ ép thêm vừa đủ để đưa tổng mức sử dụng lên chính xác 85%.

#### Bước 2: Quan sát trạng thái PENDING trên Prometheus UI
* Truy cập `http://<IP-mon-server>:9090/alerts`.
* Rule `HighMemoryUsage` chuyển sang màu vàng **`PENDING`** (Biểu thức thỏa mãn điều kiện nhưng chưa đủ thời gian `for: 1m`).

#### Bước 3: Trạng thái FIRING & Nhận cảnh báo Telegram
* Sau khi duy trì quá 1 phút, rule chuyển sang màu đỏ **`FIRING`**.
* Alertmanager gom nhóm và gửi tin nhắn tức thì về Telegram:

```text
🚨 CANH BÁO SỰ CỐ HỆ THỐNG
------------------------------------
Cảnh báo: HighMemoryUsage
Mức độ: WARNING
Dịch vụ: node_exporter
Đối tượng: 192.168.122.89:9100
Thời gian: 10:15:32 21/10/2026

Chi tiết: Mức sử dụng RAM thực tế trên 192.168.122.89:9100 đạt 85.14% (vượt ngưỡng 80%).
🔗 Tài liệu hướng dẫn khắc phục (Runbook)
------------------------------------
```

#### Bước 4: Tự động phục hồi (RESOLVED)
* Hết thời gian 180 giây, tiến trình `stress` dừng. Lượng RAM trở lại bình thường (~50-60%).
* Prometheus phát hiện giá trị tụt xuống dưới ngưỡng và báo sang Alertmanager.
* Telegram nhận thông báo phục hồi:

```text
✅ SỰ CỐ ĐÃ ĐƯỢC KHẮC PHỤC
------------------------------------
Cảnh báo: HighMemoryUsage
Mức độ: WARNING
Dịch vụ: node_exporter
Đối tượng: 192.168.122.89:9100
Thời gian: 10:18:32 21/10/2026

Chi tiết: Mức sử dụng RAM thực tế trên 192.168.122.89:9100 đạt 52.30% (vượt ngưỡng 80%).
------------------------------------
```

---

### Kịch bản 2: Cơ chế Triệt tiêu Cảnh báo (Alert Inhibition) khi Exporter chết

Mục đích: Chứng minh cơ chế `inhibit_rules` ngăn ngừa bão thông báo bằng cách tự dập tắt cảnh báo phụ khi cảnh báo chính nổ ra.

#### Bước 1: Ép tải CPU trên `mon-target`
```bash
stress-ng --cpu 1 --timeout 300s &
```
* Sau 1 phút, Prometheus kích hoạt `HighCPUUsage` (mức `warning`).
* Alertmanager UI (`http://<IP-mon-server>:9093`) hiển thị cảnh báo `HighCPUUsage`.

#### Bước 2: Cố tình tắt Node Exporter trên `mon-target`
Mô phỏng sự cố sập Exporter / lỗi dịch vụ mạng:
```bash
sudo systemctl stop prometheus-node-exporter
```

#### Bước 3: Kiểm chứng kết quả Triệt tiêu trên Alertmanager
* Sau 30 giây, Prometheus phát hiện `up == 0` và kích hoạt `NodeExporterDown` (mức `critical`).
* Kiểm tra trên giao diện Alertmanager (`http://<IP-mon-server>:9093`):
  * Cảnh báo `NodeExporterDown` hiển thị bình thường ở trạng thái active.
  * Cảnh báo `HighCPUUsage` **bị làm mờ và gắn nhãn "Inhibited"** (Bị triệt tiêu hoàn toàn).
* Kiểm tra hộp thư/Telegram: Người quản trị **chỉ nhận duy nhất** thông báo máy chủ mất kết nối `NodeExporterDown`, không bị làm phiền bởi thông báo `HighCPUUsage` phụ.

#### Bước 4: Khởi động lại dịch vụ
```bash
sudo systemctl start prometheus-node-exporter
```
Hệ thống tự động trở lại bình thường.

---

## 9. MỞ RỘNG PRODUCTION: MÔ HÌNH ON-CALL VÀ MULTI-TEAM ROUTING

Trong môi trường doanh nghiệp quy mô lớn, Alertmanager thường được chia luồng thông minh dựa trên nhãn:

```text
                               ┌─► Slack #alerts-warning (Warning level)
Alertmanager (Route & Filter) ─┼─► PagerDuty / Opsgenie (Critical -> Gọi điện trực ban)
                               ├─► Jira / Service-Now (Tự động tạo Ticket)
                               └─► Webhook Microservice (Auto-remediation / Tự khởi động lại VM)
```

Ví dụ cấu hình routing đa tầng trong `alertmanager.yml`:
```yaml
route:
  receiver: 'slack-default'
  routes:
    - matchers:
        - severity="critical"
      receiver: 'pagerduty-oncall'
    - matchers:
        - team="dba"
      receiver: 'database-telegram'
    - matchers:
        - team="platform"
      receiver: 'platform-telegram'
```

---

## 10. GỢI Ý BÁO CÁO VÀ TRÌNH BÀY SEMINAR

Khi trình bày trước giảng viên và hội đồng, nhóm nên nhấn mạnh các điểm then chốt:

1. **Từ Monitoring đến Observability & Alerting:** Giám sát qua Dashboard chỉ mang tính thụ động. Production Alerting mang lại sự chủ động đón đầu sự cố.
2. **Tính thực tiễn của giải pháp:**
   * Script `auto_stress.py` xử lý bài toán ép RAM an toàn không gây sập máy.
   * Giải quyết triệt để lỗi rỗng chuỗi thời gian trong Go Template trên Telegram Bot.
3. **Cơ chế Triệt tiêu (Inhibition):** Đây là sự khác biệt giữa hệ thống nghiệp dư (spam hàng tá alert) và hệ thống chuẩn Production (chỉ cảnh báo đúng nguồn gốc lỗi).
4. **Khả năng mở rộng:** Hệ thống sẵn sàng kết nối PagerDuty, Slack, và các hệ thống On-Call tự động hóa của doanh nghiệp.

---

## 11. TÀI LIỆU THAM KHẢO
* [Tài liệu chính thức về Prometheus Alerting Rules](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/)
* [Tài liệu cấu hình Alertmanager](https://prometheus.io/docs/alerting/latest/alertmanager/)
* [Hướng dẫn tích hợp Telegram Bot Webhook](https://prometheus.io/docs/alerting/latest/configuration/#telegram_config)
* [Nguyên tắc Google SRE Book - Monitoring Distributed Systems](https://sre.google/sre-book/monitoring-distributed-systems/)
