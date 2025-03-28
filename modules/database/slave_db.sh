#!/bin/bash

sudo yum install mariadb105-server -y
sudo systemctl enable --now mariadb

cat << EOF | sudo tee -a /etc/my.cnf.d/mariadb-server.cnf
log-bin = mysql-bin 
server-id = 2
binlog_format = row 
EOF

sudo systemctl restart mariadb

sudo mysql -e "CREATE USER 'haproxy_check'@'192.168.10.20';"
sudo mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'haproxy_check'@'192.168.10.20';"
sudo mysql -e "FLUSH PRIVILEGES;"

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
