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


# Ensure mysql unix socket file does not exist
rm -rf "${DB_SOCKET_FILE}.lock"
# Ensure MariaDB environment variables settings are valid
mysql_validate
# Ensure MariaDB is stopped when this script ends.
trap "mysql_stop" EXIT

# Ensure MariaDB is initialized
mysql_initialize


# Stop MariaDB before flagging it as fully initialized.
# Relying only on the trap defined above could produce a race condition.
mysql_stop
