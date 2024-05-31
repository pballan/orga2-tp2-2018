import matplotlib.pyplot as plt
import csv
import sys
import numpy as np

matrix = []
x = [16,32,64,128,256,512,1024,2048]
with open(sys.argv[1]) as csvfile:
    reader = csv.reader(csvfile, quoting=csv.QUOTE_NONNUMERIC)
    for row in reader:
    	matrix.append(row)
y = []
z = []
i = 0
for elem in matrix[0]:
	matrix[0][i] = (matrix[0][i])
	matrix[1][i] = (matrix[1][i])
	x[i] = x[i]
	i = i+1

plt.xlim(0, x[7])
plt.xlabel('longitud del lado de la matriz')
plt.ylabel('mediana de la cantidad de ciclos')
plt.title('as')
plt.plot(x, matrix[0])
plt.plot(x, matrix[1])
#plt.plot(x, matrix[2])
plt.legend(['ASM', 'C'],loc = 'upper left')
plt.savefig(sys.argv[1]+'.png', format='png')
plt.show()