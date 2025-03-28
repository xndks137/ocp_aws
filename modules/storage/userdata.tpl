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


sudo useradd --no-create-home --shell /bin/false prometheus

# 노드 익스포터 다운로드
wget https://github.com/prometheus/node_exporter/releases/download/v1.9.0/node_exporter-1.9.0.linux-amd64.tar.gz
tar -xvf node_exporter-1.9.0.linux-amd64.tar.gz 
cd node_exporter-1.9.0.linux-amd64/

# 실행 파일
sudo mv node_exporter /usr/local/bin/
sudo chown prometheus:prometheus /usr/local/bin/node_exporter 

# 서비스 등록
cat <<EOF | sudo tee /etc/systemd/system/node_exporter.service
[Unit]
Description=Prometheus Node Exporter
Documentation=https://prometheus.io/docs/guides/node-exporter/
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Restart=on-failure
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

# 서비스 시작
sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter
sudo systemctl restart node_exporter
sudo systemctl status node_exporter

sleep 1m

export INTERFACE=$(netstat -i | awk 'NR==3 {print $1}')
sudo networkctl renew $INTERFACE
