#!/bin/bash

sudo dnf install -y bind bind-utils

# 네임 존 생성
sudo cat << EOF >> /etc/named.rfc1912.zones
zone "cluster.local" IN {
        type master;
        file "cluster.local.zone";
        allow-update { none; };
};
EOF

# dns 설정
sudo cat << EOF > /var/named/cluster.local.zone
$TTL 1D
@   IN SOA  @ cluster.local. (
                    20250227   ; serial
                    1D  ; refresh
                    1H  ; retry
                    1W  ; expire
                    3H )    ; minimum
    IN NS   cluster.local.
    IN A    192.168.10.30
ns  IN A    192.168.10.30

;cluster name
okd4   IN A    192.168.10.30

;ocp cluster
bootstrap.okd4.cluster.local. IN  A   192.168.128.5
control-plane1.okd4.cluster.local.  IN  A   192.168.128.10
control-plane2.okd4.cluster.local.  IN  A   192.168.128.11
control-plane3.okd4.cluster.local.  IN  A   192.168.128.12

api-int.okd4   IN A    192.168.10.20
api.okd4       IN A    192.168.10.20
*.apps.okd4    IN A    192.168.10.20
apps.okd4      IN A    192.168.10.20

EOF

# named.conf 수정
sudo sed -i 's/listen-on port 53 { 127.0.0.1; };/listen-on port 53 { any; };/g' /etc/named.conf
sudo sed -i 's/allow-query     { localhost; };/allow-query     { any; };/g' /etc/named.conf

sudo chown root.named /var/named/cluster.local.zone

sudo systemctl enable --now named
sudo systemctl restart named