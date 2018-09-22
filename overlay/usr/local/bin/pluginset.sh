#!/bin/sh
. /root/library.sh

load_variables_from_file

# echo $*

case "$1" in
  addclient)
    build_client "$2" "$3" "$4" "$5" "$6"
    exit
    ;;
  service)
    service_management "$2"
esac

var_name="$1"
shift
var_newvalue="$*"
while IFS= read line
do    
  name=`echo $line | cut -f 1 -d =`
  
  case "${var_name}" in 
    "${name}")
      var_newvalue_escaped=`echo "${var_newvalue}" | sed -e 's/([\.\\\!])/\\\1/g'`
      name=`echo $line | cut -f 1 -d =`
      eval 'echo change '${name}'=${'$name'} to =${var_newvalue_escaped}'
      sed -i '' 's!^.*'"${var_name}"'.*$!'"${var_name}"'="'"${var_newvalue_escaped}"'"!' "${vars_file}"
      exit
      ;;
  esac
done <"${vars_file}"

echo "Unknown option $*"

