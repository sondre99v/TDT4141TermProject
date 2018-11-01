bitLength = 1024

def mod_mult(a, b, modulus):
    regA = a
    regB = b
    regMod = modulus
    regP = 0

    assert(a < modulus)
    assert(b < modulus)

    for i in range(bitLength-1, -1, -1):
        regP = regP << 1

        temp = regP - regMod
        if (temp >= 0):
            regP = temp

        if (((regB >> i) & 1) > 0):
            regP = regP + regA

        temp = regP - regMod
        if (temp >= 0):
            regP = temp
            
    return regP


def mod_exp(base, exponent, modulus):
    regBase = base
    regExponent = exponent
    regMod = modulus
    regResult = 1

    counter = 1

    while ((regMod >> (bitLength-1)) & 1) == 0:
        regMod = regMod << 1
        counter += 1

    while counter > 0:
        temp = regBase - regMod
        if temp >= 0:
            regBase = temp

        counter -= 1

        if counter > 0:
            regMod = regMod >> 1

    while regExponent > 0:
        if (regExponent & 1) > 0:
            regResult = mod_mult(regBase, regResult, regMod)

        regBase = mod_mult(regBase, regBase, regMod)

        regExponent = regExponent >> 1

    return regResult


def test(a, b, m):
    print('Testing a=' + str(a) + ', b=' + str(b) + ', m=' + str(m))
    testResult = mod_exp(a, b, m)
    correct = pow(a, b, m)
    
    if testResult != correct:
        print('ERROR!!!')
        print(str(a) + ' ^ ' + str(b) +
              ' = ' + str(testResult) +
              ' (should be ' +
              str(correct) + ') mod ' + str(m))
        return False
    else:
        print('CORRECT!!!')
        return True


import random
import math

# Run random tests until something failes
while(True):
    bl = 2**random.randint(2, math.log2(bitLength))
    a = random.randint(0, 2**bl-1)
    b = random.randint(0, 2**bl-1)
    n = random.randint(2, 2**(bl/2)-1)
    if not test(a, b, n):
        break
    
