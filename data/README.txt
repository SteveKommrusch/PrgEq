Problems used as real-world examples:
  Problems from:
     https://www.khanacademy.org/math/precalculus/x9e81a4f98389efdf:matrices/x9e81a4f98389efdf:properties-of-matrix-multiplication/a/properties-of-matrix-multiplication
       Problem 2 find expressions that are equal to A(B+C)
         o AB+AC
         o A(C+B)
       Problem 3 find expressions that are equal to I(AB)
         o AB
         o (AB)I
       Problem 4 find expressions that are equal to O(A+B)
         o O
         o (A+B)O
     https://www.khanacademy.org/math/precalculus/x9e81a4f98389efdf:matrices/x9e81a4f98389efdf:properties-of-matrix-addition-and-scalar-multiplication/a/properties-of-matrix-scalar-multiplication
       Problem 1 find expressions that are equal to c(1A+B)
         o cA+cB
         o cB+cA
       Problem 2 find expressions that are equal to (cd)A+0A
         o c(dA)
         o (cd+0)A
  Also, 5 non-equivalent pairs from the above are selected.

Sympy testing:  

import sympy
import timeit
from sympy import MatAdd, MatrixSymbol, MatMul, Identity
A = MatrixSymbol('A',2,2)
B = MatrixSymbol('B',2,2)
C = MatrixSymbol('C',2,2)
D = MatrixSymbol('D',2,2)
E = MatrixSymbol('E',2,2)
v = MatrixSymbol('v',2,1)
w = MatrixSymbol('w',2,1)
x = MatrixSymbol('x',2,1)
y = MatrixSymbol('y',2,1)
z = MatrixSymbol('z',2,1)
I = Identity(2)
def check():
  return sympy.simplify("( ( ( ( ( d / c ) - ( d / b ) ) - ( ( e * a ) + ( d * a ) ) ) / d ) + ( ( ( d * ( ( b + b ) * c ) ) / a ) * ( ( - e ) + ( ( a / b ) + d ) ) ) ) - ( ( ( ( ( d / c ) / d ) - ( ( d / b ) / d ) ) - ( ( ( e * a ) / d ) + ( ( d * a ) / d ) ) ) + ( ( ( ( ( d * b ) * c ) / a ) + ( ( ( d * b ) * c ) / a ) ) * ( d + ( ( a / b ) + ( - e ) ) ) ) )")

timeit.timeit(check,number=1)
0.0317497868090868
def check():
  return sympy.simplify("a - a")

timeit.timeit(check,number=1)
0.0013964297249913216
def check():
  return sympy.simplify("( ( ( ( ( C - D ) * x ) + ( ( e - c ) * x ) ) - ( - ( ( 1/ d ) * ( w - v ) ) ) ) + ( ( ( ( ( a * e ) * c ) / ( d + 0 ) ) * ( - ( a * ( z - z ) ) ) ) + v ) ) - ( ( ( ( ( ( C * x ) - ( D * x ) ) + ( ( e * x ) - ( c * x ) ) ) + ( ( ( 1/ d ) * w ) - ( ( 1/ d ) * v ) ) ) + ( ( ( c * ( a * e ) ) / d ) * ( - ( a * ( z - z ) ) ) ) ) + v )")

timeit.timeit(check,number=1)
0.022709101904183626

Approximate count for 5 axioms using a program with 10 possible axioms:
(base) lion:~$ perl -e 'for ($a=1; $a < 11; $a++) { for ($b=1; $b<11; $b++) { for ($c=1; $c<11; $c++) { for ($d=1; $d<11; $d++) { for ($e=1; $e<11; $e++) { if ($a >= $b && $b>= $c && $c >= $d && $d>=$e) { $t++; } } } } } }; print $t."\n";'
2002 = (10 + 5 - 1)!/((10-1)!5!)

