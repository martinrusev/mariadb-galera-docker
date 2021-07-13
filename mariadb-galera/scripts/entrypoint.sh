#!/bin/bash

# shellcheck disable=SC1091

set -o errexit
set -o nounset
set -o pipefail
# set -o xtrace # Uncomment this line for debugging purposes


# Load MariaDB environment variables
. /opt/canonical/mariadb-galera/scripts/env.sh


if [[ "$1" = "/opt/canonical/mariadb-galera/scripts/run.sh" ]]; then
    info "** Starting MariaDB setup **"
    /opt/canonical/mariadb-galera/scripts/setup.sh
    info "** MariaDB setup finished! **"
fi

echo ""
exec "$@"
