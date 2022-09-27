#!/bin/bash


# Exits on failure
set -e

# Get environment variables, set default values to match etcherPro
FAN_GPIO=${FAN_GPIO:-132}
THERMAL_ZONE=/sys/class/thermal/thermal_zone${THERMAL_ZONE:-0}/temp
THERMAL_HIGH=${THERMAL_HIGH:-60}000
THERMAL_LOW=${THERMAL_LOW:-40}000
REFRESH_DELAY=${REFRESH_DELAY:-60}
PWM_PERIOD=${PWM_PERIOD:-40000}
PWM_TEMPS=${PWM_TEMPS:-"0,40,50,70"}
PWM_DUTY=${PWM_DUTY:-"0,200,10000,40000"}

setup_gpio() {
# First, set GPIO as output
if [[ -d /sys/class/gpio/gpio${FAN_GPIO} ]]; then
   echo -n ${FAN_GPIO} > /sys/class/gpio/unexport
fi

echo -n ${FAN_GPIO} > /sys/class/gpio/export
echo -n out > /sys/class/gpio/gpio${FAN_GPIO}/direction
echo -n 1 > /sys/class/gpio/gpio${FAN_GPIO}/value
}

setup_pwm() {
  IFS=','
  read PWM_CHIP PWM_NUM <<< ${PWM}
  if ! [[ -d /sys/class/pwm/pwmchip${PWM_CHIP}/pwm${PWM_NUM} ]]; then
	  echo -n ${PWM_NUM} > /sys/class/pwm/pwmchip${PWM_CHIP}/export
  fi

  
  read -ra TEMPS <<< ${PWM_TEMPS}
  read -ra DUTY <<< ${PWM_DUTY}
  export TEMPS
  export DUTY
  export PWM_PATH=/sys/class/pwm/pwmchip${PWM_CHIP}/pwm${PWM_NUM}

  if [[ $(cat ${PWM_PATH}/enable) -eq 1 ]];then
	  echo -n 0 > ${PWM_PATH}/enable
  fi
  echo -n ${PWM_PERIOD} > ${PWM_PATH}/period
  echo -n ${DUTY[0]} > ${PWM_PATH}/duty_cycle
  echo -n 1 > ${PWM_PATH}/enable
}

if [[ -z ${PWM} ]]; then
    echo "Setting up GPIO mode"
    setup_gpio
else
    echo "Setting up PWM mode"
	setup_pwm
fi

regulate_gpio() {
	TEMP=$1

	if [[ ${TEMP} -ge ${THERMAL_HIGH} ]];then
       echo -n 1 > /sys/class/gpio/gpio${FAN_GPIO}/value
	elif [[ ${TEMP} -le ${THERMAL_LOW} ]];then
       echo -n 0 > /sys/class/gpio/gpio${FAN_GPIO}/value
	fi
}

regulate_pwm() {
    TEMP=$1
    
	# First, look for saturations
	if [[ ${TEMP} -le ${TEMPS[0]}000 ]];then
		echo -n ${DUTY[0]} > ${PWM_PATH}/duty_cycle
		return
	elif [[ ${TEMP} -ge ${TEMPS[-1]}000 ]];then
		echo -n ${DUTY[-1]} > ${PWM_PATH}/duty_cycle
		return
	fi

	# Otherwise, regulate
	for t in ${!TEMPS[@]}; do
		# First, we check the where the temperature sits in our list
		if [[ ${TEMP} -le ${TEMPS[$t]}000 ]]; then
			# When we found the segment ($t (T2) is the index of the temperature above the measurement in the table
			# $t-1 (T1) is the temperature below)
			# We add 3 tailing zeros to be compatible with kernel temperature format.
			T1=${TEMPS[$(($t - 1))]}000
			T2=${TEMPS[$t]}000
			DC1=${DUTY[$(($t - 1))]}
			DC2=${DUTY[$t]}
			# We want to do a linear interpolation between the corresponding PWM duty cycles.
			# - First, we get the position ratio (between 0 and 1). As BASH arithmetic is integer only, it will be between 0 and 1000
			#   R = (TEMP - T1)/(T2 - T1)
			RATIO=$(( ($TEMP - $T1) * 1000 /($T2 - $T1) ))
			# - Then we interpolate the duty cycle value 
			DC=$(($DC1 + ($DC2 - $DC1) * $RATIO / 1000 ))

			if ! [[ -z ${DEBUG} ]];then
			   echo "Temp ${TEMP}, Ratio ${RATIO}, Duty ${DC}"
			fi
			echo -n ${DC} > ${PWM_PATH}/duty_cycle
			return
		fi
	done
}

while :; do
	TEMP=$(cat ${THERMAL_ZONE}) || exit 1
    if [[ -z ${PWM} ]];then
		regulate_gpio $TEMP
	else
		regulate_pwm $TEMP
	fi
	sleep ${REFRESH_DELAY}
done
