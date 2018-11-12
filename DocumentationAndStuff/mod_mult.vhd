-- *****************************************************************************
-- Name:     mod_mult.vhd   
-- Created:  18.10.18 @ NTNU   
-- Author:   Sondre Ninive Andersen
-- Purpose:  A modular multiplier.
-- *****************************************************************************

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use IEEE.math_real."ceil";
use IEEE.math_real."log2";
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity mod_mult is
    generic(WORD_WIDTH : integer := 32);
    Port ( 
    clk		  : in  std_logic;
    rst       : in  std_logic;
    start     : in  std_logic;
    inputA    : in  std_logic_vector(WORD_WIDTH-1 downto 0);
    inputB    : in  std_logic_vector(WORD_WIDTH-1 downto 0);
    inputN    : in  std_logic_vector(WORD_WIDTH-1 downto 0);

    result    : out std_logic_vector(WORD_WIDTH-1 downto 0);
    busy    : out std_logic
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
	signal Product : unsigned(WORD_WIDTH-1 downto 0);
	signal FactorA : unsigned(WORD_WIDTH-1 downto 0);
	signal FactorB : unsigned(WORD_WIDTH downto 0);
	signal Modulus : unsigned(WORD_WIDTH-1 downto 0);
	signal Counter : unsigned(integer(ceil(log2(real(WORD_WIDTH))))-1 downto 0);
	

begin
	process(clk, rst, State) 
	--Variables inside processes
    variable nextState : State_Type;
    variable temp : unsigned(WORD_WIDTH-1 downto 0);
	begin
		nextState := State;
		
		if(rst = '1') then
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
					if FactorB(WORD_WIDTH) = '1' then
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
					Result <=  std_logic_vector(Product);
					Busy <= '0';
					
				when LoadRegisters =>
					Product <= to_unsigned(0, Product'length);
					FactorA <= unsigned(inputA);
					FactorB <= unsigned('0' & inputB);
					Modulus <= unsigned(inputN);
					Counter <= to_unsigned(0, Counter'length);
					Busy <= '1';
				
				when ShiftProduct =>
					Product <= (Product sll 1);
					Counter <= (Counter + 1);
					
				when FirstReduction =>
					FactorB <= FactorB sll 1;
					temp := Product - Modulus;
					if (temp(WORD_WIDTH-1)='1') then
						Product <= temp;
					end if;
				
				when Accumulate =>
					Product <= Product + FactorA;
				
				when SecondReduction =>
					temp := Product - Modulus;
					if (temp(WORD_WIDTH-1)='1') then
						Product <= temp;
					end if;
				
			end case;
			
		end if;
		
		State <= nextState;
	end process;
end rtl;