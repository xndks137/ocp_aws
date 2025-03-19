#!/bin/bash
echo "qwe123" | sudo passwd ec2-user --stdin
sudo dnf -y install haproxy mod_security

# 로드밸런스 설정정
sudo cat << EOF | tee /etc/haproxy/haproxy.cfg
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


listen ingress-router-80 
  bind *:80
  mode tcp
  balance source
  server control-plane0 control-plane0.${cluster_name}.${domain_name}:80 check inter 1s

EOF
  # server control-plane1 control-plane1.${cluster_name}.${domain_name}:80 check inter 1s
  # server control-plane2 control-plane2.${cluster_name}.${domain_name}:80 check inter 1s
  # server worker0 worker0.${cluster_name}.${domain_name}:80 check inter 1s
  # server worker1 worker1.${cluster_name}.${domain_name}:80 check inter 1s
  # server worker2 worker2.${cluster_name}.${domain_name}:80 check inter 1s
sudo systemctl enable --now haproxy
sudo systemctl restart haproxy

sudo dnf install -y mod_security mod_security_crs
cat << EOF >> /etc/httpd/conf/httpd.conf

# 서버 정보 제거
<IfModule security2_module>
   SecRuleEngine on
   ServerTokens Full
   SecServerSignature "None"
</IfModule>
EOF
cat <<EOF > /etc/httpd/modsecurity.d/activated_rules/custom_rule.conf
SecDefaultAction "Phase:2,deny,log,status:406"
secRule REQUEST_URI "etc/passwd" "id:'300001'"
secRule REQUEST_URI "etc/shadow" "id:'300002'"
secRule REQUEST_URI "\.\./" "id:'300003'"
SecRule ARGS "<[Ss][Cc][Rr[Ii][Pp][Tt]>" "id:'300004'"
EOF

sudo systemctl enable --now httpd
sudo systemctl restart httpd