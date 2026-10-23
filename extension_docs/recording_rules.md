# MỞ RỘNG: CHUẨN HÓA TRUY VẤN VỚI RECORDING RULES
## Prometheus Recording Rules · Metric Tính sẵn · Dashboard và Alerting Rules

**Môi trường áp dụng:** KVM/libvirt · `mon-server` và `mon-target` (Debian 12) · Prometheus, Grafana, Alertmanager, Node Exporter.

**Mục tiêu:** Tập trung công thức tính tài nguyên, thống nhất dữ liệu giữa dashboard và alert, hạn chế tính toán lặp ở phía truy vấn.

---

## MỤC LỤC

1. [Đặt vấn đề và Hạn chế của Truy vấn PromQL Lặp](#1-đặt-vấn-đề-và-hạn-chế-của-truy-vấn-promql-lặp)
   - 1.1. Hạn chế khi Khai báo Công thức tại Nhiều Thành phần
   - 1.2. Phương pháp Mở rộng được Lựa chọn
2. [Cơ chế Tính toán Định kỳ và Lưu trữ Metric trong Prometheus](#2-cơ-chế-tính-toán-định-kỳ-và-lưu-trữ-metric-trong-prometheus)
   - 2.1. Luồng Thu thập, Tính toán và Sử dụng Dữ liệu
   - 2.2. Phân biệt Recording Rules và Alerting Rules
   - 2.3. Phạm vi Triển khai và Điều kiện Áp dụng
3. [Thiết kế Nhóm Recording Rules cho Tài nguyên Hệ thống](#3-thiết-kế-nhóm-recording-rules-cho-tài-nguyên-hệ-thống)
   - 3.1. Nhóm Rule và Các Metric Tài nguyên
   - 3.2. Cấu hình Biểu thức và Phạm vi Nhãn
4. [Triển khai Cấu hình và Tích hợp Grafana, Alerting Rules](#4-triển-khai-cấu-hình-và-tích-hợp-grafana-alerting-rules)
   - 4.1. Sao lưu và Đồng bộ File Recording Rules
   - 4.2. Khai báo Danh sách File Rule trong Prometheus
   - 4.3. Kiểm tra Cú pháp và Nạp lại Cấu hình
   - 4.4. Tái sử dụng Metric trong Dashboard và Cảnh báo
5. [Kịch bản Demo Thực tế Từng bước](#5-kịch-bản-demo-thực-tế-từng-bước)
   - Demo 1: Kiểm chứng Trạng thái Rule và Dữ liệu Đầu ra
   - Demo 2: Đối chiếu Công thức và Quan sát CPU khi Tạo tải
   - Demo 3: Kiểm chứng Cảnh báo Sử dụng Metric Tính sẵn
   - 5.1. Tổng hợp Tiêu chí Đánh giá và Minh chứng
6. [Bảng So sánh và Khuyến nghị Vận hành](#6-bảng-so-sánh-và-khuyến-nghị-vận-hành)
   - 6.1. So sánh Trước và Sau khi Áp dụng Recording Rules
   - 6.2. Khuyến nghị Vận hành và Giới hạn Áp dụng
   - 6.3. Kết luận

---

## 1. ĐẶT VẤN ĐỀ VÀ HẠN CHẾ CỦA TRUY VẤN PROMQL LẶP

### 1.1. Hạn chế khi Khai báo Công thức tại Nhiều Thành phần

Hệ thống giám sát thu thập dữ liệu tài nguyên từ Node Exporter, hiển thị trên Grafana và đánh giá điều kiện cảnh báo bằng Prometheus. Khi dashboard và alert cùng khai báo biểu thức tính CPU, RAM hoặc dung lượng đĩa, hệ thống phát sinh các hạn chế:

- **Tính toán lặp:** Các truy vấn có thể thực hiện lại cùng phép tính trên dữ liệu gốc, đặc biệt khi nhiều panel hoặc người dùng truy cập đồng thời.
- **Không nhất quán:** Công thức tại dashboard và alert có thể khác nhau, dẫn đến chênh lệch giữa giá trị hiển thị và điều kiện cảnh báo.
- **Khó bảo trì:** Thay đổi phương pháp tính đòi hỏi cập nhật nhiều vị trí, làm tăng khả năng bỏ sót cấu hình.

Với mô hình hai VM, chưa có cơ sở xác định truy vấn là điểm nghẽn hiệu năng. Tính nhất quán và khả năng bảo trì là mục tiêu ưu tiên; mức tăng tốc phải được đánh giá bằng phép đo tương ứng.

### 1.2. Phương pháp giải quyết với Recording Rules

Với Recording Rules, chức năng có sẵn của Prometheus, để định kỳ tính toán biểu thức PromQL và lưu kết quả thành metric dùng chung. Giải pháp không bổ sung dịch vụ, tận dụng TSDB hiện có và phù hợp với kiến trúc giám sát đang triển khai.

Việc chỉ rút gọn truy vấn tại từng panel không tập trung được công thức giữa dashboard và alert. Recording Rules giải quyết yêu cầu này bằng cách đưa công thức về một nơi quản lý, trong khi các thành phần sử dụng cùng tên metric đầu ra.

---

## 2. CƠ CHẾ TÍNH TOÁN ĐỊNH KỲ VÀ LƯU TRỮ METRIC TRONG PROMETHEUS

### 2.1. Luồng Thu thập, Tính toán và Sử dụng Dữ liệu

Recording Rules đánh giá các biểu thức theo chu kỳ và ghi kết quả vào TSDB dưới dạng chuỗi thời gian mới. Dashboard và alert truy vấn metric đã tính sẵn thay vì khai báo lại biểu thức gốc.

```text
Node Exporter → Prometheus scrape → Metric gốc trong TSDB
                                         ↓
                              Recording Rules mỗi 5 giây
                                         ↓
                              Metric tính sẵn trong TSDB
                                  ↙              ↘
                              Grafana         Alerting Rules
                                                   ↓
                                              Alertmanager
                                                   ↓
                                                Telegram
```

Các mẫu đầu ra tiếp tục được tạo khi dữ liệu gốc thay đổi. Việc lưu kết quả hỗ trợ truy vấn lịch sử kể từ khi rule bắt đầu hoạt động; không tự sinh dữ liệu cho thời gian trước đó.

### 2.2. Phân biệt Recording Rules và Alerting Rules

| Tiêu chí | Recording Rules | Alerting Rules |
|---|---|---|
| Vai trò | Tính toán và lưu metric đầu ra | Đánh giá điều kiện cảnh báo |
| Khóa khai báo | `record`, `expr` | `alert`, `expr`, có thể có `for` |
| Kết quả chính | Chuỗi thời gian mới trong TSDB | Trạng thái cảnh báo; Prometheus cũng xuất các series trạng thái `ALERTS` |
| Thành phần sử dụng | Dashboard, alert và các truy vấn khác | Alertmanager để xử lý, chuyển tiếp thông báo |

Recording Rule không trực tiếp gửi Telegram. Alerting Rule có thể dùng metric đầu ra của Recording Rule để đánh giá ngưỡng; Alertmanager tiếp nhận và định tuyến thông báo.

### 2.3. Phạm vi Triển khai và Điều kiện Áp dụng

| Thành phần | Vai trò |
|---|---|
| VM Monitoring `mon-server` | Prometheus cổng `9090`, Grafana cổng `3000`, Alertmanager cổng `9093` |
| VM Target `mon-target` | Node Exporter tại `192.168.122.38:9100`; `stress-ng` phục vụ kiểm thử |
| `configs/prometheus/recording_rules.yml` | Nguồn cấu hình năm Recording Rules |
| `configs/prometheus/prometheus.yml` | Chu kỳ scrape, đánh giá và danh sách file rule |
| `configs/prometheus/alert_rules.yml` | Cảnh báo sử dụng metric tính sẵn |

Các rule không cố định IP target; nhãn `instance` được dùng ở truy vấn dashboard và kiểm chứng để chọn máy cần theo dõi. Cấu hình giả định mỗi Node Exporter chỉ được scrape một lần. Nếu cùng target được thu thập qua nhiều job, cần rà soát nhãn và phép tổng hợp để tránh gộp các nguồn trùng.

---

## 3. THIẾT KẾ NHÓM RECORDING RULES CHO TÀI NGUYÊN HỆ THỐNG

### 3.1. Nhóm Rule và Các Metric Tài nguyên

Nhóm `linux_host_recording_rules` sử dụng chu kỳ `5s`, thống nhất với cấu hình hiện có. Năm metric đầu ra gồm:

| Metric | Nội dung tính toán | Đơn vị |
|---|---|---|
| `instance:cpu_usage:percent` | CPU bận từ tốc độ tăng thời gian idle trong 1 phút, trung bình các lõi theo instance | % |
| `instance:memory_usage:percent` | RAM sử dụng theo `MemTotal - MemAvailable` | % |
| `instance:root_disk_usage:percent` | Dung lượng filesystem gốc sử dụng theo `size - free` | % |
| `instance:network_receive_bytes:rate1m` | Tốc độ nhận của từng giao diện được chọn trong cửa sổ 1 phút | byte/s |
| `instance:network_transmit_bytes:rate1m` | Tốc độ gửi của từng giao diện được chọn trong cửa sổ 1 phút | byte/s |

Công thức đĩa sử dụng `node_filesystem_free_bytes`, không phải `node_filesystem_avail_bytes`. `free_bytes` bao gồm dung lượng còn trống dành riêng cho hệ thống, còn `avail_bytes` biểu diễn phần sẵn có cho người dùng thông thường. Thay thế hai đại lượng làm thay đổi ý nghĩa metric và có thể ảnh hưởng điều kiện cảnh báo.

### 3.2. Cấu hình Biểu thức và Phạm vi Nhãn

Nội dung file `configs/prometheus/recording_rules.yml`:

```yaml
groups:
  - name: linux_host_recording_rules
    interval: 5s
    rules:
      - record: instance:cpu_usage:percent
        expr: 100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[1m])) * 100)

      - record: instance:memory_usage:percent
        expr: ((node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes) * 100

      - record: instance:root_disk_usage:percent
        expr: ((node_filesystem_size_bytes{mountpoint="/",fstype!="rootfs"} - node_filesystem_free_bytes{mountpoint="/",fstype!="rootfs"}) / node_filesystem_size_bytes{mountpoint="/",fstype!="rootfs"}) * 100

      - record: instance:network_receive_bytes:rate1m
        expr: rate(node_network_receive_bytes_total{device!~"lo|docker.*|veth.*"}[1m])

      - record: instance:network_transmit_bytes:rate1m
        expr: rate(node_network_transmit_bytes_total{device!~"lo|docker.*|veth.*"}[1m])
```

`record` xác định tên metric đầu ra; `expr` là công thức đánh giá. CPU sử dụng `rate` trên counter thời gian idle, lấy trung bình các lõi theo `instance`, sau đó chuyển tỷ lệ CPU bận thành phần trăm. RAM sử dụng `MemAvailable` để xét phần bộ nhớ còn có thể cấp phát. Hai rule mạng loại trừ các giao diện khớp biểu thức `lo|docker.*|veth.*`.

CPU được tổng hợp theo `instance`; RAM, đĩa và mạng giữ các nhãn từ biểu thức đầu vào, bao gồm nhãn thiết bị khi có. Tiền tố `instance:` trong tên metric không tự loại bỏ các nhãn khác.

| Tham số | Ý nghĩa |
|---|---|
| `scrape_interval: 5s` | Chu kỳ lấy dữ liệu từ exporter |
| `interval: 5s` | Chu kỳ đánh giá nhóm Recording Rules |
| `[1m]` trong `rate` | Cửa sổ dữ liệu tính tốc độ tăng counter |
| `for: 1m` trong alert CPU | Thời gian điều kiện vượt ngưỡng phải duy trì |

---

## 4. TRIỂN KHAI CẤU HÌNH VÀ TÍCH HỢP GRAFANA, ALERTING RULES

### 4.1. Sao lưu và Đồng bộ File Recording Rules

Các thao tác triển khai thực hiện trên VM Monitoring, từ thư mục gốc của kho mã. Điều kiện tiên quyết là Prometheus đang chạy, có `promtool` và quyền quản trị cấu hình. Trước khi thay đổi, cần sao lưu file hiện có; ví dụ với cấu hình chính:

```bash
sudo cp -a /etc/prometheus/prometheus.yml \
  "/etc/prometheus/prometheus.yml.$(date +%Y%m%d-%H%M%S).bak"
```

Nếu file Recording Rules đã tồn tại, thực hiện sao lưu tương tự trước khi đồng bộ. Các rule riêng của môi trường cần được đối chiếu và giữ lại; không ghi đè bằng file mẫu khi chưa rà soát.

Kiểm tra cú pháp file nguồn. Chỉ đồng bộ khi kiểm tra thành công:

```bash
promtool check rules configs/prometheus/recording_rules.yml
sudo cp configs/prometheus/recording_rules.yml /etc/prometheus/recording_rules.yml
```

### 4.2. Khai báo Danh sách File Rule trong Prometheus

Trong `/etc/prometheus/prometheus.yml`, bổ sung đường dẫn vào mục `rule_files` hiện có, giữ nguyên các file rule khác:

```yaml
rule_files:
  - "/etc/prometheus/recording_rules.yml"
  - "/etc/prometheus/alert_rules.yml"
```

### 4.3. Kiểm tra Cú pháp và Nạp lại Cấu hình

Kiểm tra cấu hình tổng thể. Chỉ gửi SIGHUP sau khi kiểm tra thành công và xác nhận dịch vụ đang chạy với PID hợp lệ:

```bash
promtool check config /etc/prometheus/prometheus.yml
sudo systemctl status prometheus
sudo kill -HUP "$(systemctl show -p MainPID --value prometheus)"
```

SIGHUP yêu cầu Prometheus nạp lại cấu hình mà không khởi động lại tiến trình, không cần bật HTTP lifecycle API. Dịch vụ đang chạy không đủ chứng minh rule mới đã nạp thành công; trạng thái rule và dữ liệu đầu ra phải được kiểm tra riêng. Nếu cấu hình mới không hợp lệ, cần đối chiếu bản sao lưu và kiểm tra lại trước khi nạp.

### 4.4. Tái sử dụng Metric trong Dashboard và Cảnh báo

Các panel CPU, RAM và đĩa trong Grafana sử dụng truy vấn tương ứng, đơn vị `Percent (0–100)`:

```promql
instance:cpu_usage:percent{instance="192.168.122.38:9100"}
instance:memory_usage:percent{instance="192.168.122.38:9100"}
instance:root_disk_usage:percent{instance="192.168.122.38:9100"}
```

Nhãn `instance` giới hạn kết quả ở VM Target. Trong cấu hình provisioning, biến dashboard có thể thay thế giá trị IP cố định. Sau khi thay đổi, cấu hình truy vấn cần được lưu theo phương thức quản lý dashboard đang sử dụng.

Các alert CPU, RAM và đĩa trong `configs/prometheus/alert_rules.yml` đã tham chiếu metric tính sẵn. Trích đoạn điều kiện CPU cao:

```yaml
- alert: HighCPUUsage
  expr: instance:cpu_usage:percent > 80
  for: 1m
```

Đây là trích đoạn minh họa, không thay thế toàn bộ file alert. Các nhãn định tuyến, mức độ nghiêm trọng và annotations phải được giữ nguyên. Điều kiện vượt 80% duy trì một phút mới đủ để alert CPU chuyển sang Firing.

---

## 5. KỊCH BẢN DEMO THỰC TẾ TỪNG BƯỚC

Các kịch bản thực hiện sau khi hoàn tất triển khai. Endpoint minh họa là API nội bộ tại `localhost:9090`; môi trường bật Basic Auth hoặc reverse proxy cần sử dụng địa chỉ và thông tin xác thực phù hợp. Mật khẩu không được ghi vào tài liệu hoặc kho mã.

### Demo 1: Kiểm chứng Trạng thái Rule và Dữ liệu Đầu ra

**Mục tiêu:** Xác nhận target có dữ liệu, Prometheus đã nạp đủ rule và metric tính sẵn được tạo cho đúng máy.

1. Trên VM Monitoring, truy vấn trạng thái thu thập của VM Target:

```bash
curl -sG http://localhost:9090/api/v1/query \
  --data-urlencode 'query=up{instance="192.168.122.38:9100"}'
```

2. Kiểm tra nhóm Recording Rules qua API:

```bash
curl -s 'http://localhost:9090/api/v1/rules?type=record' \
  | python3 -m json.tool
```

3. Truy vấn metric CPU tính sẵn; kiểm tra tương tự với metric RAM và đĩa:

```bash
curl -sG http://localhost:9090/api/v1/query \
  --data-urlencode 'query=instance:cpu_usage:percent{instance="192.168.122.38:9100"}' \
  | python3 -m json.tool
```

**Kết quả kỳ vọng:** Target có `up = 1`; nhóm `linux_host_recording_rules` chứa năm rule có `health: ok`, không có lỗi đánh giá; các truy vấn CPU, RAM và đĩa trả dữ liệu đúng instance.


### Demo 2: Đối chiếu Công thức và Quan sát CPU khi Tạo tải

**Mục tiêu:** Kiểm chứng tính nhất quán của phép tính và khả năng lưu diễn biến CPU dưới dạng metric tính sẵn.

1. Trong giao diện truy vấn Prometheus, đánh giá biểu thức CPU gốc:

```promql
100 - (avg by (instance) (
  rate(node_cpu_seconds_total{instance="192.168.122.38:9100",mode="idle"}[1m])
) * 100)
```

2. Đối chiếu với `instance:cpu_usage:percent{instance="192.168.122.38:9100"}` tại cùng timestamp đánh giá của Recording Rule. Truy vấn ở thời điểm hiện tại có thể chênh lệch vì metric tính sẵn chỉ cập nhật mỗi 5 giây.
3. Trên VM Target thử nghiệm, tạo tải CPU trong 180 giây:

```bash
stress-ng --cpu "$(nproc)" --cpu-load 100 --timeout 180s
```

4. Quan sát panel CPU trong Grafana ở khoảng thời gian 15 phút, bao gồm giai đoạn trước, trong và sau khi tạo tải.

**Kết quả kỳ vọng:** Hai cách tính CPU khớp tại cùng timestamp đánh giá; CPU tăng khi có tải, giảm sau khi kết thúc; các mẫu của giai đoạn có tải vẫn xuất hiện trong lịch sử.


### Demo 3: Kiểm chứng Cảnh báo Sử dụng Metric Tính sẵn

**Mục tiêu:** Xác nhận alert tái sử dụng cùng metric với dashboard thay vì khai báo lại công thức CPU.

1. Kiểm tra `HighCPUUsage` trong file alert sử dụng `instance:cpu_usage:percent > 80` với `for: 1m`.
2. Trong kịch bản tạo tải CPU, theo dõi giá trị metric và trạng thái alert trên Prometheus.
3. Nếu metric vượt 80% liên tục một phút, kiểm tra alert chuyển từ Pending sang Firing và được Alertmanager tiếp nhận.
4. Kiểm tra thông báo tại kênh Telegram nếu route, receiver và kết nối đã được cấu hình; kiểm tra cả trạng thái silence và inhibition khi không có thông báo.

**Kết quả kỳ vọng:** Dashboard và alert sử dụng cùng nguồn metric; alert chuyển Firing khi đủ điều kiện. Việc nhận Telegram phụ thuộc cấu hình Alertmanager và dịch vụ nhận thông báo, không do Recording Rules trực tiếp bảo đảm.


### 5.1. Tổng hợp Tiêu chí Đánh giá và Minh chứng

| Nội dung | Tiêu chí đạt | Minh chứng |
|---|---|---|
| Cấu hình | Kiểm tra rules và config không báo lỗi | Đầu ra `promtool` |
| Thực thi | Đúng nhóm, đủ năm rule, không có lỗi đánh giá | Phản hồi API Rules |
| Dữ liệu | CPU, RAM và đĩa có giá trị cho đúng target | Kết quả truy vấn và timestamp |
| Nhất quán | Metric CPU khớp biểu thức gốc tại cùng timestamp đánh giá | Giá trị đối chiếu |
| Biến thiên theo tải | CPU tăng khi có tải, giảm sau khi kết thúc | Biểu đồ kèm thời gian tạo tải |
| Tái sử dụng | Dashboard và alert tham chiếu metric tính sẵn | Cấu hình panel và alert |
| Hiệu năng | Hai cách truy vấn được đo trong điều kiện tương đương | Thời gian phản hồi, tải Prometheus và điều kiện đo |

Đánh giá hiệu năng cần sử dụng cùng target, khoảng thời gian, bước lấy mẫu và số lần lặp; đồng thời ghi nhận tải nền và ảnh hưởng bộ nhớ đệm. Tải Prometheus cần được quan sát cùng chi phí đánh giá rule, không chỉ thời gian phản hồi một truy vấn đơn lẻ.

Các tiêu chí và diễn biến trên là kế hoạch kiểm chứng, không phải kết quả thực nghiệm. Chưa có dữ liệu đo kèm theo để công bố mức tăng tốc, tỷ lệ giảm CPU hoặc I/O.

---

## 6. BẢNG SO SÁNH VÀ KHUYẾN NGHỊ VẬN HÀNH

### 6.1. So sánh Trước và Sau khi Áp dụng Recording Rules

| Tiêu chí | Truy vấn Trực tiếp Metric Gốc | Sử dụng Recording Rules |
|---|---|---|
| Quản lý công thức | Khai báo tại từng dashboard và alert | Tập trung biểu thức trong file rule |
| Nhất quán dữ liệu | Dễ lệch công thức giữa các thành phần | Dùng chung metric khi dashboard và alert đã chuyển đổi |
| Tính toán khi truy vấn | Đánh giá lại biểu thức gốc | Đọc metric được tính định kỳ |
| Lưu trữ | Lưu metric gốc | Lưu thêm chuỗi thời gian đầu ra |
| Thời điểm cập nhật | Tính theo thời điểm truy vấn | Phụ thuộc chu kỳ đánh giá rule |
| Lịch sử chỉ số tổng hợp | Tính từ dữ liệu gốc còn được lưu | Có mẫu từ thời điểm kích hoạt rule; không tự tạo lịch sử trước đó |

### 6.2. Khuyến nghị Vận hành và Giới hạn Áp dụng

- Ưu tiên chuẩn hóa các biểu thức được dùng lặp lại; giữ cấu hình rule trong kho mã, kiểm tra cú pháp và đối chiếu dữ liệu trước khi cập nhật dashboard hoặc alert.
- Rule tiêu thụ CPU khi đánh giá và tạo thêm dữ liệu lưu trữ; không bảo đảm giảm tổng tài nguyên ở mọi quy mô.
- Metric đầu ra chỉ cập nhật theo chu kỳ. Thay đổi công thức không tính lại các mẫu cũ và không tự tạo lịch sử trước khi kích hoạt.
- Các nhãn đầu vào vẫn cần được quản lý. Thêm Recording Rules không thay thế việc kiểm soát cardinality hoặc kiểm tra nguồn scrape trùng.
- Giải pháp không thay thế HA, lưu trữ dài hạn hoặc Alertmanager. Tính sẵn dữ liệu không giải quyết sự cố mất target hoặc gián đoạn máy chủ giám sát.

### 6.3. Kết luận

Recording Rules được lựa chọn để chuẩn hóa công thức tài nguyên, tạo metric dùng chung cho dashboard và alert, đồng thời tách logic tính toán khỏi thành phần hiển thị. Cấu hình năm rule và quy trình kiểm chứng thống nhất với hệ thống hiện có. Với mô hình hai VM, giá trị ưu tiên là tính nhất quán và khả năng bảo trì; kết luận định lượng về hiệu năng chỉ được bổ sung sau khi có minh chứng thực nghiệm.
