# Adafruit_RGB_Matrix
For this project, a Basys 3 board and an Adafruit RGB matrix are being utilized to develop a pattern generator (written in VHDL), create a double buffered frame buffer, and output drive logic to display patterns on the RGB matrix. 

---------------------------------------------------------------------------------------------------

## Equipment Utilized:
[Digilent Basys 3 FPGA Board](https://digilent.com/reference/_media/basys3:basys3_rm.pdf)

[Adafruit 32x32 RGB LED Matrix Panel](https://cdn-learn.adafruit.com/downloads/pdf/32x16-32x32-rgb-led-matrix.pdf)

## Software Utilized:
[Xilinx Vivado](https://docs.xilinx.com/search/all?content-lang=en-US)

## Miscellanous Online References:
[Driving a 64*64 RGB LED panel with an FPGA](https://justanotherelectronicsblog.com/?p=636)

----------------------------------------------------------------------------------------------------

>[!IMPORTANT] 
>1. The pattern generator and frame buffer logic is specific to the 32x32 matrix. Other sizes will vary in their implementation.
>2. If using a different FPGA board, refer to that board's specifications to ensure it will properly drive the matrix. 