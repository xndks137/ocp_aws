#!/bin/bash
# NAT 및 VPN 인스턴스 설정 스크립트 (Amazon Linux 2023용 - Libreswan 사용)
echo "qwe123" | sudo passwd ec2-user --stdin
# 변수 설정
LOCAL_IP="${local_ip}"                 # 인스턴스의 프라이빗 IP
LOCAL_PUBLIC_IP="${local_public_ip}"   # 인스턴스의 퍼블릭 IP(EIP)
LOCAL_CIDR="${local_cidr}"             # 온프레미스/내부 CIDR 블록
REMOTE_CIDR="${remote_cidr}"           # AWS VPC CIDR 블록
TUNNEL1_ADDRESS="${tunnel1_address}"   # AWS에서 제공하는 터널1 외부 IP
TUNNEL2_ADDRESS="${tunnel2_address}"   # AWS에서 제공하는 터널2 외부 IP
PRESHARED_KEY1="${preshared_key1}"       # 사전 공유 키1
PRESHARED_KEY2="${preshared_key2}"       # 사전 공유 키2
TUNNEL1_INSIDE_CIDR="${tunnel1_inside_cidr}" # 터널1 내부 CIDR
TUNNEL2_INSIDE_CIDR="${tunnel2_inside_cidr}" # 터널2 내부 CIDR

# 시스템 업데이트
echo "시스템 업데이트 중..."
dnf update -y

# 필요한 패키지 설치
echo "필요한 패키지 설치 중..."
dnf install -y libreswan firewalld tcpdump
systemctl enable --now ipsec
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
sudo firewall-cmd --permanent --set-target=ACCEPT
sudo firewall-cmd --reload 
systemctl restart firewalld

# VPN 설정 (Libreswan)
echo "VPN 설정 구성 중..."

# IPsec 설정 파일 생성
cat > /etc/ipsec.d/aws-vpn.conf << EOF
conn tunnel1
    auto=start
    authby=secret
    type=tunnel
    ike=aes128-sha256;modp2048
    ikelifetime=8h
    phase2=esp
    phase2alg=aes128-sha256;modp2048
    salifetime=1h
    left=%defaultroute
    leftid=$LOCAL_PUBLIC_IP
    leftsubnet=$LOCAL_CIDR
    right=$TUNNEL1_ADDRESS
    rightsubnet=$REMOTE_CIDR
    dpddelay=10
    dpdtimeout=30
    dpdaction=restart
    mark=10/0xffffffff
    vti-interface=vti1
    vti-routing=yes
    vti-shared=no
    # leftvti=$(echo $TUNNEL1_INSIDE_CIDR | cut -d'/' -f1)/32
    # encapsulation=yes
    ikev2=insist
    
conn tunnel2
    # tunnel2는 백업으로 사용하고, 하나만 활성화
    auto=add
    authby=secret
    type=tunnel
    ike=aes128-sha256;modp2048
    ikelifetime=8h
    phase2=esp
    phase2alg=aes128-sha256;modp2048
    salifetime=1h
    left=%defaultroute
    leftid=$LOCAL_PUBLIC_IP
    leftsubnet=$LOCAL_CIDR
    right=$TUNNEL1_ADDRESS
    rightsubnet=$REMOTE_CIDR
    dpddelay=10
    dpdtimeout=30
    dpdaction=restart
    mark=20/0xffffffff
    vti-interface=vti2
    vti-routing=yes
    vti-shared=no
    # leftvti=$(echo $TUNNEL2_INSIDE_CIDR | cut -d'/' -f1)/32
    # encapsulation=yes
    ikev2=insist
EOF

# 사전 공유 키 설정
cat > /etc/ipsec.d/aws-vpn.secrets << EOF
$LOCAL_PUBLIC_IP $TUNNEL1_ADDRESS: PSK "$PRESHARED_KEY1"
$LOCAL_PUBLIC_IP $TUNNEL2_ADDRESS: PSK "$PRESHARED_KEY2"
EOF

# 파일 권한 설정
chmod 600 /etc/ipsec.d/aws-vpn.secrets

# VTI 인터페이스 설정 (간소화)
cat > /etc/NetworkManager/dispatcher.d/pre-up.d/ipsec-vti.sh << EOF
#!/bin/bash
# VTI 인터페이스 설정 스크립트

# 터널 1 설정
sudo ip tunnel add vti1 mode vti local $LOCAL_IP remote $TUNNEL1_ADDRESS key 10
sudo ip addr add $(echo $TUNNEL1_INSIDE_CIDR | sed 's/\/30/\/32/') dev vti1
sudo ip link set vti1 up
sudo ip link set vti1 mtu 1400
sudo sysctl -w net.ipv4.conf.vti1.disable_policy=1

# 터널 2 설정
sudo ip tunnel add vti2 mode vti local $LOCAL_IP remote $TUNNEL2_ADDRESS key 20
sudo ip addr add $(echo $TUNNEL2_INSIDE_CIDR | sed 's/\/30/\/32/') dev vti2
sudo ip link set vti2 up
sudo ip link set vti2 mtu 1400
sudo sysctl -w net.ipv4.conf.vti2.disable_policy=1

# 라우팅 설정
sudo ip route add $REMOTE_CIDR dev vti1 metric 100
sudo ip route add $REMOTE_CIDR dev vti2 metric 200
EOF

chmod +x /etc/NetworkManager/dispatcher.d/pre-up.d/ipsec-vti.sh


# VTI 인터페이스 설정 실행
/etc/NetworkManager/dispatcher.d/pre-up.d/ipsec-vti.sh

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

# 부팅 시 NAT 및 VPN 설정 자동 적용을 위한 스크립트 생성
cat > /usr/local/bin/nat-vpn-setup.sh << EOF
#!/bin/bash
# NAT 및 VPN 설정을 위한 부팅 스크립트

# 네트워크 인터페이스 확인
PRIMARY_NIC=\$(ip -o -4 route show to default | awk '{print \$5}')

# NAT 설정
iptables -t nat -A POSTROUTING -o \$PRIMARY_NIC -j MASQUERADE
iptables -A FORWARD -i \$PRIMARY_NIC -o \$PRIMARY_NIC -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -j ACCEPT

# iptables 설정 저장
systemctl restart firewalld

# VTI 인터페이스 설정
/etc/NetworkManager/dispatcher.d/pre-up.d/ipsec-vti.sh

# IPsec 재시작
systemctl restart ipsec

echo "\$(date): NAT-VPN 설정이 재적용되었습니다." >> /var/log/nat-vpn-setup.log
EOF

chmod +x /usr/local/bin/nat-vpn-setup.sh

# 부팅 시 스크립트 실행을 위한 systemd 서비스 생성
cat > /etc/systemd/system/nat-vpn-setup.service << EOF
[Unit]
Description=NAT and VPN Setup Service
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/nat-vpn-setup.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl enable nat-vpn-setup.service

# VPN 연결 테스트 도구 생성
cat > /usr/local/bin/test-vpn-connection.sh << EOF
#!/bin/bash
# VPN 연결 테스트 스크립트

echo "VPN 연결 테스트 중..."
echo "1. IPsec 상태 확인:"
ipsec status | grep -E "tunnel[12]"

echo "2. VTI 인터페이스 상태:"
ip addr show vti1
ip addr show vti2

echo "3. 라우팅 테이블 확인:"
ip route | grep -E "vti[12]"

echo "4. AWS VPC로 ping 테스트:"
# 첫 번째 IP는 예시입니다. 실제 AWS VPC 내 IP로 변경하세요
ping -c 4 $(echo $REMOTE_CIDR | sed 's/0\/[0-9]*/1/') || echo "Ping 실패"

echo "5. tcpdump로 트래픽 캡처 (5초):"
timeout 5 tcpdump -i vti1 -n
EOF

chmod +x /usr/local/bin/test-vpn-connection.sh

# 설정 정보 출력
echo "NAT 및 VPN 설정이 완료되었습니다." > /var/log/nat-vpn-setup.log
echo "로컬 IP: $LOCAL_IP" >> /var/log/nat-vpn-setup.log
echo "로컬 퍼블릭 IP: $LOCAL_PUBLIC_IP" >> /var/log/nat-vpn-setup.log
echo "로컬 CIDR: $LOCAL_CIDR" >> /var/log/nat-vpn-setup.log
echo "원격 CIDR: $REMOTE_CIDR" >> /var/log/nat-vpn-setup.log
echo "터널1 주소: $TUNNEL1_ADDRESS" >> /var/log/nat-vpn-setup.log
echo "터널2 주소: $TUNNEL2_ADDRESS" >> /var/log/nat-vpn-setup.log
echo "터널1 내부 CIDR: $TUNNEL1_INSIDE_CIDR" >> /var/log/nat-vpn-setup.log
echo "터널2 내부 CIDR: $TUNNEL2_INSIDE_CIDR" >> /var/log/nat-vpn-setup.log
echo "설정 완료 시간: $(date)" >> /var/log/nat-vpn-setup.log

echo "NAT 및 VPN 설정이 완료되었습니다. 자세한 내용은 /var/log/nat-vpn-setup.log 파일을 확인하세요."
echo "VPN 트래픽을 캡처하려면 '/usr/local/bin/capture-vpn-traffic.sh' 명령을 실행하세요."
echo "VPN 연결을 테스트하려면 '/usr/local/bin/test-vpn-connection.sh' 명령을 실행하세요."

systemctl restart ipsec
systemctl restart firewalld

export INTERFACE=$(netstat -i | awk 'NR==3 {print $1}')
sudo networkctl renew $INTERFACE