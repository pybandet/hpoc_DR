#!/usr/bin/env bash
# -x
# Dependencies: acli, ncli, jq, sshpass, curl, md5sum, pgrep, wc, tr, pkill


###############################################################################################################################################################################
# Routine to create the networks for Era bootcamp
###############################################################################################################################################################################


function era_network_configure_api() {
  local _network1_name="${NW1_NAME}"
  local CURL_HTTP_OPTS=" --max-time 25 --silent --header Content-Type:application/json --header Accept:application/json  --insecure "

  #set -x

  log "--------------------------------------"
  log "Remove RX-Automation-Network"

  RX_NAME_CHECK=$(curl ${CURL_HTTP_OPTS} --request POST "https://${PE_HOST}:9440/api/nutanix/v3/subnets/list" --user ${PRISM_ADMIN}:${PE_PASSWORD} --data '{"kind":"subnet","filter": "name==Rx-Automation-Network""}' | jq -r '.entities[] | .status.name' | tr -d \")

  RX_NETWORK_UUID=$(curl ${CURL_HTTP_OPTS} --request POST "https://${PE_HOST}:9440/api/nutanix/v3/subnets/list" --user ${PRISM_ADMIN}:${PE_PASSWORD} --data '{"kind":"subnet","filter": "name==Rx-Automation-Network""}' | jq -r '.entities[] | .metadata.uuid' | tr -d \")

  log "RX NETWORK Check = |${RX_NAME_CHECK}|"
  log "RX NETWORK UUID = |${RX_NETWORK_UUID}|"

  log "Remove Rx-Automation-Network now..."

  RX_NETWORK_DELETE=$(curl ${CURL_HTTP_OPTS} --request DELETE "https://${PE_HOST}:9440/api/nutanix/v3/subnets/${RX_NETWORK_UUID}" --user ${PRISM_ADMIN}:${PE_PASSWORD})

  log "RX-Automation-Network Removed"

  log "--------------------------------------"
  log "Create Primary Network"

  NW1_NAME_CHECK=$(curl ${CURL_HTTP_OPTS} --request POST "https://${PE_HOST}:9440/api/nutanix/v3/subnets/list" --user ${PRISM_ADMIN}:${PE_PASSWORD} --data '{"kind":"subnet","filter": "name==Primary"}' | jq -r '.entities[] | .status.name' | tr -d \")

  log "Primary NETWORK Check = |${NW1_NAME_CHECK}|"

  log "Creating ${NW1_NAME} Network"
  log "Create primary network: Name: ${NW1_NAME}, VLAN: ${NW1_VLAN}, Subnet: ${NW1_SUBNET}, Domain: ${AUTH_DOMAIN}, Pool: ${NW1_DHCP_START} to ${NW1_DHCP_END}"

  dns_array=(${DNS_SERVERS//,/ }) # To split the DNS servers into array elements

  NW1_subnet_correct="${NW1_SUBNET%??}.0"
  #dhcp_scope=${NW1_DHCP_START}" "${NW1_DHCP_END}
  dhcp_scope="${NW1_DHCP_START} ${NW1_DHCP_END}"

HTTP_JSON_BODY=$(cat <<EOF
{
    "spec": {
        "name": "${NW1_NAME}",
        "resources": {
            "subnet_type": "VLAN",
            "ip_config": {
                "default_gateway_ip": "${NW1_GATEWAY}",
                "pool_list": [
                    {
                        "range": "${dhcp_scope}"
                    }
                ],
                "prefix_length": 25,
                "subnet_ip": "${NW1_subnet_correct}",
                "dhcp_options": {
                    "domain_name_server_list": [
                        "${AUTH_HOST}",
                        "${dns_array[0]}",
                        "${dns_array[1]}"
                    ],
                    "domain_search_list": [
                        "${AUTH_FQDN}"
                    ],
                    "domain_name": "${AUTH_FQDN}"
                }
            },
            "vlan_id": ${NW1_VLAN}
        }
    },
    "metadata": {
        "kind": "subnet"
    },
    "api_version": "3.1.0"
}
EOF
  )

  _task_id=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST --data "${HTTP_JSON_BODY}" "https://${PE_HOST}:9440/api/nutanix/v3/subnets" | jq -r '.status.execution_context.task_uuid' | tr -d \")
  loop ${_task_id} ${PE_HOST}


  log "Primary Network Created"

  log "--------------------------------------"
  log "Create Secondary Network"

  NW2_NAME_CHECK=$(curl ${CURL_HTTP_OPTS} --request POST "https://${PE_HOST}:9440/api/nutanix/v3/subnets/list" --user ${PRISM_ADMIN}:${PE_PASSWORD} --data '{"kind":"subnet","filter": "name==Secondary"}' | jq -r '.entities[] | .status.name' | tr -d \")

  log "Secondary NETWORK Check = |${NW2_NAME_CHECK}|"

  log "Create ${NW2_NAME} Network"
  log "Create secondary network: Name: ${NW2_NAME}, VLAN: ${NW2_VLAN}, Subnet: ${NW2_SUBNET}"

  NW2_subnet_correct="${NW2_SUBNET%????}.128"
  #dhcp_scope=${NW2_DHCP_START}" "${NW2_DHCP_END}
  dhcp_scope="${NW2_DHCP_START} ${NW2_DHCP_END}"

HTTP_JSON_BODY=$(cat <<EOF
{
    "spec": {
        "name": "${NW2_NAME}",
        "resources": {
            "subnet_type": "VLAN",
            "ip_config": {
                "default_gateway_ip": "${NW2_GATEWAY}",
                "pool_list": [
                    {
                        "range": "${dhcp_scope}"
                    }
                ],
                "prefix_length": 25,
                "subnet_ip": "${NW2_subnet_correct}",
                "dhcp_options": {
                    "domain_name_server_list": [
                        "${AUTH_HOST}",
                        "${dns_array[0]}",
                        "${dns_array[1]}"
                    ],
                    "domain_search_list": [
                        "${AUTH_FQDN}"
                    ],
                    "domain_name": "${AUTH_FQDN}"
                }
            },
            "vlan_id": ${NW2_VLAN}
        }
    },
    "metadata": {
        "kind": "subnet"
    },
    "api_version": "3.1.0"
}
EOF
  )

  _task_id=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST --data "${HTTP_JSON_BODY}" "https://${PE_HOST}:9440/api/nutanix/v3/subnets" | jq -r '.status.execution_context.task_uuid' | tr -d \")
  loop ${_task_id} ${PE_HOST}

  log "Secondary Network Created"

  log "--------------------------------------"
  log "Create EraManaged Network"

  NW3_NAME_CHECK=$(curl ${CURL_HTTP_OPTS} --request POST "https://${PE_HOST}:9440/api/nutanix/v3/subnets/list" --user ${PRISM_ADMIN}:${PE_PASSWORD} --data '{"kind":"subnet","filter": "name==EraManaged"}' | jq -r '.entities[] | .status.name' | tr -d \")

  log "EraManaged NETWORK Check = |${NW3_NAME_CHECK}|"

  log "Create ${NW3_NAME} Network"
  log "Create secondary network: Name: ${NW3_NAME}, VLAN: ${NW2_VLAN}"

HTTP_JSON_BODY=$(cat <<EOF
{
    "spec": {
        "name": "${NW3_NAME}",
        "resources": {
            "subnet_type": "VLAN",
            "vlan_id": ${NW2_VLAN}
        }
    },
    "metadata": {
        "kind": "subnet"
    },
    "api_version": "3.1.0"
}
EOF
  )

    _task_id=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST --data "${HTTP_JSON_BODY}" "https://${PE_HOST}:9440/api/nutanix/v3/subnets" | jq -r '.status.execution_context.task_uuid' | tr -d \")
    loop ${_task_id} ${PE_HOST}

    log "EraManaged Network Created"

    log "--------------------------------------"

  set +x

}

###############################################################################################################################################################################
# Routine to set the PE to use the AutoDC for authentication
###############################################################################################################################################################################
function pe_auth_api() {
  local CURL_HTTP_OPTS=" --max-time 25 --silent --header Content-Type:application/json --header Accept:application/json --insecure "
  local _directory_url="ldap://${AUTH_HOST}:${LDAP_PORT}"
  local         _error=45

#set -x

log "Prism Central: |${PC_HOST}|"
log "Prism Element: |${PE_HOST}|"

log "--------------------------------------"
log "Adding ${AUTH_HOST} Directory"

HTTP_JSON_BODY=$(cat <<EOF
{
  "connection_type": "LDAP",
  "directory_type": "ACTIVE_DIRECTORY",
  "directory_url": "${_directory_url}",
  "domain": "${AUTH_FQDN}",
  "group_search_type": "RECURSIVE",
  "name": "${AUTH_DOMAIN}",
  "service_account_password": "${AUTH_ADMIN_PASS}",
  "service_account_username": "${AUTH_ADMIN_USER}"
}
EOF
)

  _task_id=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST --data "${HTTP_JSON_BODY}" "https://${PE_HOST}:9440/api/nutanix/v2.0/authconfig/directories/")


log "--------------------------------------"
log "Adding Role"

HTTP_JSON_BODY=$(cat <<EOF
{
    "directoryName": "${AUTH_DOMAIN}",
    "role": "ROLE_CLUSTER_ADMIN",
    "entityType": "GROUP",
    "entityValues": [
        "${AUTH_ADMIN_GROUP}"
    ]
}
EOF
)

  _task_id=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST --data "${HTTP_JSON_BODY}" "https://${PE_HOST}:9440/PrismGateway/services/rest/v1/authconfig/directories/${AUTH_DOMAIN}/role_mappings?&entityType=GROUP&role=ROLE_CLUSTER_ADMIN")

log "Role Added"
log "--------------------------------------"

#set +x

}

###############################################################################################################################################################################
# Routine set PE's initial configuration
###############################################################################################################################################################################
function pe_init_api() {
  local CURL_HTTP_OPTS=" --max-time 25 --silent --header Content-Type:application/json --header Accept:application/json  --insecure "
  args_required 'DATA_SERVICE_IP EMAIL \
    SMTP_SERVER_ADDRESS SMTP_SERVER_FROM SMTP_SERVER_PORT \
    STORAGE_DEFAULT STORAGE_POOL STORAGE_IMAGES \
    SLEEP ATTEMPTS'

#set -x

  log "Prism Central: |${PC_HOST}|"
  log "Prism Element: |${PE_HOST}|"

  # Set the AWS IP address to PE_HOST
  AWScluster=$PE_HOST

  #############################################################
  # Set the SMTP server
  #############################################################
  log "Configure SMTP"
  payload='{"address":"mxb-002c1b01.gslb.pphosted.com","port":"25","username":null,"password":null,"secureMode":"NONE","fromEmailAddress":"NutanixHostedPOC@nutanix.com","emailStatus":null}'
  return_code=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X PUT -d $payload https://$PE_HOST:9440/PrismGateway/services/rest/v1/cluster/smtp | jq '.address'| tr -d \")
  if [ ! -z "$return_code" ]
  then
      log "SMTP sever was set..."
      # Sending the email
      cluster_name=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} https://$PE_HOST:9440/PrismGateway/services/rest/v1/cluster | jq '.name' | tr -d \")
      payload='{"recipients":["'$EMAIL'"],"subject":"TEST-'$cluster_name'","text":"TEST-'$cluster_name'"}'
      return_code=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST -d $payload https://$PE_HOST:9440/PrismGateway/services/rest/v1/cluster/send_email | jq '.emailSent'| tr -d \")
      if [ ${return_code} ]
      then
          log "Email sent to $EMAIL..."
      else
          log "Email not sent to $EMAIL..."
      fi
  else
      log "SMTP sever was not set..."
  fi


  #############################################################
  # Set the NTP servers
  #############################################################
  log "Configure NTP servers"
  ntp_arr=('0.us.pool.ntp.org' '1.us.pool.ntp.org' '2.us.pool.ntp.org' '3.us.pool.ntp.org')
  for ntp_server in ${ntp_arr[@]}
  do
      payload='{"value":"'$ntp_server'"}'
      return_code=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST -d $payload "https://$PE_HOST:9440/api/nutanix/v2.0/cluster/ntp_servers" | jq '.value' | tr -d \")
      if [ ${return_code} ]
      then
        log "NTP server $ntp_server has been added"
      else
        log "NTP server $ntp_server has not been added"
      fi
  done

  #############################################################
  # Renaming the Default Storage Pool
  #############################################################
  log "Rename default storage pool to ${STORAGE_POOL}"
  # Need to grab the id of the storage pool and the disks so that we can change the Storega Pool name
  sp_id=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} "https://"$PE_HOST":9440/PrismGateway/services/rest/v1/storage_pools?sortOrder=storage_pool_name" | jq '.entities[].id'| tr -d \")
  disks_arr=($(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} "https://$PE_HOST:9440/PrismGateway/services/rest/v1/storage_pools?sortOrder=storage_pool_name" | jq '.entities[].disks[]' | tr -d \"))

  # Build the payload
  payload='{"id":"'$sp_id'","name":"'$STORAGE_POOL'","disks":['
  for disk in "${disks_arr[@]}"
    do
      payload=$payload'"'$disk'",'
    done
  # Remove the last ","as we don't need it
  payload=${payload%?}
  payload=$payload"]}"
  # Send the command to the cluster
  return_code=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -d $payload -X PUT "https://$PE_HOST:9440/PrismGateway/services/rest/v1/storage_pools?sortOrder=storage_pool_name" | jq '.value' | tr -d \")
  # Did we get the correct return?
  if [ ${return_code} ]
  then
    log "Storage Pool has been renamed"
  else
    log "Storage Pool has not been renamed... Still continueing.."
  fi

  #############################################################
  # Renaming the default container
  #############################################################
  log "Rename default container to ${STORAGE_DEFAULT}"
  default_cont_id=($(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} "https://$PE_HOST:9440/PrismGateway/services/rest/v2.0/storage_containers" | jq '.entities[] | select (.name | contains("default")) .id' | tr -d \"))
  default_cont_st_id=($(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} "https://$PE_HOST:9440/PrismGateway/services/rest/v2.0/storage_containers" | jq '.entities[] | select (.name | contains("default")) .storage_container_uuid' | tr -d \"))
  payload='{"id":"'$default_cont_id'","storage_container_uuid":"'$default_cont_st_id'","name":"'${STORAGE_DEFAULT}'","vstore_name_list":["'${STORAGE_DEFAULT}'"]}'
  return_code=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X PATCH -d $payload "https://$PE_HOST:9440/PrismGateway/services/rest/v2.0/storage_containers" | jq '.value' | tr -d \")
  # Did we get the correct return?
  if [ ${return_code} ]
  then
    log "Default container has been renamed"
  else
    log "Default container has not been renamed... Still continueing.."
  fi

  #############################################################
  # Check to see if there is a container named Images. If not, create it
  #############################################################
  log "Check if there is a container named ${STORAGE_IMAGES}, if not create one"
  cont_arr=($(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} "https://$PE_HOST:9440/PrismGateway/services/rest/v2.0/storage_containers" | jq '.entities[].name' | tr -d \"))
  if [[ " ${cont_arr[@]} " =~ "Images" ]]
  then
      log "Found the Images container.."
  else
      log "Creating the container..."
      payload='{"name":"Images","marked_for_removal":false,"replication_factor":2,"oplog_replication_factor":2,"nfs_whitelist":[],"nfs_whitelist_inherited":true,"erasure_code":"off","prefer_higher_ecfault_domain":null,"erasure_code_delay_secs":null,"finger_print_on_write":"off","on_disk_dedup":"OFF","compression_enabled":false,"compression_delay_in_secs":null,"is_nutanix_managed":null,"enable_software_encryption":false,"encrypted":null}'
      return_code=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST -d $payload "https://$PE_HOST:9440/PrismGateway/services/rest/v2.0/storage_containers" | jq '.value' | tr -d \")
      if [ ${return_code} ]
      then
          log "Container Images has been created..."
      else
          log "Container Images has not been created..."
          exit 10
      fi
  fi

  #############################################################
  # Set dataservices IP address:
  #############################################################
  log "Set Data Services IP address to ${DATA_SERVICE_IP}"
  # Get the cluster UUID
  cluster_uuid=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} https://$PE_HOST:9440/PrismGateway/services/rest/v1/cluster | jq '.id' | tr -d \")
  cluster_name=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} https://$PE_HOST:9440/PrismGateway/services/rest/v1/cluster | jq '.name' | tr -d \")
  cluster_vip=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} https://$PE_HOST:9440/PrismGateway/services/rest/v1/cluster | jq '.clusterExternalIPAddress' | tr -d \")
  cluster_data=$DATA_SERVICE_IP
  payload='{"id":"'$cluster_uuid'","name":"'$cluster_name'","clusterExternalIPAddress":"'$cluster_vip'","clusterExternalDataServicesIPAddress":"'$cluster_data'"}'

  # Set the databaservice IP
  result_code=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X PUT -d $payload https://$PE_HOST:9440/PrismGateway/services/rest/v1/cluster | jq '.value'| tr -d \")
  if [ ${return_code} ]
  then
      log "Data services IP has been set..."
  else
      log "Data services IP has not been set..."
      exit 11
  fi

}



###############################################################################################################################################################################
# Routine to accept the EULA and disable pulse API based
###############################################################################################################################################################################
function pe_license_api() {
  local _test
  args_required 'CURL_POST_OPTS PE_PASSWORD'
  #local CURL_HTTP_OPTS=" --max-time 25 --silent --header Content-Type:application/json --header Accept:application/json  --insecure "
  #set -x

  echo ${PE_HOST}
  log "Prism Central: |${PC_HOST}|"
  log "Prism Element: |${PE_HOST}|"

  log "IDEMPOTENCY: Checking PC API responds, curl failures are acceptable..."
  prism_check 'PC' 2 0

  if (( $? == 0 )) ; then
    log "IDEMPOTENCY: PC API responds, skip"
  else
    _test=$(curl ${CURL_POST_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST --data '{
      "username": "SE with $(basename ${0})",
      "companyName": "Nutanix",
      "jobTitle": "SE"
    }' "https://${PE_HOST}:9440/PrismGateway/services/rest/v1/eulas/accept")
    log "Validate EULA on PE: _test=|${_test}|"

    _test=$(curl ${CURL_POST_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X PUT --data '{
      "defaultNutanixEmail": null,
      "emailContactList": null,
      "enable": false,
      "enableDefaultNutanixEmail": false,
      "isPulsePromptNeeded": false,
      "nosVersion": null,
      "remindLater": null,
      "verbosityType": null
    }' "https://${PE_HOST}:9440/PrismGateway/services/rest/v1/pulse")
    log "Disable Pulse in PE: _test=|${_test}|"

  fi
# set +x

}

###################################################################################################################################################
# Routine create the Era Storage container for the Era Bootcamps API Based
###################################################################################################################################################

function create_era_container_api() {
  local CURL_HTTP_OPTS=" --max-time 25 --silent --header Content-Type:application/json --header Accept:application/json  --insecure "

  log "Creating Era Storage Container"
  payload='{"name":"Era","marked_for_removal":false,"replication_factor":2,"oplog_replication_factor":2,"nfs_whitelist":[],"nfs_whitelist_inherited":true,"erasure_code":"off","prefer_higher_ecfault_domain":null,"erasure_code_delay_secs":null,"finger_print_on_write":"off","on_disk_dedup":"OFF","compression_enabled":true,"compression_delay_in_secs":null,"is_nutanix_managed":null,"enable_software_encryption":false,"encrypted":null}'
  return_code=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST -d $payload "https://$PE_HOST:9440/PrismGateway/services/rest/v2.0/storage_containers" | jq '.value' | tr -d \")
  if [ ${return_code} ]
  then
      log "Container Era has been created..."
  else
      log "Container Era has not been created..."
      exit 10
  fi

}

###################################################################################################################################################
# Routine create the Era Storage container for the Era Bootcamps API Based
###################################################################################################################################################

function update_aws_cluster_info_api() {
  local CURL_HTTP_OPTS=" --max-time 25 --silent --header Content-Type:application/json --header Accept:application/json  --insecure "
  local cluster_name="AWS-Cluster"
  set -x

  log "--------------------------------------"
  log "Updating AWS Cluster Info"
  log "--------------------------------------"

  log "Prism Central: |${PC_HOST}|"
  log "Prism Element: |${PE_HOST}|"
  log "AutoAD: |${AUTH_HOST}|"

  log "Getting Cluster Info"

  cluster_id=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X GET -d '{}' "https://$PE_HOST:9440/PrismGateway/services/rest/v1/cluster" | jq '.id' | tr -d \")
  cluster_uuid=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X GET -d '{}' "https://$PE_HOST:9440/PrismGateway/services/rest/v1/cluster" | jq '.uuid' | tr -d \")
  cluster_ip=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X GET -d '{}' "https://$PE_HOST:9440/PrismGateway/services/rest/v1/cluster" | jq '.clusterExternalIPAddress' | tr -d \")
  #cluster_dsip=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X GET -d '{}' "https://$PE_HOST:9440/PrismGateway/services/rest/v1/cluster" | jq '.clusterExternalDataServicesIPAddress' | tr -d \")
  cluster_dns=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X GET -d '{}' "https://$PE_HOST:9440/PrismGateway/services/rest/v1/cluster" | jq '.nameServers[]' | tr -d \")

  log "Cluster ID: |${cluster_id}|"
  log "Cluster UUID: |${cluster_uuid}|"
  log "Cluster Name: |${cluster_name}|"
  log "Cluster IP: |${cluster_ip}|"
  log "Cluster DataServices IP: |${DATA_SERVICE_IP}|"
  log "Cluster DNS: |${cluster_dns}|"

  log "--------------------------------------"
  log "Updating Cluster Info"

HTTP_JSON_BODY=$(cat <<EOF
{
    "id": "${cluster_id}",
    "uuid": "${cluster_uuid}",
    "name": "${cluster_name}",
    "clusterExternalIPAddress": "${cluster_ip}",
    "clusterExternalDataServicesIPAddress": "${DATA_SERVICE_IP}",
    "nameServers": [
        "${AUTH_HOST}",
        "${cluster_dns}"
        ]
}
EOF
  )

  _value=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X PUT -d "${HTTP_JSON_BODY}" "https://$PE_HOST:9440/PrismGateway/services/rest/v1/cluster" | jq '.value' | tr -d \")

  log "Update Value: |${_value}|"

  log "--------------------------------------"
  log "AWS Cluster Info Updated"
  log "--------------------------------------"

  set +x

}

#########################################################################################################################################
# Routine to Create Era Bootcamp PreProvisioned MSSQL Server 2019
#########################################################################################################################################

function deploy_api_mssql_2019() {
    local CURL_HTTP_OPTS=" --max-time 25 --silent --header Content-Type:application/json --header Accept:application/json --insecure "

set -x

log "--------------------------------------"
log "Uploading ${MSSQL19_SourceVM_Image1}"

HTTP_JSON_BODY=$(cat <<EOF
{
  "spec": {
      "name": "${MSSQL19_SourceVM_Image1}",
      "description": "${MSSQL19_SourceVM_Image1}",
      "resources": {
          "image_type": "DISK_IMAGE",
          "source_uri": "${QCOW2_REPOS}/${MSSQL19_SourceVM_Image1}.qcow2"
      }
  },
  "metadata": {
      "kind": "image"
  },
  "api_version": "3.1.0"
}
EOF
  )

_task_id=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST --data "${HTTP_JSON_BODY}" "https://${PE_HOST}:9440/api/nutanix/v3/images" | jq -r '.status.execution_context.task_uuid' | tr -d \")
loop ${_task_id} ${PE_HOST}

log "--------------------------------------"
log "Uploading ${MSSQL19_SourceVM_Image2}"

HTTP_JSON_BODY=$(cat <<EOF
{
  "spec": {
      "name": "${MSSQL19_SourceVM_Image2}",
      "description": "${MSSQL19_SourceVM_Image2}",
      "resources": {
          "image_type": "DISK_IMAGE",
          "source_uri": "${QCOW2_REPOS}/${MSSQL19_SourceVM_Image2}.qcow2"
      }
  },
  "metadata": {
      "kind": "image"
  },
  "api_version": "3.1.0"
}
EOF
  )

_task_id=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST --data "${HTTP_JSON_BODY}" "https://${PE_HOST}:9440/api/nutanix/v3/images" | jq -r '.status.execution_context.task_uuid' | tr -d \")
loop ${_task_id} ${PE_HOST}

log "--------------------------------------"
log "Getting UUIDs for Create VM Payload"

# Getting Image UUIDs
log "--------------------------------------"
log "Getting ${MSSQL19_SourceVM_Image1} UUID"

HTTP_JSON_BODY=$(cat <<EOF
{
  "kind":"image",
  "filter": "name==${MSSQL19_SourceVM_Image1}"
}
EOF
)

      MSSQL19_SourceVM_Image1_UUID=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST --data "${HTTP_JSON_BODY}" "https://${PE_HOST}:9440/api/nutanix/v3/images/list" | jq -r '.entities[] | .metadata.uuid' | tr -d \")

log "${MSSQL19_SourceVM_Image1} UUID = |${MSSQL19_SourceVM_Image1_UUID}|"
log "-----------------------------------------"

log "--------------------------------------"
log "Getting ${MSSQL19_SourceVM_Image2} UUID"

HTTP_JSON_BODY=$(cat <<EOF
{
  "kind":"image",
  "filter": "name==${MSSQL19_SourceVM_Image2}"
}
EOF
)

      MSSQL19_SourceVM_Image2_UUID=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST --data "${HTTP_JSON_BODY}" "https://${PE_HOST}:9440/api/nutanix/v3/images/list" | jq -r '.entities[] | .metadata.uuid' | tr -d \")

log "${MSSQL19_SourceVM_Image2} UUID = |${MSSQL19_SourceVM_Image2_UUID}|"
log "-----------------------------------------"

# Getting Network UUID
log "--------------------------------------"
log "Getting Network UUID"

  NETWORK_UUID=$(curl ${CURL_HTTP_OPTS} --request POST "https://${PE_HOST}:9440/api/nutanix/v3/subnets/list" --user ${PRISM_ADMIN}:${PE_PASSWORD} --data '{"kind":"subnet","filter": "name==User VM Subnet"}' | jq -r '.entities[] | .metadata.uuid' | tr -d \")

log "NETWORK UUID = |${NETWORK_UUID}|"



log "--------------------------------------"
log "Creating ${MSSQL19_SourceVM} VM"

HTTP_JSON_BODY=$(cat <<EOF
{
    "spec": {
        "name": "${MSSQL19_SourceVM}",
        "resources": {
            "num_threads_per_core": 1,
            "num_vcpus_per_socket": 1,
            "num_sockets": 4,
            "memory_size_mib": 8192,
            "disk_list": [
                {
                    "data_source_reference": {
                        "kind": "image",
                        "uuid": "${MSSQL19_SourceVM_Image1_UUID}"
                    },
                    "device_properties": {
                        "device_type": "DISK",
                        "disk_address": {
                            "adapter_type": "SCSI",
                            "device_index": 0
                        }
                    }
                },
                {
                    "data_source_reference": {
                        "kind": "image",
                        "uuid": "${MSSQL19_SourceVM_Image2_UUID}"
                    },
                    "device_properties": {
                        "device_type": "DISK",
                        "disk_address": {
                            "adapter_type": "SCSI",
                            "device_index": 1
                        }
                    }
                }
            ],
            "power_state": "ON",
            "nic_list": [
                {
                    "nic_type": "NORMAL_NIC",
                    "subnet_reference": {
                        "kind": "subnet",
                        "uuid": "${NETWORK_UUID}"
                    }
                }
            ]
        }
    },
    "api_version": "3.1.0",
    "metadata": {
        "kind": "vm"
    }
}
EOF
  )

_task_id=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST --data "${HTTP_JSON_BODY}" "https://${PE_HOST}:9440/api/nutanix/v3/vms" | jq -r '.status.execution_context.task_uuid' | tr -d \")
loop ${_task_id} ${PE_HOST}

log "${MSSQL19_SourceVM} VM Created"

#set +x

}

#########################################################################################################################################
# Routine to Create Era Bootcamp PreProvisioned MSSQL Server 2019
#########################################################################################################################################

function deploy_api_citrix_gold_image_vm() {
    local CURL_HTTP_OPTS=" --max-time 25 --silent --header Content-Type:application/json --header Accept:application/json --insecure "

set -x

log "--------------------------------------"
log "Uploading ${CitrixGoldImageVM_Image}"

HTTP_JSON_BODY=$(cat <<EOF
{
  "spec": {
      "name": "${CitrixGoldImageVM_Image}",
      "description": "${CitrixGoldImageVM_Image}",
      "resources": {
          "image_type": "DISK_IMAGE",
          "source_uri": "${QCOW2_REPOS}/${CitrixGoldImageVM_Image}.qcow2"
      }
  },
  "metadata": {
      "kind": "image"
  },
  "api_version": "3.1.0"
}
EOF
  )

_task_id=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST --data "${HTTP_JSON_BODY}" "https://${PE_HOST}:9440/api/nutanix/v3/images" | jq -r '.status.execution_context.task_uuid' | tr -d \")
loop ${_task_id}


log "--------------------------------------"
log "Getting UUIDs for Create VM Payload"

# Getting Image UUIDs
log "--------------------------------------"
log "Getting ${CitrixGoldImageVM_Image} UUID"

HTTP_JSON_BODY=$(cat <<EOF
{
  "kind":"image",
  "filter": "name==${CitrixGoldImageVM_Image}"
}
EOF
)

      CitrixGoldImageVM_Image_UUID=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST --data "${HTTP_JSON_BODY}" "https://${PE_HOST}:9440/api/nutanix/v3/images/list" | jq -r '.entities[] | .metadata.uuid' | tr -d \")


log "${CitrixGoldImageVM_Image} UUID = |${CitrixGoldImageVM_Image_UUID}|"
log "-----------------------------------------"

# Getting Network UUID
log "--------------------------------------"
log "Getting Network UUID"

  NETWORK_UUID=$(curl ${CURL_HTTP_OPTS} --request POST "https://${PE_HOST}:9440/api/nutanix/v3/subnets/list" --user ${PRISM_ADMIN}:${PE_PASSWORD} --data '{"kind":"subnet","filter": "name==User VM Subnet"}' | jq -r '.entities[] | .metadata.uuid' | tr -d \")

log "NETWORK UUID = |${NETWORK_UUID}|"



log "--------------------------------------"
log "Creating ${CitrixGoldImageVM} VM"

HTTP_JSON_BODY=$(cat <<EOF
{
    "spec": {
        "name": "${CitrixGoldImageVM}",
        "resources": {
            "num_threads_per_core": 1,
            "num_vcpus_per_socket": 1,
            "num_sockets": 4,
            "memory_size_mib": 4096,
            "disk_list": [
                {
                    "data_source_reference": {
                        "kind": "image",
                        "uuid": "${CitrixGoldImageVM_Image_UUID}"
                    },
                    "device_properties": {
                        "device_type": "DISK",
                        "disk_address": {
                            "adapter_type": "SCSI",
                            "device_index": 0
                        }
                    }
                }
            ],
            "power_state": "ON",
            "nic_list": [
                {
                    "nic_type": "NORMAL_NIC",
                    "subnet_reference": {
                        "kind": "subnet",
                        "uuid": "${NETWORK_UUID}"
                    }
                }
            ]
        }
    },
    "api_version": "3.1.0",
    "metadata": {
        "kind": "vm"
    }
}
EOF
  )

_task_id=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST --data "${HTTP_JSON_BODY}" "https://${PE_HOST}:9440/api/nutanix/v3/vms" | jq -r '.status.execution_context.task_uuid' | tr -d \")
loop ${_task_id}

log "${CitrixGoldImageVM} VM Created"

set +x

}
