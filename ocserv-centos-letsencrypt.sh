#!/bin/bash
# pre-alpha version for openconnect installer in Centos -- let's ecnrypt 
# 
# bash ocserv-cen*.sh -f username-list-file -n host-name -e email-address

usage()
{
    echo "usage:"
    echo "bash ocserv-cen*.sh -f username-list-file -n host-name -e email-address"
}


###### Main

SERVER_IP=`ip addr show | awk '/inet/ {print $2}' | grep -v "127.0.0.1" | grep -v "::" | cut -f1 -d"/"`  &
wait
LIST=""
HOST_NAME=""
EMAIL_ADDR=""

while [[ $1 != "" ]]; do
    case $1 in
        -f | --list )     shift
			        LIST=$1
                                ;;
        -n | --hostname )     shift
			        HOST_NAME=$1
                                ;;
        -e | --email )      shift
			        EMAIL_ADDR=$1
                                ;;
        -h | --help )         usage
                                exit
                                ;;
        * )                   usage
                                exit 1
    esac
    echo $1;
    shift
done

if [[ $SERVER_IP == "" ]] ; then
  usage
  exit
fi

yum update -y &
wait
yum install epel-release -y > /dev/null &
wait
yum repolist enabled > /dev/null &
wait

yum install ocserv certbot -y > /dev/null &
wait

#netstat -tulnp &
#wait

#sleep 3

certbot certonly --standalone --non-interactive --preferred-challenges http --agree-tos --email $EMAIL_ADDR -d $HOST_NAME &
wait


sed -i 's/auth = "pam\[gid-min=1000]"/auth = "plain\[\/etc\/ocserv\/ocpasswd]"/g' /etc/ocserv/ocserv.conf
sed -i 's/try-mtu-discovery = false/try-mtu-discovery = true/' /etc/ocserv/ocserv.conf
sed -i 's/dns = 192.168.1.2/dns = 1.1.1.1\ndns = 8.8.8.8/' /etc/ocserv/ocserv.conf
sed -i 's/#tunnel-all-dns = true/tunnel-all-dns = true/' /etc/ocserv/ocserv.conf
sed -i "s/server-cert = \/etc\/ssl\/certs\/ssl-cert-snakeoil.pem/server-cert=\/etc\/letsencrypt\/live\/$HOST_NAME\/fullchain.pem/" /etc/ocserv/ocserv.conf
sed -i "s/server-key = \/etc\/ssl\/private\/ssl-cert-snakeoil.key/server-key=\/etc\/letsencrypt\/live\/$HOST_NAME\/privkey.pem/" /etc/ocserv/ocserv.conf
sed -i 's/ipv4-network = 192.168.1.0/ipv4-network = 192.168.128.0/' /etc/ocserv/ocserv.conf
sed -i 's/#mtu = 1420/mtu = 1420/' /etc/ocserv/ocserv.conf
#sed -i 's/#route = default/route = default/' /etc/ocserv/ocserv.conf # for use server like gateway
sed -i 's/route = 10.10.10.0\/255.255.255.0/#route = 10.10.10.0\/255.255.255.0/' /etc/ocserv/ocserv.conf
sed -i 's/route = 192.168.0.0\/255.255.0.0/#route = 192.168.0.0\/255.255.0.0/' /etc/ocserv/ocserv.conf
sed -i 's/route = fef4:db8:1000:1001::\/64/#route = fef4:db8:1000:1001::\/64/' /etc/ocserv/ocserv.conf
sed -i 's/no-route = 192.168.5.0\/255.255.255.0/#no-route = 192.168.5.0\/255.255.255.0/' /etc/ocserv/ocserv.conf
sed -i 's/udp-port = 443/#udp-port = 443/' /etc/ocserv/ocserv.conf

iptables -I INPUT -p tcp --dport 443 -j ACCEPT
#iptables -I INPUT -p udp --dport 443 -j ACCEPT
iptables -t nat -A POSTROUTING -j MASQUERADE
iptables -I FORWARD -d 192.168.128.0/21 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -s 192.168.128.0/21 -j ACCEPT

echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
echo "net.ipv4.conf.all.proxy_arp = 1" >> /etc/sysctl.conf
sysctl -p & # apply wihout rebooting
wait

if [[ $LIST != "" ]] ; then
  while read -r -a line; do
	  echo "For user ${line[0]} password is update with ${line[1]}"
    echo "${line[1]}" | ocpasswd -c /etc/ocserv/ocpasswd "${line[0]}" &
    wait
  done < $LIST
  exit
fi




systemctl enable ocserv.service &
wait

systemctl mask ocserv.socket &
wait

cp /lib/systemd/system/ocserv.service /etc/systemd/system/ocserv.service &
wait

sed -i 's/Requires=ocserv.socket/#Requires=ocserv.socket/' /etc/systemd/system/ocserv.service
sed -i 's/Also=ocserv.socket/#Also=ocserv.socket/' /etc/systemd/system/ocserv.service

systemctl daemon-reload &
wait
systemctl stop ocserv.socket > /dev/null &
wait
systemctl disable ocserv.socket > /dev/null &
wait
systemctl restart ocserv.service > /dev/null &
wait
systemctl status ocserv.service

iptables -A INPUT -p tcp -m tcp --dport 22 -j ACCEPT


yum install iptables-services -y &
wait

systemctl enable iptables &
wait

service iptables save &
wait

systemctl iptables start &
wait

journalctl |grep ocserv



