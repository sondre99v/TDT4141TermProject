k = 64

MMSTATE_IDLE = 1
MMSTATE_LOAD_REGS = 2
MMSTATE_SHIFT_PRODUCT = 3
MMSTATE_FIRST_REDUCTION = 4
MMSTATE_ACCUMULATE = 5
MMSTATE_SECOND_REDUCTION = 6

mm1_Start = 0
mm1_InputA = 0
mm1_InputB = 0
mm1_InputN = 0
mm1_state = MMSTATE_IDLE
mm1_Result = 0
mm1_Busy = 0
mm1_P = 0
mm1_A = 0
mm1_B = 0
mm1_N = 0
mm1_C = 0


def fsm_change_state(new_state):
    global mm1_state
    global mm1_Result
    global mm1_Busy
    global mm1_P
    global mm1_A
    global mm1_B
    global mm1_N
    global mm1_C
    
    mm1_state = new_state

    if new_state == MMSTATE_IDLE:
        mm1_Result = mm1_P
        mm1_Busy = 0
        print('New state IDLE')

    elif new_state == MMSTATE_LOAD_REGS:
        mm1_P = 0
        mm1_A = mm1_InputA
        mm1_B = mm1_InputB
        mm1_N = mm1_InputN
        mm1_C = 0
        mm1_Busy = 1
        print('New state LOAD_REGS')

    elif new_state == MMSTATE_SHIFT_PRODUCT:
        mm1_P = mm1_P << 1
        mm1_C = mm1_C + 1
        print('New state SHIFT_PRODUCT')

    elif new_state == MMSTATE_FIRST_REDUCTION:
        temp = mm1_P - mm1_N
        if temp >= 0:
            mm1_P = temp
        mm1_B = (mm1_B << 1) & ((1 << (k + 1)) - 1)
        print('New state FIRST_REDUCTION')

    elif new_state == MMSTATE_ACCUMULATE:
        mm1_P = mm1_P + mm1_A
        print('New state ACCUMULATE')

    elif new_state == MMSTATE_SECOND_REDUCTION:
        temp = mm1_P - mm1_N
        if temp >= 0:
            mm1_P = temp
        print('New state SECOND_REDUCTION')

    print('P = ' + str(mm1_P))
    return


def mod_mult_fsm_step():
    if mm1_state == MMSTATE_IDLE:
        if mm1_Start == 1:
            print('Enter')
            fsm_change_state(MMSTATE_LOAD_REGS)
            print('BusyFSM1: ' + str(mm1_Busy))

    elif mm1_state == MMSTATE_LOAD_REGS:
        fsm_change_state(MMSTATE_SHIFT_PRODUCT)

    elif mm1_state == MMSTATE_SHIFT_PRODUCT:
        fsm_change_state(MMSTATE_FIRST_REDUCTION)

    elif mm1_state == MMSTATE_FIRST_REDUCTION:
        if (mm1_B >> k) > 0:
            fsm_change_state(MMSTATE_ACCUMULATE)
        elif mm1_C < k:
            fsm_change_state(MMSTATE_SHIFT_PRODUCT)
        else:
            fsm_change_state(MMSTATE_IDLE)

    elif mm1_state == MMSTATE_ACCUMULATE:
        fsm_change_state(MMSTATE_SECOND_REDUCTION)

    elif mm1_state == MMSTATE_SECOND_REDUCTION:
        if mm1_C < k:
            fsm_change_state(MMSTATE_SHIFT_PRODUCT)
        else:
            fsm_change_state(MMSTATE_IDLE)
    return


# Start
for i in range(10):
    mod_mult_fsm_step()

# 123 * 19 = 27 (mod 33)
mm1_InputA = 123
mm1_InputB = 19
mm1_InputN = 33
mm1_Start = 1

mod_mult_fsm_step()

while mm1_Busy > 0:
    mod_mult_fsm_step()

print(mm1_Result)
print('Should be: ' + str(((mm1_InputA * mm1_InputB) % mm1_InputN)))
#print(str(mm1_InputA) + ':' + str(mm1_InputB) + ':' + str(mm1_InputN))
