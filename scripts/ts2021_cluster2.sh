#!/usr/bin/env bash
# -x

#__main()__________

# Temp Safing aome needed params as we got it from the parameters
PC_HOST_AWS=${PC_HOST}
AUTO_AD_AWS=${AUTH_HOST}

# Source Nutanix environment (PATH + aliases), then common routines + global variables
. /etc/profile.d/nutanix_env.sh
. lib.common.sh
. global.vars.sh
begin

# Rereading the temp stored params as we have overwritten it by .global.vars.sh
PC_HOST=${PC_HOST_AWS}
AUTH_HOST=${AUTO_AD_AWS}

args_required 'EMAIL PE_PASSWORD PC_VERSION PC_HOST AUTH_HOST'

#dependencies 'install' 'jq' && ntnx_download 'PC' & #attempt at parallelization
# Some parallelization possible to critical path; not much: would require pre-requestite checks to work!


    . lib.pe.sh
    . lib.pe.api.sh
    . lib.pc.sh

    export AUTH_SERVER='AutoAD'
    export NW1_NAME='User VM Subnet'
    export STORAGE_ERA='SelfServiceContainer'
    export ERA_NETWORK="User VM Subnet"
    export QCOW2_REPOS='https://gts2021.s3-us-west-2.amazonaws.com'
    # Networking needs for Era Bootcamp
	  #export NW2_NAME='EraManaged'
    #export NW1_DHCP_START="${IPV4_PREFIX}.10"
    #export NW1_DHCP_END="${IPV4_PREFIX}.125" # Need to understand the NETMASK for this!!! Changed to 125 as the original Cluster staging script
    #export NW3_NAME='EraManaged'
    #export NW3_NETMASK='255.255.255.128'
    export NW1_DHCP_START="${IPV4_PREFIX}.133"
    export NW1_DHCP_END="${IPV4_PREFIX}.208"
    export NW1_GATEWAY="${IPV4_PREFIX}.129"
    export NW3_START="${IPV4_PREFIX}.210"
    export NW3_END="${IPV4_PREFIX}.253"
    #OCTET_Cluster2=(${PC_HOST//./ }) # zero index
    #IPV4_PREFIX_Cluster2=${OCTET_Cluster2[0]}.${OCTET_Cluster2[1]}.${OCTET_Cluster2[2]}
    #ERA_HOST_Cluster1=${IPV4_PREFIX_Cluster2}.$((${OCTET_Cluster2[3]} + 4))
    #export ERA_HOST="${ERA_HOST_Cluster1}"
    #export ERA_AGENT_IP="${IPV4_PREFIX}.209"
    #export ERA_AGENT_GATEWAY="${IPV4_PREFIX}.129"
    export ERA_HOST="${IPV4_PREFIX}.209"
    OCTET_Cluster1=(${PC_HOST//./ }) # zero index
    IPV4_PREFIX_Cluster1=${OCTET_Cluster1[0]}.${OCTET_Cluster1[1]}.${OCTET_Cluster1[2]}
    ERA_AGENT_Cluster1=${IPV4_PREFIX_Cluster1}.$((${OCTET_Cluster1[3]} + 4))
    ERA_AGENT_GATEWAY_Cluster1="${IPV4_PREFIX_Cluster1}.1"
    NW2_GATEWAY_Cluster1="${IPV4_PREFIX_Cluster1}.129"
    PE_HOST_HPOC=${IPV4_PREFIX_Cluster1}.$((${OCTET_Cluster1[3]} - 2))
    export ERA_AGENT_IP="${ERA_AGENT_Cluster1}"
    export ERA_AGENT_GATEWAY="${ERA_AGENT_GATEWAY_Cluster1}"

    args_required 'PE_HOST PC_LAUNCH'
    ssh_pubkey & # non-blocking, parallel suitable

    dependencies 'install' 'sshpass' && dependencies 'install' 'jq' \
    && pe_license_api \
    && pe_init_aws_api \
    && pe_auth_api \
    && cluster_check \
    && deploy_api_citrix_gold_image_vm \
    && deploy_api_mssql_2019_image \
    && deploy_api_mssql_2019 \
    && deploy_era_api \
    && configure_era_gts2021 \
    && create_image_policy_categories \
    && upload_docker_fiesta_era_blueprint



    finish
