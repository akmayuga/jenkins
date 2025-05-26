#!/bin/bash
set -x

# Check file if exists
if [[ ! -s $1 ]];then echo -e "File does not exist";exit 1;fi

# Check argument validity
if [[ $# -eq 0 ]];then echo -e "Must supply inventory RID file\nUsage:\tbash $0 <file>";exit 1;fi

# Check if script will be run by sktuser
if [[ `whoami` != "sktuser" ]];then echo -e "Must be sktuser to execute this script";exit 1;fi

# Set output file name
OUTPUT_FILE=$1-`date +%y%m%d%H%M%S`.txt
echo -e "\nGenerated output file $OUTPUT_FILE"

# Read each line
for i in `cat $1`;do
	echo -e "\tChecking $i"
	unset NUC_IP OPENVOX_IP CHECK_TYPE NUC_ARCHITECTURE FXO_JAVA_INSTALLER
	# Get NUC IP
	NUC_IP=`show-vpn-ips|grep -i $i|grep ^[0-9][0-9]|cut -d\, -f1`
	if [[ `echo $NUC_IP` == "" ]];then 
		echo "$i - Failed to capture IP address" >> $OUTPUT_FILE
		continue
	fi

    # Identify if it is an Openvox or Patton
    OPENVOX_IP=`timeout 60 ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no sktuser@$NUC_IP "sudo --non-interactive /usr/bin/get-openvox-ip.sh" 2>/dev/null`
    CHECK_TYPE=`timeout 60 ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no sktuser@$NUC_IP "uname -m;echo '^]quit' | telnet $OPENVOX_IP 12345 2>/dev/null | grep Connected" 2>/dev/null`
    if [[ `echo $CHECK_TYPE|grep Connected` == "" ]];then 
        echo "$i - Failed to connect to Openvox port. Either a Patton or Openvox is down" >> $OUTPUT_FILE
        continue
    fi

    # Check device architecture
    NUC_ARCHITECTURE=`echo "$CHECK_TYPE"|head -1`
    if [[ $NUC_ARCHITECTURE == "x86_64" ]];then
        FXO_JAVA_INSTALLER=/home/sktuser/OpenJDK8U-jre_x64_linux_hotspot_8u422b05.tar.gz
    else
        # since we have no installer for non x86 arch, we return it with error
        echo "$i - Java installer does not support $NUC_ARCHITECTURE architecture" >> $OUTPUT_FILE
        continue
    fi

    # Upload java installer
    rsync $FXO_JAVA_INSTALLER $NUC_IP:/home/sktuser 2>/dev/null

    # Install JAVA to NUC, update crontab crontab to use the new uploaded java
    if [[ $? -ne 0 ]];then
        echo "$i - Failed to download installer" >> $OUTPUT_FILE
        continue
    fi
    ssh -tt -o ServerAliveInterval=1 -o ServerAliveCountMax=1 $NUC_IP "sudo rm -rf /usr/java/jre1.8.0_422 2>/dev/null;sudo tar -zxvf $FXO_JAVA_INSTALLER >/dev/null 2>&1 && sudo mv -f jdk8u422-b05-jre /usr/java/jre1.8.0_422 && sudo sed -i 's|/usr/java/.*/bin/java|/usr/java/jre1.8.0_422/bin/java|g' /var/spool/cron/root" 2>/dev/null
        if [[ $? -ne 0 ]];then
        echo "$i - Failed to Upload java installer"
        continue
    fi
	
    echo "$i - OK. Successfully updated fxo script" >> $OUTPUT_FILE
	continue
done
