#!/bin/bash

# INSTRUCTIONS:
# First, start runPWM.py from shell prompt as follows: 'python runPWM.py &'
# Then, start this file: './run-ferment<N>.sh'

instructions=(
  'Enter a number below to make a change (q to quit):',
  '1 - change desired boiler temperature',
  '2 - enter the amount of distillate collected',
  '3 - enter the flow rate',
  '4 - enter the jar number',
  '5 - enter the phase (E, H, MR, T)',
  '6 - enter the percent alc emerging',
  '7 - enter ETOH remaining at 100% abv'
  '8 - set PWM for boiler heater'
)
headers1=('' '' '' '' '')
headers2=('' '' 'T amb' 'T boil' 'Tboil')
headers3=('Time' 'PWM' '(C)' '(C)' 'tgt(C)')
horizLine="-----------------------------------------------"
spacings=(10 6 7 7 7)
boilerTarget="65"
PWM="25"
mPWM=$(( PWM * 1000 ))
now=$( date '+%H:%M:%S' )
prevNowNs=$( date '+%s%N' )
prevNowMs=$(( prevNowNs / 1000000 ))
startTimeNs=$( date '+%s%N' )
startTimeMs=$(( startTimeNs / 1000000))
dataRow=($now $PWM "TBD" "TBD" $boilerTarget)
SECONDS=10
mDeltaTArray=()
fixedPWM=""

# PID constants, must have 3 places after decimal
K_p="1.000"
K_i="0.300"
K_d="1.000"

dataFilename="./runs/$( date '+%F' )_ferment.txt"

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
  echo "mError = " $mError
  echo ""
  echo "mK_p = " $mK_p
  echo "mProp = " $mProp
  echo ""
  echo "mK_d = " $mK_d
  echo "mDeltaTArray = " ${mDeltaTArray[@]}
  echo "diffLastTwo = " $diffLastTwo
  echo "mDiff = " $mDiff
  echo ""
  echo "mK_i = " $mK_i
  echo "mDiffAvg = " $mDiffAvg
  echo "mIntegral = " $mIntegral
  echo ""
  echo "N = " $count "; mPWM = " $mPWM
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

# PID controller used to adjust power
adjust_power()
{
  mBoilerTemp="$(convert_to_thousandths $boilerTemp)"
  mTgtBoilerTemp="$(convert_to_thousandths $boilerTarget)"
  mError="$((mTgtBoilerTemp - mBoilerTemp))"
  count=${#mDeltaTArray[@]}
  mPWM="$(convert_to_thousandths $PWM)"

  # Proportional adjustment
  mK_p="$(convert_to_thousandths $K_p)"
  mProp="$((mK_p * mError / 1000))"

  # Differential adjustment
  mK_d="$(convert_to_thousandths $K_d)"
  if [[ "$count" -ge 2 ]]; then
    diffLastTwo=$((mDeltaTArray[-1] - mDeltaTArray[-2]))
    mDiff="$((mK_d * diffLastTwo / 1000))"
  else
    mDiff="0"
  fi

  # Integral adjustment
  mK_i="$(convert_to_thousandths $K_i)"
  if [[ "$count" -ge 1 ]]; then
    mDiffSum="0"
    for i in "${!mDeltaTArray[@]}"; do
      mDiffSum=$((mDiffSum + mDeltaTArray[$i]))
    done
    mDiffAvg=$((mDiffSum / count))
  else
    mDiffAvg="0"
  fi
  if [[ $mDiffAvg -ne 0 ]]; then
    mIntegral=$((mK_i * mDiffAvg / 1000))
  else
    mIntegral="0"
  fi
  mPWM=$((mPWM + mDiff + mProp + mIntegral))
  if [[ "${mPWM:0:1}" == "-" ]] || [[ "${#mPWM}" -le 3 ]]; then
    PWM=1
  # Linear approximation of power vs PWM intersects 100% at 85% due to 
  # non-linearity of power controller, setting at 85 makes PID controller
  # more responsive on the high end
  elif [[ "${#mPWM}" -ge 3 ]] && [[ "${mPWM::-3}" -ge 85 ]]; then
    PWM=85
  else
    PWM="${mPWM:0:(-3)}.${mPWM:(-3)}"
  fi
  if [[ -z $fixedPWM ]]; then
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
  echo "Syntax: run-still [-h|t|c|f|j|p|a|r|d]"
  echo "options:"
  echo "h         Print these help instructions"
  echo "t <temp>  Set desired boiler temperature"
  echo "c <coll>  Set the amount of distillate collected"
  echo "f <rate>  Set the distillate flow rate"
  echo "j <jar#>  Set the jar number"
  echo "p <phase> Phase of run (E, H, MR, T)"
  echo "a <abv>   Percent ABV of the distillate"
  echo "r <rem>   Remaining alcohol at 100% ABV"
  echo "d <PWM>   Set to a fixed PWM for the heater"
  echo
}

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
        echo "Enter the desired boiler temperature: "
        read boilerTarget         
        mDeltaTArray=()
        mDeltaTArray[0]=$((boilerTarget * 1000 - mBoilerTemp)) ;;
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
        echo "Enter the PWM (0-99), or <CR> for PID controlled PWM: "
        read fixedPWM 
        if [[ -n $fixedPWM ]]; then
          echo $fixedPWM > pwm_setting 
        fi ;;
      "q" | "Q")
        exit ;;
    esac
  
    if [ $SECONDS -gt 8 ]; then
      input=""
      now=$( date '+%H:%M:%S' )
      nowNs=$( date '+%s%N' )
      nowMs=$(( nowNs / 1000000 ))
      ambTemp="$(get_temp '28-032197797f0c')"
      boilerTemp="$(get_temp '28-032197792401')"
      stillheadTemp="$(get_temp '28-032197794fef')"
      coolInletTemp="$(get_temp '28-0321977926b2')"
      coolOutletTemp="$(get_temp '28-032197797070')"
      if [[ -z $fixedPWM ]]; then
        dataRow=($now $PWM $ambTemp $boilerTemp $boilerTarget)
      else
        dataRow=($now $fixedPWM $ambTemp $boilerTemp $boilerTarget)
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
    t) # boiler target
      boilerTarget=$OPTARG
      mDeltaTArray=()
      mDeltaTArray[0]=$((boilerTarget * 1000 - mBoilerTemp)) ;;
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
      fixedPWM=$OPTARG 
      echo $fixedPWM > pwm_setting ;;
   \?) # invalid
      echo "Error: Invalid option"
      exit ;;
  esac
done

main
