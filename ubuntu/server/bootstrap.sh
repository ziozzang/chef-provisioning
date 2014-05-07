#!/bin/bash
# Tested on Ubuntu 12.04 / x86_64
# - code by Jioh L. Jung (ziozzang@gmail.com)

if [ `whoami` != root ]; then
  echo Please run this script as root or using sudo
  exit 1
fi

apt-get install -fy python-pip
pip install flask

HOSTNAME=`hostname -s`
CURRENT_IP=`ifconfig eth0 | grep -m 1 'inet addr:' | cut -d: -f2 | awk '{print $1}'`


cd ~
mkdir chef-server
cd chef-server/

# Install Server.
wget https://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/12.04/x86_64/chef-server_11.0.4-1.ubuntu.12.04_amd64.deb
dpkg -i chef-server_11.0.4-1.ubuntu.12.04_amd64.deb

# Fix FQDN Issue.
# - which is used when sync bookshelf.
sed -i -e "s/node\['fqdn'\]/node['ipaddress']/g" /opt/chef-server/embedded/cookbooks/chef-server/attributes/default.rb
chef-server-ctl reconfigure
chef-server-ctl stop

# default Password is
#  - ID: admin
#  - PW: p@ssw0rd1

# Fix Configuration especially related on FQDN Issue.
sed -i -e "s,\(\"url\"\: \"https\:\/\/\).*\",\1${CURRENT_IP}\",g" \
  /etc/chef-server/chef-server-running.json
sed -i -e "s,\"${HOSTNAME}\",\"${CURRENT_IP}\",g" \
  /etc/chef-server/chef-server-running.json
chef-server-ctl start

# Install Workstation (aka knife)
curl -L http://www.opscode.com/chef/install.sh | sudo bash
RANDSTR=`date +%s | sha256sum | base64 | head -c 32`
echo "${RANDSTR}" > rndstring
echo "${RANDSTR}" | knife configure -y --disable-editing --initial --defaults --repository ~/repo --admin-client-key /etc/chef-server/admin.pem

cat << EOF > /root/reg-client.py
#!/usr/bin/python
# -*- coding: utf-8 -*-
#################################################################
#
# Chef Provisioning API Script - As Master
#
#  - Script by Jioh L. Jung (ziozzang@gmail.com)
#
#################################################################
# Configuration


import os
import re
import json
import threading
from flask import Flask, redirect, url_for, request, Response

app = Flask(__name__)
lock = threading.Lock()

def regist_client(ip):
  os.system("knife client create %s -f %s.pem -s \"https://localhost\" --disable-editing" % \
    (ip, ip))

@app.route('/reg-client/')
def cmd_meta():
  ip = request.remote_addr
  fname = "%s.pem" % (ip)
  if not os.path.exists(fname):
    regist_client(ip)

  if not os.path.exists(fname):
    return Response(status=403)

  d = open(fname, "r").read()

  return Response(d,
    mimetype="text/plain")


app.run(
    debug=True,
    host='0.0.0.0',
    port=7878,
    threaded=True
  )
EOF

chmod +x /root/reg-client.py
CMD="python /root/reg-client.py > /var/log/reg-client.log 2> /var/log/reg-client.err &"

${CMD}
CNT=`grep "chef-client" /etc/rc.local | wc -l`
if [[ "$CNT" -eq 0 ]]; then
  sed -i -e "s,^\(exit.*\),#\1,g" /etc/rc.local
  echo "${CMD}" >> /etc/rc.local
fi



