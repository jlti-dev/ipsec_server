#!/bin/bash
echo -e """ possible ENV-Vars
\t RETRANSMIT_BASE --> charon.conf
\t RETRANSMIT_LIMIT --> charon.conf
\t RETRANSMIT_TIMEOUT --> charon.conf
\t RETRANSMIT_TRIES --> charon.conf
\t PUBLIC_IP --> Routing / strongswan
\t MASQUERADE_SUB --> Routing / inner-VPN-Communication
\t VPN_GATEWAY --> Routing / inner-VPN-Communication --> Will be the host for all private networks!
Proceeding with protocol"""
if [[ -z "${RETRANSMIT_BASE}" ]]; then
	echo "Using default retransmit_base"
else
	echo "Setting retransmit_base"
	sed -i -r 's/.*retransmit_base = .+/  retransmit_base = '$RETRANSMIT_BASE'/' /etc/strongswan.d/charon.conf
fi
if [[ -z "${RETRANSMIT_LIMIT}" ]];then
	echo "Using default retransmit_limit"
else
	echo "Setting retransmit_limit"
	sed -i -r 's/.*retransmit_limit = .+/  retransmit_limit = '$RETRANSMIT_LIMITi'/' /etc/strongswan.d/charon.conf
fi
if [[ -z "${RETRANSMIT_TIMEOUT}" ]];then
	echo "Using default retransmit_timeout"
else
	echo "Setting retransmit_timeout"
	sed -i -r 's/.*retransmit_timeout = .+/  retransmit_timeout = '$RETRANSMIT_TIMEOUT'/' /etc/strongswan.d/charon.conf
fi
if [[ -z "${RETRANSMIT_TRIES}" ]];then
	echo "Using default retransmit_tries"
else
	echo "Setting retransmit_tries"
	sed -i -r 's/.*retransmit_tries = .+/  retransmit_tries = '$RETRANSMIT_TRIES'/' /etc/strongswan.d/charon.conf
fi

echo "finished Charon Conf"

if [[ -z "${PUBLIC_IP}" ]]; then
	echo "Please set env variable \"PUBLIC_IP\" to an IP!"
	exit 1
else
	pubip="${PUBLIC_IP}"
fi

if [[ -z "${MASQUERADE_SUB}" ]]; then
	echo "No Masquerading of Home Network requested"
	echo "This can be a problem on the routing! Take CARE!"
fi
echo "Expecting 2 IPs (public ip and internal IP)"
ip1="$(hostname -i | awk '{ print $1}' )"
ip2="$(hostname -i | awk '{ print $2}' )"
if [[ "$ip1" == "$pubip" ]]; then
	echo "Found IP1 $ip1 being public IP"
else
	echo "Found IP1 $ip1 being internal IP, routable"
	me="$ip1"
fi
if [[ "$ip2" == "$pubip" ]]; then
	echo "Found IP2 $ip2 being public IP"
else
	echo "Found IP2 $ip2 being internal IP, routable"
	me="$ip2"
fi
if [[ -z "$ip1" || -z "$ip2" ]]; then
	echo "One IP was not found, Error in Configuration"
	echo "This is not recoverable!"
	exit 1
fi 
subnet="$(ip route | grep $me | awk '{print $1}')"
echo "Found subnet $subnet for private ip $me"
if [[ -z "${MASQUERADE_SUB}" ]]; then
	echo "Not Masquerading"
elif [[ -f "masquerade.sh" ]]; then
	echo "Found masquerade.sh - calling custom script"
	/bin/bash masquerade.sh
else
	echo "Masquerading all Traffic not coming from internal network $subnet, so you can ping it!"
	iptables --table nat --append POSTROUTING ! --source $subnet --jump MASQUERADE
	echo ".. Done. you could use masquerade.sh to do this on your own"
fi
if [[ -z "${VPN_GATEWAY}" ]]; then
	echo "Not setting vpn-gateway, ensure you can reach all networks from this container!"
else
	vpngw="${VPN_GATEWAY}"
	cmd="ip route add 10.0.0.0/8 via $vpngw"
	rc="$($cmd)"
	echo "return code for Command $cmd: $rc"
	cmd="ip route add 172.16.0.0/12 via $vpngw"
	rc="$($cmd)"
	echo "return code for Command $cmd: $rc"
	cmd="ip route add 192.168.0.0/16 via $vpngw"
	rc="$($cmd)"
	echo "return code for Command $cmd: $rc"
fi
echo "Setting up NAT so strongswan can use the public ip without caring about routing"
iptables --table nat --insert PREROUTING --destination $me --jump DNAT --to-destination $pubip

iptables --table nat --insert POSTROUTING --source $pubip --jump SNAT --to-source $me

echo "Finished Natting"

echo "Finished Startup - Starting charon now!"
exec /usr/libexec/ipsec/charon --debug-ike 0 --debug-cfg 1 --debug-mgr 1 --debug-enc 0 --debug-net 0 --debug-chd 1
