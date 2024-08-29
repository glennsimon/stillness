import time
import sys
import RPi.GPIO as GPIO
from hx711 import HX711
from pathlib import Path

# usage: python calcs.py

GPIO.setwarnings(False)
SLOPE2425 = 0.86
SLOPE56 = -1.7
volAdjust = 0.5

hx56 = HX711(5, 6)
hx2425 = HX711(24, 25)

hx56.set_reading_format("MSB", "MSB")
hx2425.set_reading_format("MSB", "MSB")

# for measuring grams
referenceUnit56 = 405.91
referenceUnit2425 = 402.78
hPercentABV = ""
hFlowrate = ""
hCollected = ""
hRemaining = ""

weightList56 = []
weightList2425 = []
timeListMin = []

THETAS = {
  "full": [-96.32780, -0.02856512, 98.96611, -37.81838, 35.07342, 0.02844898, 36.74344],
  "Q1": [1722.515, -0.04283923, -1786.652, 612.3505, -548.0476, 0.04246920, -17.43558],
  "Q2": [-357.4251, -0.01758119, 381.6007, -138.9431, 114.0415, 0.01808855, 155.2817],
  "Q3": [-6.965499, -0.02773449, -5.967778, 2.310737, 8.993499, 0.03055873, 255.8742],
  "Q4": [16.57862, -0.03431656, -37.51686, 15.19476, 3.823482, 0.03827332, 272.0696]
}

def cleanAndExit():
  sys.exit()

def dScaleDrop():
  if len(weightList2425) > 1 and weightList2425[-2] - weightList2425[-1] > 50:
    return True
  else:
    return False

def dScaleIncreasing():
  if len(weightList2425) > 9:
    length = len(weight2425)
    halfLen = int(length / 2)
    lastHalfSum = 0
    firstHalfSum = 0
    for index in range(halfLen):
      lastHalfSum += weightList2425[-(index + 1)]
      firstHalfSum += weightList2425[index]
    lastHalfAverage = lastHalfSum / halfLen
    firstHalfAverage = firstHalfSum / halfLen
    if firstHalfAverage - lastHalfAverage > 0.5:
      return True
    else:
      return False

def calculateVals(T):
  if dScaleDrop():
    # time to swap jars before measurement
    time.sleep(10)
    hx2425.tare()
    hx2425.reset()
    # calculate jar
    jarFile = Path("./temp/jar.txt")
    if jarFile.is_file():
      mJar = open("./temp/jar.txt", "r+")
      jar = int(mJar.read()) + 1
      mJar.seek(0)
    else:
      mJar = open("./temp/jar.txt", "w")
      jar = 0
    mJar.write(str(jar))
    mJar.close()
    # print("Jar: " + str(jar))
    weightList2425.clear()
    weightList56.clear()
    timeListMin.clear()
    # global SLOPE2425
    # weight2425 = hx2425.get_weight(5)
    # weight2425 = weight2425 - SLOPE2425 * (ambientTemp - tareAmbientTemp)
    # weightList2425.append(weight2425)
  if dScaleIncreasing():
    parrotTempK = T + 273.15
    if len(sys.argv) > 1:
      V = float(sys.argv[1])
    else:
      global volAdjust
      print("volAdjust: " + str(volAdjust))
      V = 53.8 + volAdjust

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
    mParrot = weightList56[-1]
    rhoTotal = mParrot / V
    print("rho_total: ", str(rhoTotal))
    wtPct = wtPercent(parrotTempK, "full", rhoTotal)
    if wtPct < 25:
      wtPct = wtPercent(parrotTempK, "Q1", rhoTotal)
    elif wtPct < 50:
      wtPct = wtPercent(parrotTempK, "Q2", rhoTotal)
    elif wtPct < 75:
      wtPct = wtPercent(parrotTempK, "Q3", rhoTotal)
    else:
      wtPct = wtPercent(parrotTempK, "Q4", rhoTotal)
    if rhoTotal > rhoH2O:
      percentABV = 0.0
    else:
      mETOH = mParrot * wtPct / 100
      volETOH = mETOH / rhoETOH
      percentABV = 100 * volETOH / V
      # percentABV = 100 * (rhoH2O - rhoTotal) / (rhoH2O - rhoETOH)
    print("% ABV: " + str(percentABV))
    hPercentABV = open("./temp/percentABV.txt", "w")
    hPercentABV.write(str(percentABV))
    hPercentABV.close()

    # calculate flowrate
    dMassDiff = weightList2425[-1] - weightList2425[-2]
    dVolDiff = dMassDiff / rhoTotal
    flowrate = dVolDiff / (timeListMin[-1] - timeListMin[-2])
    # print("Flowrate: " + str(flowrate))
    hFlowrate = open("./temp/flowrate.txt", "w")
    hFlowrate.write(str(flowrate))
    hFlowrate.close()
    volAdjust = flowrate / 50

    # calculate collected
    if Path("./temp/collected.txt").is_file():
      mCollected = open("./temp/collected.txt", "r+")
      collected = float(mCollected.read())
      mCollected.seek(0)
      mCollected.truncate()
    else:
      collected = 0.0
      mCollected = open("./temp/collected.txt", "w")
    mCollected.write(str(collected + dVolDiff))
    mCollected.close()

    # calculate remaining
    if Path("./temp/remaining.txt").is_file():
      mRemaining = open("./temp/remaining.txt", "r+")
      try:
        remaining = float(mRemaining.read())
        remaining = remaining - dVolDiff * percentABV / 100
        mRemaining.seek(0)
        mRemaining.write(str("%.2f" % remaining))
        mRemaining.truncate()
      except:
        remaining = "unknown"
        mRemaining.seek(0)
        mRemaining.write(remaining)
        mRemaining.truncate()
    else:
      mRemaining = open("./temp/remaining.txt", "w")
      mRemaining.write("unknown")
    mRemaining.close()
  else:
    mFlowrate = open("./temp/flowrate.txt", "w")
    mFlowrate.write("0")
    mFlowrate.close()

def wtPercent(T, range, rho):
  rangeList = THETAS[range]
  x2 = rangeList[0] + rangeList[1] * T + rangeList[2] * rho + rangeList[3] * rho * rho + rangeList[4] / rho + rangeList[5] * T * rho + rangeList[6] / T
  wtPct = 100 * x2 * 46.068 / (x2 * 46.068 + (1 - x2) * 18.01528)
  return wtPct

hx56.set_reference_unit(referenceUnit56)
hx2425.set_reference_unit(referenceUnit2425)

# The next line tares the parrot scale.  The parrot must be empty before calcs.py is started
hx56.tare()
hx2425.tare()
hx56.reset()
hx2425.reset()

prevTareTime = time.monotonic_ns()/1000000000.0/60/60 + 1

hAmbientTemp = open("/sys/bus/w1/devices/28-032197797f0c/w1_slave", "r")
hAmbientTemp.readline()
tareAmbientTemp = hAmbientTemp.readline()
tareAmbientTemp = float(tareAmbientTemp[29:])/1000
hAmbientTemp.close()

while True:
  try:
    # get the ambient temperature
    hAmbientTemp = open("/sys/bus/w1/devices/28-032197797f0c/w1_slave", "r")
    hAmbientTemp.readline()
    ambientTemp = hAmbientTemp.readline()
    ambientTemp = float(ambientTemp[29:])/1000
    hAmbientTemp.close()
    # print("ambientTemp: ", ambientTemp, "degC")

    # get the parrot temperature
    hParrotTemp = open("/sys/bus/w1/devices/28-3ce104578c29/w1_slave", "r")
    hParrotTemp.readline()
    parrotTemp = hParrotTemp.readline()
    parrotTemp = float(parrotTemp[29:])/1000
    hParrotTemp.close()
    # print("parrotTemp: ", parrotTemp, "degC")

    # set references and tare offsets
    # tareOffset = -611 * ambientTemp + 208631
    # hx56.set_reference_unit(1)
    # hx56.set_offset_A(tareOffset)
    # hx56.set_reference_unit(referenceUnit56)

    # Add current time
    if len(timeListMin) >= 20:
      timeListMin.pop(0)
    timeListMin.append(float(time.monotonic_ns()) / 1000000000.0 / 60.0)

    # Add current weight to weightList56
    weight56 = hx56.get_weight(5)
    weight56 = weight56 - SLOPE56 * (ambientTemp - tareAmbientTemp)
    if len(weightList56) >= 20:
      weightList56.pop(0)
    weightList56.append(weight56)
    # print("weightList56: ", weightList56)

    # Add current weight to weightList2425
    weight2425 = hx2425.get_weight(5)
    weight2425 = weight2425 - SLOPE2425 * (ambientTemp - tareAmbientTemp)
    if len(weightList2425) >= 20:
      weightList2425.pop(0)
    weightList2425.append(weight2425)
    # print("weightList2425: ", weightList2425)

    calculateVals(parrotTemp)

    hx56.reset()
    hx2425.reset()
    # delta_sec = round((time.monotonic_ns() - now)/1000000000.0, 3)
    # time.sleep(5)

  except (KeyboardInterrupt, SystemExit):
    cleanAndExit()