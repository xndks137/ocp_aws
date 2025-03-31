#!/bin/bash

sleep 1m

useradd --no-create-home --shell /bin/false prometheus

wget https://github.com/prometheus/prometheus/releases/download/v2.53.4/prometheus-2.53.4.linux-amd64.tar.gz
tar -xvf prometheus-2.53.4.linux-amd64.tar.gz
cd prometheus-2.53.4.linux-amd64

sudo mkdir /etc/prometheus
sudo mv console* /etc/prometheus
sudo mv prometheus.yml /etc/prometheus
sudo chown -R prometheus:prometheus /etc/prometheus

sudo mv prometheus /usr/local/bin/
sudo chown prometheus:prometheus /usr/local/bin/prometheus

sudo mkdir /var/lib/prometheus
sudo chown prometheus:prometheus /var/lib/prometheus
sudo chown -R prometheus:prometheus /var/lib/prometheus

sudo chcon -t bin_t /usr/local/bin/prometheus

cat << EOF | sudo tee /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
restart=on-failure
ExecStart=/usr/local/bin/prometheus \
    --config.file /etc/prometheus/prometheus.yml \
    --storage.tsdb.path /var/lib/prometheus/ \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now prometheus
sudo systemctl status prometheus.service

sudo yum install -y https://dl.grafana.com/enterprise/release/grafana-enterprise-11.5.2-1.x86_64.rpm

sudo systemctl enable --now grafana-server
sudo systemctl status grafana-server


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


cat << EOF | sudo tee -a /etc/prometheus/prometheus.yml
  - job_name: 'node_info'
    static_configs:
      - targets: 
        - ${monitor_ip}:9100       # monitor node
        - ${nat_ip}:9100    # NAT,VPN node
        - ${manager_ip}:9100   # bastion node
        - ${lb_ip}:9100   # LoadBalancer node
        - ${dns_ip}:9100   # DNS node
        - ${nfs_ip}:9100  # NFS node
        - ${db0_ip}:9100  # DB_m node
        - ${db1_ip}:9100  # DB_s node
EOF

sudo systemctl restart prometheus

sleep 3m

export INTERFACE=$(netstat -i | awk 'NR==3 {print $1}')
sudo networkctl renew $INTERFACE
