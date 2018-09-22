#!/bin/sh

# Library file
#
# Global variables
vars_file=/root/vars

# Config directories
etc_openvpn=/usr/local/etc/openvpn
openvpn_keys="${etc_openvpn}/keys"
openvpn_clients="${etc_openvpn}/clients"
etc_easy_rsa="${etc_openvpn}/easy-rsa"

# Config file
easy_rsa_vars_file="${etc_easy_rsa}/vars"
openvpn_conf="${etc_openvpn}/openvpn.conf"

create_folders()
{
  rm -rf "${etc_openvpn}" "${openvpn_keys}" "${etc_easy_rsa}" "${openvpn_clients}"
  mkdir -p "${etc_openvpn}" "${openvpn_keys}" "${etc_easy_rsa}"
}

load_variables_from_file()
{
  while IFS= read line
  do
    name=`echo $line | cut -f 1 -d =`
    val="`echo $line | cut -f 2 -d =`"
    if [ "${name}" != "" -a "${val}" != "" ]
    then
      eval "${name}=${val}"
    fi
  done <"${vars_file}"
}

easy_rsa_init()
{
  cp -r /usr/local/share/easy-rsa/* ${etc_easy_rsa}/
}
easy_rsa_config()
{
  # Set configuration entries
  #cat ${easy_rsa_vars_file} | grep -e EASYRSA_REQ_COUNTRY -e EASYRSA_REQ_PROVINCE -e EASYRSA_REQ_CITY -e EASYRSA_REQ_ORG -e EASYRSA_REQ_EMAIL -e EASYRSA_REQ_OU -e EASYRSA_KEY_SIZE -e EASYRSA_CA_EXPIRE -e EASYRSA_CERT_EXPIRE
  sed -i ''   's/^[# ]*set_var EASYRSA_REQ_COUNTRY.*$/set_var EASYRSA_REQ_COUNTRY     "'"${easyrsa_req_country}"'"/g' ${easy_rsa_vars_file}
  sed -i '' 's/^[# ]"*set_var EASYRSA_REQ_PROVINCE.*$/set_var EASYRSA_REQ_PROVINCE    "'"${easyrsa_req_province}"'"/g' ${easy_rsa_vars_file}
  sed -i ''      's/^[# ]*set_var EASYRSA_REQ_CITY.*$/set_var EASYRSA_REQ_CITY        "'"${easyrsa_req_city}"'"/g' ${easy_rsa_vars_file}
  sed -i ''       's/^[# ]*set_var EASYRSA_REQ_ORG.*$/set_var EASYRSA_REQ_ORG         "'"${easyrsa_req_org}"'"/' ${easy_rsa_vars_file}
  sed -i ''     's/^[# ]*set_var EASYRSA_REQ_EMAIL.*$/set_var EASYRSA_REQ_EMAIL       "'"${easyrsa_req_email}"'"/' ${easy_rsa_vars_file}
  sed -i ''        's/^[# ]*set_var EASYRSA_REQ_OU.*$/set_var EASYRSA_REQ_OU          "'"${easyrsa_req_ou}"'"/' ${easy_rsa_vars_file}
  sed -i ''      's/^[# ]*set_var EASYRSA_KEY_SIZE.*$/set_var EASYRSA_KEY_SIZE        "'"${easyrsa_key_size}"'"/' ${easy_rsa_vars_file}
  sed -i ''     's/^[# ]*set_var EASYRSA_CA_EXPIRE.*$/set_var EASYRSA_CA_EXPIRE       "'"${easyrsa_ca_expire}"'"/' ${easy_rsa_vars_file}
  sed -i ''   's/^[# ]*set_var EASYRSA_CERT_EXPIRE.*$/set_var EASYRSA_CERT_EXPIRE     "'"${easyrsa_cert_expire}"'"/' ${easy_rsa_vars_file}
  #cat ${easy_rsa_vars_file} | grep -e EASYRSA_REQ_COUNTRY -e EASYRSA_REQ_PROVINCE -e EASYRSA_REQ_CITY -e EASYRSA_REQ_ORG -e EASYRSA_REQ_EMAIL -e EASYRSA_REQ_OU -e EASYRSA_KEY_SIZE -e EASYRSA_CA_EXPIRE -e EASYRSA_CERT_EXPIRE
}

# EasyRSA tooling; use "script" to be able to pipe input
easy_rsa_init_pki()
{
  # Initialize PKI
  cd ${etc_easy_rsa}
  script -q /dev/null ./easyrsa.real init-pki

}
easy_rsa_init_ca()
{
  cd ${etc_easy_rsa}
  # Build Certificate Authority
  printf "%s\n%s\n%s\n" "${ca_key_passphrase}" "${ca_key_passphrase}" "${ca_common_name}" | script -q /dev/null ./easyrsa.real build-ca
  cp pki/ca.crt ${openvpn_keys}/
}
easy_rsa_cert_server()
{
  cd ${etc_easy_rsa}
  # Build Server Certificates
  printf "%s\n" "${ca_key_passphrase}" | script -q /dev/null ./easyrsa.real build-server-full "${server_common_name}" nopass
  cp "pki/issued/${server_common_name}.crt" "pki/private/${server_common_name}.key" ${openvpn_keys}/
}
easy_rsa_gen_dh()
{
  # https://security.stackexchange.com/questions/95178/diffie-hellman-parameters-still-calculating-after-24-hours
  cd ${etc_easy_rsa}
  # Generate Diffie Hellman Parameters ${etc_easy_rsa}/pki/dh.pem
  ./easyrsa.real gen-dh
  cp pki/dh.pem ${openvpn_keys}/
}
easy_rsa_setup()
{
  # EasyRSA
  easy_rsa_init
  easy_rsa_config
  easy_rsa_init_pki
  easy_rsa_init_ca
  easy_rsa_cert_server
  easy_rsa_gen_dh
  # EasyRSA
}
openvpn_create_ta()
{
  cd ${etc_easy_rsa}
  # Generate the TA key
  openvpn --genkey --secret ${openvpn_keys}/ta.key 
} 

openvpn_config_init()
{
  cp /usr/local/share/examples/openvpn/sample-config-files/server.conf "${openvpn_conf}"
}
openvpn_config_set()
{
  # OpenVPN server config
  # Clear/remove all setting we "own"
  for cfg_key in proto port ca cert key dh push tls-auth remote-cert-tls user group server
  do
    sed -i ''  's/^[ ]*'${cfg_key}' .*$//g'  "${openvpn_conf}"
  done
  {
    echo ""
    echo "proto ${server_port_type}"
    echo "port ${server_local_port}"
    echo "ca ${openvpn_keys}/ca.crt"
    echo "cert ${openvpn_keys}/${server_common_name}.crt"
    echo "key ${openvpn_keys}/${server_common_name}.key"
    echo "dh ${openvpn_keys}/dh.pem"
    echo "push \"route ${private_network}\""
    echo "server ${nat_network}"
    echo "tls-auth ${openvpn_keys}/ta.key 0"
    echo "remote-cert-tls client"
    echo "user nobody"
    echo "group nobody"
  } >> "${openvpn_conf}"
}
firewall_rules_set()
{
  # Server NAT configuration: nat_network_cidr
cat > /usr/local/etc/ipfw.rules << ENDDOC
#!/bin/sh
EPAIR=\$(/sbin/ifconfig -l | tr " " "\n" | /usr/bin/grep epair)
ipfw -q -f flush
ipfw -q nat 1 config if \${EPAIR}
ipfw -q add nat 1 all from ${nat_network_cidr} to any out via \${EPAIR}
ipfw -q add nat 1 all from any to any in via \${EPAIR}

TUN=\$(/sbin/ifconfig -l | tr " " "\n" | /usr/bin/grep tun)
#  ifconfig \${TUN} name tun0
ENDDOC
}
services_enable()
{
  sysrc -f /etc/rc.conf openvpn_enable="YES"
  sysrc -f /etc/rc.conf openvpn_if="tun"
  sysrc -f /etc/rc.conf openvpn_configfile="${openvpn_conf}"
  sysrc -f /etc/rc.conf openvpn_dir="${etc_openvpn}/"
  sysrc -f /etc/rc.conf cloned_interfaces="tun"
  sysrc -f /etc/rc.conf gateway_enable="YES"
  sysctl net.inet.ip.forwarding=1
  sysrc -f /etc/rc.conf firewall_enable="YES"
  sysrc -f /etc/rc.conf firewall_script="/usr/local/etc/ipfw.rules"
}
openvpn_running()
{
  echo ""  
  if sockstat -4 -l | grep -q -e "nobody.*openvpn.*${server_port_type}.*${server_local_port}"
  then
    echo "--------------------------"
    echo "Sockstat reports OpenVPN listening on ${server_port_type} port ${server_local_port}"
    echo "--------------------------"
  else
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "OpenVPN does NOT seem to be listening on ${server_port_type} port ${server_local_port}"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!"
  fi
}
services_start()
{
  service openvpn start
  service ipfw start
  openvpn_running
}
services_stop()
{
  service openvpn stop
  service ipfw stop
}
logging_config()
{
  # Setup logging
  grep -q openvpn.log /etc/syslog.conf && echo "An openvpn.log line already present" || sed -i ''  's#^!\*$#!openvpn\
  \*\.\*                      /var/log/openvpn.log\
  !\*#' /etc/syslog.conf
  echo '/var/log/openvpn.log           600  30 *   @T00  ZC' > /etc/newsyslog.conf.d/openvpn.conf
}

build_client()
{
  cd ${etc_easy_rsa}

  # Parameters
  client_common_name="$1"
  client_key_passphrase="$2"
  client_cfg_folder="${openvpn_clients}/${client_common_name}"
  client_cfg_file="${client_cfg_folder}/${client_common_name}.ovpn"
  
  if [ "$3" != "" ]
  then
    server_fqdn="$3"
  fi
  if [ "$4" != "" ]
  then
    server_public_port="$4"
  fi
  if [ "$5" != "" ]
  then
    server_port_type="$5"
  fi
  
  
  mkdir -p "${client_cfg_folder}"
  # Build Client Certificate
  printf "%s\n%s\n%s\n" "${client_key_passphrase}" "${client_key_passphrase}" "${ca_key_passphrase}" | script -q /dev/null ./easyrsa.real build-client-full "${client_common_name}"
  cp "${openvpn_keys}/ta.key" "${openvpn_keys}/ca.crt" "pki/issued/${client_common_name}.crt" "pki/private/${client_common_name}.key" "${client_cfg_folder}"

  # OpenVPN client config
  cp /usr/local/share/examples/openvpn/sample-config-files/client.conf "${client_cfg_file}"
  # cat "${etc_openvpn}/${client_common_name}.conf" | grep -e "^remote " -e "^cert " -e "^key "
  sed -i ''  's#^remote .*#remote '"${server_fqdn}"' '"${server_public_port}"'#'  "${client_cfg_file}"
  sed -i ''  's#^cert client.crt$#cert '"${client_common_name}"'.crt#'            "${client_cfg_file}"
  sed -i ''  's#^key client.key$#key '"${client_common_name}"'.key#'              "${client_cfg_file}"
  sed -i ''  's!^proto .*$!proto '"${server_port_type}"'!'                        "${client_cfg_file}"
  # cat "${etc_openvpn}/${client_common_name}.conf" | grep -e "^remote " -e "^cert " -e "^key " -e "^proto "

  echo ""
  echo "A client certificate and configuration set have been created at ${client_cfg_folder}"
  echo ""
}

build_server()
{
  load_variables_from_file

  create_folders

  easy_rsa_setup
  
  openvpn_create_ta
  openvpn_config_init
  openvpn_config_set

  firewall_rules_set

  services_enable
  
  logging_config
  
  services_start
}
rebuild_all()
{
  services_stop
  build_server
  build_client ${a_client_common_name} "${a_client_key_passphrase}"
}
restart_openvpn()
{
  service openvpn stop
  service openvpn start
  
  openvpn_running
}
restart_firewall()
{
  service ipfw stop
  service ipfw start
  
  openvpn_running
}
apply_config()
{
  load_variables_from_file
  
  easy_rsa_config # ${easy_rsa_vars_file}
  openvpn_config_set # ${openvpn_conf}
  firewall_rules_set # /usr/local/etc/ipfw.rules
  
  services_stop
  services_start
}
service_management()
{
  action="$1"
  
  case "${action}" in
    restart_openvpn)
      restart_openvpn
      exit
      ;;
    restart_firewall)
      restart_firewall
      exit
      ;;
    apply_config)
      apply_config
      exit
      ;;
    rebuild_all)
      rebuild_all
      exit
      ;;
    *)
      echo "Unknown action ${action}"
      ;;
  esac
}
short_explanation()
{
  load_variables_from_file
  echo ""
  echo "The following (default) settings have been used:"
  for a_var in server_local_port server_port_type private_network= nat_network_cidr nat_network server_fqdn server_public_port
  do
    eval 'echo '${a_var}'=${'${a_var}'}'
  done
  echo ""
  echo "OpenVPN server should now be running on server_port_type ${server_port_type} server_local_port ${server_local_port}"
  echo "It will provide access for remote clients to your local network (private_network): ${private_network}" 
  echo ""
  echo "An intermediate network is used by the client behind a NAT translation (nat_network_cidr/nat_network): ${nat_network_cidr} / ${nat_network}"
  echo "This should NOT overlap with your private network."
  echo ""
  echo "Client configurations which will be created will have them connect to (server_fqdn): ${server_fqdn}"
  echo "Clients will connect on server_port_type ${server_port_type}, server_public_port: ${server_public_port}"
  echo "You need to configure port-forwarding at the firewall in front of the OpenVPN jail to forward ${server_port_type}/${server_public_port} to this Jail at ${server_port_type}/${server_local_port}"
  echo ""
  echo "Client generation/configuration can be done using iocage:"
  echo "E.g.    iocage set -P addclient=yourclientname,somesecurecertpassphrase $HOST"
  echo "This will create a configuration folder at /usr/local/etc/openvpn/clients"
  echo ""
  echo "By current default it will connect to server_fqdn ${server_fqdn}, server_port_type ${server_port_type}/server_public_port ${server_public_port}"
  echo "To override this at generation:"
  echo "E.g.    iocage set -P addclient=yourclientname,somesecurecertpassphrase,your.server.fqdn.com,444 $HOST"
  echo ""
  echo "For changing and applying server attributes, use iocage as well. Please consult the README for this."
}
