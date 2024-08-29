import time
import sys
import RPi.GPIO as GPIO
from hx711 import HX711
from pathlib import Path

# usage: python scale_offset_test.py

GPIO.setwarnings(False)
SLOPE2425 = 0.86
SLOPE56 = -1.7
HEADERS = "time     | tare amb (C) | T amb (C)  | 56 wt unadj  | 2425 wt unadj | 56 wt adj  | 2425 wt adj   |\n"
HORIZ_LINE = "--------------------------------------------------------------------------------------------------\n"

hx56 = HX711(5, 6)
hx2425 = HX711(24, 25)

hx56.set_reading_format("MSB", "MSB")
hx2425.set_reading_format("MSB", "MSB")

# for measuring grams
referenceUnit56 = 405.91
referenceUnit2425 = 402.78

def cleanAndExit():
  sys.exit()

hx56.set_reference_unit(referenceUnit56)
hx2425.set_reference_unit(referenceUnit2425)

# The next line tares the parrot scale.  The parrot must be empty before calcs.py is started
hx56.tare()
hx2425.tare()
hx56.reset()
hx2425.reset()

hLogfile = open("scale_test_log.txt", "a")
hLogfile.write(HEADERS)
hLogfile.write(HORIZ_LINE)
hLogfile.close()

# hAmbientTemp = open("/sys/bus/w1/devices/28-032197797f0c/w1_slave", "r")
hAmbientTemp = open("/sys/bus/w1/devices/28-3ce104572963/w1_slave", "r")
hAmbientTemp.readline()
tareAmbientTemp = hAmbientTemp.readline()
tareAmbientTemp = float(tareAmbientTemp[29:])/1000
hAmbientTemp.close()

tareTime = float(time.monotonic_ns()) / 1000000000.0

while True:
  try:
    hLogfile = open("scale_test_log.txt", "a")
    # write time to logfile
    currTime = float(time.monotonic_ns()) / 1000000000.0
    hLogfile.write(str(currTime - tareTime) + " |")

    # write tare ambient temp to logfile
    hLogfile.write(str(tareAmbientTemp) + " |")

    # get the ambient temperature
    # hAmbientTemp = open("/sys/bus/w1/devices/28-032197797f0c/w1_slave", "r")
    hAmbientTemp = open("/sys/bus/w1/devices/28-3ce104572963/w1_slave", "r")
    hAmbientTemp.readline()
    ambientTemp = hAmbientTemp.readline()
    ambientTemp = float(ambientTemp[29:])/1000
    hAmbientTemp.close()
    # print("ambientTemp: ", ambientTemp, "degC")

    # write current ambient temp to logfile
    hLogfile.write(str(ambientTemp) + " |")

    weight56 = hx56.get_weight(5)
    # write unadjusted weight56 to logfile
    hLogfile.write(str(weight56) + " |")
    weight56 = weight56 - SLOPE56 * (ambientTemp - tareAmbientTemp)

    weight2425 = hx2425.get_weight(5)
    # write unadjusted weight2425 to logfile
    hLogfile.write(str(weight2425) + " |")
    weight2425 = weight2425 - SLOPE2425 * (ambientTemp - tareAmbientTemp)

    # write adjusted weights to logfile
    hLogfile.write(str(weight56) + " |")
    hLogfile.write(str(weight2425) + " |")

    # add new line and close logfile
    hLogfile.write("\n")
    hLogfile.close()

    hx56.reset()
    hx2425.reset()
    # delta_sec = round((time.monotonic_ns() - now)/1000000000.0, 3)
    # time.sleep(30)

  except (KeyboardInterrupt, SystemExit):
    cleanAndExit()
