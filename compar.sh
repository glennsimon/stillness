#!/bin/bash

help()
{
  #Display help
  echo 'Syntax: run-still.sh -h | -r <rem ETOH> [-x] [-p <phase>] [-c <amount coll>] [-j <jar #>]'
  echo 'where:'
  echo '  -h is help'
  echo '  -x clears all temp files and starts new run with all zeros'
  echo '  -r <rem ETOH> sets remaining ethanol in the boiler (ml)'
  echo '  -p <phase> sets phase of run (HEAT, EQUIL, FORE, HEADS, HEARTS, TAILS, COOL, STRIP)'
  echo '  -c <amount coll>  sets the amount of distillate collected'
  echo '  -j <jar #>  sets the jar number'
  echo
  echo 'At least one argument is required, either -h or -r <rem ETOH>, others optional'
}


TOP_DISPLAY=(
  'Enter a letter below to make a change (q to quit):'
  'p - enter the phase (HEAT, EQUIL, FORE, HEADS, HEARTS, TAILS, COOL, STRIP)'
  'r - enter ETOH remaining at 100% abv'
  'c - enter the amount of distillate collected'
  'j - enter the jar number'
  't - tare the parrot scale (parrot must be empty)'
)
HEADERS_1=('' '' '' '' '' '' '' '' 'flow' 'amt' 'pct' 'ETOH')
HEADERS_2=('' 'Parrot' 'T boil' 'T sthd' 'T cool' 'T cool' 'jar' '' 'rate' 'coll' 'alc' 'rem')
HEADERS_3=('Time' 'T (C)' '(C)' '(C)' 'in (C)' 'out(C)' '#' 'PHASE' 'ml/min' '(ml)' 'out' '(ml)')
H_LINE="-------------------------------------------------------------------------------------------------------------------"
SPACINGS=(16 7 7 7 7 7 4 7 7 7 7 7)
LOOP_TIME="10"
distillateFlowrate="TBD"
percentABV="TBD"
jar="0"
phase="HEAT"
distillateVol="0"
remaining="3000"
now="$( date '+%m-%d %H:%M:%S' )"
startTimeMs="$(( $(date '+%s%N') / 1000000))"
prevNowMs="$startTimeMs"
dataRow=("$now" "TBD" "TBD" "TBD" "TBD" "TBD" $jar $phase $distillateFlowrate $distillateVol $percentABV $remaining)

dataFilename="./runs/$( date '+%F' )_run.txt"

writeRow()
{
  local -n ary=$1
  for ((i=0; i < ${#ary[@]}; i++)); do
    printf "%${SPACINGS[i]}s |" "${ary[i]}"
  done
  echo ""
}

truncate()
{
  decimal="$1"
  digits="${2:-3}"
  frac=""
  if [[ "$decimal" =~ \. ]]; then
    whole="${decimal%%.*}"
    frac="${decimal#*.}"
    frac="${frac:0:digits}"
    echo "$whole.$frac"
  else
    echo "$decimal"
  fi
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
  echo $ary
}

killCalcs()
{
  pattern='^[^0-9]+([0-9]+).+?python (runPWM.py|hx711py\/calcs.py)'
  pythonPids=`ps -ef | grep python`
  while read line; do
    if [[ $line =~ $pattern ]]; then
      kill -9 ${BASH_REMATCH[1]}
      echo "python process ${BASH_REMATCH[1]} killed"
    fi
  done <<< $pythonPids
}

cleanUpAndClose()
{
  killCalcs
  exit
}

main()
{ #try
  # python runPWM.py &
  python hx711py/calcs.py &
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
    if [[ "$nowMs" -lt $((LOOP_TIME * 1000 + prevNowMs)) ]]; then
      read -rsn 1 -t 0.1 input
      case $input in
        p)
          clear
          # echo "Enter the phase (HEAT, EQUIL, FORE, HEADS, HEARTS, TAILS, COOL, STRIP): "
          # read phase
          echo "Enter the phase:"
          echo "1 - HEAT"
          echo "2 - EQUIL"
          echo "3 - FORE"
          echo "4 - HEADS"
          echo "5 - HEARTS"
          echo "6 - TAILS"
          echo "7 - COOL"
          echo "8 - STRIP"
          read -rsn 1 -t 10 phaseNum
          case $phaseNum in
            1)
              phase = "HEAT"
              ;;
            2)
              phase = "EQUIL"
              ;;
            3)
              phase = "FORE"
              ;;
            4)
              phase = "HEADS"
              ;;
            5)
              phase = "HEARTS"
              ;;
            6)
              phase = "TAILS"
              ;;
            7)
              phase = "COOL"
              ;;
            8)
              phase = "STRIP"
              ;;
          esac
          resetDisplay
          ;;
        r)
          clear
          echo "Enter the remaining ethanol: "
          read remaining
          echo $remaining > "./temp/remaining.txt"
          resetDisplay
          ;;
        c)
          clear
          echo "Enter the amount of distillate: "
          read distillateVol
          echo $distillateVol > "./temp/collected.txt"
          resetDisplay
          ;;
        j)
          clear
          echo "Enter the jar number: "
          read jar
          echo $jar > "./temp/jar.txt"
          resetDisplay
          ;;
        t)
          clear
          echo "Is the parrot empty [y/n]? "
          read reply
          if [[ "$reply" == "y" ]]; then
            killCalcs
            python hx711py/calcs.py &
            echo "calcs.py restarted, taring scales"
          else
            echo "calcs.py not restarted, using old tare values"
          fi
          echo $jar > "./temp/jar.txt"
          resetDisplay
          ;;
        "q" | "Q")
          cleanUpAndClose
          ;;
      esac
    else
      parrotTemp="$(get_temp '28-3ce104578c29')"
      boilerTemp="$(get_temp '28-032197792401')"
      stillheadTemp="$(get_temp '28-032197794fef')"
      coolInletTemp="$(get_temp '28-0321977926b2')"
      coolOutletTemp="$(get_temp '28-032197797070')"
      if [[ -e "./temp/flowrate.txt" ]]; then
        distillateFlowrate=`cat ./temp/flowrate.txt`
        distillateFlowrate="$(truncate $distillateFlowrate)"
      fi
      if [[ -e "./temp/collected.txt" ]]; then
        distillateVol=`cat ./temp/collected.txt`
        distillateVol="$(truncate $distillateVol 1)"
      fi
      if [[ -e "./temp/percentABV.txt" ]]; then
        percentABV=`cat ./temp/percentABV.txt`
        percentABV="$(truncate $percentABV)"
      fi
      if [[ -e "./temp/remaining.txt" ]]; then
        remaining=`cat ./temp/remaining.txt`
        remaining="$(truncate $remaining)"
      fi
      if [[ -e "./temp/jar.txt" ]]; then
        jar=`cat ./temp/jar.txt`
      fi
      # fi
      prevNowMs="$nowMs"
      now="$( date '+%m-%d %H:%M:%S' )"
      dataRow=("$now" $parrotTemp $boilerTemp $stillheadTemp $coolInletTemp $coolOutletTemp $jar $phase $distillateFlowrate $distillateVol $percentABV $remaining)
      for ((i = 0 ; i < ${#dataRow[@]} ; i++)); do
        printf "%${SPACINGS[i]}s |" "${dataRow[i]}" >> $dataFilename
      done
      echo "" >> $dataFilename
      resetDisplay
    fi
  done
} || { #catch (not sure if this works)
  cleanUpAndClose
}

while getopts "hxc:j:p:r:" option; do
  case $option in
    h) # display help
      help
      exit
      ;;
    x) # clear all temp files
      rm ./temp/collected.txt
      rm ./temp/flowrate.txt
      rm ./temp/jar.txt
      rm ./temp/percentABV.txt
      ;;
    c) # amount collected
      distillateVol=${OPTARG%.*}
      echo $distillateVol > "./temp/collected.txt"
      ;;
    j) # jar number
      jar=$OPTARG
      ;;
    p) # phase
      phase=$OPTARG
      ;;
    r) # remaining alcohol
      remaining=${OPTARG%.*}
      echo $remaining > "./temp/remaining.txt"
      ;;
   \?) # invalid
      echo "Error: Invalid option"
      ;;
  esac
done

main