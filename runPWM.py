import RPi.GPIO as GPIO
from time import sleep

pwmPin = 32
GPIO.setwarnings(False)
GPIO.setmode(GPIO.BOARD)
GPIO.setup(pwmPin,GPIO.OUT)
pi_pwm = GPIO.PWM(pwmPin,1000)
dutyCycle = 39.0
pi_pwm.start(dutyCycle)

while True:
  try:
    file = open("pwm_setting")
    dutyCycle = float(file.readline())
    file.close()
    pi_pwm.ChangeDutyCycle(dutyCycle)
    sleep(9)
    
  except Exception as e:
    print(e)
    pass
  sleep(1)

