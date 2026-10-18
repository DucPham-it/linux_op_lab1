# PROMETHEUS & GRAFANA MONITORING — LÝ THUYẾT ĐẦY ĐỦ

**Seminar Lab #10** · Hạ tầng: `mon-server` (1.5GB RAM: Prometheus + Grafana + Alertmanager) và `mon-target` (512MB RAM: Node Exporter + stress-ng)

---

## PHẦN 1. MÔ HÌNH PULL SO VỚI PUSH

### 1.1. Định nghĩa
- **Pull:** Prometheus chủ động gửi HTTP GET đến endpoint `/metrics` của từng target theo chu kỳ `scrape_interval`. Target chỉ "phơi" dữ liệu ra.
- **Push:** Agent trên máy được giám sát chủ động gửi dữ liệu đến server giám sát (ví dụ Graphite, StatsD, InfluxDB + Telegraf).

### 1.2. Áp dụng vào lab
- `prometheus-node-exporter` trên `mon-target` mở cổng `:9100` và chỉ **trả lời** khi bị hỏi.
- `mon-server` gọi `http://192.168.122.89:9100/metrics` mỗi 5 giây (khai báo trong `scrape_configs`).
- Bằng chứng trực quan: `curl http://localhost:9100/metrics` cho thấy đúng dữ liệu Prometheus sẽ lấy.

### 1.3. So sánh

| Tiêu chí | Pull (Prometheus) | Push |
|---|---|---|
| Ai kiểm soát tần suất | Server (tập trung) | Từng agent |
| Phát hiện target chết | Dễ: scrape thất bại → `up = 0` | Khó: không có dữ liệu có thể do chết hoặc do chưa có gì để gửi |
| Gỡ lỗi | Dùng `curl`/trình duyệt xem target | Phải xem log agent |
| Cấu hình agent | Agent không cần biết địa chỉ server | Mỗi agent khai báo địa chỉ server |
| Rủi ro quá tải server | Thấp (server tự điều tiết) | Cao (nhiều agent gửi dồn dập) |
| Qua NAT/Firewall | Khó: server phải kết nối được tới target | Dễ: agent chỉ cần ra ngoài |
| Job ngắn hạn (batch) | Khó: job kết thúc trước khi bị scrape | Phù hợp |

### 1.4. Điểm mấu chốt
Pull biến việc **"scrape thành công hay không"** thành tín hiệu sức khỏe: Prometheus tự sinh metric `up` cho mỗi target (`1` = thành công, `0` = thất bại). Đây là nền tảng của **Demo 4**.

Hạn chế của Pull (job ngắn hạn, target sau NAT) được bù bằng **Pushgateway**, chỉ nên dùng cho trường hợp đặc biệt.

---

## PHẦN 2. CÁC LOẠI METRIC VÀ HÀM `rate()`

### 2.1. Định dạng một mẫu dữ liệu
```
# HELP node_cpu_seconds_total Seconds the CPUs spent in each mode.
# TYPE node_cpu_seconds_total counter
node_cpu_seconds_total{cpu="0",mode="idle"} 18452.73
```
Gồm **tên metric** + **nhãn (label)** + **giá trị**. Dòng `# TYPE` cho biết loại metric.

### 2.2. Bốn loại metric

| Loại | Đặc điểm | Ví dụ trong lab |
|---|---|---|
| **Counter** | Chỉ tăng (hoặc reset về 0 khi tiến trình khởi động lại) | `node_cpu_seconds_total` |
| **Gauge** | Giá trị tức thời, tăng giảm tự do | `node_memory_MemAvailable_bytes`, `node_filesystem_free_bytes` |
| **Histogram** | Đếm số quan sát rơi vào từng bucket; sinh `_bucket{le="..."}`, `_sum`, `_count` | `http_request_duration_seconds` |
| **Summary** | Giống Histogram nhưng **tính sẵn quantile ở phía client** | Độ trễ với quantile 0.5 / 0.9 / 0.99 |

**Histogram vs Summary:** Histogram tính quantile ở phía server bằng `histogram_quantile()` và **gộp được** giữa nhiều instance. Summary chính xác hơn nhưng **không gộp được**. Node Exporter chủ yếu dùng Counter và Gauge, nên lab tập trung vào hai loại này.

### 2.3. Vì sao Counter luôn phải đi với `rate()`
1. `node_cpu_seconds_total{mode="idle"}` là **tổng số giây CPU đã rảnh kể từ khi boot**, chỉ tăng mãi. Giá trị `18452` không cho biết CPU đang bận hay rảnh.
2. Điều cần biết là **trong 1 phút vừa qua, mỗi giây CPU rảnh bao nhiêu giây** — đó là `rate(...[1m])`.
3. Máy rảnh hoàn toàn: idle tăng ~1 giây/giây → rate ≈ 1. Máy bận 100%: idle gần đứng yên → rate ≈ 0.
4. Công thức Demo 2:

```promql
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[1m])) * 100)
```
- `rate(...[1m])` → tỉ lệ thời gian rảnh của từng core
- `avg by (instance)` → trung bình các core của một máy
- `* 100` → đổi sang phần trăm
- `100 - ...` → đảo từ "rảnh" thành "bận"

5. **Ưu điểm thứ hai:** `rate()` tự xử lý **counter reset** (máy reboot, counter về 0 nhưng rate không âm).

**Lưu ý:** cửa sổ `[1m]` nên lớn hơn vài lần `scrape_interval` (ở đây 5s nên 1m là hợp lý).

### 2.4. Đối chiếu 3 truy vấn Demo 2

| Truy vấn | Loại metric | Cần `rate()`? |
|---|---|---|
| CPU % | Counter | **Bắt buộc** |
| RAM % | Gauge | Không (chỉ phép chia) |
| Disk % | Gauge | Không (lọc `mountpoint="/"`) |

---

## PHẦN 3. CÁCH PROMETHEUS LƯU TRỮ DỮ LIỆU (TSDB)

### 3.1. Mô hình dữ liệu
- Mỗi tổ hợp **tên metric + bộ nhãn** là một **time series** riêng. `{cpu="0",mode="idle"}` và `{cpu="0",mode="user"}` là hai series khác nhau.
- Mỗi **sample** = `(timestamp, giá trị float64)`.
- Vì vậy `[1m]` hoạt động: Prometheus lấy mọi sample của series trong 1 phút gần nhất.

### 3.2. Đường đi của một sample
```
Scrape ──► Head block (RAM) + WAL (đĩa) ──mỗi ~2 giờ──► Block bất biến trên đĩa ──► Compaction
```
1. **Head block (RAM):** dữ liệu mới nhất, truy vấn rất nhanh.
2. **WAL (Write-Ahead Log):** ghi song song ra đĩa; nếu Prometheus sập, khởi động lại sẽ **replay** mà không mất dữ liệu gần nhất.
3. **Block:** khoảng 2 giờ một lần, dữ liệu trong RAM được ghi thành thư mục block bất biến (`chunks/`, `index`, `meta.json`).
4. **Compaction:** gộp block nhỏ thành block lớn để truy vấn hiệu quả.
5. **Retention:** mặc định **15 ngày** (chỉnh bằng `--storage.tsdb.retention.time`).

### 3.3. Vì sao hiệu quả
- Nén rất tốt (timestamp delta-of-delta, giá trị nén kiểu XOR), trung bình khoảng 1–2 byte/sample.
- Giải thích vì sao VM 1.5GB RAM vẫn đủ chạy lab.

### 3.4. Giới hạn
- **Lưu cục bộ, không phân cụm:** một Prometheus = một nơi lưu. Muốn lưu dài hạn/HA dùng `remote_write` (Thanos, Mimir...).
- **High cardinality:** nhãn có quá nhiều giá trị (ví dụ `user_id`) làm số series bùng nổ, ngốn RAM.

### 3.5. Liên hệ lab
Dữ liệu nằm ở `/var/lib/prometheus` trên `mon-server` (gói Debian). **Grafana không lưu số liệu**; nó chỉ gửi truy vấn PromQL đến Prometheus rồi vẽ biểu đồ.

---

## PHẦN 4. VÒNG ĐỜI CẢNH BÁO (ALERT LIFECYCLE)

### 4.1. Hai thành phần, hai nhiệm vụ

| Thành phần | Nhiệm vụ |
|---|---|
| **Prometheus** | **Đánh giá** rule mỗi `evaluation_interval` (15s) và quyết định trạng thái alert |
| **Alertmanager** | **Xử lý thông báo**: gom nhóm, khử trùng lặp, silence, định tuyến (email, Slack...) |

### 4.2. Ba trạng thái
```
        expr đúng                 expr đúng liên tục ≥ for
Inactive ─────────► Pending ─────────────────────────────► Firing ──► gửi sang Alertmanager
    ▲                  │ expr sai                              │
    └──────────────────┴────────────── expr sai ───────────────┘
```
- **Inactive:** điều kiện chưa thỏa.
- **Pending:** điều kiện đã thỏa nhưng **chưa đủ thời gian** `for`.
- **Firing:** điều kiện thỏa liên tục suốt `for` → gửi alert sang Alertmanager.
- Chỉ cần điều kiện sai **một lần** khi đang Pending, alert về Inactive và đồng hồ `for` đếm lại từ đầu.

### 4.3. Vì sao cần Pending
Để **chống báo động giả**. CPU tăng vọt 5 giây do cron job không đáng đánh thức người trực. `for: 1m` buộc sự cố phải kéo dài mới được coi là thật.

### 4.4. Rule trong lab
```yaml
expr: 100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[1m])) * 100) > 80
for: 1m
```
Nơi **Phần 2, 3, 4 gặp nhau**: biểu thức dùng `rate()` của Counter (Phần 2), đánh giá trên dữ liệu đã lưu (Phần 3), rồi đi qua vòng đời Inactive → Pending → Firing (Phần 4).

### 4.5. Kịch bản thời gian chính xác cho Demo 3
Vì `rate()` trung bình trên cửa sổ 1 phút, CPU **không nhảy lên 100% ngay** trên biểu đồ:

| Thời điểm (từ lúc chạy `stress-ng`) | Sự kiện |
|---|---|
| 0s | Bắt đầu stress, CPU thực tế 100% |
| ~50s | Trung bình 1 phút vượt 80% → **Pending** |
| ~110s | Pending đủ 1 phút → **Firing** |
| Sau khi dừng stress | `rate` giảm dần dưới 80% → về **Inactive** |

> Khuyến nghị dùng `stress-ng --cpu 1 --timeout 300s` (120s quá sát, alert có thể chưa kịp Firing).

### 4.6. Khép vòng với Demo 4
Alert CPU chỉ bắt được "máy quá tải". Khi Node Exporter chết hoặc cả máy sập, `up = 0` nhờ mô hình **Pull** (Phần 1). Phải dùng thêm `ping` để phân biệt:

| Tình huống | `up{job="node_exporter"}` | `ping` | Kết luận | Xử lý |
|---|---|---|---|---|
| Mất Exporter | 0 | Thành công | Máy sống, dịch vụ chết | `systemctl start prometheus-node-exporter` |
| Sập Server | 0 | Thất bại | Cả hạ tầng chết | `virsh start mon-target` từ host |

Vòng khép kín: **Pull → Metric → TSDB → Alert → quay lại Pull (`up`).**

---

## TỔNG KẾT

> Prometheus **kéo (Pull)** các **metric** từ target theo chu kỳ, **lưu (TSDB)** thành chuỗi thời gian, cho phép **truy vấn (PromQL + `rate()`)** và liên tục **đánh giá (Alert Lifecycle)** để phát hiện bất thường. Grafana trực quan hóa, Alertmanager phân phối thông báo. Metric `up` sinh ra từ chính mô hình Pull giúp phân biệt "mất Exporter" và "sập Server".
