# MỞ RỘNG NHÓM 1: TÍNH SẴN SÀNG CAO VÀ LƯU TRỮ BỀN VỮNG
## High Availability (HA) & Long-term Storage cho Prometheus TSDB
**Môi trường áp dụng:** KVM/libvirt · `mon-server` (Debian 12) & `mon-target` (Debian 12) · Lab #10

---

## MỤC LỤC
1. [Đặt vấn đề và Thách thức Lưu trữ của Prometheus](#1-đặt-vấn-đề-và-thách-thức-lưu-trữ-của-prometheus)
2. [Chiến lược Quản lý Local Storage & Retention](#2-chiến-lược-quản-lý-local-storage--retention)
   - 2.1. Phân vùng đĩa chuyên dụng cho TSDB
   - 2.2. Tinh chỉnh Retention Time, Retention Size và WAL Compression
3. [Mô hình Prometheus High Availability (HA Replicas)](#3-mô-hình-prometheus-high-availability-ha-replicas)
   - 3.1. Kiến trúc Dual-Instance Active-Active
   - 3.2. Cơ chế Khử trùng lặp (Deduplication) của Alertmanager
   - 3.3. Cấu hình triển khai Prometheus Replica song song
4. [Kiến trúc Lưu trữ Dài hạn (Long-term Retention) với MinIO & Thanos](#4-kiến-trúc-lưu-trữ-dài-hạn-long-term-retention-với-minio--thanos)
   - 4.1. Tổng quan giải pháp Thanos Sidecar + Object Storage
   - 4.2. Cài đặt MinIO Server (S3-compatible Object Storage)
   - 4.3. Cấu hình Thanos Sidecar đẩy dữ liệu TSDB Blocks
   - 4.4. Cấu hình Thanos Querier cho Grafana truy vấn xuyên suốt
5. [Kịch bản Demo Thực tế Từng bước](#5-kịch-bản-demo-thực-tế-từng-bước)
   - Demo 1: Kiểm chứng WAL Compression và Cơ chế Compact dữ liệu TSDB
   - Demo 2: Kiểm thử tính sẵn sàng cao (Fault-Tolerance) khi dừng 1 Prometheus Replica
   - Demo 3: Truy vấn dữ liệu lịch sử lưu trữ dài hạn từ MinIO qua Thanos
6. [Bảng So sánh & Khuyến nghị Vận hành](#6-bảng-so-sánh--khuyến-nghị-vận-hành)

---

## 1. ĐẶT VẤN ĐỀ VÀ THÁCH THỨC LƯU TRỮ CỦA PROMETHEUS

### 1.1. Bản chất Local-First TSDB của Prometheus
Mặc định, Prometheus lưu trữ toàn bộ dữ liệu time-series trên ổ cứng cục bộ (`/var/lib/prometheus/` hoặc `./data`). Dữ liệu được gom thành các khối (blocks) 2 giờ, kết hợp cơ chế Write-Ahead Log (WAL) trong bộ nhớ để bảo vệ dữ liệu chưa kịp ghi xuống đĩa.

Tuy nhiên, trong môi trường sản xuất thực tế, mô hình lưu trữ cục bộ đơn lẻ gặp 3 giới hạn nghiêm trọng:
1. **Nguy cơ Single Point of Failure (SPOF):** Nếu máy ảo `mon-server` gặp sự cố (sập nguồn, lỗi kernel, đầy ổ cứng), toàn bộ hoạt động giám sát và cảnh báo lập tức tê liệt.
2. **Áp lực dung lượng đĩa (Storage Exhaustion):** Với tần suất cào (scrape interval) 5 giây, lượng dữ liệu sinh ra mỗi ngày rất lớn. Nếu giữ dữ liệu từ vài tháng đến hàng năm, dung lượng đĩa sẽ nhanh chóng cạn kiệt, kéo theo nguy cơ treo hệ thống máy chủ.
3. **Hiệu năng truy vấn dài hạn suy giảm (Query Degradation):** Khi Grafana thực hiện các truy vấn trong khoảng thời gian lớn (ví dụ: so sánh hiệu năng hệ thống giữa 6 tháng trước và hiện tại), Prometheus phải nạp hàng nghìn block từ đĩa vào RAM, dễ gây nghẽn bộ nhớ và crash tiến trình với lỗi Out-Of-Memory (OOM).

### 1.2. Giải pháp mở rộng toàn diện
Để khắc phục các điểm yếu trên mà vẫn duy trì tính ổn định, hệ thống mở rộng triển khai theo 2 tầng:
* **Tầng High Availability (HA):** Chạy song song 2 Prometheus instances độc lập (Replicas) cào cùng một tập target. Alertmanager chịu trách nhiệm gom nhóm và loại trừ cảnh báo trùng lặp.
* **Tầng Long-Term Storage (LTS):** Tích hợp công nghệ nén và đẩy dữ liệu định kỳ lên kho lưu trữ đối tượng (Object Storage) chuẩn S3 (MinIO cục bộ hoặc AWS S3/GCS) thông qua **Thanos Sidecar**, cho phép lưu trữ vĩnh viễn với chi phí tối thiểu.

---

## 2. CHIẾN LƯỢC QUẢN LÝ LOCAL STORAGE & RETENTION

Trước khi nâng cấp lên cụm HA hoặc Object Storage, việc tối ưu hóa cấu hình lưu trữ cục bộ trên máy chủ `mon-server` là bước bắt buộc.

### 2.1. Phân vùng đĩa chuyên dụng cho TSDB
Không nên để dữ liệu Prometheus chung với phân vùng root (`/`). Hãy gắn một ổ đĩa ảo riêng biệt trong KVM/libvirt (ví dụ `/dev/vdb` dung lượng 20GB) và mount vào `/var/lib/prometheus`:

```bash
# Định dạng ext4 cho phân vùng đĩa chuyên dụng (thực hiện trên mon-server)
sudo mkfs.ext4 -L prometheus_data /dev/vdb

# Thêm vào /etc/fstab để tự động mount khi khởi động máy
echo "LABEL=prometheus_data /var/lib/prometheus ext4 defaults,noatime 0 2" | sudo tee -a /etc/fstab

# Tạo thư mục và gán quyền sở hữu
sudo mkdir -p /var/lib/prometheus
sudo mount -a
sudo chown -R prometheus:prometheus /var/lib/prometheus
```
> [!TIP]
> Tùy chọn mount `noatime` giúp giảm thiểu đáng kể số lượt ghi I/O lên ổ đĩa vì hệ điều hành sẽ không cập nhật access time mỗi khi Prometheus đọc các file chunk dữ liệu.

### 2.2. Tinh chỉnh Retention Time, Retention Size và WAL Compression
Chỉnh sửa file cấu hình dịch vụ `/etc/systemd/system/prometheus.service` hoặc `/etc/default/prometheus`:

```ini
[Service]
ExecStart=/usr/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus/ \
  --storage.tsdb.retention.time=15d \
  --storage.tsdb.retention.size=10GB \
  --storage.tsdb.wal-compression \
  --web.enable-lifecycle
```

**Ý nghĩa các tham số:**
* `--storage.tsdb.retention.time=15d`: Giới hạn tuổi thọ dữ liệu tối đa là 15 ngày. Các block cũ hơn 15 ngày sẽ tự động bị xóa trong chu kỳ dọn dẹp tiếp theo.
* `--storage.tsdb.retention.size=10GB`: Giới hạn dung lượng TSDB tối đa không vượt quá 10GB. Nếu đĩa sắp đầy trước 15 ngày, các block cũ nhất sẽ được giải phóng trước để bảo vệ máy chủ.
* `--storage.tsdb.wal-compression`: Kích hoạt thuật toán nén Snappy cho Write-Ahead Log, giúp tiết kiệm tới 30–50% dung lượng RAM và băng thông ghi đĩa của file WAL.

Sau khi sửa, nạp lại cấu hình:
```bash
sudo systemctl daemon-reload
sudo systemctl restart prometheus
```

---

## 3. MÔ HÌNH PROMETHEUS HIGH AVAILABILITY (HA REPLICAS)

### 3.1. Kiến trúc Dual-Instance Active-Active
Khác với các hệ quản trị cơ sở dữ liệu truyền thống dùng cơ chế Master-Slave hoặc Leader-Follower phức tạp, Prometheus đạt độ sẵn sàng cao bằng mô hình **Active-Active**:
* **Prometheus Replica 1 (Chính):** Cổng `9090`.
* **Prometheus Replica 2 (Dự phòng):** Cổng `9091` (hoặc đặt trên một máy ảo phụ `mon-server-2`).
* Cả 2 bản sao cùng cào dữ liệu từ máy mục tiêu `mon-target:9100` hoàn toàn độc lập.
* Cả 2 bản sao cùng liên tục đánh giá Alerting Rules và gửi thông báo cảnh báo sang Alertmanager.

```text
       ┌───────────────────────┐
       │ mon-target (VM2:9100) │
       └───────────┬───────────┘
                   │ Scrape song song
         ┌─────────┴─────────┐
         ▼                   ▼
┌─────────────────┐ ┌─────────────────┐
│  Prometheus A   │ │  Prometheus B   │
│  (Replica 1)    │ │  (Replica 2)    │
│  Port 9090      │ │  Port 9091      │
└────────┬────────┘ └────────┬────────┘
         │                   │ Gửi Alert đồng thời
         ▼                   ▼
┌─────────────────────────────────────┐
│            Alertmanager             │
│   (Khử trùng lặp qua Fingerprint)   │
└──────────────────┬──────────────────┘
                   ▼
         ┌───────────────────┐
         │  Telegram / Mail  │
         │ (Chỉ nhận 1 alert)│
         └───────────────────┘
```

### 3.2. Cơ chế Khử trùng lặp (Deduplication) của Alertmanager
Câu hỏi thường gặp: *Nếu 2 máy chủ Prometheus cùng gửi thông báo lỗi `HighCPUUsage`, quản trị viên có bị nhận 2 tin nhắn spam trên Telegram không?*

**Câu trả lời là KHÔNG.** Alertmanager giải quyết vấn đề này nhờ cơ chế:
1. **Label Fingerprinting:** Khi nhận cảnh báo từ bất kỳ nguồn nào, Alertmanager băm toàn bộ cặp label của cảnh báo (ví dụ `alertname="HighCPUUsage"`, `instance="192.168.122.38:9100"`) thành một chuỗi định danh duy nhất (fingerprint).
2. **Cửa sổ gom nhóm (`group_wait: 10s`):** Trong khoảng 10 giây chờ đợt gửi đầu tiên, nếu Alertmanager nhận được thêm cảnh báo có cùng fingerprint từ Prometheus Replica B, nó sẽ tự động loại bỏ bản ghi trùng lặp và chỉ gửi **duy nhất 1 thông báo**.
3. **Cấu hình External Labels:** Để phân biệt nguồn gốc của từng replica trong log gỡ lỗi mà không làm sai lệch fingerprint chính, gán nhãn `replica` trong cấu hình toàn cục:

```yaml
# Trên Prometheus Replica 1 (prometheus.yml)
global:
  scrape_interval: 5s
  evaluation_interval: 5s
  external_labels:
    cluster: 'kbt-monitoring'
    replica: 'prometheus-a'

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['localhost:9093']
```

```yaml
# Trên Prometheus Replica 2 (prometheus-b.yml)
global:
  scrape_interval: 5s
  evaluation_interval: 5s
  external_labels:
    cluster: 'kbt-monitoring'
    replica: 'prometheus-b'

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['localhost:9093']
```

### 3.3. Cấu hình triển khai Prometheus Replica 2 trên cùng VM (hoặc VM riêng)
Để triển khai Replica thứ 2 trên cùng `mon-server` phục vụ bài kiểm nghiệm Lab:

1. Tạo thư mục dữ liệu và copy cấu hình:
   ```bash
   sudo mkdir -p /var/lib/prometheus-replica /etc/prometheus-replica
   sudo cp /etc/prometheus/recording_rules.yml /etc/prometheus-replica/
   sudo cp /etc/prometheus/alert_rules.yml /etc/prometheus-replica/
   ```

2. Tạo file cấu hình `/etc/prometheus-replica/prometheus.yml`:
   ```yaml
   global:
     scrape_interval: 5s
     evaluation_interval: 5s
     external_labels:
       replica: 'replica-b'

   alerting:
     alertmanagers:
       - static_configs:
           - targets: ['localhost:9093']

   rule_files:
     - "/etc/prometheus-replica/recording_rules.yml"
     - "/etc/prometheus-replica/alert_rules.yml"

   scrape_configs:
     - job_name: "node_exporter"
       static_configs:
         - targets: ["192.168.122.38:9100"]
   ```

3. Tạo systemd unit file `/etc/systemd/system/prometheus-replica.service`:
   ```ini
   [Unit]
   Description=Prometheus Replica B (High Availability)
   After=network.target

   [Service]
   User=prometheus
   Group=prometheus
   ExecStart=/usr/bin/prometheus \
     --config.file=/etc/prometheus-replica/prometheus.yml \
     --storage.tsdb.path=/var/lib/prometheus-replica/ \
     --web.listen-address="0.0.0.0:9091" \
     --storage.tsdb.retention.time=15d
   Restart=always

   [Install]
   WantedBy=multi-user.target
   ```

4. Khởi chạy Replica B:
   ```bash
   sudo chown -R prometheus:prometheus /var/lib/prometheus-replica /etc/prometheus-replica
   sudo systemctl daemon-reload
   sudo systemctl enable --now prometheus-replica
   ```

---

## 4. KIẾN TRÚC LƯU TRỮ DÀI HẠN (LONG-TERM RETENTION) VỚI MINIO & THANOS

Khi cần lưu trữ dữ liệu chỉ số từ 6 tháng đến nhiều năm để phân tích xu hướng hoặc đáp ứng yêu cầu tuân thủ kiểm toán (compliance), giải pháp chuẩn công nghiệp là tích hợp **Thanos** kết hợp **MinIO**.

```text
┌─────────────────────────┐          ┌─────────────────────────┐
│      Prometheus A       │          │      Prometheus B       │
│   (Local TSDB: 15 ngày) │          │   (Local TSDB: 15 ngày) │
└────────────┬────────────┘          └────────────┬────────────┘
             │ Mỗi 2 giờ nạp block                │ Mỗi 2 giờ nạp block
             ▼                                    ▼
┌─────────────────────────┐          ┌─────────────────────────┐
│     Thanos Sidecar      │          │     Thanos Sidecar      │
└────────────┬────────────┘          └────────────┬────────────┘
             │                                    │
             └──────────────┬─────────────────────┘
                            │ Đẩy Block nén vào Object Storage
                            ▼
               ┌────────────────────────┐
               │      MinIO Server      │
               │  (Bucket: 'thanos-lts')│
               └────────────▲───────────┘
                            │
                            │ Đọc Block lịch sử
               ┌────────────┴───────────┐
               │      Thanos Store      │
               └────────────▲───────────┘
                            │
               ┌────────────┴───────────┐
               │     Thanos Querier     │ ◄─── Grafana Dashboard
               └────────────────────────┘      (Truy vấn xuyên suốt từ
                                                hiện tại đến 1 năm trước)
```

### 4.1. Cài đặt MinIO Server trên `mon-server`
MinIO là hệ thống lưu trữ đối tượng tương thích 100% với AWS S3 API, triển khai vô cùng gọn nhẹ trên Linux:

```bash
# Tải binary MinIO server cho kiến trúc AMD64
wget https://dl.min.io/server/minio/release/linux-amd64/minio
sudo chmod +x minio
sudo mv minio /usr/local/bin/

# Tạo người dùng hệ thống và thư mục chứa bucket
sudo useradd -r -s /bin/false minio-user
sudo mkdir -p /mnt/minio-storage
sudo chown -R minio-user:minio-user /mnt/minio-storage
```

Tạo file biến môi trường `/etc/default/minio`:
```bash
MINIO_VOLUMES="/mnt/minio-storage"
MINIO_OPTS="--address :9000 --console-address :9001"
MINIO_ROOT_USER="minioadmin"
MINIO_ROOT_PASSWORD="MinioStrongPassword2026!"
```

Tạo service file `/etc/systemd/system/minio.service`:
```ini
[Unit]
Description=MinIO Object Storage Server
After=network.target

[Service]
User=minio-user
Group=minio-user
EnvironmentFile=/etc/default/minio
ExecStart=/usr/local/bin/minio server $MINIO_OPTS $MINIO_VOLUMES
Restart=always

[Install]
WantedBy=multi-user.target
```

Kích hoạt dịch vụ:
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now minio
```
> [!NOTE]
> Giao diện web MinIO Console quản lý bucket truy cập tại: `http://<IP-mon-server>:9001` (user: `minioadmin`, pass: `MinioStrongPassword2026!`). Tạo bucket tên là `thanos-lts`.

### 4.2. Cấu hình Thanos Bucket Config cho Prometheus
Tạo file cấu hình kết nối Object Storage tại `/etc/prometheus/bucket.yml`:

```yaml
type: S3
config:
  bucket: "thanos-lts"
  endpoint: "127.0.0.1:9000"
  insecure: true
  access_key: "minioadmin"
  secret_key: "MinioStrongPassword2026!"
```

### 4.3. Cài đặt và kích hoạt Thanos Sidecar
Thanos Sidecar chạy song song với tiến trình Prometheus. Mỗi khi Prometheus đóng gói xong một block dữ liệu 2 giờ, Thanos Sidecar sẽ tự động mã hóa và tải block đó lên MinIO:

```bash
# Tải Thanos binary
wget https://github.com/thanos-io/thanos/releases/download/v0.34.0/thanos-0.34.0.linux-amd64.tar.gz
tar -zxvf thanos-0.34.0.linux-amd64.tar.gz
sudo mv thanos-0.34.0.linux-amd64/thanos /usr/local/bin/
```

Tạo systemd unit cho Thanos Sidecar (`/etc/systemd/system/thanos-sidecar.service`):
```ini
[Unit]
Description=Thanos Sidecar for Prometheus
After=prometheus.service

[Service]
User=prometheus
Group=prometheus
ExecStart=/usr/local/bin/thanos sidecar \
  --tsdb.path=/var/lib/prometheus \
  --prometheus.url=http://localhost:9090 \
  --objstore.config-file=/etc/prometheus/bucket.yml \
  --grpc-address=0.0.0.0:10901 \
  --http-address=0.0.0.0:10902
Restart=always

[Install]
WantedBy=multi-user.target
```

### 4.4. Cấu hình Thanos Querier làm Data Source tập trung cho Grafana
Thanos Querier cung cấp một endpoint tương thích hoàn toàn với chuẩn Prometheus API. Khi Grafana gửi truy vấn tới Thanos Querier (port `10903`), Thanos sẽ tự động gom kết quả từ Prometheus TSDB cục bộ (dữ liệu nóng gần nhất) và MinIO S3 (dữ liệu lạnh nhiều tháng trước) rồi trả về đồ thị liền mạch:

Tạo service `/etc/systemd/system/thanos-querier.service`:
```ini
[Unit]
Description=Thanos Querier Gateway
After=network.target

[Service]
ExecStart=/usr/local/bin/thanos query \
  --http-address=0.0.0.0:10903 \
  --endpoint=127.0.0.1:10901
Restart=always

[Install]
WantedBy=multi-user.target
```

Khởi chạy Thanos stack:
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now thanos-sidecar thanos-querier
```

Trong Grafana, thêm một Prometheus Data Source mới trỏ tới: `http://localhost:10903`.

---

## 5. KỊCH BẢN DEMO THỰC TẾ TỪNG BƯỚC

### Demo 1: Kiểm chứng WAL Compression và Cơ chế Compact dữ liệu TSDB
1. Chạy lệnh kiểm tra kích thước thư mục WAL trước và sau khi kích hoạt `--storage.tsdb.wal-compression`:
   ```bash
   ls -lh /var/lib/prometheus/wal/
   ```
2. Ép Prometheus thực hiện flush dữ liệu trong bộ nhớ xuống đĩa ngay lập tức qua API Lifecycle:
   ```bash
   curl -X POST http://localhost:9090/api/v1/admin/tsdb/snapshot
   ```
3. Quan sát các thư mục block 2 giờ (UUID) được tạo ra trong `/var/lib/prometheus/`.

### Demo 2: Kiểm thử tính sẵn sàng cao (Fault-Tolerance) khi tắt 1 Replica
1. Đảm bảo cả hai instance `Prometheus A` (:9090) và `Prometheus B` (:9091) đang thu thập metric từ `mon-target`.
2. Tạo tải CPU cao trên `mon-target` để kích hoạt trạng thái FIRING:
   ```bash
   stress-ng --cpu 1 --timeout 120s
   ```
3. Trên máy `mon-server`, chủ động tắt đột ngột Prometheus chính:
   ```bash
   sudo systemctl stop prometheus
   ```
4. **Kết quả quan sát kỳ vọng:**
   * Alertmanager UI (`http://<IP-mon-server>:9093`) vẫn giữ nguyên trạng thái FIRING của cảnh báo `HighCPUUsage` do nhận luồng metric liên tục từ Replica B (:9091).
   * Kỹ sư chỉ nhận duy nhất 1 thông báo trên Telegram, không hề bị gián đoạn hay trùng lặp tin nhắn.
   * Khi khởi động lại Prometheus A (`sudo systemctl start prometheus`), hệ thống tự động đồng bộ lại bình thường.

### Demo 3: Kiểm chứng Block nén đẩy lên MinIO Object Storage
1. Mở trình duyệt truy cập MinIO Console tại `http://<IP-mon-server>:9001`.
2. Đăng nhập và mở bucket `thanos-lts`.
3. Kiểm tra danh sách các block dữ liệu định dạng `.tar.gz` kèm file `meta.json` do Thanos Sidecar tự động nén và đẩy lên.
4. Mở Grafana (chọn Data Source Thanos Querier :10903), chọn khoảng thời gian **Last 7 days** hoặc **Last 30 days**. Đồ thị CPU/RAM hiển thị đầy đủ liên tục ngay cả khi local TSDB trên Prometheus đã xoá dữ liệu cũ.

---

## 6. BẢNG SO SÁNH & KHUYẾN NGHỊ VẬN HÀNH

| Tiêu chí | Prometheus Mặc định (Local) | Mô hình HA Replicas | HA kết hợp Thanos + MinIO |
| :--- | :---: | :---: | :---: |
| **Mức độ sẵn sàng (HA)** | Thấp (SPOF đơn điểm) | Rất cao (Active-Active) | Tối đa (Cả Server lẫn Storage) |
| **Thời gian lưu trữ tối đa** | 15 - 30 ngày | 15 - 30 ngày | Không giới hạn (Vĩnh viễn) |
| **Chi phí ổ cứng** | Đắt (Phụ thuộc đĩa SSD cục bộ) | Đắt gấp đôi (2 bản local) | Rất rẻ (Đẩy lên Object Storage) |
| **Khử trùng cảnh báo** | Không áp dụng | Alertmanager tự khử trùng | Alertmanager tự khử trùng |
| **Độ phức tạp vận hành** | Rất đơn giản | Đơn giản | Trung bình |
| **Khuyến nghị áp dụng** | Môi trường Dev / Học tập | Hệ thống Production vừa | Production lớn, yêu cầu lưu trữ lâu |
