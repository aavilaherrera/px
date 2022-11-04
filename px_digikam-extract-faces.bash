#!/usr/bin/env bash


#
# Connecting to Digikam's database requires a few parameters be set.  These
# will vary depending on whether Digikam's bundled sqlite3, internal MariaDB
# database or an external MariaDB database is used.
#
# *Note: `ApplicationSupport` is a symlink to `Application Support`.
# `mysqld_safe` does not properly handle spaces in filenames.*
#
_PX_MYSQL=${_PX_MYSQL:-/Applications/digiKam.org/digikam.app/Contents/lib/mariadb/bin/mysql}
_PX_MYSQLD_SAFE=${_PX_MYSQLD_SAFE:-/Applications/digiKam.org/digikam.app/Contents/lib/mariadb/bin/mysqld_safe}
_PX_MYSQLADMIN=${_PX_MYSQLADMIN:-/Applications/digiKam.org/digikam.app/Contents/lib/mariadb/bin/mysqladmin}
_PX_MYSQL_DEFAULTS=${_PX_MYSQL_DEFAULTS:-${HOME}/Library/ApplicationSupport/digikam/digikam/mysql.conf}
_PX_MYSQL_DATADIR=${_PX_MYSQL_DATADIR:-${HOME}/.digikam/.mysql.digikam/db_data}
_PX_MYSQL_SOCKET=${_PX_MYSQL_SOCKET:-${HOME}/Library/ApplicationSupport/digikam/digikam/db_misc/mysql.socket}
_PX_MYSQLD_PIDFILE=${_PX_MYSQLD_PIDFILE:-./.px.digikam.mysql.pid}


__extract_face_regions_mysql(){
    local __timeout=${__timeout:-900} __slept=0 __db_started=false __db_isup=false
    local __sql='
        USE digikam;
        SELECT CONCAT(ar.specificpath, a.relativepath, '"'/'"', i.name) as path, t.name as tagname, value as region
        FROM AlbumRoots ar
            INNER JOIN Albums a
            INNER JOIN Images i
            INNER JOIN Tags t
            INNER JOIN ImageTagProperties itp
            ON a.id = i.album
            AND t.id = itp.tagid
            AND i.id = itp.imageid
            AND ar.id = a.albumroot
        ;
    '

    # check if db is up
    if [ -f "$_PX_MYSQLD_PIDFILE" ] || [ -f "$_PX_MYSQL_SOCKET" ]; then
        if "$_PX_MYSQL" --defaults-file="$_PX_MYSQL_DEFAULTS" --socket="$_PX_MYSQL_SOCKET" <<<"USE digikam;" > /dev/null 2>&1; then
            __db_isup=true
        fi
    fi

    if [ "$__db_isup" = false ]; then
        _message "Database is down, starting database"
        __db_started=true
        "$_PX_MYSQLD_SAFE" \
            --defaults-file="$_PX_MYSQL_DEFAULTS" \
            --datadir="$_PX_MYSQL_DATADIR" \
            --socket="$_PX_MYSQL_SOCKET" \
            --pid-file="$_PX_MYSQLD_PIDFILE" \
            &
        local __mysqld_pid=$!

        _message "Waiting for $(basename "$_PX_MYSQLD_SAFE") [pid: $__mysqld_pid]" >&2
        until [ -f "$_PX_MYSQLD_PIDFILE" ] || [ ${__slept} -ge ${__timeout} ]; do
            sleep 1
            __slept=$(($__slept + 1))
            printf "." >&2
        done
        _message "" "Waited $__slept seconds"
    fi

    # execute query
    "$_PX_MYSQL" --defaults-file="$_PX_MYSQL_DEFAULTS" --socket="$_PX_MYSQL_SOCKET" <<<"$__sql"

    if [ "$__db_started" = true ]; then
        # shutdown db server nicely
        "$_PX_MYSQLADMIN" --socket="$_PX_MYSQL_SOCKET" shutdown
        wait $__mysqld_pid
    fi
}

__crop_faces_from_regions(){
    # read from stdin, each line is:
    #
    #   IMAGE_PATH\tFACE_NAME\tSVG_RECT
    #
    # where SVG_RECT is something like:
    #
    #   '<rect x="1077" y="565" width="347" height="449"/>'
    #
    # and execute ImageMagick crop commands

    local __re='([^\t]+)\t([^\t]+)\t(<rect x="(\d+)" y="(\d+)" width="(\d+)" height="(\d+)"\/>)'
    local __replace='$.\t$2\t$1\t$4\t$5\t$6\t$7'

    perl -nle 'print if s/'"$__re"'/'"$__replace"'/' \
    | parallel --progress --colsep $'\t' __magick_crop {1} {2} {3} {4} {5} {6} {7}
}

__magick_crop(){
    local __cnt="${1:?not set}"
    local __tag="${2:?not set}"
    local __src="${3:?not set}"
    local __x="${4:?not set}"
    local __y="${5:?not set}"
    local __w="${6:?not set}"
    local __h="${7:?not set}"

    if [ "${__expand_regions:?not set}" = true ]; then
        local __we=$(($__w / 20)) __he=$(($__h / 20))
        __x=$(($__x - $__he)); __y=$(($__y - $__we))
        __w=$(($__w + 2 * $__we)); __h=$(($__h + 2 * $__he))
    fi

    local __geometry="${__w}x${__h}+${__x}+${__y}"
    local __dst_dir="${__known_faces_dir:?not set}/$__tag"
    local __dst="$__dst_dir/$__cnt.jpg"

    _px_run mkdir -p "$__dst_dir"
    _px_run magick "$__src" -crop "$__geometry" +repage "$__dst"
}
export -f __magick_crop

_px_cmd_digikam_extract_faces(){
    local _px_cmd_usage=(
        "$PROGRAM $COMMAND:"
        "   extracts DigiKam's face region thumbnails to specified directory"
        ""
        "usage: $PROGRAM $COMMAND [options] KNOWN_FACES_DIR"
        ""
        "options:"
        "    -h           help"
        "    -d           dry run"
        "    -e           expand face regions by 10%"
        "    -D DB_TYPE   database type: internal (default), external, sqlite3"
    )

    local __db_type=internal __expand_regions=false
    local OPTIND OPTARG _opts
    while getopts ":hdD:e" _opts; do
        case $_opts in
            h)
                _message "${_px_cmd_usage[@]}"
                return 0
                ;;
            d)
                __px_dryrun=true
                ;;
            D)
                __db_type="$OPTARG"
                ;;
            e)
                __expand_regions=true
                _message "Expanding regions by 10%"
                ;;
            *)
                _warn "invalid option: -$OPTARG"
                _warn "${_px_cmd_usage[@]}"
                return 1
                ;;
        esac
    done
    shift $((OPTIND-1))

    local __known_faces_dir="${1:?KNOWN_FACES_DIR not set}"
    export __expand_regions __known_faces_dir
    __extract_face_regions_mysql | __crop_faces_from_regions
}

_px_cmd_digikam_extract_faces "$@"
