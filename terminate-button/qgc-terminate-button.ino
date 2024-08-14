 #include <MAVLink.h>

#define PIN_RGB1_BLUE         13
#define PIN_RGB1_GREEN        11
#define PIN_RGB1_RED          12
#define PIN_TERMINATE         5
#define PIN_TERMINATE_TEST    2

#define TERMINATION_DURATION  1000 // milliseconds

#define SERIAL_BAUD 57600

#define CONFIRMATION_CONNECT    "TERMINATE_BUTTON_CONNECTED"
#define CONFIRMATION_DISCONNECT "TERMINATE_BUTTON_DISCONNECTED"
#define CONFIRMATION_TERMINATE  "TERMINATE"

unsigned long switch_on_time    = 0;
bool switch_was_on              = false;
bool terminated                 = false;
bool red_led_flip               = false;
bool connection_established     = false;


void RGBLEDConnectionSetColor(unsigned r, unsigned g, unsigned b) {
  digitalWrite(PIN_RGB1_RED, r ? HIGH : LOW);
  digitalWrite(PIN_RGB1_GREEN, g ? HIGH : LOW);
  digitalWrite(PIN_RGB1_BLUE, b ? HIGH : LOW);
}


bool checkConnected() {
  if (Serial.available() > 0) {
    String incomingMessage = Serial.readStringUntil('\n');
    incomingMessage.trim();
    if (incomingMessage == CONFIRMATION_CONNECT) {
      return true;
    }
  }

  return false;
}


bool checkDisconnected() {
  if (Serial.available() > 0) {
    String incomingMessage = Serial.readStringUntil('\n');
    incomingMessage.trim();
    if (incomingMessage == CONFIRMATION_DISCONNECT) {
      return true;
    }
  }

  return false;
}


void setup() {
  pinMode(PIN_TERMINATE, INPUT_PULLUP);
  pinMode(PIN_TERMINATE_TEST, OUTPUT);
  pinMode(PIN_RGB1_RED, OUTPUT);
  pinMode(PIN_RGB1_GREEN, OUTPUT);
  pinMode(PIN_TERMINATE_TEST, OUTPUT);

  RGBLEDConnectionSetColor(1,0,0);
  Serial.begin(SERIAL_BAUD);
}


void loop() {
  if (terminated) {
    return;
  }

  // State machine of connection establishment between QGroundControl and terminate button
  if (!connection_established) {
    connection_established = checkConnected();
    if (connection_established) {
      RGBLEDConnectionSetColor(0, 1, 0);
    } else {
      if (red_led_flip) {
        RGBLEDConnectionSetColor(1, 1, 0);
        red_led_flip = false;
        //delay(300);
        return;
      } else {
        RGBLEDConnectionSetColor(1, 0, 0);
        red_led_flip = true;
        //delay(300);
        return;
      }
    }
  }
  else {
    if (checkDisconnected()) {
      connection_established = false;
      return;
    }
  }

  int terminate_switch = digitalRead(PIN_TERMINATE);
  unsigned long current_time = millis();

  digitalWrite(PIN_TERMINATE_TEST, !terminate_switch);  

  if (terminate_switch == LOW) {
    digitalWrite(PIN_TERMINATE_TEST, HIGH);

    if (!switch_was_on) {
      switch_was_on = true;
      switch_on_time = current_time;
    } else if (current_time - switch_on_time >= TERMINATION_DURATION) {
      // Send termination command
      switch_was_on = false;
      Serial.println(CONFIRMATION_TERMINATE);
      terminated = true;
      RGBLEDConnectionSetColor(1, 0, 0);
    }
  } else {
    switch_was_on = false;
    digitalWrite(PIN_TERMINATE_TEST, LOW);
  }
}
