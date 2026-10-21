# TÀI LIỆU CẢNH BÁO ALERTMANAGER & PRODUCTION ALERTING

> [!NOTE]
> Nội dung của tài liệu này đã được **hợp nhất hoàn chỉnh** với chuyên đề **Production Alerting** (từ các nhánh `feat/hiep/alertmanager` và `feat/expand`).
> 
> 👉 **Vui lòng xem toàn văn tài liệu hướng dẫn và cấu hình chi tiết tại:**  
> **[production_alerting.md](production_alerting.md)**

---

## TỔNG HỢP NỘI DUNG ĐÃ ĐƯỢC TÍCH HỢP

Tài liệu [production_alerting.md](production_alerting.md) bao gồm đầy đủ toàn bộ các nội dung sau:

1. **Kiến trúc Alerting 3 lớp chuẩn Production:**
   - Lớp 1 (Detection - Prometheus) ➔ Lớp 2 (Routing & Processing - Alertmanager) ➔ Lớp 3 (Notification - Telegram Bot & On-Call Webhook).
2. **Khắc phục các lỗi thực tế:**
   - Sửa lỗi rỗng biến `Thời gian` trên Telegram với cú pháp Go Template: `{{ range .Alerts }}{{ .StartsAt.Local.Format "15:04:05 02/01/2006" }}{{ end }}`.
   - Bảng phân bổ cổng chuẩn và xử lý xung đột cổng (Grafana `3000`, Prometheus `9090`, Alertmanager `9093`, Node Exporter `9100`).
   - Chuẩn hóa công thức tính RAM theo `MemAvailable` thay cho `MemFree` để tính đúng tỉ lệ chiếm dụng thực tế.
3. **Cài đặt & Dịch vụ Systemd cho Alertmanager:**
   - Tạo user hệ thống `alertmanager`, cấu hình `/etc/systemd/system/alertmanager.service`.
   - Mẫu template thông báo Telegram HTML chuyên nghiệp (`/etc/alertmanager/alert.tmpl`).
4. **Cơ chế nâng cao của Alertmanager:**
   - **Gom cụm (Grouping):** Gom nhiều cảnh báo cùng cụm máy chủ qua `group_by`.
   - **Triệt tiêu (Inhibition):** Tự động dập tắt cảnh báo phụ (`HighCPUUsage`) khi lỗi gốc nghiêm trọng hơn (`NodeExporterDown`) đã kích hoạt.
   - **Định tuyến On-Call:** Tích hợp Webhook, PagerDuty / Opsgenie.
5. **Bộ công cụ kiểm thử tự động:**
   - Script Python [scripts/auto_stress.py](scripts/auto_stress.py) đo dung lượng RAM thực tế và tự tính toán ép chính xác mức % mong muốn (ví dụ 85%) trong 180s mà không bị Linux OOM Killer bắn hạ.
   - Kịch bản ép CPU với `stress-ng`.
6. **2 Kịch bản Demo thực tế có đối chứng:**
   - **Kịch bản 1:** Ép tải RAM 85% và chu trình vòng đời Alert (`PENDING` ➔ `FIRING` ➔ Bắn Telegram ➔ `RESOLVED`).
   - **Kịch bản 2:** Thử nghiệm Triệt tiêu cảnh báo (Alert Inhibition) khi dừng dịch vụ Exporter.
