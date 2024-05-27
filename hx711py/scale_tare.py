import time
import sys
import RPi.GPIO as GPIO
from hx711 import HX711

# usage: python scale.py <channel 1> <channel 2> <reference unit>
# reference unit must be calculated when scale is tared

def cleanAndExit():
    print("Cleaning...")
        
    print("Bye!")
    sys.exit()

chan_1 = int(sys.argv[1])
chan_2 = int(sys.argv[2])
referenceUnit = 1

print("Please wait while scale zeros out (tare)...")

hx = HX711(chan_1, chan_2)

hx.set_reading_format("MSB", "MSB")

# if chan_1 == 5 and chan_2 == 6:
#   referenceUnit = .40573
# elif chan_1 == 24 and chan_2 == 25:
#   referenceUnit = .40124
# else:
#   print("Invalid channels. Exiting...")
#   sys.exit()

hx.set_reference_unit(1)

hx.reset()

while True:
    try:
        now = time.monotonic_ns()
        fh = open("/sys/bus/w1/devices/28-032197797f0c/w1_slave", "r")
        fh.readline()
        temp = fh.readline()
        temp = float(temp[29:])/1000
        fh.close()
#        tare_val = hx.tare()
        if chan_1 == 5:
          tare_val = -611 * temp + 208631
          hx.set_reference_unit(1)
          hx.set_offset_A(tare_val)
          val = round(hx.get_weight(5))
          referenceUnit = val / 1836000
          hx.set_reference_unit(referenceUnit)
        elif chan_1 == 24:
          hx.set_reference_unit(1)
          hx.set_offset_A(589263.5)
          hx.set_reference_unit(referenceUnit)

        print("set_offset_A: " + str(tare_val))
        val = round(hx.get_weight(5))
        delta_sec = round((time.monotonic_ns() - now)/1000000000.0, 3)
        print("weight (mg): " + str(val))
        fh2 = open("logfile4.txt", "a")
        fh2.write("set_offset_A: " + str(tare_val) + "\n")
        fh2.write("weight (mg): " + str(val) + "\n")
        fh2.write("referenceUnit: " + str(referenceUnit) + "\n")
        print("read time (s): " + str(delta_sec))
        print("referenceUnit: " + str(referenceUnit))
        fh2.write("read time (s): " + str(delta_sec) + "\n")
        # offset = -1701*temp + 51944
        # val = val - offset
        # fh2.write("weight after adjust (mg): " + str(val) + "\n")
        # print("weight after adjust (mg): " + str(val))
        print("Tamb: " + str(temp))
        fh2.write("Tamb: " + str(temp) + "\n")
        fh2.close()
        hx.reset()
        delta_sec = round((time.monotonic_ns() - now)/1000000000.0, 3)
        time.sleep(300 - (time.monotonic_ns() - now)/1000000000.0)

    except (KeyboardInterrupt, SystemExit):
        fh2.close()
        cleanAndExit()
