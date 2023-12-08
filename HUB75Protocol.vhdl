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
    port (clk : in std_logic;            -- Internal clock, Basys 3 clock ~100 MHz
          clk_out : out std_logic;        -- clock that is output to RGB matrix board
          blank, latch : buffer std_logic;    -- blank (represents output enable OE) turns off display by being written high, latch (high->low) loads data into a row
          A3, A2, A1, A0 : out std_logic; --  4 address values (determines which line to display out of 32) (A4 is unused as it is unncessary for 32x32 matrix)
          R0,G0,B0,R1,G1,B1 : out std_logic); -- color value (R0,G0,B0 for upper half of board; R1, G1, B1 for lower half of board)
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

-- ***Define signals***
---------------------------------------------------------------------------------------------------
    --signal latchData: std_logic;   -- will allow determination of next step to take
    --signal latchIn, blankIn : std_logic := '0';    -- will determine what is going to be output onto matrix board (also means it can be read during process unlike output latch and blank)

    --signal rowCount : unsigned(3 downto 0) := "0000";      -- signal for row address, counts up to 15 (16 total rows)
    --signal colCount : unsigned(4 downto 0) := "00000";      -- signal for current column, counts up to 31 (32 total columns)

    --signal clockCol : std_logic := '0';

    --signal rgb : unsigned(2 downto 0) := "001";            -- signal for color values of an individual pixel (initial value: blue)

    --signal count : integer := 1;                -- Count signals for clock divider/pulse width
    --signal clk_div : std_logic;                 -- 60 kHz clock to use for outputting to board as well as in main process
    
    signal willLatchData, willSetBlank : std_logic := '0'; -- will let process know when to get ready to latch (high -> signal to board)
----------------------------------------------------------------------------------------------------

-- ***Architecture begin***
begin

    -- *** Concurrent Blocks: ***
    ------------------------------------------------------------------------------------------------
    -- Internal signal to output signal assignments
    -- latchIn and blankIN helps know internally what value will be getting output to the board
    -- ***ALTERNATIVELY, MAKE LATCH AND BLANK BUFFER SIGNALS IN ENTITY DECLARATION ***
    -- ^^^ would honestly be easier, it didn't occur to me when initially starting
    --latch <= latchIn;
    --blank <= blankIn;

    
    --clk_out <= clk_div; -- clock the data into the columns
    

    

    ------------------------------------------------------------------------------------------------



    -- ***Sequential Blocks: ***
    ------------------------------------------------------------------------------------------------
    Main: process(clk)
     --*** Variable declarations: ***
     variable rowCount : unsigned(3 downto 0) := "0000";   --signal for row address, counts up to 15 (16 total rows)
     variable colCount : unsigned(4 downto 0) := "00000";  -- signal for current column, counts up to 31 (32 total columns)
     variable rgb : unsigned(2 downto 0) := "000";         -- signal for color values of an individual pixel (initial value: black)
     variable cycleRGB : integer := 1;                     -- will determine when to change RGB values

     --*** PROCESS BEGIN ***               
        begin
            if blank = '1' then
                clk_out <= clk; -- clock data into each column by sending out clock 
            end if;
            
            if rising_edge(clk) then
                -- *** LOGIC TO HANDLE REFRESHING: ***
                ----------------------------------------------------------------------------------------------------------------------------------------
                if blank = '0' then   -- If blank is not set, then line is active (TURN OFF NEXT ROW)
                     if willSetBlank = '0' then
                        willSetBlank <= '1';
                     else 
                        willSetBlank <= '0';
                        blank <= '1';
                     end if;

                else   -- else blank is set, and line is not active (updating colors will now take place)

                    -- Send in current RGB Data to board
                    R0 <= rgb(2); G0 <= rgb(1); B0 <= rgb(0);
                    R1 <= rgb(2); G1 <= rgb(1); B1 <= rgb(0);
                    -- Indicates all data is loaded into the columns, and row is ready to be latch (low to high)
                    if colCount = "11111" then 
                        colCount := "00000";
                        willLatchData <= '1';
                        
                        --*** LOGIC TO SHIFT RGB VALUE ***
                        cycleRGB := cycleRGB + 1;
                            if cycleRGB = 100000 then
                                cycleRGB := 1;
                                rgb := rgb + 1;
                            end if;
                            
                            
                    elsif willLatchData = '1' then
                        willLatchData <= '0';
                        latch <= '1';
                    elsif latch = '1' then 
                        latch <= '0'; 
                        blank <= '0';
                        rowCount := rowCount + 1;
                        A3 <= rowCount(3);
                        A2 <= rowCount(2);
                        A1 <= rowCount(1);
                        A0 <= rowCount(0);
                    else 
                         colCount := colCount + 1; -- move to next column
                    end if;
                    
                end if;   
                
                ----------------------------------------------------------------------------------------------------------------------------------------
            end if;
    end process;








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
 
    ------------------------------------------------------------------------------------------------
end behav;
