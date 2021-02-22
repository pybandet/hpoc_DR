#!/usr/bin/env bash
# -x

#__main()__________

# Source Nutanix environment (PATH + aliases), then common routines + global variables
. /etc/profile.d/nutanix_env.sh
. lib.common.sh
. global.vars.sh
begin

args_required 'EMAIL PE_PASSWORD PC_VERSION PC_HOST'

#dependencies 'install' 'jq' && ntnx_download 'PC' & #attempt at parallelization
# Some parallelization possible to critical path; not much: would require pre-requestite checks to work!


    . lib.pe.sh
    . lib.pc.sh

    export AUTH_SERVER='AutoAD'
    # Networking needs for Era Bootcamp
	  #export NW2_NAME='EraManaged'
    export NW1_DHCP_START="${IPV4_PREFIX}.10"
    export NW1_DHCP_END="${IPV4_PREFIX}.208"
    export NW3_NAME='EraManaged'
    export NW3_NETMASK='255.255.255.128'
    export NW3_START="${IPV4_PREFIX}.209"
    export NW3_END="${IPV4_PREFIX}.253"
    OCTET_Cluster2=(${PC_HOST//./ }) # zero index
    IPV4_PREFIX_Cluster2=${OCTET_Cluster2[0]}.${OCTET_Cluster2[1]}.${OCTET_Cluster2[2]}
    ERA_HOST_Cluster1=${IPV4_PREFIX_Cluster2}.$((${OCTET_Cluster2[3]} + 5))

    args_required 'PE_HOST PC_LAUNCH'
    ssh_pubkey & # non-blocking, parallel suitable

    dependencies 'install' 'sshpass' && dependencies 'install' 'jq' \
    #&& pe_license_api \
    #&& pe_init_api \
    #&& create_era_container_api \
    era_network_configure_api \
    && authentication_source \
    && pe_auth_api \
    && deploy_api_mssql_2019 \
    && deploy_api_citrix_gold_image_vm \
    && cluster_check
