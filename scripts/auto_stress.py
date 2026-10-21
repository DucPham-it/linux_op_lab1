#!/usr/bin/env python3
"""
auto_stress.py - RAM Stress Testing Tool for Prometheus Alertmanager Demo
Automatically measures system RAM and calculates the exact delta (in MB)
needed to reach a target memory usage percentage without triggering Linux OOM killer.
"""

import sys
import subprocess
import psutil

def auto_stress(target_percent: float, duration: int = 180):
    mem = psutil.virtual_memory()
    total_mb = mem.total / (1024 * 1024)
    used_mb = mem.used / (1024 * 1024)
    current_percent = mem.percent

    print("=" * 60)
    print("      BÁO CÁO TRẠNG THÁI BỘ NHỚ RAM TRƯỚC KHI ÉP TẢI")
    print("=" * 60)
    print(f"Tổng dung lượng RAM hệ thống : {total_mb:.2f} MB")
    print(f"RAM đang sử dụng             : {used_mb:.2f} MB ({current_percent:.2f}%)")
    print(f"Mức % RAM mục tiêu           : {target_percent:.2f}%")
    print(f"Thời gian duy trì tải        : {duration} giây")

    if target_percent <= current_percent:
        print(f"\n[!] RAM hiện tại ({current_percent:.2f}%) đã >= mục tiêu ({target_percent:.2f}%). Không cần ép tải thêm.")
        return

    target_used_mb = total_mb * (target_percent / 100.0)
    needed_mb = int(target_used_mb - used_mb)

    print(f"\n[+] Tính toán: Cần ép thêm khoảng {needed_mb} MB RAM trong {duration} giây.")

    cmd = ["stress", "--vm", "1", "--vm-bytes", f"{needed_mb}M", "--timeout", f"{duration}s"]
    print(f"[+] Đang thực thi: {' '.join(cmd)}\n")
    
    try:
        subprocess.run(cmd, check=True)
        print("\n[+] Hoàn thành chu kỳ ép tải! Hệ thống đang tự động giải phóng RAM...")
    except KeyboardInterrupt:
        print("\n[*] Đã chủ động hủy tiến trình ép tải (Ctrl+C).")
    except FileNotFoundError:
        print("\n[!] Lỗi: Lệnh 'stress' chưa được cài đặt. Vui lòng chạy: sudo apt install -y stress")
    except Exception as e:
        print(f"\n[!] Lỗi khi thực thi stress: {e}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Sử dụng: python3 auto_stress.py <Phần_Trăm_RAM_Mục_Tiêu> [Thời_Gian_Giây]")
        print("Ví dụ:   python3 auto_stress.py 85 180")
        sys.exit(1)

    try:
        target_pct = float(sys.argv[1])
        dur = int(sys.argv[2]) if len(sys.argv) > 2 else 180
        auto_stress(target_pct, dur)
    except ValueError:
        print("[!] Lỗi tham số: Phần trăm RAM và thời gian phải là số hợp lệ.")
        sys.exit(1)
