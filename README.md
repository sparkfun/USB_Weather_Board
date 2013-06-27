SparkFun's USB Weather Board contains sensors that can be used to monitor atmospheric pressure, humidity, temperature, and light level. The board can also be interfaced to wind speed, direction, and rainfall sensors available separately from Sparkfun.

This archive contains the latest sketch (software) that the USB Weather Board uses to sample the sensors and output data. You can also modify this sketch to suit your own purposes, or write your own sketch from scratch. See the product page at: https://www.sparkfun.com/products/10586 for more information.

Installation:

Install the latest version of the Arduino IDE, available at http://www.arduino.cc.

This sketch requires several nonstandard libraries (interface code):

	SHT15x by Jonathan Oxer et.al.
  SFE_BMP085 library by SparkFun
	
The necessary versions of these libraries are included in this archive. These libraries must be installed onto your computer in order for the code to compile correctly.

Installing the libraries:

TL;DR: The one-step procedure to install all the software is to drag the contents of the Arduino folder in this archive into your personal Arduino sketch folder. This will create a "libraries" folder (containing support libraries), and a "Weather_Board_3" folder containing 
the firmware.

To install the libraries manually, copy the "libraries" folder to your personal Arduino sketch directory. (If there is already a "libraries" folder there, go ahead and add the included libraries to it.)  If there are older versions of the above libraries, please replace them with these. If it is running, you'll need to restart the Arduino IDE to get it to recognize the new libraries.

Installing the sketch:

To install the sketch, copy the "Weather_Board_3" folder to your personal Arduino sketch folder.

Loading the firmware onto your USB Weather Board:

1. Connect the USB Weather Board to your computer using a standard mini-B USB cable (available everywhere including www.sparkfun.com). Move both switches on the USB Weather Board to USB. The red LED should light up and your computer should automatically install the drivers and a virtual COM port. If an error occurs, see the instructions at www.arduino.cc.

2. Start the Arduino IDE.

3. Select the correct board type from the Tools/Board menu: "Arduino Pro or Pro Mini (3.3V, 8MHz) w/ATmega328"

4. Select the correct serial port from the Tools/Serial Port menu. Thi (the port that your FTDI board or cable has created, usually the highest number)

5. Load the Weather_Board_3.ino sketch into the Arduino IDE.

6. Click on the Upload (right arrow) button at the top of the window. The code should compile then upload to the USB Weather Board. If there are any errors, double-check that you installed the required libraries to the correct place, and restarted the Arduino IDE. If you continue to have problems, please contact SparkFun Technical Support (see the "Contact" section of www.sparkfun.com) and they will be happy to help you get up and running.

Have fun!
Your friends at SparkFun.
