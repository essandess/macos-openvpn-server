osx-openvpn-server
==================

OS X OpenVPN Server and Client Configuration

How to build an OpenVPN VPN server on OS X pfctl and Tunnelblick.
This setup will provide a TLS-based VPN server using 4096-bit
certificates and UDP port 443, accessible by any OpenVPN client,
especially iOS with the OpenVPN app.

Why would you want to build your own VPN server when OS X Server
already comes with a VPN service? To have certificate-based VPN.  One
VPN technology used by OS X Server is broken and should be avoided
altogether (Microsoft’s PPTP: ("PPTP traffic should be considered
unencrypted",
<https://www.cloudcracker.com/blog/2012/07/29/cracking-ms-chap-v2/>),
or requires a very long random PSK ("IPSEC-PSK is arguably worse than
PPTP ever was for a dictionary-based attack vector").  If you want
secure certificate-based VPN between OS X Server and iOS, OpenVPN is
the only option.

Furthermore, OS X has its PF firewall turned off by default.
Integrating OpenVPN access within a working OS X firewall provides
greater security. See the git essandess/osxfortress for a firewall,
blackhole, and privatizing proxy. Use the server configuration
config.ovpn.osxfortress for these features.
