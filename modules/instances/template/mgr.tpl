#!/bin/bash

sleep 1m

cat << EOF | tee /home/ec2-user/.ssh/id_ed25519
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtz
c2gtZWQyNTUxOQAAACA8VRO+hCNmfX/zKEkVTLsbMVpT7gXBsg/T9FMfO3O1DwAA
AIhPr8qlT6/KpQAAAAtzc2gtZWQyNTUxOQAAACA8VRO+hCNmfX/zKEkVTLsbMVpT
7gXBsg/T9FMfO3O1DwAAAEAwUQIBATAFBgMrZXAEIgQgQxZlstn16G2FEdYhB/aa
LzxVE76EI2Z9f/MoSRVMuxsxWlPuBcGyD9P0Ux87c7UPAAAAAAECAwQF
-----END OPENSSH PRIVATE KEY-----
EOF

sudo dnf update -y
sudo dnf install -y nginx httpd-tools git

# 웹 설정정
cat << EOF | sudo tee /etc/nginx/conf.d/files.conf
server {
    listen       8080;
    server_name  localhost;

    location / {
        root   /usr/share/nginx/html/files;
        index  index.html index.htm;
        autoindex on;
    }

    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }
}
EOF

sudo systemctl enable --now nginx
sudo systemctl restart nginx


# OKD 설치 준비비
su - ec2-user

mkdir ocp4
cd ocp4

wget https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable/openshift-install-linux.tar.gz
wget https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable/openshift-client-linux.tar.gz

tar -xvf openshift-install-linux.tar.gz
sudo mv openshift-install /usr/local/bin/

tar -xvf openshift-client-linux.tar.gz
sudo mv oc kubectl /usr/local/bin/

rm -f openshift-client-linux.tar.gz openshift-install-linux.tar.gz README.md

ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519

mkdir ignition

cat << EOF | tee ignition/install-config.yaml
apiVersion: v1
baseDomain: ${domain_name}
compute:
- hyperthreading: Enabled
  name: worker
  replicas: ${worker_count}
controlPlane:
  hyperthreading: Enabled
  name: master
  replicas: ${control_count}
metadata:
  name: ${cluster_name}
networking:
  clusterNetwork:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  networkType: OVNKubernetes
  serviceNetwork:
  - 172.30.0.0/16
platform:
  none: {}
pullSecret: '${pullSecret}'
sshKey: '$(cat ~/.ssh/id_ed25519.pub)'
EOF

cp ignition/install-config.yaml install-config.yaml.bak

openshift-install create manifests --dir ignition
openshift-install create ignition-configs --dir ignition

sudo mkdir /usr/share/nginx/html/files
sudo cp ignition/{bootstrap.ign,master.ign,worker.ign} /usr/share/nginx/html/files
sudo chmod 644 /usr/share/nginx/html/files/{bootstrap.ign,master.ign,worker.ign}

sudo chown ec2-user:ec2-user -R /ocp4

touch /tmp/user_data_complete

echo 'export KUBECONFIG=/ocp4/ignition/auth/kubeconfig' >> /home/ec2-user/.bashrc
oc completion bash > oc_bash_completion
sudo cp oc_bash_completion /etc/bash_completion.d/

htpasswd -c -B -b htpasswd admin admin
mv htpasswd /home/ec2-user/


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
