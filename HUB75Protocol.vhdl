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
          blank, latch : out std_logic;    -- blank (represents output enable OE) turns off display by being written high, latch (high->low) loads data into a row
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
    signal latchStatus, blankStatus : std_logic;   -- will allow determination of next step to take
    signal latchIn, blankIn : std_logic := '0';    -- will determine what is going to be output onto matrix board (also means it can be read during process unlike output latch and blank)

    signal rowCount : std_logic_vector(3 downto 0) := "0000";      -- signal for row address, counts up to 15 (16 total rows)
    signal colCount : std_logic_vector(4 downto 0) := "00000";      -- signal for current column, counts up to 31 (32 total columns)

    signal rgb : std_logic_vector(2 downto 0) := "001";            -- signal for color values of an individual pixel 
    signal rgbCounter : integer := 1;             -- will determine when to change RGB values

    signal count : integer := 1;                -- Count signals for clock divider/pulse width
    signal clk_div : std_logic;                 -- 60 kHz clock to use for outputting to board as well as in main process
----------------------------------------------------------------------------------------------------

-- ***Architecture begin***
begin

    -- *** Concurrent Blocks: ***
    ------------------------------------------------------------------------------------------------
    -- Internal signal to output signal assignments
    -- latchIn and blankIN helps know internally what value will be getting output to the board
    -- ***ALTERNATIVELY, MAKE LATCH AND BLANK BUFFER SIGNALS IN ENTITY DECLARATION ***
    -- ^^^ would honestly be easier, it didn't occur to me when initially starting
    latch <= latchIn;
    blank <= blankIn;

    -- Send color data to the RGB pins
    R0 <= rgb(2); G0 <= rgb(1); B0 <= rgb(0);
    R1 <= rgb(2); G1 <= rgb(1); B1 <= rgb(0);

    ------------------------------------------------------------------------------------------------



    -- ***Sequential Blocks: ***
    ------------------------------------------------------------------------------------------------

    Main: process(clk_div)
        begin
            if rising_edge(clk_div) then
                clk_out <= '0';
                ----------------------------------------------------------------------------------------------------------------------------------------
                if blankIn = '0' then   -- If blank is not set, then line is active (MUST NOW MOVE TO NEXT ROW)

                    -- if blankStatus is not set, then update the address to the board from rowCount(previous iteration through should have incremented row address) and set blankStatus for next iteration
                    if blankStatus = '0' then 
                        A3 <= rowCount(3);
                        A2 <= rowCount(2);
                        A1 <= rowCount(1);
                        A0 <= rowCount(0);
                        blankStatus <= '1';
                    -- if blankStatus is set, then the current row selected will be turned off by writing a 1 to blankIn (which gets output to the board via blank)
                    else 
                        blankStatus <= '0';
                        blankIn <= '1';
                    end if;
                ----------------------------------------------------------------------------------------------------------------------------------------  
                else  -- else blank is set, and line is not active (updating colors will now take place)

                    -- Indicates all data is loaded into the columns, and row is ready to be latch (low to high)
                    if colCount = "11111" then 
                        colCount <= "00000";
                        latchStatus <= '1';
                    -- Indicates that the latch will be written high to prepare the buffer to transfer
                    elsif latchStatus = '1' then
                        latchStatus <= '0';
                        latchIn <= '1';
                    -- Indicates that the latch low to high will now take place
                    elsif latchIn = '1' then
                        latchIn <= '0'; -- High to low for latch, data loaded into row
                        blankIn <= '0'; -- Row is turned back on by clearing blank
                        row := std_logic_vector(unsigned(row) + 1); -- Row address is incremented to the next
                    -- If nothing else is set, then continue incrementing through the columns
                    else 
                        clk_out <= '1';
                        colCount := colCount + 1;
                    end if;

                end if;      
                ----------------------------------------------------------------------------------------------------------------------------------------
            else 
                clk_out <= '0';
            end if;
    end process;


    -- *** PROCESS TO OUTPUT 60 KHZ CLOCK ***
    ClockDivider: process(clk) 
        variable temp : std_logic;
        begin
            if rising_edge(clk) then
                count <= count + 1;
                if count = 833  then  -- 100 MHz clock takes prescalar of ~1667 to divide it into 60 kHz, so ~833 for 50% duty cycle between time high and time low
                    clk_div <= not temp; 
                    count <= 1;
                end if;
            end if;
    end process;


    -- *** PROCESS TO UPDATE RGB VALUES ***
    UpdateRGB: process(rowCount, colCount) 
    begin 
        if rowCount = "1111" and colCount = "11111" then
            rgbCount <= rgbCount + 1;
            if rgbCount = 801 then -- Looking for ~800 refreshes of the entire board 
                rgb <= std_logic_vector(unsigned(rgb) + 1);
                rgbCount <= 1;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------------------------------------
end behav;