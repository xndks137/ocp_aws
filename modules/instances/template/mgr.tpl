#!/bin/bash

sudo dnf install -y nginx

# 웹 설정정
cat << EOF > /etc/nginx/conf.d/files.conf
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

export INTERFACE=$(netstat -i | awk 'NR==3 {print $1}')

sudo networkctl renew $INTERFACE

# OKD 설치 준비비
mkdir okd4
cd okd4

wget https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable/openshift-install-linux.tar.gz
tar -xvf openshift-install-linux.tar.gz
wget https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable/openshift-client-linux.tar.gz
tar -xvf openshift-client-linux.tar.gz
sudo oc kubectl /usr/local/bin
rm -f openshift-install-linux.tar.gz README.md openshift-client-linux.tar.gz 
ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519
mkdir ignition
cat << EOF > ignition/install-config.yaml
apiVersion: v1
baseDomain: xndks.xyz
compute:
- hyperthreading: Enabled
  name: worker
  replicas: 0
controlPlane:
  hyperthreading: Enabled
  name: master
  replicas: 3 # 3노드 구성은 3으로 변경
metadata:
  name: okd4
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
EOF

echo -n "sshKey: '$(cat ~/.ssh/id_ed25519.pub)'" ; >> ignition/install-config.yaml
cp ignition/install-config.yaml install-config.yaml.bak
./openshift-install create manifests --dir ignition
./openshift-install create ignition-configs --dir ignition
sudo mkdir /usr/share/nginx/html/files
sudo cp ./ignition/{bootstrap.ign,master.ign,worker.ign} /usr/share/nginx/html/files
sudo chmod 644 /usr/share/nginx/html/files/{bootstrap.ign,master.ign,worker.ign}

touch /tmp/user_data_complete