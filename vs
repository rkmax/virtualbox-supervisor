#!/bin/bash

# Conf
VBOXCMD=VBoxManage
TIMEOUT=3s

# Colors
RST=$'\e[m'
A=$'\e[33m'
V=$'\e[32m'
R=$'\e[31m'
lR=$'\e[1;31m'
uR=$'\e[4;31m'

# Header Strings
OUTPUT_STR="    %-30s %6.2f %6.2f${RST}\n"
OUTPUT_N_STR="    %-30s ${RST}\n"
HEADER_STR="\n    %s%-30s %6s %6s${RST}\n\n"

#fix bc command convert
export LC_NUMERIC="en_US.UTF-8"

# Helpers
function vm_pid
{
    UUID=$1
    ps -ef | grep $UUID | grep -v grep | awk '{ print $2}'
}

function _ext_from
{
    case $2 in
    "NAME")
        echo $1 | awk '{print $1}' | sed 's/^"\(.*\)"$/\1/'
    ;;
    "UUID")
        echo $1 | awk '{print $2}' | sed 's/^{\(.*\)}$/\1/'
    ;;
    *)
        echo "NONE"
    ;;
    esac
}

function vm_cpu
{
    PID=$1
    ps -e -o pcpu,pid | grep $PID | awk '{ print $1}'
}

function vm_mem
{
    PID=$1
    ps -e -o pmem,pid | grep $PID | awk '{ print $1}'
}

function vm_list
{
    $VBOXCMD list vms
}

function vm_runlist
{
    $VBOXCMD list runningvms
}

function vm_nonrunlist
{
    comm -3 <(vm_list | sort) <(vm_runlist | sort)
}

# Main functions
function vm_statuses
{
    local FG=$'\e[32m'
    local TMEM=0
    local TCPU=0

    printf "$HEADER_STR" $FG "RUNNING VIRTUAL MACHINES" " CPU%" " MEM%"

    while read VM
    do
        UUID=$(_ext_from "$VM" "UUID")
        NAME=$(_ext_from "$VM" "NAME")
        PID=$(vm_pid $UUID)

        MEM=$(vm_mem $PID)
        CPU=$(vm_cpu $PID)

        TMEM=$(echo "$TMEM + $MEM" | bc)
        TCPU=$(echo "$TCPU + $CPU" | bc)
        printf "$OUTPUT_STR" $NAME $CPU $MEM

    done < <(vm_runlist)

    echo -n "    --------------------------------------------"
    printf "\n$OUTPUT_STR" "TOTAL" $TCPU $TMEM
}

function vm_non_running
{
    local FG=$'\e[33m'
    printf "$HEADER_STR" $FG "NON RUNNING VIRTUAL MACHINES" "" ""
    while read VM
    do
        NAME=$(_ext_from "$VM" "NAME")
        printf "$OUTPUT_N_STR" $NAME
    done < <(vm_nonrunlist)
}

function title
{
    echo -e "
    ${V}[${A}V${V}]irtualbox [${A}S${V}]upervisor ${RST}

    Es una utilidad que ayuda a la administracion de las maquinas virtuales
    hechas con Virtualbox."
}

function check_vboxcmd
{
    type $VBOXCMD >/dev/null 2>&1 || {
        echo -e "\n    ${uR}${VBOXCMD}${RST}${R} no esta instalado, o no se encuentra en la variable PATH.${RST}\n"
        exit 1
    }
}

function usage
{
    echo -e "
    Modo de uso de $(basename "$0"):

      status                    Muestra el estado de todas las maquinas
                                virtuales del sistema, si la maquina esta
                                en modo running, muestra el uso de memoria
                                ram ${V}(MEM%)${RST} y cpu ${V}(CPU%)${RST} de cada maquina
                                virtual.

      top                       Muestra el estado de las maquinas activas
                                y actualiza constantemente la pantalla
                                por defecto actualiza cada tres (3) segundos
                                pulse CTRL-C para salir.

      start                     Inicia una maquina virtual que se encuentra
                                detenida (apagada, pausada, suspendida)

      stop                      Trata de detener una maquina virtual, usando el
                                comando ${A}acpipowerbutton${RST} de virtualbox.

      force_stop                apaga la maquina virtual por completo. es un apagado
                                forzoso.
                                ${uR}Nota${RST}: ${lR}puede perder información si realiza
                                este tipo de apagado.${RST}
"
}

function clean_loop
{
    tput rmcup
    tput cnorm

    stty sane

    exit 0
}

function status_loop
{
    stty -echo -icanon time 0 min 0

    local keypressed

    if [ $# -eq 1 ];then
        local timeout=$1
    else
        local timeout=$TIMEOUT
    fi

    tput smcup
    tput civis
    clear

    trap clean_loop SIGINT
    trap clean_loop SIGTERM

    while :
    do
        sleep $timeout &
        tput cup 0 0
        echo -e "$(date) timeout : $timeout"
        vm_statuses
        read keypressed

        printf "\n    Pulsa \e[1;34mCTRL-C\e[m para salir"
        wait
    done
}

function start_vm
{
    if [[ $# -eq 1 ]]; then
        local cmd="startvm $1 --type headless"
        $VBOXCMD ${cmd}
    else
        echo "Nada para iniciar"
        exit 0
    fi
}

function stop_vm
{
    if [[ $# -eq 1 ]]; then
        local cmd="controlvm $1 acpipowerbutton"
        $VBOXCMD ${cmd}
    else
        echo "Nada para detener"
        exit 0
    fi
}
function force_stop_vm
{
    if [[ $# -eq 1 ]]; then
        local cmd="controlvm $1 poweroff"
        $VBOXCMD ${cmd}
    else
        echo "Nada para detener"
        exit 0
    fi
}
# Start point
title
check_vboxcmd

if [[ $# -eq 0 ]];then
    usage
    exit 0
fi

case $1 in
    # Private options
    list)
        vm_list
    ;;
    non_run)
        vm_nonrunlist
    ;;
    run)
        vm_runlist
    ;;
    #Public options / autocomplete
    status)
        vm_statuses
        vm_non_running
        echo
    ;;
    start)
        shift
        start_vm $@
    ;;
    stop)
        shift
        stop_vm $@
    ;;
    force_stop)
        shift
        force_stop_vm $@
    ;;
    top)
        shift
        status_loop $1
    ;;
    *)
        usage
    ;;
esac
