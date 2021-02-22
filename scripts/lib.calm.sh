###############################################################################################################################################################################
# Routine to upload Citrix Calm Blueprint and set variables
###############################################################################################################################################################################

function upload_citrix_calm_blueprint() {
  local DIRECTORY="/home/nutanix/citrix"
  local BLUEPRINT=${Citrix_Blueprint}
  local CALM_PROJECT="BootcampInfra"
  local DOMAIN=${AUTH_FQDN}
  local AD_IP=${AUTH_HOST}
  local PE_IP=${PE_HOST}
  local DDC_IP=${CITRIX_DDC_HOST}
  local NutanixAcropolisPlugin="none"
  local CVM_NETWORK=${NW1_NAME}
  local NETWORK_NAME=${NW1_NAME}
  local VLAN_NAME=${NW1_VLAN}
  local BPG_RKTOOLS_URL="none"
  local NutanixAcropolis_Installed_Path="none"
  local LOCAL_PASSWORD="nutanix/4u"
  local DOMAIN_CREDS_PASSWORD="nutanix/4u"
  local PE_CREDS_PASSWORD="${PE_PASSWORD}"
  local SQL_CREDS_PASSWORD="nutanix/4u"
  local DOWNLOAD_BLUEPRINTS
  local NETWORK_UUID
  local SERVER_IMAGE="Windows2016.qcow2"
  local SERVER_IMAGE_UUID
  local CITRIX_IMAGE="Citrix_Virtual_Apps_and_Desktops_7_1912.iso"
  local CITRIX_IMAGE_UUID
  local CURL_HTTP_OPTS="--max-time 25 --silent -k --header Content-Type:application/json --header Accept:application/json  --insecure"
  local _loops="0"
  local _maxtries="75"

set -x

log "Starting Citrix Blueprint Deployment"

mkdir $DIRECTORY

#Getting the IMAGE_UUID
log "Getting Server Image UUID"

  _loops="0"
  _maxtries="75"

  SERVER_IMAGE_UUID_CHECK=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST -d '{}' 'https://localhost:9440/api/nutanix/v3/images/list' | grep "${SERVER_IMAGE}" | wc -l)
  # The response should be a Task UUID
  while [[ $SERVER_IMAGE_UUID_CHECK -ne 1 && $_loops -lt $_maxtries ]]; do
      log "Image not yet uploaded. $_loops/$_maxtries... sleeping 60 seconds"
      sleep 60
      SERVER_IMAGE_UUID_CHECK=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST -d '{}' 'https://localhost:9440/api/nutanix/v3/images/list' | grep "${SERVER_IMAGE}" | wc -l)
      (( _loops++ ))
  done
  if [[ $_loops -lt $_maxtries ]]; then
      log "Image has been uploaded."

HTTP_JSON_BODY=$(cat <<EOF
{
  "kind":"image",
  "filter": "name==${SERVER_IMAGE}"
}
EOF
)

      SERVER_IMAGE_UUID=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST --data "${HTTP_JSON_BODY}" 'https://localhost:9440/api/nutanix/v3/images/list' | jq -r '.entities[] | .metadata.uuid' | tr -d \")
  else
      log "Image is not upload, please check."
  fi

log "Server Image UUID = |$SERVER_IMAGE_UUID|"
log "-----------------------------------------"

sleep 30

log "Getting Network UUID"

  _loops="0"
  _maxtries="75"

  CITRIX_IMAGE_UUID_CHECK=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST -d '{}' 'https://localhost:9440/api/nutanix/v3/images/list' | grep 'Citrix_Virtual_Apps_and_Desktops_7_1912.iso' | wc -l)
  while [[ $CITRIX_IMAGE_UUID_CHECK -ne 1 && $_loops -lt $_maxtries ]]; do
      log "Image not yet uploaded. $_loops/$_maxtries... sleeping 60 seconds"
      sleep 60
      CITRIX_IMAGE_UUID_CHECK=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST -d '{}' 'https://localhost:9440/api/nutanix/v3/images/list' | grep 'Citrix_Virtual_Apps_and_Desktops_7_1912.iso' | wc -l)
      (( _loops++ ))
  done
  if [[ $_loops -lt $_maxtries ]]; then
      log "Image has been uploaded."
      CITRIX_IMAGE_UUID=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST --data '{"kind":"image","filter": "name==Citrix_Virtual_Apps_and_Desktops_7_1912.iso"}' 'https://localhost:9440/api/nutanix/v3/images/list' | jq -r '.entities[] | .metadata.uuid' | tr -d \")
  else
      log "Image is not upload, please check."
  fi

  echo "Citrix Image UUID = $CITRIX_IMAGE_UUID"
  echo "-----------------------------------------"

  sleep 30

# Getting Network UUID
log "Getting Network UUID"

  NETWORK_UUID=$(curl ${CURL_HTTP_OPTS} --request POST 'https://localhost:9440/api/nutanix/v3/subnets/list' --user ${PRISM_ADMIN}:${PE_PASSWORD} --data '{"kind":"subnet","filter": "name==Primary"}' | jq -r '.entities[] | .metadata.uuid' | tr -d \")

log "NETWORK UUID = $NETWORK_UUID"
log "-----------------------------------------"

  # download the blueprint
  DOWNLOAD_BLUEPRINTS=$(curl -L ${BLUEPRINT_URL}${BLUEPRINT} -o ${DIRECTORY}/${BLUEPRINT})
  log "Downloading ${BLUEPRINT} | BLUEPRINT_URL ${BLUEPRINT_URL}|${DOWNLOAD_BLUEPRINTS}"

  # ensure the directory that contains the blueprints to be imported is not empty
  if [[ $(ls -l "$DIRECTORY"/*.json) == *"No such file or directory"* ]]; then
      echo "There are no .json files found in the directory provided."
      exit 0
  fi

  if [ $CALM_PROJECT != 'none' ]; then

      project_uuid=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST --data '{"kind":"project", "filter":"name==BootcampInfra"}' 'https://localhost:9440/api/nutanix/v3/projects/list' | jq -r '.entities[].metadata.uuid')

      echo "Projet UUID = $project_uuid"

      if [ -z "$project_uuid" ]; then
          # project wasn't found
          # exit at this point as we don't want to assume all blueprints should then hit the 'default' project
          echo "Project $CALM_PROJECT was not found. Please check the name and retry."
          exit 0
      else
          echo "Project $CALM_PROJECT exists..."
      fi
  fi


  # update the user with script progress...

log "Starting blueprint updates and then Uploading to Calm..."

  JSONFile="${DIRECTORY}/${BLUEPRINT}"

log "Currently updating blueprint $JSONFile..."


  # NOTE: bash doesn't do in place editing so we need to use a temp file and overwrite the old file with new changes for every blueprint
  tmp=$(mktemp)

  # ADD PROJECT (affects all BPs being imported) if no project was specified on the command line, we've already pre-set the project variable to 'none' if a project was specified, we need to add it into the JSON data
  if [ $CALM_PROJECT != 'none' ]; then
      # add the new atributes to the JSON and overwrite the old JSON file with the new one
      $(jq --arg proj $CALM_PROJECT --arg proj_uuid $project_uuid '.metadata+={"project_reference":{"kind":$proj,"uuid":$proj_uuid}}' $JSONFile >"$tmp" && mv "$tmp" $JSONFile)
  fi

  # REMOVE the "status" and "product_version" keys (if they exist) from the JSON data this is included on export but is invalid on import. (affects all BPs being imported)
  tmp_removal=$(mktemp)
  $(jq 'del(.status) | del(.product_version)' $JSONFile >"$tmp_removal" && mv "$tmp_removal" $JSONFile)

  # GET BP NAME (affects all BPs being imported)
  # if this fails, it's either a corrupt/damaged/edited blueprint JSON file or not a blueprint file at all
  blueprint_name_quotes=$(jq '(.spec.name)' $JSONFile)
  blueprint_name="${blueprint_name_quotes%\"}" # remove the suffix "
  blueprint_name="${blueprint_name#\"}" # will remove the prefix "

  if [ $blueprint_name == 'null' ]; then
      echo "Unprocessable JSON file found. Is this definitely a Nutanix Calm blueprint file?"
      exit 0
  else
      # got the blueprint name means it is probably a valid blueprint file, we can now continue the upload
      echo "Uploading the updated blueprint: $blueprint_name..."

      path_to_file=$JSONFile
      bp_name=$blueprint_name
      project_uuid=$project_uuid

      upload_result=$(curl -s -k --insecure --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST -F file=@$path_to_file -F name=$bp_name -F project_uuid=$project_uuid "https://localhost:9440/api/nutanix/v3/blueprints/import_file")

      #if the upload_result var is not empty then let's say it was succcessful
      if [ -z "$upload_result" ]; then
          echo "Upload for $bp_name did not finish."
      else
          echo "Upload for $bp_name finished."
          echo "-----------------------------------------"
          # echo "Result: $upload_result"
      fi
  fi

log "Finished uploading ${BLUEPRINT}!"

#Getting the Blueprint UUID
log "Getting Citrix Blueprint ID Now"

HTTP_JSON_BODY=$(cat <<EOF
{
  "kind":"blueprint",
  "filter": "name==${Citrix_Blueprint_Name}"
}
EOF
)

  CITRIX_BLUEPRINT_UUID=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST --data '{"kind":"blueprint","filter": "name==CitrixBootcampInfra"}' 'https://localhost:9440/api/nutanix/v3/blueprints/list' | jq -r '.entities[] | .metadata.uuid' | tr -d \")

log "Citrix Blueprint UUID = $CITRIX_BLUEPRINT_UUID"

# Var list
log "-----------------------------------------"
log "Update Blueprint and writing to temp file"
log "${CALM_PROJECT} network UUID: ${project_uuid}"
log "DOMAIN=${DOMAIN}"
log "AD_IP=${AD_IP}"
log "PE_IP=${PE_IP}"
log "DDC_IP=${DDC_IP}"
log "CVM_NETWORK=${CVM_NETWORK}"
log "SERVER_IMAGE=${SERVER_IMAGE}"
log "SERVER_IMAGE_UUID=${SERVER_IMAGE_UUID}"
log "CITRIX_IMAGE=${CITRIX_IMAGE}"
log "CITRIX_IMAGE_UUID=${CITRIX_IMAGE_UUID}"
log "NETWORK_UUID=${NETWORK_UUID}"
log "-----------------------------------------"

  DOWNLOADED_JSONFile="${BLUEPRINT}-${CITRIX_BLUEPRINT_UUID}.json"
  UPDATED_JSONFile="${BLUEPRINT}-${CITRIX_BLUEPRINT_UUID}-updated.json"

  # GET The Blueprint so it can be updated
  curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X GET -d '{}' "https://localhost:9440/api/nutanix/v3/blueprints/${CITRIX_BLUEPRINT_UUID}" > ${DOWNLOADED_JSONFile}

  cat $DOWNLOADED_JSONFile \
  | jq -c 'del(.status)' \
  | jq -c -r "(.spec.resources.app_profile_list[0].variable_list[0].value = \"$DOMAIN\")" \
  | jq -c -r "(.spec.resources.app_profile_list[0].variable_list[1].value = \"$AD_IP\")" \
  | jq -c -r "(.spec.resources.app_profile_list[0].variable_list[2].value = \"$PE_IP\")" \
  | jq -c -r "(.spec.resources.app_profile_list[0].variable_list[6].value = \"$DDC_IP\")" \
  | jq -c -r "(.spec.resources.app_profile_list[0].variable_list[4].value = \"$CVM_NETWORK\")" \
  | jq -c -r "(.spec.resources.substrate_definition_list[0].create_spec.resources.disk_list[0].data_source_reference.name = \"$SERVER_IMAGE\")" \
  | jq -c -r "(.spec.resources.substrate_definition_list[0].create_spec.resources.disk_list[0].data_source_reference.uuid = \"$SERVER_IMAGE_UUID\")" \
  | jq -c -r "(.spec.resources.substrate_definition_list[0].create_spec.resources.disk_list[1].data_source_reference.name = \"$CITRIX_IMAGE\")" \
  | jq -c -r "(.spec.resources.substrate_definition_list[0].create_spec.resources.disk_list[1].data_source_reference.uuid = \"$CITRIX_IMAGE_UUID\")" \
  | jq -c -r "(.spec.resources.substrate_definition_list[].create_spec.resources.nic_list[].subnet_reference.name = \"$NETWORK_NAME\")" \
  | jq -c -r "(.spec.resources.substrate_definition_list[].create_spec.resources.nic_list[].subnet_reference.uuid = \"$NETWORK_UUID\")" \
  | jq -c -r "(.spec.resources.credential_definition_list[0].secret.value = \"$LOCAL_PASSWORD\")" \
  | jq -c -r '(.spec.resources.credential_definition_list[0].secret.attrs.is_secret_modified = "true")' \
  | jq -c -r "(.spec.resources.credential_definition_list[1].secret.value = \"$DOMAIN_CREDS_PASSWORD\")" \
  | jq -c -r '(.spec.resources.credential_definition_list[1].secret.attrs.is_secret_modified = "true")' \
  | jq -c -r "(.spec.resources.credential_definition_list[2].secret.value = \"$PE_CREDS_PASSWORD\")" \
  | jq -c -r '(.spec.resources.credential_definition_list[2].secret.attrs.is_secret_modified = "true")' \
  > $UPDATED_JSONFile

  echo "Saving Credentials Edits with PUT"

  curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X PUT -d @$UPDATED_JSONFile "https://localhost:9440/api/nutanix/v3/blueprints/${CITRIX_BLUEPRINT_UUID}"

  echo "Finished Updating Credentials"

  # GET The Blueprint payload
  curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X GET -d '{}' "https://localhost:9440/api/nutanix/v3/blueprints/${CITRIX_BLUEPRINT_UUID}" | jq 'del(.status, .spec.name) | .spec += {"application_name": "Citrix Infra", "app_profile_reference": {"uuid": .spec.resources.app_profile_list[0].uuid, "kind": "app_profile" }}' > set_blueprint_response_file.json

  # Launch the BLUEPRINT

  echo "Launching the Era Server Application"

  curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST -d @set_blueprint_response_file.json "https://localhost:9440/api/nutanix/v3/blueprints/${CITRIX_BLUEPRINT_UUID}/launch"

  echo "Finished Launching the Citrix Infra Application"

set +x

}

######################################################################################################################################
# Routine to upload SNOW-Deployerizer Calm Blueprint and set variables
######################################################################################################################################

function upload_snow_calm_blueprint() {
  local DIRECTORY="/home/nutanix/snow"
  local BLUEPRINT=${SNOW_Blueprint}
  local CALM_PROJECT="BootcampInfra"
  local Calm_App_Name="SNOW-Deployerizer"
  local AD_IP=${AUTH_HOST}
  local PE_IP=${PE_HOST}
  local PC_IP=${PC_HOST}
  local ERA_IP=${ERA_HOST}
  local CVM_NETWORK=${NW1_NAME}
  local NETWORK_NAME=${NW1_NAME}
  local VLAN_NAME=${NW1_VLAN}
  local PRISM_ADMIN_PASSWORD="${PE_PASSWORD}"
  local ROOT_PASSWORD="nutanix/4u"
  local SNOW_ADMIN_PASSWORD="nutanix/4u"
  local DOWNLOAD_BLUEPRINTS
  local NETWORK_UUID
  local SERVER_IMAGE="CentOS7.qcow2"
  local SERVER_IMAGE_UUID
  local SNOW_URL="${SNOWInstanceURL}"
  local CURL_HTTP_OPTS="--max-time 25 --silent -k --header Content-Type:application/json --header Accept:application/json  --insecure"
  local _loops="0"
  local _maxtries="75"

set -x

log "Starting SNOW-Deployerizer Blueprint Deployment"

mkdir $DIRECTORY

# Getting the IMAGE_UUID
log "Getting Server Image UUID"

  _loops="0"
  _maxtries="75"

  SERVER_IMAGE_UUID_CHECK=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST -d '{}' 'https://localhost:9440/api/nutanix/v3/images/list' | grep "${SERVER_IMAGE}" | wc -l)
  # The response should be a Task UUID
  while [[ $SERVER_IMAGE_UUID_CHECK -ne 1 && $_loops -lt $_maxtries ]]; do
      log "Image not yet uploaded. $_loops/$_maxtries... sleeping 60 seconds"
      sleep 60
      SERVER_IMAGE_UUID_CHECK=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST -d '{}' 'https://localhost:9440/api/nutanix/v3/images/list' | grep "${SERVER_IMAGE}" | wc -l)
      (( _loops++ ))
  done
  if [[ $_loops -lt $_maxtries ]]; then
      log "Image has been uploaded."

HTTP_JSON_BODY=$(cat <<EOF
{
  "kind":"image",
  "filter": "name==${SERVER_IMAGE}"
}
EOF
)

      SERVER_IMAGE_UUID=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST --data "${HTTP_JSON_BODY}" 'https://localhost:9440/api/nutanix/v3/images/list' | jq -r '.entities[] | .metadata.uuid' | tr -d \")
  else
      log "Image is not upload, please check."
  fi

log "Server Image UUID = |$SERVER_IMAGE_UUID|"
log "-----------------------------------------"

sleep 30

# Getting Network UUID
log "Getting Network UUID"

  NETWORK_UUID=$(curl ${CURL_HTTP_OPTS} --request POST 'https://localhost:9440/api/nutanix/v3/subnets/list' --user ${PRISM_ADMIN}:${PE_PASSWORD} --data '{"kind":"subnet","filter": "name==Primary"}' | jq -r '.entities[] | .metadata.uuid' | tr -d \")

log "NETWORK UUID = |$NETWORK_UUID|"
log "-----------------------------------------"

# download the blueprint
DOWNLOAD_BLUEPRINTS=$(curl -L ${BLUEPRINT_URL}${BLUEPRINT} -o ${DIRECTORY}/${BLUEPRINT})
log "Downloading ${BLUEPRINT} | BLUEPRINT_URL ${BLUEPRINT_URL}|${DOWNLOAD_BLUEPRINTS}"

  # ensure the directory that contains the blueprints to be imported is not empty
  if [[ $(ls -l "$DIRECTORY"/*.json) == *"No such file or directory"* ]]; then
      echo "There are no .json files found in the directory provided."
      exit 0
  fi

  if [ $CALM_PROJECT != 'none' ]; then

      project_uuid=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST --data '{"kind":"project", "filter":"name==BootcampInfra"}' 'https://localhost:9440/api/nutanix/v3/projects/list' | jq -r '.entities[].metadata.uuid')

      echo "Projet UUID = $project_uuid"

      if [ -z "$project_uuid" ]; then
          # project wasn't found
          # exit at this point as we don't want to assume all blueprints should then hit the 'default' project
          echo "Project $CALM_PROJECT was not found. Please check the name and retry."
          exit 0
      else
          echo "Project $CALM_PROJECT exists..."
      fi
  fi


# update the user with script progress...

log "Starting blueprint updates and then Uploading to Calm..."

JSONFile="${DIRECTORY}/${BLUEPRINT}"

log "Currently updating blueprint $JSONFile..."


  # NOTE: bash doesn't do in place editing so we need to use a temp file and overwrite the old file with new changes for every blueprint
  tmp=$(mktemp)

  # ADD PROJECT (affects all BPs being imported) if no project was specified on the command line, we've already pre-set the project variable to 'none' if a project was specified, we need to add it into the JSON data
  if [ $CALM_PROJECT != 'none' ]; then
      # add the new atributes to the JSON and overwrite the old JSON file with the new one
      $(jq --arg proj $CALM_PROJECT --arg proj_uuid $project_uuid '.metadata+={"project_reference":{"kind":$proj,"uuid":$proj_uuid}}' $JSONFile >"$tmp" && mv "$tmp" $JSONFile)
  fi

  # REMOVE the "status" and "product_version" keys (if they exist) from the JSON data this is included on export but is invalid on import. (affects all BPs being imported)
  tmp_removal=$(mktemp)
  $(jq 'del(.status) | del(.product_version)' $JSONFile >"$tmp_removal" && mv "$tmp_removal" $JSONFile)

  # GET BP NAME (affects all BPs being imported)
  # if this fails, it's either a corrupt/damaged/edited blueprint JSON file or not a blueprint file at all
  blueprint_name_quotes=$(jq '(.spec.name)' $JSONFile)
  blueprint_name="${blueprint_name_quotes%\"}" # remove the suffix "
  blueprint_name="${blueprint_name#\"}" # will remove the prefix "

  if [ $blueprint_name == 'null' ]; then
      echo "Unprocessable JSON file found. Is this definitely a Nutanix Calm blueprint file?"
      exit 0
  else
      # got the blueprint name means it is probably a valid blueprint file, we can now continue the upload
      echo "Uploading the updated blueprint: $blueprint_name..."

      path_to_file=$JSONFile
      bp_name=$blueprint_name
      project_uuid=$project_uuid

      upload_result=$(curl -s -k --insecure --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST -F file=@$path_to_file -F name=$bp_name -F project_uuid=$project_uuid "https://localhost:9440/api/nutanix/v3/blueprints/import_file")

      #if the upload_result var is not empty then let's say it was succcessful
      if [ -z "$upload_result" ]; then
          echo "Upload for $bp_name did not finish."
      else
          echo "Upload for $bp_name finished."
          echo "-----------------------------------------"
          # echo "Result: $upload_result"
      fi
  fi

log "Finished uploading ${BLUEPRINT}!"

# Getting the Blueprint UUID
log "Getting SNOW Blueprint ID Now"

HTTP_JSON_BODY=$(cat <<EOF
{
  "kind":"blueprint",
  "filter": "name==${SNOW_Blueprint_Name}"
}
EOF
)

  SNOW_BLUEPRINT_UUID=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST --data '{"kind":"blueprint","filter": "name==SNOW-Paris"}' 'https://localhost:9440/api/nutanix/v3/blueprints/list' | jq -r '.entities[] | .metadata.uuid' | tr -d \")

log "SNOW Blueprint ID: |${SNOW_BLUEPRINT_UUID}|"

# Var list
log "-----------------------------------------"
log "Update Blueprint and writing to temp file"
log "SNOW Blueprint UUID = |${SNOW_BLUEPRINT_UUID}|"
log "${CALM_PROJECT} Project UUID: |${project_uuid}|"
log "PE_IP = |${PE_IP}|"
log "PC_IP = |${PC_IP}|"
log "CVM_NETWORK = |${CVM_NETWORK}|"
log "SERVER_IMAGE = |${SERVER_IMAGE}|"
log "SERVER_IMAGE_UUID = |${SERVER_IMAGE_UUID}|"
log "NETWORK_UUID = |${NETWORK_UUID}|"
log "SNOW URL = |${SNOW_URL}|"
log "-----------------------------------------"

  DOWNLOADED_JSONFile="${BLUEPRINT}-${SNOW_BLUEPRINT_UUID}.json"
  UPDATED_JSONFile="${BLUEPRINT}-${SNOW_BLUEPRINT_UUID}-updated.json"

  # GET The Blueprint so it can be updated
  curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X GET -d '{}' "https://localhost:9440/api/nutanix/v3/blueprints/${SNOW_BLUEPRINT_UUID}" > ${DOWNLOADED_JSONFile}

  cat $DOWNLOADED_JSONFile \
  | jq -c 'del(.status)' \
  | jq -c -r "(.spec.resources.app_profile_list[0].variable_list[0].value = \"$SNOW_URL\")" \
  | jq -c -r "(.spec.resources.app_profile_list[0].variable_list[1].value = \"$SNOW_ADMIN_PASSWORD\")" \
  | jq -c -r "(.spec.resources.app_profile_list[0].variable_list[2].value = \"$PRISM_ADMIN_PASSWORD\")" \
  | jq -c -r "(.spec.resources.app_profile_list[0].variable_list[3].value = \"$PC_IP\")" \
  | jq -c -r "(.spec.resources.substrate_definition_list[0].create_spec.resources.disk_list[0].data_source_reference.name = \"$SERVER_IMAGE\")" \
  | jq -c -r "(.spec.resources.substrate_definition_list[0].create_spec.resources.disk_list[0].data_source_reference.uuid = \"$SERVER_IMAGE_UUID\")" \
  | jq -c -r "(.spec.resources.substrate_definition_list[].create_spec.resources.nic_list[].subnet_reference.name = \"$NETWORK_NAME\")" \
  | jq -c -r "(.spec.resources.substrate_definition_list[].create_spec.resources.nic_list[].subnet_reference.uuid = \"$NETWORK_UUID\")" \
  | jq -c -r "(.spec.resources.credential_definition_list[].secret.value = \"$ROOT_PASSWORD\")" \
  | jq -c -r '(.spec.resources.credential_definition_list[].secret.attrs.is_secret_modified = "true")' \
  > $UPDATED_JSONFile

log "Saving Credentials Edits with PUT"

  curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X PUT -d @$UPDATED_JSONFile "https://localhost:9440/api/nutanix/v3/blueprints/${SNOW_BLUEPRINT_UUID}"

log "Finished Updating Credentials"

# GET The Blueprint payload
log "getting Calm Blueprint Payload"

  curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X GET -d '{}' "https://localhost:9440/api/nutanix/v3/blueprints/${SNOW_BLUEPRINT_UUID}" | jq 'del(.status, .spec.name) | .spec += {"application_name": "SNOW Infra", "app_profile_reference": {"uuid": .spec.resources.app_profile_list[0].uuid, "kind": "app_profile" }}' > set_blueprint_response_file.json

# Launch the BLUEPRINT
log "Launching the SNOW-Deployerizer Application"

  curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST -d @set_blueprint_response_file.json "https://localhost:9440/api/nutanix/v3/blueprints/${SNOW_BLUEPRINT_UUID}/launch"

log "Finished Launching the SNOW-Deployerizer Application"

set +x

}

###############################################################################################################################################################################
# Routine to upload Fiesta & MSSQL Calm Blueprint and set variables
###############################################################################################################################################################################

function upload_fiesta_mssql_blueprint() {
  local DIRECTORY="/home/nutanix/fiesta"
  local BLUEPRINT=${Fiesta_MSSQL_Blueprint}
  local CALM_PROJECT="BootcampInfra"
  local DOMAIN=${AUTH_FQDN}
  local Calm_App_Name="Fiesta"
  local AD_IP=${AUTH_HOST}
  local PE_IP=${PE_HOST}
  local ERA_IP=${ERA_HOST}
  local CVM_NETWORK=${NW1_NAME}
  local NETWORK_NAME=${NW1_NAME}
  local VLAN_NAME=${NW1_VLAN}
  local PRISM_ADMIN_PASSWORD="${PE_PASSWORD}"
  local ROOT_PASSWORD="nutanix/4u"
  local SNOW_ADMIN_PASSWORD="nutanix/4u"
  local DOWNLOAD_BLUEPRINTS
  local NETWORK_UUID
  local SERVER_IMAGE="CentOS7.qcow2"
  local SERVER_IMAGE_UUID
  local DB_SERVER_IMAGE1="MSSQL16-Source-Disk1.qcow2"
  local DB_SERVER_IMAGE1_UUID
  local DB_SERVER_IMAGE2="MSSQL16-Source-Disk2.qcow2"
  local DB_SERVER_IMAGE2_UUID
  local db_password="Nutanix/4u"
  local CURL_HTTP_OPTS="--max-time 25 --silent -k --header Content-Type:application/json --header Accept:application/json  --insecure"
  local _loops="0"
  local _maxtries="75"

set -x

log "Fiesta Blueprint Deployment"

mkdir $DIRECTORY

# Getting the IMAGE_UUID
log "Getting Server Image UUID"

  _loops="0"
  _maxtries="75"

  SERVER_IMAGE_UUID_CHECK=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST -d '{}' 'https://localhost:9440/api/nutanix/v3/images/list' | grep "${SERVER_IMAGE}" | wc -l)
  # The response should be a Task UUID
  while [[ $SERVER_IMAGE_UUID_CHECK -ne 1 && $_loops -lt $_maxtries ]]; do
      log "Image not yet uploaded. $_loops/$_maxtries... sleeping 60 seconds"
      sleep 60
      SERVER_IMAGE_UUID_CHECK=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST -d '{}' 'https://localhost:9440/api/nutanix/v3/images/list' | grep "${SERVER_IMAGE}" | wc -l)
      (( _loops++ ))
  done
  if [[ $_loops -lt $_maxtries ]]; then
      log "Image has been uploaded."

HTTP_JSON_BODY=$(cat <<EOF
{
  "kind":"image",
  "filter": "name==${SERVER_IMAGE}"
}
EOF
)

      SERVER_IMAGE_UUID=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST --data "${HTTP_JSON_BODY}" 'https://localhost:9440/api/nutanix/v3/images/list' | jq -r '.entities[] | .metadata.uuid' | tr -d \")
  else
      log "Image is not upload, please check."
  fi

log "Server Image UUID = |${SERVER_IMAGE_UUID}|"
log "-----------------------------------------"

sleep 30

# Getting the DB Server IMAGE_UUID
log "Getting DB Server Image1 UUID"

  _loops="0"
  _maxtries="75"

  DB_SERVER_IMAGE1_UUID_CHECK=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST -d '{}' 'https://localhost:9440/api/nutanix/v3/images/list' | grep "${DB_SERVER_IMAGE1}" | wc -l)
  # The response should be a Task UUID
  while [[ $SERVER_IMAGE_UUID_CHECK -ne 1 && $_loops -lt $_maxtries ]]; do
      log "Image not yet uploaded. $_loops/$_maxtries... sleeping 60 seconds"
      sleep 60
      DB_SERVER_IMAGE1_UUID_CHECK=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST -d '{}' 'https://localhost:9440/api/nutanix/v3/images/list' | grep "${DB_SERVER_IMAGE1}" | wc -l)
      (( _loops++ ))
  done
  if [[ $_loops -lt $_maxtries ]]; then
      log "Image has been uploaded."

HTTP_JSON_BODY=$(cat <<EOF
{
  "kind":"image",
  "filter": "name==${DB_SERVER_IMAGE1}"
}
EOF
)

      DB_SERVER_IMAGE1_UUID=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST --data "${HTTP_JSON_BODY}" 'https://localhost:9440/api/nutanix/v3/images/list' | jq -r '.entities[] | .metadata.uuid' | tr -d \")
  else
      log "Image is not upload, please check."
  fi

log "DB Server Image1 UUID = |${DB_SERVER_IMAGE1_UUID}|"
log "-----------------------------------------"

sleep 30

# Getting the DB Server IMAGE_UUID
log "Getting DB Server Image2 UUID"

  _loops="0"
  _maxtries="75"

  DB_SERVER_IMAGE2_UUID_CHECK=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST -d '{}' 'https://localhost:9440/api/nutanix/v3/images/list' | grep "${DB_SERVER_IMAGE2}" | wc -l)
  # The response should be a Task UUID
  while [[ $SERVER_IMAGE_UUID_CHECK -ne 1 && $_loops -lt $_maxtries ]]; do
      log "Image not yet uploaded. $_loops/$_maxtries... sleeping 60 seconds"
      sleep 60
      DB_SERVER_IMAGE2_UUID_CHECK=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST -d '{}' 'https://localhost:9440/api/nutanix/v3/images/list' | grep "${DB_SERVER_IMAGE2}" | wc -l)
      (( _loops++ ))
  done
  if [[ $_loops -lt $_maxtries ]]; then
      log "Image has been uploaded."

HTTP_JSON_BODY=$(cat <<EOF
{
  "kind":"image",
  "filter": "name==${DB_SERVER_IMAGE2}"
}
EOF
)

      DB_SERVER_IMAGE2_UUID=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST --data "${HTTP_JSON_BODY}" 'https://localhost:9440/api/nutanix/v3/images/list' | jq -r '.entities[] | .metadata.uuid' | tr -d \")
  else
      log "Image is not upload, please check."
  fi

log "DB Server Image1 UUID = |${DB_SERVER_IMAGE2_UUID}|"
log "-----------------------------------------"

sleep 30

# Getting Network UUID
log "Getting Network UUID"

  NETWORK_UUID=$(curl ${CURL_HTTP_OPTS} --request POST 'https://localhost:9440/api/nutanix/v3/subnets/list' --user ${PRISM_ADMIN}:${PE_PASSWORD} --data '{"kind":"subnet","filter": "name==Primary"}' | jq -r '.entities[] | .metadata.uuid' | tr -d \")

log "NETWORK UUID = |$NETWORK_UUID|"
log "-----------------------------------------"

# download the blueprint
DOWNLOAD_BLUEPRINTS=$(curl -L ${BLUEPRINT_URL}${BLUEPRINT} -o ${DIRECTORY}/${BLUEPRINT})
log "Downloading ${BLUEPRINT} | BLUEPRINT_URL ${BLUEPRINT_URL}|${DOWNLOAD_BLUEPRINTS}"

  # ensure the directory that contains the blueprints to be imported is not empty
  if [[ $(ls -l "$DIRECTORY"/*.json) == *"No such file or directory"* ]]; then
      echo "There are no .json files found in the directory provided."
      exit 0
  fi

  if [ $CALM_PROJECT != 'none' ]; then

      project_uuid=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST --data '{"kind":"project", "filter":"name==BootcampInfra"}' 'https://localhost:9440/api/nutanix/v3/projects/list' | jq -r '.entities[].metadata.uuid')

      echo "Projet UUID = $project_uuid"

      if [ -z "$project_uuid" ]; then
          # project wasn't found
          # exit at this point as we don't want to assume all blueprints should then hit the 'default' project
          echo "Project $CALM_PROJECT was not found. Please check the name and retry."
          exit 0
      else
          echo "Project $CALM_PROJECT exists..."
      fi
  fi


# update the user with script progress...

log "Starting blueprint updates and then Uploading to Calm..."

JSONFile="${DIRECTORY}/${BLUEPRINT}"

log "Currently updating blueprint $JSONFile..."


  # NOTE: bash doesn't do in place editing so we need to use a temp file and overwrite the old file with new changes for every blueprint
  tmp=$(mktemp)

  # ADD PROJECT (affects all BPs being imported) if no project was specified on the command line, we've already pre-set the project variable to 'none' if a project was specified, we need to add it into the JSON data
  if [ $CALM_PROJECT != 'none' ]; then
      # add the new atributes to the JSON and overwrite the old JSON file with the new one
      $(jq --arg proj $CALM_PROJECT --arg proj_uuid $project_uuid '.metadata+={"project_reference":{"kind":$proj,"uuid":$proj_uuid}}' $JSONFile >"$tmp" && mv "$tmp" $JSONFile)
  fi

  # REMOVE the "status" and "product_version" keys (if they exist) from the JSON data this is included on export but is invalid on import. (affects all BPs being imported)
  tmp_removal=$(mktemp)
  $(jq 'del(.status) | del(.product_version)' $JSONFile >"$tmp_removal" && mv "$tmp_removal" $JSONFile)

  # GET BP NAME (affects all BPs being imported)
  # if this fails, it's either a corrupt/damaged/edited blueprint JSON file or not a blueprint file at all
  blueprint_name_quotes=$(jq '(.spec.name)' $JSONFile)
  blueprint_name="${blueprint_name_quotes%\"}" # remove the suffix "
  blueprint_name="${blueprint_name#\"}" # will remove the prefix "

  if [ $blueprint_name == 'null' ]; then
      echo "Unprocessable JSON file found. Is this definitely a Nutanix Calm blueprint file?"
      exit 0
  else
      # got the blueprint name means it is probably a valid blueprint file, we can now continue the upload
      echo "Uploading the updated blueprint: $blueprint_name..."

      path_to_file=$JSONFile
      bp_name=$blueprint_name
      project_uuid=$project_uuid

      upload_result=$(curl -s -k --insecure --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST -F file=@$path_to_file -F name=$bp_name -F project_uuid=$project_uuid "https://localhost:9440/api/nutanix/v3/blueprints/import_file")

      #if the upload_result var is not empty then let's say it was succcessful
      if [ -z "$upload_result" ]; then
          echo "Upload for $bp_name did not finish."
      else
          echo "Upload for $bp_name finished."
          echo "-----------------------------------------"
          # echo "Result: $upload_result"
      fi
  fi

log "Finished uploading ${BLUEPRINT}!"

# Getting the Blueprint UUID
log "Getting SNOW Blueprint ID Now"

HTTP_JSON_BODY=$(cat <<EOF
{
  "kind":"blueprint",
  "filter": "name==Fiesta-MSSQL-Source"
}
EOF
)

  FIESTA_BLUEPRINT_UUID=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST --data "${HTTP_JSON_BODY}" 'https://localhost:9440/api/nutanix/v3/blueprints/list' | jq -r '.entities[] | .metadata.uuid' | tr -d \")

log "FIESTA BLUEPRINT UUID: |${FIESTA_BLUEPRINT_UUID}|"

# Launch for the numbe of users specified

#for _user in "${USERS[@]}" ; do
_user="nate88"
User_Calm_App_Nam="${_user}${Calm_App_Name}"

# Var list
log "-----------------------------------------"
log "FIESTA_BLUEPRINT_UUID = |${FIESTA_BLUEPRINT_UUID}|"
log "${CALM_PROJECT} Project UUID: |${project_uuid}|"
log "SERVER_IMAGE = |${SERVER_IMAGE}|"
log "SERVER_IMAGE_UUID = |${SERVER_IMAGE_UUID}|"
log "DB_SERVER_IMAGE1 = |${DB_SERVER_IMAGE1}|"
log "DB_SERVER_IMAGE1_UUID = |${DB_SERVER_IMAGE1_UUID}|"
log "DB_SERVER_IMAGE2 = |${DB_SERVER_IMAGE2}|"
log "DB_SERVER_IMAGE2_UUID = |${DB_SERVER_IMAGE2_UUID}|"
log "NETWORK_UUID = |${NETWORK_UUID}|"
log "User_Calm_App_Nam = |${User_Calm_App_Nam}|"
log "user_initials = |${_user}|"
log "DOMAIN = |${DOMAIN}|"
log "-----------------------------------------"

  DOWNLOADED_JSONFile="${BLUEPRINT}-${FIESTA_BLUEPRINT_UUID}.json"
  UPDATED_JSONFile="${BLUEPRINT}-${FIESTA_BLUEPRINT_UUID}-updated.json"

  # GET The Blueprint so it can be updated
  curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X GET -d '{}' "https://localhost:9440/api/nutanix/v3/blueprints/${FIESTA_BLUEPRINT_UUID}" > ${DOWNLOADED_JSONFile}

  cat $DOWNLOADED_JSONFile \
  | jq -c 'del(.status)' \
  | jq -c -r "(.spec.resources.app_profile_list[0].variable_list[1].value = \"$DOMAIN\")" \
  | jq -c -r "(.spec.resources.app_profile_list[0].variable_list[2].value = \"$db_password\")" \
  | jq -c -r "(.spec.resources.app_profile_list[0].variable_list[5].value = \"$_user\")" \
  | jq -c -r "(.spec.resources.substrate_definition_list[0].create_spec.resources.disk_list[0].data_source_reference.name = \"$SERVER_IMAGE\")" \
  | jq -c -r "(.spec.resources.substrate_definition_list[0].create_spec.resources.disk_list[0].data_source_reference.uuid = \"$SERVER_IMAGE_UUID\")" \
  | jq -c -r "(.spec.resources.substrate_definition_list[1].create_spec.resources.disk_list[0].data_source_reference.name = \"$DB_SERVER_IMAGE1\")" \
  | jq -c -r "(.spec.resources.substrate_definition_list[1].create_spec.resources.disk_list[0].data_source_reference.uuid = \"$DB_SERVER_IMAGE1_UUID\")" \
  | jq -c -r "(.spec.resources.substrate_definition_list[1].create_spec.resources.disk_list[1].data_source_reference.name = \"$DB_SERVER_IMAGE2\")" \
  | jq -c -r "(.spec.resources.substrate_definition_list[1].create_spec.resources.disk_list[1].data_source_reference.uuid = \"$DB_SERVER_IMAGE2_UUID\")" \
  | jq -c -r "(.spec.resources.substrate_definition_list[0].create_spec.resources.nic_list[].subnet_reference.name = \"$NETWORK_NAME\")" \
  | jq -c -r "(.spec.resources.substrate_definition_list[0].create_spec.resources.nic_list[].subnet_reference.uuid = \"$NETWORK_UUID\")" \
  | jq -c -r "(.spec.resources.substrate_definition_list[1].create_spec.resources.nic_list[].subnet_reference.name = \"$NETWORK_NAME\")" \
  | jq -c -r "(.spec.resources.substrate_definition_list[1].create_spec.resources.nic_list[].subnet_reference.uuid = \"$NETWORK_UUID\")" \
  | jq -c -r "(.spec.resources.credential_definition_list[].secret.value = \"$ROOT_PASSWORD\")" \
  | jq -c -r '(.spec.resources.credential_definition_list[].secret.attrs.is_secret_modified = "true")' \
  > $UPDATED_JSONFile

log "Saving Credentials Edits with PUT"

  curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X PUT -d @$UPDATED_JSONFile "https://localhost:9440/api/nutanix/v3/blueprints/${FIESTA_BLUEPRINT_UUID}"

log "Finished Updating Credentials"

# GET The Blueprint payload
log "getting Calm Blueprint Payload"

  curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X GET -d '{}' "https://localhost:9440/api/nutanix/v3/blueprints/${FIESTA_BLUEPRINT_UUID}" | jq "del(.status, .spec.name) | .spec += {"application_name": \"$User_Calm_App_Nam\", "app_profile_reference": {"uuid": .spec.resources.app_profile_list[0].uuid, "kind": "app_profile" }}" > set_blueprint_response_file.json

# Launch the BLUEPRINT
log "Launching the ${_user} Fiesta Application"

  curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST -d @set_blueprint_response_file.json "https://localhost:9440/api/nutanix/v3/blueprints/${FIESTA_BLUEPRINT_UUID}/launch"

log "Finished Launching the ${_user} Fiesta  Application"

#done

set +x

}

###############################################################################################################################################################################
# Routine to upload Fiesta & MSSQL Calm Blueprint and set variables
###############################################################################################################################################################################

function upload_docker_fiesta_era_blueprint() {
  local DIRECTORY="/home/nutanix/cicd"
  local BLUEPRINT=${Docker_Fiesta_Era_Blueprint}
  local CALM_PROJECT="BootcampInfra"
  local DOMAIN=${AUTH_FQDN}
  local Calm_App_Name="CICD"
  local AD_IP=${AUTH_HOST}
  local PE_IP=${PE_HOST}
  local ERA_IP=${ERA_HOST}
  local ERA_ADMIN=${ERA_USER}
  local ERA_PASSWD=${ERA_PASSWORD}
  local CVM_NETWORK=${NW1_NAME}
  local NETWORK_NAME=${NW1_NAME}
  local VLAN_NAME=${NW1_VLAN}
  local PRISM_ADMIN_PASSWORD="${PE_PASSWORD}"
  local ROOT_PASSWORD="nutanix/4u"
  local SNOW_ADMIN_PASSWORD="nutanix/4u"
  local DOWNLOAD_BLUEPRINTS
  local NETWORK_UUID
  local SERVER_IMAGE="CentOS7.qcow2"
  local SERVER_IMAGE_UUID
  local db_password="Nutanix/4u"
  local CURL_HTTP_OPTS="--max-time 25 --silent -k --header Content-Type:application/json --header Accept:application/json  --insecure"
  local _loops="0"
  local _maxtries="75"

set -x

log "Starting SNOW-Deployerizer Blueprint Deployment"

mkdir $DIRECTORY

# Getting the IMAGE_UUID
log "Getting Server Image UUID"

  _loops="0"
  _maxtries="75"

  SERVER_IMAGE_UUID_CHECK=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST -d '{}' 'https://localhost:9440/api/nutanix/v3/images/list' | grep "${SERVER_IMAGE}" | wc -l)
  # The response should be a Task UUID
  while [[ $SERVER_IMAGE_UUID_CHECK -ne 1 && $_loops -lt $_maxtries ]]; do
      log "Image not yet uploaded. $_loops/$_maxtries... sleeping 60 seconds"
      sleep 60
      SERVER_IMAGE_UUID_CHECK=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST -d '{}' 'https://localhost:9440/api/nutanix/v3/images/list' | grep "${SERVER_IMAGE}" | wc -l)
      (( _loops++ ))
  done
  if [[ $_loops -lt $_maxtries ]]; then
      log "Image has been uploaded."

HTTP_JSON_BODY=$(cat <<EOF
{
  "kind":"image",
  "filter": "name==${SERVER_IMAGE}"
}
EOF
)

      SERVER_IMAGE_UUID=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST --data "${HTTP_JSON_BODY}" 'https://localhost:9440/api/nutanix/v3/images/list' | jq -r '.entities[] | .metadata.uuid' | tr -d \")
  else
      log "Image is not upload, please check."
  fi

log "Server Image UUID = |${SERVER_IMAGE_UUID}|"
log "-----------------------------------------"

sleep 30

# Getting Network UUID
log "Getting Network UUID"

  NETWORK_UUID=$(curl ${CURL_HTTP_OPTS} --request POST 'https://localhost:9440/api/nutanix/v3/subnets/list' --user ${PRISM_ADMIN}:${PE_PASSWORD} --data '{"kind":"subnet","filter": "name==Primary"}' | jq -r '.entities[] | .metadata.uuid' | tr -d \")

log "NETWORK UUID = |$NETWORK_UUID|"
log "-----------------------------------------"

# download the blueprint
DOWNLOAD_BLUEPRINTS=$(curl -L ${BLUEPRINT_URL}${BLUEPRINT} -o ${DIRECTORY}/${BLUEPRINT})
log "Downloading ${BLUEPRINT} | BLUEPRINT_URL ${BLUEPRINT_URL}|${DOWNLOAD_BLUEPRINTS}"

  # ensure the directory that contains the blueprints to be imported is not empty
  if [[ $(ls -l "$DIRECTORY"/*.json) == *"No such file or directory"* ]]; then
      echo "There are no .json files found in the directory provided."
      exit 0
  fi

  if [ $CALM_PROJECT != 'none' ]; then

      project_uuid=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST --data '{"kind":"project", "filter":"name==BootcampInfra"}' 'https://localhost:9440/api/nutanix/v3/projects/list' | jq -r '.entities[].metadata.uuid')

      echo "Projet UUID = $project_uuid"

      if [ -z "$project_uuid" ]; then
          # project wasn't found
          # exit at this point as we don't want to assume all blueprints should then hit the 'default' project
          echo "Project $CALM_PROJECT was not found. Please check the name and retry."
          exit 0
      else
          echo "Project $CALM_PROJECT exists..."
      fi
  fi


# update the user with script progress...

log "Starting blueprint updates and then Uploading to Calm..."

JSONFile="${DIRECTORY}/${BLUEPRINT}"

log "Currently updating blueprint $JSONFile..."


  # NOTE: bash doesn't do in place editing so we need to use a temp file and overwrite the old file with new changes for every blueprint
  tmp=$(mktemp)

  # ADD PROJECT (affects all BPs being imported) if no project was specified on the command line, we've already pre-set the project variable to 'none' if a project was specified, we need to add it into the JSON data
  if [ $CALM_PROJECT != 'none' ]; then
      # add the new atributes to the JSON and overwrite the old JSON file with the new one
      $(jq --arg proj $CALM_PROJECT --arg proj_uuid $project_uuid '.metadata+={"project_reference":{"kind":$proj,"uuid":$proj_uuid}}' $JSONFile >"$tmp" && mv "$tmp" $JSONFile)
  fi

  # REMOVE the "status" and "product_version" keys (if they exist) from the JSON data this is included on export but is invalid on import. (affects all BPs being imported)
  tmp_removal=$(mktemp)
  $(jq 'del(.status) | del(.product_version)' $JSONFile >"$tmp_removal" && mv "$tmp_removal" $JSONFile)

  # GET BP NAME (affects all BPs being imported)
  # if this fails, it's either a corrupt/damaged/edited blueprint JSON file or not a blueprint file at all
  blueprint_name_quotes=$(jq '(.spec.name)' $JSONFile)
  blueprint_name="${blueprint_name_quotes%\"}" # remove the suffix "
  blueprint_name="${blueprint_name#\"}" # will remove the prefix "

  if [ $blueprint_name == 'null' ]; then
      echo "Unprocessable JSON file found. Is this definitely a Nutanix Calm blueprint file?"
      exit 0
  else
      # got the blueprint name means it is probably a valid blueprint file, we can now continue the upload
      echo "Uploading the updated blueprint: $blueprint_name..."

      path_to_file=$JSONFile
      bp_name=$blueprint_name
      project_uuid=$project_uuid

      upload_result=$(curl -s -k --insecure --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST -F file=@$path_to_file -F name="${bp_name}" -F project_uuid=$project_uuid "https://localhost:9440/api/nutanix/v3/blueprints/import_file")

      #if the upload_result var is not empty then let's say it was succcessful
      if [ -z "$upload_result" ]; then
          echo "Upload for $bp_name did not finish."
      else
          echo "Upload for $bp_name finished."
          echo "-----------------------------------------"
          # echo "Result: $upload_result"
      fi
  fi

log "Finished uploading ${BLUEPRINT}!"

# Getting the Blueprint UUID
log "Getting CICD Blueprint ID Now"

HTTP_JSON_BODY=$(cat <<EOF
{
  "kind":"blueprint",
  "filter": "name==Docker_MariaDB_FiestaApp_ERA"
}
EOF
)

  CICD_BLUEPRINT_UUID=$(curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST --data "${HTTP_JSON_BODY}" 'https://localhost:9440/api/nutanix/v3/blueprints/list' | jq -r '.entities[] | .metadata.uuid' | tr -d \")

log "CICD BLUEPRINT UUID: |${CICD_BLUEPRINT_UUID}|"

# Launch for the numbe of users specified

for _user in "${USERS[@]}" ; do

User_Calm_App_Nam="${_user}${Calm_App_Name}"

# Var list
log "-----------------------------------------"
log "CICD_BLUEPRINT_UUID = |${CICD_BLUEPRINT_UUID}|"
log "${CALM_PROJECT} Project UUID: |${project_uuid}|"
log "SERVER_IMAGE = |${SERVER_IMAGE}|"
log "SERVER_IMAGE_UUID = |${SERVER_IMAGE_UUID}|"
log "NETWORK_UUID = |${NETWORK_UUID}|"
log "User_Calm_App_Nam = |${User_Calm_App_Nam}|"
log "ERA_IP = |${ERA_IP}|"
log "ERA_ADMIN = |${ERA_ADMIN}|"
log "ERA_PASSWD = |${ERA_PASSWD}|"
log "initials = |${_user}|"
log "-----------------------------------------"

  DOWNLOADED_JSONFile="${BLUEPRINT}-${CICD_BLUEPRINT_UUID}.json"
  UPDATED_JSONFile="${BLUEPRINT}-${CICD_BLUEPRINT_UUID}-updated.json"

  # GET The Blueprint so it can be updated
  curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X GET -d '{}' "https://localhost:9440/api/nutanix/v3/blueprints/${CICD_BLUEPRINT_UUID}" > ${DOWNLOADED_JSONFile}

  cat $DOWNLOADED_JSONFile \
  | jq -c 'del(.status)' \
  | jq -c -r "(.spec.resources.app_profile_list[0].variable_list[0].value = \"$_user\")" \
  | jq -c -r "(.spec.resources.app_profile_list[0].variable_list[1].value = \"$ERA_IP\")" \
  | jq -c -r "(.spec.resources.app_profile_list[0].variable_list[2].value = \"$ERA_ADMIN\")" \
  | jq -c -r "(.spec.resources.app_profile_list[0].variable_list[5].value = \"$ERA_PASSWD\")" \
  | jq -c -r "(.spec.resources.substrate_definition_list[0].create_spec.resources.disk_list[0].data_source_reference.name = \"$SERVER_IMAGE\")" \
  | jq -c -r "(.spec.resources.substrate_definition_list[0].create_spec.resources.disk_list[0].data_source_reference.uuid = \"$SERVER_IMAGE_UUID\")" \
  | jq -c -r "(.spec.resources.substrate_definition_list[1].create_spec.resources.disk_list[0].data_source_reference.name = \"$SERVER_IMAGE\")" \
  | jq -c -r "(.spec.resources.substrate_definition_list[1].create_spec.resources.disk_list[0].data_source_reference.uuid = \"$SERVER_IMAGE_UUID\")" \
  | jq -c -r "(.spec.resources.substrate_definition_list[2].create_spec.resources.disk_list[0].data_source_reference.name = \"$SERVER_IMAGE\")" \
  | jq -c -r "(.spec.resources.substrate_definition_list[2].create_spec.resources.disk_list[0].data_source_reference.uuid = \"$SERVER_IMAGE_UUID\")" \
  | jq -c -r "(.spec.resources.substrate_definition_list[0].create_spec.resources.nic_list[].subnet_reference.name = \"$NETWORK_NAME\")" \
  | jq -c -r "(.spec.resources.substrate_definition_list[0].create_spec.resources.nic_list[].subnet_reference.uuid = \"$NETWORK_UUID\")" \
  | jq -c -r "(.spec.resources.substrate_definition_list[1].create_spec.resources.nic_list[].subnet_reference.name = \"$NETWORK_NAME\")" \
  | jq -c -r "(.spec.resources.substrate_definition_list[1].create_spec.resources.nic_list[].subnet_reference.uuid = \"$NETWORK_UUID\")" \
  | jq -c -r "(.spec.resources.substrate_definition_list[2].create_spec.resources.nic_list[].subnet_reference.name = \"$NETWORK_NAME\")" \
  | jq -c -r "(.spec.resources.substrate_definition_list[2].create_spec.resources.nic_list[].subnet_reference.uuid = \"$NETWORK_UUID\")" \
  | jq -c -r "(.spec.resources.credential_definition_list[].secret.value = \"$ROOT_PASSWORD\")" \
  | jq -c -r '(.spec.resources.credential_definition_list[].secret.attrs.is_secret_modified = "true")' \
  > $UPDATED_JSONFile

log "Saving Credentials Edits with PUT"

  curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X PUT -d @$UPDATED_JSONFile "https://localhost:9440/api/nutanix/v3/blueprints/${CICD_BLUEPRINT_UUID}"

log "Finished Updating Credentials"

# GET The Blueprint payload
log "getting Calm Blueprint Payload"

  curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X GET -d '{}' "https://localhost:9440/api/nutanix/v3/blueprints/${CICD_BLUEPRINT_UUID}" | jq "del(.status, .spec.name) | .spec += {"application_name": \"$User_Calm_App_Nam\", "app_profile_reference": {"uuid": .spec.resources.app_profile_list[0].uuid, "kind": "app_profile" }}" > set_blueprint_response_file.json

# Launch the BLUEPRINT
log "Launching the ${_user} Fiesta Application"

  curl ${CURL_HTTP_OPTS} --user ${PRISM_ADMIN}:${PE_PASSWORD} -X POST -d @set_blueprint_response_file.json "https://localhost:9440/api/nutanix/v3/blueprints/${CICD_BLUEPRINT_UUID}/launch"

log "Finished Launching the ${_user} Fiesta  Application"

done

set +x

}
