# Production Alerting: Từ Alert cơ bản đến cảnh báo chuyên nghiệp

## Mục tiêu của chủ đề

Chủ đề này đi đúng theo yêu cầu trong [agent.md](agent.md): hệ thống cảnh báo chuyên nghiệp (Production Alerting). Mục tiêu không chỉ là “có alert”, mà là:

- giảm spam cảnh báo bằng `Grouping`
- tránh cảnh báo lặp khi lỗi gốc đã rõ bằng `Inhibition`
- chuẩn hóa rule theo `Golden Signals`
- chuẩn bị cho mô hình `On-Call` bằng PagerDuty / Opsgenie trong môi trường production

---

## 1. Tại sao cần Production Alerting?

Hệ thống cảnh báo cơ bản thường chỉ gửi email/Slack đơn lẻ cho từng sự kiện. Điều này gây ra ba vấn đề lớn:

- Spam thông báo: nhiều alert cùng một nguyên nhân
- Mất ngữ cảnh: kỹ sư không biết alert nào là vấn đề gốc
- Tốn thời gian xử lý: cảnh báo phụ lặp lại khiến team khó tập trung

Production Alerting giải quyết bằng cách:

- gom nhóm alert tương tự lại với `group_by`
- ẩn cảnh báo phụ khi đã có cảnh báo chính với `inhibit_rules`
- gắn `severity`, `service`, `team`, `instance` để phân loại và ưu tiên
- dựa trên `Golden Signals` để cảnh báo đúng sự cố đúng tầng

---

## 2. Kiến trúc demo trên local

- VM 1 (`mon-server`): Prometheus + Alertmanager + Grafana
- VM 2 (`mon-target`): Node Exporter + `stress-ng`

Mục tiêu demo:

- `HighCPUUsage` : cảnh báo warning khi CPU > 80% trong 1 phút
- `NodeExporterDown` : cảnh báo critical khi exporter mất kết nối
- Khi `NodeExporterDown` xảy ra, `HighCPUUsage` sẽ bị ẩn nhờ `inhibition`

---

## 3. Cấu hình host theo từng môi trường

Phần này bổ sung cho các bạn đang dùng `Arch Linux`, `Fedora`, hoặc `VirtualBox` thay vì chỉ dùng một môi trường duy nhất.

### 3.1. Arch Linux host

Nếu host là Arch Linux, dùng libvirt + QEMU như lab gốc:

```bash
sudo pacman -Syu qemu-desktop libvirt virt-manager dnsmasq iptables-nft
sudo usermod -aG libvirt,kvm $USER
sudo systemctl enable --now libvirtd
newgrp libvirt
sudo virsh net-autostart default
sudo virsh net-start default
sudo virsh net-list --all
```

Lưu ý:

- `virbr0` sẽ được tạo bởi libvirt default network
- `192.168.122.0/24` là dải IP nội bộ cho VM
- nếu dùng `firewalld`, cần reload cấu hình sau khi cài libvirt:

```bash
sudo firewall-cmd --reload
```

---

### 3.2. Fedora host

Nếu host dùng Fedora, có thể dùng KVM/libvirt tương tự nhưng cài qua `dnf`:

```bash
sudo dnf install @virtualization
sudo systemctl enable --now libvirtd
sudo usermod -aG libvirt $USER
sudo firewall-cmd --add-service=libvirt --permanent
sudo firewall-cmd --reload
newgrp libvirt
sudo virsh net-autostart default
sudo virsh net-start default
sudo virsh net-list --all
```

Nếu máy có hỗ trợ KVM, kiểm tra:

```bash
ls /dev/kvm
```

Nếu `kvm` không tồn tại, có thể cần bật Intel VT-x/AMD-V trong BIOS hoặc dùng QEMU emulation mode.

---

### 3.3. VirtualBox host

Nếu bạn dùng VirtualBox thay vì KVM/libvirt, vẫn có thể chạy lab này nhưng cần thay đổi cách networking:

#### Cài đặt trên Arch:

```bash
sudo pacman -S virtualbox virtualbox-host-modules-arch
sudo usermod -aG vboxusers $USER
sudo systemctl enable --now vboxservice
```

#### Cài đặt trên Fedora:

```bash
sudo dnf install VirtualBox VirtualBox-ExtensionPack
sudo usermod -aG vboxusers $USER
sudo systemctl enable --now vboxdrv
```

#### Cấu hình mạng cho từng VM trong VirtualBox

- NIC 1: NAT để VM có Internet
- NIC 2: Host-only Adapter để VM nằm cùng dải mạng nội bộ với host
- Gán IP tĩnh cho các VM trong dải như `192.168.56.0/24` hoặc `192.168.122.0/24`

Ví dụ:

```bash
VBoxManage list hostonlyifs
```

Sau đó tạo VM, gắn 2 NIC:

- NAT: để download package và truy cập Internet
- Host-only: để Prometheus scrape data từ target VM

Lưu ý quan trọng:

- nếu dùng VirtualBox, bạn không cần `libvirt`/`virsh`
- nhưng vẫn phải cấu hình IP tĩnh và port forwarding rõ ràng cho Prometheus/Grafana
- cách demo vẫn giống nhau: `target` export metrics, `server` scrape, `Alertmanager` cảnh báo

---

### 3.4. Chọn môi trường nào phù hợp?

| Môi trường | Ưu điểm | Nhược điểm | Nên dùng khi |
|---|---|---|---|
| Arch + libvirt | chuẩn xác nhất với lab | cần cấu hình hệ thống nhiều hơn | học Linux/KVM thật |
| Fedora + libvirt | dễ cài và ổn định | cần BIOS VT-x / KVM | máy có hỗ trợ virtualization mạnh |
| VirtualBox | dễ dùng, GUI đơn giản | networking phức tạp hơn | người mới, demo nhanh |

---

## 4. Rule cảnh báo theo Golden Signals

Mẫu rule cảnh báo nên phản ánh 4 chỉ số vàng:

- Latency: độ trễ dịch vụ
- Traffic: lượng request / lưu lượng
- Errors: tỷ lệ lỗi
- Saturation: mức quá tải / resource sử dụng

Ví dụ theo local lab:

```yaml
groups:
  - name: production_alerts
    rules:
      - alert: HighCPUUsage
        expr: 100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[1m])) * 100) > 80
        for: 1m
        labels:
          severity: warning
          service: node
          team: platform
        annotations:
          summary: "CPU cao trên {{ $labels.instance }}"
          description: "CPU usage đã vượt ngưỡng 80% trong 1 phút, hiện tại {{ $value }}%."

      - alert: NodeExporterDown
        expr: up{job="node_exporter"} == 0
        for: 30s
        labels:
          severity: critical
          service: exporter
          team: platform
        annotations:
          summary: "Node Exporter bị mất trên {{ $labels.instance }}"
          description: "Prometheus không thể scrape metric từ exporter trên {{ $labels.instance }}."
```

> Trong môi trường production, các rule nên mở rộng sang latency, 5xx error rate, queue depth, disk usage, memory saturation, v.v.

---

## 4. Cấu hình Alertmanager với Grouping và Inhibition

Trên VM 1, tạo file:

```bash
sudo nano /etc/prometheus/alert_rules_production.yml
```

Sau đó cập nhật Prometheus:

```bash
sudo nano /etc/prometheus/prometheus.yml
```

Thêm:

```yaml
rule_files:
  - "/etc/prometheus/alert_rules.yml"
  - "/etc/prometheus/alert_rules_production.yml"
```

Sau đó tạo file Alertmanager config:

```bash
sudo nano /etc/prometheus/alertmanager.yml
```

Nội dung mẫu:

```yaml
global:
  resolve_timeout: 5m

route:
  receiver: "platform-team"
  group_by: ['alertname', 'instance', 'job']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 1h
  routes:
    - matchers:
        - severity="critical"
      receiver: "platform-team"

receivers:
  - name: "platform-team"
    webhook_configs:
      - url: "http://127.0.0.1:5001/"
        send_resolved: true

inhibit_rules:
  - source_matchers:
      - severity="critical"
      - alertname="NodeExporterDown"
    target_matchers:
      - severity="warning"
      - alertname="HighCPUUsage"
    equal: ['instance', 'job']
```

### Giải thích

- `group_by`: gom nhiều alert liên quan thành 1 cảnh báo thống nhất.
- `group_wait`: chờ trước khi gộp alert.
- `group_interval`: khoảng thời gian giữa các gói alert.
- `inhibit_rules`: nếu có `NodeExporterDown` critical, thì `HighCPUUsage` warning trên cùng instance sẽ bị ẩn để tránh spam và giúp người vận hành tập trung vào nguyên nhân gốc.

Restart dịch vụ:

```bash
sudo systemctl restart prometheus
sudo systemctl restart prometheus-alertmanager
```

Mở UI:

- Prometheus: `http://192.168.122.54:9090`
- Alertmanager: `http://192.168.122.54:9093`

---

## 5. On-call Management trong production

Phần này là phần mở rộng thực tế để chuyển từ lab sang production:

- PagerDuty / Opsgenie dùng để phân ca trực cho kỹ sư
- khi alert severity = critical, hệ thống tự động gọi / nhắn tin / tạo incident
- nếu có nhiều đội, routing theo `team`, `service`, `severity`

Mô hình tham khảo:

```yaml
route:
  receiver: "platform-team"
  routes:
    - matchers:
        - severity="critical"
      receiver: "pagerduty-critical"
    - matchers:
        - team="platform"
      receiver: "slack-platform"
```

> Với local demo, ta không cần tích hợp thật PagerDuty. Chỉ cần cấu hình route và hiểu cách Alertmanager sẽ làm việc khi triển khai production.

---

## 6. Demo thực hành trên local

### Bước 1: Kiểm tra môi trường

```bash
sudo systemctl status prometheus
sudo systemctl status prometheus-alertmanager
```

Nếu chưa chạy:

```bash
sudo systemctl enable --now prometheus
sudo systemctl enable --now prometheus-alertmanager
```

---

### Bước 2: Chạy CPU stress trên target

Trên VM 2:

```bash
stress-ng --cpu 1 --timeout 180s
```

Sau 1 phút, Prometheus sẽ tạo alert `HighCPUUsage`.

Trên UI Alertmanager, bạn sẽ thấy alert được `group_by` theo `instance` / `alertname` thay vì hiển thị một đống cảnh báo lẻ.

---

### Bước 3: Tắt Node Exporter để test inhibition

Trên VM 2:

```bash
sudo systemctl stop prometheus-node-exporter
```

Sau khoảng 30 giây, alert `NodeExporterDown` sẽ xuất hiện với mức `critical`.

Khi đó, `HighCPUUsage` sẽ bị ẩn tự động theo rule `inhibit_rules` vì cùng instance và đã có lỗi gốc rõ ràng hơn.

Kiểm tra:

```bash
curl http://localhost:9100/metrics
```

Nó sẽ lỗi vì exporter đã dừng.

---

### Bước 4: Xem PromQL

Trên Prometheus UI -> Graph:

```promql
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[1m])) * 100)
```

```promql
up{job="node_exporter"}
```

```promql
ALERTS{alertname="HighCPUUsage"}
```

---

## 7. Kết luận

Đây đúng là “Production Alerting” vì nó không chỉ phát cảnh báo mà còn:

- ưu tiên sự cố đúng mức
- tránh spam thông tin
- gom cảnh báo theo nhóm
- phân tầng lỗi theo độ nghiêm trọng
- chuẩn hóa theo nguyên tắc production operations

Nói cách khác, lab hiện tại vượt khỏi alert cơ bản, đi thẳng vào nếp nghĩ vận hành hệ thống thực tế.

---

## 8. Gợi ý báo cáo cho nhóm

- Mục tiêu: triển khai Alertmanager professional alerting
- Công nghệ: Prometheus + Alertmanager + Node Exporter
- Demo: grouping + inhibition + CPU stress + exporter stop
- Kết quả mong muốn: alert rõ hơn, ít spam, dễ xử lý hơn
- Kết nối production: PagerDuty / Opsgenie / routing theo service

---

## 9. Tài liệu tham khảo

- https://prometheus.io/docs/alerting/latest/alertmanager/
- https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/
- https://prometheus.io/docs/guides/node-exporter/
- https://www.pagerduty.com/