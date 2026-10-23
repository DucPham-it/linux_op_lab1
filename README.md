# HỆ THỐNG GIÁM SÁT VÀ CẢNH BÁO TỰ ĐỘNG CHUẨN PRODUCTION (LAB #10)
## Production Observability Stack: Prometheus, Grafana, Alertmanager & Node Exporter
**Học phần / Chuyên đề:** Linux System Administration & Observability Engineering  
**Hạ tầng thực nghiệm:** KVM/libvirt Debian 12 Minimal Cloud (`mon-server` & `mon-target`)  
**Tài liệu học tập & Báo cáo:** [report.md](report.md) · [slide/slide.md](slide/slide.md) · [theory.md](theory.md)

---

## CẤU TRÚC REPOSITORY

```text
Projects/Linux/Seminar/linux_op_lab1/
├── README.md                      # Hướng dẫn triển khai, kiểm thử và tổng quan hệ thống
├── report.md                      # Báo cáo toàn diện đồ án (Lý thuyết, Setup, Demo, Mở rộng)
├── theory.md                      # Nền tảng lý thuyết cốt lõi (Pull vs Push, TSDB, Metrics, rate)
├── slide/
│   └── slide.md                   # Slide thuyết trình chuẩn Marp/Markdown Presentation
├── extension_docs/                # Thư mục 5 chuyên đề nghiên cứu mở rộng nâng cao
│   ├── ha_longterm_storage.md     # Mở rộng 1: Tính sẵn sàng cao (HA Replicas) & Thanos + MinIO LTS
│   ├── production_alerting.md     # Mở rộng 2: Cảnh báo chuyên nghiệp, triệt tiêu alert, Telegram
│   ├── security_and_auth.md       # Mở rộng 3: Mã hóa TLS 1.3, Web Basic Auth (bcrypt), UFW Firewall
│   ├── gitops_monitoring_as_code.md # Mở rộng 4: Tự động hóa hạ tầng (Grafana Provisioning, File SD)
│   └── recording_rules.md         # Mở rộng 5: Tối ưu hóa PromQL và Recording Rules
├── configs/                       # Toàn bộ mã nguồn cấu hình (Monitoring-as-Code)
│   ├── prometheus/                # prometheus.yml, recording_rules.yml, alert_rules.yml, targets/
│   ├── alertmanager/              # alertmanager.yml, alert.tmpl (HTML Telegram template)
│   ├── grafana/                   # provisioning/ (datasources, dashboards) & dashboard JSON
│   ├── nginx/                     # monitoring.conf (Reverse Proxy TLS 1.3)
│   ├── node_exporter/             # web-config.yml (Basic Auth)
│   └── thanos/                    # bucket.yml (S3 MinIO)
├── scripts/                       # Các kịch bản tự động hóa & kiểm thử
│   ├── deploy_stack.sh            # Pipeline đồng bộ và nạp cấu hình One-Click chuẩn GitOps
│   ├── setup_vms.sh               # Tự động cấp phát máy ảo KVM qua qemu-img CoW
│   ├── auto_stress.py             # Công cụ ép tải RAM thông minh tránh OOM Killer
│   └── demo_troubleshoot.sh       # Script kiểm chứng phân biệt mất Exporter vs sập VM
└── cloud-init/                    # Cấu hình cấp phát máy ảo tự động
    ├── user-data.yaml             # Khởi tạo user debian, SSH key, cài gói tự động
    └── meta-data.yaml             # Gán instance-id và hostname
```

---

## MỤC LỤC HƯỚNG DẪN TRIỂN KHAI & KIỂM THỬ
1. [Yêu cầu tiên quyết trên máy Host](#1-yêu-cầu-tiên-quyết-trên-máy-host)
2. [Bước 1: Cấp phát tự động 2 máy ảo (mon-server & mon-target)](#bước-1-cấp-phát-tự-động-2-máy-ảo-mon-server--mon-target)
3. [Bước 2: Cấu hình Máy mục tiêu (mon-target)](#bước-2-cấu-hình-máy-mục-tiêu-mon-target)
4. [Bước 3: Triển khai Cụm Giám sát trên mon-server bằng GitOps One-Click](#bước-3-triển-khai-cụm-giám-sát-trên-mon-server-bằng-gitops-one-click)
5. [Bước 4: Kiểm thử 4 Demo Bắt buộc của Seminar](#bước-4-kiểm-thử-4-demo-bắt-buộc-của-seminar)
   - [Demo 1: Thu thập & Dashboard Grafana thời gian thực](#demo-1-thu-thập--dashboard-grafana-thời-gian-thực)
   - [Demo 2: Thực thi và giải thích 3 câu truy vấn PromQL](#demo-2-thực-thi-và-giải-thích-3-câu-truy-vấn-promql)
   - [Demo 3: Kích hoạt cảnh báo Stress Test (Pending -> Firing)](#demo-3-kích-hoạt-cảnh-báo-stress-test-pending---firing)
   - [Demo 4: Troubleshooting phân biệt mất Exporter vs sập Server](#demo-4-troubleshooting-phân-biệt-mất-exporter-vs-sập-server)
6. [Bước 5: Kiểm thử các Chuyên đề Mở rộng (HA, Security, GitOps)](#bước-5-kiểm-thử-các-chuyên-đề-mở-rộng-ha-security-gitops)
   - [Mở rộng 1: Tái sinh Grafana sau Thảm họa (Disaster Recovery)](#mở-rộng-1-tái-sinh-grafana-sau-thảm-họa-disaster-recovery)
   - [Mở rộng 2: Cấp phát mục tiêu động không gián đoạn (File SD)](#mở-rộng-2-cấp-phát-mục-tiêu-động-không-gián-đoạn-file-sd)
   - [Mở rộng 3: Kiểm chứng Bảo mật TLS & Web Basic Auth](#mở-rộng-3-kiểm-chứng-bảo-mật-tls--web-basic-auth)
   - [Mở rộng 4: Tính sẵn sàng cao (Active-Active HA Failover)](#mở-rộng-4-tính-sẵn-sàng-cao-active-active-ha-failover)
7. [Các câu lệnh gỡ lỗi nhanh (Cheatsheet)](#7-các-câu-lệnh-gỡ-lỗi-nhanh-cheatsheet)

---

## 1. YÊU CẦU TIÊN QUYẾT TRÊN MÁY HOST

Máy tính của bạn (Arch Linux, Ubuntu, Debian, Fedora...) cần cài sẵn gói ảo hóa KVM:

```bash
# Trên Arch Linux:
sudo pacman -S qemu-full virt-install virt-manager libvirt edk2-ovmf dnsmasq bridge-utils iptables-nft

# Trên Ubuntu / Debian:
sudo apt update && sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients virtinst bridge-utils

# Kích hoạt dịch vụ libvirt và mạng mặc định (NAT 192.168.122.0/24)
sudo systemctl enable --now libvirtd
sudo virsh net-start default 2>/dev/null || true
sudo virsh net-autostart default 2>/dev/null || true
```

---

## BƯỚC 1: CẤP PHÁT TỰ ĐỘNG 2 MÁY ẢO (mon-server & mon-target)

Bạn có thể chạy script tự động [scripts/setup_vms.sh](scripts/setup_vms.sh) hoặc thực hiện thủ công như sau:

```bash
# 1. Tạo thư mục chứa máy ảo
mkdir -p ~/vms && cd ~/vms

# 2. Tải bản Debian 12 Cloud Base Image chuẩn (chỉ tải 1 lần ~350MB)
wget -O debian-12-base.qcow2 https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2

# 3. Tạo 2 đĩa Copy-on-Write (CoW) overlays liên kết với Base Image
qemu-img create -f qcow2 -F qcow2 -b debian-12-base.qcow2 mon-server.qcow2 15G
qemu-img create -f qcow2 -F qcow2 -b debian-12-base.qcow2 mon-target.qcow2 10G

# 4. Khởi chạy 2 máy ảo bằng virt-install với cấu hình cloud-init
# Máy 1: mon-server (1.5GB RAM, 2 vCPU)
sudo virt-install \
  --name mon-server \
  --ram 1536 \
  --vcpus 2 \
  --disk path=$HOME/vms/mon-server.qcow2,format=qcow2 \
  --os-variant debian12 \
  --network network=default,model=virtio \
  --cloud-init user-data=/path/to/linux_op_lab1/cloud-init/user-data.yaml,meta-data=/path/to/linux_op_lab1/cloud-init/meta-data.yaml \
  --graphics none \
  --noautoconsole \
  --import

# Máy 2: mon-target (512MB RAM, 1 vCPU)
sudo virt-install \
  --name mon-target \
  --ram 512 \
  --vcpus 1 \
  --disk path=$HOME/vms/mon-target.qcow2,format=qcow2 \
  --os-variant debian12 \
  --network network=default,model=virtio \
  --cloud-init user-data=/path/to/linux_op_lab1/cloud-init/user-data.yaml,meta-data=/path/to/linux_op_lab1/cloud-init/meta-data.yaml \
  --graphics none \
  --noautoconsole \
  --import
```

Kiểm tra IP được cấp phát cho 2 máy:
```bash
sudo virsh net-dhcp-leases default
```
*(Giả sử trong bài: `mon-server` là `192.168.122.54`, `mon-target` là `192.168.122.38`)*.

---

## BƯỚC 2: CẤU HÌNH MÁY MỤC TIÊU (mon-target)

Truy cập SSH vào `mon-target`:
```bash
ssh debian@192.168.122.38
```

1. **Cài đặt Node Exporter và công cụ ép tải:**
   ```bash
   sudo apt update && sudo apt install -y prometheus-node-exporter stress-ng ufw
   sudo systemctl enable --now prometheus-node-exporter
   ```

2. **Kiểm tra endpoint metrics:**
   ```bash
   curl -s http://localhost:9100/metrics | head -n 20
   ```

3. **Cấu hình tường lửa UFW (Bảo mật chuyên đề 3):**
   ```bash
   sudo ufw default deny incoming
   sudo ufw default allow outgoing
   sudo ufw allow 22/tcp comment "SSH"
   sudo ufw allow from 192.168.122.54 to any port 9100 proto tcp comment "Allow Node Exporter only from mon-server"
   sudo ufw enable
   ```

---

## BƯỚC 3: TRIỂN KHAI CỤM GIÁM SÁT TRÊN mon-server BẰNG GITOPS ONE-CLICK

Truy cập SSH vào `mon-server`:
```bash
ssh debian@192.168.122.54
```

1. **Cài đặt Prometheus, Alertmanager và Grafana:**
   ```bash
   # Cài Prometheus và Alertmanager từ repository Debian
   sudo apt update && sudo apt install -y prometheus prometheus-alertmanager git curl jq

   # Cài Grafana Enterprise
   sudo mkdir -p /etc/apt/keyrings/
   wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
   echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
   sudo apt update && sudo apt install -y grafana
   sudo systemctl enable --now grafana-server
   ```

2. **Clone mã nguồn dự án:**
   ```bash
   git clone https://github.com/DucPham-it/linux_op_lab1.git
   cd linux_op_lab1
   ```

3. **Thực thi script triển khai chuẩn GitOps One-Click:**
   ```bash
   sudo ./scripts/deploy_stack.sh
   ```
   *Script sẽ tự động:*
   - Bắt lỗi cú pháp bằng `promtool` và `amtool`.
   - Đồng bộ toàn bộ file trong [configs/](configs/) vào `/etc/prometheus/`, `/etc/alertmanager/`, `/etc/grafana/provisioning/`.
   - Cấp phát dashboard JSON vào `/var/lib/grafana/dashboards/`.
   - Gọi API Hot-reload `curl -X POST http://localhost:9090/-/reload` và khởi động lại Grafana.

---

## BƯỚC 4: KIỂM THỬ 4 DEMO BẮT BUỘC CỦA SEMINAR

### Demo 1: Thu thập & Dashboard Grafana thời gian thực
1. Mở trình duyệt web từ máy Host và truy cập: `http://192.168.122.54:3000` (User mặc định: `admin` / `admin`).
2. Vào mục **Dashboards ➔ Browse ➔ Thư mục "Linux Production" ➔ Chọn "Linux Host Metrics (Production)"**.
3. **Kết quả quan sát:**
   - 4 KPI cards (CPU Gauge, Memory Gauge, Disk Gauge, Uptime Stat) hiển thị chính xác theo thời gian thực.
   - Các đồ thị dòng thời gian (Time-series) của CPU, RAM, Network Traffic liên tục cập nhật mỗi 5 giây.
   - *Ghi chú:* Toàn bộ Dashboard này được tự động nạp từ file [configs/grafana/json/linux_host_metrics.json](configs/grafana/json/linux_host_metrics.json) mà không cần vẽ thủ công.

---

### Demo 2: Thực thi và giải thích 3 câu truy vấn PromQL
Mở trình duyệt truy cập Prometheus Web Graph: `http://192.168.122.54:9090/graph` và lần lượt thực thi 3 câu lệnh sau:

* **Câu 1 (Bắt buộc dùng `rate()` để đo tốc độ CPU tiêu thụ):**
  ```promql
  100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[1m])) * 100)
  ```
  - *Giải thích:* Metric `node_cpu_seconds_total` là Counter. Hàm `rate(...[1m])` tính số giây CPU ở chế độ nghỉ (`idle`) mỗi giây trong 1 phút qua. Lấy `100 - (idle * 100)` sẽ ra tỷ lệ % CPU bận.
* **Câu 2 (Đo mức sử dụng RAM chuẩn Linux Kernel):**
  ```promql
  ((node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes) * 100
  ```
  - *Giải thích:* Sử dụng `MemAvailable` (đã tính gộp cả bộ nhớ đệm Buffer/Cache mà Kernel có thể thu hồi khi cần), tránh báo động giả khi cache RAM cao.
* **Câu 3 (Đo lưu lượng mạng truyền nhận theo thời gian thực):**
  ```promql
  rate(node_network_receive_bytes_total{device!~"lo|docker.*"}[1m])
  ```
  - *Giải thích:* Tính tốc độ nhận dữ liệu (Bytes/giây) trên các card mạng vật lý, loại trừ loopback và card ảo.

---

### Demo 3: Kích hoạt cảnh báo Stress Test (Pending -> Firing)
1. Trên `mon-server`, mở trang cảnh báo: `http://192.168.122.54:9090/alerts`.
   - Quan sát trạng thái ban đầu của rule `HighCPUUsage` là màu xanh: **Inactive**.
2. Trên `mon-target`, tiến hành ép tải CPU lên 100% bằng lệnh:
   ```bash
   stress-ng --cpu 1 --timeout 150s
   ```
   *(Hoặc chạy script ép RAM: `python3 scripts/auto_stress.py 90 180`)*.
3. **Diễn biến quan sát trên UI:**
   - Sau 5 giây: Metric vượt ngưỡng 80% ➔ Alert chuyển sang màu vàng: **Pending** (Đang đếm thời gian `for: 1m`).
   - Sau 60 giây duy trì: Alert chính thức chuyển sang màu đỏ: **Firing** ➔ Alertmanager gửi thông báo Telegram.
   - Khi lệnh `stress-ng` kết thúc, tải CPU giảm về bình thường ➔ Alert tự động chuyển sang trạng thái **Resolved**.

---

### Demo 4: Troubleshooting phân biệt mất Exporter vs sập Server
Chạy script tự động [scripts/demo_troubleshoot.sh](scripts/demo_troubleshoot.sh) hoặc thực hiện thủ công:

1. **Trường hợp 1 (Tắt Exporter - Target VM vẫn sống):**
   - Trên `mon-target`: `sudo systemctl stop prometheus-node-exporter`
   - Trên Prometheus Targets (`http://192.168.122.54:9090/targets`):
     - Endpoint chuyển sang màu đỏ: **DOWN**.
     - Dòng lỗi hiển thị: `Get "http://192.168.122.38:9100/metrics": dial tcp 192.168.122.38:9100: connect: connection refused`.
     - *Phân tích:* Máy chủ mục tiêu vẫn sống (ping và SSH được), nhưng dịch vụ port 9100 bị tắt.
2. **Trường hợp 2 (Tắt hẳn Target VM):**
   - Bật lại exporter: `sudo systemctl start prometheus-node-exporter`.
   - Trên máy Host, tắt máy ảo mục tiêu: `sudo virsh destroy mon-target`.
   - Trên Prometheus Targets:
     - Dòng lỗi hiển thị: `context deadline exceeded` hoặc `no route to host`.
     - *Phân tích:* Toàn bộ tầng mạng/máy ảo bị sập hoàn toàn. Rule `InstanceDown` được kích hoạt và cơ chế **Inhibition** của Alertmanager sẽ triệt tiêu các cảnh báo con CPU/RAM của máy đó.

---

## BƯỚC 5: KIỂM THỬ CÁC CHUYÊN ĐỀ MỞ RỘNG (HA, SECURITY, GITOPS)

### Mở rộng 1: Tái sinh Grafana sau Thảm họa (Disaster Recovery)
1. Dừng Grafana và xóa hoàn toàn database SQLite:
   ```bash
   sudo systemctl stop grafana-server
   sudo rm -f /var/lib/grafana/grafana.db
   ```
2. Khởi động lại dịch vụ:
   ```bash
   sudo systemctl start grafana-server
   ```
3. Mở lại trình duyệt `http://192.168.122.54:3000`:
   - Dù cơ sở dữ liệu vừa bị xóa trắng, nhờ có **Provisioning**, toàn bộ Data Source Prometheus và Dashboard Linux Server tự động xuất hiện nguyên vẹn 100% trong chưa đầy 5 giây! Chi tiết xem tại [extension_docs/gitops_monitoring_as_code.md](extension_docs/gitops_monitoring_as_code.md).

---

### Mở rộng 2: Cấp phát mục tiêu động không gián đoạn (File SD)
1. Thêm một IP máy mục tiêu giả định vào file [configs/prometheus/targets/nodes.json](configs/prometheus/targets/nodes.json):
   ```json
   [
     {
       "targets": ["192.168.122.38:9100"],
       "labels": { "hostname": "mon-target", "role": "metrics-agent" }
     },
     {
       "targets": ["192.168.122.99:9100"],
       "labels": { "hostname": "new-web-node", "role": "web-server" }
     }
   ]
   ```
2. Copy vào thư mục hệ thống:
   ```bash
   sudo cp configs/prometheus/targets/nodes.json /etc/prometheus/targets/
   ```
3. Mở trang `http://192.168.122.54:9090/targets` (KHÔNG cần chạy lệnh restart hay reload dịch vụ).
4. *Kết quả:* Sau đúng 5 giây, target `192.168.122.99:9100` tự động xuất hiện trên giao diện.

---

### Mở rộng 3: Kiểm chứng Bảo mật TLS & Web Basic Auth
Chi tiết xem tại [extension_docs/security_and_auth.md](extension_docs/security_and_auth.md).
1. **Kiểm tra ép HTTPS qua Nginx:**
   ```bash
   curl -I http://192.168.122.54/
   ```
   *Kết quả:* Trả về `HTTP/1.1 301 Moved Permanently` chuyển hướng sang `https://192.168.122.54/`.
2. **Kiểm tra Basic Auth bảo vệ Prometheus:**
   ```bash
   # Gửi request không có tài khoản:
   curl -k -i https://192.168.122.54/prometheus/api/v1/targets
   # Kết quả: HTTP/1.1 401 Unauthorized

   # Gửi request có tài khoản admin (bcrypt):
   curl -k -u admin:AdminStrongPass2026! https://192.168.122.54/prometheus/api/v1/targets
   # Kết quả: HTTP/1.1 200 OK
   ```

---

### Mở rộng 4: Tính sẵn sàng cao (Active-Active HA Failover)
Chi tiết xem tại [extension_docs/ha_longterm_storage.md](extension_docs/ha_longterm_storage.md).
1. Khởi chạy instance Prometheus thứ 2 trên cổng 9091:
   ```bash
   sudo prometheus --config.file=configs/prometheus/prometheus-replica.yml \
                   --storage.tsdb.path=/tmp/prom-replica \
                   --web.listen-address="0.0.0.0:9091" &
   ```
2. Gây tải cao trên `mon-target` để kích hoạt trạng thái FIRING.
3. Tắt đột ngột Prometheus chính: `sudo systemctl stop prometheus`.
4. *Kết quả:* Alertmanager (`http://192.168.122.54:9093`) vẫn duy trì trạng thái FIRING qua Replica 9091; Telegram nhận đúng 1 thông báo nhờ cơ chế khử trùng lặp (Deduplication).

---

## 7. CÁC CÂU LỆNH GỠ LỖI NHANH (CHEATSHEET)

```bash
# Kiểm tra log dịch vụ theo thời gian thực
sudo journalctl -u prometheus -f
sudo journalctl -u prometheus-alertmanager -f
sudo journalctl -u grafana-server -f

# Kiểm tra cú pháp cấu hình thủ công bằng promtool & amtool
promtool check config /etc/prometheus/prometheus.yml
promtool check rules /etc/prometheus/recording_rules.yml
promtool check rules /etc/prometheus/alert_rules.yml
amtool check-config /etc/alertmanager/alertmanager.yml

# Kích hoạt Hot-reload Prometheus không làm gián đoạn
curl -s -X POST http://localhost:9090/-/reload

# Kiểm tra các cổng đang lắng nghe trên máy chủ
sudo ss -tulpn | grep -E '3000|9090|9091|9093|9100'
```
