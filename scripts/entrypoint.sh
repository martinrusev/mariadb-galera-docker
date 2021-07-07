#!/bin/bash

# shellcheck disable=SC1091

set -o errexit
set -o nounset
set -o pipefail
# set -o xtrace # Uncomment this line for debugging purposes


# Load MariaDB environment variables
. /opt/canonical/scripts/mariadb-env.sh

print_welcome_page

if [[ "$1" = "/opt/canonical/scripts/mariadb-galera/run.sh" ]]; then
    info "** Starting MariaDB setup **"
    /opt/canonical/scripts/mariadb-galera/setup.sh
    info "** MariaDB setup finished! **"
fi

echo ""
exec "$@"
