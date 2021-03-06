#!/bin/bash

echo ""

SCRIPT=$(readlink -f "$0")
INSTALLPATH=$(dirname "${SCRIPT}")
TOPDIR=$(dirname "${INSTALLPATH}")
default_ccnet_conf_dir=${TOPDIR}/ccnet

manage_py=${INSTALLPATH}/seahub/manage.py
gunicorn_conf=${INSTALLPATH}/runtime/seahub.conf
gunicorn_pidfile=${INSTALLPATH}/runtime/seahub.pid

export LD_LIBRARY_PATH=${INSTALLPATH}/seafile/lib/:${LD_LIBRARY_PATH}

script_name=$0
function usage () {
    echo "Usage : "
    echo "$(basename ${script_name}) { start <port> | stop | restart <port> }" 
    echo "default port is 8000"
    echo ""
}

# Check args
if [[ $1 != "start" && $1 != "stop" && $1 != "restart" ]]; then
    usage;
    exit 1;
fi

function validate_seaf_server_running () {
    if ! pgrep -f "seafile-controller -c ${default_ccnet_conf_dir}" 2>/dev/null 1>&2; then
        echo "seafile server process is not running, please start it by:"
        echo ""
        echo "          ./seafile.sh start"
        echo ""
        exit 1;
    fi
}

function validate_seahub_running () {
    if pgrep -f "${manage_py} run_gunicorn" 2>/dev/null 1>&2; then
        echo "Seahub is already running."
        exit 1;
    fi
}

function validate_port () {
    if ! [[ ${port} =~ ^[1-9][0-9]{1,4}$ ]] ; then
        printf "\033[033m${port}\033[m is not a valid port number\n\n"
        usage;
        exit 1
    fi
}

if [[ ($1 == "start" || $1 == "restart") && ($# == 2 || $# == 1) ]]; then
    if [[ $# == 2 ]]; then
        port=$2
        validate_port
    else
        port=8000
    fi
elif [[ $1 == "stop" && $# == 1 ]]; then
    dummy=dummy
else
    usage;
    exit 1
fi

function start_seahub () {
    validate_seaf_server_running;
    validate_seahub_running;
    pid=$(pgrep -f "${manage_py} run_gunicorn")
    if [[ "${pid}" != "" ]]; then
        echo "Seahub has already been running.".
        exit 1;
    fi
    echo "Starting seahub http server at port ${port} ..."
    seafile_python_path=${INSTALLPATH}/seafile/lib/python2.7/site-packages
    thirdpart_path=${INSTALLPATH}/seahub/thirdpart
    export CCNET_CONF_DIR=${default_ccnet_conf_dir}
    export PYTHONPATH=${seafile_python_path}:${thirdpart_path}
    "${manage_py}" run_gunicorn -c "${gunicorn_conf}" -b "0.0.0.0:${port}"

    # Ensure seahub is started successfully
    sleep 2
    if ! pgrep -f "${manage_py} run_gunicorn" 2>/dev/null 1>&2; then
        printf "\033[33mError:Seahub failed to start.\033[m\n"
        echo "Please try to run \"./seafile.sh start\" again"
        echo "If it fails again, Please remove ${default_ccnet_conf_dir} and run ./setup-seafile.sh again"
        exit 1;
    fi
}

function stop_seahub () {
    if [[ -f ${gunicorn_pidfile} ]]; then
        pid=$(cat "${gunicorn_pidfile}")
        echo "Stopping seahub ..."
        kill ${pid}
        return 0
    else
        echo "Seahub is not running"
    fi
}

function restart_seahub () {
    stop_seahub
    sleep 2
    start_seahub
}

case $1 in 
    "start" )
        start_seahub;
        ;;
    "stop" )
        stop_seahub;
        ;;
    "restart" )
        restart_seahub;
        ;;
esac

echo "Done."
echo ""
