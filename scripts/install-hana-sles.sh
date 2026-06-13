###############################################################################
# SAP HANA single-node install on SLES for SAP
#  - SID: BMK
#  - Instance: 00
#  - Passwords: Appr0ved!!!!
###############################################################################
set -euo pipefail

LOGFILE="/var/log/install-hana-sles.log"
exec > >(tee -a "${LOGFILE}") 2>&1

echo "=== $(date) | SAP HANA SLES Prep Script Starting ==="

###############################################################################
# CONFIGURATION (EDIT THESE)
###############################################################################
SID="BMK"
INSTANCE_NUMBER="00"
MASTER_PASSWORD="Appr0ved!!!!"

# Azure Storage account details for HANA media
STORAGE_ACCOUNT_NAME="$1"  # Pass the storage account name as the first argument to the script
STORAGE_CONTAINER_NAME="hana"
MEDIA_ARCHIVE_NAME="SAP_HANA_INSTALLER.tgz"
# Optional SAS token (without leading '?'), or leave empty if public
STORAGE_SAS_TOKEN=""

MEDIA_DOWNLOAD_DIR="/sapmedia"
MEDIA_URL_BASE="https://${STORAGE_ACCOUNT_NAME}.blob.core.windows.net/${STORAGE_CONTAINER_NAME}"
if [[ -n "${STORAGE_SAS_TOKEN}" ]]; then
  MEDIA_URL="${MEDIA_URL_BASE}/${MEDIA_ARCHIVE_NAME}?${STORAGE_SAS_TOKEN}"
else
  MEDIA_URL="${MEDIA_URL_BASE}/${MEDIA_ARCHIVE_NAME}"
fi

# Expected HANA DB directory after extraction
HANA_DB_DIR="${MEDIA_DOWNLOAD_DIR}/SAP_HANA_DATABASE"

# Azure disk device paths (match Bicep LUNs 0–3)
DISK_DATA="/dev/disk/azure/scsi1/lun0"
DISK_LOG="/dev/disk/azure/scsi1/lun1"
DISK_SHARED="/dev/disk/azure/scsi1/lun2"
DISK_USR_SAP="/dev/disk/azure/scsi1/lun3"

MNT_DATA="/hana/data"
MNT_LOG="/hana/log"
MNT_SHARED="/hana/shared"
MNT_USR_SAP="/usr/sap"

###############################################################################
# HELPER FUNCTIONS
###############################################################################
fail() {
  echo "ERROR: $*" >&2
  exit 1
}

ensure_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    fail "This script must be run as root."
  fi
}

ensure_device() {
  local dev="$1"
  if [[ ! -b "${dev}" ]]; then
    fail "Block device ${dev} not found."
  fi
}

ensure_dir() {
  local dir="$1"
  if [[ ! -d "${dir}" ]]; then
    mkdir -p "${dir}"
  fi
}

is_mounted() {
  local dir="$1"
  mountpoint -q "${dir}"
}

add_fstab_entry() {
  local dev="$1"
  local mnt="$2"
  local fs="$3"
  local opts="$4"

  if ! grep -q "${dev} ${mnt} " /etc/fstab; then
    echo "${dev} ${mnt} ${fs} ${opts} 0 0" >> /etc/fstab
  fi
}

###############################################################################
# 1. Pre-checks
###############################################################################
ensure_root

echo "Hostname: $(hostname -f)"
echo "Using SID=${SID}, INSTANCE_NUMBER=${INSTANCE_NUMBER}"

###############################################################################
# 2. Install required OS packages
###############################################################################
echo "Installing SLES for SAP required packages..."

zypper refresh
zypper install -y \
  saptune \
  saptune-patterns \
  uuidd \
  net-tools \
  glibc-locale \
  unrar \
  tcsh \
  libaio1 \
  numactl \
  libicu \
  which

systemctl enable uuidd
systemctl start uuidd

###############################################################################
# 3. Apply SAP Notes via saptune
###############################################################################
echo "Applying SAP HANA saptune profile..."

saptune solution apply HANA || echo "saptune solution apply HANA returned non-zero, continuing..."
saptune daemon start || echo "saptune daemon start returned non-zero, continuing..."

###############################################################################
# 4. Prepare mount points and disks
###############################################################################
echo "Preparing disks and mount points..."

ensure_device "${DISK_DATA}"
ensure_device "${DISK_LOG}"
ensure_device "${DISK_SHARED}"
ensure_device "${DISK_USR_SAP}"

ensure_dir "${MNT_DATA}"
ensure_dir "${MNT_LOG}"
ensure_dir "${MNT_SHARED}"
ensure_dir "${MNT_USR_SAP}"

# Format only if no filesystem exists
for dev in "${DISK_DATA}" "${DISK_LOG}" "${DISK_SHARED}" "${DISK_USR_SAP}"; do
  if ! blkid "${dev}" >/dev/null 2>&1; then
    echo "Creating XFS filesystem on ${dev}..."
    mkfs.xfs "${dev}"
  else
    echo "Filesystem already present on ${dev}, skipping mkfs."
  fi
done

add_fstab_entry "${DISK_DATA}"   "${MNT_DATA}"    "xfs" "defaults"
add_fstab_entry "${DISK_LOG}"    "${MNT_LOG}"     "xfs" "defaults"
add_fstab_entry "${DISK_SHARED}" "${MNT_SHARED}"  "xfs" "defaults"
add_fstab_entry "${DISK_USR_SAP}" "${MNT_USR_SAP}" "xfs" "defaults"

mount -a

for dir in "${MNT_DATA}" "${MNT_LOG}" "${MNT_SHARED}" "${MNT_USR_SAP}"; do
  if ! is_mounted "${dir}"; then
    fail "Mount failed for ${dir}"
  fi
done

echo "Disks mounted successfully."

###############################################################################
# 5. Kernel tuning (additional to saptune)
###############################################################################
echo "Applying kernel tuning..."

SYSCTL_CONF="/etc/sysctl.d/99-sap-hana.conf"
cat > "${SYSCTL_CONF}" <<EOF
vm.swappiness = 10
kernel.shmmax = 68719476736
kernel.shmall = 4294967296
EOF

sysctl --system

###############################################################################
# 6. Download and extract SAP HANA media
###############################################################################
echo "Preparing SAP HANA media in ${MEDIA_DOWNLOAD_DIR}..."

ensure_dir "${MEDIA_DOWNLOAD_DIR}"
cd "${MEDIA_DOWNLOAD_DIR}"

if [[ ! -f "${MEDIA_ARCHIVE_NAME}" ]]; then
  echo "Downloading HANA media from ${MEDIA_URL}..."
  curl -fSL -o "${MEDIA_ARCHIVE_NAME}" "${MEDIA_URL}" || fail "Failed to download HANA media."
else
  echo "Media archive ${MEDIA_ARCHIVE_NAME} already exists, skipping download."
fi

if [[ ! -d "${HANA_DB_DIR}" ]]; then
  echo "Extracting HANA media..."
  tar -xvf "${MEDIA_ARCHIVE_NAME}"
else
  echo "HANA media directory ${HANA_DB_DIR} already exists, skipping extraction."
fi

[[ -x "${HANA_DB_DIR}/hdblcm" ]] || fail "hdblcm not found in ${HANA_DB_DIR}"

###############################################################################
# 7. Run SAP HANA Lifecycle Manager (hdblcm)
###############################################################################
echo "Running SAP HANA installer (hdblcm)..."

HOST_FQDN="$(hostname -f)"

"${HANA_DB_DIR}/hdblcm" \
  --action=install \
  --sid="${SID}" \
  --number="${INSTANCE_NUMBER}" \
  --components=server \
  --system_user_password="${MASTER_PASSWORD}" \
  --sapadm_password="${MASTER_PASSWORD}" \
  --hostname="${HOST_FQDN}" \
  --read_password_from_stdin=off \
  --batch

echo "=== $(date) | SAP HANA Installation Completed Successfully ==="
exit 0
