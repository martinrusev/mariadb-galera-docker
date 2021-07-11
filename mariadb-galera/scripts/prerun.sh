#!/bin/bash

# shellcheck disable=SC1091

set -o errexit
set -o nounset
set -o pipefail
# set -o xtrace # Uncomment this line for debugging purposes

# Load MariaDB scripts
. /opt/canonical/mariadb-galera/scripts/helpers.sh
. /opt/canonical/mariadb-galera/scripts/functions.sh

# Load MariaDB environment variables
. /opt/canonical/mariadb-galera/scripts/env.sh


# Configure MariaDB options based on build-time defaults
info "Configuring default MariaDB options"
ensure_dir_exists "$DB_CONF_DIR"
mysql_create_default_config

for dir in "$DB_TMP_DIR" "$DB_LOGS_DIR" "$DB_CONF_DIR" "${DB_CONF_DIR}/bitnami" "$DB_VOLUME_DIR" "$DB_DATA_DIR" "$DB_GALERA_BOOTSTRAP_DIR"; do
    ensure_dir_exists "$dir"
    chmod -R g+rwX "$dir"
done

# Redirect all logging to stdout
ln -sf /dev/stdout "$DB_LOGS_DIR/mysqld.log"
