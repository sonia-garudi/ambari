#!/bin/bash
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#

############################
## NOTE:
##      1) This script should be executed on NameNode host as that host is guaranteed to have all the users needed while creating keytab file
##      2) The script has been verified to work in gce environment and 
##         vagrant environment documented at ambari wiki: https://cwiki.apache.org/confluence/display/AMBARI/Quick+Start+Guide 
###########################

usage () {
echo "Usage: keytabs.sh <HOST_PRINCIPAL_KEYTABLE.csv> <SSH_LOGIN_KEY_PATH>";
echo "  <HOST_PRINCIPAL_KEYTABLE.csv>: CSV file generated by 'Enable Security Wizard' of Ambari";
echo "  <SSH_LOGIN_KEY_PATH>: File path to the ssh login key for root user";
exit 1;
}

###################
## processCSVFile()
###################
processCSVFile () {
    csvFile=$1;
    csvFile=$(printf '%q' "$csvFile")
    touch generate_keytabs.sh;
    chmod 755 generate_keytabs.sh;

    echo "#!/bin/bash" > generate_keytabs.sh;
    echo "###########################################################################" >> generate_keytabs.sh;
    echo "###########################################################################" >> generate_keytabs.sh;
    echo "## " >> generate_keytabs.sh;
    echo "## Ambari Security Script Generator" >> generate_keytabs.sh;
    echo "## "  >> generate_keytabs.sh;
    echo "## Ambari security script is generated which should be run on the" >> generate_keytabs.sh;
    echo "## Kerberos server machine." >> generate_keytabs.sh;
    echo "## " >> generate_keytabs.sh;
    echo "## Running the generated script will create host specific keytabs folders." >> generate_keytabs.sh;
    echo "## Each of those folders will contain service specific keytab files with " >> generate_keytabs.sh;
    echo "## appropriate permissions. There folders should be copied as the appropriate" >> generate_keytabs.sh;
    echo "## host's '/etc/security/keytabs' folder" >> generate_keytabs.sh;
    echo "###########################################################################" >> generate_keytabs.sh;
    echo "###########################################################################" >> generate_keytabs.sh;
    
    rm -f commands.mkdir;
    rm -f commands.chmod;
    rm -f commands.addprinc;
    rm -f commands.xst
    rm -f commands.xst.cp
    rm -f commands.chown.1
    rm -f commands.chmod.1
    rm -f commands.chmod.2
    rm -f commands.tar
    
    seenHosts="";
    seenPrincipals="";
    
    echo "mkdir -p ./tmp_keytabs" >> commands.mkdir;
    cat $csvFile | while read line; do
        hostName=`echo $line|cut -d , -f 1`;
        service=`echo $line|cut -d , -f 2`;
        principal=`echo $line|cut -d , -f 3`;
        keytabFile=`echo $line|cut -d , -f 4`;
        keytabFilePath=`echo $line|cut -d , -f 5`;
        owner=`echo $line|cut -d , -f 6`;
        group=`echo $line|cut -d , -f 7`;
        acl=`echo $line|cut -d , -f 8`;
        
        if [[ $seenHosts != *$hostName* ]]; then
              echo "mkdir -p ./keytabs_$hostName" >> commands.mkdir;
              echo "chmod 755 ./keytabs_$hostName" >> commands.chmod;
              echo "chown -R root:$group `pwd`/keytabs_$hostName" >> commands.chown.1
              echo "tar -cvf keytabs_$hostName.tar -C keytabs_$hostName ." >> commands.tar
              seenHosts="$seenHosts$hostName";
        fi
        
        if [[ $seenPrincipals != *" $principal"* ]]; then
          echo -e "kadmin.local -q \"addprinc -randkey $principal\"" >> commands.addprinc;
          seenPrincipals="$seenPrincipals $principal"
        fi
        tmpKeytabFile="`pwd`/tmp_keytabs/$keytabFile";
	    newKeytabPath="`pwd`/keytabs_$hostName$keytabFilePath";
	    newKeytabFile="$newKeytabPath/$keytabFile";
        if [ ! -f $tmpKeytabFile ]; then
          echo "kadmin.local -q \"xst -k $tmpKeytabFile $principal\"" >> commands.xst;          
        fi
        if [ ! -d $newKeytabPath ]; then
            echo "mkdir -p $newKeytabPath" >> commands.mkdir;
        fi
        echo "cp $tmpKeytabFile $newKeytabFile" >> commands.xst.cp
        echo "chmod $acl $newKeytabFile" >> commands.chmod.2
        echo "chown $owner:$group $newKeytabFile" >> commands.chown.1
    done;
    
    
    echo "" >> generate_keytabs.sh;
    echo "" >> generate_keytabs.sh;
    echo "###########################################################################" >> generate_keytabs.sh;
    echo "# Making host specific keytab folders" >> generate_keytabs.sh;
    echo "###########################################################################" >> generate_keytabs.sh;
    cat commands.mkdir >> generate_keytabs.sh;
    echo "" >> generate_keytabs.sh;
    echo "###########################################################################" >> generate_keytabs.sh;
    echo "# Changing permissions for host specific keytab folders" >> generate_keytabs.sh;
    echo "###########################################################################" >> generate_keytabs.sh;
    cat commands.chmod >> generate_keytabs.sh;
    echo "" >> generate_keytabs.sh;
    echo "###########################################################################" >> generate_keytabs.sh;
    echo "# Creating Kerberos Principals" >> generate_keytabs.sh;
    echo "###########################################################################" >> generate_keytabs.sh;
    cat commands.addprinc >> generate_keytabs.sh;
    echo "" >> generate_keytabs.sh;
    echo "###########################################################################" >> generate_keytabs.sh;
    echo "# Creating Kerberos Principal keytabs in host specific keytab folders" >> generate_keytabs.sh;
    echo "###########################################################################" >> generate_keytabs.sh;
    cat commands.xst >> generate_keytabs.sh;
    cat commands.xst.cp >> generate_keytabs.sh;
    echo "" >> generate_keytabs.sh;
    echo "###########################################################################" >> generate_keytabs.sh;
    echo "# Changing ownerships of host specific keytab files" >> generate_keytabs.sh;
    echo "###########################################################################" >> generate_keytabs.sh;
    cat commands.chown.1 >> generate_keytabs.sh;
    echo "" >> generate_keytabs.sh;
    echo "###########################################################################" >> generate_keytabs.sh;
    echo "# Changing access permissions of host specific keytab files" >> generate_keytabs.sh;
    echo "###########################################################################" >> generate_keytabs.sh;
    #cat commands.chmod.1
    cat commands.chmod.2 >> generate_keytabs.sh;
    echo "" >> generate_keytabs.sh;
    echo "###########################################################################" >> generate_keytabs.sh;
    echo "# Packaging keytab folders" >> generate_keytabs.sh;
    echo "###########################################################################" >> generate_keytabs.sh;
    cat commands.tar >> generate_keytabs.sh;
    echo "" >> generate_keytabs.sh;
    echo "###########################################################################" >> generate_keytabs.sh;
    echo "# Cleanup" >> generate_keytabs.sh;
    echo "###########################################################################" >> generate_keytabs.sh;
    echo "rm -rf ./tmp_keytabs" >> generate_keytabs.sh;
    echo "" >> generate_keytabs.sh;
    echo "echo \"****************************************************************************\"" >> generate_keytabs.sh;
    echo "echo \"****************************************************************************\"" >> generate_keytabs.sh;
    echo "echo \"** Copy and extract 'keytabs_[hostname].tar' files onto respective hosts. **\"" >> generate_keytabs.sh;
    echo "echo \"**                                                                        **\"" >> generate_keytabs.sh;
    echo "echo \"** Generated keytab files are preserved in the 'tmp_keytabs' folder.      **\"" >> generate_keytabs.sh;
    echo "echo \"****************************************************************************\"" >> generate_keytabs.sh;
    echo "echo \"****************************************************************************\"" >> generate_keytabs.sh;
    
    rm -f commands.mkdir >> generate_keytabs.sh;
    rm -f commands.chmod >> generate_keytabs.sh;
    rm -f commands.addprinc >> generate_keytabs.sh;
    rm -f commands.xst >> generate_keytabs.sh;
    rm -f commands.xst.cp >> generate_keytabs.sh;
    rm -f commands.chown.1 >> generate_keytabs.sh;
    rm -f commands.chmod.1 >> generate_keytabs.sh;
    rm -f commands.chmod.2 >> generate_keytabs.sh;
    rm -f commands.tar >> generate_keytabs.sh;
    # generate keytabs
    sh ./generate_keytabs.sh
}

########################
## installKDC () : Install rng tools,pdsh on KDC host and KDC packages on all host. Modify krb5 file
########################
installKDC () {
  csvFile=$1;
  sshLoginKey=$2;
  HOSTNAME=`hostname --fqdn`
  scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  krb5_new_conf=$scriptDir"/krb5.conf"
  krb5_conf="/etc/krb5.conf"
  #export additional path for suse and centos5
  PATH=$PATH:/usr/lib/mit/sbin/:/usr/kerberos/sbin/:/usr/sbin/:/sbin/
  # Install rng tools
  installRngtools
  # Install kdc server on this host
  $inst_cmd $server_packages
  # Configure /etc/krb5.conf
  cp $krb5_conf $krb5_conf".bak"
  cp $krb5_new_conf $krb5_conf
  sed -i "s/\(kdc *= *\).*kerberos.example.com.*/\1$HOSTNAME/" $krb5_conf
  sed -i "s/\(admin_server *= *\).*kerberos.example.com.*/\1$HOSTNAME/" $krb5_conf
  # Create principal key and start services
  if [[ ! -f $principal_file ]]; then
    echo -ne '\n\n' | kdb5_util create -s
    $kdc_services_start
  fi
  # Install pdsh on this host
  $inst_cmd pdsh;
  chown root:root -R /usr;
  eval `ssh-agent`
  ssh-add $sshLoginKey
  hostNames='';
  while read line; do
    hostName=`echo $line|cut -d , -f 1`;
    if [ -z "$hostNames" ]; then
      hostNames=$hostName;
      continue;
    fi
    if [[ $hostNames != *$hostName* ]]; then
      hostNames=$hostNames,$hostName;
    fi
  done < $csvFile
  # Check all hosts for passwordless ssh
  OLD_IFS=$IFS
  IFS=,
  for host in $hostNames; do
    checkSSH $host
  done
  IFS=$OLD_IFS
  export PDSH_SSH_ARGS_APPEND="-q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PreferredAuthentications=publickey"
  pdsh -R ssh -w $hostNames "$inst_cmd $client_packages"
  pdsh -R ssh -w $hostNames "$inst_cmd pdsh"
  pdsh -R ssh -w $hostNames chown root:root -R /usr
  pdcp -R ssh -w $hostNames $krb5_conf $krb5_conf
}

########################
## distributeKeytabs () : Distribute the tar on all respective hosts root directory and untar it
########################
distributeKeytabs () {
  shopt -s nullglob  
  filearray=(keytabs_*tar)
  for i in ${filearray[@]}; do
    derivedname=${i%.*}
    derivedname=${derivedname##keytabs_}
    echo $derivedname
    scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $i root@$derivedname:/
    ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$derivedname "cd /;tar xvf $i --no-overwrite-dir"
  done
}

########################
## getEnvironmentCMD () : get linux distribution type and package manager
########################
getEnvironmentCMD () {
  os=`python -c 'import sys; sys.path.append("/usr/lib/python2.6/site-packages/"); from ambari_commons import OSCheck; print OSCheck.get_os_family()'`
  version=`python -c 'import sys; sys.path.append("/usr/lib/python2.6/site-packages/"); from ambari_commons import OSCheck; print OSCheck.get_os_major_version()'`
  os=$os$version;
  case $os in
  'debian12' )
    pkgmgr='apt-get'
    inst_cmd="env DEBIAN_FRONTEND=noninteractive /usr/bin/$pkgmgr --allow-unauthenticated --assume-yes install -f "
    client_packages="krb5-user libpam-krb5 libpam-ccreds auth-client-config"
    server_packages="krb5-kdc krb5-admin-server $client_packages"
    rng_tools="rng-tools"
    principal_file="/etc/krb5kdc/principal"
    kdc_services_start="service krb5-admin-server start; service krb5-kdc start"
    ;;
  'redhat5' )
    pkgmgr='yum'
    inst_cmd="/usr/bin/$pkgmgr -y install "
    client_packages="krb5-workstation"
    server_packages="krb5-server krb5-libs krb5-auth-dialog $client_packages"
    rng_tools="rng-utils"
    principal_file="/var/kerberos/krb5kdc/principal"
    kdc_services_start="service kadmin start; service krb5kdc start"
    ;;
  'redhat6' )
    pkgmgr='yum'
    inst_cmd="/usr/bin/$pkgmgr -y install "
    client_packages="krb5-workstation"
    server_packages="krb5-server krb5-libs krb5-auth-dialog $client_packages"
    rng_tools="rng-tools"
    principal_file="/var/kerberos/krb5kdc/principal"
    kdc_services_start="service kadmin start; service krb5kdc start"
    ;;
  'suse11' )
    pkgmgr='zypper'
    inst_cmd="/usr/bin/$pkgmgr install --auto-agree-with-licenses --no-confirm "
    client_packages="krb5-client"
    server_packages="krb5 krb5-server $client_packages"
    rng_tools="rng-tools"
    principal_file="/var/lib/kerberos/krb5kdc/principal"
    kdc_services_start="krb5kdc"
    ;;
  esac
}

########################
## checkUser () : If the user executing the script is not "root" then exit
########################
checkUser () {
  userid=`id -u`;
  if (($userid != 0)); then
    echo "ERROR: The script needs to be executed by root user"
    exit 1;
  fi
}

########################
## checkSSH () : If passwordless ssh for root is not configured then exit
########################
checkSSH () {
  host=$1
  ssh -oPasswordAuthentication=no -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $host "exit 0" && return_value=0 || return_value=$? && true
  if [[ $return_value != 0 ]]; then
    echo "ERROR: Passwordless ssh for user root is not configured for host $host"
    exit 1;
  fi
}

########################
## installRngtools () : Install and start rng-tools
########################
installRngtools () {
  $inst_cmd $rng_tools
  echo $inst_cmd $rng_utils
  if [ $os == 'debian12' ] || [ $os == 'suse11' ]; then
    echo "HRNGDEVICE=/dev/urandom" >> /etc/default/rng-tools
    /etc/init.d/rng-tools start || true
  elif [ $os == 'redhat5' ]; then
    /sbin/rngd -r /dev/urandom -o /dev/random -f -t .001 --background
  else
    sed -i "s/\(EXTRAOPTIONS *= *\).*/\1\"-r \/dev\/urandom\"/" "/etc/sysconfig/rngd"
    # start rngd
    /etc/init.d/rngd start
  fi
}

if (($# != 2)); then
    usage
fi

set -e
checkUser
getEnvironmentCMD
installKDC $@
processCSVFile $@
distributeKeytabs $@

