#from sage.rings.number_field.number_field_element_quadratic import NumberFieldElement_quadratic
#K.<sqrt2> = QuadraticField(2,name='sqrt2')

d1 = 3/5
d3 = 1/10
f = 4/5
p = 15/100
del1 = 4/200
del2 = 4*sqrt(2)/200

d2 = f - d1 - d3

c2 = 0
c3 = -1/(1-f)
c1 = (1-d2*c2-d3*c3)/d1

d12 = d2 / 2
d22 = d2 / 2

d13 = c1 / (c1 - c3) * d12
d43 = d13
d11 = p - d13
d31 = p - d12
d51 = d11
d41 = (d1 - d11 - d31 - d51)/2
d21 = d41
d23 = (d3 - d13 - d43)/2
d33 = d23

del13 = c1 * del1 / (c1 - c3)
del11 = del1 - del13

del23 = c1 * del2 / (c1 - c3)
del21 = del2 - del23

d21new = d21 - del11 - del21
d41new = d41 - del11 - del21
d23new = d23 - del13 - del23
d33new = d33 - del13 - del23

t1 = del1
t2 = del1 + del2
a0 = d11 + d13
a1 = a0 + t1
a2 = a0 + t2
A = a0+d21+d23
A0 = A + d12

slopes = [c1,c3,c1,c3,c1,c3,c1,c3,c2,c1,c2,c3,c1,c3,c1,c3,c1,c3,c1,c3]

interval_lengths = [d11,d13,del11,del13,del21,del23,d21new,d23new,d12,d31,d22,d33new,d41new,del23,del21,del13,del11,d43,d51,1-f]

h = piecewise_function_from_interval_lengths_and_slopes(interval_lengths, slopes)
