#!/bin/bash

# INSTRUCTIONS:
# First, start runPWM.py from shell prompt as follows: 'python runPWM.py &'
# Then, start this file: './run-still.sh'

LINE1="Enter a number below to make a change:"
LINE2="1 - change desired stillhead temperature"
LINE3="2 - enter the amount of distillate collected"
LINE4="3 - enter the jar number"
LINE5="4 - quit"
HEADERS="Time,PWM,T boiler (C),T stillhead(C),T stillhead target (C),jar #,amount collected"
ENTER_LINE="Enter name for data file: "
DESIREDSTILLHEADTEMP=76.5
PWM=40
KPWM=40000
JAR=4p
DATA_ROW="TBD,$PWM,TBD,TBD,$DESIREDSTILLHEADTEMP,$JAR"
SECONDS=10
PREVSHT=76500
LAST_TEN_DTEMPS=()
LAST_TEN_PWMS=()

clear
echo $ENTER_LINE
read DATAFILENAME
echo $HEADERS >> $DATAFILENAME

strindex()
{
  POS=-1
  TMPPOS=0
  for (( i=0; i<${#2}; i++ ))
  do
    if [ ${2:$i:1} == $1 ]
    then
      POS=$i
      break
    fi
  done
}

convert_to_thousandths()
{
  strindex '.' $1
  if [[ $POS == -1 && $1 != 0 ]]
  then
    VAL_IN_THOUSANDTHS="${1}000"
  else
    WHOLE=${1:0:$POS}
    FRAC=${1:$((POS + 1))}
    while [ ${#FRAC} -lt 3 ]
    do
      FRAC=${FRAC}0
    done
    if [ ${#FRAC} -gt 3 ]
    then
      FRAC=${FRAC:0:3}
    fi
    VAL_IN_THOUSANDTHS="${WHOLE}${FRAC}"
    REGEX="(-?)([0]*)(.*)"
    if [[ $VAL_IN_THOUSANDTHS =~ $REGEX ]]
    then
      if [ ${#BASH_REMATCH[3]} -eq 0 ]
      then
        VAL_IN_THOUSANDTHS=0
      else
        VAL_IN_THOUSANDTHS="${BASH_REMATCH[1]}${BASH_REMATCH[3]}"
      fi
    fi
  fi
}

reset_display()
{
  echo `clear`
  echo $LINE1
  echo $LINE2
  echo $LINE3
  echo $LINE4
  echo $LINE5
  echo $HEADERS
  echo $DATA_ROW
  echo $PWM
  echo $STEPCHANGE
  echo $DIFF
  echo $COUNT $KPWM $PWMAVG $INT
}

get_temp()
{
  TMI=`cat /sys/bus/w1/devices/$1/w1_slave`
  REGEX='[^t]+t=(.+)'
  if [[ $TMI =~ $REGEX ]]
  then
    TEMP="${BASH_REMATCH[1]}"
    FRAC_PART=${TEMP:(-3)}
    WHOLE_PART=$((TEMP/1000))
    TEMP=$WHOLE_PART.$FRAC_PART
  fi
}

# PID controller used to adjust power
adjust_power()
{
  convert_to_thousandths $STILLHEADTEMP
  USHT=$VAL_IN_THOUSANDTHS
  convert_to_thousandths $DESIREDSTILLHEADTEMP
  UDSHT=$VAL_IN_THOUSANDTHS

  # proportional adjustment
  STEPCHANGE=$((PREVSHT - USHT))

  # differential adjustment
  DIFF=$(((UDSHT - USHT)/3))

  convert_to_thousandths $PWM
  PWM=$VAL_IN_THOUSANDTHS

  # integral adjustment
  DIFFSUM=0
  PWMSUM=0
  for i in "${!LAST_TEN_DTEMPS[@]}"; do
    DIFFSUM=$((DIFFSUM + LAST_TEN_DTEMPS[$i]))
    PWMSUM=$((PWMSUM + LAST_TEN_PWMS[$i]))
  done
  COUNT=${#LAST_TEN_DTEMPS[@]}
  DIFFAVG=$((DIFFSUM / COUNT))
  PWMAVG=$((PWMSUM / COUNT))
  if [ $DIFFAVG -ne 0 ]
  then
    INT=$(((UDSHT-USHT)*(PWM-PWMAVG)/DIFFAVG))
  else
    INT=0
  fi

  KPWM=$((PWM + STEPCHANGE + DIFF + INT))
  PWM=${KPWM:0:(-3)}.${KPWM:(-3)}
  if [ "${KPWM:0:(-3)}" -ge "100" ]
  then
    PWM=99
  fi
  if [ "${KPWM:0:(-3)}" -le "0" ]
  then
    PWM=1
  fi
  echo $PWM > pwm_setting
  PREVSHT=$USHT
}

update_arrays()
{
  if [ ${#LAST_TEN_DTEMPS[@]} -ge 10 ]
  then
    for i in {1..10}
    do
      LAST_TEN_DTEMPS[$i-1]=${LAST_TEN_DTEMPS[$i]}
      LAST_TEN_PWMS[$i-1]=${LAST_TEN_PWMS[$i]}
    done
    LAST_TEN_DTEMPS[9]=$((UDSHT - USHT))
    LAST_TEN_PWMS[9]=$KPWM
  else
    LAST_TEN_DTEMPS+=($((UDSHT - USHT)))
    LAST_TEN_PWMS+=($KPWM)
  fi
}

echo $PWM > pwm_setting

while true
do
  read -rsn 1 -t 0.1 INPUT
  if [ "$INPUT" = 1 ]
  then
    clear
    echo "Enter the desired stillhead temperature: "
    read DESIREDSTILLHEADTEMP
    reset_display
  elif [ "$INPUT" = 2 ]
  then
    clear
    echo "Enter the amount of distillate: "
    read DISTILLATEVOL
    reset_display
  elif [ "$INPUT" = 3 ]
  then
    clear
    echo "Enter the jar number: "
    read JAR
    DISTILLATEVOL=0
    reset_display
  elif [ "$INPUT" = 4 ]
  then
    clear
    break
  fi

  if [ $SECONDS -gt 8 ]
  then
    INPUT=""
    NOW=$(date)
    get_temp "28-032197792401"
    BOILERTEMP=$TEMP
    get_temp "28-032197794fef"
    STILLHEADTEMP=$TEMP
    DATA_ROW="$NOW,$PWM,$BOILERTEMP,$STILLHEADTEMP,$DESIREDSTILLHEADTEMP,$JAR,$DISTILLATEVOL"
    clear
    reset_display
    echo $DATA_ROW >> $DATAFILENAME
    DISTILLATEVOL=""
    update_arrays
    adjust_power
    SECONDS=0
  fi
done