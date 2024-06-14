#!/bin/bash

# INSTRUCTIONS:
# Start this file: './run-ferment.sh [-h] | [-t <boiler temp tgt>] [-p <fixed PWM number>]'

instructions=(
  'Enter a number below to make a change (q to quit):',
  't - change desired boiler temperature',
  'p - set PWM for boiler heater'
)
headers1=('' '' '' '' '')
headers2=('' '' 'T amb' 'T boil' 'Tboil')
headers3=('Time' 'PWM' '(C)' '(C)' 'tgt(C)')
horizLine="-----------------------------------------------"
spacings=(15 6 7 7 7)
boilerTarget="74"
PWM="25"
mPWM=$(( PWM * 1000 ))
now=$( date '+%H:%M:%S' )
prevNowNs=$( date '+%s%N' )
prevNowMs=$(( prevNowNs / 1000000 - 10000))
dataRow=("$now" $PWM "TBD" "TBD" $boilerTarget)
mDeltaTArray=()
fixedPWM=""

dataFilename="runs/$( date '+%F' )_ferment.txt"

write_row()
{
  local -n ary=$1
  for ((i=0; i < ${#ary[@]}; i++)); do
    printf "%${spacings[i]}s |" "${ary[i]}"
  done
  echo ""
}

convert_to_thousandths()
{
  decimal=$1
  frac="000"
  sign=""
  if [[ "${decimal:0:1}" == "-" ]]; then
    sign="-"
    decimal="${decimal:1}"
  fi
  if [[ "$decimal" =~ \. ]]; then
    whole="${decimal%%.*}"
    frac="${decimal#*.}"
    frac="${frac:0:3}"
  else
    whole="$decimal"
  fi
  while [[ "${#frac}" -lt 3 ]]; do
    frac=0"$frac"
  done
  thousandths="$whole$frac"
  while [[ "${thousandths:0:1}" == "0" ]] && [[ "${#thousandths}" -gt 1 ]]; do
    thousandths="${thousandths:1}"
  done
  if [[ "$thousandths" -ne 0 ]]; then
    thousandths="$sign$thousandths"
  fi
  echo "$thousandths"
}

reset_display()
{
  clear
  for ((i=0; i < ${#instructions[@]}; i++)); do
    echo "${instructions[i]}"
  done
  write_row headers1 >&1
  write_row headers2 >&1
  write_row headers3 >&1
  echo $horizLine >&1
  write_row dataRow >&1
  echo ""
  echo "fixedPWM = " $fixedPWM
  echo "PWM = " $PWM
  echo "mPWM = " $mPWM
  echo ""
  echo "mError = " $mError
  echo ""
  echo "mDeltaTArray = " ${mDeltaTArray[@]}
  echo ""
}

get_temp()
{
  if [[ -d /sys/bus/w1/devices/$1 ]]; then
    sensorOutput=`cat /sys/bus/w1/devices/$1/w1_slave`
    mTempPattern='[^t]+t=(.+)'
    fracPart="999"
    wholePart="99"
    if [[ $sensorOutput =~ $mTempPattern ]]; then
      mTemp="${BASH_REMATCH[1]}"
      fracPart="${mTemp:(-3)}"
      wholePart="$((mTemp/1000))"
    fi
    echo "$wholePart.$fracPart"
  else
    echo 'absent'
  fi
}

# Experimentally derived method for setting PWM (if PWM not fixed)
adjust_power()
{
  mBoilerTemp="$(convert_to_thousandths $boilerTemp)"
  mTgtBoilerTemp="$(convert_to_thousandths $boilerTarget)"
  mAmbTemp="$(convert_to_thousandths $ambTemp)"
  # Thermal resistance from boiler to ambient (C/W, in thousandths)
  mError="$((mTgtBoilerTemp - mBoilerTemp))"
  
  if [[ "$mError" -gt 2000 ]]; then
    mPWM="99000"
  elif [[ "$mError" -lt -2000 ]]; then
    mPWM="1000"
  else
    mPWM=$(( 5000 * mError / 2000 + 1000000 * (mTgtBoilerTemp - mAmbTemp) / 215 / 15910 + 14639 ))
  fi

  PWM="${mPWM:0:(-3)}.${mPWM:(-3)}"
  if [[ -z "$fixedPWM" ]]; then
    echo $PWM > pwm_setting
  fi
}

update_arrays()
{
  if [ ${#mDeltaTArray[@]} -ge 10 ]; then
    for i in {1..10}; do
      mDeltaTArray[$i-1]=${mDeltaTArray[$i]}
    done
    mDeltaTArray[9]=$((mTgtBoilerTemp - mBoilerTemp))
  else
    mDeltaTArray+=($((mTgtBoilerTemp - mBoilerTemp)))
  fi
}

help()
{
  #Display help
  echo "Syntax: ./run-ferment.sh [-h] | [-t <temp>] [-p <PWM>]"
  echo "options:"
  echo "-h         Print these help instructions"
  echo "-t <temp>  Set desired boiler temperature"
  echo "-p <PWM>   Set to a fixed PWM for the heater"
  echo
}

python runPWM.py &
write_row headers1 >> $dataFilename
write_row headers2 >> $dataFilename
write_row headers3 >> $dataFilename
echo $horizLine >> $dataFilename

main() 
{
  while true ; do
    read -rsn 1 -t 0.1 input
    case $input in
      t)
        clear
        echo "Enter the desired boiler temperature: "
        read boilerTarget         
        mDeltaTArray=()
        mDeltaTArray[0]=$((boilerTarget * 1000 - mBoilerTemp))
        ;;
      p)
        clear
        echo "Enter the PWM (0-99), or <CR> for PID controlled PWM: "
        read fixedPWM 
        if [[ -n $fixedPWM ]]; then
          echo $fixedPWM > pwm_setting 
        fi
        ;;
      "q" | "Q")
        pattern='^[^0-9]+([0-9]+).+?python runPWM.py'
        pythonPids=`ps -ef | grep python`
        while read line; do
          if [[ $line =~ $pattern ]]; then 
            kill -9 ${BASH_REMATCH[1]}
            echo "python process ${BASH_REMATCH[1]} killed"
          fi
        done <<< $pythonPids
        exit
        ;;
    esac
    input=""

    nowNs=$( date '+%s%N' )
    nowMs=$(( nowNs / 1000000 ))
    timeDiff=$(( nowMs - prevNowMs ))
    if [[ "$timeDiff" -ge 10000 ]]; then
      now="$( date '+%m-%d %H:%M:%S' )"
      ambTemp="$(get_temp '28-032197797f0c')"
      boilerTemp="$(get_temp '28-3ce104577969')"
      if [[ -z $fixedPWM ]]; then
        dataRow=("$now" $PWM $ambTemp $boilerTemp $boilerTarget)
      else
        dataRow=("$now" $fixedPWM $ambTemp $boilerTemp $boilerTarget)
      fi
      reset_display
      i=0
      for datum in ${dataRow[@]}; do
        printf "%${spacings[i]}s |" $datum >> $dataFilename
        i=$(( i + 1 ))
      done
      echo "" >> $dataFilename
      update_arrays
      adjust_power
      prevNowMs=$nowMs
    fi
  done
}

while getopts "ht:p:" option; do
  case $option in
    h) # display help
      help
      exit
      ;;
    t) # boiler target
      boilerTarget=$OPTARG
      mDeltaTArray=()
      mDeltaTArray[0]=$((boilerTarget * 1000 - mBoilerTemp))
      ;;
    p) # duty cycle (PWM)
      fixedPWM=$OPTARG 
      echo $fixedPWM > pwm_setting
      ;;
   \?) # invalid
      echo "Error: Invalid option"
      exit
      ;;
  esac
done

main
