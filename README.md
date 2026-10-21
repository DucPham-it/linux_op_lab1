# LAB #10: PROMETHEUS & GRAFANA MONITORING - COMPLETE COMMAND REFERENCE & GUIDE
**File:** `/home/archlinux/Projects/Linux/seminar.md`

This document contains all the commands recommended for setting up the environment, provisioning the virtual machines, deploying the monitoring stack, and executing the mandatory demos for Seminar Lab #10. Every command is accompanied by a detailed explanation of what it does and why it is required.

---

# TABLE OF CONTENTS / MỤC LỤC
- [ENGLISH VERSION](#english-version)
  - [Part 1: Host Environment Setup (Arch Linux)](#part-1-host-environment-setup-arch-linux)
  - [Part 2: Virtual Machine Provisioning (Automated via Cloud Image)](#part-2-virtual-machine-provisioning-automated-via-cloud-image)
  - [Part 3: Configuring Target VM (mon-target, 512MB RAM)](#part-3-configuring-target-vm-mon-target-512mb-ram)
  - [Part 4: Configuring Monitoring Server (mon-server, 1.5GB RAM)](#part-4-configuring-monitoring-server-mon-server-15gb-ram)
  - [Part 5: Mandatory Demo Execution](#part-5-mandatory-demo-execution)
- [PHIÊN BẢN TIẾNG VIỆT](#phiên-bản-tiếng-việt)
  - [Phần 1: Thiết lập môi trường máy chủ (Arch Linux)](#phần-1-thiết-lập-môi-trường-máy-chủ-arch-linux)
  - [Phần 2: Khởi tạo máy ảo (Tự động hóa qua Cloud Image)](#phần-2-khởi-tạo-máy-ảo-tự-động-hóa-qua-cloud-image)
  - [Phần 3: Cấu hình máy ảo mục tiêu (mon-target, 512MB RAM)](#phần-3-cấu-hình-máy-ảo-mục-tiêu-mon-target-512mb-ram)
  - [Phần 4: Cấu hình máy chủ giám sát (mon-server, 1.5GB RAM)](#phần-4-cấu-hình-máy-chủ-giám-sát-mon-server-15gb-ram)
  - [Phần 5: Thực hiện các bài demo bắt buộc](#phần-5-thực-hiện-các-bài-demo-bắt-buộc)
- [APPENDIX / PHỤ LỤC: WSL2 GUIDE FOR WINDOWS USERS](#appendix--phụ-lục-wsl2-guide-for-windows-users--hướng-dẫn-wsl2-cho-windows)
  - [English: Getting Started with WSL2](#english-getting-started-with-wsl2-windows-subsystem-for-linux)
  - [Tiếng Việt: Hướng dẫn cài đặt và sử dụng WSL2](#tiếng-việt-hướng-dẫn-cài-đặt-và-sử-dụng-wsl2-cho-người-dùng-windows)
- [APPENDIX / PHỤ LỤC: FEDORA GUIDE (HOST & WSL2)](#appendix--phụ-lục-fedora-guide-host--wsl2--hướng-dẫn-dành-cho-fedora)
  - [English: Fedora Host Environment Setup & Fedora on WSL2](#english-fedora-host-environment-setup--fedora-on-wsl2)
  - [Tiếng Việt: Thiết lập môi trường Fedora cho máy chủ & Fedora trên WSL2](#tiếng-việt-thiết-lập-môi-trường-fedora-cho-máy-chủ--fedora-trên-wsl2)
- [APPENDIX / PHỤ LỤC: PRODUCTION LEVEL ALERTING](#appendix--phụ-lục-production-level-alerting)
  - [English: Production Level Alerting Architecture & Practice](#english-production-level-alerting-architecture--practice)
  - [Tiếng Việt: Kiến trúc và Thực hành Cảnh báo Chuẩn Production](#tiếng-việt-kiến-trúc-và-thực-hành-cảnh-báo-chuẩn-production)

---

# ENGLISH VERSION

## PART 1: HOST ENVIRONMENT SETUP (ARCH LINUX)

### 1. Install Virtualization & Networking Tools
**Command:**
```bash
sudo pacman -Syu qemu-desktop libvirt virt-manager dnsmasq iptables-nft
```

**Explanation:**
- `sudo`: Executes the package manager with root administrative privileges.
- `pacman -Syu`: Synchronizes package databases (`-y`) and updates existing packages (`-u`) before installing (`-S`) to prevent partial upgrade states.
- `qemu-desktop`: Installs QEMU (Quick Emulator) with desktop/graphical display support (SPICE, GTK, audio, virtio-gpu). It acts as the hypervisor device emulator.
- `libvirt`: The system daemon and API layer providing unified management for virtual machines, virtual networks, and storage pools.
- `virt-manager`: Graphical desktop application (Virtual Machine Manager) to configure, manage, and view guest VM screens easily.
- `dnsmasq`: Lightweight DNS forwarder and DHCP server used by libvirt to automatically assign private IP addresses (e.g. `192.168.122.x`) to guest VMs.
- `iptables-nft`: The nftables-backed translation layer for iptables rules, allowing libvirt to create NAT (Network Address Translation) firewall rules so VMs can access the Internet through the host machine.

---

### 2. Grant User Permissions for KVM & Libvirt
**Command:**
```bash
sudo usermod -aG libvirt,kvm $USER
```

**Explanation:**
- `usermod`: Modifies user account properties in the system.
- `-aG` (append to Groups): Appends the specified groups without removing the user from other groups.
- `libvirt`: Grants membership to the libvirt group, allowing your non-root user to manage VMs via virsh or virt-manager without sudo.
- `kvm`: Grants read and write access to the hardware-accelerated device node `/dev/kvm`.
- `$USER`: Shell environment variable expanding to your current username (`archlinux`).

---

### 3. Enable and Start the Libvirt Service
**Command:**
```bash
sudo systemctl enable --now libvirtd
```

**Explanation:**
- `systemctl`: Control utility for systemd system and service manager.
- `enable`: Configures the service (and its socket units) to start automatically at boot.
- `--now`: Starts the service immediately in the current session without requiring a reboot.
- `libvirtd`: The main Libvirt background daemon.

---

### 4. Apply New Group Membership to Current Shell Session
**Command:**
```bash
newgrp libvirt
```

**Explanation:**
- In Linux, group membership additions normally require logging out and back in.
- `newgrp` starts a subshell session with the 'libvirt' group ID immediately active, allowing you to test or run virsh commands right away without rebooting.

---

### 5. Set Libvirt Default Virtual Network to Auto-Start
**Command:**
```bash
sudo virsh net-autostart default
```

**Explanation:**
- `virsh`: Command-line interface for managing libvirt guest domains and networks.
- `net-autostart`: Marks the specified virtual network to be automatically brought up whenever libvirtd starts (including system reboot).
- `default`: The default virtual NAT network defined by libvirt (subnet `192.168.122.0/24`).

---

### 6. Reload Firewall Daemon Configuration
**Command:**
```bash
sudo firewall-cmd --reload
```

**Explanation:**
- `firewall-cmd`: Command-line client for firewalld.
- `--reload`: Reloads firewall rules and zones from disk without interrupting active connections.
- **Why this is needed:** Installing libvirt installs a new firewalld zone file (`/usr/lib/firewalld/zones/libvirt.xml`). Because firewalld was already running, it must reload its definitions so it recognizes the 'libvirt' zone and allows virsh to attach the virtual bridge (`virbr0`) without throwing zone lookup errors.

---

### 7. Start the Virtual Network
**Command:**
```bash
sudo virsh net-start default
```

**Explanation:**
- `net-start`: Activates the specified virtual network.
- Creates the virtual bridge interface `virbr0` on the host, spawns a dnsmasq instance for DHCP/DNS, and configures NAT forwarding rules.

---

### 8. Verify Network Status
**Command:**
```bash
sudo virsh net-list --all
```

**Explanation:**
- Lists all configured virtual networks and displays their operational status (State: active) and persistence setting (Autostart: yes).

---

## PART 2: VIRTUAL MACHINE PROVISIONING (AUTOMATED VIA CLOUD IMAGE)

**Requirements per syllabus:**
- **VM 1 (Monitoring Server):**
  - Name: `mon-server`
  - RAM: `1536 MB` (1.5 GB)
  - vCPU: `2`
  - Disk: `15 GB`
  - OS: `Debian 12 (Bookworm)`
  - IP Assigned: `192.168.122.54`
  - Services to run: Prometheus (`:9090`), Grafana (`:3000`), Alertmanager (`:9093`)

- **VM 2 (Target Node):**
  - Name: `mon-target`
  - RAM: `512 MB`
  - vCPU: `1`
  - Disk: `10 GB`
  - OS: `Debian 12 (Bookworm)`
  - IP Assigned: `192.168.122.89`
  - Services to run: Node Exporter (`:9100`), `stress-ng`

---

### 1. Download Official Debian 12 Minimal Cloud Image
**Command:**
```bash
wget -O debian-12-generic-amd64.qcow2 https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2
```

**Explanation:**
- `wget`: Network downloader.
- `-O`: Saves the downloaded file under the specified filename.
- `debian-12-generic-amd64.qcow2`: Pre-installed, minimal Debian 12 cloud image supporting cloud-init configuration on first boot.

---

### 2. Create Independent Copy-on-Write (CoW) Overlay Disks
**Commands:**
```bash
mkdir -p ~/vms
qemu-img create -f qcow2 -F qcow2 -b ~/debian-12-generic-amd64.qcow2 ~/vms/mon-server.qcow2 15G
qemu-img create -f qcow2 -F qcow2 -b ~/debian-12-generic-amd64.qcow2 ~/vms/mon-target.qcow2 10G
```

**Explanation:**
- `qemu-img create`: Utility to initialize virtual disk image files.
- `-f qcow2`: Target disk format (QEMU Copy-On-Write version 2).
- `-F qcow2`: Specifies the format of the underlying backing file.
- `-b ~/debian-12-generic-amd64.qcow2`: Base template image. All read operations come from this base file until modified.
- `~/vms/mon-server.qcow2 15G`: Creates an overlay disk for VM 1 with a virtual capacity expanded to 15 GB.
- `~/vms/mon-target.qcow2 10G`: Creates an overlay disk for VM 2 with a virtual capacity expanded to 10 GB.
- **Why CoW:** Avoids duplicating the base 430 MB image, saving disk space and allowing instant provisioning without touching the original base file.

---

### 3. Prepare Cloud-Init Credentials
**Command:**
```bash
echo "debian" > /tmp/vm-pass.txt
```

**Explanation:**
- Creates a temporary file holding the default password (`debian`) to be injected into the cloud-init user accounts (both root and debian user) so console/sudo access works immediately.

---

### 4. Provision and Launch VM 1 (mon-server)
**Command:**
```bash
virt-install --connect qemu:///system \
  --name mon-server \
  --memory 1536 \
  --vcpus 2 \
  --os-variant debian12 \
  --disk path=/home/archlinux/vms/mon-server.qcow2,device=disk,bus=virtio \
  --network network=default,model=virtio \
  --cloud-init root-password-file=/tmp/vm-pass.txt,clouduser-ssh-key=/home/archlinux/.ssh/id_ed25519.pub \
  --import \
  --noautoconsole
```

**Explanation:**
- `virt-install`: Command-line tool for provisioning new virtual machines under libvirt.
- `--connect qemu:///system`: Directs the connection to the system-level hypervisor daemon.
- `--name mon-server`: Unique domain name for the VM.
- `--memory 1536`: Allocates 1536 MiB (1.5 GB) RAM.
- `--vcpus 2`: Allocates 2 virtual CPU cores.
- `--os-variant debian12`: Tells libvirt to tune kernel and device configurations for Debian 12.
- `--disk path=...,bus=virtio`: Attaches the CoW disk using high-performance paravirtualized virtio bus.
- `--network network=default,model=virtio`: Connects VM to `virbr0` with virtio NIC driver.
- `--cloud-init root-password-file=...,clouduser-ssh-key=...`: Generates a temporary cloud-init NoCloud ISO that injects the host's SSH public key into `~/.ssh/authorized_keys` for the `debian` user and sets the root/user password.
- `--import`: Tells virt-install to boot directly from an existing installed disk image rather than starting an OS installer.
- `--noautoconsole`: Returns back to the shell prompt instead of locking into the VM serial console.

---

### 5. Provision and Launch VM 2 (mon-target)
**Command:**
```bash
virt-install --connect qemu:///system \
  --name mon-target \
  --memory 512 \
  --vcpus 1 \
  --os-variant debian12 \
  --disk path=/home/archlinux/vms/mon-target.qcow2,device=disk,bus=virtio \
  --network network=default,model=virtio \
  --cloud-init root-password-file=/tmp/vm-pass.txt,clouduser-ssh-key=/home/archlinux/.ssh/id_ed25519.pub \
  --import \
  --noautoconsole
```

**Explanation:**
- Same parameters as above, tailored for VM 2 specs (512 MiB RAM, 1 vCPU, 10 GB disk).
- Clean up password file after creation:
  ```bash
  rm /tmp/vm-pass.txt
  ```

---

### 6. Verify Running VMs and Inspect IP Addresses
**Commands:**
```bash
virsh -c qemu:///system list
virsh -c qemu:///system domifaddr mon-server
virsh -c qemu:///system domifaddr mon-target
virsh -c qemu:///system net-dhcp-leases default
```

**Explanation:**
- `domifaddr`: Queries the VM interface addresses allocated via libvirt DHCP.
- **IP Allocations for this session:**
  - `mon-server`: `192.168.122.54`
  - `mon-target`: `192.168.122.89`

---

### 7. Access VMs via SSH from Arch Host
**Commands:**
```bash
ssh debian@192.168.122.54   # Log into mon-server
ssh debian@192.168.122.89   # Log into mon-target
```

**Explanation:**
- Authenticates securely with your host SSH key (`id_ed25519`) without prompting for passwords.
- The default username is `debian` with full sudo capabilities (password: `debian`).

---

## PART 3: CONFIGURING TARGET VM (mon-target, 512MB RAM)

Log into VM 2 (via console or SSH):

### 1. Install Node Exporter and Stress Testing Tool
**Commands (Debian/Ubuntu):**
```bash
sudo apt update
sudo apt install -y prometheus-node-exporter stress-ng
```

**Explanation:**
- `prometheus-node-exporter`: Daemon that collects system hardware and OS metrics from the Linux kernel (`/proc`, `/sys`) and exposes them via HTTP in Prometheus format.
- `stress-ng`: Workload generation tool used to stress CPU, RAM, and I/O to trigger performance thresholds during the alert demo.

---

### 2. Enable and Start Node Exporter
**Commands:**
```bash
sudo systemctl enable --now prometheus-node-exporter
```

**Explanation:**
- Ensures the exporter runs on boot and starts listening immediately on port 9100.

---

### 3. Verify Node Exporter Metrics Output Locally
**Command:**
```bash
curl http://localhost:9100/metrics | head -n 30
```

**Explanation:**
- `curl`: HTTP client to fetch web content from the command line.
- `http://localhost:9100/metrics`: The standard endpoint where Node Exporter presents plain-text time-series metrics.
- `head -n 30`: Prints the first 30 lines to confirm metrics (HELP and TYPE descriptors).

---

### 4. Find the Target VM's IP Address
**Command:**
```bash
ip -br addr show
```

**Explanation:**
- Displays IP addresses in brief tabular format. Note the IP assigned on interface `enp1s0` or `eth0` (e.g., `192.168.122.50`). You will use this IP in VM 1's config.

---

## PART 4: CONFIGURING MONITORING SERVER (mon-server, 1.5GB RAM)

Log into VM 1:

### 1. Install Prometheus, Alertmanager, and Grafana
**Commands (Debian/Ubuntu):**
```bash
# Install Prometheus & Alertmanager from official Debian repositories
sudo apt update
sudo apt install -y prometheus prometheus-alertmanager

# Install Grafana from official Grafana Labs repository (Debian 12 doesn't include grafana in base repos)
sudo apt install -y apt-transport-https software-properties-common wget gpg
sudo mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
sudo apt update
sudo apt install -y grafana
```

**Explanation:**
- `prometheus`: Time-series database engine that scrapes and evaluates alert rules.
- `prometheus-alertmanager`: Receives alert triggers from Prometheus, deduplicates, groups, and routes notifications.
- `grafana`: Interactive web UI for query visualization and dashboard creation.
- `apt-transport-https`, `wget`, `gpg`: Prerequisites to securely fetch and verify Grafana's signed APT repository via HTTPS using GPG authentication keys.

---

### 2. Configure Prometheus (Scrape Target & Rule Files)
**Edit configuration:**
```bash
sudo nano /etc/prometheus/prometheus.yml
```

**Configure complete `/etc/prometheus/prometheus.yml`:**
```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "/etc/prometheus/alert_rules.yml"

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "node_exporter"
    scrape_interval: 5s
    static_configs:
      - targets: ["192.168.122.89:9100"]
```

**Explanation:**
- `rule_files`: Directs Prometheus to load alert definitions from `/etc/prometheus/alert_rules.yml`.
- `job_name`: Label used to identify the group of instances being monitored.
- `scrape_interval`: Frequency at which Prometheus issues HTTP GET requests to `/metrics`. Set to 5s for fast real-time lab demonstrations.
- `targets`: The IP address and port of VM 2's Node Exporter.

---

### 3. Configure Alert Rule for High CPU Usage
**Create rule file:**
```bash
sudo nano /etc/prometheus/alert_rules.yml
```

**Add content:**
```yaml
groups:
  - name: host_alerts
    rules:
      - alert: HighCPUUsage
        expr: 100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[1m])) * 100) > 80
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "Instance {{ $labels.instance }} High CPU Usage"
          description: "CPU usage has exceeded 80% for more than 1 minute (Current: {{ $value }}%)."
```

**Explanation:**
- `alert`: Name of the alert.
- `expr`: PromQL condition. Calculates non-idle CPU percentage over the last 1 minute. Fires if > 80%.
- `for: 1m`: Must remain true continuously for 1 minute before firing (transitions from Inactive -> Pending -> Firing).
- Link this file into `/etc/prometheus/prometheus.yml` under:
  ```yaml
  rule_files:
    - "/etc/prometheus/alert_rules.yml"
  ```

---

### 4. Enable and Restart Monitoring Services
**Commands:**
```bash
sudo systemctl enable --now prometheus
sudo systemctl enable --now prometheus-alertmanager
sudo systemctl enable --now grafana-server
sudo systemctl restart prometheus
```

**Explanation:**
- Applies all configuration changes and verifies that all services are active.
- Grafana is now accessible at `http://192.168.122.54:3000` (default login: `admin`/`admin`).
- Prometheus UI is accessible at `http://192.168.122.54:9090`.
- Alertmanager UI is accessible at `http://192.168.122.54:9093`.

---

## PART 5: MANDATORY DEMO EXECUTION

### DEMO 1: Real-time Dashboard in Grafana
**Steps:**
1. Open web browser on Host: `http://192.168.122.54:3000`
2. Default user account and password is `admin`/`admin`.
3. Navigate to **Connections** -> **Data Sources** -> **Add Prometheus**.  
   Set URL: `http://localhost:9090` and click **"Save & test"**.
4. Go to **Dashboards** -> **Import** -> Enter ID `"1860"` (Node Exporter Full) -> **Load**.
5. Select the Prometheus data source and click **Import**.

**Result:** Full live visualization of CPU, RAM, Disk, and Network for the target VM.

---

### DEMO 2: PromQL Queries & Rate Explanation
Execute these in Prometheus Web UI (`http://192.168.122.54:9090/graph`):

1. **Real-time CPU Usage (%):**
   ```promql
   100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[1m])) * 100)
   ```
   - **Why rate() is mandatory:** `node_cpu_seconds_total` is a monotonically increasing `COUNTER` tracking total seconds CPU spent in states since boot. A raw counter value cannot represent current load; `rate()` calculates per-second increase over a 1-minute time window.

2. **RAM Usage (%):**
   ```promql
   (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100
   ```
   - Uses `GAUGE` metrics representing absolute values fluctuating up and down.

3. **Root Filesystem Disk Usage (%):**
   ```promql
   (1 - (node_filesystem_free_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"})) * 100
   ```
   - Calculates used percentage of disk space by filtering on `mountpoint="/"`.

---

### DEMO 3: Alert Lifecycle Simulation (Pending -> Firing)

1. On VM 2 (`mon-target`), run:
   ```bash
   stress-ng --cpu 1 --timeout 120s
   ```
   **Explanation:**
   - `--cpu 1`: Maxes out 1 CPU core to 100%.
   - `--timeout 120s`: Runs the workload for 2 minutes.

2. On VM 1 (`mon-server`), open Prometheus UI -> **Alerts** tab:
   - **0s - 10s:** Rule matches -> State becomes **PENDING** (yellow).
   - **At 60s:** Duration threshold met -> State becomes **FIRING** (red).
   - Open Alertmanager UI (`:9093`) to show the active firing alert.
   - **After 120s:** `stress-ng` exits, CPU drops -> State returns to **INACTIVE** (green).

---

### DEMO 4: Troubleshooting ("Lost Exporter" vs. "Dead Host")

**Objective:**
Demonstrate that Prometheus metric `up{job="node_exporter"} == 0` only indicates metric collection failure. Sysadmins must combine it with network-level checks (`ping`) to distinguish between application crashes and total infrastructure outages.

#### Case A: Node Exporter Process Failure (Target Host is ALIVE, Service DEAD)
1. Simulate service failure on `mon-target` (VM 2):
   ```bash
   sudo systemctl stop prometheus-node-exporter
   ```

2. Verify metric status on `mon-server` (Prometheus Web UI `http://192.168.122.54:9090/graph`):
   - **Query:**
     ```promql
     up{job="node_exporter"}
     ```
   - **Result:** Value drops from `1` to `0`.

3. Run network connectivity check on `mon-server` terminal:
   ```bash
   ping -c 3 192.168.122.89
   ```
   - **Observed Output:**
     ```text
     3 packets transmitted, 3 received, 0% packet loss, time ...
     ```
     *(ICMP replies received; IP network layer and Linux kernel on VM 2 are alive).*

4. **Diagnostic Conclusion:**
   - The machine hardware, OS, and networking are completely healthy.
   - **Root cause:** The exporter daemon crashed or was manually stopped.
   - **Remediation:** No physical or virtualization intervention needed. Just inspect service logs (`journalctl -u prometheus-node-exporter`) and restart the daemon:  
     On `mon-target`:
     ```bash
     sudo systemctl start prometheus-node-exporter
     ```
   - Verify recovery on Prometheus UI: `up{job="node_exporter"}` transitions back to `1`.

#### Case B: Full Host Crash (Target Host is COMPLETELY DEAD / Powered Off)
1. Simulate sudden server crash / power failure on `mon-target` (VM 2):
   ```bash
   sudo poweroff
   ```

2. Verify metric status on `mon-server` (Prometheus Web UI `http://192.168.122.54:9090/graph`):
   - **Query:**
     ```promql
     up{job="node_exporter"}
     ```
   - **Result:** Value remains `0` (or shows `"context deadline exceeded / connection refused"`).

3. Run network connectivity check on `mon-server` terminal:
   ```bash
   ping -c 3 192.168.122.89
   ```
   - **Observed Output:**
     ```text
     From 192.168.122.54 icmp_seq=1 Destination Host Unreachable
     3 packets transmitted, 0 received, +3 errors, 100% packet loss.
     ```

4. **Diagnostic Conclusion:**
   - Total infrastructure failure (Power outage, Kernel Panic, VM crash, or network isolation).
   - **Remediation:** SSH is impossible. Requires hypervisor/datacenter-level intervention.  
     From Arch Host machine:
     ```bash
     virsh -c qemu:///system start mon-target
     ```
   - After booting up, verify VM recovery:
     ```bash
     ping -c 3 192.168.122.89  # (0% packet loss)
     ```
     *(In Prometheus UI: `up{job="node_exporter"}` returns to `1`)*.

---

# PHIÊN BẢN TIẾNG VIỆT

## BÀI THỰC HÀNH #10: GIÁM SÁT VỚI PROMETHEUS & GRAFANA - TÀI LIỆU HƯỚNG DẪN & TRA CỨU LỆNH ĐẦY ĐỦ
**Tệp:** `/home/archlinux/Projects/Linux/seminar.md`

Tài liệu này bao gồm toàn bộ các câu lệnh được khuyến nghị để thiết lập môi trường, khởi tạo các máy ảo, triển khai hệ thống giám sát (monitoring stack), và thực hiện các bài demo bắt buộc cho Seminar Lab #10. Mỗi câu lệnh đều đi kèm với giải thích chi tiết về chức năng và lý do cần thiết.

---

## PHẦN 1: THIẾT LẬP MÔI TRƯỜNG MÁY CHỦ (ARCH LINUX)

### 1. Cài đặt các công cụ ảo hóa & mạng
**Câu lệnh:**
```bash
sudo pacman -Syu qemu-desktop libvirt virt-manager dnsmasq iptables-nft
```

**Giải thích:**
- `sudo`: Thực thi trình quản lý gói với đặc quyền quản trị viên (root).
- `pacman -Syu`: Đồng bộ hóa cơ sở dữ liệu gói (`-y`) và cập nhật các gói hiện có (`-u`) trước khi cài đặt (`-S`) để tránh tình trạng nâng cấp không đồng bộ (partial upgrade).
- `qemu-desktop`: Cài đặt QEMU (Quick Emulator) hỗ trợ giao diện đồ họa/desktop (SPICE, GTK, âm thanh, virtio-gpu). Nó đóng vai trò là trình giả lập thiết bị hypervisor.
- `libvirt`: System daemon và tầng API cung cấp khả năng quản lý thống nhất cho các máy ảo, mạng ảo và vùng lưu trữ (storage pools).
- `virt-manager`: Ứng dụng đồ họa trên desktop (Virtual Machine Manager) giúp cấu hình, quản lý và xem màn hình máy ảo khách (guest VM) một cách dễ dàng.
- `dnsmasq`: Dịch vụ chuyển tiếp DNS và máy chủ DHCP dung lượng nhẹ được libvirt sử dụng để tự động cấp phát địa chỉ IP nội bộ (ví dụ: `192.168.122.x`) cho các máy ảo khách.
- `iptables-nft`: Lớp biên dịch trên nền tảng nftables cho các quy tắc iptables, cho phép libvirt tạo các quy tắc tường lửa NAT (Network Address Translation) để các máy ảo có thể truy cập Internet thông qua máy chủ (host).

---

### 2. Cấp quyền người dùng cho KVM & Libvirt
**Câu lệnh:**
```bash
sudo usermod -aG libvirt,kvm $USER
```

**Giải thích:**
- `usermod`: Chỉnh sửa các thuộc tính tài khoản người dùng trong hệ thống.
- `-aG` (append to Groups): Thêm người dùng vào các nhóm được chỉ định mà không xóa người dùng khỏi các nhóm khác.
- `libvirt`: Thêm người dùng vào nhóm libvirt, cho phép tài khoản không phải root quản lý máy ảo thông qua virsh hoặc virt-manager mà không cần sudo.
- `kvm`: Cấp quyền đọc và ghi vào thiết bị tăng tốc phần cứng `/dev/kvm`.
- `$USER`: Biến môi trường shell trả về tên người dùng hiện tại (`archlinux`).

---

### 3. Kích hoạt và khởi chạy dịch vụ Libvirt
**Câu lệnh:**
```bash
sudo systemctl enable --now libvirtd
```

**Giải thích:**
- `systemctl`: Tiện ích điều khiển hệ thống systemd và trình quản lý dịch vụ.
- `enable`: Cấu hình dịch vụ (và các socket unit của nó) tự động khởi chạy khi khởi động máy.
- `--now`: Khởi chạy dịch vụ ngay lập tức trong phiên hiện tại mà không cần khởi động lại máy.
- `libvirtd`: Tiến trình nền (daemon) chính của Libvirt.

---

### 4. Áp dụng quyền thành viên nhóm mới vào phiên Shell hiện tại
**Câu lệnh:**
```bash
newgrp libvirt
```

**Giải thích:**
- Trong Linux, việc thêm người dùng vào nhóm mới thường yêu cầu đăng xuất và đăng nhập lại.
- `newgrp` khởi động một phiên subshell với group ID 'libvirt' được kích hoạt ngay lập tức, cho phép bạn kiểm tra hoặc chạy các lệnh virsh ngay mà không cần khởi động lại.

---

### 5. Cấu hình mạng ảo mặc định của Libvirt tự động khởi chạy
**Câu lệnh:**
```bash
sudo virsh net-autostart default
```

**Giải thích:**
- `virsh`: Giao diện dòng lệnh để quản lý các domain (máy ảo) và mạng của libvirt.
- `net-autostart`: Đánh dấu mạng ảo được chỉ định sẽ tự động kích hoạt mỗi khi libvirtd khởi chạy (bao gồm cả khi khởi động lại hệ thống).
- `default`: Mạng NAT ảo mặc định do libvirt định nghĩa (dải mạng `192.168.122.0/24`).

---

### 6. Tải lại cấu hình tường lửa (Firewall Daemon)
**Câu lệnh:**
```bash
sudo firewall-cmd --reload
```

**Giải thích:**
- `firewall-cmd`: Trình điều khiển dòng lệnh cho firewalld.
- `--reload`: Tải lại các quy tắc tường lửa và vùng (zones) từ đĩa mà không làm gián đoạn các kết nối đang hoạt động.
- **Lý do cần thiết:** Việc cài đặt libvirt sẽ thêm một tệp zone mới cho firewalld (`/usr/lib/firewalld/zones/libvirt.xml`). Do firewalld đã chạy từ trước, nó cần tải lại các định nghĩa để nhận diện zone 'libvirt' và cho phép virsh gắn cầu mạng ảo (`virbr0`) mà không bị lỗi tra cứu zone.

---

### 7. Khởi động mạng ảo
**Câu lệnh:**
```bash
sudo virsh net-start default
```

**Giải thích:**
- `net-start`: Kích hoạt mạng ảo được chỉ định.
- Tạo giao diện cầu ảo `virbr0` trên máy chủ, khởi chạy một tiến trình dnsmasq phục vụ DHCP/DNS, và cấu hình các quy tắc chuyển tiếp NAT.

---

### 8. Kiểm tra trạng thái mạng
**Câu lệnh:**
```bash
sudo virsh net-list --all
```

**Giải thích:**
- Liệt kê tất cả các mạng ảo đã được cấu hình và hiển thị trạng thái hoạt động (State: active) cùng với thiết lập tự khởi động (Autostart: yes).

---

## PHẦN 2: KHỞI TẠO MÁY ẢO (TỰ ĐỘNG HÓA QUA CLOUD IMAGE)

**Yêu cầu theo đề cương:**
- **VM 1 (Máy chủ giám sát - Monitoring Server):**
  - Tên: `mon-server`
  - RAM: `1536 MB` (1.5 GB)
  - vCPU: `2`
  - Dung lượng đĩa: `15 GB`
  - Hệ điều hành: `Debian 12 (Bookworm)`
  - IP được cấp phát: `192.168.122.54`
  - Dịch vụ chạy: Prometheus (`:9090`), Grafana (`:3000`), Alertmanager (`:9093`)

- **VM 2 (Node mục tiêu giám sát - Target Node):**
  - Tên: `mon-target`
  - RAM: `512 MB`
  - vCPU: `1`
  - Dung lượng đĩa: `10 GB`
  - Hệ điều hành: `Debian 12 (Bookworm)`
  - IP được cấp phát: `192.168.122.89`
  - Dịch vụ chạy: Node Exporter (`:9100`), `stress-ng`

---

### 1. Tải Cloud Image tối giản chính thức của Debian 12
**Câu lệnh:**
```bash
wget -O debian-12-generic-amd64.qcow2 https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2
```

**Giải thích:**
- `wget`: Công cụ tải tệp qua mạng.
- `-O`: Lưu tệp đã tải xuống với tên tệp được chỉ định.
- `debian-12-generic-amd64.qcow2`: Image Debian 12 cloud tối giản, cài đặt sẵn, hỗ trợ cấu hình cloud-init ngay trong lần khởi động đầu tiên.

---

### 2. Tạo các đĩa phủ Copy-on-Write (CoW) độc lập
**Các câu lệnh:**
```bash
mkdir -p ~/vms
qemu-img create -f qcow2 -F qcow2 -b ~/debian-12-generic-amd64.qcow2 ~/vms/mon-server.qcow2 15G
qemu-img create -f qcow2 -F qcow2 -b ~/debian-12-generic-amd64.qcow2 ~/vms/mon-target.qcow2 10G
```

**Giải thích:**
- `qemu-img create`: Tiện ích khởi tạo các tệp ảnh đĩa ảo.
- `-f qcow2`: Định dạng đĩa đích (QEMU Copy-On-Write phiên bản 2).
- `-F qcow2`: Chỉ định định dạng của tệp nền (backing file).
- `-b ~/debian-12-generic-amd64.qcow2`: Tệp image mẫu cơ sở. Mọi thao tác đọc đều lấy từ tệp gốc này cho đến khi có dữ liệu được ghi đè/sửa đổi.
- `~/vms/mon-server.qcow2 15G`: Tạo đĩa phủ cho VM 1 với dung lượng ảo mở rộng lên 15 GB.
- `~/vms/mon-target.qcow2 10G`: Tạo đĩa phủ cho VM 2 với dung lượng ảo mở rộng lên 10 GB.
- **Tại sao dùng CoW:** Tránh nhân bản tệp ảnh gốc 430 MB, tiết kiệm dung lượng đĩa và cho phép khởi tạo máy ảo gần như tức thì mà không can thiệp vào tệp gốc.

---

### 3. Chuẩn bị thông tin xác thực cho Cloud-Init
**Câu lệnh:**
```bash
echo "debian" > /tmp/vm-pass.txt
```

**Giải thích:**
- Tạo tệp tạm chứa mật khẩu mặc định (`debian`) để đưa vào các tài khoản người dùng cloud-init (cả tài khoản root và debian) giúp truy cập console/sudo hoạt động ngay.

---

### 4. Khởi tạo và kích hoạt VM 1 (mon-server)
**Câu lệnh:**
```bash
virt-install --connect qemu:///system \
  --name mon-server \
  --memory 1536 \
  --vcpus 2 \
  --os-variant debian12 \
  --disk path=/home/archlinux/vms/mon-server.qcow2,device=disk,bus=virtio \
  --network network=default,model=virtio \
  --cloud-init root-password-file=/tmp/vm-pass.txt,clouduser-ssh-key=/home/archlinux/.ssh/id_ed25519.pub \
  --import \
  --noautoconsole
```

**Giải thích:**
- `virt-install`: Công cụ dòng lệnh để khởi tạo các máy ảo mới dưới sự quản lý của libvirt.
- `--connect qemu:///system`: Điều hướng kết nối tới tiến trình hypervisor ở cấp độ hệ thống.
- `--name mon-server`: Tên domain duy nhất cho máy ảo.
- `--memory 1536`: Phân bổ 1536 MiB (1.5 GB) RAM.
- `--vcpus 2`: Phân bổ 2 nhân CPU ảo.
- `--os-variant debian12`: Báo cho libvirt tối ưu cấu hình kernel và thiết bị cho Debian 12.
- `--disk path=...,bus=virtio`: Gắn đĩa CoW sử dụng bus virtio chuẩn hóa bán ảo hóa hiệu năng cao.
- `--network network=default,model=virtio`: Kết nối máy ảo vào mạng `virbr0` với driver mạng virtio.
- `--cloud-init root-password-file=...,clouduser-ssh-key=...`: Tạo một tệp NoCloud ISO tạm thời để đưa khóa công khai SSH của máy host vào `~/.ssh/authorized_keys` của người dùng `debian` và thiết lập mật khẩu cho root/user.
- `--import`: Yêu cầu virt-install khởi động trực tiếp từ ảnh đĩa đã cài đặt sẵn thay vì chạy trình cài đặt hệ điều hành (OS installer).
- `--noautoconsole`: Trả về dấu nhắc lệnh shell ngay thay vì bị khóa vào serial console của máy ảo.

---

### 5. Khởi tạo và kích hoạt VM 2 (mon-target)
**Câu lệnh:**
```bash
virt-install --connect qemu:///system \
  --name mon-target \
  --memory 512 \
  --vcpus 1 \
  --os-variant debian12 \
  --disk path=/home/archlinux/vms/mon-target.qcow2,device=disk,bus=virtio \
  --network network=default,model=virtio \
  --cloud-init root-password-file=/tmp/vm-pass.txt,clouduser-ssh-key=/home/archlinux/.ssh/id_ed25519.pub \
  --import \
  --noautoconsole
```

**Giải thích:**
- Các tham số tương tự như trên, được tùy chỉnh theo thông số cấu hình VM 2 (512 MiB RAM, 1 vCPU, đĩa 10 GB).
- Xóa tệp mật khẩu tạm thời sau khi khởi tạo:
  ```bash
  rm /tmp/vm-pass.txt
  ```

---

### 6. Kiểm tra các máy ảo đang chạy và xem địa chỉ IP
**Các câu lệnh:**
```bash
virsh -c qemu:///system list
virsh -c qemu:///system domifaddr mon-server
virsh -c qemu:///system domifaddr mon-target
virsh -c qemu:///system net-dhcp-leases default
```

**Giải thích:**
- `domifaddr`: Truy vấn các địa chỉ mạng của máy ảo được cấp phát qua libvirt DHCP.
- **Các địa chỉ IP được cấp phát trong phiên này:**
  - `mon-server`: `192.168.122.54`
  - `mon-target`: `192.168.122.89`

---

### 7. Truy cập máy ảo qua SSH từ máy chủ Arch
**Các câu lệnh:**
```bash
ssh debian@192.168.122.54   # Đăng nhập vào mon-server
ssh debian@192.168.122.89   # Đăng nhập vào mon-target
```

**Giải thích:**
- Xác thực bảo mật bằng SSH key của máy host (`id_ed25519`) mà không cần nhập mật khẩu.
- Tên người dùng mặc định là `debian` với đầy đủ quyền sudo (mật khẩu: `debian`).

---

## PHẦN 3: CẤU HÌNH MÁY ẢO MỤC TIÊU (mon-target, 512MB RAM)

Đăng nhập vào VM 2 (thông qua console hoặc SSH):

### 1. Cài đặt Node Exporter và công cụ kiểm thử tải (Stress Testing)
**Các câu lệnh (Debian/Ubuntu):**
```bash
sudo apt update
sudo apt install -y prometheus-node-exporter stress-ng
```

**Giải thích:**
- `prometheus-node-exporter`: Tiến trình dịch vụ thu thập các chỉ số phần cứng và hệ điều hành từ Linux kernel (`/proc`, `/sys`) và xuất chúng qua HTTP dưới định dạng chuẩn của Prometheus.
- `stress-ng`: Công cụ tạo tải công việc được sử dụng để ép tải CPU, RAM và I/O nhằm kích hoạt các ngưỡng cảnh báo trong bài demo alert.

---

### 2. Kích hoạt và khởi chạy Node Exporter
**Các câu lệnh:**
```bash
sudo systemctl enable --now prometheus-node-exporter
```

**Giải thích:**
- Đảm bảo exporter tự khởi động cùng hệ thống và bắt đầu lắng nghe ngay trên cổng 9100.

---

### 3. Kiểm tra kết quả xuất chỉ số (Metrics) của Node Exporter cục bộ
**Câu lệnh:**
```bash
curl http://localhost:9100/metrics | head -n 30
```

**Giải thích:**
- `curl`: Trình gửi yêu cầu HTTP để lấy nội dung web từ giao diện dòng lệnh.
- `http://localhost:9100/metrics`: Điểm cuối chuẩn (endpoint) nơi Node Exporter cung cấp các chuỗi thời gian (time-series metrics) dưới dạng văn bản thuần.
- `head -n 30`: In ra 30 dòng đầu tiên để xác nhận các chỉ số (các bộ mô tả HELP và TYPE).

---

### 4. Tìm địa chỉ IP của máy ảo mục tiêu
**Câu lệnh:**
```bash
ip -br addr show
```

**Giải thích:**
- Hiển thị các địa chỉ IP dưới định dạng bảng ngắn gọn. Ghi nhận IP được gán trên giao diện `enp1s0` hoặc `eth0` (ví dụ: `192.168.122.50`). Bạn sẽ sử dụng IP này trong cấu hình của VM 1.

---

## PHẦN 4: CẤU HÌNH MÁY CHỦ GIÁM SÁT (mon-server, 1.5GB RAM)

Đăng nhập vào VM 1:

### 1. Cài đặt Prometheus, Alertmanager và Grafana
**Các câu lệnh (Debian/Ubuntu):**
```bash
# Cài đặt Prometheus & Alertmanager từ kho lưu trữ chính thức của Debian
sudo apt update
sudo apt install -y prometheus prometheus-alertmanager

# Cài đặt Grafana từ kho lưu trữ chính thức của Grafana Labs (Debian 12 không có grafana trong kho cơ sở)
sudo apt install -y apt-transport-https software-properties-common wget gpg
sudo mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
sudo apt update
sudo apt install -y grafana
```

**Giải thích:**
- `prometheus`: Hệ cơ sở dữ liệu chuỗi thời gian (time-series database) chịu trách nhiệm thu thập (scrape) và đánh giá các quy tắc cảnh báo (alert rules).
- `prometheus-alertmanager`: Tiếp nhận các cảnh báo được kích hoạt từ Prometheus, khử trùng lặp (deduplicate), nhóm lại và định tuyến gửi thông báo.
- `grafana`: Giao diện web trực quan tương tác phục vụ việc truy vấn dữ liệu và tạo bảng điều khiển (dashboard).
- `apt-transport-https`, `wget`, `gpg`: Các gói điều kiện cần để tải về và xác thực an toàn kho lưu trữ APT đã ký của Grafana qua HTTPS bằng khóa xác thực GPG.

---

### 2. Cấu hình Prometheus (Mục tiêu thu thập & Tệp quy tắc)
**Chỉnh sửa cấu hình:**
```bash
sudo nano /etc/prometheus/prometheus.yml
```

**Nội dung cấu hình đầy đủ của `/etc/prometheus/prometheus.yml`:**
```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "/etc/prometheus/alert_rules.yml"

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

    - job_name: "node_exporter"
      scrape_interval: 5s
      static_configs:
        - targets: ["192.168.122.89:9100"]
```

**Giải thích:**
- `rule_files`: Chỉ dẫn Prometheus tải các định nghĩa quy tắc cảnh báo từ `/etc/prometheus/alert_rules.yml`.
- `job_name`: Nhãn định danh cho nhóm các thực thể (instances) được giám sát.
- `scrape_interval`: Tần suất Prometheus gửi yêu cầu HTTP GET đến `/metrics`. Đặt là 5s để phục vụ các bài trình diễn trực tiếp nhanh chóng trong phòng lab.
- `targets`: Địa chỉ IP và cổng của Node Exporter trên VM 2.

---

### 3. Cấu hình quy tắc cảnh báo khi mức sử dụng CPU cao (High CPU Usage)
**Tạo tệp quy tắc:**
```bash
sudo nano /etc/prometheus/alert_rules.yml
```

**Thêm nội dung:**
```yaml
groups:
  - name: host_alerts
    rules:
      - alert: HighCPUUsage
        expr: 100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[1m])) * 100) > 80
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "Instance {{ $labels.instance }} High CPU Usage"
          description: "CPU usage has exceeded 80% for more than 1 minute (Current: {{ $value }}%)."
```

**Giải thích:**
- `alert`: Tên cảnh báo.
- `expr`: Điều kiện PromQL. Tính toán phần trăm CPU không ở trạng thái rảnh rỗi (non-idle) trong 1 phút qua. Cảnh báo kích hoạt nếu > 80%.
- `for: 1m`: Điều kiện phải duy trì đúng liên tục trong 1 phút trước khi kích hoạt chính thức (chuyển đổi từ Inactive -> Pending -> Firing).
- Khai báo liên kết tệp này vào `/etc/prometheus/prometheus.yml` dưới mục:
  ```yaml
  rule_files:
    - "/etc/prometheus/alert_rules.yml"
  ```

---

### 4. Kích hoạt và khởi động lại các dịch vụ giám sát
**Các câu lệnh:**
```bash
sudo systemctl enable --now prometheus
sudo systemctl enable --now prometheus-alertmanager
sudo systemctl enable --now grafana-server
sudo systemctl restart prometheus
```

**Giải thích:**
- Áp dụng tất cả các thay đổi cấu hình và xác nhận rằng tất cả dịch vụ đều đang hoạt động.
- Grafana hiện có thể truy cập tại `http://192.168.122.54:3000` (đăng nhập mặc định: `admin`/`admin`).
- Giao diện Prometheus truy cập tại `http://192.168.122.54:9090`.
- Giao diện Alertmanager truy cập tại `http://192.168.122.54:9093`.

---

## PHẦN 5: THỰC HIỆN CÁC BÀI DEMO BẮT BUỘC

### DEMO 1: Bảng điều khiển thời gian thực trên Grafana
**Các bước thực hiện:**
1. Mở trình duyệt web trên máy Host: `http://192.168.122.54:3000`
2. Tài khoản và mật khẩu mặc định là `admin`/`admin`.
3. Điều hướng tới **Connections** -> **Data Sources** -> **Add Prometheus**.  
   Đặt URL: `http://localhost:9090` và nhấn **"Save & test"**.
4. Truy cập **Dashboards** -> **Import** -> Nhập ID `"1860"` (Node Exporter Full) -> **Load**.
5. Chọn nguồn dữ liệu Prometheus và nhấn **Import**.

**Kết quả:** Trực quan hóa trực tiếp toàn bộ dữ liệu CPU, RAM, Ổ đĩa và Mạng của máy ảo mục tiêu.

---

### DEMO 2: Truy vấn PromQL & Giải thích hàm rate()
Thực thi các câu truy vấn này trong giao diện web Prometheus (`http://192.168.122.54:9090/graph`):

1. **Mức sử dụng CPU thời gian thực (%):**
   ```promql
   100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[1m])) * 100)
   ```
   - **Lý do bắt buộc dùng hàm rate():** `node_cpu_seconds_total` là một chỉ số `COUNTER` tăng đơn điệu theo thời gian ghi lại tổng số giây CPU đã trải qua ở các trạng thái kể từ khi khởi động. Giá trị thô của bộ đếm không thể biểu diễn tải hiện tại; hàm `rate()` tính toán mức tăng trên mỗi giây trong một khoảng thời gian 1 phút.

2. **Mức sử dụng RAM (%):**
   ```promql
   (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100
   ```
   - Sử dụng các chỉ số `GAUGE` đại diện cho các giá trị tuyệt đối có thể tăng hoặc giảm liên tục.

3. **Mức sử dụng đĩa hệ thống tệp gốc (%):**
   ```promql
   (1 - (node_filesystem_free_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"})) * 100
   ```
   - Tính toán phần trăm dung lượng đĩa đã sử dụng bằng cách lọc theo `mountpoint="/"`.

---

### DEMO 3: Mô phỏng vòng đời cảnh báo (Alert Lifecycle: Pending -> Firing)

1. Trên VM 2 (`mon-target`), chạy lệnh:
   ```bash
   stress-ng --cpu 1 --timeout 120s
   ```
   **Giải thích:**
   - `--cpu 1`: Ép 1 nhân CPU hoạt động hết công suất 100%.
   - `--timeout 120s`: Duy trì tải công việc trong vòng 2 phút.

2. Trên VM 1 (`mon-server`), mở giao diện Prometheus UI -> tab **Alerts**:
   - **Từ 0s - 10s:** Khớp quy tắc -> Trạng thái chuyển thành **PENDING** (màu vàng).
   - **Tại 60s:** Đạt ngưỡng thời gian duy trì -> Trạng thái chuyển thành **FIRING** (màu đỏ).
   - Mở giao diện Alertmanager UI (`:9093`) để xem cảnh báo đang kích hoạt (firing).
   - **Sau 120s:** `stress-ng` kết thúc, CPU hạ nhiệt -> Trạng thái trở về **INACTIVE** (màu xanh lá).

---

### DEMO 4: Xử lý sự cố ("Mất Exporter" vs. "Sập Host hoàn toàn")

**Mục tiêu:**
Chứng minh rằng chỉ số Prometheus `up{job="node_exporter"} == 0` chỉ phản ánh sự cố thu thập chỉ số (metrics). Quản trị viên hệ thống (Sysadmin) phải kết hợp kiểm tra ở tầng mạng (lệnh `ping`) để phân biệt giữa việc ứng dụng bị sập và toàn bộ hạ tầng ngừng hoạt động.

#### Trường hợp A: Tiến trình Node Exporter gặp sự cố (Host mục tiêu VẪN SỐNG, Dịch vụ CHẾT)
1. Mô phỏng sự cố dừng dịch vụ trên `mon-target` (VM 2):
   ```bash
   sudo systemctl stop prometheus-node-exporter
   ```

2. Kiểm tra trạng thái chỉ số trên `mon-server` (Prometheus Web UI `http://192.168.122.54:9090/graph`):
   - **Truy vấn:**
     ```promql
     up{job="node_exporter"}
     ```
   - **Kết quả:** Giá trị giảm từ `1` xuống `0`.

3. Kiểm tra khả năng kết nối mạng trên terminal của `mon-server`:
   ```bash
   ping -c 3 192.168.122.89
   ```
   - **Kết quả quan sát:**
     ```text
     3 packets transmitted, 3 received, 0% packet loss, time ...
     ```
     *(Đã nhận được phản hồi ICMP; tầng mạng IP và Linux kernel trên VM 2 vẫn hoạt động bình thường).*

4. **Kết luận chẩn đoán:**
   - Phần cứng, hệ điều hành và mạng của máy ảo hoàn toàn khỏe mạnh.
   - **Nguyên nhân gốc rễ:** Tiến trình daemon của exporter đã bị sập hoặc bị dừng thủ công.
   - **Cách khắc phục:** Không cần can thiệp vật lý hay ảo hóa. Chỉ cần kiểm tra nhật ký dịch vụ (`journalctl -u prometheus-node-exporter`) và khởi động lại daemon:  
     Trên `mon-target`:
     ```bash
     sudo systemctl start prometheus-node-exporter
     ```
   - Xác nhận phục hồi trên Prometheus UI: `up{job="node_exporter"}` chuyển trạng thái trở lại `1`.

#### Trường hợp B: Sập toàn bộ máy chủ (Host mục tiêu HOÀN TOÀN TẮT / Mất nguồn)
1. Mô phỏng máy chủ bị sập đột ngột / mất nguồn trên `mon-target` (VM 2):
   ```bash
   sudo poweroff
   ```

2. Kiểm tra trạng thái chỉ số trên `mon-server` (Prometheus Web UI `http://192.168.122.54:9090/graph`):
   - **Truy vấn:**
     ```promql
     up{job="node_exporter"}
     ```
   - **Kết quả:** Giá trị giữ nguyên là `0` (hoặc hiển thị `"context deadline exceeded / connection refused"`).

3. Kiểm tra khả năng kết nối mạng trên terminal của `mon-server`:
   ```bash
   ping -c 3 192.168.122.89
   ```
   - **Kết quả quan sát:**
     ```text
     From 192.168.122.54 icmp_seq=1 Destination Host Unreachable
     3 packets transmitted, 0 received, +3 errors, 100% packet loss.
     ```

4. **Kết luận chẩn đoán:**
   - Toàn bộ hạ tầng gặp sự cố (Mất nguồn, Kernel Panic, sập máy ảo, hoặc cô lập mạng).
   - **Cách khắc phục:** Không thể truy cập qua SSH. Yêu cầu can thiệp ở tầng hypervisor / trung tâm dữ liệu.  
     Từ máy chủ Arch Host:
     ```bash
     virsh -c qemu:///system start mon-target
     ```
   - Sau khi máy ảo khởi động xong, kiểm tra phục hồi:
     ```bash
     ping -c 3 192.168.122.89  # (0% packet loss)
     ```
     *(Trên giao diện Prometheus UI: `up{job="node_exporter"}` quay trở lại giá trị `1`)*.


---

# APPENDIX / PHỤ LỤC: WSL2 GUIDE FOR WINDOWS USERS / HƯỚNG DẪN WSL2 CHO WINDOWS

---

## ENGLISH: GETTING STARTED WITH WSL2 (WINDOWS SUBSYSTEM FOR LINUX)

### 1. Introduction
Windows Subsystem for Linux 2 (WSL2) allows Windows 10 and 11 users to run a genuine Linux kernel inside a lightweight virtual machine. It provides full system call compatibility, fast file system performance, and native Linux package management (`apt`), making it ideal for practicing Linux administration, networking, and monitoring without dual-booting.

### 2. Prerequisites
- **OS:** Windows 10 (Version 2004, Build 19041 or higher) or Windows 11.
- **Hardware Virtualization:** Enabled in BIOS/UEFI (Intel VT-x or AMD-V).
- *Verify:* Open Windows **Task Manager** &rarr; **Performance** tab &rarr; **CPU** &rarr; check **"Virtualization: Enabled"**.

### 3. Installing WSL2 on Windows
Open **PowerShell** or **Command Prompt** as Administrator and run:
```powershell
wsl --install
```

> [!NOTE]
> - This command automatically enables the required Windows features (Virtual Machine Platform, Windows Subsystem for Linux), downloads the latest Linux kernel, and installs Ubuntu by default.
> - To install **Debian 12** specifically (matching this lab):
>   ```powershell
>   wsl --install -d Debian
>   ```
> - To list all available Linux distributions:
>   ```powershell
>   wsl --list --online
>   ```
> - Restart your PC if prompted by Windows.

### 4. Basic WSL Management Commands (Run in Windows PowerShell)
- **Check installed distros and WSL versions:**
  ```powershell
  wsl --list --verbose   # or: wsl -l -v
  ```
- **Set WSL2 as default version:**
  ```powershell
  wsl --set-default-version 2
  ```
- **Shut down all running WSL instances:**
  ```powershell
  wsl --shutdown
  ```
- **Launch default Linux distro:**
  ```powershell
  wsl
  ```

### 5. Initial Linux Setup inside WSL2
When opening WSL for the first time, create your Linux username and password. Then update packages:
```bash
sudo apt update && sudo apt upgrade -y
```

Install essential command-line tools:
```bash
sudo apt install -y build-essential curl wget git htop net-tools dnsutils jq
```

### 6. Enable systemd in WSL2 (Required for `systemctl` services)
Modern WSL2 supports `systemd`, which is needed to run background services like `libvirtd`, `prometheus`, and `grafana-server` via `systemctl`.

Edit `/etc/wsl.conf` inside WSL:
```bash
sudo nano /etc/wsl.conf
```

Add the following lines:
```ini
[boot]
systemd=true
```

Save (`Ctrl+O`, `Enter`) and exit (`Ctrl+X`). In PowerShell, restart WSL:
```powershell
wsl --shutdown
```
Reopen WSL and verify:
```bash
systemctl status
```

### 7. Enable Nested Virtualization (For running KVM / QEMU inside WSL2)
To run virtual machines via KVM/QEMU inside WSL2, enable nested virtualization on the Windows host.
Create or edit `C:\Users\<Your-Windows-Username>\.wslconfig` and add:
```ini
[wsl2]
nestedVirtualization=true
```

In PowerShell, restart WSL:
```powershell
wsl --shutdown
```

Verify KVM hardware acceleration is available inside WSL:
```bash
ls -l /dev/kvm
```

### 8. Installing Monitoring Tools inside WSL2
- **Install Prometheus & Node Exporter:**
  ```bash
  sudo apt install -y prometheus prometheus-node-exporter
  sudo systemctl enable --now prometheus
  sudo systemctl enable --now prometheus-node-exporter
  ```

- **Install Grafana:**
  ```bash
  sudo apt install -y apt-transport-https software-properties-common wget gpg
  sudo mkdir -p /etc/apt/keyrings/
  wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
  echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
  sudo apt update
  sudo apt install -y grafana
  sudo systemctl enable --now grafana-server
  ```

### 9. Accessing Services from Windows
WSL2 automatically maps ports to the Windows host network:
- **Grafana Web UI:** Open browser on Windows &rarr; `http://localhost:3000` (default login: `admin`/`admin`).
- **Prometheus Web UI:** Open browser on Windows &rarr; `http://localhost:9090`.
- **Node Exporter Metrics:** Open browser on Windows &rarr; `http://localhost:9100/metrics`.
- **Access Linux Files in Windows Explorer:** Type `\\wsl$` in the Windows File Explorer address bar.
- **VS Code Integration:** Install the **"WSL"** extension in VS Code on Windows, then run `code .` inside any WSL2 directory.

---

## TIẾNG VIỆT: HƯỚNG DẪN CÀI ĐẶT VÀ SỬ DỤNG WSL2 CHO NGƯỜI DÙNG WINDOWS

### 1. Giới thiệu về WSL2
Windows Subsystem for Linux 2 (WSL2) cho phép người dùng Windows 10 và 11 chạy một nhân Linux (Linux kernel) thực thụ bên trong máy ảo siêu nhẹ. WSL2 tương thích hoàn toàn với các lệnh hệ thống (system call) của Linux, tốc độ đọc ghi tệp nhanh và sử dụng trình quản lý gói chuẩn của Linux (`apt`). Điều này giúp bạn dễ dàng thực hành quản trị Linux, cấu hình mạng và hệ thống giám sát (Prometheus/Grafana) mà không cần cài đặt hai hệ điều hành song song (dual-boot).

### 2. Yêu cầu hệ thống
- **Hệ điều hành:** Windows 10 (Phiên bản 2004, Build 19041 trở lên) hoặc Windows 11.
- **Ảo hóa phần cứng (Hardware Virtualization):** Bật trong BIOS/UEFI (Intel VT-x hoặc AMD-V).
- *Kiểm tra:* Mở **Task Manager** trên Windows &rarr; tab **Performance** &rarr; mục **CPU** &rarr; kiểm tra dòng **"Virtualization: Enabled"**.

### 3. Cài đặt WSL2 trên Windows
Mở **PowerShell** hoặc **Command Prompt** với quyền Quản trị viên (**Run as Administrator**) và thực thi:
```powershell
wsl --install
```

> [!NOTE]
> - Câu lệnh này sẽ tự động bật các tính năng cần thiết của Windows (Virtual Machine Platform, Windows Subsystem for Linux), tải bản Linux kernel mới nhất và cài đặt bản phân phối Ubuntu mặc định.
> - Để cài đặt **Debian 12** (phù hợp với môi trường của bài lab này):
>   ```powershell
>   wsl --install -d Debian
>   ```
> - Để xem danh sách các bản Linux có thể cài đặt:
>   ```powershell
>   wsl --list --online
>   ```
> - Khởi động lại máy tính nếu Windows yêu cầu.

### 4. Các lệnh quản lý WSL cơ bản (Chạy trên Windows PowerShell)
- **Kiểm tra các bản phân phối đã cài đặt và phiên bản WSL:**
  ```powershell
  wsl --list --verbose   # hoặc: wsl -l -v
  ```
- **Đặt WSL2 làm phiên bản mặc định:**
  ```powershell
  wsl --set-default-version 2
  ```
- **Tắt toàn bộ các máy ảo WSL đang chạy:**
  ```powershell
  wsl --shutdown
  ```
- **Khởi động bản Linux mặc định:**
  ```powershell
  wsl
  ```

### 5. Cấu hình ban đầu bên trong WSL2
Khi mở WSL lần đầu tiên, hãy đặt tên người dùng (username) và mật khẩu (password). Sau đó cập nhật các gói hệ thống:
```bash
sudo apt update && sudo apt upgrade -y
```

Cài đặt các gói công cụ cơ bản:
```bash
sudo apt install -y build-essential curl wget git htop net-tools dnsutils jq
```

### 6. Bật systemd trong WSL2 (Bắt buộc để chạy các dịch vụ quản lý qua `systemctl`)
Các phiên bản WSL2 hiện tại đã hỗ trợ `systemd`, đây là thành phần bắt buộc để chạy các dịch vụ nền như `libvirtd`, `prometheus`, `grafana-server` thông qua `systemctl`.

Chỉnh sửa tệp `/etc/wsl.conf` trong terminal WSL:
```bash
sudo nano /etc/wsl.conf
```

Thêm nội dung sau:
```ini
[boot]
systemd=true
```

Lưu tệp (`Ctrl+O`, `Enter`) và thoát (`Ctrl+X`). Sau đó trên PowerShell của Windows, tắt WSL để áp dụng:
```powershell
wsl --shutdown
```
Mở lại WSL và kiểm tra:
```bash
systemctl status
```

### 7. Kích hoạt ảo hóa lồng (Nested Virtualization để chạy KVM / QEMU trong WSL2)
Để chạy các máy ảo bằng KVM/QEMU bên trong WSL2, bạn cần kích hoạt ảo hóa lồng trên máy chủ Windows.
Mở hoặc tạo tệp `C:\Users\<Tên-Người-Dùng-Windows>\.wslconfig` và thêm vào:
```ini
[wsl2]
nestedVirtualization=true
```

Trong PowerShell, khởi động lại WSL:
```powershell
wsl --shutdown
```

Kiểm tra xem thiết bị tăng tốc ảo hóa KVM đã xuất hiện trong WSL hay chưa:
```bash
ls -l /dev/kvm
```

### 8. Cài đặt các công cụ giám sát trong WSL2
- **Cài đặt Prometheus & Node Exporter:**
  ```bash
  sudo apt install -y prometheus prometheus-node-exporter
  sudo systemctl enable --now prometheus
  sudo systemctl enable --now prometheus-node-exporter
  ```

- **Cài đặt Grafana:**
  ```bash
  sudo apt install -y apt-transport-https software-properties-common wget gpg
  sudo mkdir -p /etc/apt/keyrings/
  wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
  echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
  sudo apt update
  sudo apt install -y grafana
  sudo systemctl enable --now grafana-server
  ```

### 9. Truy cập các dịch vụ từ trình duyệt Windows
WSL2 tự động ánh xạ cổng mạng sang Windows:
- **Giao diện Grafana:** Mở trình duyệt trên Windows &rarr; `http://localhost:3000` (đăng nhập mặc định: `admin`/`admin`).
- **Giao diện Prometheus:** Mở trình duyệt trên Windows &rarr; `http://localhost:9090`.
- **Xem chỉ số Node Exporter:** Mở trình duyệt trên Windows &rarr; `http://localhost:9100/metrics`.
- **Truy cập tệp Linux từ File Explorer Windows:** Nhập `\\wsl$` vào thanh địa chỉ của Windows File Explorer.
- **Tích hợp VS Code:** Cài đặt extension **"WSL"** trong VS Code trên Windows, sau đó gõ lệnh `code .` tại bất kỳ thư mục nào trong WSL2.


---

# APPENDIX / PHỤ LỤC: FEDORA GUIDE (HOST & WSL2) / HƯỚNG DẪN DÀNH CHO FEDORA

---

## ENGLISH: FEDORA HOST ENVIRONMENT SETUP & FEDORA ON WSL2

### 1. Fedora Host Environment Setup (Alternative to Arch Linux Part 1)
If your host machine runs Fedora Linux instead of Arch Linux, use `dnf` to install the complete virtualization stack.

#### a. Install Virtualization & Networking Tools
```bash
sudo dnf install -y @virtualization qemu-kvm libvirt virt-install virt-manager virt-viewer dnsmasq iptables-nft
```

**Explanation:**
- `@virtualization`: Fedora package group installing core KVM and QEMU hypervisor packages.
- `qemu-kvm`: KVM kernel module support and QEMU architecture emulator.
- `libvirt`: Management daemon and toolset for virtual machines and networks.
- `virt-install`: Command-line tool to provision VMs (used in Part 2).
- `virt-manager`: Desktop GUI client for inspecting guest VMs.
- `dnsmasq` & `iptables-nft`: DHCP/DNS services and NAT translation for virtual networks.

#### b. Grant User Permissions
```bash
sudo usermod -aG libvirt,kvm $USER
newgrp libvirt
```

#### c. Enable and Start Libvirt Service
```bash
sudo systemctl enable --now libvirtd
```

#### d. Configure Default Virtual Network
```bash
sudo firewall-cmd --reload
sudo virsh net-autostart default
sudo virsh net-start default
sudo virsh net-list --all
```

---

### 2. Running Fedora on Windows WSL2
Fedora can also be run inside Windows WSL2 for practicing Linux commands and DNF package management.

#### a. Installing Fedora on WSL2
- **Option 1 — Via Microsoft Store:**
  Search for **"Fedora Remix for WSL"** in the Microsoft Store and click **Install**.

- **Option 2 — Manual import using official Fedora Container rootfs (Free):**
  Open PowerShell as Administrator:
  ```powershell
  # 1. Download official Fedora rootfs tarball
  curl -Lo fedora.tar.xz https://download.fedoraproject.org/pub/fedora/linux/releases/40/Container/x86_64/images/Fedora-Container-Base-Generic-40-1.14.x86_64.tar.xz

  # 2. Create destination folder and import into WSL
  mkdir C:\WSL\Fedora
  wsl --import Fedora C:\WSL\Fedora fedora.tar.xz --version 2

  # 3. Launch Fedora
  wsl -d Fedora
  ```

#### b. Update Packages & Install Basic Development Tools
```bash
sudo dnf update -y
sudo dnf install -y @development-tools curl wget git htop net-tools bind-utils jq
```

#### c. Enable systemd in Fedora WSL
Edit `/etc/wsl.conf`:
```bash
sudo nano /etc/wsl.conf
```
Add:
```ini
[boot]
systemd=true
```
In Windows PowerShell, restart WSL:
```powershell
wsl --shutdown
```

---

### 3. Installing Monitoring Stack on Fedora (Prometheus & Grafana via DNF)

#### a. Install Prometheus and Node Exporter
Fedora provides Node Exporter in its official repositories:
```bash
sudo dnf install -y node_exporter
sudo systemctl enable --now node_exporter
```

For the Prometheus server:
```bash
wget https://github.com/prometheus/prometheus/releases/download/v2.51.2/prometheus-2.51.2.linux-amd64.tar.gz
tar -xvf prometheus-2.51.2.linux-amd64.tar.gz
cd prometheus-2.51.2.linux-amd64
./prometheus --config.file=prometheus.yml
```

#### b. Install Grafana via Official RPM Repository on Fedora
```bash
sudo tee /etc/yum.repos.d/grafana.repo << 'EOF'
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF

sudo dnf install -y grafana
sudo systemctl enable --now grafana-server
```

#### c. Verify in Web Browser
- **Grafana UI:** `http://localhost:3000` (default login: `admin`/`admin`)
- **Node Exporter:** `http://localhost:9100/metrics`

---

## TIẾNG VIỆT: THIẾT LẬP MÔI TRƯỜNG FEDORA CHO MÁY CHỦ & FEDORA TRÊN WSL2

### 1. Thiết lập máy chủ môi trường Fedora (Phương án thay thế cho Arch Linux ở Phần 1)
Nếu máy chủ của bạn chạy hệ điều hành Fedora Linux thay vì Arch Linux, hãy sử dụng trình quản lý gói DNF để cài đặt toàn bộ ngăn xếp ảo hóa.

#### a. Cài đặt các công cụ ảo hóa & mạng
```bash
sudo dnf install -y @virtualization qemu-kvm libvirt virt-install virt-manager virt-viewer dnsmasq iptables-nft
```

**Giải thích:**
- `@virtualization`: Nhóm gói của Fedora cài đặt toàn bộ các thành phần lõi KVM và hypervisor QEMU.
- `qemu-kvm`: Hỗ trợ module hạt nhân KVM và trình giả lập phần cứng QEMU.
- `libvirt`: Tiến trình daemon và bộ công cụ quản lý các máy ảo và mạng ảo.
- `virt-install`: Tiện ích dòng lệnh để khởi tạo máy ảo tự động (sử dụng ở Phần 2).
- `virt-manager`: Giao diện đồ họa máy tính để theo dõi màn hình máy ảo khách.
- `dnsmasq` & `iptables-nft`: Dịch vụ cấp phát IP DHCP/DNS và chuyển đổi địa chỉ mạng NAT.

#### b. Cấp quyền người dùng cho Libvirt & KVM
```bash
sudo usermod -aG libvirt,kvm $USER
newgrp libvirt
```

#### c. Kích hoạt và khởi chạy dịch vụ Libvirt
```bash
sudo systemctl enable --now libvirtd
```

#### d. Cấu hình mạng ảo mặc định
```bash
sudo firewall-cmd --reload
sudo virsh net-autostart default
sudo virsh net-start default
sudo virsh net-list --all
```

---

### 2. Cài đặt và sử dụng Fedora trên Windows WSL2
Bạn hoàn toàn có thể chạy Fedora bên trong Windows WSL2 để thực hành các câu lệnh Linux và trình quản lý gói DNF.

#### a. Cài đặt Fedora trên WSL2
- **Cách 1 — Qua Microsoft Store:**
  Tìm kiếm **"Fedora Remix for WSL"** trên Microsoft Store và nhấn **Cài đặt (Install)**.

- **Cách 2 — Nhập thủ công bằng image vùng chứa chính thức của Fedora (Miễn phí):**
  Mở Windows PowerShell (Chạy với quyền Quản trị viên - Run as Administrator):
  ```powershell
  # 1. Tải tệp rootfs nén của Fedora
  curl -Lo fedora.tar.xz https://download.fedoraproject.org/pub/fedora/linux/releases/40/Container/x86_64/images/Fedora-Container-Base-Generic-40-1.14.x86_64.tar.xz

  # 2. Tạo thư mục lưu trữ và nhập vào WSL
  mkdir C:\WSL\Fedora
  wsl --import Fedora C:\WSL\Fedora fedora.tar.xz --version 2

  # 3. Khởi động Fedora
  wsl -d Fedora
  ```

#### b. Cập nhật hệ thống & cài đặt các công cụ phát triển cơ bản
```bash
sudo dnf update -y
sudo dnf install -y @development-tools curl wget git htop net-tools bind-utils jq
```

#### c. Bật systemd trong Fedora WSL
Chỉnh sửa tệp `/etc/wsl.conf`:
```bash
sudo nano /etc/wsl.conf
```
Thêm nội dung:
```ini
[boot]
systemd=true
```
Trong Windows PowerShell, khởi động lại WSL:
```powershell
wsl --shutdown
```

---

### 3. Cài đặt ngăn xếp giám sát trên Fedora (Prometheus & Grafana qua DNF)

#### a. Cài đặt Prometheus và Node Exporter
Fedora hỗ trợ gói Node Exporter trực tiếp trong kho lưu trữ chính thức:
```bash
sudo dnf install -y node_exporter
sudo systemctl enable --now node_exporter
```

Đối với máy chủ Prometheus:
```bash
wget https://github.com/prometheus/prometheus/releases/download/v2.51.2/prometheus-2.51.2.linux-amd64.tar.gz
tar -xvf prometheus-2.51.2.linux-amd64.tar.gz
cd prometheus-2.51.2.linux-amd64
./prometheus --config.file=prometheus.yml
```

#### b. Cài đặt Grafana qua kho RPM chính thức trên Fedora
```bash
sudo tee /etc/yum.repos.d/grafana.repo << 'EOF'
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF

sudo dnf install -y grafana
sudo systemctl enable --now grafana-server
```

#### c. Kiểm tra trên trình duyệt
- **Giao diện Grafana:** `http://localhost:3000` (đăng nhập: `admin`/`admin`)
- **Chỉ số Node Exporter:** `http://localhost:9100/metrics`
---

# APPENDIX / PHỤ LỤC: PRODUCTION LEVEL ALERTING

## ENGLISH: PRODUCTION LEVEL ALERTING ARCHITECTURE & PRACTICE

### 1. The Need for Production-Level Alerting (Alert Fatigue & Golden Signals)
Basic alerting setups send uncoordinated emails or chats whenever any single threshold is breached. In real-world enterprise environments, this approach quickly creates severe operational failures:
* **Alert Fatigue (Spam):** When an incident occurs (such as a server crash), dozens of dependent alerts fire simultaneously (CPU metrics lost, RAM metrics missing, Web service down, DB timeout). Engineers become overwhelmed and begin to ignore notifications.
* **Context Loss:** When dozens of alerts fire at once, operators cannot distinguish between the **Root Cause** (e.g. host down) and secondary **Symptoms** (e.g. high latency).
* **The 4 Pillars of Production Alerting:**
  1. **Grouping (`group_by`):** Aggregating related alerts into a single cohesive notification rather than firing individual messages for every single alert.
  2. **Inhibition (`inhibit_rules`):** Automatically silencing secondary, dependent warnings when a critical root-cause alert is already firing (e.g. silencing `HighCPUUsage` when `NodeExporterDown` is active).
  3. **Golden Signals Standardization:** Defining alert rules around Google SRE Golden Signals (Latency, Traffic, Errors, Saturation) with structured metadata (`severity`, `team`, `tier`, `runbook_url`).
  4. **Smart Routing & On-Call Escalation:** Routing warnings to team chat channels (Slack, Telegram) while critical incidents trigger on-call escalations (PagerDuty, Opsgenie).

---

### 2. The 3-Tier Alerting Architecture
```text
[ TIER 1: DETECTION ]            [ TIER 2: ROUTING & PROCESSING ]       [ TIER 3: NOTIFICATION ]
┌─────────────────────────┐       ┌───────────────────────────────┐      ┌─────────────────────────┐
│    Prometheus Server    │       │         Alertmanager          │      │     Telegram Bot        │
│                         │       │                               │      │   (Real-time Chat)      │
│ • Periodic PromQL eval  │──────►│ • Grouping (group_by)         │─────►├─────────────────────────┤
│ • Threshold buffer (for)│(Firing│ • Deduplication               │      │    PagerDuty / Slack    │
│ • States:               │)      │ • Inhibition (inhibit_rules)  │      │     (On-Call Escalation)│
│   Pending -> Firing     │       │ • Silencing (Maintenance)     │      │                         │
└─────────────────────────┘       └───────────────────────────────┘      └─────────────────────────┘
```
1. **Tier 1 - Detection (Prometheus):** Prometheus evaluates PromQL expressions every `evaluation_interval`. When an expression remains true for the duration specified by `for`, the alert transitions from `PENDING` to `FIRING` and is dispatched to Alertmanager.
2. **Tier 2 - Routing & Processing (Alertmanager):** Alertmanager acts as the central intelligence hub. It deduplicates alerts, waits for grouping windows (`group_wait`), filters out alerts suppressed by `inhibit_rules` or silences, and routes valid notifications to configured receivers.
3. **Tier 3 - Notification (Telegram / Slack / PagerDuty):** Transmits rich HTML/Markdown messages with timestamps, severity levels, detailed descriptions, and runbook links to engineering teams.

---

### 3. Port Allocation & Conflict Prevention
In complex monitoring setups, port collisions are frequent causes of startup failure.

| Service | Default Port | Common Conflicting Software | Resolution Strategy |
| :--- | :---: | :--- | :--- |
| **Grafana** | `3000` | Node.js dev server, React apps, Ruby on Rails | Set `http_port = 3001` in `/etc/grafana/grafana.ini` |
| **Prometheus** | `9090` | Cockpit Web Console, Java microservices | Set `--web.listen-address="0.0.0.0:9091"` in systemd unit |
| **Alertmanager** | `9093` | Previous Alertmanager instances, mesh proxies | Set `--web.listen-address="0.0.0.0:9094"` in systemd unit |
| **Node Exporter**| `9100` | Other hardware monitoring daemons | Set `--web.listen-address="0.0.0.0:9101"` |

**Verification Command (run on host or VM):**
```bash
sudo ss -tulpn | grep -E '3000|9090|9093|9100'
```

---

### 4. Alertmanager Production Configuration (`alertmanager.yml`)
Configure `/etc/alertmanager/alertmanager.yml` on `mon-server` with grouping, inhibition, and Telegram notification delivery:

```yaml
global:
  resolve_timeout: 5m

templates:
  - '/etc/alertmanager/alert.tmpl'

route:
  group_by: ['alertname', 'instance', 'job']
  group_wait: 10s       # Wait 10s to collect simultaneous alerts
  group_interval: 1m     # Frequency for sending updates on existing groups
  repeat_interval: 1h    # Interval before re-sending unchanged firing alerts
  receiver: 'telegram-receiver'
  routes:
    - matchers:
        - severity="critical"
      receiver: 'telegram-receiver'
      continue: true
    - matchers:
        - severity="critical"
      receiver: 'incident-webhook'

receivers:
  - name: 'telegram-receiver'
    telegram_configs:
      - bot_token: 'YOUR_TELEGRAM_BOT_TOKEN'
        chat_id: YOUR_TELEGRAM_CHAT_ID
        parse_mode: 'HTML'
        send_resolved: true
        message: '{{ template "telegram.html" . }}'

  - name: 'incident-webhook'
    webhook_configs:
      - url: 'http://127.0.0.1:5001/alerts'
        send_resolved: true

# INHIBITION RULES: Mute HighCPUUsage (warning) when NodeExporterDown (critical) is active
inhibit_rules:
  - source_matchers:
      - severity="critical"
      - alertname="NodeExporterDown"
    target_matchers:
      - severity="warning"
      - alertname="HighCPUUsage"
    equal: ['instance', 'job']
```

---

### 5. Telegram HTML Notification Template & Go Template Timestamp Fix
Create `/etc/alertmanager/alert.tmpl`:

```gotemplate
{{ define "telegram.html" }}
{{ if eq .Status "firing" }}
<b>🚨 PRODUCTION ALERT: SYSTEM INCIDENT</b>
{{ else }}
<b>✅ INCIDENT RECOVERY: RESOLVED</b>
{{ end }}
------------------------------------
{{ range .Alerts }}
<b>Alert Name:</b> <code>{{ .Labels.alertname }}</code>
<b>Severity:</b> <code>{{ .Labels.severity | toUpper }}</code>
<b>Service:</b> {{ .Labels.job }}
<b>Target:</b> <code>{{ .Labels.instance }}</code>
<b>Timestamp:</b> <code>{{ .StartsAt.Local.Format "15:04:05 02/01/2006" }}</code>

<b>Description:</b> {{ .Annotations.description }}
{{ if .Annotations.runbook_url }}
🔗 <a href="{{ .Annotations.runbook_url }}">Runbook Documentation</a>
{{ end }}
------------------------------------
{{ end }}
{{ end }}
```

> **Why the Timestamp Bug Occurs:** In Go Template rendering, calling `{{ .StartsAt }}` directly outside of the `{{ range .Alerts }}` loop evaluates to nil because `.StartsAt` is an attribute of individual alerts, not the top-level payload. Furthermore, Go requires the specific reference date format `15:04:05 02/01/2006` to correctly serialize timestamps.

---

### 6. Standardized Alert Rules & Accurate Memory Formula (`alert_rules.yml`)
Place in `/etc/prometheus/alert_rules.yml`:

```yaml
groups:
  - name: production_node_alerts
    rules:
      - alert: NodeExporterDown
        expr: up{job="node_exporter"} == 0
        for: 30s
        labels:
          severity: critical
          team: platform
          tier: infrastructure
        annotations:
          summary: "Node Exporter on {{ $labels.instance }} is unreachable"
          description: "Target {{ $labels.instance }} has been unreachable for more than 30 seconds."
          runbook_url: "https://wiki.internal.net/ops/runbook/node-down"

      - alert: HighCPUUsage
        expr: 100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[1m])) * 100) > 80
        for: 1m
        labels:
          severity: warning
          team: platform
          tier: infrastructure
        annotations:
          summary: "High CPU usage detected on {{ $labels.instance }}"
          description: "CPU utilization on {{ $labels.instance }} is currently {{ $value | printf \"%.2f\" }}% (> 80%)."
          runbook_url: "https://wiki.internal.net/ops/runbook/cpu-spike"

      # NOTE: Using MemAvailable instead of MemFree to reflect actual reclaimable memory
      - alert: HighMemoryUsage
        expr: 100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) > 80
        for: 1m
        labels:
          severity: warning
          team: platform
          tier: infrastructure
        annotations:
          summary: "High Memory usage detected on {{ $labels.instance }}"
          description: "Actual RAM utilization on {{ $labels.instance }} reached {{ $value | printf \"%.2f\" }}% (> 80%)."
          runbook_url: "https://wiki.internal.net/ops/runbook/high-ram"

      - alert: DiskSpaceLow
        expr: 100 - ((node_filesystem_avail_bytes{mountpoint="/"} * 100) / node_filesystem_size_bytes{mountpoint="/"}) > 85
        for: 1m
        labels:
          severity: warning
          team: platform
          tier: storage
        annotations:
          summary: "Root filesystem partition low on disk space on {{ $labels.instance }}"
          description: "Root partition on {{ $labels.instance }} has exceeded 85% disk utilization."
          runbook_url: "https://wiki.internal.net/ops/runbook/disk-cleanup"
```

Verify configurations with Prometheus developer tools:
```bash
promtool check config /etc/prometheus/prometheus.yml
promtool check rules /etc/prometheus/alert_rules.yml
amtool check-config /etc/alertmanager/alertmanager.yml
```

---

### 7. Automated Testing Tools (`auto_stress.py`)
To test RAM alerting reliably without triggering the Linux Out-Of-Memory (OOM) Killer, use `scripts/auto_stress.py` on `mon-target`:

```bash
# On mon-target:
sudo apt update && sudo apt install -y python3-psutil stress
# Run dynamic RAM stress targeting 85% usage for 180 seconds:
python3 scripts/auto_stress.py 85 180
```

---

### 8. End-to-End Live Incident Demos

#### Demo Scenario A: RAM Stress & Alert Lifecycle (Pending -> Firing -> Resolved)
1. **Trigger Load:** Run `python3 scripts/auto_stress.py 85 180` on `mon-target`.
2. **Observe PENDING:** Within 5 seconds, open Prometheus UI (`http://<server-ip>:9090/alerts`). `HighMemoryUsage` switches to yellow **`PENDING`**.
3. **Observe FIRING & Notification:** After 1 minute of sustained load, the rule enters red **`FIRING`**. Alertmanager groups and dispatches the HTML notification to Telegram.
4. **Observe RECOVERY:** After 180 seconds, `stress` terminates. Memory drops back to normal (~50%). Prometheus detects normal state and Alertmanager issues an automated **`RESOLVED`** notification to Telegram.

#### Demo Scenario B: Alert Inhibition Demonstration
1. **Generate CPU Stress:** Run `stress-ng --cpu 1 --timeout 300s &` on `mon-target`.
2. **Wait for HighCPUUsage Warning:** Observe the alert in Alertmanager (`http://<server-ip>:9093`).
3. **Simulate Host/Agent Crash:** Stop Node Exporter: `sudo systemctl stop prometheus-node-exporter`.
4. **Verify Inhibition:** Once `NodeExporterDown` enters `FIRING` (Critical), Alertmanager evaluates `inhibit_rules`. `HighCPUUsage` is automatically muted/inhibited. Engineers receive only one notification for the root cause (`NodeExporterDown`).

---

## TIẾNG VIỆT: KIẾN TRÚC VÀ THỰC HÀNH CẢNH BÁO CHUẨN PRODUCTION

### 1. Tại sao cần cảnh báo chuẩn Production (Bão cảnh báo & 4 Tín hiệu vàng)
Hệ thống cảnh báo cơ bản thường gửi email/chat đơn lẻ mỗi khi một chỉ số vượt ngưỡng. Trong môi trường doanh nghiệp, cách tiếp cận này nhanh chóng dẫn đến sự cố nghiêm trọng:
* **Bão cảnh báo (Alert Fatigue / Spam):** Khi một sự cố gốc xảy ra (máy chủ mất nguồn), hàng loạt cảnh báo phụ nổ ra cùng lúc (mất CPU, mất RAM, web sập, DB ngắt kết nối). Kỹ sư bị ngợp thông báo và bắt đầu phớt lờ cảnh báo.
* **Mất ngữ cảnh:** Nhận hàng trăm tin nhắn khiến đội ngũ vận hành không thể phân biệt đâu là **Nguyên nhân gốc (Root Cause)** và đâu là **Triệu chứng phụ (Symptoms)**.
* **Bốn trụ cột của Production Alerting:**
  1. **Gom cụm (`group_by`):** Gộp các cảnh báo liên quan vào duy nhất một thông báo tổng hợp.
  2. **Triệt tiêu (`inhibit_rules`):** Tự động dập tắt cảnh báo phụ khi cảnh báo chính mức nghiêm trọng hơn đã kích hoạt (ví dụ: tắt `HighCPUUsage` khi `NodeExporterDown` đã nổ ra).
  3. **Chuẩn hóa Golden Signals:** Xây dựng quy tắc theo 4 tín hiệu vàng (Độ trễ, Lưu lượng, Lỗi, Độ bão hòa) kèm metadata chuẩn (`severity`, `team`, `tier`, `runbook_url`).
  4. **Định tuyến thông minh & On-Call:** Cảnh báo Warning gửi vào nhóm chat (Telegram, Slack); cảnh báo Critical tự động kích hoạt ca trực On-Call (PagerDuty, Opsgenie).

---

### 2. Kiến trúc Cảnh báo 3 Lớp (3-Tier Alerting Architecture)
```text
[ LỚP 1: DETECTION ]             [ LỚP 2: ROUTING & PROCESSING ]        [ LỚP 3: NOTIFICATION ]
┌─────────────────────────┐       ┌───────────────────────────────┐      ┌─────────────────────────┐
│    Prometheus Server    │       │         Alertmanager          │      │     Telegram Bot        │
│                         │       │                               │      │   (Nhắn tin Real-time)  │
│ • Quét định kỳ PromQL   │──────►│ • Gom cụm (group_by)          │─────►├─────────────────────────┤
│ • Thời gian đệm (for)   │(Firing│ • Lọc trùng lặp (Deduplicate) │      │    PagerDuty / Slack    │
│ • Trạng thái:           │)      │ • Triệt tiêu (inhibit_rules)  │      │     (Điều phối On-Call) │
│   Pending -> Firing     │       │ • Tắt tạm thời (Silencing)    │      │                         │
└─────────────────────────┘       └───────────────────────────────┘      └─────────────────────────┘
```
1. **Lớp 1 - Detection (Prometheus):** Chịu trách nhiệm đo đạc và phát hiện. Định kỳ chạy các truy vấn PromQL. Khi biểu thức vượt ngưỡng liên tục trong khoảng thời gian `for`, trạng thái chuyển từ `PENDING` sang `FIRING` và đẩy dữ liệu sang Alertmanager.
2. **Lớp 2 - Routing & Processing (Alertmanager):** Bộ não xử lý thông báo. Chờ cửa sổ gom cụm (`group_wait`), áp dụng các quy tắc triệt tiêu (`inhibit_rules`) để dập tắt thông báo rác, và điều phối tới đúng đích nhận.
3. **Lớp 3 - Notification (Telegram / Slack / PagerDuty):** Gửi thông điệp định dạng HTML/Markdown giàu thông tin kèm thời gian, đối tượng, mức độ và liên kết tài liệu khắc phục (Runbook).

---

### 3. Quản lý và xử lý xung đột cổng hệ thống
Khi triển khai ngăn xếp giám sát, xung đột cổng là lỗi thường gặp nhất.

| Dịch vụ | Cổng chuẩn | Dịch vụ dễ gây xung đột | Giải pháp xử lý |
| :--- | :---: | :--- | :--- |
| **Grafana** | `3000` | Node.js dev server, React, Ruby on Rails | Đổi `http_port = 3001` trong `/etc/grafana/grafana.ini` |
| **Prometheus** | `9090` | Cockpit Web Console, ứng dụng Java | Đổi `--web.listen-address="0.0.0.0:9091"` trong systemd service |
| **Alertmanager** | `9093` | Alertmanager bản cũ, Envoy/Mesh | Đổi `--web.listen-address="0.0.0.0:9094"` trong systemd service |
| **Node Exporter**| `9100` | Các daemon thu thập chỉ số khác | Đổi `--web.listen-address="0.0.0.0:9101"` |

**Lệnh kiểm tra tiến trình đang chiếm dụng cổng:**
```bash
sudo ss -tulpn | grep -E '3000|9090|9093|9100'
```

---

### 4. Cấu hình Alertmanager toàn diện (`alertmanager.yml`)
Mở file `/etc/alertmanager/alertmanager.yml` trên `mon-server`:

```yaml
global:
  resolve_timeout: 5m

templates:
  - '/etc/alertmanager/alert.tmpl'

route:
  group_by: ['alertname', 'instance', 'job']
  group_wait: 10s       # Chờ 10s gom các alert đồng thời
  group_interval: 1m     # Khoảng thời gian cập nhật nhóm cảnh báo
  repeat_interval: 1h    # Gửi lại cảnh báo nếu sự cố chưa giải quyết
  receiver: 'telegram-receiver'
  routes:
    - matchers:
        - severity="critical"
      receiver: 'telegram-receiver'
      continue: true
    - matchers:
        - severity="critical"
      receiver: 'incident-webhook'

receivers:
  - name: 'telegram-receiver'
    telegram_configs:
      - bot_token: 'YOUR_TELEGRAM_BOT_TOKEN'
        chat_id: YOUR_TELEGRAM_CHAT_ID
        parse_mode: 'HTML'
        send_resolved: true
        message: '{{ template "telegram.html" . }}'

  - name: 'incident-webhook'
    webhook_configs:
      - url: 'http://127.0.0.1:5001/alerts'
        send_resolved: true

# QUY TẮC TRIỆT TIÊU: Ẩn HighCPUUsage (warning) khi NodeExporterDown (critical) đang xảy ra
inhibit_rules:
  - source_matchers:
      - severity="critical"
      - alertname="NodeExporterDown"
    target_matchers:
      - severity="warning"
      - alertname="HighCPUUsage"
    equal: ['instance', 'job']
```

---

### 5. Thông báo Telegram HTML & Khắc phục lỗi Timestamp trong Go Template
Tạo file `/etc/alertmanager/alert.tmpl`:

```gotemplate
{{ define "telegram.html" }}
{{ if eq .Status "firing" }}
<b>🚨 CANH BÁO SỰ CỐ HỆ THỐNG CHUẨN PRODUCTION</b>
{{ else }}
<b>✅ SỰ CỐ ĐÃ ĐƯỢC KHẮC PHỤC (RESOLVED)</b>
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
🔗 <a href="{{ .Annotations.runbook_url }}">Tài liệu hướng dẫn xử lý (Runbook)</a>
{{ end }}
------------------------------------
{{ end }}
{{ end }}
```

> **Nguyên nhân lỗi rỗng biến thời gian trên Telegram:** Biến `.StartsAt` là thuộc tính của từng phần tử bên trong danh sách `.Alerts`. Nếu gọi trực tiếp ngoài vòng lặp, Alertmanager không thể render dữ liệu. Đồng thời, Go Template yêu cầu cú pháp định dạng thời gian tham chiếu chuẩn `15:04:05 02/01/2006` để chuyển đổi Unix timestamp sang chuỗi ngày giờ có thể đọc được.

---

### 6. Chuẩn hóa Quy tắc cảnh báo & Công thức tính RAM thực tế (`alert_rules.yml`)
Cấu hình tại `/etc/prometheus/alert_rules.yml`:

```yaml
groups:
  - name: production_node_alerts
    rules:
      - alert: NodeExporterDown
        expr: up{job="node_exporter"} == 0
        for: 30s
        labels:
          severity: critical
          team: platform
          tier: infrastructure
        annotations:
          summary: "Node Exporter trên {{ $labels.instance }} mất kết nối"
          description: "Target {{ $labels.instance }} không phản hồi trong hơn 30 giây."
          runbook_url: "https://wiki.internal.net/ops/runbook/node-down"

      - alert: HighCPUUsage
        expr: 100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[1m])) * 100) > 80
        for: 1m
        labels:
          severity: warning
          team: platform
          tier: infrastructure
        annotations:
          summary: "Phát hiện tải CPU cao trên {{ $labels.instance }}"
          description: "Mức sử dụng CPU trên {{ $labels.instance }} hiện là {{ $value | printf \"%.2f\" }}% (> 80%)."
          runbook_url: "https://wiki.internal.net/ops/runbook/cpu-spike"

      # LƯU Ý: Dùng MemAvailable thay cho MemFree để phản ánh chính xác lượng RAM thực tế có thể cấp phát
      - alert: HighMemoryUsage
        expr: 100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) > 80
        for: 1m
        labels:
          severity: warning
          team: platform
          tier: infrastructure
        annotations:
          summary: "Phát hiện tải RAM cao trên {{ $labels.instance }}"
          description: "Mức sử dụng RAM thực tế trên {{ $labels.instance }} đạt {{ $value | printf \"%.2f\" }}% (> 80%)."
          runbook_url: "https://wiki.internal.net/ops/runbook/high-ram"

      - alert: DiskSpaceLow
        expr: 100 - ((node_filesystem_avail_bytes{mountpoint="/"} * 100) / node_filesystem_size_bytes{mountpoint="/"}) > 85
        for: 1m
        labels:
          severity: warning
          team: platform
          tier: storage
        annotations:
          summary: "Phân vùng root (/) sắp hết dung lượng trên {{ $labels.instance }}"
          description: "Phân vùng root trên {{ $labels.instance }} đã vượt quá 85% dung lượng lưu trữ."
          runbook_url: "https://wiki.internal.net/ops/runbook/disk-cleanup"
```

Kiểm tra tính hợp lệ trước khi khởi chạy:
```bash
promtool check config /etc/prometheus/prometheus.yml
promtool check rules /etc/prometheus/alert_rules.yml
amtool check-config /etc/alertmanager/alertmanager.yml
```

---

### 7. Bộ công cụ kiểm thử tự động (`auto_stress.py`)
Để kiểm thử cảnh báo RAM chính xác mà không làm kích hoạt cơ chế Linux OOM Killer làm sập máy ảo `mon-target`, sử dụng file `scripts/auto_stress.py`:

```bash
# Cài đặt thư viện trên mon-target:
sudo apt update && sudo apt install -y python3-psutil stress
# Ép tải mục tiêu đạt chính xác 85% RAM trong 180 giây:
python3 scripts/auto_stress.py 85 180
```

---

### 8. Kịch bản Demo thực hành trực tiếp

#### Kịch bản A: Ép tải RAM, Vòng đời Alert & Thông báo Telegram (Firing ➔ Resolved)
1. **Kích hoạt tải:** Chạy `python3 scripts/auto_stress.py 85 180` trên `mon-target`.
2. **Quan sát PENDING:** Trong vòng 5 giây, truy cập Prometheus UI (`http://<IP-server>:9090/alerts`). Rule `HighMemoryUsage` chuyển sang màu vàng **`PENDING`**.
3. **Quan sát FIRING & Bắn Telegram:** Sau 1 phút duy trì liên tục, rule chuyển sang màu đỏ **`FIRING`**. Alertmanager gom cụm và gửi tin nhắn HTML tức thì về Telegram.
4. **Tự động phục hồi:** Sau 180 giây, script kết thúc. Lượng RAM tự động giải phóng về mức bình thường. Prometheus chuyển trạng thái và Telegram nhận thông báo **`RESOLVED`**.

#### Kịch bản B: Mô phỏng Exporter chết & Kiểm chứng Triệt tiêu cảnh báo (Alert Inhibition)
1. **Gây tải CPU:** Chạy `stress-ng --cpu 1 --timeout 300s &` trên `mon-target`.
2. **Chờ cảnh báo HighCPUUsage xuất hiện:** Kiểm tra trên giao diện Alertmanager (`http://<IP-server>:9093`).
3. **Mô phỏng sập Exporter:** Dừng dịch vụ: `sudo systemctl stop prometheus-node-exporter`.
4. **Kiểm chứng cơ chế Inhibition:** Khi `NodeExporterDown` (Critical) kích hoạt, Alertmanager tự động nhận diện và dập tắt (Inhibited) cảnh báo `HighCPUUsage`. Quản trị viên chỉ nhận duy nhất 1 thông báo lỗi gốc `NodeExporterDown`.
