#!/bin/bash
# Chef-client very init provisioning script.
# - code by Jioh L. Jung (ziozzang@gmail.com)

#SERVER_IP="192.168.0.175"
if [[ "$1" == "" ]]; then
  echo "SERVER_IP is empty!"
  echo "USAGE: $0 [SERVER_IP]"
  echo "Ex) $0 1.2.3.4"
  exit 0
fi

if [ `whoami` != root ]; then
  echo Please run this script as root or using sudo
  exit 1
fi

SERVER_IP=$1

CURRENT_IP=`ifconfig eth0 | grep -m 1 'inet addr:' | cut -d: -f2 | awk '{print $1}'`
curl -L https://www.opscode.com/chef/install.sh | sudo bash
mkdir -p /etc/chef

curl http://${SERVER_IP}:7878/reg-client/ > /etc/chef/client.pem
cat << EOF > /etc/chef/client.rb
log_level        :info
log_location     STDOUT
chef_server_url  'https://${SERVER_IP}'
validation_client_name 'chef-validator'
EOF

CMD="chef-client -N ${CURRENT_IP} -d"
${CMD}
CNT=`grep "chef-client" /etc/rc.local | wc -l`
if [[ "$CNT" -eq 0 ]]; then
  sed -i -e "s,^\(exit.*\),#\1,g" /etc/rc.local
  echo "${CMD}" >> /etc/rc.local
fi
