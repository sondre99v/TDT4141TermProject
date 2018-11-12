-- *****************************************************************************
-- Name:     mod_exp.vhd   
-- Created:  12.11.18 @ NTNU   
-- Author:   Sondre Ninive Andersen
-- Purpose:  A modular exponentiator.
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

entity mod_exp is
    generic(WORD_WIDTH : integer :=32);
    Port ( 
    clk		     : in  std_logic;
    rst          : in  std_logic;
    start        : in  std_logic;
    inputBase    : in  std_logic_vector(WORD_WIDTH-1 downto 0);
    inputExp     : in  std_logic_vector(WORD_WIDTH-1 downto 0);
    inputModulus : in  std_logic_vector(WORD_WIDTH-1 downto 0);

    result       : out std_logic_vector(WORD_WIDTH-1 downto 0);
    busy         : out std_logic
    );
end mod_mult;

architecture rtl of mod_exp is
	type State_Type is (
		Idle, 
		LoadRegisters,
		UpShiftModulus, 
		ReduceBase,
		InitiateMultiplications, 
		AwaitProducts,
		ExtractProducts
	);
	
	signal State : State_Type;
	signal Result : unsigned(WORD_WIDTH-1 downto 0);
	signal BaseReg : unsigned(WORD_WIDTH-1 downto 0);
	signal ExpReg : unsigned(WORD_WIDTH downto 0);
	signal Modulus : unsigned(WORD_WIDTH-1 downto 0);
	signal Counter : unsigned(integer(ceil(log2(real(WORD_WIDTH))))-1 downto 0);
	
	-- TODO: Add correct entity instantiating, with generics
	mm1: entity mod_mult;
	mm2: entity mod_mult;

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
					if Modulus(WORD_WIDTH-1) = '1' then
						nextState := ReduceBase;
					else
						nextState := UpShiftModulus;
					end if;
					
				when UpShiftModulus =>
					if Modulus(WORD_WIDTH-1) = '1' then
						nextState := ReduceBase;
					end if;
					
				when ReduceBase =>
					if (Counter = 0) then
						nextState := InitiateMultiplications;
					end if;
					
				when InitiateMultiplications =>
					nextState := AwaitProducts;
					
				when AwaitProducts =>
					if !(mm1.Busy or mm2.Busy) then
						nextState := ExtractProducts;
					end if;
					
				when ExtractProducts =>
					if ExpReg = 0 then
						nextState := Idle;
					else
						nextState := InitiateMultiplications;
					end if;
					
				when others =>
					nextState := Idle;
			end case;
			
			-- Handle entry actions for the new state
			case nextState is
				when Idle =>
					Result <= std_logic_vector(mm1.Result);
					Busy <= '0';
					
				when LoadRegisters =>
					BaseReg <= inputBase;
					ExpReg <= inputExp;
					Modulus <= inputModulus;
					Result <= unsigned(1);
					Counter <= unsigned(1);
					Busy <= '1';
					
				when UpShiftModulus =>
					Modulus <= Modulus sll 1;
					Counter <= (Counter + 1);
					
				when ReduceBase =>
					temp := BaseReg - Modulus;
					if (temp(WORD_WIDTH-1)='1') then
						BaseReg <= temp;
					end if;
					if (Counter != unsigned(0)) then
						Modulus <= Modulus sll 1;
					end if;
					Counter <= (Counter - 1);
					
				when InitiateMultiplications =>
					-- These assignments can be removed if
					-- the mm entities are instansiated with 
					-- their inputs always connected to the correct signals
					mm1.inputA <= BaseReg;
					mm1.inputB <= Result;
					mm1.inputModulus <= Modulus;
					mm2.inputA <= BaseReg;
					mm2.inputB <= BaseReg;
					mm2.inputModulus <= Modulus;
					
					if ExpReg(0) = '1' then
						mm1.start <= '1';
					end if;
					mm2.start <= '1';
					
				when AwaitProducts =>
					mm1.start <= '0';
					mm2.start <= '0';
					
				when ExtractProducts =>
					if ExpReg(0) = '1' then
						Result <= mm1.result;
					end if;
					BaseReg <= mm2.result;
					ExpReg <= ExpReg sll 1;
					
				when others =>
					nextState := Idle;
				
			end case;
			
		end if;
		
		State <= nextState;
	end process;
end rtl;