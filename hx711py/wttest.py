import time
import sys
import RPi.GPIO as GPIO
from hx711 import HX711
from pathlib import Path

# usage: python calcs.py

GPIO.setwarnings(False)

hx56 = HX711(5, 6)
hx2425 = HX711(24, 25)

hx56.set_reading_format("MSB", "MSB")
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

def cleanAndExit():
  hLogFile.close()
  sys.exit()

hx56.set_reference_unit(referenceUnit56)
hx2425.set_reference_unit(referenceUnit2425)

hx2425.tare()
hx56.reset()
hx2425.reset()

hLogFile = open("./temp/wtlog.txt", "a")
hLogFile.write("Time,Tamb,Tparrot,wt56,wt2425\n")
hLogFile.close()

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
    tareOffset = -611 * ambientTemp + 208631
    hx56.set_reference_unit(1)
    hx56.set_offset_A(tareOffset)
    hx56.set_reference_unit(referenceUnit56)

    currentTime = time.ctime()

    weight56 = hx56.get_weight(5)
    # print("weightList56: ", weightList56)

    weight2425 = hx2425.get_weight(5)
    # print("weightList2425: ", weightList2425)

    hLogFile = open("./temp/wtlog.txt", "a")
    hLogFile.write(currentTime + "," + str(ambientTemp) + "," + str(parrotTemp) + "," + str(weight56) + "," + str(weight2425) + "\n")
    print(currentTime + "," + str(ambientTemp) + "," + str(parrotTemp) + "," + str(weight56) + "," + str(weight2425))
    hLogFile.close()

    hx56.reset()
    hx2425.reset()
    # delta_sec = round((time.monotonic_ns() - now)/1000000000.0, 3)
    time.sleep(30)

  except (KeyboardInterrupt, SystemExit):
    cleanAndExit()