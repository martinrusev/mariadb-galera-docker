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

/opt/canonical/mariadb-galera/scripts/setup.sh

# mysqld_safe does not allow logging to stdout/stderr, so we stick with mysqld
EXEC="/usr/sbin/mysqld"

flags=("--defaults-file=${DB_CONF_DIR}/my.cnf" "--basedir=${DB_BASE_DIR}" "--datadir=${DB_DATA_DIR}" "--socket=${DB_SOCKET_FILE}")
[[ -z "${DB_PID_FILE:-}" ]] || flags+=("--pid-file=${DB_PID_FILE}")

# Add flags specified via the 'DB_EXTRA_FLAGS' environment variable
read -r -a db_extra_flags <<< "$(mysql_extra_flags)"
[[ "${#db_extra_flags[@]}" -gt 0 ]] && flags+=("${db_extra_flags[@]}")

# Add flags passed to this script
flags+=("$@")

# Fix for MDEV-16183 - mysqld_safe already does this, but we are using mysqld
LD_PRELOAD="$(find_jemalloc_lib)${LD_PRELOAD:+ "$LD_PRELOAD"}"
export LD_PRELOAD

info "** Starting MariaDB **"

set_previous_boot

# TODO - Only for debugging purposes
cat /opt/canonical/mariadb-galera/mariadb/conf/my.cnf

info "$EXEC" "${flags[@]}"
exec "$EXEC" "${flags[@]}"
