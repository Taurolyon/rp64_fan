#!/bin/bash

###########################################################################
# A simple bash script to run and control the NanoPi M4 SATA hat PWM1 fan #
###########################################################################

# Modified from mar0ni's script:
# https://forum.armbian.com/topic/11086-pwm-fan-on-nanopi-m4/?tab=comments#comment-95180

# Export pwmchip1 that controls the SATA hat fan if it hasn't been done yet
# This will create a 'pwm0' subfolder that allows us to control various properties of the fan
if [ ! -d /sys/class/pwm/pwmchip1/pwm0 ]; then
    echo 0 > /sys/class/pwm/pwmchip1/export
fi
sleep 1
while [ ! -d /sys/class/pwm/pwmchip1/pwm0 ];
do
    sleep 1
done

# Set default period (40000ns = 25kHz)
echo 40000 > /sys/class/pwm/pwmchip1/pwm0/period

# The default polarity is inversed. Set it to 'normal' instead.
echo normal > /sys/class/pwm/pwmchip1/pwm0/polarity

# CPU, GPU and disks temperatures to monitor
declare -a CpuTemps=(75000 68000 60000 50000 40000)
declare -a DiskTemps=(55 50 45 40 35)
# Duty cycle for each temperature range
declare -a DutyCycles=(40000 9000 3500 2200 2050)
# Change the following if you want the script to change the fan speed more/less frequently
timeStep=5

# Run fan at full speed for some seconds when the script starts, then keep running at calculated speed
echo ${DutyCycles[0]} > /sys/class/pwm/pwmchip1/pwm0/duty_cycle
echo 1 > /sys/class/pwm/pwmchip1/pwm0/enable
sleep $timeStep

# Main loop to monitor cpu (zone0) and gpu (zone1) temperatures, as well as NAS hard disks temperatures
# and assign duty cycles accordingly. Disks device name must be adapted to your own case (/dev/sdX).
# The -n option of smartctl avoid to spin up a disk if it has stopped
while true
do
    temp0=$(cat /sys/class/thermal/thermal_zone0/temp)
    temp1=$(cat /sys/class/thermal/thermal_zone1/temp)
    test $temp0 -gt $temp1 && tempU=$temp0 || tempU=$temp1
    tempD=0
        temp2=`/usr/sbin/smartctl -l scttempsts -d sat -n standby /dev/sda | grep -m 1 Temperature | awk '{print $3}'`
    if [ -n "$temp2" ]; then
        tempD=$temp2
    fi
    temp3=`/usr/sbin/smartctl -l scttempsts -d sat -n standby /dev/sdb | grep -m 1 Temperature | awk '{print $3}'`
    if [ -n "$temp3" ]; then
               test $temp3 -gt $tempD && tempD=$temp3
    fi
    temp4=`/usr/sbin/smartctl -l scttempsts -d sat -n standby /dev/sdc | grep -m 1 Temperature | awk '{print $3}'`
    if [ -n "$temp4" ]; then
               test $temp4 -gt $tempD && tempD=$temp4
    fi
    temp5=`/usr/sbin/smartctl -l scttempsts -d sat -n standby /dev/sdd | grep -m 1 Temperature | awk '{print $3}'`
    if [ -n "$temp5" ]; then
               test $temp5 -gt $tempD && tempD=$temp5
    fi
    duty0=$(cat /sys/class/pwm/pwmchip1/pwm0/duty_cycle)
    DUTY=0
    # If you changed the length of $CpuTemps and $DutyCycles, then change the following length, too
    for i in 0 1 2 3 4; do
        # add some hysteresis when the fan speeds down to avoid continuous stop and go
        test $duty0 -ge ${DutyCycles[$i]} && j=2 || j=0
        if [ $tempU -gt $((${CpuTemps[$i]}-$j*1000)) ] || [ $tempD -gt $((${DiskTemps[$i]}-$j)) ]; then
            # if the fan is stopped, first full speed to ensure it really starts
            test $duty0 -eq 0 && DUTY=${DutyCycles[0]} || DUTY=${DutyCycles[$i]}
            # To test the script, uncomment the following line:
            # echo "i: $i, j: $j, cpu: $temp0, gpu: $temp1, target: ${CpuTemps[$i]}; d1: $temp2, d2: $temp3, d3: $temp4, d4: $temp5, target: ${DiskTemps[$i]}, duty: $DUTY"
            break        
        fi
    done
    echo $DUTY > "/sys/class/pwm/pwmchip1/pwm0/duty_cycle";
    sleep $timeStep;
done

exit 0
