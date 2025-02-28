#!/bin/bash

sudo coreos-installer install /dev/xvda --ignition-url=http://192.168.10.10/bootstrap.ign --insecure-ignition --copy-network
sudo reboot