import time
import sys

# usage: python ethanol_density_C.py <temp in deg C>

T = float(sys.argv[1])

a = 1.0414e-3
b = 1.5672e-6
c = 5.148e-8

rho_25 = .78522

alpha = a + b*T + c*T**2
density = rho_25 * (1 - alpha * (T - 25))
print("density is: " + str(density))
