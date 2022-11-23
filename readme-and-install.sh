#!/bin/bash -x

# macOS OpenVPN Server and Client Configuration

# commands
OPEN=/usr/bin/open
CAT=/bin/cat
MORE=/usr/bin/more

$CAT <<'HELPSTRING' | $MORE
macOS OpenVPN Server and Client Configuration

How to build an OpenVPN VPN server on macOS pfctl and Tunnelblick.
This setup will provide a TLS-based VPN server using EC ed25519
certificates and UDP port 443, accessible by any OpenVPN client,
especially iOS with the OpenVPN app.

The commands to install an OpenVPN server on macOS and iOS are:

# Install everything here
export OPENVPN_INSTALL=~/Security/OpenVPN
mkdir -p ${OPENVPN_INSTALL}/pki_backupvars
mkdir -p ${OPENVPN_INSTALL}/Profiles/Tunnelblick
mkdir -p ${OPENVPN_INSTALL}/Profiles/OpenVPN-app

# install easy-rsa v. 3, openvpn2, and openssl-1.1 via MacPorts:
sudo port install openvpn2 easy-rsa openssl-1.1

# configure easy-rsa
install -m 0755 -B .orig ./vars ${OPENVPN_INSTALL}/pki_backupvars

# edit ${OPENVPN_INSTALL}/pki_backupvars for local instance
# change: EASYRSA_REQ_COUNTRY, EASYRSA_CA_EXPIRE etc.
open -e ${OPENVPN_INSTALL}/pki_backupvars	# or emacs, nano, vi, etc.

cd ${OPENVPN_INSTALL}
easyrsa init-pki
diff -NaurdwB -I '^ *#.*' ${OPENVPN_INSTALL}/pki_backupvars/vars ./pki/vars > /tmp/vars.patch
patch -p5 ${OPENVPN_INSTALL}/pki/vars < /tmp/vars.patch
rm /tmp/vars.patch

# copy the Tunnelblick and client configuration
rsync -va ./openvpn-server-tun.tblk ${OPENVPN_INSTALL}/Profiles/Tunnelblick
install -m 0600 ./openvpn-client-tun.ovpn ${OPENVPN_INSTALL}/Profiles/OpenVPN-app

# create the keys

# dh; tls-auth, tls-crypt
openvpn2 --genkey secret pki/ta.key

# Client-specific TLS keys
# https://github.com/TinCanTech/easy-tls

easyrsa build-ca

# <ca>
openssl x509 -in pki/ca.crt | pbcopy
# <tls-crypt>
pbcopy < pki/ta.key

easyrsa gen-req hostname.servername.com nopass
easyrsa sign-req server hostname.servername.com

easyrsa gen-req my-iPhone
easyrsa sign-req client client-domainname

# .ovpn12 currently do not work with ECDSA; see:
# https://forums.openvpn.net/viewtopic.php?p=77248&hilit=OpenSSL%3A+could+not+obtain+signature#p77248
# https://community.openvpn.net/openvpn/ticket/1024
if false; then
    # https://developer.apple.com/forums/thread/697030
    EASYRSA_OPENSSL=openssl-1.1 easyrsa export-p12 client-domainname
    # https://openvpn.net/faq/how-do-i-use-a-client-certificate-and-private-key-from-the-ios-keychain/
    mv pki/private/client-domainname.{p,ovpn}12

# Client certificate decrypted key
openssl pkey -in pki/private/client-domainname.key -out pki/private/client-domainname.key.decrypted

# unified cert in .ovpn 
# <cert>
openssl x509 -in pki/issued/client-domainname.crt -text | pbcopy
# <key>
pbcopy < pki/private/client-domainname.key.decrypted

# Example:
#
# ...
# Common Name (eg, your name or your server's hostname) [client-domainname]:domainname.com
# ...
# Email Address [admin@domainname.com]:
 
cd ${OPENVPN_INSTALL}
openssl verify -CAfile pki/ca.crt pki/ca.crt
sudo openssl verify -CAfile pki/ca.crt server-domainname.crt
sudo openssl verify -CAfile pki/ca.crt pki/client-domainname.crt

# Create .p12 client certificates/keys for iOS clients
# .ovpn12 currently do not work with ECDSA; see:
# https://forums.openvpn.net/viewtopic.php?p=77248&hilit=OpenSSL%3A+could+not+obtain+signature#p77248
# https://developer.apple.com/forums/thread/697030
# openssl-1.1 pkcs12 -export -in pki/issued/client-domainname.crt -inkey pki/private/client-domainname.key -certfile pki/ca.crt -name client-domainname -out pki/private/client-domainname.p12

# Copy the necessary files to the .tblk directory
# cp -p ca.crt server-domainname.crt server-domainname.key ta.key ${OPENVPN_INSTALL}/Profiles/Tunnelblick/openvpn-server-tun.tblk
install -m 0644 ${OPENVPN_INSTALL}/pki/ca.crt ${OPENVPN_INSTALL}/Profiles/Tunnelblick/openvpn-server-tun.tblk
install -m 644 ${OPENVPN_INSTALL}/pki/issued/server-domainname.crt ${OPENVPN_INSTALL}/Profiles/Tunnelblick/openvpn-server-tun.tblk
install -m 0600 ${OPENVPN_INSTALL}/pki/private/server-domainname.key ${OPENVPN_INSTALL}/Profiles/Tunnelblick/openvpn-server-tun.tblk
install -m 0600 ${OPENVPN_INSTALL}/pki/ta.key ${OPENVPN_INSTALL}/Profiles/Tunnelblick/openvpn-server-tun.tblk

sudo install -m 0644 -B .orig sysctl.conf /etc
# reboot or set by hand prior to reboot:
sudo sysctl net.inet.ip.forwarding=1 net.inet6.ip6.forwarding=1

# Configure your router to forward port udp port 443 to the OpenVPN server

# Configure the server's config.ovpn file to specifiy the server IP on the LAN
# Edit ${OPENVPN_INSTALL}/Profiles/Tunnelblick/openvpn-server-tun.tblk/config.ovpn to relect your NAT configuration
sed -i '' -e 's/10.0.1.3/'`ifconfig en0 | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p'`'/g' ${OPENVPN_INSTALL}/Profiles/Tunnelblick/openvpn-server-tun.tblk/config.ovpn
# Use config.ovpn.osxfortress with "git clone https://github.com/essandess/osxfortress" for
# secured, privacy-enhanced features on VPN clients
sed -i '' -e 's/10.0.1.3/'`ifconfig en0 | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p'`'/g' ${OPENVPN_INSTALL}/Profiles/Tunnelblick/openvpn-server-tun.tblk/config.ovpn.osxfortress
# install -m 0644 -B .orig ${OPENVPN_INSTALL}/Profiles/Tunnelblick/openvpn-server-tun.tblk/config.ovpn.osxfortress ${OPENVPN_INSTALL}/Profiles/Tunnelblick/openvpn-server-tun.tblk/config.ovpn

# Load the .tblk file into Tunnelblick; connect/configure the server from Tunnelblick
open ${OPENVPN_INSTALL}/Profiles/Tunnelblick/openvpn-server-tun.tblk

# Configure pf to use the VPN interface
# copy the pf.conf file locally, or use MacPorts macos-fortress
sudo install -m 0644 pf.conf "/Library/Application Support/Tunnelblick/"
sudo pfctl -ef "/Library/Application Support/Tunnelblick/pf.conf"

# Use a text editor to add the certificates ca.crt, ta.key, and client PKI
# to the client .ovpn file
open -e ${OPENVPN_INSTALL}/openvpn-client-tun.ovpn	# or emacs, nano, vi, etc.

# Install the OpenVPN app on iOS

# Copy the .p12 file to a .ovpn12 file, and add the .ovpn12 file to the iOS OpenVPN app with one of these methods:
# iTunes: Device>Apps>File Sharing>Add...
# AirDrop
# Email: 
uuencode ${OPENVPN_INSTALL}/keys/client-domainname.p12 client-domainname.ovpn12 | mail -s "client-domainname.ovpn12" myself@myemail.com

# Transfer the client OpenVPN file openvpn-client-tun.ovpn
# to the OpenVPN app using macOS Finder with AirDrop or iOS Syncing

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
