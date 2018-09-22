#!/bin/sh
. /root/library.sh

build_server

build_client ${a_client_common_name} "${a_client_key_passphrase}"

openvpn_running

short_explanation
