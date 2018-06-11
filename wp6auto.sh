#!/usr/bin/env bash
# Automating detection and setup of pineapple and gateway
PINEMAC=00:c0:ca:
PINEIF=NONE
GATEWAYIP=NONE
GATEWAYIF=NONE

# Find Pineapple
for IFACE in `find /sys/class/net/ -type l`
do
    read MAC <$IFACE/address
    if [[ ${MAC} == ${PINEMAC}* ]]
    then
        PINEIF=${IFACE##*/}
    fi
done

if [[ ${PINEIF} == NONE ]]
then
    echo "No Pineapple found"
    exit 1
fi
echo "Pineapple found on interface ${PINEIF}"

ifconfig ${PINEIF} down                                  #Bring down wifi pineapple interface


# Remove pineapple default gateway if exists
route del default ${PINEIF} &> /dev/null
# Find default gateway
GATEWAYLAN=`ip r | grep default | head -n 1 | cut -f 3 -d ' '`
GATEWAYIF=`ip r | grep default | head -n 1 | cut -f 5 -d ' '`

if [[ ${GATEWAYIF} == NONE ]]
then
    echo "No gateway found"
    exit 1
fi

GATEWAYIP=`ip addr show ${GATEWAYIF} | grep -Po 'inet \K[\d.]+'`
echo "Default gateway found on interface ${GATEWAYIF}: ${GATEWAYLAN} with IP ${GATEWAYIP}"

ifconfig ${PINEIF} 172.16.42.42 netmask 255.255.255.0 up #Bring up wifi pineapple interface
route del default ${PINEIF} &> /dev/null
echo "Brought ${PINEIF} up with IP 172.16.42.42"
echo '1' > /proc/sys/net/ipv4/ip_forward                 # Enable IP Forwarding
echo "Enabled IP Forwarding"
iptables -X                                              #clear chains and rules
iptables -F
iptables -A FORWARD -i ${GATEWAYLAN} -o ${PINEIF} -s 172.16.42.0/24 -m state --state NEW -j ACCEPT #setup IP forwarding
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A POSTROUTING -t nat -j MASQUERADE
echo "Enabled packet forwarding"
route del default                              #remove default route
route add default gw ${GATEWAYLAN} ${GATEWAYIF} #add default gateway
echo "Reset default gateway"
