import math

SINE_RES = 360
CLK_FREQ_HZ   = 100_000_000
CARRIER_FREQ  = 1_000
PERIOD_CYCLES = CLK_FREQ_HZ / CARRIER_FREQ
AMPLITUDE = (PERIOD_CYCLES // 2) * 80 // 100

with open("sine_lut.hex", "w") as f:
  for i in range(SINE_RES):
  val = int((PERIOD_CYCLES/2) + AMPLITUDE * math.sin(2*math.pi*i/SINE_RES))
  f.write(f"{val:04x}\n")

