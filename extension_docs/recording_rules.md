# RECORDING RULES TRONG PROMETHEUS

**Tài liệu hướng dẫn và demo — Đồ án Linux Monitoring**

**Đối tượng:** Nhóm 5 thành viên

**Hệ thống:** Prometheus, Grafana, Alertmanager, Node Exporter

**Target VM:** `192.168.122.38:9100`

---

## 1. Tổng quan

### 1.1. Recording Rules là gì?

Recording Rules là cơ chế cho phép Prometheus thực hiện các biểu thức PromQL theo chu kỳ và lưu kết quả thành những **time series mới** trong cơ sở dữ liệu TSDB.

Ví dụ, để tính CPU Usage thông thường, cần sử dụng:

```promql
100 * (
  1 - avg by(instance) (
    rate(node_cpu_seconds_total{mode="idle"}[1m])
  )
)
```

Khi sử dụng Recording Rules, Prometheus có thể tính toán biểu thức này trước và lưu kết quả với tên:

```promql
instance:cpu_usage:percent
```

Khi đó Grafana hoặc Alerting Rules chỉ cần sử dụng tên metric mới.

### 1.2. Ý tưởng triển khai

Trước khi sử dụng Recording Rules:

```text
Node Exporter
     |
     v
Prometheus TSDB
     |
     v
Grafana
     |
     v
Thực hiện PromQL phức tạp để tính CPU
```

Sau khi sử dụng Recording Rules:

```text
Node Exporter
     |
     v
Prometheus
     |
     v
Recording Rules
     |
     +--- CPU Usage %
     +--- RAM Usage %
     +--- Disk Usage %
     |
     v
Prometheus TSDB
     |
     +--- Grafana Dashboard
     |
     +--- Alerting Rules
               |
               v
          Alertmanager
               |
               v
            Telegram
```

**Điểm quan trọng:** Recording Rules không phải phần mềm mới. Đây là chức năng có sẵn của Prometheus.

---

## 2. Tác dụng thực tế

### 2.1. Giảm tính toán lặp lại

Giả sử hệ thống có 20 server, 10 Dashboard và nhiều người cùng truy cập.

Nếu mọi Dashboard đều sử dụng một biểu thức PromQL phức tạp, Prometheus có thể phải thực hiện lại các phép tính nhiều lần.

Recording Rules cho phép tính sẵn một biểu thức và lưu kết quả.

Nhờ đó, các Dashboard có thể truy vấn lại kết quả mà không cần tính lại toàn bộ biểu thức.

### 2.2. Chuẩn hóa cách tính

Nếu nhiều người viết các công thức CPU Usage khác nhau, kết quả Dashboard có thể không thống nhất.

Recording Rules giúp xác định một công thức chung.

Ví dụ:

- Dashboard CPU dùng `instance:cpu_usage:percent`.
- Alert CPU dùng `instance:cpu_usage:percent`.
- Các truy vấn thống kê cũng dùng metric này.

### 2.3. Dễ bảo trì

Thay vì sửa biểu thức CPU ở nhiều Dashboard, nhóm chỉ cần sửa Recording Rule tại Prometheus.

### 2.4. Lưu kết quả tính toán theo thời gian

Recording Rule ghi kết quả vào TSDB.

Ví dụ:

```text
10:00:00    CPU = 12%
10:00:15    CPU = 13%
10:00:30    CPU = 45%
10:00:45    CPU = 94%
10:01:00    CPU = 98%
```

Nhờ đó, Grafana có thể vẽ biểu đồ lịch sử CPU từ metric đã tính sẵn.

**Lưu ý:** Recording Rule không tự tạo dữ liệu lịch sử trước thời điểm nó bắt đầu chạy.

### 2.5. Hạn chế

Recording Rules cũng sử dụng tài nguyên của Prometheus để đánh giá biểu thức và lưu thêm dữ liệu.

Trong hệ thống đồ án chỉ có 2 VM, cải thiện hiệu năng có thể không đáng kể. Giá trị chính là khả năng tái sử dụng, chuẩn hóa và mở rộng.

---

## 3. Recording Rules và Alerting Rules khác nhau thế nào?

| Tiêu chí | Recording Rules | Alerting Rules |
|---|---|---|
| Chức năng | Tính toán và lưu metric | Phát hiện điều kiện cảnh báo |
| Khóa cấu hình | `record` | `alert` |
| Kết quả | Time series mới | Alert Pending/Firing |
| Lưu vào TSDB | Có | Không tạo metric kết quả theo cách Recording Rule |
| Dùng trong Grafana | Có | Chủ yếu phục vụ cảnh báo |
| Gửi Telegram | Không trực tiếp | Qua Prometheus và Alertmanager |

Ví dụ Recording Rule:

```yaml
- record: instance:cpu_usage:percent
  expr: ...
```

Ví dụ Alerting Rule:

```yaml
- alert: HighCPUUsage
  expr: instance:cpu_usage:percent > 80
  for: 1m
```

Recording Rule trả lời câu hỏi:

**CPU hiện đang sử dụng bao nhiêu phần trăm?**

Alerting Rule trả lời câu hỏi:

**CPU có vượt ngưỡng 80% liên tục trong 1 phút hay không?**

---

## 4. Môi trường triển khai

Đồ án sử dụng hai máy ảo Linux Server không có GUI.

### VM1 — Monitoring

Các thành phần:

- Prometheus — port `9090`
- Grafana — port `3000`
- Alertmanager — port `9093`
- Recording Rules
- Alerting Rules

Các file cấu hình:

```text
/etc/prometheus/
├── prometheus.yml
├── alert_rules.yml
└── recording_rules.yml
```

### VM2 — Target

IP:

```text
192.168.122.38
```

Các thành phần:

- Debian Linux
- Node Exporter — port `9100`
- stress-ng — dùng tạo CPU load

Trong phần mở rộng này, chúng ta **chỉ tính toán và theo dõi metrics của Target `192.168.122.38:9100`**, không cần giám sát CPU của VM Monitoring.

---

## 5. Thiết kế các Recording Rules

Nhóm triển khai 3 Recording Rules.

| Metric | Chức năng |
|---|---|
| `instance:cpu_usage:percent` | Phần trăm CPU sử dụng |
| `instance:memory_usage:percent` | Phần trăm RAM sử dụng |
| `instance:root_disk_usage:percent` | Phần trăm dung lượng Disk root không còn sẵn có |

### 5.1. CPU Usage

```promql
100 * (
  1 - avg by(instance) (
    rate(
      node_cpu_seconds_total{
        instance="192.168.122.38:9100",
        mode="idle"
      }[1m]
    )
  )
)
```

Giải thích:

- `node_cpu_seconds_total`: Counter lưu thời gian CPU tích lũy.
- `mode="idle"`: lựa chọn thời gian CPU rảnh.
- `rate(...[1m])`: tính tốc độ tăng trung bình của Counter trong 1 phút.
- `avg by(instance)`: trung bình trên các CPU logic của cùng server.
- `1 - idle`: tính tỷ lệ CPU bận.
- `100 *`: chuyển sang phần trăm.

### 5.2. RAM Usage

```promql
100 * (
  1 -
  node_memory_MemAvailable_bytes{
    instance="192.168.122.38:9100"
  }
  /
  node_memory_MemTotal_bytes{
    instance="192.168.122.38:9100"
  }
)
```

Công thức:

```text
RAM Usage (%) =
100 × (1 - Available RAM / Total RAM)
```

### 5.3. Disk Usage

```promql
100 * (
  1 -
  node_filesystem_avail_bytes{
    instance="192.168.122.38:9100",
    mountpoint="/"
  }
  /
  node_filesystem_size_bytes{
    instance="192.168.122.38:9100",
    mountpoint="/"
  }
)
```

Công thức sử dụng dung lượng filesystem còn sẵn có cho người dùng thông thường. Vì vậy kết quả có thể hơi khác tỷ lệ `used/total` trên filesystem có reserved blocks.

---

## 6. Hướng dẫn cấu hình từng bước

Toàn bộ các bước dưới đây thực hiện trên **VM Monitoring**.

### Bước 1 — Kiểm tra Prometheus

```bash
sudo systemctl status prometheus
```

Kiểm tra Target:

```bash
curl -sG http://localhost:9090/api/v1/query \
  --data-urlencode \
  'query=up{instance="192.168.122.38:9100"}'
```

Kết quả mong đợi: Target có giá trị `up = 1`.

### Bước 2 — Sao lưu cấu hình

```bash
sudo cp -a /etc/prometheus/prometheus.yml \
  /etc/prometheus/prometheus.yml.bak
```

```bash
sudo cp -a /etc/prometheus/alert_rules.yml \
  /etc/prometheus/alert_rules.yml.bak
```

### Bước 3 — Tạo Recording Rules

```bash
sudo nano /etc/prometheus/recording_rules.yml
```

Nội dung:

```yaml
groups:
  - name: linux_resource_recording
    interval: 15s
    rules:

      # CPU Usage
      - record: instance:cpu_usage:percent
        expr: |
          100 * (
            1 - avg by(instance) (
              rate(node_cpu_seconds_total{instance="192.168.122.38:9100",mode="idle"}[1m])
            )
          )

      # RAM Usage
      - record: instance:memory_usage:percent
        expr: |
          100 * (
            1 -
            node_memory_MemAvailable_bytes{instance="192.168.122.38:9100"}
            /
            node_memory_MemTotal_bytes{instance="192.168.122.38:9100"}
          )

      # Disk Usage
      - record: instance:root_disk_usage:percent
        expr: |
          100 * (
            1 -
            node_filesystem_avail_bytes{instance="192.168.122.38:9100",mountpoint="/"}
            /
            node_filesystem_size_bytes{instance="192.168.122.38:9100",mountpoint="/"}
          )
```

### Bước 4 — Khai báo file mới

Mở:

```bash
sudo nano /etc/prometheus/prometheus.yml
```

Trong `rule_files`, khai báo:

```yaml
rule_files:
  - "/etc/prometheus/alert_rules.yml"
  - "/etc/prometheus/recording_rules.yml"
```

Giữ nguyên những phần cấu hình Prometheus khác.

### Bước 5 — Kiểm tra cú pháp

```bash
promtool check rules \
  /etc/prometheus/recording_rules.yml
```

```bash
promtool check config \
  /etc/prometheus/prometheus.yml
```

Nhóm đã có kết quả kiểm tra thành công:

```text
SUCCESS: 2 rule files found

alert_rules.yml
SUCCESS: 3 rules found

recording_rules.yml
SUCCESS: 3 rules found
```

Điều này chứng minh hai file rule hợp lệ về cú pháp, nhưng chưa đủ để xác nhận Recording Rules đã được Prometheus thực thi.

### Bước 6 — Nạp cấu hình

```bash
sudo systemctl restart prometheus
```

Kiểm tra:

```bash
sudo systemctl status prometheus
```

Hoặc dùng SIGHUP để reload mà không restart:

```bash
sudo kill -HUP "$(systemctl show -p MainPID --value prometheus)"
```

### Bước 7 — Kiểm tra Recording Rules

```bash
curl -s \
  'http://localhost:9090/api/v1/rules?type=record' \
  | python3 -m json.tool
```

Kết quả cần có:

```text
linux_resource_recording
```

Gồm ba Recording Rules và không có lỗi đánh giá.

### Bước 8 — Kiểm tra dữ liệu được tạo

CPU:

```bash
curl -sG http://localhost:9090/api/v1/query \
  --data-urlencode \
  'query=instance:cpu_usage:percent' \
  | python3 -m json.tool
```

RAM:

```bash
curl -sG http://localhost:9090/api/v1/query \
  --data-urlencode \
  'query=instance:memory_usage:percent' \
  | python3 -m json.tool
```

Disk:

```bash
curl -sG http://localhost:9090/api/v1/query \
  --data-urlencode \
  'query=instance:root_disk_usage:percent' \
  | python3 -m json.tool
```

Kết quả hợp lệ phải có dữ liệu của:

```text
instance="192.168.122.38:9100"
```

Nếu `result` rỗng, kiểm tra lại raw metrics, trạng thái Target và thông tin đánh giá Rules.

---

## 7. Tích hợp Grafana

Mở Grafana Dashboard.

Tại các panel CPU, RAM, Disk, sửa PromQL như sau.

**CPU:**

```promql
instance:cpu_usage:percent{instance="192.168.122.38:9100"}
```

**RAM:**

```promql
instance:memory_usage:percent{instance="192.168.122.38:9100"}
```

**Disk:**

```promql
instance:root_disk_usage:percent{instance="192.168.122.38:9100"}
```

Chọn đơn vị hiển thị:

```text
Percent (0–100)
```

Nhấn **Apply**, sau đó **Save dashboard**.

Chúng ta lọc theo `instance` để Dashboard chỉ hiển thị Target VM, không hiển thị Node Exporter trên chính VM Monitoring.

---

## 8. Phương pháp Demo Recording Rules

### Demo 1 — So sánh truy vấn trước và sau

Truy vấn CPU gốc:

```promql
100 * (
  1 - avg by(instance) (
    rate(node_cpu_seconds_total{
      instance="192.168.122.38:9100",
      mode="idle"
    }[1m])
  )
)
```

Truy vấn metric đã được Recording Rule tạo ra:

```promql
instance:cpu_usage:percent{instance="192.168.122.38:9100"}
```

**Kết quả kỳ vọng:** Hai truy vấn trả về giá trị gần nhau.

Có thể có chênh lệch nhỏ do Recording Rule chỉ cập nhật theo chu kỳ 15 giây, còn truy vấn trực tiếp được tính ở thời điểm hiện tại.

Điều này chứng minh công thức CPU đã được Prometheus tính và lưu sẵn.

### Demo 2 — Tạo CPU Load

Trên Target VM:

```bash
nproc
```

Sau đó chạy:

```bash
stress-ng --cpu "$(nproc)" \
  --cpu-load 100 \
  --timeout 180s
```

Lệnh này tạo tải CPU trong 3 phút.

Trên Grafana, theo dõi:

```promql
instance:cpu_usage:percent{instance="192.168.122.38:9100"}
```

Diễn biến kỳ vọng:

```text
CPU thấp
   |
   v
Chạy stress-ng
   |
   v
CPU Usage tăng
   |
   v
Recording Rule cập nhật
   |
   v
Grafana hiển thị mức CPU cao
   |
   v
stress-ng kết thúc
   |
   v
CPU giảm
```

**Ý nghĩa:** Recording Rule không phải dữ liệu cố định. Nó tiếp tục tính toán khi raw metrics thay đổi.

### Demo 3 — Chứng minh dữ liệu đã được lưu

Sau khi `stress-ng` kết thúc:

1. Mở Grafana.
2. Chọn khoảng thời gian **Last 15 minutes**.
3. Hiển thị biểu đồ Time series của CPU.
4. Quan sát đoạn CPU tăng cao khi chạy stress-ng.
5. Quan sát đoạn CPU trở lại mức thấp sau khi kết thúc.

Điều này chứng minh Recording Rule đã tạo các mẫu dữ liệu theo thời gian trong TSDB.

### Demo 4 — Tích hợp với cảnh báo

Chỉ thực hiện sau khi Recording Rules đã chạy chính xác.

Trong `/etc/prometheus/alert_rules.yml`, có thể sửa biểu thức của cảnh báo CPU hiện tại thành:

```yaml
expr: instance:cpu_usage:percent{instance="192.168.122.38:9100"} > 80
for: 1m
```

Giữ nguyên các `labels`, `annotations` và các alert khác trong file.

Sau đó kiểm tra lại:

```bash
promtool check config /etc/prometheus/prometheus.yml
```

Nạp cấu hình mới.

Khi CPU duy trì trên 80%:

```text
Recording Rule
      |
      v
CPU Usage > 80%
      |
      v
Alert Pending
      |
      | Duy trì 1 phút
      v
Alert Firing
      |
      v
Alertmanager
      |
      v
Telegram
```

Lưu ý: `rate(...[1m])` là khoảng tính trung bình của Counter; `for: 1m` là thời gian điều kiện alert phải duy trì. Đây là hai tham số khác nhau.
