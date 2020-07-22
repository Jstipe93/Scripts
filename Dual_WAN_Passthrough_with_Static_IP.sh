#Place in custom firewall rules

# config interface name:
interface=wan
# kernel device name:
dev=wan
 
address="$(config get network.interface.$interface.ipv4.address)"
gateway="$(config get network.interface.$interface.ipv4.gateway)"
defroute="$(ip route | grep "default via $gateway" | head -1)"
 
ip addr del $address dev $dev 2>/dev/null
ip route add $gateway dev $dev 2>/dev/null
ip route add $defroute 2>/dev/null
 
intf=network.interface.ipv4_interface_$dev
if ! ubus call $intf status 2>/dev/null | grep -q "\"ip\": \"$ipaddr\""; then
        ipaddr="${address%/*}"
        netmask="${address##*/}"
        ubus call $intf set_data "{ \"ip\": \"$ipaddr\", \"netmask\": \"$netmask\" }" 2>/dev/null \
                && trigger event netifd
fi
