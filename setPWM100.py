import RPi.GPIO as GPIO
from time import sleep

pwmPin = 32
GPIO.setwarnings(False)
GPIO.setmode(GPIO.BOARD)
GPIO.setup(pwmPin,GPIO.OUT)
pi_pwm = GPIO.PWM(pwmPin,1000)
dutyCycle = 100.0
pi_pwm.start(dutyCycle)

while True:
  sleep(10)
