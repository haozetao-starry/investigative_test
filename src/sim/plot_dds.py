import pandas as pd, matplotlib.pyplot as plt

df = pd.read_csv(r"C:\Users\Lenovo\Desktop\investigative_test\src\sim\dds_sweep_wave.csv")
plt.plot(df["cycle"], df["wave_out"])
plt.show()