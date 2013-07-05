SparkFun's USB Weather Board contains sensors that can be used to monitor atmospheric pressure, humidity, temperature, and light level. The board can also be interfaced to wind speed, direction, and rainfall sensors available separately from Sparkfun.

Product page: www.sparkfun.com/products/10586

This archive contains the latest sketch (firmware) that the USB Weather Board uses to sample the sensors and output data. You can use this sketch as-is, modify it to suit your own purposes, or write your own sketches from scratch. See the datasheet and schematics for more information.

Installation:

Install the latest version of the Arduino IDE, available at www.arduino.cc. This code was tested using Arduino versions 1.0.3 and 1.0.4.

This sketch requires several nonstandard libraries (special device interface code):

* SHT15x by Jonathan Oxer et.al.
* SFE_BMP085 library by SparkFun
	
These libraries are included in this archive, and must be installed onto your computer in order for the code to compile correctly. See the instructions below.

Installing the required files:

TL;DR: The one-step procedure to install all of the required files is to drag the contents of the Arduino folder contained in this archive into your personal Arduino sketch folder (this is normally located in your personal documents folder.) This will create a "libraries" folder (containing the above libraries), and a "Weather_Board_3" folder containing the sketch.

If there is already a "libraries" folder, add the included libraries to it. If there are older versions of the above libraries in the folder, please replace them with the versions in this archive. If it is running, restart the Arduino IDE to get it to recognize the new libraries.

Loading the firmware onto your USB Weather Board:

1. Connect the USB Weather Board to your computer using a standard mini-B USB cable (available everywhere including www.sparkfun.com). Move both switches on the USB Weather Board to USB. The red LED should light up and your computer should automatically install the FTDI drivers and create a virtual COM port. If there is a problem installing the FTDI drivers, please see the instructions at www.arduino.cc.

2. Start the Arduino IDE.

3. Select the following board type from the Tools/Board menu: "Arduino Pro or Pro Mini (3.3V, 8MHz) w/ATmega328"

4. Select the correct serial port from the Tools/Serial Port menu. This will be the port that your FTDI board or cable has created, it is usually the highest numbered port in the list of options.

5. Load (up-arrow button) the Weather_Board_3.ino sketch into the Arduino IDE.

6. Click on the Upload (right arrow) button at the top of the window. The code should compile then upload to the USB Weather Board. If there are any errors, double-check that you installed the required libraries to the correct folder, and have restarted the Arduino IDE. If you continue to have problems, please contact SparkFun Technical Support (see the "Contact" section of www.sparkfun.com) and they'll be happy to help you get up and running.

Once the sketch is uploaded, the green LED will blink three times and the board will begin running. To check the output, you can use the terminal software of your choice, or open the Arduino IDE's Serial Monitor window (magnifying-glass button). Ensure that the Serial Monitor window is set to "9600 baud", and that line ending is set to "carriage return". To bring up the menu, type a 'Z' character into the entry box at the top of the window, and press send or hit return. See the datasheet for more information.

If you have questions, don't hesistate to contact us at techsupport@sparkfun.com.

Have fun!
Your friends at SparkFun.
