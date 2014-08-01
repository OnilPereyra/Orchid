// Botanicalls allows plants to ask for human help.
// http://www.botanicalls.com
// program by Rob Faludi (http://faludi.com) with additional code from various public examples
// Botanicalls is a project with Kati London, Rob Faludi and Kate Hartman

#define VERSION "3.01" // use with 2.2 leaf board hardware

// Your Token to Tweet (get it from http://arduino-tweet.appspot.com/)
#define TOKEN "14052394-9gYsPnSXTyw0RFVNKMFU14GwNY9RiJXw6Xt3moTkQ"  
// (the @botanicallstest account token is "14052394-9gYsPnSXTyw0RFVNKMFU14GwNY9RiJXw6Xt3moTkQ")

#if defined(ARDUINO) && ARDUINO > 18
#include <SPI.h> // library to support SPI bus interactions with Wiznet module in Arduino versions 19 and above
#endif

#include <Ethernet.h> // libraries to interact with Wiznet Ethernet
#include <EthernetDHCP.h> // library to automatically request an IP address http://www.arduino.cc/playground/Code/TwitterLibrary#Download
#include <EthernetDNS.h> // library to look up server hostnames http://www.arduino.cc/playground/Code/TwitterLibrary#Download
#include <Twitter.h> // library to interact with Twitter  http://www.arduino.cc/playground/Code/TwitterLibrary
#include <EEPROM.h> // library to store information in firmware
#include <TrueRandom.h> // library for better randomization http://code.google.com/p/tinkerit/wiki/TrueRandom
#include <HTTPClient.h> 

// All messages need to be less than 129 characters
// Arduino RAM is limited. If code fails, try shorter messages
#define URGENT_WATER "URGENT! Water me!"
#define WATER "Water me please."
#define THANK_YOU "Thank you for watering me!"
#define OVER_WATERED "You over watered me."
#define UNDER_WATERED "You didn't water me enough."
#define URI "/linkedsensordata"

//tracks the state to avoid erroneously repeated tweets
#define URGENT_SENT 3
#define WATER_SENT 2
#define MOISTURE_OK 1

#define MOIST 425 // minimum level of satisfactory moisture
#define DRY 300  // maximum level of tolerable dryness
#define HYSTERESIS 25 // stabilization value http://en.wikipedia.org/wiki/Hysteresis
#define SOAKED 575 // minimum desired level after watering
#define WATERING_CRITERIA 115 // minimum change in value that indicates watering

#define MOIST_SAMPLE_INTERVAL 120 // seconds over which to average moisture samples
#define WATERED_INTERVAL 60 // seconds between checks for watering events

#define TWITTER_INTERVAL 1// minimum seconds between twitter postings

#define MOIST_SAMPLES 10 //number of moisture samples to average

int moistValues[MOIST_SAMPLES];

// names for the input and output pins
#define LEDPIN 13 // generic status LED
#define MOISTPIN 0 // moisture input is on analog pin 0
#define PROBEPOWER 8 // feeds power to the moisture probes
#define MOISTLED 9  // LED that indicates the plant needs water
#define COMMLED 4 // LED that indicates communication status
#define SWITCH 3// input for normally open momentary switch

unsigned long lastMoistTime=0; // storage for millis of the most recent moisture reading
unsigned long lastWaterTime=0; // storage for millis of the most recent watering reading
unsigned long lastTwitterTime=0; // storage for millis of the most recent Twitter message

int lastMoistAvg=0; // storage for moisture value
int lastWaterVal=0; // storage for watering detection value

//serial number and counter for tagging posts
unsigned int serial = 0;
unsigned int counter = 0;

// initialize Twitter object
Twitter twitter(TOKEN);

DhcpState ipState = DhcpStateNone; // a variable to store the DHCP state


void setup()  { 
  serial = getSerial(); // create or obtain a serial number from EEPROM memory
  counter = getCounter(); // create or obtain a tweet count from EEPROM memory
  // Ethernet Shield Settings
  byte mac[] = {  
    0x02, 0xBC, 0xA1, 0x15, serial >> 8, serial & 0xFF                         }; // create a private MAC address using serial number
  pinMode(LEDPIN, OUTPUT);
  pinMode(PROBEPOWER, OUTPUT);
  pinMode(MOISTLED, OUTPUT);
  pinMode(COMMLED, OUTPUT);
  pinMode(SWITCH, INPUT);
  digitalWrite(SWITCH, HIGH); // turn on internal pull up resistors
  // initialize moisture value array
  for(int i = 0; i < MOIST_SAMPLES; i++) { 
    moistValues[i] = 0; 
  }
  digitalWrite(PROBEPOWER, HIGH);
  lastWaterVal = analogRead(MOISTPIN);//take a moisture measurement to initialize watering value
  digitalWrite(PROBEPOWER, LOW);

  Serial.begin(9600);   // set the data rate for the hardware serial port
  Serial.println("");   // begin printing to debug output
  Serial.print("Botanicalls v");
  Serial.println(VERSION);
  Serial.print("mac: ");
  for (int i=0; i< 6; i++) {
    Serial.print(mac[i],HEX);
    if(i<5) Serial.print(":");
  }
  Serial.println("");
  Serial.print("token: ");
  Serial.println(TOKEN);
  Serial.print("serial: ");
  Serial.println(serial,HEX);
  Serial.print("ctr: ");
  Serial.println(counter,DEC);

  // start Ethernet, resolve server IP (TODO, not now.)
  //byte servIP[4];
  
  EthernetDHCP.begin(mac, true); // start ethernet DHCP in non-blocking polling mode
  // DNSError err = EthernetDNS.resolveHostName(CLIENTHOST, servIP);
  
    // blink the comm light with the version number
  blinkLED(COMMLED,3,200); // version 3
  delay(200);
  blinkLED(COMMLED,0,200); // point 0
  delay(200);
  blinkLED(COMMLED,1,200); // point 0
  analogWrite(MOISTLED, 36); // turn on the moisture LED
}


void loop()       // main loop of the program     
{
  moistureCheck(); // check to see if moisture levels require Twittering out
  wateringCheck(); // check to see if a watering event has occurred to report it
  buttonCheck(); // check to see if the debugging button is pressed
  analogWrite(COMMLED,0); // douse comm light if it was on
  dhcpCheck(); // check and update DHCP connection
  if (millis() % 60000 == 0 && ipState != DhcpStateLeased && ipState != DhcpStateRenewing) {
    blinkLED(COMMLED,1,30); // quick blnk of COMM led if there's no ip address
  }
}
