#!/bin/bash

convert_to_thousandths()
{
  STRINGTOCONVERT=$1
  FRAC="000"
  PREFIX=""
  if [[ "${STRINGTOCONVERT:0:1}" == "-" ]]; then
    SIGN="-"
    STRINGTOCONVERT="${STRINGTOCONVERT:1}"
  fi
  if [[ "$STRINGTOCONVERT" =~ \. ]]; then
    WHOLE="${STRINGTOCONVERT%%.*}"
    FRAC="${STRINGTOCONVERT#*.}"
    FRAC="${FRAC:0:3}"
  else
    WHOLE="$STRINGTOCONVERT"
  fi
  while [[ "${#FRAC}" -lt 3 ]]; do
    FRAC=0"$FRAC"
  done 
  VAL_IN_THOUSANDTHS="$WHOLE$FRAC"
  while [[ "${VAL_IN_THOUSANDTHS:0:1}" == "0" ]] && [[ "${#VAL_IN_THOUSANDTHS}" -gt 1 ]]; do 
    VAL_IN_THOUSANDTHS="${VAL_IN_THOUSANDTHS:1}"
  done
  if [[ "$VAL_IN_THOUSANDTHS" -ne 0 ]]; then
    VAL_IN_THOUSANDTHS="$SIGN$VAL_IN_THOUSANDTHS"
  fi
  # echo "$VAL_IN_THOUSANDTHS"
}

STILLHEADTEMP=70.045
DESIREDSTILLHEADTEMP=75.2

convert_to_thousandths 70
convert_to_thousandths $STILLHEADTEMP
convert_to_thousandths $DESIREDSTILLHEADTEMP
convert_to_thousandths 70.034532895
convert_to_thousandths 0.034532895
convert_to_thousandths .034532895
convert_to_thousandths 0.0
convert_to_thousandths .0
convert_to_thousandths 0
convert_to_thousandths -70
convert_to_thousandths "-$STILLHEADTEMP"
convert_to_thousandths "-$DESIREDSTILLHEADTEMP"
convert_to_thousandths -70.034532895
convert_to_thousandths -.034532895
convert_to_thousandths -0.0
convert_to_thousandths -.0
convert_to_thousandths -0

