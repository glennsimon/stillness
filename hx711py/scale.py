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
# referenceUnit = float(sys.argv[3])

print("Please wait while scale zeros out (tare)...")

hx = HX711(chan_1, chan_2)

hx.set_reading_format("MSB", "MSB")

# milligrams
if chan_1 == 5 and chan_2 == 6:
  referenceUnit = .40573
elif chan_1 == 24 and chan_2 == 25:
  referenceUnit = .40124
else:
  print("Invalid channels. Exiting...")
  sys.exit()

hx.set_reference_unit(referenceUnit)

hx.reset()

# hx.tare()
if chan_1 == 5:
  hx.set_reference_unit(1)
  hx.set_offset_A(189115.2)
  hx.set_reference_unit(referenceUnit)
elif chan_1 == 24:
  hx.set_reference_unit(1)
  hx.set_offset_A(589263.5)
  hx.set_reference_unit(referenceUnit)

print("Tare done! Add weight now...")

while True:
    try:
        now = time.monotonic_ns()
        val = round(hx.get_weight(5))
        delta_sec = round((time.monotonic_ns() - now)/1000000000.0, 3)
        print("weight (mg): " + str(val))
        print("read time (s): " + str(delta_sec))

        hx.power_down()
        hx.power_up()
        time.sleep(0.5)

    except (KeyboardInterrupt, SystemExit):
        cleanAndExit()