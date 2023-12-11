# Adafruit_RGB_Matrix
For this project, a Basys 3 board and an Adafruit RGB matrix are being utilized with the goal to develop a pattern generator (written in VHDL), create a double buffered frame buffer, and output drive logic to display patterns on the RGB matrix. 

---------------------------------------------------------------------------------------------------

## Equipment Utilized:
[Digilent Basys 3 FPGA Board](https://digilent.com/reference/_media/basys3:basys3_rm.pdf)

[Adafruit 32x32 RGB LED Matrix Panel](https://cdn-learn.adafruit.com/downloads/pdf/32x16-32x32-rgb-led-matrix.pdf)

## Software Utilized:
[Xilinx Vivado](https://docs.xilinx.com/search/all?content-lang=en-US)

## Miscellanous Online References:
[Driving a 64*64 RGB LED panel with an FPGA](https://justanotherelectronicsblog.com/?p=636)

[RGB LED Panel Driver Tutorial](https://bikerglen.com/projects/lighting/led-panel-1up/)

----------------------------------------------------------------------------------------------------

>[!IMPORTANT] 
>1. The pattern generator and frame buffer logic is specific to the 32x32 matrix. Other sizes will vary in their implementation.
>2. If using a different FPGA board, refer to that board's specifications to ensure it will properly drive the matrix. 

----------------------------------------------------------------------------------------------------

## Useful Reference Images from Online Sources:
1. Figure 1: Adafruit RGB Matrix Pinout: Image/Quote from justanotherelectronicsblog.com: "The RGB matrix just has 16 pins, with the pinout being as follows" 

![Alt text](ReferenceImages/Figure%201.%20Pinout%20of%20the%20RGB%20matrix%20(from%20justanotherelectronicsblog.com).png?raw=true "Figure 1")

2. Figure 2: Intended Waveform Behavior of the Adafruit RGB Matrix: Image from justanotherelectronicsblog.com

![Alt text](ReferenceImages/Figure%202.%20Waveform%20behavior%20of%20the%20RGB%20matrix%20(from%20justanotherelectronicsblog.com).png?raw=true "Figure 2")

3. Figure 3: Basic State Machine for Frame Buffer to RGB Matrix:L Image from justanotherelectronicsblog.com

![Alt text](ReferenceImages/Figure%203.%20Frame%20buffer%20for%20matrix%20(from%20justanotherelectronicsblog.com).png?raw=true "Figure 3")

4. Figure 4: Image/Quote from bikerglen.com: "RGB LED panel column and row driver organization." 

![Alt text](ReferenceImages/Figure%204.%20RGB%20LED%20panel%20column%20and%20row%20driver%20organization%20(bikerglen.com).png?raw=true "Figure 4")

5. Figure 5: Image/Quote from bikerglen.com: "Column driver operation for the R0 data input and top-half red columns outputs. There are two more of these shift registers at the top of the display for the top-half green and blue columns and three more at the bottom for the bottom half red, green, and blue columns."

![Alt text](ReferenceImages/Figure%205.%20Column%20driver%20operation%20for%20the%20R0%20data%20input%20and%20top%20half%20red%20columns%20outputs%20(from%20bikerglen.com).png?raw=true "Figure 5")