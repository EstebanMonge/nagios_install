#!/bin/bash

PLUG_PATH='/usr/local/nagios/libexec'

VAR=`$PLUG_PATH/check_snmp -H $1 -o $2 -C $3 -r="*0 days*" --invert-search`

VAR2=`echo $VAR | awk '{print $5}' | cut -d ')' -f 1 | sed 's/^.//'`

VAR3=`expr $VAR2 / 100`

VAR4=`expr $VAR2 / 6000`

VAR5=`expr $VAR2 / 360000`

VAR6=`expr $VAR2 / 8640000`

echo $VAR Seconds=$VAR3 Minutes=$VAR4 Hours=$VAR5 Days=$VAR6 Timeticks=$VAR2 
