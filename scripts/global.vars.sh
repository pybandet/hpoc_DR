#!/usr/bin/env bash

# shellcheck disable=SC2034
RELEASE='release.json'
PC_DEV_VERSION='pc.2020.9'
PC_CURRENT_VERSION='pc.2020.9'
PC_STABLE_VERSION='5.17.0.3'
FILES_VERSION='3.7.1'
FILE_ANALYTICS_VERSION='2.2.0'
NTNX_INIT_PASSWORD='nutanix/4u'
PRISM_ADMIN='admin'
SSH_PUBKEY="${HOME}/.ssh/id_rsa.pub"
STORAGE_POOL='SP01'
STORAGE_DEFAULT='Default'
STORAGE_IMAGES='Images'
STORAGE_ERA='Era'
ATTEMPTS=40
SLEEP=60
PrismOpsServer='PrismOpsLabUtilityServer'
SeedPC='seedPC.zip'
BasicUnattend='basic_unattend.xml'
CALM_RSA_KEY_FILE='calm_rsa_key.env'

Citrix_Blueprint='CitrixBootcampInfra.json'
Beam_Blueprint=''
Karbon_Blueprint='KarbonClusterDeployment.json'
CICDInfra_Blueprint='CICD_Infra.json'

# Curl and SSH settings
CURL_OPTS='--insecure --silent --show-error' # --verbose'
CURL_POST_OPTS="${CURL_OPTS} --max-time 5 --header Content-Type:application/json --header Accept:application/json --output /dev/null"
CURL_HTTP_OPTS="${CURL_POST_OPTS} --write-out %{http_code}"
SSH_OPTS='-o StrictHostKeyChecking=no -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/dev/null'
SSH_OPTS+=' -q' # -v'

####################################################
# Users for Tools VMs and Source VMs
###################################################

USERS=(\
   User01 \
   User02 \
   User03 \
   User04 \
   User05 \
   User06 \
)

####################################################
# Era VARs
###################################################

ERA_Blueprint='EraServerDeployment.json'
ERAServerImage='ERA-Server-build-2.0.0.qcow2'
ERAServerName='EraServer'
ERA_USER="admin"
#ERA_PASSWORD="nutanix/4u"
ERA_PASSWORD="${PE_PASSWORD}"
ERA_Default_PASSWORD="Nutanix/4u"
ERA_NETWORK="Secondary"
ERA_Container_RF="2"

MSSQL_SourceVM="MSSQLSourceVM"
MSSQL_SourceVM_Image1="MSSQL_1"
MSSQL_SourceVM_Image2="MSSQL_2"

Oracle_12c_SourceVM="Oracle12cSource"
Oracle_12c_SourceVM_BootImage="12c_bootdisk"
Oracle_12c_SourceVM_Image1="12c_disk1"
Oracle_12c_SourceVM_Image2="12c_disk2"
Oracle_12c_SourceVM_Image3="12c_disk3"
Oracle_12c_SourceVM_Image4="12c_disk4"
Oracle_12c_SourceVM_Image5="12c_disk5"
Oracle_12c_SourceVM_Image6="12c_disk6"

Oracle_19c_SourceVM="Oracle19cSource"
Oracle_19c_SourceVM_BootImage="19c-bootdisk"
Oracle_19c_SourceVM_Image1="19c-disk1"
Oracle_19c_SourceVM_Image2="19c-disk2"
Oracle_19c_SourceVM_Image3="19c-disk3"
Oracle_19c_SourceVM_Image4="19c-disk4"
Oracle_19c_SourceVM_Image5="19c-disk5"
Oracle_19c_SourceVM_Image6="19c-disk6"
Oracle_19c_SourceVM_Image7="19c-disk7"
Oracle_19c_SourceVM_Image8="19c-disk8"
Oracle_19c_SourceVM_Image9="19c-disk9"

####################################################
# 3rd Party images used at GTS or Add-On Labs
###################################################
#Peer Software
PeerMgmtServer='Windows2016-PeerMgmt-30sep20'
PeerAgentServer='Windows2016-PeerAgent-30sep20'
PMC="PeerMgmt"
AGENTA="PeerAgent-Files"
AGENTB="PeerAgent-Win"

#Hycu
HycuServer='HYCU-4.0.3-Demo'

#Veeam
VeeamServer=''

##################################
#
# Look for JQ, AutoDC, and QCOW2 Repos in DC specific below.
#
##################################

_prio_images_arr=(\
  ERA-Server-build-1.2.1.qcow2 \
  Windows2016.qcow2 \
  CentOS7.qcow2 \
  Citrix_Virtual_Apps_and_Desktops_7_1912.iso \
)

QCOW2_IMAGES=(\
   CentOS7.qcow2 \
   Windows2016.qcow2 \
   Windows2012R2.qcow2 \
   Windows10-1709.qcow2 \
   WinToolsVM.qcow2 \
   Linux_ToolsVM.qcow2 \
   ERA-Server-build-1.2.1.qcow2 \
   MSSQL-2016-VM.qcow2 \
   hycu-3.5.0-6253.qcow2 \
   VeeamAvailability_1.0.457.vmdk \
   move3.2.0.qcow2 \
)
ISO_IMAGES=(\
   CentOS7.iso \
   Windows2016.iso \
   Windows2012R2.iso \
   Windows10.iso \
   Nutanix-VirtIO-1.1.5.iso \
   VeeamBR_9.5.4.2615.Update4.iso \
)

# shellcheck disable=2206
OCTET=(${PE_HOST//./ }) # zero index
IPV4_PREFIX=${OCTET[0]}.${OCTET[1]}.${OCTET[2]}
DATA_SERVICE_IP=${IPV4_PREFIX}.$((${OCTET[3]} + 1))
PC_HOST=${IPV4_PREFIX}.$((${OCTET[3]} + 2))
FILE_ANALYTICS_HOST=${IPV4_PREFIX}.$((${OCTET[3]} - 22))
PrismOpsServer_HOST="${IPV4_PREFIX}.$((${OCTET[3]} + 5))"
ERA_HOST=${IPV4_PREFIX}.$((${OCTET[3]} + 7))
CITRIX_DDC_HOST=${IPV4_PREFIX}.$((${OCTET[3]} + 8))
BUCKETS_DNS_IP="${IPV4_PREFIX}.16"
BUCKETS_VIP="${IPV4_PREFIX}.17"
OBJECTS_NW_START="${IPV4_PREFIX}.18"
OBJECTS_NW_END="${IPV4_PREFIX}.21"
DNS_SERVERS='8.8.8.8'
NTP_SERVERS='0.us.pool.ntp.org,1.us.pool.ntp.org,2.us.pool.ntp.org,3.us.pool.ntp.org'
SUBNET_MASK="255.255.255.128"

# Getting the network ready

NW1_NAME='Primary'
NW1_VLAN=0

# TODO: Need to make changes to the network configuration if we are running against a single Node Cluster
# https://confluence.eng.nutanix.com:8443/pages/viewpage.action?spaceKey=SEW&title=Bootcamps%3A+Networking+Scheme

case "${OCTET[3]}" in

  7 ) # We are in Partition 1
    NW1_SUBNET="${IPV4_PREFIX}.1/26"
    NW1_GATEWAY="${IPV4_PREFIX}.1"
    NW1_DHCP_START="${IPV4_PREFIX}.38"
    NW1_DHCP_END="${IPV4_PREFIX}.58"
    NW2_NAME=''
    NW2_VLAN=''
    NW2_SUBNET=''
    NW2_DHCP_START=''
    NW2_DHCP_END=''
    NW3_NAME=''
    NW3_NETMASK=''
    NW3_START=""
    NW3_END=""
    ERA_NETWORK="Primary"
    ERA_Container_RF="1"
    BUCKETS_DNS_IP=${IPV4_PREFIX}.$((${OCTET[3]} + 25))
    BUCKETS_VIP=${IPV4_PREFIX}.$((${OCTET[3]} + 26))
    OBJECTS_NW_START=${IPV4_PREFIX}.$((${OCTET[3]} + 27))
    OBJECTS_NW_END=${IPV4_PREFIX}.$((${OCTET[3]} + 30))
    ;;

  71 ) # We are in Partition 2
    NW1_SUBNET="${IPV4_PREFIX}.65/26"
    NW1_GATEWAY="${IPV4_PREFIX}.65"
    NW1_DHCP_START="${IPV4_PREFIX}.102"
    NW1_DHCP_END="${IPV4_PREFIX}.122"
    NW2_NAME=''
    NW2_VLAN=''
    NW2_SUBNET=''
    NW2_DHCP_START=''
    NW2_DHCP_END=''
    NW3_NAME=''
    NW3_NETMASK=''
    NW3_START=""
    NW3_END=""
    ERA_NETWORK="Primary"
    ERA_Container_RF="1"
    BUCKETS_DNS_IP=${IPV4_PREFIX}.$((${OCTET[3]} + 25))
    BUCKETS_VIP=${IPV4_PREFIX}.$((${OCTET[3]} + 26))
    OBJECTS_NW_START=${IPV4_PREFIX}.$((${OCTET[3]} + 27))
    OBJECTS_NW_END=${IPV4_PREFIX}.$((${OCTET[3]} + 30))
    ;;

  135 ) # We are in Partition 3
    NW1_SUBNET="${IPV4_PREFIX}.129/26"
    NW1_GATEWAY="${IPV4_PREFIX}.129"
    NW1_DHCP_START="${IPV4_PREFIX}.166"
    NW1_DHCP_END="${IPV4_PREFIX}.186"
    NW2_NAME=''
    NW2_VLAN=''
    NW2_SUBNET=''
    NW2_DHCP_START=''
    NW2_DHCP_END=''
    NW3_NAME=''
    NW3_NETMASK=''
    NW3_START=""
    NW3_END=""
    ERA_NETWORK="Primary"
    ERA_Container_RF="1"
    BUCKETS_DNS_IP=${IPV4_PREFIX}.$((${OCTET[3]} + 25))
    BUCKETS_VIP=${IPV4_PREFIX}.$((${OCTET[3]} + 26))
    OBJECTS_NW_START=${IPV4_PREFIX}.$((${OCTET[3]} + 27))
    OBJECTS_NW_END=${IPV4_PREFIX}.$((${OCTET[3]} + 30))
    ;;

  199 ) # We are in Partition 4
    NW1_SUBNET="${IPV4_PREFIX}.193/26"
    NW1_GATEWAY="${IPV4_PREFIX}.193"
    NW1_DHCP_START="${IPV4_PREFIX}.230"
    NW1_DHCP_END="${IPV4_PREFIX}.250"
    NW2_NAME=''
    NW2_VLAN=''
    NW2_SUBNET=''
    NW2_DHCP_START=''
    NW2_DHCP_END=''
    NW3_NAME=''
    NW3_NETMASK=''
    NW3_START=""
    NW3_END=""
    ERA_NETWORK="Primary"
    ERA_Container_RF="1"
    BUCKETS_DNS_IP=${IPV4_PREFIX}.$((${OCTET[3]} + 25))
    BUCKETS_VIP=${IPV4_PREFIX}.$((${OCTET[3]} + 26))
    OBJECTS_NW_START=${IPV4_PREFIX}.$((${OCTET[3]} + 27))
    OBJECTS_NW_END=${IPV4_PREFIX}.$((${OCTET[3]} + 30))
    ;;


  * ) # For normal clusters
    NW1_SUBNET="${IPV4_PREFIX}.1/25"
    NW1_GATEWAY="${IPV4_PREFIX}.1"
    NW1_DHCP_START="${IPV4_PREFIX}.50"
    NW1_DHCP_END="${IPV4_PREFIX}.125"

    NW2_NAME='Secondary'
    NW2_VLAN=$((OCTET[2]*10+1))
    NW2_SUBNET="${IPV4_PREFIX}.129/25"
    NW2_GATEWAY="${IPV4_PREFIX}.129"
    NW2_DHCP_START="${IPV4_PREFIX}.132"
    NW2_DHCP_END="${IPV4_PREFIX}.253"

    NW3_NAME='EraManaged'
    NW3_NETMASK='255.255.255.128'
    NW3_START="${IPV4_PREFIX}.220"
    NW3_END="${IPV4_PREFIX}.253"
    ;;

esac

# Stuff needed for object_store
#OBJECTS_OFFLINE_REPO='http://10.42.194.11/workshop_staging/objects'
VLAN=${OCTET[2]}
NETWORK="${OCTET[0]}.${OCTET[1]}"

SMTP_SERVER_ADDRESS='mxb-002c1b01.gslb.pphosted.com'
SMTP_SERVER_FROM='NutanixHostedPOC@nutanix.com'
SMTP_SERVER_PORT=25

AUTH_SERVER='AutoAD' # default; TODO:180 refactor AUTH_SERVER choice to input file
AUTH_HOST="${IPV4_PREFIX}.$((${OCTET[3]} + 4))"
LDAP_PORT=389
AUTH_FQDN='ntnxlab.local'
AUTH_DOMAIN='NTNXLAB'
AUTH_ADMIN_USER='administrator@'${AUTH_FQDN}
AUTH_ADMIN_PASS='nutanix/4u'
AUTH_ADMIN_GROUP='SSP Admins'


# For Nutanix HPOC/Marketing clusters (RTP 10.55, PHC 10.42, PHX 10.38)
# https://sewiki.nutanix.com/index.php/HPOC_IP_Schema
case "${OCTET[0]}.${OCTET[1]}" in

  10.55 ) # HPOC us-east = DUR
    PC_DEV_METAURL='http://10.55.251.38/workshop_staging/pcdeploy-pc.2020.9.json'
    PC_DEV_URL='http://10.55.251.38/workshop_staging/pc.2020.9.tar'
    PC_CURRENT_METAURL='http://10.55.251.38/workshop_staging/pcdeploy-pc.2020.9.json'
    PC_CURRENT_URL='http://10.55.251.38/workshop_staging/pc.2020.9.tar'
    PC_STABLE_METAURL='http://10.55.251.38/workshop_staging/pcdeploy-5.17.0.3.json'
    PC_STABLE_URL='http://10.55.251.38/workshop_staging/euphrates-5.17.0.3-stable-prism_central.tar'
    FILES_METAURL='http://10.55.251.38/workshop_staging/nutanix-afs-el7.3-release-afs-3.7.1-stable-metadata.json'
    FILES_URL='http://10.55.251.38/workshop_staging/nutanix-afs-el7.3-release-afs-3.7.1-stable.qcow2'
    FILE_ANALYTICS_METAURL='http://10.55.251.38/workshop_staging/nutanix-file_analytics-el7.7-release-2.2.0-metadata.json'
    FILE_ANALYTICS_URL='http://10.55.251.38/workshop_staging/nutanix-file_analytics-el7.7-release-2.2.0.qcow2'
    JQ_REPOS=(\
         'http://10.55.251.38/workshop_staging/jq-linux64.dms' \
         'https://s3.amazonaws.com/get-ahv-images/jq-linux64.dms' \
         #'https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64' \
   )
    SSHPASS_REPOS=(\
       'http://10.55.251.38/workshop_staging/sshpass-1.06-2.el7.x86_64.rpm' \
       #'http://mirror.centos.org/centos/7/extras/x86_64/Packages/sshpass-1.06-2.el7.x86_64.rpm' \
    )
    QCOW2_REPOS=(\
       'http://10.55.251.38/workshop_staging/' \
       'https://s3.amazonaws.com/get-ahv-images/' \
    )
    AUTODC_REPOS=(\
     'http://10.55.251.38/workshop_staging/AutoDC2.qcow2' \
     'https://s3.amazonaws.com/get-ahv-images/AutoDC2.qcow2' \
    )
    AUTOAD_REPOS=(\
    'http://10.55.251.38/workshop_staging/AutoAD.qcow2' \
    'https://s3.amazonaws.com/get-ahv-images/AutoAD.qcow2' \
    )
    PC_DATA='http://10.55.251.38/workshop_staging/seedPC.zip'
    BLUEPRINT_URL='http://10.55.251.38/workshop_staging/CalmBlueprints/'
    DNS_SERVERS='10.55.251.10,10.55.251.11'
    ERA_PRIMARY_DNS='10.55.251.10'
    ERA_SECONDARY_DNS='10.55.251.11'
	  OBJECTS_OFFLINE_REPO='http://10.55.251.38/workshop_staging/objects'
    ;;
  10.42 ) # HPOC us-west = PHX
    PC_DEV_METAURL='http://10.42.194.11/workshop_staging/pcdeploy-pc.2020.9.json'
    PC_DEV_URL='http://10.42.194.11/workshop_staging/pc.2020.9.tar'
    PC_CURRENT_METAURL='http://10.42.194.11/workshop_staging/pcdeploy-pc.2020.9.json'
    PC_CURRENT_URL='http://10.42.194.11/workshop_staging/pc.2020.9.tar'
    PC_STABLE_METAURL='http://10.42.194.11/workshop_staging/pcdeploy-5.17.0.3.json'
    PC_STABLE_URL='http://10.42.194.11/workshop_staging/euphrates-5.17.0.3-stable-prism_central.tar'
    FILES_METAURL='http://10.42.194.11/workshop_staging/nutanix-afs-el7.3-release-afs-3.7.1-stable-metadata.json'
    FILES_URL='http://10.42.194.11/workshop_staging/nutanix-afs-el7.3-release-afs-3.7.1-stable.qcow2'
    FILE_ANALYTICS_METAURL='http://10.42.194.11/workshop_staging/nutanix-file_analytics-el7.7-release-2.2.0-metadata.json'
    FILE_ANALYTICS_URL='http://10.42.194.11/workshop_staging/nutanix-file_analytics-el7.7-release-2.2.0.qcow2'
    JQ_REPOS=(\
         'http://10.42.194.11/workshop_staging/jq-linux64.dms' \
         'https://s3.amazonaws.com/get-ahv-images/jq-linux64.dms' \
         #'https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64' \
   )
    SSHPASS_REPOS=(\
       'http://10.42.194.11/workshop_staging/sshpass-1.06-2.el7.x86_64.rpm' \
       #'http://mirror.centos.org/centos/7/extras/x86_64/Packages/sshpass-1.06-2.el7.x86_64.rpm' \
    )
    QCOW2_REPOS=(\
       'http://10.42.194.11/workshop_staging/' \
       'https://s3.amazonaws.com/get-ahv-images/' \
    )
    AUTODC_REPOS=(\
     'http://10.42.194.11/workshop_staging/AutoDC2.qcow2' \
     'https://s3.amazonaws.com/get-ahv-images/AutoDC2.qcow2' \
    )
    AUTOAD_REPOS=(\
     'http://10.42.194.11/workshop_staging/AutoAD.qcow2' \
     'https://s3.amazonaws.com/get-ahv-images/AutoAD.qcow2' \
    )
    PC_DATA='http://10.42.194.11/workshop_staging/seedPC.zip'
    BLUEPRINT_URL='http://10.42.194.11/workshop_staging/CalmBlueprints/'
    DNS_SERVERS='10.42.196.10,10.42.194.10'
    ERA_PRIMARY_DNS='10.42.196.10'
    ERA_SECONDARY_DNS='10.42.194.10'
    OBJECTS_OFFLINE_REPO='http://10.42.194.11/workshop_staging/objects'
    ;;
  10.38 ) # HPOC us-west = PHX 1-Node Clusters
    PC_DEV_METAURL='http://10.42.194.11/workshop_staging/pcdeploy-pc.2020.9.json'
    PC_DEV_URL='http://10.42.194.11/workshop_staging/pc.2020.9.tar'
    PC_CURRENT_METAURL='http://10.42.194.11/workshop_staging/pcdeploy-pc.2020.9.json'
    PC_CURRENT_URL='http://10.42.194.11/workshop_staging/pc.2020.9.tar'
    PC_STABLE_METAURL='http://10.42.194.11/workshop_staging/pcdeploy-5.17.0.3.json'
    PC_STABLE_URL='http://10.42.194.11/workshop_staging/euphrates-5.17.0.3-stable-prism_central.tar'
    FILES_METAURL='http://10.42.194.11/workshop_staging/nutanix-afs-el7.3-release-afs-3.7.1-stable-metadata.json'
    FILES_URL='http://10.42.194.11/workshop_staging/nutanix-afs-el7.3-release-afs-3.7.1-stable.qcow2'
    FILE_ANALYTICS_METAURL='http://10.42.194.11/workshop_staging/nutanix-file_analytics-el7.7-release-2.2.0-metadata.json'
    FILE_ANALYTICS_URL='http://10.42.194.11/workshop_staging/nutanix-file_analytics-el7.7-release-2.2.0.qcow2'
    JQ_REPOS=(\
           'http://10.42.194.11/workshop_staging/jq-linux64.dms' \
           'https://s3.amazonaws.com/get-ahv-images/jq-linux64.dms' \
           #'https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64' \
     )
    SSHPASS_REPOS=(\
         'http://10.42.194.11/workshop_staging/sshpass-1.06-2.el7.x86_64.rpm' \
         #'http://mirror.centos.org/centos/7/extras/x86_64/Packages/sshpass-1.06-2.el7.x86_64.rpm' \
      )
    QCOW2_REPOS=(\
         'http://10.42.194.11/workshop_staging/' \
         'https://s3.amazonaws.com/get-ahv-images/' \
    )
    AUTODC_REPOS=(\
       'http://10.42.194.11/workshop_staging/AutoDC2.qcow2' \
       'https://s3.amazonaws.com/get-ahv-images/AutoDC2.qcow2' \
    )
    AUTOAD_REPOS=(\
     'http://10.42.194.11/workshop_staging/AutoAD.qcow2' \
     'https://s3.amazonaws.com/get-ahv-images/AutoAD.qcow2' \
    )
    PC_DATA='http://10.42.194.11/workshop_staging/seedPC.zip'
    BLUEPRINT_URL='http://10.42.194.11/workshop_staging/CalmBlueprints/'
    DNS_SERVERS="10.42.196.10,10.42.194.10"
    ERA_PRIMARY_DNS='10.42.196.10'
    ERA_SECONDARY_DNS='10.42.194.10'
	  OBJECTS_OFFLINE_REPO='http://10.42.194.11/workshop_staging/objects'

    # If the third OCTET is between 170 and 199, we need to have the +3 vlan for the secondary
    if [[ ${OCTET[2]} -gt 169 ]]; then
      NW2_VLAN=$((OCTET[2]*10+3))
    fi
      ;;
  10.136 ) # HPOC us-west = BLR
    PC_DEV_METAURL='http://10.136.239.13/workshop_staging/pcdeploy-pc.2020.9.json'
    PC_DEV_URL='http://10.136.239.13/workshop_staging/pc.2020.9.tar'
    PC_CURRENT_METAURL='http://10.136.239.13/workshop_staging/pcdeploy-pc.2020.9.json'
    PC_CURRENT_URL='http://10.136.239.13/workshop_staging/pc.2020.9.tar'
    PC_STABLE_METAURL='http://10.136.239.13/workshop_staging/pcdeploy-5.17.0.3.json'
    PC_STABLE_URL='http://10.136.239.13/workshop_staging/euphrates-5.17.0.3-stable-prism_central.tar'
    FILES_METAURL='http://10.136.239.13/workshop_staging/nutanix-afs-el7.3-release-afs-3.7.1-stable-metadata.json'
    FILES_URL='http://10.136.239.13/workshop_staging/nutanix-afs-el7.3-release-afs-3.7.1-stable.qcow2'
    FILE_ANALYTICS_METAURL='http://10.136.239.13/workshop_staging/nutanix-file_analytics-el7.7-release-2.2.0-metadata.json'
    FILE_ANALYTICS_URL='http://10.136.239.13/workshop_staging/nutanix-file_analytics-el7.7-release-2.2.0.qcow2'
    JQ_REPOS=(\
         'http://10.136.239.13/workshop_staging/jq-linux64.dms' \
         'https://s3.amazonaws.com/get-ahv-images/jq-linux64.dms' \
         #'https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64' \
   )
    SSHPASS_REPOS=(\
       'http://10.136.239.13/workshop_staging/sshpass-1.06-2.el7.x86_64.rpm' \
       #'http://mirror.centos.org/centos/7/extras/x86_64/Packages/sshpass-1.06-2.el7.x86_64.rpm' \
    )
    QCOW2_REPOS=(\
       'http://10.136.239.13/workshop_staging/' \
       'https://s3.amazonaws.com/get-ahv-images/' \
    )
    AUTODC_REPOS=(\
     'http://10.136.239.13/workshop_staging/AutoDC2.qcow2' \
     'https://s3.amazonaws.com/get-ahv-images/AutoDC2.qcow2' \
    )
    AUTOAD_REPOS=(\
     'http://10.136.239.13/workshop_staging/AutoAD.qcow2' \
     'https://s3.amazonaws.com/get-ahv-images/AutoAD.qcow2' \
    )
    PC_DATA='http://10.136.239.13/workshop_staging/seedPC.zip'
    BLUEPRINT_URL='http:/10.136.239.13/workshop_staging/CalmBlueprints/'
    DNS_SERVERS='10.136.239.10,10.136.239.11'
    ERA_PRIMARY_DNS='10.136.239.10'
    ERA_SECONDARY_DNS='10.136.239.11'
    OBJECTS_OFFLINE_REPO='http://10.136.239.13/workshop_staging/objects'
    ;;
  10.132 ) # https://sewiki.nutanix.com/index.php/SH-COLO-IP-ADDR
    JQ_REPOS=(\
         'https://s3.amazonaws.com/get-ahv-images/jq-linux64.dms' \
         #'https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64' \
   )
    QCOW2_REPOS=(\
       'https://s3.amazonaws.com/get-ahv-images/jq-linux64.dms' \
    )
    AUTODC_REPOS=(\
     'https://s3.amazonaws.com/get-ahv-images/AutoDC2.qcow2' \
   )

   DNS_SERVERS='10.132.71.40'
   NW1_SUBNET="${IPV4_PREFIX%.*}.128.4/17"
   NW1_DHCP_START="${IPV4_PREFIX}.100"
   NW1_DHCP_END="${IPV4_PREFIX}.250"
   # PC deploy file local override, TODO:30 make an PC_URL array and eliminate
   PC_CURRENT_URL=http://10.132.128.50/E%3A/share/Nutanix/PrismCentral/pc-${PC_VERSION}-deploy.tar
   PC_CURRENT_METAURL=http://10.132.128.50/E%3A/share/Nutanix/PrismCentral/pc-${PC_VERSION}-deploy-metadata.json
   PC_STABLE_METAURL=${PC_CURRENT_METAURL}

   QCOW2_IMAGES=(\
      Centos7-Base.qcow2 \
      Centos7-Update.qcow2 \
      Windows2012R2.qcow2 \
      panlm-img-52.qcow2 \
      kx_k8s_01.qcow2 \
      kx_k8s_02.qcow2 \
      kx_k8s_03.qcow2 \
    )
    ;;
esac

# Find operating system and set dependencies
if [[ -e /etc/lsb-release ]]; then
  # Linux Standards Base
  OS_NAME="$(grep DISTRIB_ID /etc/lsb-release | awk -F= '{print $2}')"
elif [[ -e /etc/os-release ]]; then
  # CPE = https://www.freedesktop.org/software/systemd/man/os-release.html
  OS_NAME="$(grep '^ID=' /etc/os-release | awk -F= '{print $2}')"
elif [[ $(uname -s) == 'Darwin' ]]; then
  OS_NAME='Darwin'
fi

WC_ARG='-l'
if [[ ${OS_NAME} == 'Darwin' ]]; then
  WC_ARG='-l'
fi
if [[ ${OS_NAME} == 'alpine' ]]; then
  WC_ARG='-l'
fi
