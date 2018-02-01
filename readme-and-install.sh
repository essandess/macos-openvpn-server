#!/bin/bash -x

# OS X OpenVPN Server and Client Configuration

# commands
OPEN=/usr/bin/open
CAT=/bin/cat
MORE=/usr/bin/more

$CAT <<'HELPSTRING' | $MORE
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

The commands to install an OpenVPN server on OS X and iOS are:

# Install everything here
export OPENVPN_INSTALL=~/Backups/OpenVPN
sudo mkdir -p $OPENVPN_INSTALL
sudo rsync -va /Applications/Tunnelblick.app/Contents/Resources/easy-rsa-tunnelblick $OPENVPN_INSTALL

# configure easy-rsa
sudo install -m 755 -B .orig ./vars $OPENVPN_INSTALL
diff -NaurdwB -I '^ *#.*' $OPENVPN_INSTALL/vars ./vars > /tmp/vars.patch
sudo patch -p5 $OPENVPN_INSTALL/vars < /tmp/vars.patch
rm /tmp/vars.patch

# copy the Tunnelblick and client configuration
rsync -va ./openvpn-server-tun.tblk $OPENVPN_INSTALL
install -m 600 ./openvpn-client-tun.ovpn $OPENVPN_INSTALL

# create the keys
cd $OPENVPN_INSTALL/easy-rsa-tunnelblick
sudo mkdir -m go-rwx ./keys
sudo touch ./keys/index.txt
sudo echo 1 > ./keys/serial
. ./vars
sudo -E ./clean-all
sudo -E ./build-ca --pass
sudo -E ./build-key-server server-domainname
# choose a unique Common Name (CN) for each client
sudo -E ./build-key client-domainname
sudo -E ./build-dh
# Use the openvpn executable
sudo /Applications/Tunnelblick.app/Contents/Resources/openvpn/default --genkey --secret ./keys/ta.key

# Notes:
# Use the domain name "domainname.com" for the common name
# Contact email "admin@domainname.com" must match name in CA;
# otherwise, there will be some X509 error.
 
# For the server-domainname cert, use the default common name
# "server-domainname".This must also match the client configuration
# setting:
# tls-remote domainname.com
 
# Unnecessary if you already signed with ./build-key[-server]
# ./sign-req server-domainname
# ./sign-req client-domainname
 
cd $OPENVPN_INSTALL/easy-rsa-tunnelblick/keys
sudo openssl verify -CAfile ca.crt ca.crt
sudo openssl verify -CAfile ca.crt server-domainname.crt
sudo openssl verify -CAfile ca.crt client-domainname.crt

# Create .p12 client certificates/keys for iOS clients
sudo openssl pkcs12 -export -in client-domainname.crt -inkey client-domainname.key -certfile ca.crt -name client-domainname -out client-domainname.p12

# Copy the necessary files to the .tblk directory
# sudo cp -p ca.crt dh4096.pem server-domainname.crt server-domainname.key ta.key $OPENVPN_INSTALL/openvpn-server-tun.tblk
sudo install -m 644 $OPENVPN_INSTALL/easy-rsa-tunnelblick/keys/ca.crt $OPENVPN_INSTALL/openvpn-server-tun.tblk
sudo install -m 600 $OPENVPN_INSTALL/easy-rsa-tunnelblick/keys/dh4096.pem $OPENVPN_INSTALL/openvpn-server-tun.tblk
sudo install -m 644 $OPENVPN_INSTALL/easy-rsa-tunnelblick/keys/server-domainname.crt $OPENVPN_INSTALL/openvpn-server-tun.tblk
sudo install -m 600 $OPENVPN_INSTALL/easy-rsa-tunnelblick/keys/server-domainname.key $OPENVPN_INSTALL/openvpn-server-tun.tblk
sudo install -m 600 $OPENVPN_INSTALL/easy-rsa-tunnelblick/keys/ta.key $OPENVPN_INSTALL/openvpn-server-tun.tblk
sudo chmod -R $USER $OPENVPN_INSTALL/openvpn-server-tun.tblk

sudo mkdir '/Library/Application Support/vpn'
sudo install -m 755 osx-openvpn-server/enable-vpn-forward-nat.sh '/Library/Application Support/vpn'
sudo install -m 644 net.openvpn.enable-vpn-forward-nat.plist /Library/LaunchDaemons
sudo launchctl load -w /Library/LaunchDaemons/net.openvpn.enable-vpn-forward-nat.plist

# Configure your router to forward port udp port 443 to the OpenVPN server

# Configure the server's config.ovpn file to specifiy the server IP on the LAN
# Edit $OPENVPN_INSTALL/openvpn-server-tun.tblk/config.ovpn to relect your NAT configuration
sed -i '' -e 's/10.0.1.3/'`ifconfig en0 | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p'`'/g' $OPENVPN_INSTALL/openvpn-server-tun.tblk/config.ovpn
# Use config.ovpn.osxfortress with "git clone https://github.com/essandess/osxfortress" for
# secured, privacy-enhanced features on VPN clients
sed -i '' -e 's/10.0.1.3/'`ifconfig en0 | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p'`'/g' $OPENVPN_INSTALL/openvpn-server-tun.tblk/config.ovpn.osxfortress
install -m 644 -B .orig $OPENVPN_INSTALL/openvpn-server-tun.tblk/config.ovpn.osxfortress $OPENVPN_INSTALL/openvpn-server-tun.tblk/config.ovpn

# Load the .tblk file into Tunnelblick; connect/configure the server from Tunnelblick
# Remove the README and other files that will cause Tunnelblick to fail
rm $OPENVPN_INSTALL/openvpn-server-tun.tblk/README $OPENVPN_INSTALL/openvpn-server-tun.tblk/config.ovpn.osxfortress
open $OPENVPN_INSTALL/openvpn-server-tun.tblk

# Use a text editor to add the certificate ca.crt and ta.key to the client .ovpn file
open -e $OPENVPN_INSTALL/openvpn-client-tun.ovpn	# or emacs, nano, vi, etc.

# Install the OpenVPN app on iOS

# Copy the .p12 file to a .ovpn12 file, and add the .ovpn12 file to the iOS OpenVPN app with one of these methods:
# iTunes: Device>Apps>File Sharing>Add...
# AirDrop
# Email: 
uuencode $OPENVPN_INSTALL/keys/client-domainname.p12 client-domainname.ovpn12 | mail -s "client-domainname.ovpn12" myself@myemail.com

# OpenVPN v1.2.6 uses its own keychain, not the iOS keychain

# Transfer the client OpenVPN file openvpn-client-tun.ovpn
# to the OpenVPN app using iTunes, Device>Apps>File Sharing>Add...
open -a iTunes

# Launch the OpenVPN app and toggle the "Connect" button

# check if the OpenVPN server is up
sudo lsof -i ':443' | grep UDP
sudo nmap -sU -p 443 server.domainname.com
HELPSTRING

# prerequisites

# Tunnelblick
if ! [ -d /Applications/Tunnelblick.app ]; then
    $OPEN -a Safari https://code.google.com/p/tunnelblick/
    $CAT <<GET_TUNNELBLICK
Please download and install Tunnelblick from https://code.google.com/p/tunnelblick.
GET_TUNNELBLICK
    exit 1
fi


# check if the OpenVPN server is up
# sudo lsof -i ':443'
# sudo nmap -sU -p 443 server.domainname.com


exit 0
