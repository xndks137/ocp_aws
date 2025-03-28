#!/bin/bash

sleep 1m

sudo dnf install -y bind bind-utils

# 네임 존 생성
sudo cat << EOF >> /etc/named.rfc1912.zones
zone "${domain_name}" IN {
        type master;
        file "${domain_name}.zone";
        allow-update { none; };
};
EOF

# dns 설정
sudo cat << EOF > /var/named/${domain_name}.zone
\$TTL 1D
@   IN SOA  @ ${domain_name}. (
                    31522   ; serial
                    1D  ; refresh
                    1H  ; retry
                    1W  ; expire
                    3H )    ; minimum
    IN NS   ${domain_name}.
    IN A    ${dns_ip}
ns  IN A    ${dns_ip}

;cluster name
${cluster_name}   IN A    ${dns_ip}

;ocp cluster
bootstrap.${cluster_name}.${domain_name}.       IN  A   ${bootstrap_ip}
control-plane0.${cluster_name}.${domain_name}.  IN  A   ${control0_ip}
control-plane1.${cluster_name}.${domain_name}.  IN  A   ${control1_ip}
control-plane2.${cluster_name}.${domain_name}.  IN  A   ${control2_ip}
worker0.${cluster_name}.${domain_name}.         IN  A   ${worker0_ip}
worker1.${cluster_name}.${domain_name}.         IN  A   ${worker1_ip}
worker2.${cluster_name}.${domain_name}.         IN  A   ${worker2_ip}

api-int.${cluster_name}   IN A    ${lb_ip}
api.${cluster_name}       IN A    ${lb_ip}
*.apps.${cluster_name}    IN A    ${lb_ip}

;db Proxy
mydb.${cluster_name}   IN A    ${lb_ip}

;nodes
nat.${cluster_name}        IN A   ${nat_ip}
manager.${cluster_name}    IN A   ${manager_ip}
lb.${cluster_name}         IN A   ${lb_ip}
dns.${cluster_name}        IN A   ${dns_ip}
monitor.${cluster_name}        IN A   ${monitor_ip}
nfs.${cluster_name}        IN A   ${nfs_ip}
db0.${cluster_name}        IN A   ${db0_ip}
db1.${cluster_name}        IN A   ${db1_ip}
gitea.${cluster_name}      IN A   ${gitea_ip}

EOF

# named.conf 수정
sudo sed -i 's/listen-on port 53 { 127.0.0.1; };/listen-on port 53 { any; };/g' /etc/named.conf
sudo sed -i 's/listen-on-v6 port 53 { ::1; };/listen-on-v6 port 53 { any; };/g' /etc/named.conf
sudo sed -i 's/allow-query     { localhost; };/allow-query     { any; };\n\tforwarders { 1.1.1.1; 1.0.0.1; };/g' /etc/named.conf

sudo chown root.named /var/named/${domain_name}.zone

sudo systemctl enable --now named
sudo systemctl restart named

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

export INTERFACE=$(netstat -i | awk 'NR==3 {print $1}')
sudo networkctl renew $INTERFACE

touch /tmp/user_data_complete
