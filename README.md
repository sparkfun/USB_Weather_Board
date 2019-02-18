# **NOTE: This product has been retired from our catalog. The information contained here is for reference only. No support is guaranteed. For a new version, please check out our [Weather Shield](https://www.sparkfun.com/products/12081).**

*If you are looking for more up-to-date info, please check out some of these resources to see how other users are still hacking and improving on this product.*
* *[SparkFun Forum](https://forum.sparkfun.com/)*
* *[Comments Here on GitHub](https://github.com/sparkfun/USB_Weather_Board/issues)*
* *[IRC Channel](https://www.sparkfun.com/news/263)*

## USB Weather Board [(SEN-10586)](https://www.sparkfun.com/products/10586)

<img src="https://dlnmh9ip6v2uc.cloudfront.net/images/products/1/0/5/8/6/10586-05b.jpg" alt="USB Weather Board" height="300" width="300">

SparkFun's USB Weather Board contains sensors that can be used to monitor atmospheric pressure, humidity, temperature, and light level. The board can also be interfaced to wind speed, direction, and rainfall sensors available separately from Sparkfun.

Product page: [www.sparkfun.com/products/10586](https://www.sparkfun.com/products/10586)

User guide: [https://github.com/sparkfun/USB_Weather\_Board/blob/master/USB\_Weather\_Board\_V3\_datasheet\_130705.pdf?raw=true](https://github.com/sparkfun/USB_Weather_Board/blob/master/USB_Weather_Board_V3_datasheet_130705.pdf?raw=true)

Github repository: [https://github.com/sparkfun/USB\_Weather\_Board](https://github.com/sparkfun/USB_Weather_Board)

This archive contains the latest sketch (firmware) that the USB Weather Board uses to sample the sensors and output data. You can use this sketch as-is, modify it to suit your own purposes, or write your own sketches from scratch. See the datasheet and schematics for more information.

### Installation:

If you haven't, install the free Arduino IDE, available at [www.arduino.cc](http://www.arduino.cc). This code was tested using Arduino versions 1.0.3, 1.0.4 and 1.0.5.

This sketch requires several nonstandard libraries (special device interface code):

* SHT15x by Jonathan Oxer et.al.
* SFE_BMP085 library by SparkFun
	
These libraries are included in this archive, and must be installed onto your computer in order for the code to compile correctly. See the instructions below.

#### Installing the required files:

TL;DR: The one-step procedure to install all of the required files is to drag the contents of the Arduino folder contained in this archive into your personal Arduino sketch folder (this is normally located in your personal documents folder.) This will create a "libraries" folder (containing the above libraries), and a "Weather\_Board\_3" folder containing the sketch.

If there is already a "libraries" folder, add the included libraries to it. If there are older versions of the above libraries in the folder, please replace them with the versions in this archive. If it is running, restart the Arduino IDE to get it to recognize the new libraries.

#### Loading the firmware onto your USB Weather Board:

1. Connect the USB Weather Board to your computer using a standard mini-B USB cable (available everywhere including www.sparkfun.com). Move both switches on the USB Weather Board to USB. The red LED should light up and your computer should automatically install the FTDI drivers and create a virtual COM port. If there is a problem installing the FTDI drivers, please see the instructions at www.arduino.cc.

2. Start the Arduino IDE.

3. Select the following board type from the Tools/Board menu: "Arduino Pro or Pro Mini (3.3V, 8MHz) w/ATmega328"

4. Select the correct serial port from the Tools/Serial Port menu. This will be the port that your FTDI board or cable has created, it is usually the highest numbered port in the list of options.

5. Load (up-arrow button) the weather\_board\_3.ino sketch into the Arduino IDE.

6. Click on the Upload (right arrow) button at the top of the window. The code should compile then upload to the USB Weather Board. If there are any errors, double-check that you installed the required libraries to the correct folder, and have restarted the Arduino IDE. If you continue to have problems, please contact SparkFun Technical Support (see the "Contact" section of www.sparkfun.com) and they'll be happy to help you get up and running.

Once the sketch is uploaded, the green LED will blink three times and the board will begin running. To check the output, you can use the terminal software of your choice, or open the Arduino IDE's Serial Monitor window (magnifying-glass button). Ensure that the Serial Monitor window is set to "9600 baud", and that line ending is set to "carriage return". To bring up the menu, type a 'Z' character into the entry box at the top of the window, and press send or hit return. See the datasheet for more information.

If you have questions, don't hesistate to contact us at techsupport@sparkfun.com.

Have fun!
Your friends at SparkFun.

### Revision history:

1.4 2013/7/5

> Changed all menu operations to completely support Arduino serial monitor (CR/NL ignored unless needed). Set Arduino serial monitor to 9600 baud, and line endings to carriage return.

1.3 2013/6/25

> Added code to prevent an intermittent lockup when rebooting; now resets the humidity sensor connection before intializing the BMP085. Many thanks to Nathan Isherwood.
		
> Added plain 'Z' and 'z' as well as CTRL-Z to enter menu to better support Arduino serial monitor.
		
> Fixed error in rain-gauge constant. Many thanks to Michael Bauer.

> Added reset to factory defaults option to menu.

> Moved constant strings to flash (freed over 1K bytes!)

1.2 2012/1/23

> Update all code to be compatible with Arduino 1.0
		
1.1 2011/08/01

> Changed sample_rate to 32-bit, max = 4294966 seconds (47 days)

> RAM is also getting tight, so removed some error strings and added RAM gauge to menu.
		
1.0 2011/06/27

> Initial release
