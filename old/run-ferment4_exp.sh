#!/bin/bash

# INSTRUCTIONS:
# First, start runPWM.py from shell prompt as follows: 'python runPWM.py &'
# Then, start this file: './run-still.sh'

instr1="Enter a number below to make a change:"
instr2="1 - change desired boiler temperature"
instr5="4 - quit"
headers1=("" "" "T top" "T boil" "T boil" "jar" "amt coll")
headers2=("Time" "PWM" "(C)" "(C)" "tgt(C)" "#" "(ml)")
horizLine="---------------------------------------------------------"
spacings=(10 6 7 7 7 7 7 7 4 9)
boilerTarget=75
PWM=35
mPWM=$(( PWM * 1000 ))
jar=0
dataRow=("TBD" $PWM "TBD" "TBD" "TBD" "TBD" "TBD" $boilerTarget $jar)
SECONDS=10
mDeltaTArray=()
mPWMArray=()

dataFilename="$( date '+%F' )_run.txt"

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
  echo `clear`
  echo $instr1
  echo $instr2
  echo $instr3
  echo $instr4
  echo $instr5
  write_row headers1 >&1
  write_row headers2 >&1
  echo $horizLine >&1
  write_row dataRow >&1
  echo ""
  echo "PWM = " $PWM
  echo "stepChange = " $stepChange
  echo "diff = " $diff
  echo "N = " $count "; mPWM = " $mPWM "; mPWMAvg = " $mPWMAvg "; integral = " $integral
}

get_temp()
{
  sensorOutput=`cat /sys/bus/w1/devices/$1/w1_slave`
  mTempPattern='[^t]+t=(.+)'
  fracPart="999"
  wholePart="99"
  if [[ $sensorOutput =~ $mTempPattern ]]
  then
    mTemp="${BASH_REMATCH[1]}"
    fracPart="${mTemp:(-3)}"
    wholePart="$((mTemp/1000))"
  fi
  echo "$wholePart.$fracPart"
}

# PID controller used to adjust power
adjust_power()
{
  mBoilerTemp="$(convert_to_thousandths $boilerTemp)"
  mTgtBoilerTemp="$(convert_to_thousandths $boilerTarget)"

  # proportional adjustment
  stepChange="$((mPrevStillHeadTemp - mBoilerTemp))"
  # differential adjustment
  diff="$(((mTgtBoilerTemp - mBoilerTemp)/3))"

  # integral adjustment
  mPWM="$(convert_to_thousandths $PWM)"
  diffSum=0
  mPWMSum=0
  for i in "${!mDeltaTArray[@]}"; do
    diffSum=$((diffSum + mDeltaTArray[$i]))
    mPWMSum=$((mPWMSum + mPWMArray[$i]))
  done
  count=${#mDeltaTArray[@]}
  diffAvg=$((diffSum / count))
  mPWMAvg=$((mPWMSum / count))
  if [ $diffAvg -ne 0 ]
  then
    integral=$(((mTgtBoilerTemp-mBoilerTemp)*(mPWM-mPWMAvg)/diffAvg/10))
  else
    integral=0
  fi

  mPWM=$((mPWM + stepChange + diff + integral))
  if [[ "${mPWM:0:1}" == "-" ]] || [[ "${#mPWM}" -le 3 ]]
  then 
    PWM=1
  elif [[ "${#mPWM}" -ge 3 ]] && [[ "${mPWM::-3}" -ge 99 ]]
  then
    PWM=99
  else
    PWM="${mPWM:0:(-3)}.${mPWM:(-3)}"
  fi
  echo $PWM > pwm_setting
  mPrevStillHeadTemp=$mBoilerTemp
}

update_arrays()
{
  if [ ${#mDeltaTArray[@]} -ge 10 ]
  then
    for i in {1..10}
    do
      mDeltaTArray[$i-1]=${mDeltaTArray[$i]}
      mPWMArray[$i-1]=${mPWMArray[$i]}
    done
    mDeltaTArray[9]=$((mTgtBoilerTemp - mBoilerTemp))
    mPWMArray[9]=$mPWM
  else
    mDeltaTArray+=($((mTgtBoilerTemp - mBoilerTemp)))
    mPWMArray+=($mPWM)
  fi
}

echo $PWM > pwm_setting

write_row headers1 >> $dataFilename
write_row headers2 >> $dataFilename
echo $horizLine >> $dataFilename
write_row headers1 >&1
write_row headers2 >&1
echo $horizLine

while true
do
  read -rsn 1 -t 0.1 input
  if [ "$input" = 1 ]
  then
    clear
    echo "Enter the desired stillhead temperature: "
    read boilerTarget
    reset_display
  elif [ "$input" = 2 ]
  then
    clear
    echo "Enter the amount of distillate: "
    read distillateVol
    reset_display
  elif [ "$input" = 3 ]
  then
    clear
    echo "Enter the jar number: "
    read jar
    distillateVol=0
    reset_display
  elif [ "$input" = 4 ]
  then
    clear
    break
  fi

  if [ $SECONDS -gt 8 ]
  then
    input=""
    NOW=$( date '+%H:%M:%S' )
    topTemp="$(get_temp '28-032197797f0c')"
    boilerTemp="$(get_temp '28-032197792401')"
    dataRow=($NOW $PWM $topTemp $boilerTemp $boilerTarget $jar $distillateVol)
    clear
    reset_display
    i=0
    for datum in ${dataRow[@]}
    do
      printf "%${spacings[i]}s |" $datum >> $dataFilename
      i=$(( i + 1 ))
    done
    echo "" >> $dataFilename
    distillateVol=""
    update_arrays
    adjust_power
    SECONDS=0
  fi
done
