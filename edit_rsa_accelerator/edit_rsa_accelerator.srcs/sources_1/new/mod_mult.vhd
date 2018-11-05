----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05.11.2018 00:49:23
-- Design Name: 
-- Module Name: mod_mult - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity mod_mult is
    generic(WORD_WIDTH : integer :=32);
    Port ( clk : in STD_LOGIC;
           rst : in STD_LOGIC;
           start : in STD_LOGIC;
           inputA : in STD_LOGIC;
           inputB : in STD_LOGIC;
           inputN : in STD_LOGIC;
           result : out STD_LOGIC;
           busy : out STD_LOGIC);
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
	process(clk, rst) 
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
					Result <= Product;
					Busy <= 0;
					
				when LoadRegisters =>
					Product <= 0;
					FactorA <= inputA;
					FactorB <= 0 & inputB;
					Modulus <= inputN;
					Counter <= 0;
					Busy <= '1';
				
				when ShiftProduct =>
					Product <= (Product << 1);
					Counter <= Counter + 1);
					
				when FirstReduction =>
					FactorB <= FactorB << 1;
					temp := Product - Modulus;
					if (temp(WORD_WIDTH-1)) then
						Product <= temp;
					end if;
				
				when Accumulate =>
					Product <= Product + FactorA;
				
				when SecondReduction =>
					temp := Product - Modulus;
					if (temp(WORD_WIDTH-1)) then
						Product <= temp;
					end if;
				
			end case;
			
		end if;
		
		State <= nextState;
	end process;
end rtl;
