#!/bin/bash
#
# References: The Book of PF, p. 21; https://forums.openvpn.net/topic11401.html
#
# Sleep is necessary cause network has to be up at the time of following commands
# Otherwise the network will not work at all
#
sleep 15
#
/usr/sbin/sysctl -w net.inet.ip.fw.enable=1
/usr/sbin/sysctl -w net.inet.ip.forwarding=1
#/usr/sbin/sysctl -w net.inet6.ip6.forwarding=1

# natd and ipfw are DEPRECATED. Use pfctl(8) instead with nat, e.g.
# nat on en0 from 10.0.0.0/8 to any -> (en0)
###/usr/sbin/natd -interface en0
###/sbin/ipfw add divert natd ip from any to any via en0
