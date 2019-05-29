#!/bin/bash
# Script to create snapshot of Nova Instance (to glance)
# Place the computerc file in the same directory as this script

# To restore to a new server:
# openstack server create --image "SNAPSHOT_NAME" --flavor "Standard 1" --availability-zone NL1 --nic net-id=00000000-0000-0000-0000-000000000000 --key "SSH_KEY" "VM_NAME"
# To restore to this server (keep public IP)
# openstack server rebuild --image "SNAPSHOT_IMAGE_UUID" "INSTANCE_UUID"

# OpenStack Command Line tools required:
# apt-get install python-openstackclient
# yum install python2-openstackclient

# mail nofitications :
# apt-get install libnet-ssleay-perl swaks
# yum install swaks

# Get the script path
SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

# dry-run
DRY_RUN="${3}"

# First we check if all the commands we need are installed.
command_exists() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "I require $1 but it's not installed. Aborting."
    exit 1
  fi
}

for COMMAND in "openstack" "tr" "swaks"; do
  command_exists "${COMMAND}"
done

# Check if the computerc file exists. If so, assume it has the credentials.
if [[ ! -f "${SCRIPTPATH}/.openstack_snapshotrc" ]]; then
  echo "${SCRIPTPATH}/.openstack_snapshotrc file required."
  exit 1
else
  source "${SCRIPTPATH}/.openstack_snapshotrc"
fi

# Export the emails from & to
EMAIL_FROM="$LOG_EMAIL_FROM"
EMAIL_TO="$LOG_EMAIL_TO"
SMTP_HOST="$LOG_SMTP_HOST"
SMTP_PORT="$LOG_SMTP_PORT"
SMTP_TLS="$LOG_SMTP_TLS"
SMTP_AUTH_TYPE="$LOG_SMTP_AUTH_TYPE"
SMTP_AUTH_USER="$LOG_SMTP_AUTH_USER"
SMTP_AUTH_PWD="$LOG_SMTP_AUTH_PWD"

# backup_type
BACKUP_TYPE="${1}"
if [[ -z "${BACKUP_TYPE}" ]]; then
  BACKUP_TYPE="manual"
fi

# rotation of snapshots
ROTATION="${2}"

launch_instances_backups () {
  if output=$(openstack server list | awk -F'|' '/\|/ && !/ID/{system("echo "$2"__"$3"")}'); then
    set -- "$output"
    IFS=$'\n'; declare -a arrOutput=($*)

    for instance in "${arrOutput[@]}"; do
      set -- "$instance"
      IFS=__; declare arrInstance=($*)

      # instance UUID
      INSTANCE_UUID="${arrInstance[0]:0:${#arrInstance[0]}-1}"

      # instance name
      INSTANCE_NAME="${arrInstance[2]:1:${#arrInstance[2]}-1}"

      # snapshot names will sort by date, instance_name and UUID.
      SNAPSHOT_NAME="snapshot-$(date "+%Y%m%d%H%M")-${BACKUP_TYPE}-${INSTANCE_NAME}"

      echo "INFO: Start OpenStack snapshot creation : ${INSTANCE_NAME}"

      if [ "$DRY_RUN" = "--dry-run" ] ; then
        echo "DRY-RUN is enabled. In real a backup of the instance called ${SNAPSHOT_NAME} would've been done like that :
        openstack server backup create --name ${SNAPSHOT_NAME} --type ${BACKUP_TYPE} --rotate ${ROTATION} ${INSTANCE_UUID}"
      else
        if ! openstack server backup create --name "${SNAPSHOT_NAME}" --type "${BACKUP_TYPE}" --rotate "${ROTATION}" "${INSTANCE_UUID}" 2> tmp_error.log; then
          cat tmp_error.log >> nova_errors.log
        else
          echo "SUCCESS: Backup image created and pending upload."
        fi
      fi
    done

  else
    echo "NO INSTANCE FOUND"
  fi
}

launch_volumes_backups () {
  if output=$(openstack volume list | awk -F'|' '/\|/ && !/ID/{system("echo "$2"__"$3"")}'); then
    set -- "$output"
    IFS=$'\n'; declare -a arrOutput=($*)

    for volume in "${arrOutput[@]}"; do
      set -- "$volume"
      IFS=__; declare arrVolume=($*)

      # Get the volume UUID
      VOLUME_UUID="${arrVolume[0]:0:${#arrVolume[0]}-1}"

      # Get the volume name
      VOLUME_NAME="${arrVolume[2]:1:${#arrVolume[2]}-1}"

      # snapshot names will sort by date, instance_name and UUID.
      SNAPSHOT_NAME="snapshot-$(date "+%Y%m%d%H%M")-${BACKUP_TYPE}-${VOLUME_NAME}"

      echo "INFO: Start OpenStack snapshot creation : ${VOLUME_NAME}"
      if [ "$DRY_RUN" = "--dry-run" ] ; then
        #echo "DRY-RUN is enabled. In real a backup of the volume called ${SNAPSHOT_NAME} would've been done like that :
        #openstack volume backup create --name ${SNAPSHOT_NAME} --description ${VOLUME_NAME} ${VOLUME_UUID} --force"
	echo "DRY-RUN is enabled. In real a backup of the volume called ${SNAPSHOT_NAME} would've been done like that :
	openstack snapshot create --name ${SNAPSHOT_NAME} --description ${VOLUME_NAME} ${VOLUME_UUID} --force"
      else
        #openstack volume backup create --name "${SNAPSHOT_NAME}" --description "${VOLUME_NAME}" "${VOLUME_UUID}" --force 2> tmp_error.log
        if ! openstack snapshot create --name "${SNAPSHOT_NAME}" --description "${VOLUME_NAME}" "${VOLUME_UUID}" --force 2> tmp_error.log; then
          cat tmp_error.log >> nova_errors.log
        else
          echo "SUCCESS: Backup volume created and pending upload."
        fi
      fi

    done
  else
    echo "NO VOLUME FOUND"
  fi
}

send_errors_if_there_are () {
  if [ -f nova_errors.log ]; then
    swaks -s "Snapshot errors" --from "$EMAIL_FROM" --to "$EMAIL_TO" --server "$SMTP_HOST" --port "$SMTP_PORT" "$SMTP_TLS" --auth "$SMTP_AUTH_TYPE" --auth-user "$SMTP_AUTH_USER" --auth-password "$SMTP_AUTH_PWD" --body nova_errors.log >/dev/null
  fi
}

if [ -f nova_errors.log ]; then
  rm -f nova_errors.log
fi
launch_instances_backups
launch_volumes_backups
send_errors_if_there_are
"${SCRIPTPATH}"/count_volume_snapshots.sh "$ROTATION"
