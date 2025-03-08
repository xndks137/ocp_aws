#!/bin/bash
set -e

# 시스템 업데이트
yum update -y

# NFS 유틸리티 설치
yum install -y nfs-utils

# NFS 서비스 시작 및 활성화
systemctl enable nfs-server rpcbind
systemctl start nfs-server rpcbind

sleep 20

# 데이터 볼륨 마운트
mkfs -t xfs /dev/sdf
mkdir -p ${nfs_share_path}
echo "/dev/sdf ${nfs_share_path} xfs defaults 0 0" >> /etc/fstab
mount -a

# NFS 공유 설정
chmod 777 ${nfs_share_path}
echo "${nfs_share_path}   ${pri_sub_cidr}(rw,sync,no_root_squash)" > /etc/exports
exportfs -a

# 방화벽 설정 (Amazon Linux 2의 경우 기본적으로 비활성화됨)
if command -v firewall-cmd &> /dev/null; then
    firewall-cmd --permanent --add-service=nfs
    firewall-cmd --permanent --add-service=rpc-bind
    firewall-cmd --permanent --add-service=mountd
    firewall-cmd --reload
fi