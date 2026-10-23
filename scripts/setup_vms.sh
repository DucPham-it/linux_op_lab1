#!/usr/bin/env bash
# setup_vms.sh - Tự động cấp phát mon-server & mon-target bằng KVM/libvirt & CoW overlay
set -euo pipefail

BASE_IMG="/var/lib/libvirt/images/debian-12-genericcloud-amd64.qcow2"
IMG_DIR="/var/lib/libvirt/images"

echo "==> [1/3] Kiểm tra base image..."
if [ ! -f "$BASE_IMG" ]; then
    echo "Tải Debian 12 Cloud Base Image..."
    sudo wget -P "$IMG_DIR" https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2
fi

echo "==> [2/3] Khởi tạo đĩa CoW Overlays..."
sudo qemu-img create -f qcow2 -F qcow2 -b "$BASE_IMG" "$IMG_DIR/mon-server.qcow2" 20G
sudo qemu-img create -f qcow2 -F qcow2 -b "$BASE_IMG" "$IMG_DIR/mon-target.qcow2" 10G

echo "==> [3/3] Tạo và khởi động máy ảo..."
# 1. mon-server (1.5GB RAM, 2 vCPU)
sudo virt-install \
  --name mon-server \
  --ram 1536 \
  --vcpus 2 \
  --disk path="$IMG_DIR/mon-server.qcow2",format=qcow2 \
  --os-variant debian12 \
  --network network=default,model=virtio \
  --cloud-init user-data=cloud-init/user-data.yaml \
  --graphics none \
  --noautoconsole \
  --import

# 2. mon-target (512MB RAM, 1 vCPU)
sudo virt-install \
  --name mon-target \
  --ram 512 \
  --vcpus 1 \
  --disk path="$IMG_DIR/mon-target.qcow2",format=qcow2 \
  --os-variant debian12 \
  --network network=default,model=virtio \
  --cloud-init user-data=cloud-init/user-data.yaml \
  --graphics none \
  --noautoconsole \
  --import

echo "==> Hoàn tất khởi tạo 2 máy ảo mon-server và mon-target!"
