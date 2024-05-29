import time
import statistics
import sys
import RPi.GPIO as GPIO
from hx711 import HX711

# usage: python calcs.py

hx2425 = HX711(24, 25)

hx2425.set_reading_format("MSB", "MSB")

# for measuring grams
referenceUnit56 = 400
referenceUnit2425 = 400
hPercentABV = ""
hFlowrate = ""
hCollected = ""
hRemaining = ""

weightList56 = []
weightList2425 = []
timeListMin = []

def dScaleDrop():
  if len(weightList2425) == 10 and weightList2425[0] - weightList2425[9] > 100:
    return True

def dScaleIncreasing():
  if len(weightList2425) > 1 and weightList2425[-1] > weightList2425[0] + 0.5:
    return True

def calculateVals(T):
  if dScaleDrop():
    hx2425.tare()
    hx2425.reset()
    weightList2425 = []
  if dScaleIncreasing():
    if len(sys.argv) > 1:
      V = float(sys.argv[1])
    else:
      V = 53.228

    # calculate water density at temperature T
    a = 2.8054253e-10
    b = 1.0556302e-7
    c = 4.6170461e-5
    d = 7.9870401e-3
    e = 16.945176
    f = 999.83952
    g = 1.687985e-2
    rhoH2O = ((f + e*T - d*T**2 - c*T**3 + b*T**4 - a*T**5) / (1 + g*T)) / 1000
    # print("H2O density is: " + str(rhoH2O))

    # calculate ethanol density at temperature T
    a = 1.0414e-3
    b = 1.5672e-6
    c = 5.148e-8
    rho25 = .78522
    alpha = a + b*T + c*T**2
    rhoETOH = rho25 * (1 - alpha * (T - 25))
    # print("ETOH density is: " + str(rhoETOH))

    # calculate %ABV
    mParrot = statistics.mean(weightList56)
    rhoTotal = mParrot / V
    percentABV = 100 * (rhoH2O - rhoTotal) / (rhoH2O - rhoETOH)
    print("% ABV: " + str(percentABV))
    hPercentABV = open("../temp/percentABV.txt", "w")
    hPercentABV.write(str(percentABV))
    hPercentABV.close()

    # calculate flowrate
    dMassDiff = weightList2425[-1] - weightList2425[-2]
    dVolDiff = dMassDiff / rhoTotal
    flowrate = dVolDiff / (timeListMin[-1] - timeListMin[-2])
    print("Flowrate: " + str(flowrate))
    hFlowrate = open("../temp/flowrate.txt", "w")
    hFlowrate.write(str(flowrate))
    hFlowrate.close()

    # calculate collected
    hCollected = open("../temp/collected.txt", "r+")
    collected = hCollected.read()
    print("Collected: " + str(collected))
    hCollected.seek(0)
    hCollected.write(str(collected + dVolDiff))
    hCollected.truncate()
    hCollected.close()

    hRemaining = open("../temp/collected.txt", "r+")
    remaining = hRemaining.read()
    print("Remaining: " + str(remaining))
    hRemaining.seek(0)
    hRemaining.write(str(remaining - dVolDiff * percentABV / 100))
    hRemaining.truncate()
    hRemaining.close()

hx2425.set_reference_unit(referenceUnit2425)
hx2425.reset()

while True:
  try:
    # get the ambient temperature
    hAmbientTemp = open("/sys/bus/w1/devices/28-032197797f0c/w1_slave", "r")
    hAmbientTemp.readline()
    ambientTemp = hAmbientTemp.readline()
    ambientTemp = float(ambientTemp[29:])/1000
    hAmbientTemp.close()
    print("ambientTemp: ", ambientTemp, "degC")

    # get the parrot temperature
    hParrotTemp = open("/sys/bus/w1/devices/28-3ce104578c29/w1_slave", "r")
    hParrotTemp.readline()
    parrotTemp = hParrotTemp.readline()
    parrotTemp = float(parrotTemp[29:])/1000
    hParrotTemp.close()
    print("parrotTemp: ", parrotTemp, "degC")

    # set references and tare offsets
    tareOffset = -611 * ambientTemp + 208631

    # Add current time
    if len(timeListMin) >= 10:
      timeListMin.pop(0)
    timeListMin.append(float(time.monotonic_ns()) / 1000000000.0 / 60.0)
    print("timeListMin: ", timeListMin)

    # Add current weight to weightList2425
    if len(weightList2425) >= 10:
      weightList2425.pop(0)
    weightList2425.append(hx2425.get_weight(5))
    print("weightList2425: ", weightList2425)

    calculateVals(parrotTemp)

    hx2425.reset()
    # delta_sec = round((time.monotonic_ns() - now)/1000000000.0, 3)
    # time.sleep(300 - (time.monotonic_ns() - now)/1000000000.0)

  except (KeyboardInterrupt, SystemExit):
    exit