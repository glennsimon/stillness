#!/bin/bash

convert_to_thousandths()
{
  STRINGTOCONVERT=$1
  FRAC=
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

adjust_power()
{
  convert_to_thousandths $STILLHEADTEMP
  USHT=$UT
  convert_to_thousandths $DESIREDSTILLHEADTEMP
  UDSHT=$UT
  DIFF=$((UDSHT - USHT))
}

STILLHEADTEMP=70.045
DESIREDSTILLHEADTEMP=75.2

convert_to_thousandths 70
echo $VAL_IN_THOUSANDTHS
convert_to_thousandths $STILLHEADTEMP
echo $VAL_IN_THOUSANDTHS
convert_to_thousandths $DESIREDSTILLHEADTEMP
echo $VAL_IN_THOUSANDTHS
convert_to_thousandths 70.034532895
echo $VAL_IN_THOUSANDTHS
convert_to_thousandths 0.034532895
echo $VAL_IN_THOUSANDTHS
convert_to_thousandths .034532895
echo $VAL_IN_THOUSANDTHS
convert_to_thousandths 0.0
echo $VAL_IN_THOUSANDTHS
convert_to_thousandths .0
echo $VAL_IN_THOUSANDTHS
convert_to_thousandths 0
echo $VAL_IN_THOUSANDTHS
convert_to_thousandths -70
echo $VAL_IN_THOUSANDTHS
convert_to_thousandths "-$STILLHEADTEMP"
echo $VAL_IN_THOUSANDTHS
convert_to_thousandths "-$DESIREDSTILLHEADTEMP"
echo $VAL_IN_THOUSANDTHS
convert_to_thousandths -70.034532895
echo $VAL_IN_THOUSANDTHS
convert_to_thousandths -.034532895
echo $VAL_IN_THOUSANDTHS
convert_to_thousandths -0.0
echo $VAL_IN_THOUSANDTHS
convert_to_thousandths -.0
echo $VAL_IN_THOUSANDTHS
convert_to_thousandths -0
echo $VAL_IN_THOUSANDTHS

