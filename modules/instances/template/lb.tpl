#!/bin/bash

sleep 1m

sudo dnf -y update
sudo dnf -y install haproxy docker
sudo systemctl enable --now haproxy
sudo systemctl enable --now docker

# modsecurity-spoa 설치
docker run -d -p 12345:12345 --name modsec quay.io/jcmoraisjr/modsecurity-spoa -n 2

cat << EOF | sudo tee /etc/haproxy/spoe-modsecurity.conf
[modsecurity]
spoe-agent modsecurity-agent
    messages     check-request
    option       var-prefix  modsec
    timeout      hello       100ms
    timeout      idle        30s
    timeout      processing  1s
    use-backend  spoe-modsecurity
spoe-message check-request
    args   unique-id method path query req.ver req.hdrs_bin req.body_size req.body
    event  on-frontend-http-request
EOF

# 로드밸런스 설정정
sudo cat << EOF > /etc/haproxy/haproxy.cfg
global
  log         127.0.0.1 local2
  pidfile     /var/run/haproxy.pid
  maxconn     4000
  daemon

defaults
  mode                    http
  log                     global
  option                  dontlognull
  option http-server-close
  option                  redispatch
  retries                 3
  timeout http-request    10s
  timeout queue           1m
  timeout connect         10s
  timeout client          1m
  timeout server          1m
  timeout http-keep-alive 10s
  timeout check           10s
  maxconn                 3000

frontend stats
  bind *:1936
  mode            http
  log             global
  maxconn 10
  stats enable
  stats hide-version
  stats refresh 30s
  stats show-node
  stats show-desc Stats for az1 cluster 
  stats auth admin:admin
  stats uri /stats

listen api-server-6443 
  bind *:6443
  mode tcp
  server bootstrap bootstrap.${cluster_name}.${domain_name}:6443 check inter 1s backup 
  server control-plane0 control-plane0.${cluster_name}.${domain_name}:6443 check inter 1s


listen machine-config-server-22623 
  bind *:22623
  mode tcp
  server bootstrap bootstrap.${cluster_name}.${domain_name}:22623 check inter 1s backup 
  server control-plane0 control-plane0.${cluster_name}.${domain_name}:22623 check inter 1s


listen ingress-router-443 
  bind *:443
  mode tcp
  balance source
  server control-plane0 control-plane0.${cluster_name}.${domain_name}:443 check inter 1s
  # server control-plane1 control-plane1.${cluster_name}.${domain_name}:80 check inter 1s
  # server control-plane2 control-plane2.${cluster_name}.${domain_name}:80 check inter 1s
  # server worker0 worker0.${cluster_name}.${domain_name}:80 check inter 1s
  # server worker1 worker1.${cluster_name}.${domain_name}:80 check inter 1s
  # server worker2 worker2.${cluster_name}.${domain_name}:80 check inter 1s

listen ingress-router-80
  bind *:80
  mode http
  balance source
  filter spoe engine modsecurity config /etc/haproxy/spoe-modsecurity.conf
  http-request deny if { var(txn.modsec.code) -m int gt 0 }

  server control-plane0 control-plane0.${cluster_name}.${domain_name}:80 check inter 1s
  # server control-plane1 control-plane1.${cluster_name}.${domain_name}:80 check inter 1s
  # server control-plane2 control-plane2.${cluster_name}.${domain_name}:80 check inter 1s
  # server worker0 worker0.${cluster_name}.${domain_name}:80 check inter 1s
  # server worker1 worker1.${cluster_name}.${domain_name}:80 check inter 1s
  # server worker2 worker2.${cluster_name}.${domain_name}:80 check inter 1s

backend spoe-modsecurity
  mode tcp
  server modsec-spoa1 127.0.0.1:12345

listen mysql-write-3307
  bind *:3307
  mode tcp
  server db0 db0.${cluster_name}.${domain_name}:3306 check inter 1s


listen mysql-read-3306
  bind *:3306
  mode tcp
  balance roundrobin
  server db0 db0.${cluster_name}.${domain_name}:3306 check backup inter 1s
  server db1 db1.${cluster_name}.${domain_name}:3306 check inter 1s


listen gitea-3000
  bind *:3000
  mode tcp
  server gitea gitea.${cluster_name}.${domain_name}:3000 check inter 1s

EOF


sudo systemctl restart haproxy

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
