import sys

# usage: python percent_abv.py <temp in deg C> <mass> <volume>

T = float(sys.argv[1])
M = float(sys.argv[2])
if len(sys.argv) > 3:
  V = float(sys.argv[3])
else:
  V = 53.228

# calculate water density at temperature T
a = 2.8054253e-10
b = 1.0556302e-7
c = 4.6170461e-5
d = 7.9870401e-3
e = 16.945176
f = 999.83952
g = 1.687985e-2

rho_H2O = ((f + e*T - d*T**2 - c*T**3 + b*T**4 - a*T**5) / (1 + g*T)) / 1000
print("H2O density is: " + str(rho_H2O))

# calculate ethanol density at temperature T

a = 1.0414e-3
b = 1.5672e-6
c = 5.148e-8

rho_25 = .78522

alpha = a + b*T + c*T**2
rho_ETOH = rho_25 * (1 - alpha * (T - 25))
print("ETOH density is: " + str(rho_ETOH))

# calculate %ABV
pct_abv = 100 * (M / V - rho_H2O) / (rho_ETOH - rho_H2O)
print("% ABV: " + str(pct_abv))
