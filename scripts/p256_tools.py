p=0xffffffff00000001000000000000000000000000ffffffffffffffffffffffff

def evaluate(x, n):
  total = 0
  i = 0
  base = 2**n
  for t in x:
    if t > 10944121435919637611123202872628637544274182200208017171849102093287904247808:
      total -= (p-t)*(base**i)
    else:
      total += t*(base**i)
    i += 1
  return total

def get_representation(x, n, k):
  return [(x >> (n*i)) % 2**n for i in range(0,k)]