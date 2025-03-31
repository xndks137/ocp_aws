#!/bin/bash
# NAT 및 VPN 인스턴스 설정 스크립트 (Amazon Linux 2023용 - Libreswan 사용)

# 시스템 업데이트
echo "시스템 업데이트 중..."
dnf update -y

# 필요한 패키지 설치
echo "필요한 패키지 설치 중..."
dnf install -y firewalld tcpdump
systemctl enable --now firewalld

# 호스트명 설정
hostnamectl --static set-hostname NAT-VPN-Instance

# IP 포워딩 및 IPsec 관련 설정 활성화
echo "네트워크 설정 구성 중..."
cat <<EOF > /etc/sysctl.d/99-nat-vpn.conf
net.ipv4.ip_forward=1
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.default.rp_filter=0
EOF

# 네트워크 인터페이스 확인
PRIMARY_NIC=$(ip -o -4 route show to default | awk '{print $5}')

# 설정 적용
sysctl -p /etc/sysctl.d/99-nat-vpn.conf

echo "PRIMARY_NIC=$PRIMARY_NIC" >> /etc/environment

# NAT 설정
echo "NAT 설정 구성 중..."
iptables -t nat -A POSTROUTING -o $PRIMARY_NIC -j MASQUERADE
iptables -A FORWARD -i $PRIMARY_NIC -o $PRIMARY_NIC -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -j ACCEPT

# iptables 설정 저장

systemctl enable --now firewalld
sudo firewall-cmd --permanent --zone=public --add-masquerade
sudo firewall-cmd --permanent --zone=public --add-service=ipsec
sudo firewall-cmd --permanent --zone=public --add-service=ssh
sudo firewall-cmd --permanent --zone=public --add-service=mysql
sudo firewall-cmd --permanent --zone=public --add-service=http
sudo firewall-cmd --permanent --zone=public --add-service=http
sudo firewall-cmd --permanent --set-target=ACCEPT
sudo firewall-cmd --reload 
systemctl restart firewalld


# tcpdump 스크립트 생성
cat > /usr/local/bin/capture-vpn-traffic.sh << EOF
#!/bin/bash
# VPN 트래픽 캡처 스크립트

TIMESTAMP=\$(date +%Y%m%d-%H%M%S)
CAPTURE_DIR=/var/log/tcpdump
DURATION=60  # 캡처 시간(초)

# 캡처 디렉토리 생성
mkdir -p \$CAPTURE_DIR

# 기본 인터페이스 트래픽 캡처
tcpdump -i $PRIMARY_NIC -n esp or udp port 500 or udp port 4500 -w \$CAPTURE_DIR/vpn-traffic-\$TIMESTAMP-primary.pcap -c 1000 &

# VTI 인터페이스 트래픽 캡처
tcpdump -i vti1 -n -w \$CAPTURE_DIR/vpn-traffic-\$TIMESTAMP-vti1.pcap -c 500 &
tcpdump -i vti2 -n -w \$CAPTURE_DIR/vpn-traffic-\$TIMESTAMP-vti2.pcap -c 500 &

echo "VPN 트래픽 캡처 시작: \$TIMESTAMP"
echo "캡처 파일은 \$CAPTURE_DIR 디렉토리에 저장됩니다."
echo "약 \$DURATION초 후에 자동으로 종료됩니다."

# 지정된 시간 후 프로세스 종료
sleep \$DURATION
pkill -f "tcpdump -i"

echo "VPN 트래픽 캡처 완료"
EOF

chmod +x /usr/local/bin/capture-vpn-traffic.sh

# 설정 정보 출력
echo "NAT 및 VPN 설정이 완료되었습니다. 자세한 내용은 /var/log/nat-vpn-setup.log 파일을 확인하세요."
echo "VPN 트래픽을 캡처하려면 '/usr/local/bin/capture-vpn-traffic.sh' 명령을 실행하세요."


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

sleep 3m

export INTERFACE=$(netstat -i | awk 'NR==3 {print $1}')
sudo networkctl renew $INTERFACE
