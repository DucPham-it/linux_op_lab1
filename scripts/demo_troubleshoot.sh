#!/usr/bin/env bash
# demo_troubleshoot.sh - Minh họa Demo 4: Phân biệt lỗi mất Exporter vs sập Server
set -euo pipefail

PROM_URL="http://localhost:9090"
TARGET_HOST="192.168.122.38"

echo "======================================================================"
echo "    KỊCH BẢN KIỂM CHỨNG DEMO 4: TROUBLESHOOTING GIÁM SÁT PROMETHEUS"
echo "======================================================================"

echo ""
echo "--- [TRẠNG THÁI 1: BÌNH THƯỜNG] ---"
echo "Truy vấn metric 'up' của target..."
curl -s "$PROM_URL/api/v1/query?query=up" | jq . || true

echo ""
echo "--- [TRẠNG THÁI 2: DỪNG NODE EXPORTER TRÊN TARGET (VM VẪN SỐNG)] ---"
echo "Thao tác: ssh debian@$TARGET_HOST 'sudo systemctl stop node_exporter'"
echo "Kỳ vọng: Prometheus ghi nhận up == 0, lỗi 'connection refused'."
echo "Prometheus biết rõ node mạng vẫn phản hồi ICMP/TCP nhưng port 9100 bị đóng."

echo ""
echo "--- [TRẠNG THÁI 3: TẮT HOÀN TOÀN TARGET VM] ---"
echo "Thao tác: sudo virsh shutdown mon-target"
echo "Kỳ vọng: Prometheus ghi nhận up == 0, lỗi 'no route to host' hoặc 'context deadline exceeded'."
echo "Alertmanager kích hoạt cảnh báo InstanceDown cấp độ CRITICAL và ức chế các cảnh báo con."

echo ""
echo "Hoàn thành mô tả kịch bản kiểm thử Demo 4!"
