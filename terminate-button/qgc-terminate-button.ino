 #include <MAVLink.h>


#define PIN_RGB1_BLUE           10
#define PIN_RGB1_GREEN          11
#define PIN_RGB1_RED            12
#define PIN_TERMINATE           5

#define SERIAL_BAUD             57600

// connection established between QGC and term. butt.
#define CONFIRMATION_CONNECT    "TER0"
// termination command
#define CONFIRMATION_TERMINATE  "TER1"
// disconnection between qgc and term. butt.
#define CONFIRMATION_DISCONNECT "TER2"

bool terminated                 = false;
bool connection_established     = false;


void RGBLEDConnectionSetColor(unsigned r, unsigned g, unsigned b) {
  digitalWrite(PIN_RGB1_RED, r ? HIGH : LOW);
  digitalWrite(PIN_RGB1_GREEN, g ? HIGH : LOW);
  digitalWrite(PIN_RGB1_BLUE, b ? HIGH : LOW);
}


bool checkStatus(String message) {
  if (Serial.available() > 0) {
    String incomingMessage = Serial.readStringUntil('\n');
    incomingMessage.trim();
    if (incomingMessage == message) {
      return true;
    }
  }

  return false;
}


void setup() {
  pinMode(PIN_TERMINATE,  INPUT_PULLUP);
  pinMode(PIN_RGB1_RED,   OUTPUT);
  pinMode(PIN_RGB1_GREEN, OUTPUT);
  pinMode(PIN_RGB1_BLUE,  OUTPUT);

  RGBLEDConnectionSetColor(0, 0, 0);

  Serial.begin(SERIAL_BAUD);
}


void loop() {
  if (terminated) {
    return;
  }

  // State machine of connection establishment between QGroundControl and terminate button
  if (!connection_established) {
    connection_established = checkStatus(CONFIRMATION_CONNECT);
    if (connection_established) {
      RGBLEDConnectionSetColor(0, 1, 0);
    } else {
      RGBLEDConnectionSetColor(0, 0, 1);
      return;
    }
  }
  // TODO [lpavic]: very big delay when terminate button is pressed
  // occurs because of this code, because of Serial.readStringUntil('\n')
  // see how to handle this problems if needed 
  // 1. LED on hardware terminate button won't be red when virtual
  // terminate button invokes termination
  // 2. when manually disconnecting the hardware terminate button
  // inside Application setting of QGC, LED on hardware terminate
  // button won't indicate that, it would still be green light 
  /*
  else {
    if (checkStatus(CONFIRMATION_DISCONNECT)) {
      connection_established = false;
      return;
    } else if (checkStatus(CONFIRMATION_TERMINATE)) {
      terminated = true;
      RGBLEDConnectionSetColor(1, 0, 0);
      return;
    }
  }
*/
  int terminate_switch = digitalRead(PIN_TERMINATE);

  if (terminate_switch == LOW) {
      Serial.println(CONFIRMATION_TERMINATE);
      terminated = true;
      RGBLEDConnectionSetColor(1, 0, 0);
  }
}
