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
mkdir /home/ec2-user/okd4
cd /home/ec2-user/okd4

wget https://github.com/okd-project/okd-scos/releases/download/4.17.0-okd-scos.3/openshift-client-linux-4.17.0-okd-scos.3.tar.gz
tar -xvf openshift-client-linux-4.17.0-okd-scos.3.tar.gz
sudo mv oc kubectl /usr/local/bin
oc adm release extract --tools quay.io/okd/scos-release:4.17.0-okd-scos.3
rm -f ccoctl-linux-* openshift-client-linux-* release.txt sha256sum.txt
tar -xvf openshift-install-linux-4.17.0-okd-scos.3.tar.gz
rm -f openshift-install-linux-4.17.0-okd-scos.3.tar.gz README.md
ssh-keygen -t ed25519 -N '' -f /home/ec2-user/.ssh/id_ed25519
mkdir ignition
cat << EOF > ignition/install-config.yaml
apiVersion: v1
baseDomain: cluster.local
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

echo -n "sshKey: '$(cat /home/ec2-user/.ssh/id_ed25519.pub)'" ; >> ignition/install-config.yaml
cp ignition/install-config.yaml install-config.yaml.bak
./openshift-install create manifests --dir ignition
./openshift-install create ignition-configs --dir ignition
sudo mkdir /usr/share/nginx/html/files
sudo cp ./ignition/{bootstrap.ign,master.ign,worker.ign} /usr/share/nginx/html/files
sudo chmod 644 /usr/share/nginx/html/files/{bootstrap.ign,master.ign,worker.ign}

touch /tmp/user_data_complete

export KUBECONFIG=/home/ec2-user/okd4/ignition/auth/kubeconfig
echo 'export KUBECONFIG=/home/ec2-user/okd4/ignition/auth/kubeconfig' >> ~/.bashrc