// USB Weather Board V3 firmware
// Mike Grusin, SparkFun Electronics
// www.sparkfun.com

// Compile and load onto SparkFun USB Weather Board V3 using Arduino development envrionment,
// Download from www.arduino.cc

// Uses the SHT15x library by Jonathan Oxer et.al.
// Supplied with this software distribution, or download from https://github.com/practicalarduino/SHT1x.
// Place in your Arduino sketchbook under "libraries/SHT1x"

// Uses the SFE_BMP085 library by SparkFun with math from http://wmrx00.sourceforge.net/Arduino/BMP085-Calcs.pdf
// Supplied with this distribution; place in your Arduino sketchbook under "libraries/SFE_BMP085"

// License:
// This code is free to use, change, improve, even sell!  All we ask for is two things:
// 1. That you give SparkFun credit for the original code,
// 2. If you sell or give it away, you do so under the same license so others can do the same thing.
// More at http://creativecommons.org/licenses/by-sa/3.0/

// Have fun! 
// -your friends at SparkFun

// Revision history
// 1.2 Update all code to be compatible with Arduino 1.0 2012/1/23
// 1.1 changed sample_rate to 32-bit, max = 4294966 seconds (47 days)
//     RAM is also getting tight, so removed some error strings and added RAM gauge to menu 2011/08/01
// 1.0 initial release, 2011/06/27

// firmware version
const char version_major = 1;
const char version_minor = 2;

// external libraries
#include <SHT1x.h> // SHT15 humidity sensor library
#include <SFE_BMP085.h> // BMP085 pressure sensor library
#include <Wire.h> // I2C library (necessary for pressure sensor)
#include <avr/eeprom.h> // extended EEPROM read/write functions

// digital I/O pins
// (the following three are predefined)
// const int SCK = 13;
// const int MISO = 12;
// const int MOSI = 11;
const int XCLR = 9;
const int EOC = 8;
const int RF_RTS = 6;
const int RF_CTS = 5;
const int STATUSLED = 4;
const int WSPEED = 3;
const int RAIN = 2;

// analog I/O pins
const int LIGHT = 7;
const int BATT_LVL = 6;
const int WDIR = 0;

// global variables
float SHT15_humidity;
float SHT15_temp;
float SHT15_dewpoint;
double BMP085_pressure;
double BMP085_temp;
float TEMT6000_light;
float WM_wspeed;
float WM_wdirection;
float WM_rainfall = 0.0;
float batt_volts;
int LED = 0; // status LED
unsigned int windRPM, stopped;
// volatiles are subject to modification by IRQs
volatile unsigned long tempwindRPM, windtime, windlast, windinterval;
volatile unsigned char windintcount;
volatile boolean gotwspeed;
volatile unsigned long raintime, rainlast, raininterval, rain;

// constant conversion factors
const int BATT_RATIO = 63.3271; // divide ADC from BATT_LVL by this to get volts
const float WIND_RPM_TO_MPH = 22.686745; // divide RPM by this for velocity
const float WIND_RPM_TO_MPS = 50.748803; // divide RPM by this for meters per second
const float RAIN_BUCKETS_TO_INCHES = 0.0086206896; // multiply bucket tips by this for inches
const float RAIN_BUCKETS_TO_MM = 0.21896551; // multiply bucket tips by this for mm 
const unsigned int ZERODELAY = 4000; // ms, zero RPM if no result for this time period (see irq below)

// sensor objects
SHT1x humidity_sensor(A4, A5);
SFE_BMP085 pressure_sensor(BMP_ADDR);

// enumerated options, changed in user menu

// output format
const int CSV = 1; // default NMEA-like comma-separated values
const int ANSI = 2; // ANSI-formatted data with hardware testing
const int LCD = 3; // directly drive a SparkFun serial-enabled 16x2 LCD display

// general units
const int ENGLISH = 1; // wind speed in miles per hour, rain in inches, temperature in degrees Fahrenheit
const int SI = 2; // International System, aka the metric system. Wind speed in meters per second, rain in mm, temperature in degrees Celsius

// pressure units
const int MBAR = 1; // millibars
const int INHG = 2; // inches of mercury (US weather report standard)
const int PSI = 3; // pounds per square inch

// pressure type
const int ABSOLUTE = 1; // absolute (true) pressure, changes with altitude (ignore altitude variable)
const int RELATIVE = 2; // relative (weather) pressure, altitude effects removed (use altitude variable)

// defaults, replaced with EEPROM settings if saved
int data_format = ANSI;
int general_units = ENGLISH;
unsigned long sample_rate = 2; // sample rate (seconds per sample, 0 for as fast as possible)
int pressure_type = RELATIVE;
long altitude = 1596; // fixed weather station altitude in meters, for relative (sea level) pressure measurement
int pressure_units = INHG;
boolean weather_meters_attached = true; // true if we've hooked up SparkFun's Weather Meters (SEN-08942) (set to false to remove weather meters data from output)
long baud_rate = 9600; // default baud rate

// hardware memory pointers, used by freeMemory() (see: http://www.arduino.cc/playground/Code/AvailableMemory)

extern unsigned int __bss_end;
extern unsigned int __heap_start;
extern void *__brkval;

int freeMemory()
{
  int free_memory;

  if((int)__brkval == 0)
     free_memory = ((int)&free_memory) - ((int)&__bss_end);
  else
    free_memory = ((int)&free_memory) - ((int)__brkval);

  return free_memory;
}

// interrupt routines (these are called by the hardware interrupts, not by the main code)

void rainIRQ()
// if the Weather Meters are attached, count rain gauge bucket tips as they occur
// activated by the magnet and reed switch in the rain gauge, attached to input D2
{
  raintime = micros(); // grab current time
  raininterval = raintime - rainlast; // calculate interval between this and last event

  if (raininterval > 100) // ignore switch-bounce glitches less than 100uS after initial edge
  {
    rain++; // increment bucket counter
    rainlast = raintime; // set up for next event
  }
}

void wspeedIRQ()
// if the Weather Meters are attached, measure anemometer RPM (2 ticks per rotation), set flag if RPM is updated
// activated by the magnet in the anemometer (2 ticks per rotation), attached to input D3

// this routine measures RPM by measuring the time between anemometer pulses
// windintcount is the number of pulses we've measured - we need two to measure one full rotation (eliminates any bias between the position of the two magnets)
// when windintcount is 2, we can calculate the RPM based on the total time from when we got the first pulse
// note that this routine still needs an outside mechanism to zero the RPM if the anemometer is stopped (no pulses occur within a given period of time)
{
  windtime = micros(); // grab current time
  if ((windintcount == 0) || ((windtime - windlast) > 10000)) // ignore switch-bounce glitches less than 10ms after the reed switch closes
  {
    if (windintcount == 0) // if we're starting a new measurement, reset the interval
      windinterval = 0;  
    else
      windinterval += (windtime - windlast); // otherwise, add current interval to the interval timer

    if (windintcount == 2) // we have two measurements (one full rotation), so calculate result and start a new measurement
    {
      tempwindRPM = (60000000ul / windinterval); // calculate RPM (temporary since it may change unexpectedly)
      windintcount = 0;
      windinterval = 0;  
      gotwspeed = true; // set flag for main loop
    }

    windintcount++;    
    windlast = windtime; // save the current time so that we can calculate the interval between now and the next interrupt
  }
}

void setup()
// this procedure runs once upon startup or reboot
// perform all the settings we need before running the main loop
{
  // set up inputs and outputs
  pinMode(XCLR,OUTPUT); // output to BMP085 reset (unused)
  digitalWrite(XCLR,HIGH); // make pin high to turn off reset 
  
  pinMode(EOC,INPUT); // input from BMP085 end of conversion (unused)
  digitalWrite(EOC,LOW); // turn off pullup
  
  pinMode(STATUSLED,OUTPUT); // output to status LED
  
  pinMode(WSPEED,INPUT); // input from wind meters windspeed sensor
  digitalWrite(WSPEED,HIGH); // turn on pullup
  
  pinMode(RAIN,INPUT); // input from wind meters rain gauge sensor
  digitalWrite(RAIN,HIGH); // turn on pullup

  // get settings from EEPROM (use defaults if EEPROM has not been used)
  retrieveEEPROMsettings();
  
  // initialize serial port
  Serial.begin(baud_rate);
  Serial.println();
  Serial.println("RESET");

  // initialize BMP085 pressure sensor
  if (pressure_sensor.begin() == 0)
    error(1);

  // init wind speed interrupt global variables
  gotwspeed = false; windRPM = 0; windintcount = 0;
 
  // blink status LED 3 times
  digitalWrite(STATUSLED,HIGH);
  delay(100);
  digitalWrite(STATUSLED,LOW);
  delay(250);
  digitalWrite(STATUSLED,HIGH);
  delay(100);
  digitalWrite(STATUSLED,LOW);
  delay(250);
  digitalWrite(STATUSLED,HIGH);
  delay(100);
  digitalWrite(STATUSLED,LOW);
  delay(250);

  if (weather_meters_attached)
  {
    // attach external interrupt pins to IRQ functions
    attachInterrupt(0,rainIRQ,FALLING);
    attachInterrupt(1,wspeedIRQ,FALLING);
    
    // turn on interrupts
    interrupts();
  }
}

void loop()
// loops forever after setup() ends
{
  static long templong, windstopped;
  static unsigned long loopstart, loopend;
  double Tn, m;
  static char LCDstate;
  char status;
  
  // record current time so we can sample at regular intervals
  loopstart = millis();
  loopend = loopstart + (sample_rate * 1000ul);

  // turn on LED while we're doing measurements
  digitalWrite(STATUSLED,HIGH);

  // an interrupt occurred, handle it now
  if (gotwspeed)
  {
    gotwspeed = false;
    windRPM = word(tempwindRPM); // grab the RPM value calculated by the interrupt routine
    windstopped = millis() + ZERODELAY; // save this timestamp
  }

  // zero wind speed RPM if we don't get a reading in ZERODELAY ms
  if (millis() > windstopped)
  {
    windRPM = 0; windintcount = 0;
  }
  
  TWCR &= ~(_BV(TWEN));  // turn off I2C enable bit so we can access the SHT15 humidity sensor

  // get humidity and temp (SHT15)
  SHT15_temp = humidity_sensor.readTemperatureC();
  SHT15_humidity = humidity_sensor.readHumidity();

  // compute dewpoint (because we can!)
  if (SHT15_temp > 0.0)
    {Tn = 243.12; m = 17.62;}
  else
    {Tn = 272.62; m = 22.46;}

  SHT15_dewpoint = (Tn*(log(SHT15_humidity/100)+((m*SHT15_temp)/(Tn+SHT15_temp)))/(m-log(SHT15_humidity/100)-((m*SHT15_temp)/(Tn+SHT15_temp))));

  // get temp (SHT15)
  switch (general_units)
  {
    case ENGLISH: // Fahrenheit
      SHT15_temp = (SHT15_temp*9.0/5.0)+32.0;
      SHT15_dewpoint = (SHT15_dewpoint*9.0/5.0)+32.0;
      break;
    case SI: // celsius, don't need to do anything
      break;
    default:
      SHT15_temp = -1.0; // error, invalid units
      SHT15_dewpoint = -1.0; // error, invalid units
  }

  TWCR |= _BV(TWEN);  // turn on I2C enable bit so we can access the BMP085 pressure sensor

  // start BMP085 temperature reading
  status = pressure_sensor.startTemperature();
  if (status != 0)
    delay(status); // if nonzero, status is number of ms to wait for reading to become available
  else
    error(2);
    
  // retrieve BMP085 temperature reading
  status = pressure_sensor.getTemperature(&BMP085_temp); // deg C
  if (status == 0)
    error(3);
  
  // start BMP085 pressure reading
  status = pressure_sensor.startPressure(3);
  if (status != 0)
    delay(status); // if nonzero, status is number of ms to wait for reading to become available
  else
    error(4);
    
  // retrieve BMP085 pressure reading
  status = pressure_sensor.getPressure(&BMP085_pressure, &BMP085_temp); // mbar, deg C
  if (status == 0)
    error(5);
 
  // compensate for altitude if needed
  if (pressure_type == RELATIVE)
    BMP085_pressure = pressure_sensor.sealevel(BMP085_pressure,altitude);

  // convert to desired units
  switch (general_units)
  {
    case SI: // celsius
      // do nothing, already C
      break;
    case ENGLISH: // Fahrenheit
      BMP085_temp = BMP085_temp * 1.8 + 32.0;
      break;
    default:
      BMP085_temp = -1.0; // error, invalid units
  }

  switch (pressure_units)
  {
    case MBAR:
      // do nothing, already mbar
      break;
    case INHG:
      BMP085_pressure = BMP085_pressure / 33.8600000;
      break;
    case PSI:
      BMP085_pressure = BMP085_pressure / 68.9475728;
      break;
    default:
      BMP085_pressure = -1.0; // error, invalid units
  }

  // get light
  TEMT6000_light = (1023.0 - float(analogRead(LIGHT))) / 10.23; // 0-100 percent

  // windspeed unit conversion
  switch (general_units)
  {
    case SI: // meters per second
      WM_wspeed = float(windRPM) / WIND_RPM_TO_MPS;
      break;
    case ENGLISH: // miles per hour
      WM_wspeed = float(windRPM) / WIND_RPM_TO_MPH;
      break;
    default:
      WM_wspeed = -1.0; // error, invalid units
  }

  // get wind direction
  WM_wdirection = get_wind_direction();

  // rainfall unit conversion
  switch (general_units)
  {
    case SI: // mm
      WM_rainfall = rain * RAIN_BUCKETS_TO_MM;
      break;
    case ENGLISH: // inches
      WM_rainfall = rain * RAIN_BUCKETS_TO_INCHES;
      break;
    default:
      WM_rainfall = -1.0; // error, invalid units
  }

  // get battery voltage
  batt_volts = float(analogRead(BATT_LVL)) / BATT_RATIO;

  // below are a bunch of nested switch statements to handle the different output data_formats that are possible
  // feel free to modify them or add your own!

  switch (data_format)
  {

    case CSV: // data_format: comma-separated values
    {
      // number after values is number of digits after decimal point to print
      Serial.print("$");
      printComma();
      Serial.print(SHT15_temp,1);
      printComma();
      Serial.print(SHT15_humidity,0);
      printComma();
      Serial.print(SHT15_dewpoint,1);
      printComma();
      switch (pressure_units) // change decimal point for different units
      {
        case MBAR:
          Serial.print(BMP085_pressure,2);
          break;
        case INHG:
          Serial.print(BMP085_pressure,3);
          break;
        case PSI:
          Serial.print(BMP085_pressure,4);
          break;
      }
      printComma();
      // Serial.print(BMP085_temp,1);  // for CSV format, we'll only output the SHT15 temperature
      // Serial.print(",");
      Serial.print(TEMT6000_light,1);
      printComma();
      if (weather_meters_attached)
      {
        Serial.print(WM_wspeed,1);
        printComma();
        Serial.print(WM_wdirection,0);
        printComma();
        switch (general_units) // change decimal point for different units
        {
          case ENGLISH:
            Serial.print(WM_rainfall,2);
            break;
          case SI:
            Serial.print(WM_rainfall,1);
            break;
        }
        printComma();
      }
      Serial.print(batt_volts,2);
      printComma();
      Serial.print("*");
      Serial.println();
    }
    break;

    case ANSI: // this data_format neatly formats the data on an ANSI terminal, and has pass/fail values for testing
    {
      ansiHome();
      Serial.println();
  
      Serial.print("SHT15 temperature:");
      ansiTab();
      ansiTab();
      Serial.print(SHT15_temp,1);
      Serial.print(" deg ");
      switch (general_units)
      {
        case ENGLISH:
          Serial.print("F ");
          ansiTab();
          if ((SHT15_temp > 60) && (SHT15_temp < 85)) pass(); else fail();
          break;
        case SI:
          Serial.print("C ");
          ansiTab();
          if ((SHT15_temp > 15) && (SHT15_temp < 30)) pass(); else fail();
          break;
      }

      Serial.print("SHT15 humidity:  ");
      ansiTab();
      ansiTab();
      Serial.print(SHT15_humidity,0);
      Serial.print("% ");
      ansiTab();
      ansiTab();
      if ((SHT15_humidity > 10) && (SHT15_humidity < 90)) pass(); else fail();


      Serial.print("SHT15 dewpoint:  ");
      ansiTab();
      ansiTab();
      Serial.print(SHT15_dewpoint,1);
      Serial.print(" deg ");
      switch (general_units)
      {
        case ENGLISH:
          Serial.println("F ");
          break;
        case SI:
          Serial.println("C ");
          break;
      }

      Serial.print("BMP085 pressure:");
      ansiTab();
      ansiTab();
      switch (pressure_units) // change decimal point for different units
      {
        case MBAR:
          Serial.print(BMP085_pressure,2);
          Serial.print(" mbar ");
          ansiTab();
          if ((BMP085_pressure > 900) && (BMP085_pressure < 1100)) pass(); else fail();
          break;
        case INHG:
          Serial.print(BMP085_pressure,3);
          Serial.print(" in Hg ");
          ansiTab();
          if ((BMP085_pressure > 25) && (BMP085_pressure < 35)) pass(); else fail();
          break;
        case PSI:
          Serial.print(BMP085_pressure,4);
          Serial.print(" PSI ");
          ansiTab();
          if ((BMP085_pressure > 13) && (BMP085_pressure < 15)) pass(); else fail();
          break;
      }

      Serial.print("BMP085 temperature:");
      ansiTab();
      ansiTab();
      Serial.print(BMP085_temp,1);
      Serial.print(" deg ");
      switch (general_units)
      {
        case ENGLISH:
          Serial.print("F ");
          ansiTab();
          if ((BMP085_temp > 60) && (BMP085_temp < 90)) pass(); else fail();
          break;
        case SI:
          Serial.print("C ");
          ansiTab();
          if ((BMP085_temp > 15) && (BMP085_temp < 35)) pass(); else fail();
          break;
      }
  
      Serial.print("TEMT6000 light:  ");
      ansiTab();
      ansiTab();
      Serial.print(TEMT6000_light,1);
      Serial.print("% ");
      ansiTab();
      ansiTab();
      if ((TEMT6000_light > 0) && (TEMT6000_light < 100)) pass(); else fail();
  
      if (weather_meters_attached)
      {
        Serial.print("Weather meters wind speed:");
        ansiTab();
        Serial.print(WM_wspeed,1);
        switch (general_units)
        {
          case ENGLISH:
            Serial.print(" MPH ");
            ansiTab();
            if (WM_wspeed > 0.0) pass(); else fail();
            break;
          case SI:
            Serial.print(" m/s ");
            ansiTab();
            ansiTab();
            if (WM_wspeed > 0.0) pass(); else fail();
            break;
        }
    
        Serial.print("Weather meters wind direction:");
        ansiTab();
        Serial.print(WM_wdirection,0);
        Serial.print(" degrees ");
        ansiTab();
        // direction will read -1 if wind direction sensor is disconnected or faulty
        if (WM_wdirection != -1) pass(); else fail();
    
        Serial.print("Weather meters rainfall:");
        ansiTab();
        switch (general_units)
        {
          case ENGLISH:
            Serial.print(WM_rainfall,2);
            Serial.print(" inches ");
            ansiTab();
            if (WM_rainfall > 0.05) pass(); else fail();
            break;
          case SI:
            Serial.print(WM_rainfall,0);
            Serial.print(" mm ");
            ansiTab();
            ansiTab();
            if (WM_rainfall > 0.5) pass(); else fail();
            break;
        }
      }
      Serial.print("External power:  ");
      ansiTab();
      ansiTab();
      Serial.print(batt_volts,2);
      Serial.print(" Volts ");
      ansiTab();
      if ((batt_volts > 3.5) && (batt_volts < 13.0)) pass(); else fail();
      Serial.println();
    }
    break;

    case LCD: // this data_format will directly drive a SparkFun serial-enabled 16x2 LCD
    // since you can't show everything at once on a small LCD display, this routine rotates through the values,
    // displaying a different set every time we pass through the loop() using LCDstate to keep track of where it is
    // to change the display rate, change the sample rate in the menu
    {
      LCDclear();
      switch (LCDstate)
      {
        case 0:
          LCDline1();
          Serial.print("temp: ");
          Serial.print(SHT15_temp,1);
          switch (general_units)
          {
            case ENGLISH:
              Serial.print(" F");
              break;
            case SI:
              Serial.print(" C");
              break;
          }
          LCDline2();
          Serial.print("humid: ");
          Serial.print(SHT15_humidity,0);
          Serial.print("%");
          break;
        case 1:
          LCDline1();
          Serial.print("baro: ");
          switch (pressure_units) // change decimal point for different units
          {
            case MBAR:
              Serial.print(BMP085_pressure,2);
              Serial.print(" mb");
              break;
            case INHG:
              Serial.print(BMP085_pressure,3);
              Serial.print(" in");
              break;
            case PSI:
              Serial.print(BMP085_pressure,3);
              Serial.print(" PSI");
              break;
          }
          LCDline2();
          Serial.print("dewp: ");
          Serial.print(SHT15_dewpoint,1);
          switch (general_units)
          {
            case ENGLISH:
              Serial.print(" F");
              break;
            case SI:
              Serial.print(" C");
              break;
          }
          break;
        case 2:
          LCDline1();
          Serial.print("wind: ");
          Serial.print(WM_wspeed,1);
          switch (general_units)
          {
            case ENGLISH:
              Serial.print(" MPH");
              break;
            case SI:
              Serial.print(" m/s");
              break;
          }
          LCDline2();
          Serial.print("dir: ");
          Serial.print(WM_wdirection,0);
          Serial.print(" deg");
          break;
        case 3:
          LCDline1();
          Serial.print("rain: ");
          switch (general_units)
          {
            case ENGLISH:
              Serial.print(WM_rainfall,2);
              Serial.print(" in");
              break;
            case SI:
              Serial.print(WM_rainfall,0);
              Serial.print(" mm");
              break;
          }
          LCDline2();
          Serial.print("light: ");
          Serial.print(TEMT6000_light,1);
          Serial.print("%");
          break;
      }
      LCDstate++;
      // reset LCDstate to 0 depending on whether we want to show the Weather Meters data or not
      if ((weather_meters_attached && (LCDstate > 3)) || (!weather_meters_attached && (LCDstate > 1))) 
        LCDstate = 0;
      break;
    }
  }

  // turn off LED (done with measurements)
  digitalWrite(STATUSLED,LOW);

  // we're done sampling all the sensors and printing out the results
  // now wait in a loop for the next sample time
  // while we're waiting, we'll check the serial port to see if the user has pressed CTRL-Z to activate the menu
  do // this is a rare instance of do-while - we need to run through this loop at least once to see if CTRL-Z has been pressed
  {
    while (Serial.available())
    {
      if (Serial.read() == 0x1A) // CTRL-Z
      {
        menu(); // display the menu and allow settings to be changed
        loopend = millis(); // we're done with the menu, break out of the do-while
      }
    }
  }
  while(millis() < loopend);
}

float get_wind_direction() 
// read the wind direction sensor, return heading in degrees
{
  unsigned int adc;
  
  adc = analogRead(WDIR); // get the current reading from the sensor
  
  // The following table is ADC readings for the wind direction sensor output, sorted from low to high.
  // Each threshold is the midpoint between adjacent headings. The output is degrees for that ADC reading.
  // Note that these are not in compass degree order!  See Weather Meters datasheet for more information.
  
  if (adc < 380) return (112.5);
  if (adc < 393) return (67.5);
  if (adc < 414) return (90);
  if (adc < 456) return (157.5);
  if (adc < 508) return (135);
  if (adc < 551) return (202.5);
  if (adc < 615) return (180);
  if (adc < 680) return (22.5);
  if (adc < 746) return (45);
  if (adc < 801) return (247.5);
  if (adc < 833) return (225);
  if (adc < 878) return (337.5);
  if (adc < 913) return (0);
  if (adc < 940) return (292.5);
  if (adc < 967) return (315);
  if (adc < 990) return (270);
  return (-1); // error, disconnected?
}

/* From Weather Meters docs and the Weather Board V3 schematic:

heading         resistance      volts           nominal         midpoint (<)
112.5	º	0.69	k	1.2	V	372	counts	380
67.5	º	0.89	k	1.26	V	389	counts	393
90	º	1	k	1.29	V	398	counts	414
157.5	º	1.41	k	1.39	V	430	counts	456
135	º	2.2	k	1.56	V	483	counts	508
202.5	º	3.14	k	1.72	V	534	counts	551
180	º	3.9	k	1.84	V	569	counts	615
22.5	º	6.57	k	2.13	V	661	counts	680
45	º	8.2	k	2.26	V	700	counts	746
247.5	º	14.12	k	2.55	V	792	counts	801
225	º	16	k	2.62	V	811	counts	833
337.5	º	21.88	k	2.76	V	855	counts	878
0	º	33	k	2.91	V	902	counts	913
292.5	º	42.12	k	2.98	V	925	counts	940
315	º	64.9	k	3.08	V	956	counts	967
270	º	98.6	k	3.15	V	978	counts	>967
*/

void menu()
// provide the user a way to modify settings, and save those settings to EEPROM to survive reboot / shutdown
{
  boolean done = false;
  char choice;
  long templong;

  // print out a menu of choices, with current settings in (parenthesis)

  Serial.println();
  Serial.print("SparkFun USB Weather Board V3 firmware version ");
  Serial.print(version_major,DEC); Serial.print(".");  Serial.println(version_minor,DEC);
  Serial.print("free RAM: "); Serial.print(freeMemory()); Serial.println(" bytes");
  Serial.println();
  
  while (!done)
  {
    Serial.print("1. Data format (");
    switch (data_format)
    {
      case CSV: Serial.print("CSV"); break;
      case ANSI: Serial.print("ANSI"); break;
      case LCD: Serial.print("LCD"); break;
    }
    Serial.println(")");

    Serial.print("2. General units (");
    switch (general_units)
    {
      case ENGLISH: Serial.print("English"); break;
      case SI: Serial.print("SI"); break;
    }
    Serial.println(")");

    Serial.print("3. Sample rate (");
    Serial.print(sample_rate,DEC);
    Serial.println(")");

    Serial.print("4. Pressure units (");
    switch (pressure_units)
    {
      case MBAR: Serial.print("mbar"); break;
      case INHG: Serial.print("inches Hg"); break;
      case PSI: Serial.print("PSI"); break;
    }
    Serial.println(")");

    Serial.print("5. Pressure type (");
    switch (pressure_type)
    {
      case RELATIVE: Serial.print("relative"); break;
      case ABSOLUTE: Serial.print("absolute"); break;
    }
    Serial.println(")");

    Serial.print("6. Station altitude (");
    Serial.print(altitude,DEC);
    Serial.println(" meters)");

    Serial.print("7. Baud rate (");
    Serial.print(baud_rate,DEC);
    Serial.println(" baud)");

    Serial.println("8. Zero rain counter");

    Serial.print("9. Weather Meters attached (");
    if (weather_meters_attached)
      Serial.println("yes)");
    else
      Serial.println("no)");

    Serial.println("X. Exit (don't save changes to EEPROM)");
    Serial.println("S. Save (save changes to EEPROM)");
    Serial.println();

    // wait for user input from serial port, and act on that input
    // many of these are submenus, some require entering a number
    
    choice = getChar(); // note that this will uppercase the character for you
    switch (choice)
    {
      case '1':
        Serial.println("1. CSV");
        Serial.println("2. ANSI");
        Serial.println("3. LCD");
        Serial.println();
        data_format = getChar() - '0';
        break;

      case '2':
        Serial.println("1. English");
        Serial.println("2. SI (metric)");
        Serial.println();
        general_units = getChar() - '0';
        break;

      case '3':
        Serial.print("Enter sample rate (every x seconds): ");
        templong = getLong();
        if (templong > 4294966ul)
        {
          Serial.println();
          Serial.println();
          Serial.println("SAMPLE RATE TOO LARGE (max = 4294966 seconds)");
          Serial.println();
        }
        else
        {
          sample_rate = templong;
          Serial.println();
          Serial.println();
        }
        break;

      case '4':
        Serial.println("1. mbar");
        Serial.println("2. inches Hg");
        Serial.println("3. PSI");
        Serial.println();
        pressure_units = getChar() - '0';
        break;

      case '5':
        Serial.println("1. absolute");
        Serial.println("2. relative");
        Serial.println();
        pressure_type = getChar() - '0';
        reboot();
        break;

      case '6':
        Serial.print("Enter altitude in integer meters: ");
        altitude = getLong();
        Serial.println();
        Serial.println();
        reboot();
        break;

      case '7':
        Serial.print("Enter baud rate: ");
        templong = getLong();
        Serial.println();
        Serial.println();
        // make SURE value entered is one of the valid baud rates (otherwise it will be impossible to talk to the board!)
        if ((templong == 300) || (templong == 1200) || (templong == 2400) || (templong == 4800) || (templong == 9600) || (templong == 19200) || (templong == 38400) || (templong == 57600) || (templong == 115200))
        {
          baud_rate = templong;
          reboot();
        }
        else
        {
          Serial.println("INVALID BAUD RATE (use 300, 1200, 2400, 4800, 9600, 19200, 38400, 57600, 115200)");
          Serial.println();
        }
        break;

      case '8':
        rain = 0;
        Serial.println("Rain counter zeroed");
        Serial.println();
        break;

      case '9':
        Serial.println("1. yes");
        Serial.println("2. no");
        Serial.println();
        weather_meters_attached = (getChar() == '1');
        break;

      case 'S':
        storeEEPROMsettings();
        // no break here! we want to fall through the 'Q' choice and quit
      case 'X':
        done = true;
        break;
    }
  }
}

char getChar()
// wait for one character to be typed (and convert to uppercase if it's alphabetic)
{
  digitalWrite(STATUSLED,HIGH);
  while (!Serial.available())
    {;} // wait here forever for a character
  digitalWrite(STATUSLED,LOW);
  return(toupper(Serial.read())); // return the upper case character
}

long getLong()
// wait for a number to be input (end with return), allows backspace and negative
{
  char mystring[10];
  char mychar;
  int x = 0;
  boolean done = false;
  
  // input a string of characters from the user
  
  while (!done)
  {
    mychar = getChar();
    if ((mychar == 0x0D) || (mychar == 0x0A)) // carriage return or line feed?
    {
      // terminate the string with 0x00 and exit
      mystring[x] = 0;
      done = true;
    }
    else
    {
      if ((mychar == 0x08) && (x > 0)) // backspace?
      {
        // simulate a backspace - back up, print a space to erase character, and backspace again
        Serial.write(0x08);
        Serial.print(" ");
        Serial.write(0x08);
        x--;
      }
      else // a real character?
      {
//        if ((mychar != 0x08) && (x < 10)) 
        if (x < 10)
        {
          Serial.print(mychar);
          mystring[x] = mychar;
          x++;
        }
      }
    }
  }
  // convert string to long using ASCII-to-long standard function
  return(atol(mystring));
}

void storeEEPROMsettings()
// store all the user-changable settings in EEPROM so it survives power cycles
// note that ints are two bytes, longs are four
{
  eeprom_write_word((uint16_t*)0,data_format);
  eeprom_write_word((uint16_t*)2,general_units);
//  eeprom_write_word((uint16_t*)4,sample_rate); // this space available for an int (changed sample rate to long)
  eeprom_write_word((uint16_t*)6,pressure_units);
  eeprom_write_word((uint16_t*)8,pressure_type);
  eeprom_write_dword((uint32_t*)10,altitude);
  eeprom_write_dword((uint32_t*)14,baud_rate);
  eeprom_write_word((uint16_t*)18,(int)weather_meters_attached);
  eeprom_write_dword((uint32_t*)22,sample_rate);
}

void retrieveEEPROMsettings()
// retrieve settings previously stored in EEPROM
// only load into variables if the settings are valid (-1 == 0xFF == erased)
// note that ints are two bytes, longs are four
{
  int tempint;
  long templong;
  
  // don't initialize variables if EEPROM is unused
  // (uninitialized EEPROM values read back as -1)
  tempint = eeprom_read_word((uint16_t*)0); if (tempint != -1) data_format = tempint;
  tempint = eeprom_read_word((uint16_t*)2); if (tempint != -1) general_units = tempint;
//  tempint = eeprom_read_word((uint16_t*)4); if (tempint != -1) sample_rate = tempint; // this space available for an int (changed sample rate to long)
  tempint = eeprom_read_word((uint16_t*)6); if (tempint != -1) pressure_units = tempint;
  tempint = eeprom_read_word((uint16_t*)8); if (tempint != -1) pressure_type = tempint;
  templong = eeprom_read_dword((uint32_t*)10); if (templong != -1) altitude = templong;
  templong = eeprom_read_dword((uint32_t*)14); if (templong != -1) baud_rate = templong;
  tempint = eeprom_read_word((uint16_t*)18); if (tempint != -1) weather_meters_attached = (boolean)tempint;
  templong = eeprom_read_dword((uint32_t*)22); if (templong != -1) sample_rate = templong;
}

void ansiClear()
// send ANSI clear screen command
// used by ANSI output format
{
  // send ESC [2J
  // which will clear the screen on an ANSI terminal
  Serial.write(27);
  Serial.write(91);
  Serial.write(50);
  Serial.write(74);
}

void ansiHome()
// ANSI terminal command to move the cursor to 0,0 without clearing screen
// used by ANSI output format
{
  // send ESC [H 
  // which puts the cursor in the home 0,0 position on an ANSI terminal
  Serial.write(27);
  Serial.write(91);
  Serial.write(72);
}

void ansiTab()
// send ANSI "tab" character
// used by ANSI output format
{
  // send tab char
  Serial.write(9);
}

void pass()
// space-saver for pass/fail tests in ANSI output format
// used by ANSI output format
{
  Serial.println("    "); // print spaces to erase "FAIL" if necessary
}

void fail()
// space-saver for pass/fail test in ANSI output format
// used by ANSI output format
{
  Serial.println("FAIL");
}

void reboot()
// space-saver for menu reboot message
{
  Serial.println("REBOOT WEATHER BOARD TO PUT NEW SETTINGS INTO EFFECT");
  Serial.println();
}

void LCDclear()
// clear the screen of an SparkFun serial-enabled LCD
// used by LCD output format
{
  LCDline1();
  Serial.write("                ");
  LCDline2();
  Serial.write("                ");
}

void LCDline1()
// move cursor to start of line 1 on a SparkFun serial-enabled LCD
// used by LCD output format
{
  Serial.write(254);
  Serial.write(128);
}

void LCDline2()
// move cursor to start of line 2 on a SparkFun serial-enabled LCD
// used by LCD output format
{
  Serial.write(254);
  Serial.write(192);
}

void error(int errorcode) // save some space by printing out a generic error message
{
  Serial.print("ERROR #"); Serial.print(errorcode,DEC); Serial.println(", see sketch for cause");
}

void printComma() // we do this a lot, it saves two bytes each time we call it
{
  Serial.print(",");
}

