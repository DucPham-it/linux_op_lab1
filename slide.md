---
marp: true
theme: default
paginate: true
header: "Chuyên đề Mở rộng: HA & LTS · Security & Auth · GitOps & MaC"
footer: "Lab #10 · Prometheus | Grafana | Alertmanager | Thanos | MinIO | Nginx"
---

# BÁO CÁO CÁC CHUYÊN ĐỀ MỞ RỘNG
## Giám sát Hạ tầng Linux Chuẩn Enterprise
### High Availability & LTS · Security & Auth · GitOps & MaC

**Môi trường:** KVM/libvirt · Debian 12 Minimal Cloud  
**Node:** `mon-server` (192.168.122.54) & `mon-target` (192.168.122.38)

---

## MỤC TIÊU 3 CHUYÊN ĐỀ MỞ RỘNG

```text
┌────────────────────────────────────────────────────────────────────────┐
│                      3 TRỤ CỘT NÂNG CẤP HỆ THỐNG                       │
├────────────────────┬────────────────────┬──────────────────────────────┤
│ 1. HA & LƯU TRỮ    │ 2. AN NINH & AUTH  │ 3. GITOPS & TỰ ĐỘNG HÓA      │
│ (ha_longterm.md)   │ (security_auth.md) │ (gitops_monitoring_code.md)  │
├────────────────────┼────────────────────┼──────────────────────────────┤
│ • Không còn SPOF   │ • Mã hóa TLS 1.3   │ • Xóa bỏ thảm họa ClickOps   │
│ • Khử trùng Alert  │ • Web Basic Auth   │ • Grafana Provisioning       │
│ • Thanos + MinIO   │ • Grafana RBAC/SSO │ • File Service Discovery     │
│ • Lưu trữ vĩnh viễn│ • Tường lửa UFW    │ • Pipeline deploy_stack.sh   │
└────────────────────┴────────────────────┴──────────────────────────────┘
```

---

# PHẦN 1: TÍNH SẴN SÀNG CAO & LƯU TRỮ DÀI HẠN
### High Availability (HA) & Long-Term Storage (LTS)

---

## 1.1. Thách thức của Prometheus Local TSDB

* **Bản chất Local-First:** Dữ liệu time-series lưu cục bộ trong các block 2h kết hợp Write-Ahead Log (WAL).
* **3 Rủi ro nghiêm trọng khi lên Production:**
  1. **Đơn điểm lỗi (SPOF):** 1 node `mon-server` chết ➔ Mù toàn bộ hệ thống quan sát và tê liệt cảnh báo.
  2. **Cạn kiệt ổ cứng (Storage Exhaustion):** Scrape interval 5s ➔ Đĩa phình to nhanh chóng; khó giữ data > 1 tháng.
  3. **Suy giảm hiệu năng truy vấn (Query Degradation / OOM):** Truy vấn lịch sử 6 tháng - 1 năm khiến Prometheus nạp hàng nghìn block vào RAM ➔ Crash Out-Of-Memory.

---

## 1.2. Chiến lược Tối ưu hóa Local TSDB

Trước khi lên HA/Cloud, tối ưu tối đa ổ cứng cục bộ:

* **Tách phân vùng chuyên dụng (`/var/lib/prometheus`):**
  - Mount với cờ `noatime` trong `/etc/fstab`:
    ```text
    LABEL=prometheus_data /var/lib/prometheus ext4 defaults,noatime 0 2
    ```
  - *Hiệu quả:* Triệt tiêu thao tác ghi I/O cập nhật access time mỗi khi đọc chunk.
* **Chính sách Retention Kép & Nén WAL:**
  - `--storage.tsdb.retention.time=15d`: Tự động xóa block cũ sau 15 ngày.
  - `--storage.tsdb.retention.size=10GB`: Xóa sớm hơn nếu dung lượng chạm mốc 10GB.
  - `--storage.tsdb.wal-compression`: Kích hoạt nén Snappy ➔ Giảm **30–50%** RAM & dung lượng đĩa của WAL.

---

## 1.3. Kiến trúc Dual-Instance Active-Active

* **Nguyên lý:** Chạy 2 bản sao độc lập cùng cào (scrape) từ `mon-target:9100`.
  - `Prometheus A` (Replica 1): Cổng `9090` (external_label: `replica="prometheus-a"`).
  - `Prometheus B` (Replica 2): Cổng `9091` (external_label: `replica="prometheus-b"`).
* **Cơ chế Khử trùng lặp (Alertmanager Deduplication):**
  - Cả 2 instance cùng phát hiện sự cố và cùng bắn cảnh báo sang Alertmanager.
  - Alertmanager băm nhãn alert thành **Fingerprint duy nhất**.
  - Cửa sổ gom `group_wait: 10s` ➔ **Alertmanager tự loại bỏ alert trùng lặp, chỉ gửi đúng 1 thông báo tới Telegram**.

```text
[ Prometheus A (:9090) ] ──┐
                           ├──► [ Alertmanager ] ──► [ Telegram: 1 Alert duy nhất ]
[ Prometheus B (:9091) ] ──┘     (Deduplication)
```

---

## 1.4. Lưu trữ Dài hạn (LTS) với Thanos & MinIO

```text
┌──────────────────────┐   ┌──────────────────────┐
│  Prometheus A (:9090)│   │  Prometheus B (:9091)│
└──────────┬───────────┘   └──────────┬───────────┘
           │ (Mỗi 2h nén block)       │ (Mỗi 2h nén block)
           ▼                          ▼
┌──────────────────────┐   ┌──────────────────────┐
│ Thanos Sidecar:10901 │   │ Thanos Sidecar:10902 │
└──────────┬───────────┘   └──────────┬───────────┘
           │ Đẩy block lên S3         │
           ▼                          │
┌─────────────────────────────────────┴┐
│         MinIO S3 Server (:9000)      │ ◄─── Bucket: 'thanos-lts'
└──────────────────▲───────────────────┘
                   │ Đọc block lịch sử
┌──────────────────┴───────────────────┐
│         Thanos Querier (:10903)      │ ◄─── Grafana Dashboard
└──────────────────────────────────────┘      (Truy vấn xuyên suốt từ hiện tại đến 1 năm)
```

* **Thanos Sidecar:** Gắn liền với TSDB; đẩy block hoàn tất 2h lên MinIO.
* **MinIO Object Storage:** Tương thích chuẩn AWS S3 API, triển khai gọn nhẹ trên Linux.
* **Thanos Querier:** Cung cấp API Prometheus hợp nhất; truy vấn dữ liệu nóng (Local TSDB) + dữ liệu lạnh (MinIO).

---

# PHẦN 2: BẢO MẬT & QUẢN LÝ QUYỀN TRUY CẬP
### Security, TLS Encryption, Authentication & Access Control (RBAC)

---

## 2.1. Mô hình Đe dọa (Threat Model) Hệ thống Giám sát

Hạ tầng monitoring mặc định thường chạy **HTTP bản rõ** với 4 lỗ hổng chí mạng:

1. **Rò rỉ thông tin hạ tầng (Information Disclosure):** Node Exporter `:9100` lộ toàn bộ kernel, tiến trình, tài nguyên mạng ➔ Kẻ tấn công trinh sát hệ thống.
2. **Nghe lén dữ liệu (Eavesdropping & Packet Sniffing):** Dữ liệu chỉ số và token/mật khẩu truyền plaintext trên mạng nội bộ.
3. **Phá hoại dữ liệu qua Admin API (Data Destruction):** Nếu bật `--web.enable-admin-api`, bất kỳ ai cũng có thể gửi `POST /api/v1/admin/tsdb/delete_series` để xóa trắng dữ liệu.
4. **Mất kiểm soát giao diện:** Grafana cho phép tự do đăng ký (`allow_sign_up`) và xem dashboard ẩn danh (anonymous access).

---

## 2.2. Mã hóa Đường truyền: Nginx TLS Reverse Proxy

* **Nginx làm SSL Termination tập trung:**
  - Tạo chứng chỉ OpenSSL RSA 2048-bit, bắt buộc giao thức `TLSv1.2` và `TLSv1.3`.
  - Tự động chuyển hướng toàn bộ HTTP (Port 80) sang HTTPS (Port 443).
  - Tích hợp Security Headers: `HSTS`, `X-Content-Type-Options: nosniff`, `X-XSS-Protection`.
* **Cấu hình Reverse Proxy theo Route-Prefix:**

```text
Trình duyệt / Client (HTTPS:443 - TLS 1.3)
                  │
                  ▼
┌────────────────────────────────────────────────────────┐
│             Nginx Reverse Proxy (mon-server)           │
├────────────────────────────────────────────────────────┤
│ • location /              ──► Grafana (127.0.0.1:3000) │
│ • location /prometheus/   ──► Prometheus (:9090)       │
│ • location /alertmanager/ ──► Alertmanager (:9093)     │
└────────────────────────────────────────────────────────┘
```

---

## 2.3. Xác thực Basic Auth (bcrypt) & Phân quyền RBAC

* **Native Web Basic Auth trên Prometheus & Node Exporter:**
  - Dùng thuật toán băm an toàn: `htpasswd -B -C 10 /etc/prometheus/web_auth.htpasswd admin`.
  - Khai báo file `web.yml` trong cờ khởi chạy: `--web.config.file=/etc/prometheus/web.yml`.
  - `prometheus.yml` cấu hình cào dữ liệu an toàn:
    ```yaml
    basic_auth:
      username: "scraper"
      password: "ScraperStrongPassword2026!"
    ```
* **Siết chặt Bảo mật & RBAC trong Grafana (`grafana.ini`):**
  - Khóa tạo tài khoản tự do: `allow_sign_up = false`.
  - Tắt hoàn toàn chế độ ẩn danh: `[auth.anonymous] enabled = false`.
  - Phân quyền theo vai trò rõ ràng:
    - **Admin:** Quản trị datasource, user, bảo mật.
    - **Editor:** Tạo và chỉnh sửa dashboard, rules.
    - **Viewer:** Chỉ có quyền đọc, không chỉnh sửa cấu hình.

---

## 2.4. Khóa Admin API & Cô lập Tường lửa UFW

* **Vô hiệu hóa TSDB Admin API:**
  - Tuyệt đối **loại bỏ cờ `--web.enable-admin-api`** khỏi service systemd.
  - Ngăn chặn triệt để nguy cơ tấn công HTTP POST xóa database time-series.
* **Tường lửa UFW trên `mon-target` (Cô lập Exporter):**
  - Mặc định chặn tất cả kết nối đi vào: `ufw default deny incoming`.
  - Chỉ mở SSH (Port 22) cho quản trị.
  - **Chỉ mở cổng 9100 cho DUY NHẤT IP của `mon-server` (`192.168.122.54`)**:
    ```bash
    sudo ufw allow from 192.168.122.54 to any port 9100 proto tcp
    ```
* **Cô lập Cổng dịch vụ trên `mon-server`:**
  - Các port 3000, 9090, 9093 chỉ bind trên `127.0.0.1` (loopback).
  - UFW chỉ mở ra ngoài các cổng: 22 (SSH), 80 (Redirect HTTP) và 443 (HTTPS).

---

# PHẦN 3: GITOPS & MONITORING AS CODE
### Declarative Provisioning, File SD & Pipeline Triển khai

---

## 3.1. Thảm họa "ClickOps" vs. Triết lý GitOps

* **Thảm họa Vận hành Thủ công (ClickOps):**
  - Bấm chuột cấu hình Datasource, vẽ Panel, chỉnh sửa ngưỡng alert trên Web UI.
  - **Hậu quả:** Không có version control (không biết ai sửa gì lúc nào), sai lệch môi trường (Configuration Drift), mất trắng cấu hình khi máy chủ hỏng (Disaster Recovery Failure).
* **Triết lý Monitoring-as-Code (MaC) & GitOps:**
  - 100% tài nguyên được biểu diễn dưới dạng code (declarative YAML/JSON).
  - Git là **Single Source of Truth** (`git commit`, `git push`, code review).
  - Tự động kiểm tra cú pháp trước khi nạp (`promtool`, `amtool`).

```text
Git Repository ──► Code Review ──► promtool check ──► Hot-Reload Hệ thống
```

---

## 3.2. Grafana Provisioning (Datasource & Dashboard as Code)

Tự động nạp cấu hình từ `/etc/grafana/provisioning/` mỗi khi khởi động:

* **Datasource as Code (`datasources/prometheus.yml`):**
  ```yaml
  apiVersion: 1
  datasources:
    - name: Prometheus
      type: prometheus
      url: http://localhost:9090
      isDefault: true
      editable: false        # Khóa chỉnh sửa trên UI để chống drift
  ```
* **Dashboard as Code (`dashboards/dashboards.yml`):**
  ```yaml
  apiVersion: 1
  providers:
    - name: 'Linux Infrastructure'
      folder: 'Linux Production'
      type: file
      allowUiUpdates: false  # Chặn mọi hành vi sửa giao diện ghi đè JSON gốc
      updateIntervalSeconds: 10
      options:
        path: /var/lib/grafana/dashboards
  ```

---

## 3.3. Prometheus File-based Service Discovery (File SD)

* **Nhược điểm của `static_configs`:** Thêm/sửa IP máy chủ mục tiêu phải mở file `prometheus.yml` và restart dịch vụ ➔ Rủi ro cú pháp làm sập monitoring.
* **Cơ chế File SD (`file_sd_configs`):**
  - Prometheus liên tục giám sát thư mục `/etc/prometheus/targets/*.json`.
  - Cấu hình trong `prometheus.yml`:
    ```yaml
    - job_name: "node_exporter"
      file_sd_configs:
        - files:
            - '/etc/prometheus/targets/*.json'
          refresh_interval: 5s
    ```
* **Đăng ký máy chủ mục tiêu động (`targets/nodes.json`):**
  - Chỉ cần ghi file JSON vào thư mục ➔ **Prometheus tự nạp target và label sau 5 giây mà không cần reload hay restart**.

---

## 3.4. Pipeline Triển khai Tự động (`deploy_stack.sh`)

Script [deploy_stack.sh](file:///home/archlinux/Projects/Linux/Seminar/linux_op_lab1/scripts/deploy_stack.sh) thực thi quy trình CI/CD cục bộ an toàn qua 5 bước:

```bash
# 1. Kiểm tra tính hợp lệ cú pháp trước khi triển khai
promtool check config configs/prometheus/prometheus.yml
promtool check rules  configs/prometheus/*.yml
amtool check-config   configs/alertmanager/alertmanager.yml

# 2. Đồng bộ file cấu hình vào thư mục hệ thống
sudo cp configs/prometheus/*.yml /etc/prometheus/
sudo cp configs/prometheus/targets/*.json /etc/prometheus/targets/

# 3. Đồng bộ Grafana Provisioning & Dashboards JSON
sudo cp configs/grafana/datasources/*.yml /etc/grafana/provisioning/datasources/
sudo cp configs/grafana/dashboards/*.yml  /etc/grafana/provisioning/dashboards/
sudo cp configs/grafana/json/*.json       /var/lib/grafana/dashboards/

# 4. Kích hoạt Hot-Reload không làm rớt dịch vụ
curl -s -X POST http://localhost:9090/-/reload
sudo systemctl reload alertmanager
sudo systemctl restart grafana-server
```

---

# CẢM ƠN THẦY VÀ CÁC BẠN ĐÃ THEO DÕI!
### Q & A
