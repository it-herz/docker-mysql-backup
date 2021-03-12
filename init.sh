#!/bin/bash
set -e

#
# Retreive and check mode, which can either be "BACKUP" or "RESTORE".
# Based on the mode, different default options will be set.
#

MODE=${MODE:-BACKUP}
 
case "${MODE^^}" in
    'BACKUP')
        OPTIONS=${OPTIONS:--c}
        ;;
    'RESTORE')
        OPTIONS=${OPTIONS:--o}
        ;;
    *)
        echo 'ERROR: Please set MODE environment variable to "BACKUP" or "RESTORE"' >&2
        exit 255
esac

#
# Retreive backup settings and set some defaults.
# Then display the settings on standard out.
#

USER="mybackup"

echo "${MODE} SETTINGS"
echo "================"
echo
echo "  User:               ${USER}"
echo "  UID:                ${BACKUP_UID:=666}"
echo "  GID:                ${BACKUP_GID:=666}"
echo "  Umask:              ${UMASK:=0022}"
echo
echo "  Base directory: i   ${BASE_DIR:=/backup}"
[[ "${MODE^^}" == "RESTORE" ]] && \
echo "  Restore directory:  ${RESTORE_DIR}"
echo
echo "  Options:            ${OPTIONS}"
echo

#
# Detect linked container settings based on Docker's environment variables.
# Display the container informations on standard out.
#

echo "DATABASE SETTINGS"
echo "=================="
echo
echo
echo "  Address:   ${DB_ADDR}"
echo "  Port:      ${DB_PORT:=3306}"
echo
echo "  User:      ${DB_USER:=root}"
echo "  Database:  ${DB_NAME:=mysql}"
echo

#
# Change UID / GID of backup user and settings umask.
#

[[ $(id -u ${USER}) == $BACKUP_UID ]] || usermod  -o -u $BACKUP_UID ${USER}
[[ $(id -g ${USER}) == $BACKUP_GID ]] || groupmod -o -g $BACKUP_GID ${USER}

umask ${UMASK}

#
# Building common CLI options to use for mydumper and myloader.
#

CLI_OPTIONS="-v 3 -h ${DB_ADDR} -P ${DB_PORT:=3306} -u ${DB_USER:=/root} -p ${DB_PASS} -B ${DB_NAME:=mysql} ${OPTIONS}"

#
# When MODE is set to "BACKUP", then mydumper has to be used to backup the database.
#

echo "${MODE^^}"
echo "======="
echo

if [[ "${MODE^^}" == "BACKUP" ]]
then

    printf "===> Creating base directory... "
    mkdir -p ${BASE_DIR}
    echo "DONE"

    printf "===> Changing owner of base directory... "
    chown ${USER}: ${BASE_DIR}
    echo "DONE"

    printf "===> Changing into base directory... "
    cd ${BASE_DIR}
    echo "DONE"

    echo "===> Starting backup..."
    exec su -pc "mydumper ${CLI_OPTIONS}" ${USER}

#
# When MODE is set to "RESTORE", then myloader has to be used to restore the database.
#

elif [[ "${MODE^^}" == "RESTORE" ]]
then

    printf "===> Changing into base directory... "
    cd ${BASE_DIR}
    echo "DONE"

    if [[ -z "${RESTORE_DIR}" ]]
    then
        printf "===> No RESTORE_DIR set, trying to find latest backup... "
        RESTORE_DIR=$(ls -t | head -1)
        if [[ -n "${RESTORE_DIR}" ]]
        then
            echo "DONE"
        else
            echo "FAILED"
            echo "ERROR: Auto detection of latest backup directory failed!" >&2
            exit 1
        fi
    fi

    echo "===> Restoring database from ${RESTORE_DIR}..."
    exec su -pc "myloader --directory=${RESTORE_DIR} ${CLI_OPTIONS}" ${USER}

fi
