# OpenVPN Plugin Artifact

This installs a simple OpenVPN server setup and client configuration.

After installation, you need to setup portforwarding from your internet router (UDP port 443) to this Jail instance (UDP port 1194).
The default local network is `192.168.1.0/24`, the default NAT network is `10.8.0.0/24`.
If these ranges don't conflict with your network setup, the server configuration doesn't really need any changes.

The default FQDN address which clients will use is `nas.mydomain.com` at port UDP 443.
You will likely need to change the FQDN of the server, but you could just use the certificate and manually change this in your client.

Client files (configuration and certificates) can be found within the jail at `/usr/local/etc/openvpn/clients`


Probably you will want to change the default passphrases of the server and client, but this will require a rebuild of the PKI, but can be easily done (see below)


# Usage

## Installation of the OpenVPN Jail/Plugin
For commandline installation:

Create a local copy of `openvpn.json` in this repo and run:
```
iocage fetch -P --name ./openvpn.json dhcp=on
```


## (Re-) Configuration
The following examples assume the name of the jail to be `openvpn`.

Pay special attention to the placement of the quotes around the parameters where spaces are used!

### Minimal configuration
An example of probably the most minimal number of changed attributes specific and really relevant for operation. This assumes your jail/server is on (the default) network `192.168.1.0/24`:

Create a new client certificate for client named `yourclientname`, with passphrase `somesecurecertpassphrase`, and configured to connect with the FQDN `vpn.yourdomain.com`.
```
iocage set -P \
  addclient=yourclientname,somesecurecertpassphrase,vpn.yourdomain.com \
openvpn
```

### Networks configuration
If your jail/server is NOT on (the default) network `192.168.1.0/24`, but for example `172.16.1.0`:
```
iocage set -P \
  "private_network=172.16.1.0 255.255.255.0" \
  service=apply_config \
openvpn
```
Pay special attention to the placement of the quotes around the parameters where spaces are used!

Should the default NAT network (`10.8.0.0/24`) conflict with your setup, you configure a different network but you need to supply the NAT network in 2 formats. E.g when changing to `172.16.16.0/24':
```
iocage set -P \
  "nat_network_cidr=172.16.16.0/24" \
  "nat_network=172.16.16.0 255.255.255.0" \
  service=apply_config \
openvpn
```


## Major configuration
If you want changes to the CA certificate to take effect, or basically change all default attributes, the PKI need to be re-initialized, which basically does the installation again.
Example of actually "changing" the password on the CA certificate and some attributes, and doing a rebuild:
```
iocage set -P \
  "ca_key_passphrase=Secret1" \
  easyrsa_req_country=NL \
  easyrsa_req_city=Amsterdam \
  service=rebuild_all \
openvpn
```

# Client certificates/connectivity

By default, the client will connect using UDP to a public port (443) where you have configured your router to forward that port to the jail (port 1194 default).
The parameters that are really specific to each environment are thereby contained in the client configuration.

## Generate a client certificate and configuration

Actually you could just use the client configuration which is created by default, only change the client config to suit you environment.
Generating a specific set for a specific client may be easier, and is good practice to generate a certificate specific for each client.

The client configuration consists of the following attributes:

Required
- client_common_name
- client_key_passphrase

Optional
- server_fqdn
- server_public_port
- server_port_type

NOTE: When using optional parameters, the order is fixed; meaning if you would only want to change the port_type (3rd option), you MUST also provide the options before the respective one.

Examples:
```
# iocage set -P addclient=client2,pass,vpn.yourdomain.com openvpn

# iocage set -P addclient=client3,pass,vpn.yourdomain.com,445,tcp openvpn
```

The resulting set can be found in the jail at `/usr/local/etc/openvpn/clients/<client_common_name>`.
The folder contains a complete set which can used to import into a OpenVPN client configuration.

## Service Management property

The `service` property can be set to the following values, triggering the respective service management task:
- `restart_openvpn`:  Restart OpenVPN service
- `restart_firewall`: Restart Firewall/NAT service
- `apply_config`:  Apply changes to configurations without rebuilding certificates (and passphrases!)
- `rebuild_all`: Rebuild server configuration, root, server and default client certificates. Destroys and invalidates all issued certificates.

### Choosing between `apply_config` and `rebuild_all`
Note that `apply_config` will only change default values, which are subsequently set in configuration files. E.g. a change to `easyrsa_req_email` will only show up in the next generated certificate. E.g. changing `ca_key_passphrase` will NOT change the passphrase of the actual existing CA certificate; this will change the "supplied" ca passphrase when signing new certificates, and therefore WILL break certificate generation.

For changes to the CA certificates, a `rebuild_all` is needed. As this will generate new CA and server certificates, any previously generated client certificates become invalid.
Only downside to a `rebuild_all` is that regeneration of "all" client certificates is required.

## Notes on some properties

The description in `settings.json` will give you a reasonable clue what each property does.

### `nat_network` and `nat_network_cidr`
These networks should be the same, except for their notation. 

For example
In case of `nat_network_cidr` "10.8.1.0/24", then `nat_network` "10.8.1.0 255.255.255.0".

Or in case of `nat_network_cidr` "172.16.0.0/16", then `nat_network` "172.16.0.0 255.255.0.0".


# Notes on success of installation of VPN server

While developing this plugin, at first the installation would allways fail; when stopping my active/working OpenVPN jail, the installation would not fail anymore on the tun device `/dev/tun...`.
So aparently this setup does not (really) allow multiple consumers of `/dev/tun0`, or at least this installation doesn't.
Therefore removed the "fixed" tun allocation (renaming) of `tun0`.
This may result in multiple device files in `/dev/tun..`, but that doesn't hurt and will be cleaned at first reboot. The positive effect is an OpenVPN jail which installation is more stable (I hope ;-).

Regarding routing/NAT; using `gateway_enable="YES"` will enable routing, which enable the firewall to perform the NAT, but only after a reboot. Adjustment here was also setting `sysctl net.inet.ip.forwarding=1` to activate routing immediately.

This might also explain why some users are reporting that it only works after restarting the host(!)...


# Thanks to
The installation is based upon the following post: https://forums.freenas.org/index.php?threads/step-by-step-to-install-openvpn-inside-a-jail-in-freenas-11-1-u1.61681/

