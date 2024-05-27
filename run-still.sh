#!/bin/bash

help()
{
  #Display help
  echo 'Syntax: run-still.sh -h | -r <rem ETOH> [-p <phase>] [-c <amount coll>] [-j <jar #>]'
  echo 'where:'
  echo '  -h is help'
  echo '  -r <rem ETOH> sets remaining ethanol in the boiler (ml)'
  echo '  -p <phase> sets phase of run (heat, equil, FORE, HEADS, HEARTS, TAILS, cool)'
  echo '  -c <amount coll>  sets the amount of distillate collected'
  echo '  -j <jar #>  sets the jar number'
  echo
  echo 'At least one argument is required, either -h or -r <rem ETOH>, others optional'
}


TOP_DISPLAY=(
  'Enter a letter below to make a change (q to quit):'
  'p - enter the phase (HEAT, EQUIL, FORE, HEADS, HEARTS, TAILS, COOL)'
  'r - enter ETOH remaining at 100% abv'
  'c - enter the amount of distillate collected'
  'j - enter the jar number'
)
HEADERS_1=('' '' '' '' '' '' '' '' 'flow' 'amt' 'pct' 'ETOH')
HEADERS_2=('' 'Parrot' 'T boil' 'T sthd' 'T cool' 'T cool' 'jar' '' 'rate' 'coll' 'alc' 'rem')
HEADERS_3=('Time' 'T (C)' '(C)' '(C)' 'in (C)' 'out(C)' '#' 'PHASE' 'ml/min' '(ml)' 'out' '(ml)')
H_LINE="--------------------------------------------------------------------------------------------------------------------------------------"
SPACINGS=(16 7 7 7 7 7 4 7 7 7 7 7)
LOOP_TIME="10"
distillateFlowrate="TBD"
percentABV="TBD"
jar="0"
phase="HEAT"
distillateVol="0"
remaining="3000"
mRemaining="$(( remaining * 1000 ))"
now="$( date '+%m-%d %H:%M:%S' )"
startTimeMs="$(( $(date '+%s%N') / 1000000))"
prevNowMs="$startTimeMs"
dataRow=($now "TBD" "TBD" "TBD" "TBD" "TBD" $jar $phase $distillateFlowrate $distillateVol $percentABV $remaining)
dScaleArray=(0)
pScaleArray=(0)

dataFilename="./runs/$( date '+%F' )_run.txt"

writeRow()
{
  local -n ary=$1
  for ((i=0; i < ${#ary[@]}; i++)); do
    printf "%${SPACINGS[i]}s |" "${ary[i]}"
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

resetDisplay()
{
  clear
  for ((i=0; i < ${#TOP_DISPLAY[@]}; i++)); do
    echo "${TOP_DISPLAY[i]}"
  done
  writeRow HEADERS_1 >&1
  writeRow HEADERS_2 >&1
  writeRow HEADERS_3 >&1
  echo $H_LINE >&1
  writeRow dataRow >&1
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

# usage: $(updateArray <array to update> <value to add to end> [<array length>])
# array holds 10 values max unless optional <array length> option is used
updateArray()
{
  local -n ary=$1
  length="${3:-10}"
  if [[ "${#ary[@]}" -ge "$length" ]]; then
    for ((i = 1 ; i < "$length" ; i++)); do
      ary[$i-1]="${ary[$i]}"
    done
    ary[9]="$2"
  else
    ary+=("$2")
  fi
}

cleanUpAndClose()
{
  # Careful, this will kill all python scripts running on the computer
  pid=$(pidof python)
  while [[ -n "$pid" ]]; do
    kill -9 $pid
    pid=$(pidof python)
  done
  exit
}

dScaleIncreasing()
{
  if [[ "${#dScaleArray[@]}" -ge 10]]; then
    mDiff="$(( dScaleArray[9] - dScaleArray[0] ))"
    if [[ "$mDiff" -ge 1000 ]]; then
      echo 0 # true
    fi
  else
    echo 1 # false
  fi
}

dScaleDrop()
{
  if [[ "${#dScaleArray[@]}" -ge 10]]; then
    mDiff="$(( dScaleArray[0] - dScaleArray[9] ))"
    if [[ "$mDiff" -ge 10000 ]]; then
      echo 0 # true
    fi
  else
    echo 1 # false
  fi
}

main()
{ #try
  echo "Need to write calcs.py script - include re-tare for weight drop on dScale"
  cleanUpAndClose
  python calcs.py $LOOP_TIME &
  resetDisplay
  writeRow HEADERS_1 >> $dataFilename
  writeRow HEADERS_2 >> $dataFilename
  writeRow HEADERS_3 >> $dataFilename
  echo $H_LINE >> $dataFilename
  now="$( date '+%m-%d %H:%M:%S' )"
  parrotTemp="$(get_temp '28-3ce104578c29')"
  boilerTemp="$(get_temp '28-032197792401')"
  stillheadTemp="$(get_temp '28-032197794fef')"
  coolInletTemp="$(get_temp '28-0321977926b2')"
  coolOutletTemp="$(get_temp '28-032197797070')"
  while true ; do
    nowMs="$(( $(date '+%s%N') / 1000000))"
    if [[ $nowMs -lt $((LOOP_TIME * 1000 + prevNowMs)) ]]; then
      read -rsn 1 -t 0.1 input
      case $input in
        p)
          clear
          echo "Enter the phase (E, H, MR, T): "
          read phase ;;
        r)
          clear
          echo "Enter the remaining ethanol: "
          read remaining
          mRemaining=$(( remaining * 1000 )) ;;
        c)
          clear
          echo "Enter the amount of distillate: "
          read distillateVol
          mDistillateVol=$(( distillateVol * 1000 )) ;;
        j)
          clear
          echo "Enter the jar number: "
          read jar ;;
        "q" | "Q")
          cleanUpAndClose ;;
      esac
    else
      # get the latest scale values and append to array
      if [[ -e "./temp/pScale.txt" ]]; then
        value=`cat ./temp/pScale.txt`
        $(updateArray $pScaleArray $value)
      fi
      if [[ -e "./temp/dScale.txt" ]]; then
        value=`cat ./temp/dScale.txt`
        $(updateArray $dScaleArray $value)
      fi
      if dScaleDrop; then
        jar+=1
        dScaleArray=(0)
        # python tareScale.py 24 25 & - NO! do this in the python script if dScale weight drops
      fi
      if dScaleIncreasing; then
        # python script calculates density, %ABV, collected volume, flow rate, and remaining ETOH
        if [[ -e "./temp/flowrate.txt" ]]; then
          distillateFlowrate=`cat ./temp/flowrate.txt`
        fi
        if [[ -e "./temp/collected.txt" ]]; then
          distillateVol=`cat ./temp/collected.txt`
        fi
        if [[ -e "./temp/percentABV.txt" ]]; then
          percentABV=`cat ./temp/percentABV.txt`
        fi
        if [[ -e "./temp/remaining.txt" ]]; then
          remaining=`cat ./temp/remaining.txt`
        fi
      fi
      prevNowMs=$nowMs
    fi
  done
  dataRow=($now $parrotTemp $boilerTemp $stillheadTemp $coolInletTemp $coolOutletTemp $jar $phase $distillateFlowrate $distillateVol $percentABV $remaining)
  for ((i = 0 ; i < ${#dataRow[@]} ; i++)); do
    printf "%${SPACINGS[i]}s |" ${dataRow[i]} >> $dataFilename
  done
  echo "" >> $dataFilename
  resetDisplay
} || { #catch (not sure if this works)
  cleanUpAndClose
}

while getopts "hc:j:p:r:" option; do
  case $option in
    h) # display help
      help
      exit ;;
    c) # amount collected
      distillateVol=$OPTARG
      mDistillateVol=$(( distillateVol * 1000 )) ;;
    j) # jar number
      jar=$OPTARG ;;
    p) # phase
      phase=$OPTARG ;;
    r) # remaining alcohol
      remaining=$OPTARG
      mRemaining=$(( remaining * 1000 )) ;;
   \?) # invalid
      echo "Error: Invalid option"
      cleanUpAndClose ;;
  esac
done

main
