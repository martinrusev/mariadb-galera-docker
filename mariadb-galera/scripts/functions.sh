#!/bin/bash
set -eo pipefail
shopt -s nullglob

########################
# Check if a previous boot exists
# Globals:
#   DB_*
# Arguments:
#   None
# Returns:
#   Yes or no
#########################
get_previous_boot() {
    [[ -e "$DB_GALERA_BOOTSTRAP_FILE" ]] && echo "yes" || echo "no"
}

########################
# Create a flag file to indicate previous boot
# Globals:
#   DB_*
# Arguments:
#   None
# Returns:
#   None
#########################
set_previous_boot() {
    info "Setting previous boot"
    touch "$DB_GALERA_BOOTSTRAP_FILE"
}

########################
# Validate settings in MYSQL_*/MARIADB_* environment variables
# Globals:
#   DB_*
# Arguments:
#   None
# Returns:
#   None
#########################
mysql_validate() {
    info "Validating settings in MYSQL_*/MARIADB_* env vars"
    local error_code=0

    # Auxiliary functions
    print_validation_error() {
        error "$1"
        error_code=1
    }

    empty_password_enabled_warn() {
        warn "You set the environment variable ALLOW_EMPTY_PASSWORD=${ALLOW_EMPTY_PASSWORD}. For safety reasons, do not use this flag in a production environment."
    }
    empty_password_error() {
        print_validation_error "The $1 environment variable is empty or not set. Set the environment variable ALLOW_EMPTY_PASSWORD=yes to allow the container to be started with blank passwords. This is recommended only for development."
    }
    backslash_password_error() {
        print_validation_error "The password cannot contain backslashes ('\'). Set the environment variable $1 with no backslashes (more info at https://dev.mysql.com/doc/refman/8.0/en/string-comparison-functions.html)"
    }

    if is_boolean_yes "$ALLOW_EMPTY_PASSWORD"; then
        empty_password_enabled_warn
    else
        if [[ -n "$DB_GALERA_MARIABACKUP_USER" ]] && [[ -z "$DB_GALERA_MARIABACKUP_PASSWORD" ]]; then
            empty_password_error "$(get_env_var GALERA_MARIABACKUP_PASSWORD)"
        fi

        if is_boolean_yes "$(get_galera_cluster_bootstrap_value)"; then
            if [[ -z "$DB_ROOT_PASSWORD" ]]; then
                empty_password_error "$(get_env_var ROOT_PASSWORD)"
            fi
            if (( ${#DB_ROOT_PASSWORD} > 32 )); then
                print_validation_error "The password can not be longer than 32 characters. Set the environment variable $(get_env_var ROOT_PASSWORD) with a shorter value (currently ${#DB_ROOT_PASSWORD} characters)"
            fi
            if [[ -n "$DB_USER" ]]; then
                if is_boolean_yes "$DB_ENABLE_LDAP" && [[ -n "$DB_PASSWORD" ]]; then
                    warn "You enabled LDAP authentication. '$DB_USER' user will be authentication using LDAP, the password set at the environment variable $(get_env_var PASSWORD) will be ignored"
                elif ! is_boolean_yes "$DB_ENABLE_LDAP" && [[ -z "$DB_PASSWORD" ]]; then
                    empty_password_error "$(get_env_var PASSWORD)"
                fi
            fi
        fi
    fi

    if [[ -n "$DB_GALERA_FORCE_SAFETOBOOTSTRAP" ]] && ! is_yes_no_value "$DB_GALERA_FORCE_SAFETOBOOTSTRAP"; then
        print_validation_error "The allowed values for MARDIA_GALERA_FORCE_SAFETOBOOTSTRAP are yes or no."
    fi

    if [[ -z "$DB_GALERA_CLUSTER_NAME" ]]; then
        print_validation_error "Galera cluster cannot be created without setting the environment variable $(get_env_var GALERA_CLUSTER_NAME)."
    fi

    if [[ -z "$(get_galera_cluster_address_value)" ]]; then
        print_validation_error "Galera cluster cannot be created without setting the environment variable $(get_env_var GALERA_CLUSTER_ADDRESS). If you are bootstrapping a new Galera cluster, set the environment variable $(get_env_var GALERA_CLUSTER_ADDRESS)=yes."
    fi

    if [[ "${DB_ROOT_PASSWORD:-}" = *\\* ]]; then
        backslash_password_error "$(get_env_var ROOT_PASSWORD)"
    fi
    if [[ "${DB_PASSWORD:-}" = *\\* ]]; then
        backslash_password_error "$(get_env_var PASSWORD)"
    fi

    if is_boolean_yes "$DB_ENABLE_TLS"; then
        if [[ -z "${DB_TLS_CERT_FILE}" ]] || [[ -z "${DB_TLS_KEY_FILE}" ]] || [[ -z "${DB_TLS_CA_FILE}" ]]; then
            print_validation_error "The TLS cert file, key and CA are required when TLS is enabled. Set the environment variables TLS_CERT_FILE, TLS_KEY_FILE and TLS_CA_FILE with the path to each file."
        fi
        if [[ ! -f "${DB_TLS_CERT_FILE}" ]]; then
            print_validation_error "The TLS_CERT file ${DB_TLS_CERT_FILE} must exist."
        fi
        if [[ ! -f "${DB_TLS_KEY_FILE}" ]]; then
            print_validation_error "The TLS_KEY file ${DB_TLS_KEY_FILE} must exist."
        fi
        if [[ ! -f "${DB_TLS_CA_FILE}" ]]; then
            print_validation_error "The TLS_CA file ${DB_TLS_CA_FILE} must exist."
        fi
    fi

    collation_env_var="$(get_env_var COLLATION)"
    is_empty_value "${!collation_env_var:-}" || warn "The usage of '$(get_env_var COLLATION)' is deprecated and will soon be removed. Use '$(get_env_var COLLATE)' instead."

    [[ "$error_code" -eq 0 ]] || exit "$error_code"
}

########################
# Creates MySQL/MariaDB configuration file
# Globals:
#   DB_*
# Arguments:
#   None
# Returns:
#   None
#########################
mysql_create_default_config() {
    debug "Creating main configuration file"
    cat > "$DB_CONF_FILE" <<EOF
[mysqladmin]
user=${DB_USER}

[mysqld]
skip_host_cache
skip_name_resolve
explicit_defaults_for_timestamp
basedir=${DB_BASE_DIR}
datadir=${DB_DATA_DIR}
port=${DB_DEFAULT_PORT_NUMBER}
tmpdir=${DB_TMP_DIR}
socket=${DB_SOCKET_FILE}
pid_file=${DB_PID_FILE}
max_allowed_packet=16M
bind_address=${DB_DEFAULT_BIND_ADDRESS}
log_error=${DB_LOGS_DIR}/mysqld.log
character_set_server=${DB_DEFAULT_CHARACTER_SET}
collation_server=${DB_DEFAULT_COLLATE}
plugin_dir=${DB_BASE_DIR}/plugin
binlog_format=row
log_bin=mysql-bin

[client]
port=${DB_DEFAULT_PORT_NUMBER}
socket=${DB_SOCKET_FILE}
default_character_set=UTF8
plugin_dir=${DB_BASE_DIR}/plugin

[manager]
port=${DB_DEFAULT_PORT_NUMBER}
socket=${DB_SOCKET_FILE}
pid_file=${DB_PID_FILE}

[galera]
wsrep_on=ON
wsrep_provider=${DB_BASE_DIR}/lib/libgalera_smm.so
wsrep_sst_method=mariabackup
wsrep_slave_threads=4
wsrep_cluster_address=${DB_GALERA_DEFAULT_CLUSTER_ADDRESS}
wsrep_sst_auth=${DB_GALERA_DEFAULT_MARIABACKUP_USER}:${DB_GALERA_DEFAULT_MARIABACKUP_PASSWORD}
wsrep_cluster_name=${DB_GALERA_DEFAULT_CLUSTER_NAME}
wsrep_node_name=${DB_GALERA_DEFAULT_NODE_NAME}
wsrep_node_address=${DB_GALERA_DEFAULT_NODE_ADDRESS}

[mariadb]
plugin_load_add = auth_pam

EOF
}



########################
# Ensure MySQL/MariaDB is initialized
# Globals:
#   DB_*
# Arguments:
#   None
# Returns:
#   None
#########################
mysql_initialize() {
    info "Initializing $DB_FLAVOR database"
    # This fixes an issue where the trap would kill the entrypoint.sh, if a PID was left over from a previous run
    # Exec replaces the process without creating a new one, and when the container is restarted it may have the same PID
    rm -f "$DB_PID_FILE"

    debug "Ensuring expected directories/files exist"
    for dir in "$DB_DATA_DIR" "$DB_TMP_DIR" "$DB_LOGS_DIR" "$DB_GALERA_BOOTSTRAP_DIR"; do
        ensure_dir_exists "$dir"
        am_i_root && chown "$DB_DAEMON_USER:$DB_DAEMON_GROUP" "$dir"
    done

    if is_file_writable "$DB_CONF_FILE"; then
        if ! is_mounted_dir_empty "$DB_GALERA_MOUNTED_CONF_DIR"; then
            info "Found mounted configuration directory"
            mysql_copy_mounted_config
        fi
        info "Updating 'my.cnf' with custom configuration"
        mysql_update_custom_config
        mysql_galera_update_custom_config
        mysql_galera_configure_ssl
    else
        warn "The ${DB_FLAVOR} configuration file '${DB_CONF_FILE}' is not writable or does not exist. Configurations based on environment variables will not be applied for this file."
    fi

    if [[ -f "${DB_CONF_DIR}/my_custom.cnf" ]]; then
        if is_file_writable "${DB_CONF_DIR}/bitnami/my_custom.cnf"; then
            info "Injecting custom configuration 'my_custom.cnf'"
            cat "${DB_CONF_DIR}/my_custom.cnf" > "${DB_CONF_DIR}/bitnami/my_custom.cnf"
        else
            warn "Could not inject custom configuration for the ${DB_FLAVOR} configuration file '$DB_CONF_DIR/bitnami/my_custom.cnf' because it is not writable."
        fi
    fi

    if [[ -e "$DB_DATA_DIR/mysql" ]]; then
        info "Persisted data detected. Restoring"

        if is_boolean_yes "$(get_galera_cluster_bootstrap_value)"; then
            if is_boolean_yes "$DB_GALERA_FORCE_SAFETOBOOTSTRAP"; then
                set_safe_to_bootstrap
            fi
            if ! is_safe_to_bootstrap; then
                error "It is not safe to bootstrap form this node ('safe_to_bootstrap=0' is set in 'grastate.dat'). If you want to force bootstrap, set the environment variable MARIADB_GALERA_FORCE_SAFETOBOOTSTRAP=yes"
                exit 1
            fi
        fi

        return
    else
        # initialization should not be performed on non-primary nodes of a galera cluster
        if is_boolean_yes "$(get_galera_cluster_bootstrap_value)"; then
            debug "Cleaning data directory to ensure successfully initialization"
            rm -rf "${DB_DATA_DIR:?}"/*
            mysql_install_db
            mysql_start_bg
            debug "Deleting all users to avoid issues with galera configuration"
            mysql_execute "mysql" <<EOF
DELETE FROM mysql.user WHERE user not in ('mysql.sys','mariadb.sys');
EOF

            mysql_ensure_root_user_exists "$DB_ROOT_USER" "$DB_ROOT_PASSWORD"
            mysql_ensure_user_not_exists "" # ensure unknown user does not exist
            if [[ -n "$DB_USER" ]]; then
                local -a args=("$DB_USER")
                if is_boolean_yes "$DB_ENABLE_LDAP"; then
                    args+=("--use-ldap")
                elif [[ -n "$DB_PASSWORD" ]]; then
                    args+=("-p" "$DB_PASSWORD")
                fi
                mysql_ensure_optional_user_exists "${args[@]}"
            fi
            if [[ -n "$DB_DATABASE" ]]; then
                local -a createdb_args=("$DB_DATABASE")
                [[ -n "$DB_USER" ]] && createdb_args+=("-u" "$DB_USER")
                [[ -n "$DB_CHARACTER_SET" ]] && createdb_args+=("--character-set" "$DB_CHARACTER_SET")
                [[ -n "$DB_COLLATE" ]] && createdb_args+=("--collate" "$DB_COLLATE")
                mysql_ensure_optional_database_exists "${createdb_args[@]}"
            fi
            mysql_ensure_galera_mariabackup_user_exists "$DB_GALERA_MARIABACKUP_USER" "$DB_GALERA_MARIABACKUP_PASSWORD"
            mysql_ensure_replication_user_exists "$MARIADB_REPLICATION_USER" "$MARIADB_REPLICATION_PASSWORD"

            [[ -n "$(get_master_env_var_value ROOT_PASSWORD)" ]] && export ROOT_AUTH_ENABLED="yes"
            if [[ "$DB_FLAVOR" = "mysql" ]]; then
                mysql_upgrade
            else
                local -a args=(mysql)
                args+=("$DB_ROOT_USER" "$DB_ROOT_PASSWORD")
                debug "Flushing privileges"
                mysql_execute "${args[@]}" <<EOF
flush privileges;
EOF
            fi
        fi
    fi
}


########################
# Stop MySQL/Mariadb
# Globals:
#   DB_*
# Arguments:
#   None
# Returns:
#   None
#########################
mysql_stop() {
    local -r retries=25
    local -r sleep_time=5

    are_db_files_locked() {
        local return_value=0
        read -r -a db_files <<< "$(find "$DB_DATA_DIR" -regex "^.*ibdata[0-9]+" -print0 -o -regex "^.*ib_logfile[0-9]+" -print0 | xargs -0)"
        for f in "${db_files[@]}"; do
            debug_execute lsof -w "$f" && return_value=1
        done
        return $return_value
    }

    ! is_mysql_running && return

    info "Stopping $DB_FLAVOR"
    stop_service_using_pid "$DB_PID_FILE"
    debug "Waiting for $DB_FLAVOR to unlock db files"
    if ! retry_while are_db_files_locked "$retries" "$sleep_time"; then
        error "$DB_FLAVOR failed to stop"
        return 1
    fi
}



########################
# Find the path to the libjemalloc library file
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   Path to a libjemalloc shared object file
#########################
find_jemalloc_lib() {
    local -a locations=( "/usr/lib" "/usr/lib64" )
    local -r pattern='libjemalloc.so.[0-9]'
    local path
    for dir in "${locations[@]}"; do
        # Find the first element matching the pattern and quit
        [[ ! -d "$dir" ]] && continue
        path="$(find "$dir" -name "$pattern" -print -quit)"
        [[ -n "$path" ]] && break
    done
    echo "${path:-}"
}

########################
# Execute a reliable health check against the current mysql instance
# Globals:
#   DB_ROOT_PASSWORD, DB_MASTER_ROOT_PASSWORD
# Arguments:
#   None
# Returns:
#   mysqladmin output
#########################
mysql_healthcheck() {
    local args=("-uroot" "-h0.0.0.0")
    local root_password

    root_password="$(get_master_env_var_value ROOT_PASSWORD)"
    if [[ -n "$root_password" ]]; then
        args+=("-p${root_password}")
    fi

    mysqladmin "${args[@]}" ping && mysqladmin "${args[@]}" status
}

########################
# Prints flavor of 'mysql' client (useful to determine proper CLI flags that can be used)
# Globals:
#   DB_*
# Arguments:
#   None
# Returns:
#   mysql client flavor
#########################
mysql_client_flavor() {
    if "${DB_BIN_DIR}/mysql" "--version" 2>&1 | grep -q MariaDB; then
        echo "mariadb"
    else
        echo "mysql"
    fi
}

########################
# Prints extra options for MySQL client calls (i.e. SSL options)
# Globals:
#   DB_*
# Arguments:
#   None
# Returns:
#   List of options to pass to "mysql" CLI
#########################
mysql_client_extra_opts() {
    # Helper to get the proper value for the MySQL client environment variable
    mysql_client_env_value() {
        local env_name="MYSQL_CLIENT_${1:?missing name}"
        if [[ -n "${!env_name:-}" ]]; then
            echo "${!env_name:-}"
        else
            env_name="DB_CLIENT_${1}"
            echo "${!env_name:-}"
        fi
    }
    local -a opts=()
    local key value
    if is_boolean_yes "${DB_ENABLE_SSL:-no}"; then
        if [[ "$(mysql_client_flavor)" = "mysql" ]]; then
            opts+=("--ssl-mode=REQUIRED")
        else
            opts+=("--ssl=TRUE")
        fi
        # Add "--ssl-ca", "--ssl-key" and "--ssl-cert" options if the env vars are defined
        for key in ca key cert; do
            value="$(mysql_client_env_value "SSL_${key^^}_FILE")"
            [[ -n "${value}" ]] && opts+=("--ssl-${key}=${value}")
        done
    fi
    echo "${opts[@]:-}"
}

########################
# Configure database extra start flags
# Globals:
#   DB_*
# Arguments:
#   None
# Returns:
#   Array with extra flags to use
#########################
mysql_extra_flags() {
    local -a dbExtraFlags=()
    read -r -a userExtraFlags <<< "$DB_EXTRA_FLAGS"

    # This avoids a non-writable configuration file break a Galera Cluster, due to lack of proper Galera clustering configuration
    # This is especially important for the MariaDB Galera chart, in which the 'my.cnf' configuration file is mounted by default
    if ! is_file_writable "$DB_CONF_FILE"; then
        dbExtraFlags+=(
            "--wsrep-node-name=$(get_node_name)"
            "--wsrep-node-address=$(get_node_address)"
            "--wsrep-cluster-name=${DB_GALERA_CLUSTER_NAME}"
            "--wsrep-cluster-address=$(get_galera_cluster_address_value)"
            "--wsrep-sst-method=${DB_GALERA_SST_METHOD}"
            "--wsrep-sst-auth=${DB_GALERA_MARIABACKUP_USER}:${DB_GALERA_MARIABACKUP_PASSWORD}"
        )
    fi

    [[ ${#userExtraFlags[@]} -eq 0 ]] || dbExtraFlags+=("${userExtraFlags[@]}")

    echo "${dbExtraFlags[@]}"
}

########################
# Check for user override of wsrep_node_name
# Globals:
#   DB_*
# Arguments:
#   None
# Returns:
#   String with node name
#########################
get_node_name() {
    if [[ -n "$DB_GALERA_NODE_NAME" ]]; then
        echo "$DB_GALERA_NODE_NAME"
    else
        # In some environments, the network may not be fully set up when starting the initialization
        # So, to avoid issues, we retry the 'hostname' command until it succeeds (for a few minutes)
        local -r retries="60"
        local -r seconds="5"
        retry_while "hostname" "$retries" "$seconds" >/dev/null
        hostname
    fi
}

########################
# Check for user override of wsrep_node_address
# Globals:
#   DB_*
# Arguments:
#   None
# Returns:
#   String with node address
#########################
get_node_address() {
    if [[ -n "$DB_GALERA_NODE_ADDRESS" ]]; then
        echo "$DB_GALERA_NODE_ADDRESS"
    else
        # In some environments, the network may not be fully set up when starting the initialization
        # So, to avoid issues, we retry the 'hostname' command until it succeeds (for a few minutes)
        local -r retries="60"
        local -r seconds="5"
        retry_while "hostname -i" "$retries" "$seconds" >/dev/null
        hostname -i
    fi
}

########################
# Build Galera cluster address string from the bootstrap string
# Globals:
#   DB_*
# Arguments:
#   None
# Returns:
#   None
#########################
get_galera_cluster_address_value() {
    local clusterAddress
    if ! is_boolean_yes "$(get_galera_cluster_bootstrap_value)" && is_boolean_yes "$(has_galera_cluster_other_nodes)"; then
        clusterAddress="$DB_GALERA_CLUSTER_ADDRESS"
    else
        clusterAddress="gcomm://"
    fi
    debug "Set Galera cluster address to ${clusterAddress}"
    echo "$clusterAddress"
}

########################
# Whether the Galera node will perform bootstrapping of a new cluster, or join an existing one
# Globals:
#   DB_*
# Arguments:
#   None
# Returns:
#   None
#########################
get_galera_cluster_bootstrap_value() {
    local clusterBootstrap
    local local_ip
    local host_ip

    # This block evaluate if the cluster needs to be boostraped or not.
    # When the node is marked to bootstrap:
    # - We want to have bootstrap enabled when executing up to "run.sh" (included), for the first time.
    #   To do this, we check if the node has already been initialized before with "get_previous_boot".
    # - For the second "setup.sh" and "run.sh" calls, it will automatically detect the cluster was already bootstrapped, so it disables it.
    #   That way, the node will join the existing Galera cluster instead of bootstrapping a new one.
    #   We disable the bootstrap right after processing environment variables in "run.sh" with "set_previous_boot".
    # - Users can force a bootstrap to happen again on a node, by setting the environment variable "MARIADB_GALERA_FORCE_SAFETOBOOTSTRAP".
    # When the node is not marked to bootstrap, the node will join an existing cluster.
    if is_boolean_yes "$DB_GALERA_FORCE_SAFETOBOOTSTRAP"; then
        clusterBootstrap="yes"
    elif is_boolean_yes "$DB_GALERA_CLUSTER_BOOTSTRAP"; then
        clusterBootstrap="yes"
    elif is_boolean_yes "$(get_previous_boot)"; then
        clusterBootstrap="no"
    elif ! is_boolean_yes "$(has_galera_cluster_other_nodes)"; then
        clusterBootstrap="yes"
    else
        clusterBootstrap="no"
    fi
    echo "$clusterBootstrap"
}
