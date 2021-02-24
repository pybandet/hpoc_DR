#!/usr/bin/env bash
# -x

#__main()__________

# Source Nutanix environment (PATH + aliases), then common routines + global variables
. /etc/profile.d/nutanix_env.sh
. lib.common.sh
. global.vars.sh
begin

args_required 'EMAIL PE_PASSWORD PC_VERSION PC_HOST AUTH_HOST'

#dependencies 'install' 'jq' && ntnx_download 'PC' & #attempt at parallelization
# Some parallelization possible to critical path; not much: would require pre-requestite checks to work!


    . lib.pe.sh
    . lib.pe.api.sh
    . lib.pc.sh

    export AUTH_SERVER='AutoAD'
    export NW1_NAME='User VM Subnet'
    # Networking needs for Era Bootcamp
	  #export NW2_NAME='EraManaged'
    #export NW1_DHCP_START="${IPV4_PREFIX}.10"
    #export NW1_DHCP_END="${IPV4_PREFIX}.125" # Need to understand the NETMASK for this!!! Changed to 125 as the original Cluster staging script
    #export NW3_NAME='EraManaged'
    #export NW3_NETMASK='255.255.255.128'
    export NW3_START="${IPV4_PREFIX}.209"
    export NW3_END="${IPV4_PREFIX}.253"
    OCTET_Cluster2=(${PC_HOST//./ }) # zero index
    IPV4_PREFIX_Cluster2=${OCTET_Cluster2[0]}.${OCTET_Cluster2[1]}.${OCTET_Cluster2[2]}
    ERA_HOST_Cluster1=${IPV4_PREFIX_Cluster2}.$((${OCTET_Cluster2[3]} + 4))

    args_required 'PE_HOST PC_LAUNCH'
    ssh_pubkey & # non-blocking, parallel suitable

    dependencies 'install' 'sshpass' && dependencies 'install' 'jq' \
    && pe_license_api \
    && update_aws_cluster_info_api \
    && pe_init_api \
    #&& create_era_container_api \
    && cluster_check \
    #&& era_network_configure_api \
    && pe_auth_api \
    && configure_era_cluster_2 \
    && deploy_api_mssql_2019 \
    && deploy_api_citrix_gold_image_vm

    finish
