import time
import sys

# usage: python water_density_C.py <temp in deg C>

T = float(sys.argv[1])

a = 2.8054253e-10
b = 1.0556302e-7
c = 4.6170461e-5
d = 7.9870401e-3
e = 16.945176
f = 999.83952
g = 1.687985e-2

density = ((f + e*T - d*T**2 - c*T**3 + b*T**4 - a*T**5) / (1 + g*T)) / 1000
print("density is: " + str(density))
