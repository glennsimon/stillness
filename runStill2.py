import subprocess
import RPi.GPIO as GPIO
import time
import threading
import curses
import os



def main(win):
  pwmPin = 32
  GPIO.setwarnings(False)
  GPIO.setmode(GPIO.BOARD)
  GPIO.setup(pwmPin,GPIO.OUT)
  pi_pwm = GPIO.PWM(pwmPin,1000)
  dutyCycle = 50.0
  desiredStillHeadTemp = 70.0
  jarNum = 1
  pi_pwm.start(dutyCycle)
  devices = ["/sys/bus/w1/devices/28-032197792401/w1_slave", "/sys/bus/w1/devices/28-032197794fef/w1_slave"]
  print("Enter a number below to make a change:")
  print("1 - change desired stillhead temperature")
  print("2 - enter the amount of distillate collected")
  print("3 - quit")
  filename = input("Enter name for data file: ")
  file = open(filename, "a")
  headers = ["Time","PWM","T_boiler","T_stillhead","T_stillhead_desired","jar","amount_collected"]
  headerString = ""
  for header in headers:
    headerString += header + " "
  print(headerString)
  file.write(headerString + "\n")
  file.close()
  
  def grabData():
    file = open(filename, "a")
    pi_pwm.ChangeDutyCycle(dutyCycle)
    data = time.strftime("%d/%m/%y@%H:%M:%S") + " "
    data += str(dutyCycle) + " "
    for device in devices:
      output = subprocess.run(["cat",device], capture_output=True).stdout.decode()
      temp_string = output[output.find("t=") + 2:]
      temp = str(round(float(temp_string) / 1000.0, 2))
      data += temp + " "
    data += str(jarNum) + " "
    print(data, end="\r")
    file.write(data + "\n")
    file.close()
    threading.Timer(10.0, grabData).start()
    
  threading.Timer(0.0, grabData).start()  
  win.nodelay(True)
  key = ""
  # win.clear()
  # win.addstr("Detected key: ")
  while True:
    try:
      key = win.getkey()
      # win.clear()
      # win.addstr("Detected key: ")
      # win.addstr(str(key))
      if key == os.linesep:
        break
      elif str(key) == "1":
        desiredStillHeadTemp = input("Enter the desired still head temperature in degC: ")
      elif str(key) == "2":
        distillateAmount = input("Enter the amount of distillate in jar in ml: ")
      elif str(key) == "3":
        exit()
      else:
        pass

    except Exception as e:
      pass

curses.wrapper(main)
  
