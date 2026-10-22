# MỞ RỘNG NHÓM 5: TỰ ĐỘNG HÓA HẠ TẦNG (GITOPS & MONITORING AS CODE)
## Declarative Provisioning, File-based Service Discovery & CI/CD Sync
**Môi trường áp dụng:** KVM/libvirt · `mon-server` (Debian 12) & `mon-target` (Debian 12) · Lab #10

---

## MỤC LỤC
1. [Đặt vấn đề: Thảm họa "ClickOps" và Triết lý Monitoring-as-Code](#1-đặt-vấn-đề-thảm-họa-clickops-và-triết-lý-monitoring-as-code)
2. [Grafana Provisioning: Quản lý Nguồn dữ liệu & Dashboard bằng Mã nguồn](#2-grafana-provisioning-quản-lý-nguồn-dữ-liệu--dashboard-bằng-mã-nguồn)
   - 2.1. Cấu trúc thư mục Provisioning chuẩn của Grafana
   - 2.2. Khai báo Tự động Nguồn dữ liệu (Datasource as Code)
   - 2.3. Khai báo Tự động Dashboard (Dashboard as Code qua JSON Provider)
   - 2.4. Trích xuất (Export) và Chuẩn hóa Dashboard JSON từ giao diện
3. [Prometheus File-based Service Discovery (File SD)](#3-prometheus-file-based-service-discovery-file-sd)
   - 3.1. Hạn chế của cấu hình tĩnh `static_configs`
   - 3.2. Cấu hình Dynamic Scrape qua `file_sd_configs`
   - 3.3. Tự động thêm bớt máy chủ giám sát mà không cần Reload dịch vụ
4. [Xây dựng Pipeline Tự động hóa Đồng bộ (GitOps Pipeline)](#4-xây-dựng-pipeline-tự-động-hóa-đồng-bộ-gitops-pipeline)
   - 4.1. Cấu trúc thư mục Git chuẩn mực cho Monitoring-as-Code
   - 4.2. Kịch bản Tự động Triển khai & Kiểm thử Cú pháp (`deploy_stack.sh`)
   - 4.3. Tự động hóa kiểm soát phiên bản qua Git Hook / Cron Sync
5. [Kịch bản Demo Thực tế Từng bước](#5-kịch-bản-demo-thực-tế-từng-bước)
   - Demo 1: Khắc phục Thảm họa (Disaster Recovery) - Tái sinh Grafana từ con số 0
   - Demo 2: Cấp phát Động mục tiêu giám sát (Dynamic Target Onboarding) qua File SD
   - Demo 3: Thực thi Triển khai Tự động bằng Script One-Click
6. [Bảng So sánh Phương thức Vận hành ClickOps vs GitOps](#6-bảng-so-sánh-phương-thức-vận-hành-clickops-vs-gitops)

---

## 1. ĐẶT VẤN ĐỀ: THẢM HỌA "CLICKOPS" VÀ TRIẾT LÝ MONITORING-AS-CODE

### 1.1. Thảm họa vận hành thủ công (ClickOps)
Trong quá trình triển khai ban đầu, người quản trị thường cấu hình hệ thống bằng cách:
* Đăng nhập giao diện Grafana, bấm chuột từng bước để thêm Prometheus Data Source.
* Vẽ từng Panel, căn chỉnh PromQL, chọn màu sắc và bấm nút Save thủ công trên web.
* Mở file `/etc/prometheus/prometheus.yml` bằng `nano` mỗi khi có máy ảo mới, gõ thủ công IP và restart dịch vụ.

Cách làm này (gọi là **ClickOps**) bộc lộ các rủi ro thảm họa khi hệ thống mở rộng:
1. **Không có lịch sử phiên bản (No Version Control):** Không thể biết ai đã thay đổi ngưỡng cảnh báo, sửa công thức đồ thị vào thời điểm nào và lý do tại sao.
2. **Sai lệch cấu hình (Configuration Drift):** Môi trường Dev, Staging và Production trở nên khác biệt nhau sau nhiều lần bấm chuột tùy tiện của các kỹ sư.
3. **Thất bại khi khôi phục sau thảm họa (Disaster Recovery Failure):** Nếu máy ảo `mon-server` bị hỏng ổ cứng, người vận hành sẽ mất hàng ngày để nhớ lại và vẽ lại toàn bộ các Dashboard phức tạp từ đầu.

### 1.2. Triết lý Monitoring-as-Code (MaC) & GitOps
**Monitoring-as-Code** coi toàn bộ tài nguyên giám sát là phần mềm:
* Data Sources và Dashboards được biểu diễn dưới dạng file declarative YAML/JSON và lưu trong kho lưu trữ Git (`git commit`, `git push`).
* Danh sách máy chủ được quản lý động qua các tệp danh bạ (Service Discovery).
* Mọi thay đổi đều được kiểm tra cú pháp tự động (`promtool`, `amtool`) trước khi áp dụng vào hệ thống thực tế.

```text
┌──────────────────────────────────────────────┐
│  Git Repository: Projects/Linux/linux_op_lab1│
│  ├── grafana/provisioning/                   │
│  │   ├── datasources/prometheus.yml          │
│  │   └── dashboards/dashboards.yml           │
│  ├── dashboards/linux_host_metrics.json      │
│  ├── prometheus/targets/nodes.json           │
│  └── rules/{recording_rules,alert_rules}.yml │
└──────────────────────┬───────────────────────┘
                       │ git pull && ./deploy_stack.sh
                       ▼
┌──────────────────────────────────────────────┐
│        Production Server (mon-server)        │
│  • Tự động nạp Data Source vào Grafana       │
│  • Tự động hiển thị Dashboard không cần click│
│  • Tự động quét và cào IP target mới         │
└──────────────────────────────────────────────┘
```

---

## 2. GRAFANA PROVISIONING: QUẢN LÝ NGUỒN DỮ LIỆU & DASHBOARD BẰNG MÃ NGUỒN

Grafana cung cấp cơ chế **Provisioning** cho phép tự động nạp cấu hình từ thư mục hệ thống `/etc/grafana/provisioning/` mỗi khi dịch vụ khởi động.

### 2.1. Cấu trúc thư mục Provisioning chuẩn của Grafana
```text
/etc/grafana/provisioning/
├── datasources/
│   └── prometheus.yml        # Định nghĩa kết nối tới Prometheus TSDB
└── dashboards/
    └── dashboards.yml        # Định nghĩa thư mục chứa các file JSON dashboard
/var/lib/grafana/dashboards/
└── linux_host_metrics.json   # Mã nguồn JSON của Dashboard Linux Server
```

### 2.2. Khai báo Tự động Nguồn dữ liệu (Datasource as Code)
Tạo file `/etc/grafana/provisioning/datasources/prometheus.yml`:

```yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    orgId: 1
    url: http://localhost:9090
    isDefault: true
    version: 1
    editable: false           # Khóa chỉnh sửa trên UI để tránh lệch cấu hình Git
    jsonData:
      httpMethod: POST
      timeInterval: 5s
      manageAlerts: true
```
> [!TIP]
> Tùy chọn `editable: false` đảm bảo không ai có thể vào giao diện web sửa bậy URL hay xóa nguồn dữ liệu. Mọi thay đổi bắt buộc phải commit vào Git.

### 2.3. Khai báo Tự động Dashboard (Dashboard as Code qua JSON Provider)
Tạo file `/etc/grafana/provisioning/dashboards/dashboards.yml`:

```yaml
apiVersion: 1

providers:
  - name: 'Linux Infrastructure'
    orgId: 1
    folder: 'Linux Production'
    type: file
    disableDeletion: true
    updateIntervalSeconds: 10 # Tự động phát hiện nếu file JSON trong thư mục có thay đổi
    allowUiUpdates: false     # Mọi chỉnh sửa trên UI sẽ không ghi đè vào file gốc
    options:
      path: /var/lib/grafana/dashboards
```

### 2.4. Trích xuất (Export) và Chuẩn hóa Dashboard JSON từ giao diện
1. Tạo thư mục chứa file dashboard:
   ```bash
   sudo mkdir -p /var/lib/grafana/dashboards
   sudo chown -R grafana:grafana /var/lib/grafana/dashboards
   ```
2. Nếu bạn đã có sẵn Dashboard vẽ trên web, nhấp vào biểu tượng **Share (Chia sẻ) ➔ Export ➔ View JSON ➔ Copy to clipboard**.
3. Lưu nội dung JSON vào file `/var/lib/grafana/dashboards/linux_host_metrics.json`.
4. Đảm bảo trong JSON các panel PromQL sử dụng đúng các Recording Metric đã chuẩn hóa:
   * `instance:cpu_usage:percent`
   * `instance:memory_usage:percent`
   * `instance:root_disk_usage:percent`

Khởi động lại Grafana:
```bash
sudo systemctl restart grafana-server
```
Đăng nhập Grafana: Bạn sẽ thấy thư mục **"Linux Production"** cùng toàn bộ Dashboard xuất hiện ngay lập tức mà không cần tạo thủ công.

---

## 3. PROMETHEUS FILE-BASED SERVICE DISCOVERY (FILE SD)

### 3.1. Hạn chế của cấu hình tĩnh `static_configs`
Trong mô hình cơ bản, mỗi khi thêm máy ảo mới cần giám sát, quản trị viên phải sửa file `/etc/prometheus/prometheus.yml` và chạy `systemctl restart prometheus`. Khi số lượng server lên tới hàng chục hoặc hàng trăm máy, thao tác này gây rủi ro làm gián đoạn tiến trình Prometheus nếu file YAML bị sai khoảng trắng.

### 3.2. Cấu hình Dynamic Scrape qua `file_sd_configs`
Prometheus hỗ trợ cơ chế **File Service Discovery (`file_sd_configs`)**: Prometheus liên tục giám sát một thư mục chứa các file JSON hoặc YAML. Khi file thay đổi, Prometheus tự động đọc lại danh sách IP mục tiêu trong vòng vài giây mà không cần khởi động lại.

Sửa file `/etc/prometheus/prometheus.yml`:

```yaml
global:
  scrape_interval: 5s
  evaluation_interval: 5s

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  # Thay thế static_configs bằng file_sd_configs cho toàn bộ máy ảo Linux:
  - job_name: "node_exporter"
    scrape_interval: 5s
    file_sd_configs:
      - files:
          - '/etc/prometheus/targets/*.json'
        refresh_interval: 5s
```

### 3.3. Tự động thêm bớt máy chủ giám sát qua File Targets
Tạo thư mục targets:
```bash
sudo mkdir -p /etc/prometheus/targets
```

Tạo file danh bạ máy chủ `/etc/prometheus/targets/nodes.json`:
```json
[
  {
    "targets": ["192.168.122.38:9100"],
    "labels": {
      "environment": "production",
      "role": "application-target",
      "hostname": "mon-target"
    }
  }
]
```
Prometheus sẽ tự động nạp `192.168.122.38:9100` và gắn các nhãn `environment="production"` vào toàn bộ các metric thu thập được từ máy đó.

---

## 4. XÂY DỰNG PIPELINE TỰ ĐỘNG HÓA ĐỒNG BỘ (GITOPS PIPELINE)

### 4.1. Cấu trúc thư mục Git chuẩn mực
Trong repository `Projects/Linux/Seminar/linux_op_lab1/`, tổ chức cây thư mục chuẩn GitOps:

```text
Projects/Linux/Seminar/linux_op_lab1/
├── configs/
│   ├── prometheus/
│   │   ├── prometheus.yml
│   │   ├── recording_rules.yml
│   │   ├── alert_rules.yml
│   │   └── targets/
│   │       └── nodes.json
│   ├── alertmanager/
│   │   ├── alertmanager.yml
│   │   └── alert.tmpl
│   └── grafana/
│       ├── datasources/
│       │   └── prometheus.yml
│       ├── dashboards/
│       │   └── dashboards.yml
│       └── json/
│           └── linux_host_metrics.json
└── scripts/
    ├── auto_stress.py
    └── deploy_stack.sh
```

### 4.2. Kịch bản Tự động Triển khai & Kiểm thử Cú pháp (`deploy_stack.sh`)
Tạo script [scripts/deploy_stack.sh](file:///home/archlinux/Projects/Linux/Seminar/linux_op_lab1/scripts/deploy_stack.sh) chịu trách nhiệm kiểm tra toàn diện trước khi chép file vào hệ thống:

```bash
#!/usr/bin/env bash
# deploy_stack.sh - Tự động đồng bộ và nạp cấu hình Monitoring Stack chuẩn GitOps

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "==> Bắt đầu kiểm tra và triển khai Monitoring as Code từ: $REPO_DIR"

# 1. Kiểm tra tính hợp lệ cú pháp Prometheus & Alertmanager
echo "[1/5] Kiểm tra cú pháp Rules và Config..."
promtool check config "$REPO_DIR/configs/prometheus/prometheus.yml"
promtool check rules "$REPO_DIR/configs/prometheus/recording_rules.yml"
promtool check rules "$REPO_DIR/configs/prometheus/alert_rules.yml"
amtool check-config "$REPO_DIR/configs/alertmanager/alertmanager.yml"

# 2. Đồng bộ file cấu hình Prometheus
echo "[2/5] Đồng bộ cấu hình Prometheus..."
sudo cp "$REPO_DIR/configs/prometheus/prometheus.yml" /etc/prometheus/
sudo cp "$REPO_DIR/configs/prometheus/recording_rules.yml" /etc/prometheus/
sudo cp "$REPO_DIR/configs/prometheus/alert_rules.yml" /etc/prometheus/
sudo mkdir -p /etc/prometheus/targets
sudo cp "$REPO_DIR/configs/prometheus/targets/"*.json /etc/prometheus/targets/
sudo chown -R prometheus:prometheus /etc/prometheus

# 3. Đồng bộ file cấu hình Alertmanager
echo "[3/5] Đồng bộ cấu hình Alertmanager..."
sudo cp "$REPO_DIR/configs/alertmanager/alertmanager.yml" /etc/alertmanager/
sudo cp "$REPO_DIR/configs/alertmanager/alert.tmpl" /etc/alertmanager/
sudo chown -R alertmanager:alertmanager /etc/alertmanager

# 4. Đồng bộ Grafana Provisioning
echo "[4/5] Đồng bộ Grafana Provisioning & Dashboards..."
sudo mkdir -p /etc/grafana/provisioning/datasources /etc/grafana/provisioning/dashboards /var/lib/grafana/dashboards
sudo cp "$REPO_DIR/configs/grafana/datasources/"*.yml /etc/grafana/provisioning/datasources/
sudo cp "$REPO_DIR/configs/grafana/dashboards/"*.yml /etc/grafana/provisioning/dashboards/
sudo cp "$REPO_DIR/configs/grafana/json/"*.json /var/lib/grafana/dashboards/
sudo chown -R grafana:grafana /etc/grafana/provisioning /var/lib/grafana/dashboards

# 5. Reload dịch vụ không làm gián đoạn hoạt động
echo "[5/5] Nạp cấu hình mới (Hot Reload)..."
curl -s -X POST http://localhost:9090/-/reload || sudo systemctl reload prometheus
sudo systemctl reload alertmanager || sudo systemctl restart alertmanager
sudo systemctl restart grafana-server

echo "==> [THÀNH CÔNG] Toàn bộ hệ thống giám sát đã được đồng bộ chuẩn GitOps!"
```

Cấp quyền thực thi:
```bash
chmod +x scripts/deploy_stack.sh
```

### 4.3. Tự động hóa kiểm soát phiên bản qua Git Hook / Cron Sync
Để máy chủ `mon-server` tự động cập nhật khi có commit mới trên nhánh `main`:
```bash
# Thêm cấu hình tự động pull và deploy mỗi 5 phút vào crontab của root:
sudo crontab -e
# Thêm dòng:
# */5 * * * * cd /home/archlinux/Projects/Linux/Seminar/linux_op_lab1 && git pull origin main && ./scripts/deploy_stack.sh > /var/log/monitoring_gitops.log 2>&1
```

---

## 5. KỊCH BẢN DEMO THỰC TẾ TỪNG BƯỚC

### Demo 1: Khắc phục Thảm họa (Disaster Recovery) - Tái sinh Grafana
Kịch bản: Giả lập cơ sở dữ liệu SQLite của Grafana bị hỏng hoàn toàn.
1. Dừng Grafana và xóa sạch database:
   ```bash
   sudo systemctl stop grafana-server
   sudo rm -f /var/lib/grafana/grafana.db
   ```
2. Khởi động lại dịch vụ Grafana:
   ```bash
   sudo systemctl start grafana-server
   ```
3. **Kết quả quan sát kỳ vọng:**
   * Truy cập `http://<IP-mon-server>:3000`.
   * Mặc dù cơ sở dữ liệu vừa bị xóa sạch, nhờ có **Provisioning**, toàn bộ kết nối Prometheus Data Source và các Dashboard Linux Host Metrics lập tức tự động xuất hiện nguyên vẹn 100%.

### Demo 2: Cấp phát Động mục tiêu giám sát (Dynamic Target Onboarding) qua File SD
Kịch bản: Thêm một máy ảo mục tiêu mới (ví dụ `web-vm` có IP `192.168.122.10`) vào hệ thống giám sát.
1. Mở file `/etc/prometheus/targets/nodes.json` và chèn thêm đối tượng:
   ```json
   [
     {
       "targets": ["192.168.122.38:9100"],
       "labels": { "hostname": "mon-target", "role": "metrics-agent" }
     },
     {
       "targets": ["192.168.122.10:9100"],
       "labels": { "hostname": "web-vm", "role": "web-server" }
     }
   ]
   ```
2. Lưu file và KHÔNG thực hiện bất kỳ lệnh restart hay reload nào.
3. Mở Prometheus UI (`http://<IP-mon-server>:9090/targets`).
4. **Kết quả quan sát kỳ vọng:**
   * Sau tối đa 5 giây, target `192.168.122.10:9100` tự động xuất hiện trên danh sách targets của Prometheus với đầy đủ các label đã khai báo.

### Demo 3: Thực thi Triển khai Tự động bằng Script One-Click
1. Thay đổi một ngưỡng cảnh báo trong file `configs/prometheus/alert_rules.yml`.
2. Chạy lệnh:
   ```bash
   ./scripts/deploy_stack.sh
   ```
3. Quan sát script tự chạy `promtool`, copy file, phân quyền và hot-reload thành công mà không làm rớt gói tin nào.

---

## 6. BẢNG SO SÁNH PHƯƠNG THỨC VẬN HÀNH CLIKOPS VS GITOPS

| Tiêu chí so sánh | Phương pháp Thủ công (ClickOps) | Tự động hóa Hạ tầng (GitOps / MaC) |
| :--- | :--- | :--- |
| **Quản lý thay đổi** | Thao tác trên giao diện, không ai kiểm soát | Mọi thay đổi đi qua Git commit và code review |
| **Kiểm tra lỗi cú pháp** | Thường chỉ biết khi dịch vụ crash | Kiểm tra tự động trước bằng `promtool check` |
| **Thời gian khôi phục sự cố**| Mất hàng giờ/ngày để vẽ lại dashboard | Dưới 30 giây (chạy lệnh khởi tạo) |
| **Độ nhất quán môi trường** | Thường xuyên lệch cấu hình giữa các máy | 100% giống nhau trên mọi môi trường |
| **Thêm máy chủ mới** | Sửa file trung tâm, restart dịch vụ | Thả file JSON mục tiêu vào thư mục `targets/` |
