# CÁC CHUYÊN ĐỀ MỞ RỘNG CHO HỆ THỐNG GIÁM SÁT (SEMINAR EXTENSIONS)

Tài liệu này tổng hợp các hướng mở rộng nâng cao cho đồ án Linux Monitoring (Prometheus, Grafana, Alertmanager, Node Exporter). Mỗi chuyên đề được thiết kế đồng bộ chính xác với kiến trúc môi trường của repository (`mon-server` và `mon-target` trên nền tảng KVM/libvirt Debian 12).

---

### 🗂️ Nhóm 1: Tính sẵn sàng cao và Lưu trữ bền vững (HA & Long-term Storage)
> 📖 **Tài liệu hướng dẫn chi tiết:** [ha_longterm_storage.md](ha_longterm_storage.md)

Hệ thống cơ bản thường bị mất dữ liệu khi restart hoặc bị treo khi dung lượng đĩa cạn kiệt. Chuyên đề giải quyết:
* **Tối ưu hóa Local Storage:** Phân vùng ổ cứng chuyên dụng `/var/lib/prometheus` với tùy chọn mount `noatime`, tinh chỉnh giới hạn thời gian (`--storage.tsdb.retention.time=15d`), kích thước tối đa (`--storage.tsdb.retention.size=10GB`) và nén WAL (`--storage.tsdb.wal-compression`).
* **High Availability (HA):** Chạy song song 2 Prometheus Replicas (Active-Active) cào cùng một target. Alertmanager tự động khử trùng lặp cảnh báo (Deduplication) nhờ Fingerprint và cửa sổ gom nhóm.
* **Long-Term Storage (LTS):** Tích hợp MinIO (S3-compatible Object Storage) và Thanos Sidecar để tự động nén đẩy các block TSDB 2 giờ lên lưu trữ vĩnh viễn, kết hợp Thanos Querier phục vụ truy vấn đồ thị lịch sử nhiều tháng.

---

### 🔔 Nhóm 2: Hệ thống cảnh báo chuyên nghiệp (Production Alerting)
> 📖 **Tài liệu hướng dẫn chi tiết:** [production_alerting.md](production_alerting.md)

Hệ thống cơ bản chỉ gửi thông báo thô về kênh chat, dễ gây ra "bão cảnh báo" (Alert Fatigue). Chuyên đề giải quyết:
* **Kiến trúc Alerting 3 lớp:** Detection (Prometheus) ➔ Routing & Processing (Alertmanager) ➔ Notification (Telegram Bot HTML).
* **Gom cụm (Grouping) & Triệt tiêu (Inhibition):** Gom nhiều lỗi cùng máy chủ thành 1 thông báo; tự động tắt cảnh báo phụ (`HighCPUUsage`) khi cảnh báo gốc nghiêm trọng (`NodeExporterDown`) đã kích hoạt.
* **Chuẩn hóa công thức RAM:** Sử dụng `MemAvailable` thay vì `MemFree` để phản ánh đúng thực tế tài nguyên Linux.
* **Script ép tải thông minh:** [scripts/auto_stress.py](scripts/auto_stress.py) ép chính xác % RAM mong muốn trong 180s mà không bị Linux OOM-Killer bắn hạ.

---

### 🔒 Nhóm 3: Bảo mật và Quản lý quyền truy cập (Security & Auth)
> 📖 **Tài liệu hướng dẫn chi tiết:** [security_and_auth.md](security_and_auth.md)

Bảo vệ hệ thống giám sát khỏi các nguy cơ nghe lén (sniffing), rò rỉ topology máy chủ hoặc can thiệp phá hoại:
* **Mã hóa TLS/HTTPS toàn diện:** Cài đặt Nginx Reverse Proxy làm SSL Termination (cổng 443), tự động chuyển hướng HTTP (80) sang HTTPS, trang bị đầy đủ Security Headers (HSTS, X-Content-Type-Options, X-Frame-Options).
* **Xác thực Web Basic Auth & RBAC:** Kích hoạt xác thực mã hóa bcrypt trực tiếp trên Prometheus Web (`web.yml`) và Node Exporter; siết chặt phân quyền trong Grafana (Admin, Editor, Viewer), tắt anonymous và đăng ký tài khoản tự do.
* **Tường lửa & Bảo vệ TSDB Admin API:** Khóa cấm cờ `--web.enable-admin-api` ngăn chặn xóa sạch dữ liệu; thiết lập tường lửa UFW trên `mon-target` chỉ cho phép duy nhất IP `mon-server` cào cổng `9100`.

---

### 📊 Nhóm 4: Tối ưu dữ liệu và Giám sát chuyên sâu (Metrics Optimization & APM)

Tránh việc Prometheus bị "nghẽn" do có quá nhiều dữ liệu rác, đồng thời đi sâu vào tầng ứng dụng:
* **Quản lý Metric Cardinality:** Sử dụng tính năng Relabeling trong file cấu hình `prometheus.yml` để lọc, sửa hoặc loại bỏ bớt các label không cần thiết trước khi Prometheus lưu trữ, giúp tiết kiệm dung lượng RAM.
* **Application Performance Monitoring (APM):** Sử dụng các thư viện code (như Micrometer cho Java, Prom-client cho Node.js/Python) để tự phát hành các custom metrics riêng (ví dụ: số lượng đơn hàng/phút, số user online, response time endpoint HTTP).

---

### 🤖 Nhóm 5: Tự động hóa hạ tầng (GitOps & Monitoring as Code)
> 📖 **Tài liệu hướng dẫn chi tiết:** [gitops_monitoring_as_code.md](gitops_monitoring_as_code.md)

Chuyển đổi hoàn toàn phương thức quản trị từ thao tác thủ công bằng chuột (ClickOps) sang mã nguồn:
* **Grafana Provisioning:** Tự động nạp Prometheus Data Source (`datasources.yml`) và Dashboards (`dashboards.yml` + JSON) từ file mã nguồn khi dịch vụ khởi động, hỗ trợ Disaster Recovery tức thì khi mất database.
* **File-based Service Discovery (File SD):** Sử dụng `file_sd_configs` trỏ tới `/etc/prometheus/targets/*.json`, tự động nhận diện máy chủ mới trong vòng 5 giây mà không cần reload hoặc restart Prometheus.
* **One-Click Deployment Script:** Script tự động hóa kiểm tra cú pháp (`promtool check`, `amtool check`), đồng bộ file cấu hình và hot-reload stack an toàn không gián đoạn dịch vụ.
