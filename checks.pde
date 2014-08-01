//function for checking soil moisture against threshold
void moistureCheck() {
  static int counter = 1;//init static counter
  static int state = MOISTURE_OK; // tracks which messages have been sent
  int moistAverage = 0; // init soil moisture average
  if((millis() - lastMoistTime) / 1000 > (MOIST_SAMPLE_INTERVAL / MOIST_SAMPLES)) {
    for(int i = MOIST_SAMPLES - 1; i > 0; i--) {
      moistValues[i] = moistValues[i-1]; //move the first measurement to be the second one, and so forth until we reach the end of the array.   
    }
    digitalWrite(PROBEPOWER, HIGH);
    moistValues[0] = analogRead(MOISTPIN);//take a measurement and put it in the first place
    digitalWrite(PROBEPOWER, LOW);
    lastMoistTime = millis();
    int moistTotal = 0;//create a little local int for an average of the moistValues array
    for(int i = 0; i < MOIST_SAMPLES; i++) {//average the measurements (but not the nulls)
      moistTotal += moistValues[i];//in order to make the average we need to add them first 
    }
    if(counter<MOIST_SAMPLES) {
      moistAverage = moistTotal/counter;
      counter++; //this will add to the counter each time we've gone through the function
    }
    else {
      moistAverage = moistTotal/MOIST_SAMPLES;//here we are taking the total of the current light readings and finding the average by dividing by the array size
    } 
    //lastMeasure = millis();
    Serial.print("moisture level: ");
    digitalWrite(PROBEPOWER, HIGH);
    Serial.print(analogRead(MOISTPIN),DEC); 
    digitalWrite(PROBEPOWER, LOW);
    Serial.print(" average: ");
    Serial.println(moistAverage,DEC); 
    postMsg(analogRead(MOISTPIN));

    ///return values
    if ((moistAverage < DRY)  &&  (lastMoistAvg >= DRY)  && state < URGENT_SENT && (millis() > (lastTwitterTime + TWITTER_INTERVAL)) ) {
      Serial.println("URGENT tweet");
      posttweet(URGENT_WATER);   // announce to Twitter
      state = URGENT_SENT; // remember this message
    }
    else if  ((moistAverage < MOIST)  &&  (lastMoistAvg >= MOIST)   && state < WATER_SENT &&  (millis() > (lastTwitterTime + TWITTER_INTERVAL)) ) {
      Serial.println("WATER tweet");
      posttweet(WATER);   // announce to Twitter
      state = WATER_SENT; // remember this message
    }
    else if (moistAverage > MOIST + HYSTERESIS) {
      state = MOISTURE_OK; // reset to messages not yet sent state
    }
    lastMoistAvg = moistAverage; // record this moisture average for comparison the next time this function is called
    moistLight(moistAverage);
  }
}


//function for checking for watering events
void wateringCheck() {
  int moistAverage = 0; // init soil moisture average
  if((millis() - lastWaterTime) / 1000 > WATERED_INTERVAL) {
    digitalWrite(PROBEPOWER, HIGH);
    int waterVal = analogRead(MOISTPIN);//take a moisture measurement
    digitalWrite(PROBEPOWER, LOW);
    lastWaterTime = millis();

    Serial.println("watering detection");
    if (waterVal >= lastWaterVal + WATERING_CRITERIA) { // if we've detected a watering event
      if (waterVal >= SOAKED  &&  lastWaterVal < MOIST &&  (millis() > (lastTwitterTime + TWITTER_INTERVAL))) {
        Serial.println("TY tweet");
        posttweet(THANK_YOU);  // announce to Twitter

      }
      else if  (waterVal >= SOAKED  &&  lastWaterVal >= MOIST  &&  (millis() > (lastTwitterTime + TWITTER_INTERVAL)) ) {
        Serial.println("OW tweet");
        posttweet(OVER_WATERED);   // announce to Twitter

      }
      else if  (waterVal < SOAKED  &&  lastWaterVal < MOIST  &&  (millis() > (lastTwitterTime + TWITTER_INTERVAL)) ) {
        Serial.println("UW tweet");
        posttweet(UNDER_WATERED);   // announce to Twitter

      }
    }    
    lastWaterVal = waterVal; // record the watering reading for comparison next time this function is called
  }
}



// setting the moisture LED
void moistLight (int wetness) {
  if (wetness < DRY) {
    blinkLED(MOISTLED, 6, 50); // blink fast when soil is very dry
    analogWrite(MOISTLED, 8);
  }
  else if (wetness < MOIST) {
    blinkLED(MOISTLED, 2, 500); // blink slowly when watering is needed
    analogWrite(MOISTLED, 24);
  }
  else {
    analogWrite(MOISTLED,wetness/4); // otherwise display a steady LED with brightness mapped to moisture
  }
}


// send tweets when Test switch is pressed
void buttonCheck() { 
  static boolean lastSwitch = HIGH; // variable to hold the last button state
  if (digitalRead(SWITCH) == LOW && lastSwitch == HIGH) {
    delay(1000); // delay to allow device to physically stabilize after button press
    digitalWrite(PROBEPOWER, HIGH);
    long moistLevel = analogRead(MOISTPIN); // take a moisture reading
    digitalWrite(PROBEPOWER, LOW);
    // assemble a string for Twitter
    char *str1 = "Current Moisture: ";
    char *str2;
    str2= (char*) calloc (4,sizeof(char)); // allocate memory to string 2
    int moistPct = (moistLevel*100)/810;  // moisture is on a scale from 0 to 800. 
    moistPct = min(moistPct, 100); // don't allow percentages greater than 100
    itoa(moistPct,str2,10); // store moisture reading in a string variable
    char *str3 = "%";
    char *str4 = " Needs water!";
    char *message;
    message = (char*) calloc(strlen(str1) + strlen(str2) + strlen(str3) + strlen(str4) + 1, sizeof(char)); // allocate memory for the message
    strcat(message, str1); // assemble (concatenate) the strings into a message
    strcat(message, str2);
    strcat(message, str3);
    if (moistLevel < MOIST) { // add alert when soil is dry
      strcat(message, str4);
    }
    posttweet(message);   // announce to Twitter
    free(message); // free the allocated string memory
    free(str2);

    if (digitalRead(SWITCH) == LOW) { // if switch is held down, send a second tweet with the version number
      blinkLED(COMMLED,4,1000);
      char *message;
      char *str1 = "v";
      message = (char*) calloc(strlen(str1) + strlen(VERSION) + 1, sizeof(char));
      strcat(message, str1);
      strcat(message, VERSION);
      Serial.println("TEST tweet");
      posttweet(message);   // announce to Twitter
      free(message); // free the allocated string memory
      // show debugging info
      Serial.println("");
      Serial.print("ip: ");
      Serial.println(ip_to_str(EthernetDHCP.ipAddress()));
      Serial.print("gw: ");
      Serial.println(ip_to_str(EthernetDHCP.gatewayIpAddress()));
      Serial.print("dns: ");
      Serial.println(ip_to_str(EthernetDHCP.dnsIpAddress()));
    }
  }
  lastSwitch = digitalRead(SWITCH); // store the button press state for next time
}
