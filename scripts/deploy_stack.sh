#!/usr/bin/env bash
# deploy_stack.sh - Tự động đồng bộ và nạp cấu hình Monitoring Stack chuẩn GitOps
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "======================================================================"
echo "==> Bắt đầu kiểm tra và triển khai Monitoring as Code từ: $REPO_DIR"
echo "======================================================================"

# 1. Kiểm tra tính hợp lệ cú pháp Prometheus & Alertmanager (nếu có công cụ)
echo "[1/5] Kiểm tra tính hợp lệ cú pháp Rules và Config..."
if command -v promtool >/dev/null 2>&1; then
    promtool check config "$REPO_DIR/configs/prometheus/prometheus.yml"
    promtool check rules  "$REPO_DIR/configs/prometheus/recording_rules.yml"
    promtool check rules  "$REPO_DIR/configs/prometheus/alert_rules.yml"
    echo "  [OK] promtool syntax validation passed."
else
    echo "  [WARN] promtool chưa được cài đặt, bỏ qua bước check cú pháp Prometheus."
fi

if command -v amtool >/dev/null 2>&1; then
    amtool check-config "$REPO_DIR/configs/alertmanager/alertmanager.yml"
    echo "  [OK] amtool syntax validation passed."
else
    echo "  [WARN] amtool chưa được cài đặt, bỏ qua bước check cú pháp Alertmanager."
fi

# 2. Đồng bộ file cấu hình Prometheus
echo "[2/5] Đồng bộ cấu hình Prometheus..."
sudo mkdir -p /etc/prometheus/targets
sudo cp "$REPO_DIR/configs/prometheus/prometheus.yml" /etc/prometheus/
sudo cp "$REPO_DIR/configs/prometheus/recording_rules.yml" /etc/prometheus/
sudo cp "$REPO_DIR/configs/prometheus/alert_rules.yml" /etc/prometheus/
if [ -f "$REPO_DIR/configs/prometheus/web.yml" ]; then
    sudo cp "$REPO_DIR/configs/prometheus/web.yml" /etc/prometheus/
fi
sudo cp "$REPO_DIR/configs/prometheus/targets/"*.json /etc/prometheus/targets/
if id "prometheus" >/dev/null 2>&1; then
    sudo chown -R prometheus:prometheus /etc/prometheus
fi

# 3. Đồng bộ file cấu hình Alertmanager
echo "[3/5] Đồng bộ cấu hình Alertmanager..."
sudo mkdir -p /etc/alertmanager
sudo cp "$REPO_DIR/configs/alertmanager/alertmanager.yml" /etc/alertmanager/
sudo cp "$REPO_DIR/configs/alertmanager/alert.tmpl" /etc/alertmanager/
if id "alertmanager" >/dev/null 2>&1; then
    sudo chown -R alertmanager:alertmanager /etc/alertmanager
fi

# 4. Đồng bộ Grafana Provisioning & Dashboards JSON
echo "[4/5] Đồng bộ Grafana Provisioning & Dashboards..."
sudo mkdir -p /etc/grafana/provisioning/datasources \
              /etc/grafana/provisioning/dashboards \
              /var/lib/grafana/dashboards
sudo cp "$REPO_DIR/configs/grafana/datasources/"*.yml /etc/grafana/provisioning/datasources/
sudo cp "$REPO_DIR/configs/grafana/dashboards/"*.yml  /etc/grafana/provisioning/dashboards/
sudo cp "$REPO_DIR/configs/grafana/json/"*.json       /var/lib/grafana/dashboards/
if id "grafana" >/dev/null 2>&1; then
    sudo chown -R grafana:grafana /etc/grafana/provisioning /var/lib/grafana/dashboards
fi

# 5. Nạp cấu hình mới (Hot Reload không gián đoạn)
echo "[5/5] Nạp cấu hình mới (Hot Reload)..."
if curl -s -X POST http://localhost:9090/-/reload >/dev/null 2>&1; then
    echo "  [OK] Prometheus Hot-reload thành công qua HTTP API."
else
    echo "  [INFO] Thử reload qua systemd..."
    sudo systemctl reload prometheus 2>/dev/null || sudo systemctl restart prometheus 2>/dev/null || true
fi

sudo systemctl reload alertmanager 2>/dev/null || sudo systemctl restart alertmanager 2>/dev/null || true
sudo systemctl restart grafana-server 2>/dev/null || true

echo "======================================================================"
echo "==> [THÀNH CÔNG] Toàn bộ hệ thống giám sát đã được đồng bộ chuẩn GitOps!"
echo "======================================================================"
