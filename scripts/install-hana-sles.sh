
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
INSTANCE_NUMBER="01"
MASTER_PASSWORD="Appr0ved!!!!"

# Azure Storage account details for HANA media
STORAGE_ACCOUNT_NAME="$1"  # Pass the storage account name as the first argument to the script
STORAGE_CONTAINER_NAME="hana"
MEDIA_ARCHIVE_NAME="SAP_HANA_INSTALLER.tgz"
