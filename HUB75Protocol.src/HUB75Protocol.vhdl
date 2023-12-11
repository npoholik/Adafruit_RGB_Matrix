----------------------------------------------------------------------------------
-- ECE 3205 - Advanced Digital Design
-- Engineer: Nikolas Poholik
-- 
-- Create Date: 12/02/2023 08:43:59 PM
-- Design Name: HUB75Protocol
-- Module Name: HUB75Protocol - behav
-- Project Name: AdaFruit_RGB_Matrix
-- Target Devices: Basys 3 FPGA, AdaFruit 32x32 RGB Matrix
----------------------------------------------------------------------------------
Library ieee;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use IEEE.NUMERIC_STD.all;

Library ieee;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use IEEE.NUMERIC_STD.all;


entity HUB75Protocol is
    port (clk : in std_logic;                               -- Internal clock, Basys 3 clock ~100 MHz
          clk_out : out std_logic;                          -- Clock that is output to RGB matrix board
          blank, latch : buffer std_logic;                  -- Blank (represents output enable OE) turns off display by being written high, latch (high->low) loads data into a row
          A3, A2, A1, A0 : out std_logic;                   --  4 address values (determines which line to display out of 32) (A4 is unused as it is unncessary for 32x32 matrix)
          R0,G0,B0,R1,G1,B1 : out std_logic;                -- Color value (R0,G0,B0 for upper half of board; R1, G1, B1 for lower half of board)
          SW_middle : in std_logic;                         -- Input from middle button 
          SW_left, SW_right, SW_up, SW_down : in std_logic; -- Input from the four directional buttons
          dimEN : out std_logic_vector(3 downto 0);         -- Enable for the seven segment display that displays current dim setting
          dimSegment : out std_logic_vector(6 downto 0));   -- 7-bit output to the seven segment display to show numerical values
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
    --SIGNALS FOR REFRESH PROCESS
    signal rowCount : unsigned(3 downto 0) := "0000";      -- signal for row address, counts up to 15 (16 total rows)
    signal colCount : unsigned(4 downto 0) := "00000";     -- signal for current column, counts up to 31 (32 total columns)
    signal user_Dim : unsigned(2 downto 0) := "000";       -- signal for the user selected dim setting, will increment in response to a button press 

    -- CLOCK SIGNALS
    signal clk_div : std_logic;         -- 25 MHz clock to be used to synchronize all logic in this project (created utilizing clock wizard)
    signal reset : std_logic;           -- unused component of clock generated by clock wizard (***RECOMMENDED TO DELETE) 
    signal locked : std_logic;          -- unused component of clock generated by clock wizard (***RECOMMENDED TO DELETE)
    
    -- SIGNALS FOR DIM BUTTON (MIDDLE)
    signal SW_middle_out : std_logic;
    signal SW_mid_prev : std_logic;
    
    -- SIGNALS FOR MOVEMENT BUTTONS (UP, DOWN, LEFT, RIGHT)
    signal SW_up_out : std_logic;
    signal SW_up_prev : std_logic;
    signal SW_left_out : std_logic;
    signal SW_left_prev : std_logic;
    signal SW_right_out : std_logic;
    signal SW_right_prev : std_logic;
    signal SW_down_out : std_logic;
    signal SW_down_prev : std_logic;
    
    -- SIGNALS TO STORE POSITION (X AND Y INCREMENT/DECREMENT ACCORDING TO USER BUTTON PRESSES)
    -- MEANT FOR MOVEMENT OF A SPRITE
    signal yPos : integer range 0 to 31 := 0;
    signal xPos : integer range 0 to 31 := 0;
    
    -- SIGNALS FOR KEEPING TRACK OF NEXT STEP IN REFRESH PROCESS; SIGNALS UNDERGOING PROPAGATION DELAY WHEN ASSIGNED IN A PROCESS IS VITAL TO FUNCTIONALITY
    signal willLatchData, willSetBlank : std_logic := '0'; -- Will let process know when to get ready to latch (high -> low signal to board) or when the row is ready to be turned off and data clocked to it
----------------------------------------------------------------------------------------------------

    -- *** DEFINE THE DIVDED CLOCK GENERATED BY CLOCK WIZARD: ***
    component clk_wiz
        port
        (-- Clock out ports
          clk_out : out std_logic;
         -- Status and control signals (UNUSED IN CURRENT DESIGN)
          reset : in std_logic;
          locked : out std_logic;
          -- Clock in ports
          clk_in : in std_logic );
    end component;

    -- *** DECLARE A LOOKUP TABLE FOR RGB REFRESH ACCORDING TO DIM STATUS ***
----------------------------------------------------------------------------------------------------
    type Dim is array (7 downto 0) of integer;
    signal DimLookup : Dim := (1200000, 871428,742857, 614285, 485714,357142,228571,125000); -- Stores the counter values for each various user dim input
        -- Math: 1,000,000 - [(1,000,000 - 100,000)/7] * Index
            -- Where 1,000,000 - 100,000 represents the range and 7 represents the # of steps
            -- Numbers that differ required slight calibration tweaks in testing (1 mil to 1.2, 100,000 to 125k)
----------------------------------------------------------------------------------------------------

    -- *** DOUBLE FRAME BUFFER ***
----------------------------------------------------------------------------------------------------
    -- GOAL: Write all RGB values for each pixel on the screen into one buffer, transfer said buffer to secondary once finished, and have RGB values read exclusively from the second buffer (AVOIDS GLITCHES AND UNWANTED PIXEL BLURRING)
    type FrameBuffer is array (natural range<>, natural range <>) of std_logic_vector(2 downto 0); -- Declaration of the type necessary for buffer
    
    signal readBuffer : FrameBuffer(0 to 31, 0 to 31);
    signal writeBuffer : FrameBuffer(0 to 31, 0 to 31);
----------------------------------------------------------------------------------------------------
                                         
     -- *** SPRITE ***
     -- GOAL: Have a pre-designed image loaded into ROM to easily draw from according to positional values
     type SROM is array (natural range <>, natural range<>) of std_logic_vector(2 downto 0);
     signal FaceROM : SROM(0 to 19, 0 to 19) :=
     (
      ("000","000","000","000","000","000","000","000","000","000","000","000","000","000","000","000","000","000","000","000"),
      ("000","000","000","000","000","000","011","011","011","011","011","011","011","011","000","000","000","000","000","000"),
      ("000","000","000","000","000","011","011","011","011","011","011","011","011","011","011","000","000","000","000","000"),
      ("000","000","000","000","011","011","000","000","000","000","000","000","000","000","011","011","000","000","000","000"),
      ("000","000","000","011","011","000","000","000","000","000","000","000","000","000","000","011","011","000","000","000"),
      ("000","000","000","011","011","000","000","000","000","000","000","000","000","000","000","011","011","000","000","000"),
      ("000","000","000","011","011","000","000","000","000","000","000","000","000","000","000","011","011","000","000","000"),
      ("000","000","011","011","110","110","110","110","110","110","110","110","110","110","110","110","011","011","000","000"),
      ("000","011","011","011","110","110","110","110","110","110","110","110","110","110","110","110","011","011","011","000"),
      ("000","011","011","011","110","000","000","000","110","110","110","110","000","000","000","110","011","011","011","000"),
      ("000","011","011","011","110","000","000","000","110","110","110","110","000","000","000","110","011","011","011","000"),
      ("000","000","011","011","110","110","110","110","110","110","110","110","110","110","110","110","011","011","000","000"),
      ("000","000","000","011","110","110","110","110","110","110","110","110","110","110","110","110","011","000","000","000"),
      ("000","000","000","000","110","011","011","110","011","011","011","011","110","011","011","110","000","000","000","000"),
      ("000","000","000","000","110","011","011","011","011","011","011","011","011","011","011","110","000","000","000","000"),
      ("000","000","000","000","110","011","011","011","110","110","110","110","011","011","011","110","000","000","000","000"),
      ("000","000","000","000","110","110","110","110","110","110","110","110","110","110","110","110","000","000","000","000"),
      ("000","000","000","000","110","110","110","110","110","110","110","110","110","110","110","110","000","000","000","000"),
      ("000","000","000","000","110","110","110","110","110","110","110","110","110","110","110","110","000","000","000","000"),
      ("000","000","000","000","000","000","000","000","000","000","000","000","000","000","000","000","000","000","000","000"));                            
     
-- ***Architecture begin***
------------------------------------------------------------------------------------------------
begin

    --*** COMPONENT INSTANTIATION ***
    ------------------------------------------------------------------------------------------------
    ClockDivider : clk_wiz
        port map ( 
        -- Clock out ports  
            clk_out => clk_div,
        -- Status and control signals                
            reset => reset,
            locked => locked,
        -- Clock in ports
            clk_in => clk );
    ------------------------------------------------------------------------------------------------


    -- ***Sequential Blocks: ***
    ------------------------------------------------------------------------------------------------
    Main: process(clk_div)
     --*** Variable declarations: ***
     variable cycleRGB : integer := 1;                    -- Will determine when to change RGB values
     variable rgb : unsigned(2 downto 0) := "000";        -- Signal for color values of an individual pixel (initial value: black)   
     variable spriteRGB : unsigned(2 downto 0);           -- Will pull and hold RGB values from sprite ROM  
     variable dim : unsigned(2 downto 0) := "000";        -- Acts as a counter with its limit set by signal user_Dim
     --*** PROCESS BEGIN ***               
        begin
            if blank = '1' then
                clk_out <= clk_div; -- Clock data into each column while a row is shut off (blank asserted high) by sending out divided clock
            end if;
            
            if rising_edge(clk_div) then
                -- *** LOGIC TO HANDLE REFRESHING: ***
                ----------------------------------------------------------------------------------------------------------------------------------------
                if blank = '0' then   -- If blank is not set, then line is active (TURN OFF NEXT ROW)
                     -- Following if/else will allow a couple of clock cycles to account for propagation delay to turn off row
                     if willSetBlank = '0' then
                        willSetBlank <= '1';
                     else 
                        willSetBlank <= '0';
                        blank <= '1';
                     end if;

                else   -- Else means blank is set, and line is not active (updating colors will now take place)
                    
                    -- Send in current background RGB Data to board
                    R0 <= rgb(2); G0 <= rgb(1); B0 <= rgb(0);
                    R1 <= rgb(2); G1 <= rgb(1); B1 <= rgb(0);
                    
                    -- Check if the current row and column count correspond to the user selected x and y position
                    -- If true for either the top half or bottom half of the matrix, pull RGB colors from ROM and assign it to R0/R1, G0/G1, B0/B1 instead of rgb[2:0]
                    if rowCount - yPos >= 0 and rowCount - yPos <= 19 then -- Checking if rowCount - yPos <= 19 represents checking if space for 20 bits exist 
                        if xPos - colCount >= 0 and xPos - colCount <= 19 then
                            spriteRGB := unsigned(FaceROM(to_integer(rowCount) - yPos, xPos - to_integer(colCount)));
                            R0 <= spriteRGB(2);
                            G0 <= spriteRGB(1);
                            B0 <= spriteRGB(0);
                        end if;
                    end if;
                    if rowCount + 15 - yPos >= 0 and rowCount + 16 - yPos <= 19 then
                        if xPos - colCount >= 0 and xPos - colCount <= 19 then
                            spriteRGB := unsigned(FaceROM(to_integer(rowCount) + 15 - yPos, xPos - to_integer(colCount)));
                            R1 <= spriteRGB(2);
                            G1 <= spriteRGB(1);
                            B1 <= spriteRGB(0);
                        end if;
                    end if;
                                  
                    if colCount = "11111" then  -- Indicates all data is loaded into the columns, and row is ready to be latch (low to high)
                        colCount <= "00000";
                        -- Check if data needs to be reclocked to the columns to create dimming effect that the user selected
                        if dim = user_Dim then -- No reclocking required
                            dim := "000";
                            willLatchData <= '1';

                            --*** LOGIC TO SHIFT RGB BACKGROUND VALUE ***
                            cycleRGB := cycleRGB + 1;
                                if cycleRGB = DimLookup(7 - to_integer(user_Dim)) then -- Refer to lookup table to determine how high counter must go
                                    cycleRGB := 1;  -- Restart counter value
                                    rgb := rgb + 1; -- Increment color value by 1 (entire pattern is 8 including off)
                                elsif cycleRGB > DimLookup(7 - to_integer(user_Dim)) then -- ***IF DIM SETTING CHANGED AND cycleRGB > new Dim setting, THEN THIS WILL ENSURE IT DOES NOT COUNT TO OVERFLOW
                                    cycleRGB := 1;
                                end if;

                        else  -- Reclocking is required, restart from column 0 
                            dim := dim + 1;
                            willLatchData <= '0';
                        end if;
                    -- The following elsif's handle latching data into the row before moving onto the next
                    elsif willLatchData = '1' then
                        willLatchData <= '0'; -- Clear signal for future latches
                        latch <= '1';         -- Send a high signal to latch (next clock cycle will generate High -> Low necessary to latch column data)
                    elsif latch = '1' then 
                        latch <= '0'; -- Clear latch for High -> Low pulse
                        blank <= '0'; -- Turn current row on (data has now sent to all pixels)
                        -- Move to next row 
                        rowCount <= rowCount + 1; 
                        A3 <= rowCount(3);
                        A2 <= rowCount(2);
                        A1 <= rowCount(1);
                        A0 <= rowCount(0);
                    else 
                         colCount <= colCount + 1; -- Move to the next column if not yet finished
                    end if;
                end if;   
                
                ----------------------------------------------------------------------------------------------------------------------------------------
            end if;
    end process;

    -- Create a shift register of 20 bits to handle button debouncing for the middle button (dimming button)
    Middle_Button_Debouncing: process(clk_div) 
        -- A variable will update immediately in response to signals from the button 
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

    -- Create an edge detector for the middle button (dimming button)
    Middle_Button_Edge_Detector:process(clk_div)
    begin 
        if rising_edge(clk_div) then
            -- Store the previous button result in a signal (signals will lag behind the output of the debouncing)
            SW_mid_prev <= SW_middle_out;

            -- Detect a positive edge on the button by comparing the previous status to the current
            -- This ensures the button will only trigger a change in position once per press
            if SW_middle_out = '1' and SW_mid_prev = '0' then 
                user_Dim <= user_Dim + 1;
            end if;

        end if;
    end process;
    
    -- Create a process to display to the seven segment display and show the user what dim setting they are currently at
    -- Synthesizes as a multiplexor 
    Seven_Segment: process(clk_div)
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
    
    -- Create a shift register of 20 bits to handle button debouncing for the up, down, left, and right buttons
    Position_Buttons_Debouncing: process(clk_div)
        -- Variables will update immediately in response to signals from the button 
        variable shiftBtnUp : std_logic_vector(19 downto 0);
        variable shiftBtnLeft : std_logic_vector(19 downto 0);
        variable shiftBtnRight : std_logic_vector(19 downto 0);
        variable shiftBtnDown : std_logic_vector(19 downto 0);
    begin 
        if rising_edge(clk_div) then
            shiftBtnUp := shiftBtnUp(18 downto 0) & SW_up;
            shiftBtnLeft := shiftBtnLeft(18 downto 0) & SW_left;
            shiftBtnRight := shiftBtnRight(18 downto 0) & SW_right;
            shiftBtnDown := shiftBtnDown(18 downto 0) & SW_down;
            
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
    
    
    -- Create an edge detector for button presses of the up, down, left, and right buttons
    Position_Buttons_Edge_Detector: process(clk_div)
    begin 
        if rising_edge(clk_div) then
            -- store the previous button result in signals (signals will lag behind the output of the debouncing)
            SW_up_prev <= SW_up_out;
            SW_left_prev <= SW_left_out;
            SW_right_prev <= SW_right_out;
            SW_down_prev <= SW_down_out;
            
            -- Detect a positive edge on the button by comparing the previous status to the current
            -- This ensures the button will only trigger a change in position once per press
            if SW_up_out = '1' and SW_up_prev = '0' then 
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
    
    ------------------------------------------------------------------------------------------------------
-- *** END ARCHITECTURE
end behav;
