#!/bin/bash

# Conf
VBOXCMD=VBoxManage
RST=$'\e[m'
OUTPUT_STR="    %-30s %6.2f %6.2f${RST}\n"
OUTPUT_N_STR="    %-30s ${RST}\n"
HEADER_STR="\n    %s%-30s %6s %6s${RST}\n\n"


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
    done < <(comm -3 <(vm_list | sort) <(vm_runlist | sort))    
}

function usage
{
    local A=$'\e[33m'    
    local V=$'\e[32m'
    echo -e "
    ${V}[${A}V${V}]irtualbox [${A}S${V}]upervisor ${RST}

    Es una utilidad que ayuda a la administracion de las maquinas virtuales
    hechas con Virtualbox.

    Modo de uso de $(basename "$0"):

      status                    Muestra el estado de todas las maquinas
                                virtuales del sistema, si la maquina esta
                                en modo running, muestra el uso de memoria
                                ram (MEM%) y cpu (CPU%) de cada maquina
                                virtual.

      top                       Muestra el estado de las maquinas activas
                                y actualiza constantemente la pantalla
                                por defecto actualiza cada tres (3) segundos
                                pulse CTRL-C para salir.
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

    tput smcup
    tput civis
    clear

    trap clean_loop SIGINT
    trap clean_loop SIGTERM

    while :
    do
        sleep 3s &
        tput cup 0 0
        date
        vm_statuses
        read keypressed

        printf "\n    Pulsa \e[1;34mCTRL-C\e[m para salir"        
        wait
    done
}

# Start point


if [[ $# -eq 0 ]];then
    usage
    exit 0
fi

case $1 in
    list)
        vm_list
    ;;
    status)
        vm_statuses
        vm_non_running
        echo
    ;;
    top)
        status_loop
    ;;
    *)
        usage
    ;;
esac
