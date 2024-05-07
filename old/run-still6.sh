#!/bin/bash

# INSTRUCTIONS:
# First, start runPWM.py from shell prompt as follows: 'python runPWM.py &'
# Then, start this file: './run-still.sh'

instructions=(
  'Enter a number below to make a change (q to quit):',
  '1 - change desired stillhead temperature',
  '2 - enter the amount of distillate collected',
  '3 - enter the flow rate',
  '4 - enter the jar number',
  '5 - enter the phase (E, H, MR, T)',
  '6 - enter the percent alc emerging',
  '7 - enter ETOH remaining at 100% abv'
  '8 - set PWM for boiler heater'
)
headers1=('' '' '' '' '' '' '' '' '' '' 'flow' 'amt' 'pct' 'amt' 'ETOH')
headers2=('' '' 'T amb' 'T boil' 'T sthd' 'T cool' 'T cool' 'T sthd' 'jar' '' 'rate' 'coll' 'alc' '100abv' 'rem')
headers3=('Time' 'PWM' '(C)' '(C)' '(C)' 'in (C)' 'out(C)' 'tgt(C)' '#' 'PHASE' 'ml/min' '(ml)' 'out' '(ml)' '(ml)')
horizLine="--------------------------------------------------------------------------------------------------------------------------------------"
spacings=(10 6 7 7 7 7 7 7 4 7 7 7 7 7 7)
stillheadTarget="76.5"
PWM=40
mPWM=$(( PWM * 1000 ))
distillateFlowrate=30
percentABV=80
jar=0
phase="E"
distillateVol=0
extracted=0
remaining=9000
mRemaining=$(( remaining * 1000 ))
now=$( date '+%H:%M:%S' )
prevNowNs=$( date '+%s%N' )
prevNowMs=$(( prevNowNs / 1000000 ))
startTimeNs=$( date '+%s%N' )
startTimeMs=$(( startTimeNs / 1000000))
dataRow=($now $PWM "TBD" "TBD" "TBD" "TBD" "TBD" $stillheadTarget $jar $phase $distillateFlowrate $distillateVol $percentABV $extracted $remaining)
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
  for ((i=0; i < ${#instructions[@]}; i++)); do
    echo "${instructions[i]}"
  done
  write_row headers1 >&1
  write_row headers2 >&1
  write_row headers3 >&1
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
  mStillHeadTemp="$(convert_to_thousandths $stillheadTemp)"
  mTgtStillHeadTemp="$(convert_to_thousandths $stillheadTarget)"

  # proportional adjustment
  stepChange="$((mPrevStillHeadTemp - mStillHeadTemp))"
  # differential adjustment
  diff="$(((mTgtStillHeadTemp - mStillHeadTemp)/3))"

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
    integral=$(((mTgtStillHeadTemp-mStillHeadTemp)*(mPWM-mPWMAvg)/diffAvg/10))
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
  mPrevStillHeadTemp=$mStillHeadTemp
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
    mDeltaTArray[9]=$((mTgtStillHeadTemp - mStillHeadTemp))
    mPWMArray[9]=$mPWM
  else
    mDeltaTArray+=($((mTgtStillHeadTemp - mStillHeadTemp)))
    mPWMArray+=($mPWM)
  fi
}

help()
{
  #Display help
  echo "Syntax: run-still [-h|t|c|f|j|p|a|r|d]"
  echo "options:"
  echo "h         Print these help instructions"
  echo "t <temp>  Set desired stillhead temperature"
  echo "c <coll>  Set the amount of distillate collected"
  echo "f <rate>  Set the distillate flow rate"
  echo "j <jar#>  Set the jar number"
  echo "p <phase> Phase of run (E, H, MR, T)"
  echo "a <abv>   Percent ABV of the distillate"
  echo "r <rem>   Remaining alcohol at 100% ABV"
  echo "d <PWM>   Set PWM for boiler heater"
  echo
}

echo $PWM > pwm_setting

clear
write_row headers1 >> $dataFilename
write_row headers2 >> $dataFilename
write_row headers3 >> $dataFilename
echo $horizLine >> $dataFilename

main() 
{
  while true ; do
    read -rsn 1 -t 0.1 input
    case $input in
      1)
        clear
        echo "Enter the desired stillhead temperature: "
        read stillheadTarget ;;
      2)
        clear
        echo "Enter the amount of distillate: "
        read distillateVol
        mDistillateVol=$(( distillateVol * 1000 )) ;;
      3)
        clear
        echo "Enter the distillate flow rate: "
        read distillateFlowrate ;;
      4)
        clear
        echo "Enter the jar number: "
        read jar ;;
      5)
        clear
        echo "Enter the phase (E, H, MR, T): "
        read phase ;;
      6)
        clear
        echo "Enter the percent ABV: "
        read percentABV ;;
      7)
        clear
        echo "Enter the remaining ethanol: "
        read remaining 
        mRemaining=$(( remaining * 1000 )) ;;
      8)
        clear
        echo "Enter the value of PWM you want to set (0-99): "
        read PWM ;;
      "q" | "Q")
        exit ;;
    esac
  
    if [ $SECONDS -gt 8 ]
    then
      input=""
      now=$( date '+%H:%M:%S' )
      nowNs=$( date '+%s%N' )
      nowMs=$(( nowNs / 1000000 ))
      ambTemp="$(get_temp '28-032197797f0c')"
      boilerTemp="$(get_temp '28-032197792401')"
      stillheadTemp="$(get_temp '28-032197794fef')"
      coolInletTemp="$(get_temp '28-0321977926b2')"
      coolOutletTemp="$(get_temp '28-032197797070')"
      mDeltaDistVol=$(( distillateFlowrate * (nowMs - prevNowMs) / 60 ))
      mDistillateVol=$(( mDistillateVol + mDeltaDistVol ))
      distillateVol=$(( mDistillateVol / 1000 ))
      mExtracted=$(( mDeltaDistVol * percentABV / 100 ))
      extracted=$(( mExtracted / 1000 ))
      mRemaining=$(( mRemaining - mExtracted ))
      remaining=$(( mRemaining / 1000 ))
      dataRow=($now $PWM $ambTemp $boilerTemp $stillheadTemp $coolInletTemp $coolOutletTemp $stillheadTarget $jar $phase $distillateFlowrate $distillateVol $percentABV $extracted $remaining)
      clear
      reset_display
      i=0
      for datum in ${dataRow[@]}
      do
        printf "%${spacings[i]}s |" $datum >> $dataFilename
        i=$(( i + 1 ))
      done
      echo "" >> $dataFilename
      update_arrays
      adjust_power
      SECONDS=0
      prevNowMs=$nowMs
    fi
  done
}

while getopts "ht:c:f:j:p:a:r:d:" option; do
  case $option in
    h) # display help
      help
      exit ;;
    t) # stillhead target
      stillheadTarget=$OPTARG ;;
    c) # amount collected
      distillateVol=$OPTARG
      mDistillateVol=$(( distillateVol * 1000 )) ;;
    f) # distillate flow rate
      distillateFlowrate=$OPTARG ;;
    j) # jar number
      jar=$OPTARG ;;
    p) # phase
      phase=$OPTARG ;;
    a) # percent ABV of distillate
      percentABV=$OPTARG ;;
    r) # remaining alcohol
      remaining=$OPTARG
      mRemaining=$(( remaining * 1000 )) ;;
    d) # duty cycle (PWM)
      PWM=$OPTARG ;;
   \?) # invalid
      echo "Error: Invalid option"
      exit ;;
  esac
done

main