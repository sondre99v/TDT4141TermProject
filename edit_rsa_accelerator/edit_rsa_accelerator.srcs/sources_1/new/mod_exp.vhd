-- *****************************************************************************
-- Name:     mod_exp.vhd   
-- Created:  12.11.18 @ NTNU   
-- Author:   Sondre Ninive Andersen, Wesley Ryan Paintsil
-- Purpose:  Modular exponentiation
-- *****************************************************************************

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use IEEE.math_real."ceil";
use IEEE.math_real."log2";


entity mod_exp is
    generic(
        WORD_WIDTH   : integer := 256
    );
    Port ( 
        -- Clock and reset inputs
        clk		     : in std_logic;
        reset_n      : in std_logic;
        
        -- Argument inputs
        inputBase    : in std_logic_vector(WORD_WIDTH-1 downto 0);
        inputExp     : in std_logic_vector(WORD_WIDTH-1 downto 0);
        inputModulus : in std_logic_vector(WORD_WIDTH-1 downto 0);
        
        -- Result output
        result       : out std_logic_vector(WORD_WIDTH-1 downto 0);
        
        -- Tag, used to keep track of metadata about the job
        inputTag     : in std_logic_vector(31 downto 0);
        outputTag    : out std_logic_vector(31 downto 0);
        
        -- Control signals
        start        : in std_logic;    -- When high, inputs will be latched, and a new job will be started
        busy         : out std_logic;   -- When high, the component is working on a job
        ready        : out std_logic;   -- When high, the component is ready to start a new job
        retreive     : in std_logic     -- When high, the component will consider the result as read, and will allow a new job to start
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
		ExtractProducts,
		ResultReady
	);
	
	-- Registers used during the computation
	signal State : State_Type;
	signal ResultReg : unsigned(WORD_WIDTH-1 downto 0);
	signal BaseReg : unsigned(WORD_WIDTH-1 downto 0);
	signal ExpReg : unsigned(WORD_WIDTH downto 0);
	signal Modulus : unsigned(WORD_WIDTH downto 0);
	signal Counter : unsigned(integer(ceil(log2(real(WORD_WIDTH))))-1 downto 0);
	signal Tag : std_logic_vector(31 downto 0);
	
	-- mm1 signals
    signal i_start_mm1 : std_logic:='0';
    signal o_result_mm1 : std_logic_vector(WORD_WIDTH-1 downto 0);
    signal o_busy_mm1 : std_logic;
    
    -- mm2 signals
    signal i_start_mm2 : std_logic:='0';
    signal o_result_mm2 : std_logic_vector(WORD_WIDTH-1 downto 0);
    signal o_busy_mm2 : std_logic;
    
begin
    -- Instansiate modular multiplier to multiply in factors to the accumulator
    mm1: entity work.mod_mult
    generic map (
        WORD_WIDTH => WORD_WIDTH
    )
    port map (
        clk => clk,
        reset_n => reset_n,
        start => i_start_mm1,
        inputA => std_logic_vector(BaseReg),
        inputB => std_logic_vector(ResultReg),
        inputN => std_logic_vector(Modulus(WORD_WIDTH-1 downto 0)),
        result => o_result_mm1,
        busy => o_busy_mm1
    );
    
    -- Instansiate modular multiplier to square the base register
    mm2: entity work.mod_mult
    generic map (
        WORD_WIDTH => WORD_WIDTH
    )
    port map (
        clk => clk,
        reset_n => reset_n,
        start => i_start_mm2,
        inputA => std_logic_vector(BaseReg),
        inputB => std_logic_vector(BaseReg),
        inputN => std_logic_vector(Modulus(WORD_WIDTH-1 downto 0)),
        result => o_result_mm2,
        busy => o_busy_mm2
    );
    
    -- Combinational computation of control signals
    ready <= '1' when (State = Idle) else '0';
    busy <= '0' when (State = Idle or State = ResultReady) else '1';
    i_start_mm1 <= '1' when (State = InitiateMultiplications and ExpReg(0) = '1') else '0';
    i_start_mm2 <= '1' when (State = InitiateMultiplications) else '0';
    
    -- Process to handle FSM
	process(clk, reset_n)
		variable nextState : State_Type;
		variable temp : unsigned(WORD_WIDTH downto 0);
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
					if (Counter = 0) then
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
						nextState := ResultReady;
					else
						nextState := InitiateMultiplications;
					end if;
					
				when ResultReady =>
				    if retreive = '1' then
				        nextState := Idle;
				    end if;
				    
				when others =>
					nextState := Idle;
			end case;
			
			-- Handle entry actions for the new state
			case nextState is
				when Idle =>
					--No action
					
				when LoadRegisters =>
					BaseReg <= unsigned(inputBase);
					ExpReg <= unsigned('0' & inputExp);
					Modulus <= unsigned('0' & inputModulus);
					ResultReg <= to_unsigned(1,ResultReg'length);
					Counter <= to_unsigned(1,Counter'length);
					Tag <= inputTag;
					
				when UpShiftModulus =>
					Modulus <= shift_left(Modulus, 1);
					Counter <= (Counter + 1);
					
				when ReduceBase =>
				    -- Subtract modulus from base if base > modulus
					temp := unsigned('0' & BaseReg) - Modulus;
					if (temp(WORD_WIDTH) = '0') then
						BaseReg <= temp(WORD_WIDTH-1 downto 0);
					end if;
					
					if (Counter /= 1) then
						Modulus <= shift_right(Modulus, 1);
					end if;
					Counter <= (Counter - 1);
					
				when InitiateMultiplications =>
					-- No action
					
				when AwaitProducts =>
					-- No action
					
				when ExtractProducts =>
					if ExpReg(0) = '1' then
						ResultReg <= unsigned(o_result_mm1);
					end if;
					BaseReg <= unsigned(o_result_mm2);
					ExpReg <= shift_right(ExpReg,1);
                                        
                when ResultReady =>
                    result <= o_result_mm1;
                    outputTag <= Tag;
					
				when others =>
					nextState := Idle;
				
			end case;
		end if;
		
		State <= nextState;
	end process;
end rtl;
