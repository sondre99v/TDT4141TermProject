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

entity rsa_core is
    generic (
        C_BLOCK_SIZE          : integer := 256
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
    -- Core Interfaces
    signal core0_result : std_logic_vector(C_BLOCK_SIZE-1 downto 0);
    signal core1_result : std_logic_vector(C_BLOCK_SIZE-1 downto 0);
    signal core0_busy   : std_logic;
    signal core1_busy   : std_logic;
    signal core0_start  : std_logic;
    signal core1_start  : std_logic;
    signal core0_tag_in : std_logic_vector(31 downto 0);
    signal core1_tag_in : std_logic_vector(31 downto 0);
    signal core0_tag_out: std_logic_vector(31 downto 0);
    signal core1_tag_out: std_logic_vector(31 downto 0);
    signal core0_ready  : std_logic;
    signal core1_ready  : std_logic;
    signal core0_retreive : std_logic;
    signal core1_retreive : std_logic;
    
    --Dispatcher
    signal free_core    : std_logic;
    signal start_new_job: std_logic;
    signal new_job_done : std_logic;
    signal next_id_in   : std_logic_vector(30 downto 0); -- ID of next incoming job
    signal next_id_out  : std_logic_vector(30 downto 0); -- ID of next job to be sent out
    
    signal nd: std_logic_vector(255 downto 0);
    
begin
    me0: entity work.mod_exp port map (
        clk => clk,
        reset_n => reset_n,
        start => core0_start,
        retreive => core0_retreive,
        inputTag => core0_tag_in,
        inputBase => msgin_data,
        inputExp => key_e_d,
        inputModulus => key_n,
        result => core0_result,
        outputTag => core0_tag_out,
        busy => core0_busy,
        ready => core0_ready
    );
    
    me1: entity work.mod_exp port map (
       clk => clk,
       reset_n => reset_n,
       start => core1_start,
       retreive => core1_retreive,
       inputTag => core1_tag_in,
       inputBase => msgin_data,
       inputExp => key_e_d,
       inputModulus => key_n,
       result => core1_result,
       outputTag => core1_tag_out,
       busy => core1_busy,
       ready => core1_ready
    );
    

    --Dispatcher
    free_core <= core0_ready or core1_ready;
    
    start_new_job <= free_core and msgin_valid;
    
    core0_tag_in(31) <= msgin_last;
    core0_tag_in(30 downto 0) <= next_id_in;
    
    core1_tag_in(31) <= msgin_last;
    core1_tag_in(30 downto 0) <= next_id_in;
    
    
    --MsgIn interface
    msgin_ready <= free_core; 
    
    -- Start the first free core
    process(start_new_job, core0_ready, core1_ready) begin
        core0_start <= '0';
        core1_start <= '0';
        
        if(start_new_job = '1') then
            -- Choose core to dispatch job to
            if (core0_ready = '1') then
                core0_start <= '1';
            elsif (core1_ready = '1') then
                core1_start <= '1';
            end if;
       end if;
    end process;
   
    -- Ouput job if the next id out is ready
    process(msgout_ready, core0_busy, core1_busy, core0_ready, core1_ready, core0_tag_out, core1_tag_out) begin
        msgout_data <= (others => 'U');
        msgout_last <= '0';
        msgout_valid <= '0';
        new_job_done <= '0';
        core0_retreive <= '0';
        core1_retreive <= '0';
        
        if (msgout_ready = '1') then
            if (core0_busy = '0' and core0_ready = '0' and core0_tag_out(30 downto 0) = next_id_out) then
                msgout_data <= core0_result;
                msgout_last <= core0_tag_out(31);
                msgout_valid <= '1';
                core0_retreive <= '1';
                new_job_done <= '1';
            end if;
                            
            if (core1_busy = '0' and core1_ready = '0' and core1_tag_out(30 downto 0) = next_id_out) then
                msgout_data <= core1_result;
                msgout_last <= core1_tag_out(31);
                msgout_valid <= '1';
                core1_retreive <= '1';
                new_job_done <= '1';
            end if;
        end if;
    end process;
   
   -- Increment job ID for incoming and outgoing jobs
    process(clk, reset_n) begin
        if(reset_n = '0') then
            next_id_in <= (others => '0');
            next_id_out <= (others => '0');
        elsif(clk'event and clk='1') then
            if (start_new_job = '1') then
                next_id_in <= std_logic_vector(unsigned(next_id_in) + 1);
            end if;
            
            if (new_job_done = '1') then
                next_id_out <= std_logic_vector(unsigned(next_id_out) + 1);
            end if;
        end if;
    end process;
    
    rsa_status(0) <= core0_busy;
    rsa_status(1) <= core1_busy;
    --rsa_status   <= (others => '0');
end rtl;
