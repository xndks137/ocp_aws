#!/bin/bash

sudo dnf install -y nginx httpd-tools git

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

# OKD 설치 준비비
mkdir /home/ec2-user/ocp4
cd /home/ec2-user/ocp4

wget https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable/openshift-install-linux.tar.gz
tar -xvf openshift-install-linux.tar.gz
sudo mv openshift-install /usr/local/bin/
rm -f openshift-install-linux.tar.gz README.md
wget https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable/openshift-client-linux.tar.gz
tar -xvf openshift-client-linux.tar.gz
sudo mv oc kubectl /usr/local/bin/
rm -f openshift-client-linux.tar.gz
ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519
mkdir ignition
cat << EOF > ignition/install-config.yaml
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
EOF

echo -n "sshKey: '$(cat ~/.ssh/id_ed25519.pub)'" >> ignition/install-config.yaml
cp ignition/install-config.yaml install-config.yaml.bak
openshift-install create manifests --dir ignition
openshift-install create ignition-configs --dir ignition
chown ec2-user.ec2-user -R /home/ec2-user/ocp4
sudo mkdir /usr/share/nginx/html/files
sudo cp /home/ec2-user/ocp4/ignition/{bootstrap.ign,master.ign,worker.ign} /usr/share/nginx/html/files
sudo chmod 644 /usr/share/nginx/html/files/{bootstrap.ign,master.ign,worker.ign}

echo 'export KUBECONFIG=/home/ec2-user/ocp4/ignition/auth/kubeconfig' >> /home/ec2-user/.bashrc
oc completion bash > oc_bash_completion
cp oc_bash_completion /etc/bash_completion.d/

htpasswd -c -B -b users.htpasswd admin admin
mv users.htpasswd /usr/share/nginx/html/files/


export INTERFACE=$(netstat -i | awk 'NR==3 {print $1}')
sudo networkctl renew $INTERFACE

touch /tmp/user_data_complete