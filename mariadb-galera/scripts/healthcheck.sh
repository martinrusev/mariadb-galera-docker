#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail
# set -o xtrace # Uncomment this line for debugging purposes

# Load MariaDB scripts
. /opt/canonical/mariadb-galera/scripts/helpers.sh
. /opt/canonical/mariadb-galera/scripts/functions.sh


# Load MariaDB environment variables
. /opt/canonical/mariadb-galera/scripts/env.sh

mysql_healthcheck
