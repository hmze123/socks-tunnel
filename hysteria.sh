#!/bin/bash
#Script Variables
PORT_TCP='5666';
PORT_UDP='5666';
SUB_DOMAIN=sg.socket-tunnel.online
MYIP=$(wget -qO- icanhazip.com);
server_ip=$(curl -s https://api.ipify.org)
timedatectl set-timezone Asia/Riyadh

install_require () {
clear
echo 'Installing dependencies.'
{
export DEBIAN_FRONTEND=noninteractive
apt update
apt install -y gnupg openssl 
apt install -y iptables socat
apt install -y netcat httpie php neofetch vnstat
apt install -y screen gnutls-bin python
apt install -y dos2unix nano unzip jq virt-what net-tools default-mysql-client
apt install -y build-essential
clear
}
clear
}

install_hysteria(){
clear
echo 'Installing hysteria.'
{
wget -N --no-check-certificate -q -O ~/install_server.sh https://raw.githubusercontent.com/apernet/hysteria/master/install_server.sh; chmod +x ~/install_server.sh; ./install_server.sh
} &>/dev/null
}

modify_hysteria(){
clear
echo 'modifying hysteria.'
{
rm -f /etc/hysteria/config.json

echo '{
  "listen": ":5666",
  "cert": "/etc/hysteria/hysteria.crt",
  "key": "/etc/hysteria/hysteria.key",
  "up_mbps": 100,
  "down_mbps": 100,
  "disable_udp": false,
  "obfs": "hamza",
  "auth": {
    "mode": "passwords",
    "config": ["hamza", "firenetdev"]
  }
}
' >> /etc/hysteria/config.json

chmod 755 /etc/hysteria/config.json
#chmod 755 /etc/hysteria/hysteria.crt
#chmod 755 /etc/hysteria/hysteria.key
}
}

install_letsencrypt()
{
clear
echo "Installing letsencrypt."
{
apt remove apache2 -y
echo "$SUB_DOMAIN" > /root/domain
domain=$(cat /root/domain)
curl  https://get.acme.sh | sh
~/.acme.sh/acme.sh --register-account -m firenetdev@gmail.com --server zerossl
~/.acme.sh/acme.sh --issue -d "${domain}" --standalone -k ec-256
~/.acme.sh/acme.sh --installcert -d "${domain}" --fullchainpath /etc/hysteria/hysteria.crt --keypath /etc/hysteria/hysteria.key --ecc
chmod 755 /etc/hysteria/hysteria.crt
chmod 755 755 /etc/hysteria/hysteria.key
}
}

install_firewall_kvm () {
clear
echo "Installing iptables."
echo "net.ipv4.ip_forward=1
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.eth0.rp_filter=0" >> /etc/sysctl.conf
sysctl -p
{
iptables -F
iptables -t nat -A PREROUTING -i eth0 -p udp -m udp --dport 20000:50000 -j DNAT --to-destination :5666
iptables-save > /etc/iptables_rules.v4
ip6tables-save > /etc/iptables_rules.v6
}
}

install_squid(){
clear
echo 'Installing proxy.'
{
sudo apt install -y squid
cd /etc/squid/ || exit
rm squid.conf
echo "acl SSH dst $(ip route get 8.8.8.8 | awk '/src/ {f=NR} f&&NR-1==f' RS=" ")" >> squid.conf
echo 'acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 21
acl Safe_ports port 443
acl Safe_ports port 70
acl Safe_ports port 210
acl Safe_ports port 1025-65535
acl Safe_ports port 280
acl Safe_ports port 488
acl Safe_ports port 591
acl Safe_ports port 777
acl CONNECT method CONNECT
http_access allow SSH
http_access deny all
http_port 8080
http_port 8181
http_port 9090
coredump_dir /var/spool/squid3
refresh_pattern ^ftp: 1440 20% 10080
refresh_pattern ^gopher: 1440 0% 1440
refresh_pattern -i (/cgi-bin/|\?) 0 0% 0
refresh_pattern . 0 20% 4320
visible_hostname KobZ-Proxy' >> squid.conf

service squid restart
cd /etc || exit
}
}


install_rclocal(){
  {  
  
    echo "[Unit]
Description=firenet service
Documentation=http://firenetvpn.com

[Service]
Type=oneshot
ExecStart=/bin/bash /etc/rc.local
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target" >> /etc/systemd/system/firenet.service
    echo '#!/bin/sh -e
iptables-restore < /etc/iptables_rules.v4
ip6tables-restore < /etc/iptables_rules.v6
sysctl -p
service hysteria-server restart
exit 0' >> /etc/rc.local
    sudo chmod +x /etc/rc.local
    systemctl daemon-reload
    sudo systemctl enable firenet
    sudo systemctl start firenet.service
  }
}

start_service () {
clear
echo 'Starting..'
{

sudo crontab -l | { echo "7 0 * * * /root/.acme.sh/acme.sh --cron --home /root/.acme.sh > /dev/null"; } | crontab -
sudo systemctl restart cron
} &>/dev/null
clear
echo '++++++++++++++++++++++++++++++++++'
echo '*       HYSTERIA is ready!    *'
echo '+++++++++++************+++++++++++'
echo -e "[IP] : $server_ip\n[Hysteria Port] : 5666\n"
history -c;
rm /root/.installer
rm /root/install_server.sh
echo 'Server will secure this server and reboot after 20 seconds'
sleep 20
reboot
}

install_require
install_hysteria
install_letsencrypt
install_firewall_kvm
modify_hysteria
install_squid
install_rclocal
start_service
