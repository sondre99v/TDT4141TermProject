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
--use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity mod_exp is
    generic(WORD_WIDTH : integer :=256);
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
end mod_exp;

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
	
	 component mod_mult 
       port (
       clk          : in  std_logic;
       rst_n       : in  std_logic;
       start     : in  std_logic;
       inputA    : in  std_logic_vector(WORD_WIDTH-1 downto 0);
       inputB    : in  std_logic_vector(WORD_WIDTH-1 downto 0);
       inputN    : in  std_logic_vector(WORD_WIDTH-1 downto 0);
   
       o_result    : out std_logic_vector(WORD_WIDTH-1 downto 0);
       o_busy   : out std_logic
       );
       end component;
	
	signal State : State_Type;
	signal ResultReg : unsigned(WORD_WIDTH-1 downto 0);
	signal BaseReg : unsigned(WORD_WIDTH-1 downto 0);
	signal ExpReg : unsigned(WORD_WIDTH downto 0);
	signal Modulus : unsigned(WORD_WIDTH downto 0); --remove /add -1
	signal Counter : unsigned(integer(ceil(log2(real(WORD_WIDTH))))-1 downto 0);
	
	--mm1 signals
	--inputs
    signal i_start_mm1     :   std_logic:='0';
    signal inputA_mm1    :   std_logic_vector(WORD_WIDTH-1 downto 0):=(others =>'0');
    signal inputB_mm1    :   std_logic_vector(WORD_WIDTH-1 downto 0):=(others =>'0');
    signal inputN_mm1    :   std_logic_vector(WORD_WIDTH-1 downto 0):=(others =>'0');
     
    --outputs
    signal o_result_mm1 : std_logic_vector(WORD_WIDTH-1 downto 0);
    signal o_busy_mm1 : std_logic;
    
    --mm1 signals
    --inputs
    signal i_start_mm2     :   std_logic:='0';
    signal inputA_mm2    :   std_logic_vector(WORD_WIDTH-1 downto 0):=(others =>'0');
    signal inputB_mm2    :   std_logic_vector(WORD_WIDTH-1 downto 0):=(others =>'0');
    signal inputN_mm2    :   std_logic_vector(WORD_WIDTH-1 downto 0):=(others =>'0');
     
    --outputs
    signal o_result_mm2 : std_logic_vector(WORD_WIDTH-1 downto 0);
    signal o_busy_mm2 : std_logic;
       
       
	
	

begin
    --connections
    mm1: mod_mult port map (
        clk=>clk,
        rst_n=>rst,
        start=>i_start_mm1,
        inputA=>inputA_mm1,
        inputB=>inputB_mm1,
        inputN=>inputN_mm1,
        o_result=>o_result_mm1,
        o_busy=>o_busy_mm1
        );
    mm2: mod_mult port map (
            clk=>clk,
            rst_n=>rst,
            start=>i_start_mm2,
            inputA=>inputA_mm2,
            inputB=>inputB_mm2,
            inputN=>inputN_mm2,
            o_result=>o_result_mm2,
            o_busy=>o_busy_mm2
            );
	process(clk, rst, State) 
		--Variables inside processes
		variable nextState : State_Type;
		variable temp : unsigned(WORD_WIDTH downto 0):=(others => '0'); --make wordwidt-1
	begin
		nextState := State;
		
		if(rst = '0') then
			nextState := Idle;
			--result    <=(others => '0');
            busy   <='0';
		elsif rising_edge(clk) then
		
			-- Handle state transitions
			case State is
				when Idle =>
					if (Start = '1') then
						nextState := LoadRegisters;
					end if;

				when LoadRegisters =>
					if (Modulus(WORD_WIDTH-1) = '1') then
						nextState := ReduceBase;
					else
						nextState := UpShiftModulus;
					end if;
					
				when UpShiftModulus =>
					if (Modulus(WORD_WIDTH-1) = '1') then
						nextState := ReduceBase;
					else
					   nextState := UpShiftModulus;
					end if;
					
				when ReduceBase =>
					if (Counter = 0) then -- counter 1 
						nextState := InitiateMultiplications;
					end if;
					
				when InitiateMultiplications =>
					nextState := AwaitProducts;
					
				when AwaitProducts =>
					if ((o_busy_mm1 or o_busy_mm2)='0') then
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
					result <= o_result_mm1;
					busy <= '0';
					
				when LoadRegisters =>
					BaseReg <= unsigned(inputBase);
					ExpReg <= unsigned('0' & inputExp);
					Modulus <= unsigned('0' & inputModulus); -- remove '0'
					ResultReg <= to_unsigned(1,ResultReg'length);
					Counter <= to_unsigned(1,Counter'length);
					busy <= '1';
					
				when UpShiftModulus =>
					Modulus <= shift_left(Modulus,1);
					Counter <= (Counter + 1);
					
				when ReduceBase =>
					temp := unsigned('0' & BaseReg) - Modulus;
					if (temp(WORD_WIDTH)='0') then --add -1
						BaseReg <= temp(WORD_WIDTH-1 downto 0); --remove downto
					end if;
					
					if ((Counter /= 1)) then --/=0
						Modulus <= shift_right(Modulus,1);
					end if;
					Counter <= (Counter - 1);
					
					
				when InitiateMultiplications =>
					-- These assignments can be removed if
					-- the mm entities are instansiated with 
					-- their inputs always connected to the correct signals
					inputA_mm1 <= std_logic_vector(BaseReg);
					inputB_mm1 <= std_logic_vector(ResultReg);
					inputN_mm1 <= std_logic_vector(Modulus(WORD_WIDTH-1 downto 0));
					inputA_mm2 <= std_logic_vector(BaseReg);
					inputB_mm2 <= std_logic_vector(BaseReg);
					inputN_mm2 <= std_logic_vector(Modulus(WORD_WIDTH-1 downto 0));
					inputN_mm2 <= std_logic_vector(Modulus(WORD_WIDTH-1 downto 0));
					
					if ExpReg(0) = '1' then
						i_start_mm1 <= '1';
					end if;
					i_start_mm2 <= '1';
					
				when AwaitProducts =>
					i_start_mm1 <= '0';
					i_start_mm2 <= '0';
					
				when ExtractProducts =>
					if ExpReg(0) = '1' then
						ResultReg <= unsigned(o_result_mm1);
					end if;
					BaseReg <= unsigned(o_result_mm2);
					ExpReg <= shift_right(ExpReg,1);
					
				when others =>
					nextState := Idle;
				
			end case;
			
		end if;
		
		State <= nextState;
	end process;
end rtl;