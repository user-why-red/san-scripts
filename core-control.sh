#!/bin/bash

#
# A bash script to list available CPUs and turn off CPUs specified by user input.
# By @user_why_red
#

if [[ $(id -u) -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

# list online CPUs
list_online_cpus() {
    echo "Online CPUs:"
    for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
        if [ "$(cat $cpu/online)" -eq 1 ]; then
            echo "$(basename $cpu)"
        fi
    done
}

# Turn off specific cpu
turn_off_cpu() {
    cpu=$1
    if [ -f /sys/devices/system/cpu/$cpu/online ]; then
        echo 0 > /sys/devices/system/cpu/$cpu/online
        if [ $? -eq 0 ]; then
            echo "$cpu has been turned off."
        else
            echo "Failed to turn off $cpu."
        fi
    else
        echo "$cpu does not exist or cannot be turned off."
    fi
}

list_online_cpus

# Get user input
read -p "Enter the CPU core you want to turn off (e.g., cpu1): " cpu_core

turn_off_cpu $cpu_core
