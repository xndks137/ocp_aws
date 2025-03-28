#!/bin/bash

sudo dnf -y install git

wget https://github.com/go-gitea/gitea/releases/download/v1.23.5/gitea-1.23.5-linux-amd64
mv gitea-1.23.5-linux-amd64 gitea
sudo useradd --shell /bin/bash git
chmod a+x ./gitea
sudo mv ./gitea /usr/local/bin/

sudo mkdir -p /etc/gitea /var/lib/gitea/{custom,data,indexers,public,log}
sudo chown -R git:git /var/lib/gitea/
sudo chmod -R 770 /var/lib/gitea/
sudo chown root:git /etc/gitea
sudo chmod -R 770 /etc/gitea

sudo wget https://raw.githubusercontent.com/go-gitea/gitea/master/contrib/systemd/gitea.service -P /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable --now gitea
sudo systemctl status gitea

sleep 1m

export INTERFACE=$(netstat -i | awk 'NR==3 {print $1}')
sudo networkctl renew $INTERFACE
