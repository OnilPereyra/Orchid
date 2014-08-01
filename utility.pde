// post a tweet
void posttweet(char* msg) {
  digitalWrite(COMMLED,HIGH); // light the Communications LED
  // assemble a string for Twitter, appending a unique ID to prevent Twitter's repeat detection
  char *str1 = " [";
  char *str2;
  str2= (char*) calloc (5,sizeof(char)); // allocate memory to string 2
  itoa(serial,str2,16); // turn serial number into a string
  char *str3 = "-";
  char *str4;
  str4= (char*) calloc (5,sizeof(char)); // allocate memory to string 4
  itoa(counter%10000,str4,10); // turn message counter into a string
  char *str5 = "]";
  char *message;
  // allocate memory for the message
  message = (char*) calloc(strlen(msg) + strlen(str1) + strlen(str2) + strlen(str3) + strlen(str4) + strlen(str5) + 1, sizeof(char));
  strcat(message, msg); // assemble (concatenate) the strings into a message
  strcat(message, str1);
  strcat(message, str2);   
  strcat(message, str3);
  strcat(message, str4);
  strcat(message, str5);
  Serial.println("connect...");
  if (ipState == DhcpStateLeased || ipState == DhcpStateRenewing) {
    if (twitter.post(message)) { // attempt to tweet the message
      int status = twitter.wait(); // receive the status
      digitalWrite(COMMLED,LOW); // turn off the communications LED
      delay(100);
      if (status == 200) {
        Serial.println("tweet ok");
      } 
      else {
        Serial.print("tweet fail: code ");
        Serial.println(status); // if tweet fails, print the error code
        blinkLED(COMMLED,2,100); // ...and blink the communications LED twice
      }
      counter++; // iterate the message counter
      setCounter(counter); // store the message counter in EEPROM memory
    } 
    else {
      Serial.println("connect fail"); // if connection fails entirely,
      blinkLED(COMMLED,4,100); // ...blink the communications LED 4 times
    } 
  }
  else {
    Serial.println("DHCP fail"); // if connection fails entirely,
    blinkLED(COMMLED,6,100); // ...blink the communications LED 4 times
  }
  free(message); // free the allocated string memory
  free(str2);
  free(str4);
}

// retrieve the randomized unit serial number information from EEPROM
unsigned int getSerial() {
  unsigned int ser ;
  if (EEPROM.read(2) != 1) {
    Serial.println("init ser");
    ser = TrueRandom.random(1,0xFFFE);
    EEPROM.write(0,ser >> 8);
    EEPROM.write(1,ser & 0xFF);
    EEPROM.write(2,1);
  }
  ser = (EEPROM.read(0) << 8) + (EEPROM.read(1));
  return ser;
}

// retrieve the message counter information from EEPROM
unsigned int getCounter() {
  unsigned int ctr;
  //initial setting of counter
  if (EEPROM.read(5) != 1) { // if counter set status is false
    Serial.println("init ctr");
    EEPROM.write(3,0); // write LEB zero
    EEPROM.write(4,0); // write MSB zero
    EEPROM.write(5,1); // counter set status is true
  }
  //get counter reading
  ctr = (EEPROM.read(3) << 8) + (EEPROM.read(4)); // add MSB + LSB for 16-bit counter
  return ctr;
}

// write the message counter information to EEPROM
void setCounter(unsigned int ctr) {
  EEPROM.write(3,ctr >> 8); // write the MSB
  EEPROM.write(4,ctr & 0xFF); // write the LSB
}

// a utility function to nicely format an IP address.
const char* ip_to_str(const uint8_t* ipAddr)
{
  static char buf[16];
  sprintf(buf, "%d.%d.%d.%d\0", ipAddr[0], ipAddr[1], ipAddr[2], ipAddr[3]);
  return buf;
}


// check and attempt to create a DHCP leased IP address
void dhcpCheck() {
  DhcpState prevState = ipState; // record the current state
  ipState = EthernetDHCP.poll(); // poll for an updated state
  if (prevState != ipState) { // if this is a new state then report it
    switch (ipState) {
    case DhcpStateDiscovering:
      Serial.println("DHCP disc");
      break;
    case DhcpStateRequesting:
      Serial.println("DHCP req");
      break;
    case DhcpStateRenewing:
      Serial.println("DHCP renew");
      break;
    case DhcpStateLeased: 
      {
        Serial.println("DHCP OK!");
        // We have a new DHCP lease, so print the info
        const byte* ipAddr = EthernetDHCP.ipAddress();
        const byte* gatewayAddr = EthernetDHCP.gatewayIpAddress();
        const byte* dnsAddr = EthernetDHCP.dnsIpAddress();
        Serial.print("ip: ");
        Serial.println(ip_to_str(ipAddr));
        Serial.print("gw: ");
        Serial.println(ip_to_str(gatewayAddr));
        Serial.print("dns: ");
        Serial.println(ip_to_str(dnsAddr));
        break;
      }
    }
  }
} 


// this function blinks the an LED light as many times as requested
void blinkLED(byte targetPin, int numBlinks, int blinkRate) {
  for (int i=0; i<numBlinks; i++) {
    digitalWrite(targetPin, HIGH);   // sets the LED on
    delay(blinkRate);                     // waits for a blinkRate milliseconds
    digitalWrite(targetPin, LOW);    // sets the LED off
    delay(blinkRate);
  }
}

void postMsg(int senseVal){

  char charVal[4];
  itoa(senseVal,charVal,10);
  
  /* Working on some type conversion
  char req[40];
  char req1[] = "{ \"value\": ";
  char req2[] = " }";
  char *concatena(char *req1, char *charVal, char *req2) {
    strcat(req, req1);
    strcat(req, charVal);
    strcat(req, req2);
    return req;
  } 
  */
  
  Serial.println("posting message");
  // start the Client connection

  byte servip[] = { 81, 162, 68, 150 };
  
  // Dummy payload
  char req[] = "{ \"value\": 0}"; 

  HTTPClient client("81.162.68.150",servip,5984);
  client.debug(-1);
  http_client_parameter json_header[] = {
      { 
        "Content-Type","application/json"      }
      ,{
        NULL,NULL      }
    };
  
  FILE* result = client.postURI(URI,NULL,req,json_header);
  int returnCode = client.getLastReturnCode();
  if (result!=NULL) {
    client.closeStream(result);
  } 
  else {
    Serial.println("failed to connect");
  }
  if (returnCode==200 || returnCode==201) {
    Serial.println("data uploaded");
  } 
  else {
    Serial.print("ERROR: Server returned ");
    Serial.println(returnCode);
  }
}
