#!/bin/bash
# OpenSIPS Docker bootstrap

MYSQL_PWD=${MYSQL_PWD:-"passwd"}
EXTERNAL_IP=$(cat /etc/public_ip.txt)
ADVERTISED_IP=${ADVERTISED_IP:-$EXTERNAL_IP}
ADVERTISED_PORT=${ADVERTISED_PORT:-"5060"}
WSS_PORT=${WSS_PORT:-"5061"}
HOST_IP=$(ip route get 8.8.8.8 | awk '{print $NF; exit}')

echo "Your IP : ${HOST_IP}"
echo "Public IP : ${EXTERNAL_IP}"
echo -e "Your Advertised IP:PORT : ${ADVERTISED_IP}:${ADVERTISED_PORT}\n\n"

# Starting MySQL
service mysql start

# Auto Create Database
expect -c "
spawn /usr/local/sbin/opensipsdbctl create \"\"
expect \"MySQL password for root: \"
send \"${MYSQL_PWD}\r\"
expect \"Install presence related tables? (y/n):\"
send \"y\r\"
expect \"Install tables for imc cpl siptrace domainpolicy carrierroute userblacklist b2b cachedb_sql registrant call_center fraud_detection emergency? (y/n)\"
send \"y\r\"

expect \"END\"
"

# Configure opensips.cfg
sed -i "s/advertised_address=.*/advertised_address=\"${ADVERTISED_IP}\"/g" /usr/local/etc/opensips/opensips.cfg
sed -i "s/listen=udp.*/listen=udp:${HOST_IP}:${ADVERTISED_PORT}/g" /usr/local/etc/opensips/opensips.cfg
sed -i "s/listen=ws.*/listen=ws:${HOST_IP}:${WSS_PORT}/g" /usr/local/etc/opensips/opensips.cfg

# Starting RTPEngine process
insmod /rtpengine/xt_RTPENGINE.ko
modprobe xt_RTPENGINE
mkdir /recording
rtpengine -p /var/run/rtpengine.pid --interface=$HOST_IP!$ADVERTISED_IP -n 127.0.0.1:60000 -c 127.0.0.1:60001 -m 20000 -M 20100 -E -L 7 \
  --recording-method=proc \
  --recording-dir=/recording

# Starting OpenSIPS process
/usr/local/sbin/opensips -c
/usr/local/sbin/opensipsctl start
rsyslogd -n
