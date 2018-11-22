-- *****************************************************************************
-- Name:     mod_mult.vhd   
-- Created:  05.11.18 @ NTNU   
-- Author:   Sondre Ninive Andersen
-- Purpose:  Modular multiplication
-- *****************************************************************************

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use IEEE.math_real."ceil";
use IEEE.math_real."log2";


entity mod_mult is
    generic(
        WORD_WIDTH : integer := 256
    );
    Port ( 
        clk		  : in  std_logic;
        reset_n   : in  std_logic;
        start     : in  std_logic;
        inputA    : in  std_logic_vector(WORD_WIDTH-1 downto 0);
        inputB    : in  std_logic_vector(WORD_WIDTH-1 downto 0);
        inputN    : in  std_logic_vector(WORD_WIDTH-1 downto 0);
    
        result    : out std_logic_vector(WORD_WIDTH-1 downto 0);
        busy      : out std_logic
    );
end mod_mult;

architecture rtl of mod_mult is
	type State_Type is (
		Idle, 
		LoadRegisters,
		ShiftProduct, 
		FirstReduction,
		Accumulate, 
		SecondReduction
	);
	
	signal State : State_Type;
	signal Product : unsigned(WORD_WIDTH downto 0):= (others => '0');
	signal FactorA : unsigned(WORD_WIDTH-1 downto 0);
	signal FactorB : unsigned(WORD_WIDTH downto 0);
	signal Modulus : unsigned(WORD_WIDTH-1 downto 0);
	signal Counter : unsigned(integer(ceil(log2(real(WORD_WIDTH)))) downto 0);
    
    signal AdderResult : unsigned(WORD_WIDTH downto 0);
    signal AdderInputB : unsigned(WORD_WIDTH downto 0);
    signal AdderCarryIn : unsigned(0 downto 0);
begin
    AdderResult <= Product + AdderInputB + AdderCarryIn;
    
    process(State, Modulus, FactorA) begin
        if (State = ShiftProduct or State = Accumulate) then
            -- Setup adder to subtract the modulus
            AdderInputB <= not unsigned('0' & Modulus);
            AdderCarryIn <= to_unsigned(1, 1);
        elsif (State = FirstReduction) then
            -- Setup adder to add factor A
            AdderInputB <= unsigned('0' & FactorA);
            AdderCarryIn <= to_unsigned(0, 1);
        else
            AdderInputB <= (others => '0');
            AdderCarryIn <= (others => '0');
        end if;
    end process;
    
	process(clk, reset_n)
        --Variables inside processes
        variable nextState : State_Type;
        variable temp : unsigned(WORD_WIDTH downto 0) := (others => '0');
	begin
		nextState := State;
		
		if(reset_n = '0') then
			nextState := Idle;
		elsif rising_edge(clk) then
            
			-- Handle state transitions
			case State is
				when Idle =>
					if (Start = '1') then
						nextState := LoadRegisters;
					end if;
					
				when LoadRegisters =>
					nextState := ShiftProduct;
					
				when ShiftProduct =>
					nextState := FirstReduction;
					
				when FirstReduction =>
				    temp := shift_right(FactorB, WORD_WIDTH);
					if (temp > to_unsigned(0, temp'length)) then
						nextState := Accumulate;
					else
						if (Counter = WORD_WIDTH) then
							nextState := Idle;
						else
							nextState := ShiftProduct;
						end if;
					end if;
					
				when Accumulate =>
					nextState := SecondReduction;
					
				when SecondReduction =>
					if (Counter = WORD_WIDTH) then
						nextState := Idle;
					else
						nextState := ShiftProduct;
					end if;
					
				when others =>
					nextState := Idle;
			end case;
			
			-- Handle entry actions for the new state
			case nextState is
				when Idle =>
					result <=  std_logic_vector(Product(WORD_WIDTH-1 downto 0));
					busy <= '0';
					
				when LoadRegisters =>
					Product <=(others => '0');
					FactorA <= unsigned(inputA);
					FactorB <= unsigned('0' & inputB);
					Modulus <= unsigned(inputN);
					Counter <= to_unsigned(0, Counter'length);
					busy <= '1';
				
				when ShiftProduct =>
					Product <= shift_left(Product, 1);
					Counter <= (Counter + 1);
					
				when FirstReduction =>
					FactorB <= shift_left(FactorB, 1);
					--temp := Product - unsigned('0' & Modulus);
					--if (temp(WORD_WIDTH) = '0') then
					--	Product <= temp;
					--end if;
					if (AdderResult(WORD_WIDTH) = '0') then
					   Product <= AdderResult;
					end if;
				    
				when Accumulate =>
					--Product <= Product + unsigned('0' & FactorA);
				    Product <= AdderResult;
				    
				when SecondReduction =>
					--temp := Product - unsigned('0' & Modulus);
					--if (temp(WORD_WIDTH) = '0') then
					--	Product <= temp;
					--end if;
				    
                    if (AdderResult(WORD_WIDTH) = '0') then
                       Product <= AdderResult;
                    end if;
			end case;
		end if;
		
		State <= nextState;
	end process;
end rtl;
