k = 256

MMSTATE_IDLE = 1
MMSTATE_LOAD_REGS = 2
MMSTATE_SHIFT_PRODUCT = 3
MMSTATE_FIRST_REDUCTION = 4
MMSTATE_ACCUMULATE = 5
MMSTATE_SECOND_REDUCTION = 6

VERBOSE = False

def testBit(v, b):
    return ((v >> b) & 1) != 0

class mod_mult_fsm:
    InStart = 0
    InA = 0
    InB = 0
    InN = 0
    OutResult = 0
    OutBusy = 0
    state = MMSTATE_IDLE
    P = 0
    A = 0
    B = 0
    N = 0
    C = 0

    def change_state(self, new_state):
        self.state = new_state

        if new_state == MMSTATE_IDLE:
            self.OutResult = self.P
            self.OutBusy = 0
            if (VERBOSE): print('New state IDLE')


        elif new_state == MMSTATE_LOAD_REGS:
            self.P = 0
            self.A = self.InA
            self.B = self.InB
            self.N = self.InN
            self.C = 0
            self.OutBusy = 1
            if (VERBOSE): print('New state LOAD_REGS')


        elif new_state == MMSTATE_SHIFT_PRODUCT:
            self.P = self.P << 1
            self.C = self.C + 1
            if (VERBOSE): print('New state SHIFT_PRODUCT')


        elif new_state == MMSTATE_FIRST_REDUCTION:
            temp = self.P - self.N
            if temp >= 0:
                self.P = temp
            self.B = (self.B << 1) & ((1 << (k + 1)) - 1)
            if (VERBOSE): print('New state FIRST_REDUCTION')


        elif new_state == MMSTATE_ACCUMULATE:
            self.P = self.P + self.A
            if (VERBOSE): print('New state ACCUMULATE')


        elif new_state == MMSTATE_SECOND_REDUCTION:
            temp = self.P - self.N
            if temp >= 0:
                self.P = temp
            if (VERBOSE): print('New state SECOND_REDUCTION')


        if (VERBOSE): print('P = ' + str(self.P))
        return


    def step(self):
        if self.state == MMSTATE_IDLE:
            if self.InStart == 1:
                self.change_state(MMSTATE_LOAD_REGS)

        elif self.state == MMSTATE_LOAD_REGS:
            self.change_state(MMSTATE_SHIFT_PRODUCT)

        elif self.state == MMSTATE_SHIFT_PRODUCT:
            self.change_state(MMSTATE_FIRST_REDUCTION)

        elif self.state == MMSTATE_FIRST_REDUCTION:
            if testBit(self.B, k):
                self.change_state(MMSTATE_ACCUMULATE)
            elif self.C < k:
                self.change_state(MMSTATE_SHIFT_PRODUCT)
            else:
                self.change_state(MMSTATE_IDLE)

        elif self.state == MMSTATE_ACCUMULATE:
            self.change_state(MMSTATE_SECOND_REDUCTION)

        elif self.state == MMSTATE_SECOND_REDUCTION:
            if self.C < k:
                self.change_state(MMSTATE_SHIFT_PRODUCT)
            else:
                self.change_state(MMSTATE_IDLE)
        else:
            print("ModMult: Unexpected state \"" + str(self.state) + "\"!")
# end class mod_mult_fsm


class mod_exp_fsm:
    InStart = 0
    InBase = 0
    InExp = 0
    InModulus = 0
    OutResult = 0
    OutBusy = 0
    state = "Idle"
    R = 0
    B = 0
    E = 0
    N = 0
    i = 0
    mm1 = mod_mult_fsm()
    mm2 = mod_mult_fsm()

    def change_state(self, new_state):
        self.state = new_state

        if self.state == "Idle":
            self.OutResult = self.mm1.OutResult
            self.OutBusy = 0

            
        elif self.state == "LoadRegisters":
            self.B = self.InBase
            self.E = self.InExp
            self.N = self.InModulus
            self.R = 1
            self.i = 1
            self.OutBusy = 1

            
        elif self.state == "UpShiftModulus":
            self.N = (self.N << 1)
            self.i += 1

            
        elif self.state == "ReduceBase":
            temp = self.B - self.N
            if temp >= 0:
                self.B = temp
            self.i -= 1
            if self.i != 0:
                self.N = self.N >> 1

            
        elif self.state == "InitiateMultiplications":
            self.mm1.InA = self.B
            self.mm1.InB = self.R
            self.mm1.InN = self.N
            if testBit(self.E, 0):
                self.mm1.InStart = 1
                
            self.mm2.InA = self.B
            self.mm2.InB = self.B
            self.mm2.InN = self.N
            self.mm2.InStart = 1
            
            
        elif self.state == "AwaitProducts":
            self.mm1.InStart = 0
            self.mm2.InStart = 0

            
        elif self.state == "ExtractProducts":
            if testBit(self.E, 0):
                self.R = self.mm1.OutResult
            self.B = self.mm2.OutResult
            self.E = self.E >> 1

            
        else:
            print("ModExp: Unexpected state \"" + self.state + "\"!")

    def step(self):
        if self.state == "Idle":
            if self.InStart == 1:
                self.change_state("LoadRegisters")
                
        elif self.state == "LoadRegisters":
            if testBit(self.N, k-1):
                self.change_state("ReduceBase")
            else:
                self.change_state("UpShiftModulus")
            
        elif self.state == "UpShiftModulus":
            if testBit(self.N, k-1):
                self.change_state("ReduceBase")
            else:
                self.change_state("UpShiftModulus")
            
            
        elif self.state == "ReduceBase":
            if self.i == 0:
                self.change_state("InitiateMultiplications")
            else:
                self.change_state("ReduceBase")
            
        elif self.state == "InitiateMultiplications":
            self.change_state("AwaitProducts")
            
        elif self.state == "AwaitProducts":
            if not (self.mm1.OutBusy or self.mm2.OutBusy):
                self.change_state("ExtractProducts")
            
        elif self.state == "ExtractProducts":
            if self.E == 0:
                self.change_state("Idle")
            else:
                self.change_state("InitiateMultiplications")
        else:
            print("ModExp: Unexpected state \"" + self.state + "\"!")

        self.mm1.step()
        self.mm2.step()
    
# end class mod_exp_fsm


# InStart

from random import randint

me1 = mod_exp_fsm()

while True:
    # Idle step for 10 cycles
    for i in range(10):
        me1.step()

    # Set inputs
    me1.InBase = randint(0, (2**k)-1)
    me1.InExp = randint(0, (2**k)-1)
    me1.InModulus = randint(2, (2**k)-1)
    me1.InStart = 1

    # Step once to allow OutBusy to rise
    me1.step()
    me1.InStart = 0

    # Step until operation is done
    while me1.OutBusy:
        me1.step()

    # Print result
    shouldBe = pow(me1.InBase, me1.InExp, me1.InModulus)
    print('OutResult1: ' + str(me1.OutResult))
    print('Should be: ' + str(shouldBe))
    assert(me1.OutResult == shouldBe)

