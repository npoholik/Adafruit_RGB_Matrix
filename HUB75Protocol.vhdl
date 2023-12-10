----------------------------------------------------------------------------------
-- ECE 3205 - Advanced Digital Design
-- Engineer: Nikolas Poholik
-- 
-- Create Date: 12/02/2023 08:43:59 PM
-- Design Name: HUB75Protocol
-- Module Name: HUB75Protocol - behav
-- Project Name: AdaFruit_RGB_Matrix
-- Target Devices: Basys 3 FPGA, 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------
Library ieee;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use IEEE.NUMERIC_STD.all;


entity HUB75Protocol is
    port (clk : in std_logic;                 -- Internal clock, Basys 3 clock ~100 MHz
          clk_out : out std_logic;            -- clock that is output to RGB matrix board
          blank, latch : buffer std_logic;    -- blank (represents output enable OE) turns off display by being written high, latch (high->low) loads data into a row
          A3, A2, A1, A0 : out std_logic;     --  4 address values (determines which line to display out of 32) (A4 is unused as it is unncessary for 32x32 matrix)
          R0,G0,B0,R1,G1,B1 : out std_logic; -- color value (R0,G0,B0 for upper half of board; R1, G1, B1 for lower half of board)
          SW_middle : in std_logic;
          SW_left, SW_right, SW_up, SW_down : in std_logic;
          dimEN : out std_logic_vector(3 downto 0);
          dimSegment : out std_logic_vector(6 downto 0));
end HUB75Protocol;


architecture behav of HUB75Protocol is
-- ******************************************************************************************************************
-- *** LOGIC GOALS FOR ARCHITECTURE: ***
--  1. Select which line to display using the 4 address (A[3:0]) given the RGB matrix has 16 lines to pick signal
--  2. Turn the row display off by making the Blank pin high (avoids glitches)
--  3. Clock 32 bits of data using the Clock pin and RGB signal
--  4. Toggle the latch pin from high to low, which will load the data into the signal
--  5. Turn the row display on by setting the blank pin low
-- **** CLOCK OF 60 kHZ for 32x32 MATRIX *****
-- *******************************************************************************************************************


-- ***Define signals*** (Most signals moved to Main process)
---------------------------------------------------------------------------------------------------
    --signal latchData: std_logic;   -- will allow determination of next step to take
    --signal latchIn, blankIn : std_logic := '0';    -- will determine what is going to be output onto matrix board (also means it can be read during process unlike output latch and blank)

    signal rowCount : unsigned(3 downto 0) := "0000";      -- signal for row address, counts up to 15 (16 total rows)
    signal colCount : unsigned(4 downto 0) := "00000";      -- signal for current column, counts up to 31 (32 total columns)
    signal user_Dim : unsigned(2 downto 0) := "000";
    --signal clockCol : std_logic := '0';

    --signal rgb : unsigned(2 downto 0) := "001";            -- signal for color values of an individual pixel (initial value: blue)

    --signal count : integer := 1;                -- Count signals for clock divider/pulse width
    signal clk_div : std_logic;                 -- 60 kHz clock to use for outputting to board as well as in main process
    signal reset : std_logic;
    signal locked : std_logic; 
    
    -- buttons
    signal SW_middle_out : std_logic;
    signal SW_mid_prev : std_logic;
    
    --movement buttons
    signal SW_up_out : std_logic;
    signal SW_up_prev : std_logic;
    signal SW_left_out : std_logic;
    signal SW_left_prev : std_logic;
    signal SW_right_out : std_logic;
    signal SW_right_prev : std_logic;
    signal SW_down_out : std_logic;
    signal SW_down_prev : std_logic;
    
    signal willLatchData, willSetBlank : std_logic := '0'; -- will let process know when to get ready to latch (high -> signal to board)
----------------------------------------------------------------------------------------------------

    -- *** COMPONENT INSTANTIATION: ***
    component clk_wiz
        port
        (-- Clock in ports
         -- Clock out ports
          clk_out          : out    std_logic;
         -- Status and control signals
          reset             : in     std_logic;
          locked            : out    std_logic;
          clk_in           : in     std_logic
        );
    end component;

    -- *** HOLDS PRE DETERMINED VALUES ACCORDING TO DIM
    type Dim is array (7 downto 0) of integer;
    signal DimLookup : Dim := (1200000, 871428,742857, 614285, 485714,357142,228571,125000);
    -- Stores the counter values for each various user dim input
        -- Math: 1,000,000 - [(1,000,000 - 100,000)/7] * Index
            -- Where 1,000,000 - 100,000 represents the range and 7 represents the # of steps
            -- Numbers that differ required slight calibration tweaks (1 mil to 1.2, 100,000 to 125k)

    -- *** FRAME BUFFER ***
    type FrameBuffer is array (natural range<>, natural range <>) of std_logic_vector(2 downto 0);
    signal readBuffer : FrameBuffer(0 to 31, 0 to 31) := 
    (("111", "100", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"));
    
    
    signal writeBufferBottom : FrameBuffer(0 to 15, 0 to 31) := 
    (("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"));
    
    signal writeBufferTop : FrameBuffer(0 to 15, 0 to 31) :=
    (("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"),
    ("000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000", "000"));
    
    signal doneWriting : std_logic;
    --signal doneTransferring : std_logic;
    
    -- *** SPRITES ***
    type SROM is array (natural range <>, natural range <>) of std_logic_vector(2 downto 0);
    signal squareSprite : SROM(3 downto 0, 3 downto 0) := (("111", "111", "111", "111"), ("111", "111", "111", "111"), ("111", "111", "111", "111"),("111", "111", "111", "111"));
                                                         
    signal yPos : unsigned(4 downto 0);
    signal xPos : unsigned(4 downto 0);                                                     
     
    -- signal rgb : unsigned(2 downto 0) := "001";
    --    {"000", "000", "000", "000", "000", "000", "000"
-- ***Architecture begin***
begin

    -- *** Concurrent Blocks: *** (Unused in current iteration)
    ------------------------------------------------------------------------------------------------
    -- Internal signal to output signal assignments
    -- latchIn and blankIN helps know internally what value will be getting output to the board
    -- ***ALTERNATIVELY, MAKE LATCH AND BLANK BUFFER SIGNALS IN ENTITY DECLARATION ***
    -- ^^^ would honestly be easier, it didn't occur to me when initially starting
    --latch <= latchIn;
    --blank <= blankIn;

    
    --clk_out <= clk_div; -- clock the data into the columns
    
    ------------------------------------------------------------------------------------------------

    --*** COMPONENT INSTANTIATION ***
    ClockDivider : clk_wiz
        port map ( 
        -- Clock out ports  
            clk_out => clk_div,
        -- Status and control signals                
            reset => reset,
            locked => locked,
        -- Clock in ports
            clk_in => clk
        );

    -- ***Sequential Blocks: ***
    ------------------------------------------------------------------------------------------------
    Main: process(clk_div)
     --*** Variable declarations: *** (moved to write buffer process)
     variable cycleRGB : integer := 1;                    -- will determine when to change RGB values
     variable rgb : unsigned(2 downto 0) := "000";         -- signal for color values of an individual pixel (initial value: black)   
     variable dim : unsigned(2 downto 0) := "000";
     variable upperColor : std_logic_vector(2 downto 0);
     variable lowerColor : std_logic_vector(2 downto 0);
     variable rowIndex : unsigned(3 downto 0);
     variable colIndex : unsigned(4 downto 0);
     --*** PROCESS BEGIN ***               
        begin
            if blank = '1' then
                clk_out <= clk_div; -- clock data into each column by sending out clock 
            end if;
            
            if rising_edge(clk_div) then
                    
                upperColor := writeBufferTop(to_integer(rowCount),to_integer(colCount));
                lowerColor := writeBufferBottom(to_integer(rowCount), to_integer(colCount));
                -- *** LOGIC TO HANDLE REFRESHING: ***
                ----------------------------------------------------------------------------------------------------------------------------------------
                if blank = '0' then   -- If blank is not set, then line is active (TURN OFF NEXT ROW)
                     -- Following if/else will allow a couple of clock cycles to account for propagation delay 
                     if willSetBlank = '0' then
                        willSetBlank <= '1';
                     else 
                        willSetBlank <= '0';
                        blank <= '1';
                     end if;

                else   -- else blank is set, and line is not active (updating colors will now take place)

                    -- Send in current RGB Data to board
                    
                    R0 <= upperColor(2);
                    G0 <= upperColor(1);
                    B0 <= upperColor(0);
                    
                    R1 <= lowerColor(2);
                    G0 <= lowerColor(1);
                    B0 <= lowerColor(0);
                
                    
                    -- Indicates all data is loaded into the columns, and row is ready to be latch (low to high)
                    if colCount = "11111" then 
                        colCount <= "00000";
                        if dim = user_Dim then
                            dim := "000";
                            willLatchData <= '1';
                            --*** LOGIC TO SHIFT RGB VALUE *** (moved to separate process)
                            cycleRGB := cycleRGB + 1;
                            if cycleRGB = DimLookup(7 - to_integer(user_Dim)) then
                                cycleRGB := 1;
                                rgb := rgb + 1; -- increment color value by 1 (entire pattern is 8 including off)
                                doneWriting <= '0';
                            elsif cycleRGB > DimLookup(7 - to_integer(user_Dim)) then
                                cycleRGB := 1;
                            end if;
                        else 
                           dim := dim + 1;
                           willLatchData <= '0';
                        end if;
                    -- The following elsif's handle latching data into the row before moving onto the next
                    elsif willLatchData = '1' then
                        willLatchData <= '0';
                        latch <= '1';
                    elsif latch = '1' then 
                        latch <= '0'; -- reset latch
                        blank <= '0'; -- turn current row on
                        rowCount <= rowCount + 1; -- move to next row 
                        rowIndex := rowIndex + 1;
                        
                        A3 <= rowCount(3);
                        A2 <= rowCount(2);
                        A1 <= rowCount(1);
                        A0 <= rowCount(0);
                    else 
                        if doneWriting = '0' then
                            writeBufferBottom(to_integer(rowIndex), to_integer(colIndex)) <= std_logic_vector(rgb);
                            writeBufferTop(to_integer(rowIndex), to_integer(colIndex)) <= std_logic_vector(rgb);
                        end if;
                        if rowCount = "1111" and colCount = "11111" then
                            doneWriting <= '1';
                        end if;
                         colCount <= colCount + 1; -- Move to the next column if still possible
                         colIndex := colIndex + 1;
                    end if;
                    
                end if;   
                
                ----------------------------------------------------------------------------------------------------------------------------------------
            end if;
    end process;

    
    --Write_Frame: process(rowCount, colCount)
    --begin
     --   if doneWriting = '0' then
       --     writeBufferTop(to_integer(rowCount), to_integer(colCount)) <= std_logic_vector(rgb);
       --     writeBufferBottom(to_integer(rowCount), to_integer(colCount)) <= std_logic_vector(rgb);
       --     if rowCount = "1111" and colCount = "11111" then
       --         doneWriting <= '1';
       --     end if;
      --  end if;
    --end process;
   
   
  --  Transfer_Buffers:process(doneWriting)
   -- begin
   -- if rising_edge(clk_div) then
    --    if doneWriting = '1' then
     --       for row in 0 to 31 loop
       --         for col in 0 downto 31 loop
         --           readBuffer(row, col) <= writeBuffer(row,col);
           --     end loop;
           -- end loop;
       -- end if;
   -- end if;
   -- end process;
    
    
    Dim_Button_Debouncing: process(clk_div) 
    variable shiftBtn : std_logic_vector(19 downto 0);
    begin 
        if rising_edge(clk_div) then
            shiftBtn := shiftBtn(18 downto 0) & SW_middle;
            if shiftBtn = "11111111111111111111" then
                SW_middle_out <= '1';
            else
                SW_middle_out <= '0';
        end if;
    end if;
    end process;

    Dim_Button_Edge_Detector:process(clk_div)
    begin 
    if rising_edge(clk_div) then
        SW_mid_prev <= SW_middle_out;
        if SW_middle_out = '1' and SW_mid_prev = '0' then --detect a positive edge on the button
            user_Dim <= user_Dim + 1;
        end if;
    end if;
    end process;
    
    
    SevenSegment: process(clk_div)
    begin
        if rising_edge(clk_div) then
            case user_Dim is
                when "000" => dimSegment <= "1000000";
                when "001" => dimSegment <= "1111001";
                when "010" => dimSegment <= "0100100";
                when "011" => dimSegment <= "0110000";
                when "100" => dimSegment <= "0011001";
                when "101" => dimSegment <= "0010010";
                when "110" => dimSegment <= "0000010";
                when "111" => dimSegment <= "1111000";
                when others => dimSegment <= "1111111";
            end case;
            dimEN <= "1110"; -- Active low Anode enables 
        end if;
    end process;
    
    
    UpdateSpriteMovement: process(yPos, xPos) 
    variable color : std_logic_vector(2 downto 0);
    begin
        -- ensure position is within bounds of screen
        if rowCount - yPos >= 0 and rowCount - yPos <= 4 then
            if colCount - xPos >= 0 and colCount - xPos <= 4 then
                --color := squareSprite(to_integer(rowCount - yPos), to_integer(colCount - xPos));
               -- R0 <= color(2);
               -- G0 <= color(1);
               -- B0 <= color(0);
            end if;
        end if;
    end process;
    
    
    Position_Movement_Debouncing: process(clk_div)
    variable shiftBtnUp : std_logic_vector(19 downto 0);
    variable shiftBtnLeft : std_logic_vector(19 downto 0);
    variable shiftBtnRight : std_logic_vector(19 downto 0);
    variable shiftBtnDown : std_logic_vector(19 downto 0);
    begin 
        if rising_edge(clk_div) then
            shiftBtnUp := shiftBtnLeft(18 downto 0) & SW_up;
            shiftBtnLeft := shiftBtnLeft(18 downto 0) & SW_left;
            shiftBtnRight := shiftBtnLeft(18 downto 0) & SW_right;
            shiftBtnDown := shiftBtnLeft(18 downto 0) & SW_down;
            
            if shiftBtnUp = "11111111111111111111" then
                SW_up_out <= '1';
            else
                SW_up_out <= '0';
            end if;
            
            if shiftBtnLeft = "11111111111111111111" then
                SW_left_out <= '1';
            else
                SW_left_out <= '0';
            end if;
            
            if shiftBtnRight = "11111111111111111111" then
                SW_right_out <= '1';
            else
                SW_right_out <= '0';
            end if;
            
            if shiftBtnDown = "11111111111111111111" then
                SW_down_out <= '1';
            else
                SW_down_out <= '0';
            end if;
    end if;
    end process;
    
    Position_Movement_Edge_Detector: process(clk_div)
    begin 
    if rising_edge(clk_div) then
        SW_up_prev <= SW_up_out;
        SW_left_prev <= SW_left_out;
        SW_right_prev <= SW_right_out;
        SW_down_prev <= SW_down_out;
        
        if SW_up_out = '1' and SW_up_prev = '0' then --detect a positive edge on the button
            yPos <= yPos - 1;
        end if;
        
        if SW_left_out = '1' and SW_left_prev = '0' then
            xPos <= xPos - 1;
        end if;
        
        if SW_right_out = '1' and SW_right_prev = '0' then
            xPos <= xPos + 1;
        end if;
        
        if SW_down_out = '1' and SW_down_prev = '0' then
            yPos <= yPos + 1;
        end if;
    end if;
    end process;
    
    -- *** OLD ITERATIONS: INCORRECT/UNUSED
    ---------------------------------------------------------------------------------------------------------------------------


--   process(colCount)
--   variable temp : std_logic := '0';
 --   begin
--         clk_out <= not temp;
--         if colCount = "11111" then
--            R0 <= rgb(2); G0 <= rgb(1); B0 <= rgb(0);
--            R1 <= rgb(2); G1 <= rgb(1); B1 <= rgb(0);
--        end if;
 --   end process;


    -- *** PROCESS TO UPDATE RGB VALUES ***
--    UpdateRGB: process(clk, rowCount, colCount)
--        variable rgbCounter : integer := 1;  -- will determine when to change RGB values
--    begin 
--    if rising_edge(clk) then
--       if rowCount = "1111" and colCount = "11111" then
--            rgbCounter := rgbCounter + 1;
--            if rgbCounter = 1000000 then -- Looking for ~80,000 refreshes of the entire board 
--                rgbCounter := 1;
--                rgb <= rgb + 1;
--            end if;
--        end if;
--    end if;
--    end process; 


--    process(clk, rgb)
--    begin
--    if rising_edge(clk)then
--        R0 <= rgb(2); G0 <= rgb(1); B0 <= rgb(0);
--        R1 <= rgb(2); G1 <= rgb(1); B1 <= rgb(0);
 --       end if;
--    end process;


   -- *** PROCESS TO OUTPUT 25 MHz CLOCK ***
--    ClockDivider: process(clk) 
--        variable temp : std_logic := '0';
--        variable count : integer := 1;
--        begin
--            if rising_edge(clk) then
--                count := count + 1;
--                if count = 4  then  -- 100 MHz clock takes prescalar of 
--                   clk_div <= not temp; 
--                   count := 1;
--                end if;
--            end if;
--    end process;
    
    
      --  process(colCount) 
 --  variable temp : std_logic := '0';
 --   begin
 --       clk_out <= not temp;
 --   end process;
 
  --   Write_Frame: process(clk_div)
 --   variable cycleRGB : integer := 1;                    -- will determine when to change RGB values
 --   variable rgb : unsigned(2 downto 0) := "000";         -- signal for color values of an individual pixel (initial value: black) 
  --  begin
    --if rising_edge(clk_div) then
      --  if colCount = "11111" then
        --    cycleRGB := cycleRGB + 1;
          --  if cycleRGB = DimLookup(7 - to_integer(user_Dim)) then
            --    cycleRGB := 1;
              --  rgb := rgb + 1; -- increment color value by 1 (entire pattern is 8 including off)
                --doneWriting <= '0';
            --elsif cycleRGB > DimLookup(7 - to_integer(user_Dim)) then
              --  cycleRGB := 1;
            --end if;
        --end if;
        
      --  if doneWriting = '0' then
        --    writeBuffer(to_integer(rowCount), to_integer(colCount)) <= std_logic_vector(rgb);
          --  writeBuffer(to_integer(rowCount) + 16, to_integer(colCount)) <= std_logic_vector(rgb);
        --elsif rowCount = "1111" and colCount = "11111" then
          --  doneWriting <= '1';
        --end if;
        
    --end if;
    --end process;
    ------------------------------------------------------------------------------------------------------

end behav;
