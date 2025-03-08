#!/bin/bash


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
*.apps.${cluster_name}       IN A    ${lb_ip}

EOF

# named.conf 수정
sudo sed -i 's/listen-on port 53 { 127.0.0.1; };/listen-on port 53 { any; };/g' /etc/named.conf
sudo sed -i 's/listen-on-v6 port 53 { ::1; };/listen-on-v6 port 53 { any; };/g' /etc/named.conf
sudo sed -i 's/allow-query     { localhost; };/allow-query     { any; };/g' /etc/named.conf

sudo chown root.named /var/named/${domain_name}.zone

sudo systemctl enable --now named
sudo systemctl restart named

export INTERFACE=$(netstat -i | awk 'NR==3 {print $1}')
sudo networkctl renew $INTERFACE

touch /tmp/user_data_complete
