--------------------------------------------------------------------------------
-- Author       : Wesley Ryan Paintsil, Sondre Ninive Andersen
-- Organization : Norwegian University of Science and Technology (NTNU)
--                Department of Electronic Systems
--                https://www.ntnu.edu/ies
-- Course       : TFE4141 Design of digital systems 1 (DDS1)
-- Year         : 2018
-- Project      : RSA accelerator
-- License      : This is free and unencumbered software released into the 
--                public domain (UNLICENSE)
--------------------------------------------------------------------------------
-- Purpose: 
--   RSA encryption core. This core computes
--   C = M**key_e mod key_n.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;


entity rsa_core is
    generic (
        C_BLOCK_SIZE           : integer := 256
	);
    port (
        -----------------------------------------------------------------------------
        -- Clocks and reset
        -----------------------------------------------------------------------------      
        clk                    :  in std_logic;
        reset_n                :  in std_logic;
          
        -----------------------------------------------------------------------------
        -- Slave msgin interface
        -----------------------------------------------------------------------------
        -- Message that will be sent out is valid
        msgin_valid            : in std_logic;   
        -- Slave ready to accept a new message
        msgin_ready            : out std_logic;
        -- Message that will be sent out of the rsa_msgin module
        msgin_data             :  in std_logic_vector(C_BLOCK_SIZE-1 downto 0);
        -- Indicates boundary of last packet
        msgin_last             :  in std_logic;
        
        -----------------------------------------------------------------------------
        -- Master msgout interface
        -----------------------------------------------------------------------------
        -- Message that will be sent out is valid
        msgout_valid            : out std_logic;   
        -- Slave ready to accept a new message
        msgout_ready            :  in std_logic;
        -- Message that will be sent out of the rsa_msgin module
        msgout_data             : out std_logic_vector(C_BLOCK_SIZE-1 downto 0);
        -- Indicates boundary of last packet
        msgout_last             : out std_logic;
    
        -----------------------------------------------------------------------------
        -- Interface to the register block
        -----------------------------------------------------------------------------    
        key_e_d                 :  in std_logic_vector(C_BLOCK_SIZE-1 downto 0);
        key_n                   :  in std_logic_vector(C_BLOCK_SIZE-1 downto 0);
        rsa_status              :  out std_logic_vector(31 downto 0)    
          
    );
end rsa_core;

architecture rtl of rsa_core is
    constant C_NUM_CORES : natural := 8;
    
    -- Core Interface Signals
    type dataWordArray  is array (C_NUM_CORES-1 downto 0) of std_logic_vector(C_BLOCK_SIZE-1 downto 0);
    type ctrlWordArray  is array (C_NUM_CORES-1 downto 0) of std_logic_vector(31 downto 0);
    type signalArray    is array (C_NUM_CORES-1 downto 0) of std_logic;
    
    signal core_result   : dataWordArray;
    signal core_busy     : signalArray;
    signal core_start    : signalArray;
    signal core_tag_in   : ctrlWordArray;
    signal core_tag_out  : ctrlWordArray;
    signal core_ready    : signalArray;
    signal core_retreive : signalArray;
    
    -- Dispatcher signals
    signal free_core    : std_logic;
    signal start_new_job: std_logic;
    signal new_job_done : std_logic;
    signal next_id_in   : std_logic_vector(30 downto 0); -- ID of next incoming job
    signal next_id_out  : std_logic_vector(30 downto 0); -- ID of next job to be sent out
    
begin
    -- Instansiate Cores
    g_GEN_CORES: for i in 0 to C_NUM_CORES-1 generate
    begin
        me: entity work.mod_exp 
        generic map (
            WORD_WIDTH => C_BLOCK_SIZE
        )
        port map (
            clk => clk,
            reset_n => reset_n,
            start => core_start(i),
            retreive => core_retreive(i),
            inputTag => core_tag_in(i),
            inputBase => msgin_data,
            inputExp => key_e_d,
            inputModulus => key_n,
            result => core_result(i),
            outputTag => core_tag_out(i),
            busy => core_busy(i),
            ready => core_ready(i)
        );
    
        core_tag_in(i)(31) <= msgin_last;
        core_tag_in(i)(30 downto 0) <= next_id_in;
    end generate g_GEN_CORES;

    --MsgIn interface
    msgin_ready <= free_core; 
    
    -- Dispatcher
    free_core <= or_reduce(std_logic_vector(core_ready));
    start_new_job <= free_core and msgin_valid;
    
    -- Start the first free core
    process(start_new_job, core_ready) begin
        core_start <= (others=>'0');
        
        if(start_new_job = '1') then
            -- Choose core to dispatch job to
            for i in 0 to C_NUM_CORES-1 loop
                if (core_ready(i) = '1') then
                    core_start(i) <= '1';
                    exit; -- Exit once a core has been found and started
                end if;
            end loop;
       end if;
    end process;
   
    -- Ouput job if the next id out is ready
    process(msgout_ready, core_busy, core_ready, core_tag_out) begin
        msgout_data <= (others => 'U');
        msgout_last <= '0';
        msgout_valid <= '0';
        new_job_done <= '0';
        core_retreive <= (others=>'0');
        
        if (msgout_ready = '1') then
            -- Loop through all cores to find if one of them has the next job finished
            for i in 0 to C_NUM_CORES-1 loop
                if (core_busy(i) = '0' and core_ready(i) = '0' and core_tag_out(i)(30 downto 0) = next_id_out) then
                    -- Output the found cores result, and signal to the core that it can reset 
                    msgout_data <= core_result(i);
                    msgout_last <= core_tag_out(i)(31);
                    msgout_valid <= '1';
                    core_retreive(i) <= '1';
                    new_job_done <= '1';
                end if;
            end loop;
        end if;
    end process;
   
   -- Increment job ID for incoming and outgoing jobs
    process(clk, reset_n) begin
        if(reset_n = '0') then
            next_id_in <= (others => '0');
            next_id_out <= (others => '0');
        elsif(clk'event and clk='1') then
            -- Increment next_id_in if a new job has been received
            if (start_new_job = '1') then
                next_id_in <= std_logic_vector(unsigned(next_id_in) + 1);
            end if;
            
            -- Increment next_id_out if a new job has been delivered
            if (new_job_done = '1') then
                next_id_out <= std_logic_vector(unsigned(next_id_out) + 1);
            end if;
        end if;
    end process;
    
    -- Show the busy signal for each core in the status register  
    rsa_status(C_NUM_CORES-1 downto 0) <= std_logic_vector(core_busy);
end rtl;
