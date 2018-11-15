--------------------------------------------------------------------------------
-- Author       : Oystein Gjermundnes
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
--   RSA encryption core template. This core currently computes
--   C = M xor key_n
--
--   Replace/change this module so that it implements the function
--   C = M**key_e mod key_n.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity rsa_core is
	generic (
		-- Users to add parameters here
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
    rsa_status              : out std_logic_vector(31 downto 0)    
          
  );
end rsa_core;

architecture rtl of rsa_core is
component mod_exp 
    Port ( 
        clk             : in  std_logic;
        rst          : in  std_logic;
        start        : in  std_logic;
        inputBase    : in  std_logic_vector(C_BLOCK_SIZE-1 downto 0);
        inputExp     : in  std_logic_vector(C_BLOCK_SIZE-1 downto 0);
        inputModulus : in  std_logic_vector(C_BLOCK_SIZE-1 downto 0);
    
        result       : out std_logic_vector(C_BLOCK_SIZE-1 downto 0);
        busy         : out std_logic
        );
        end component;
    
    --inputs
    signal start     :   std_logic:='0';
    signal BaseReg    :   std_logic_vector(C_BLOCK_SIZE-1 downto 0):=(others =>'0'); --msg_in
    signal ExpReg    :   std_logic_vector(C_BLOCK_SIZE-1 downto 0):=(others =>'0'); --key_e_d
    signal ModReg    :   std_logic_vector(C_BLOCK_SIZE-1 downto 0):=(others =>'0'); --key_n
    
    --outputs
    signal result : std_logic_vector(C_BLOCK_SIZE-1 downto 0); --msgout
    signal busy : std_logic;
    
    --internals
    signal new_message : std_logic;
    
begin
    uut: mod_exp port map (
    clk=>clk,
    rst=>reset_n,
    start=>start,
    inputBase=>BaseReg,
    inputExp=>ExpReg,
    inputModulus=>ModReg,
    result=>result,
    busy=>busy
    );
    
    --MsgIn interface
    new_message <= (msgin_valid and (not busy));
    msgin_ready <= not busy;
    ExpReg <= key_e_d;
    ModReg <= key_n;
    start <= new_message;   
    BaseReg <= msgin_data;
     --MsgOut interface
     
    --msgout_valid <= new_message and (result(0) or result(34));
    msgout_data <= result;
    
    
    



  --msgout_valid <= msgin_valid;   
  --msgin_ready  <= msgout_ready;
  --msgout_data  <= msgin_data xor key_n; --result
  --msgout_last  <= msgin_last;
  rsa_status   <= (others => '0');
end rtl;
