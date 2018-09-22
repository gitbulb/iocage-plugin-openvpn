#!/bin/sh

. /root/library.sh
load_variables_from_file

eval 'testvar=${'$1'}'

if [ "${testvar}" == "" ]
then
  echo "Unknown option: $*"
else
  eval 'echo ${'$1'}'
fi
