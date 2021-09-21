#!/bin/bash
########
# Prepare the Azure Linux VM for RKE2 installation
# Extend the partition of the OS disk
# Format and mount data disk
########
set -eu

function info() {
  echo "[INFO] [$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*"
}

########
# Resize the OS partition. Azure only partitions 64GB of the attached OS disk
# extend the second partition of the /dev/sdX disk to 100%
# allocate more disk space to the /tmp and /var logical volumes after the resize
########
function resize_part() {
  local ROOT_DEV
  local PARTITION_NO # partition to resize, defaults to 2
  PARTITION_NO="2"
  ROOT_DEV="/dev/$(tree /dev/disk/azure | grep -w "\sroot\s" | awk -F/ '{print $NF}')"
  info "Resizing partition ${PARTITION_NO} of disk ${ROOT_DEV}"
  # Fix GPT table non-interactively.
  # Going around the bug described here: https://lists.gnu.org/archive/html/bug-parted/2020-01/msg00005.html
  echo "Fix" | parted ---pretend-input-tty "${ROOT_DEV}" print
  parted "${ROOT_DEV}" --script resizepart "${PARTITION_NO}" 100%
  pvresize "${ROOT_DEV}${PARTITION_NO}"

  #get FS for /var and extend
  local VAR_FS
  VAR_FS=$(df | grep -w "\s/var$" | awk '{print $1}')
  info "/var is the mount point of ${VAR_FS}"
  lvextend "${VAR_FS}" -L +500G
  xfs_growfs /var

  #get FS for /tmp and extend
  local TMP_FS
  TMP_FS=$(df | grep -w "\s/tmp$" | awk '{print $1}')
  info "/tmp is the mount point of ${VAR_FS}"
  lvextend "${TMP_FS}" -L +20G
  xfs_growfs /tmp

  #get FS for / and extend
  local ROOT_FS
  ROOT_FS=$(df | grep -w "\s/$" | awk '{print $1}')
  info "/ is the mount point of ${ROOT_FS}"
  lvextend "${ROOT_FS}" -L +100G
  xfs_growfs /

  #get FS for /usr and extend
  local USR_FS
  USR_FS=$(df | grep -w "\s/usr$" | awk '{print $1}')
  info "/usr is the mount point of ${USR_FS}"
  lvextend "${USR_FS}" -L +15G
  xfs_growfs /usr

  #get FS for /home and extend
  local HOME_FS
  HOME_FS=$(df | grep -w "\s/home$" | awk '{print $1}')
  info "/home is the mount point of ${HOME_FS}"
  lvextend "${HOME_FS}" -L +15G
  xfs_growfs /home
}

########
# Format and mount data disk
########
function mount_data_disk() {
  local DATA_DISK_DEV
  local UUID
  local DATADISK_MOUNT="/datadisk"
  DATA_DISK_DEV="/dev/$(tree /dev/disk/azure | grep -w "\slun1\s" | awk -F/ '{print $NF}')"
  info "Partitioning ${DATA_DISK_DEV}, creating partition \"data\" with 100%"
  parted "${DATA_DISK_DEV}" --script mklabel gpt mkpart "data" ext4 0% 100%
  # the new partition is not ready for format immediately
  # shellcheck disable=SC2143
  while [[ ! "$(blkid -o device | grep -e "^${DATA_DISK_DEV}1$")" ]]; do
    info "Waiting for ${DATA_DISK_DEV}1 to be available"
    sleep 5;
  done
  info "Creating ext4 FS for ${DATA_DISK_DEV}1"
  mkfs.ext4 "${DATA_DISK_DEV}1"
  partprobe "${DATA_DISK_DEV}1"

  mkdir "${DATADISK_MOUNT}"
  mount "${DATA_DISK_DEV}1" "${DATADISK_MOUNT}"
  UUID=$(blkid -o value -s UUID "${DATA_DISK_DEV}1")
  grep -q "${DATADISK_MOUNT}" /etc/fstab || 
  printf "# data-disk\nUUID=%s    %s    ext4    defaults    0    0\n" "${UUID}" "${DATADISK_MOUNT}" >> /etc/fstab
}

function scrape_sys_metrics() {
  #https://serverfault.com/questions/686860/add-cronjob-with-bash-script-no-crontab-for-root
  set +e
  crontab -l > monitoringcron
  echo "*/1 * * * * /usr/lib64/sa/sa1 1 1" >> monitoringcron
  crontab monitoringcron
  rm monitoringcron
  set -e
}

function do_install() {
  info "installing"
  resize_part
  mount_data_disk
  scrape_sys_metrics
}

dnf -y install jq
do_install
exit 0