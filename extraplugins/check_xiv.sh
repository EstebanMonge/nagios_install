#!/bin/bash
###################################################################################
# Esteban Monge
# emonge@gbm.net
# Ver 0.1b
# 04/02/12
# Sources:
# http://blog.felixbrezo.com/?p=473
# http://wiki.bash-hackers.org/howto/getopts_tutorial
# http://www.linuxquestions.org/questions/linux-general-1/store-multi-line-output-into-an-array-in-a-linux-bash-script-706878/
# http://stackoverflow.com/questions/4667509/problem-accessing-a-global-variable-from-within-a-while-loop
# http://publib.boulder.ibm.com/infocenter/ibmxiv/r2/index.jsp?topic=%2Fcom.ibm.help.xivgen3.doc%2Fxiv_cmdcontainer.html
###################################################################################

# Set xcli path, usually located in /opt/XIVGUI
xcli_path='/opt/XIVGUI';
CHECK_STATE=0;

# Function for help and usage
showHelp () {
echo -e "USE:"
echo -e "\t$0 [-H -u -p -C -w -c | -h]"
echo -e "OPTIONS:"
echo -e "\t-H\tIP Address"
echo -e "\t-u\tUsername"
echo -e "\t-p\tPassword"
echo -e "\t-C\tXIV Command"
echo -e "\t-w\tWarning threshold"
echo -e "\t-c\tCritical threshold"
echo -e "\t-h\tThis Help"
}

# Function for obtain XIV components is Not OK
componentNOTOK ()
{
# Start to obtain xcli output
i=0
while read line
do
    array[$i]="$line"
    if [  $i != "0" ]
    then
# Determine Not OK Components
	case "${array[$i]}" in  
		*"OK"*)
		;;
		*"Component"*)
		;; 
		*) CHECK_STATE=2
		PROBLEM="$PROBLEM "`echo "${array[$i]}" | awk '{ print $1 " " $2; }'`
		;;
	esac
    fi
    (( i++ ))
done < <($xcli_path/xcli -m $HOSTNAME -u $USERNAME -p $PASSWORD $COMMAND)
}

# Function for obtain Critical Event from XIV
criticalEVENTS ()
{
# Start to obtain xcli output
i=0
while read line
do
    array[$i]="$line"
    if [  $i != "0" ]
    then
# Determine Not OK Components
	case "${array[$i]}" in  
		*"Critical"*) CHECK_STATE=2
		   PROBLEM="$PROBLEM "`echo "${array[$i]}" | awk '{ print $1 " " $2 " " $4; }'`
		;;
		*)
		;;
	esac
    fi
    (( i++ ))
done < <($xcli_path/xcli -m $HOSTNAME -u $USERNAME -p $PASSWORD $COMMAND max_events=10)
}
# Catch options
while getopts "H: u: p: C: w:c:h" OPTION; do
  case $OPTION in
    H)
      HOSTNAME=$OPTARG
      ;;
    u)
      USERNAME=$OPTARG
      ;;
    p)
      PASSWORD=$OPTARG
      ;;
    C)
      COMMAND=$OPTARG 
      ;;
    w)
      WARNING=$OPTARG
      ;;
    c)
      CRITICAL=$OPTARG
      ;;
    h) 
      showHelp
      ;;
    \?)
      showHelp
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 3
      ;;
  esac
done

# Limit available commands
case $COMMAND in
     cf_list) componentNOTOK;;
     dimm_list) componentNOTOK;;
     disk_list) componentNOTOK;;
     ethernet_cable_list) componentNOTOK;;
     fan_list) componentNOTOK;;
     module_list) componentNOTOK;;
     psu_list) componentNOTOK;;
     ups_list) componentNOTOK;;
     event_list) criticalEVENTS;;
     *) echo "UNKNOWN: Command $COMMAND not supported or not exist"
	exit 3;;
esac

# Determine output
case "$CHECK_STATE" in
	0) echo "OK: $COMMAND Full full perfect"
	   exit $CHECK_STATE
	   ;;
	2) echo "CRITICAL: $COMMAND problem found $PROBLEM" 
	   exit $CHECK_STATE
	   ;;
	*) echo "UNKNOWN: $COMMAND with config problems"
	   exit $CHECK_STATE

esac
