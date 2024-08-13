 #include <MAVLink.h>

#define PIN_RGB1_BLUE         13
#define PIN_RGB1_GREEN        11
#define PIN_RGB1_RED          12
#define PIN_TERMINATE         5
#define PIN_TERMINATE_TEST    2

#define TERMINATION_DURATION  1000 // milliseconds

#define SERIAL_BAUD 57600

#define CONFIRMATION_INPUT_MESSAGE "TERMINATE_BUTTON_CONNECTED_SUCCESSFULLY"
#define CONFIRMATION_OUTPUT_MESSAGE "TERMINATE"

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


bool checkSerialConnection() {
  if (Serial.available() > 0) {
    String incomingMessage = Serial.readStringUntil('\n');
    incomingMessage.trim();
    if (incomingMessage == CONFIRMATION_INPUT_MESSAGE) {
      return true;
    }
  } else {
    return false;
  }

  return false;
}


void setup() {
  pinMode(PIN_TERMINATE, INPUT_PULLUP);
  pinMode(PIN_TERMINATE_TEST, OUTPUT);
  pinMode(PIN_RGB1_RED, OUTPUT);
  pinMode(PIN_RGB1_GREEN, OUTPUT);
  pinMode(PIN_TERMINATE_TEST, OUTPUT);

  Serial.begin(SERIAL_BAUD);
}


void loop() {
  if (terminated) {
    return;
  }

  // Check if variable for connection establishement is true, if not
  // Check if conneciton is established - if yes, light green
  // if connection is not established, blink LED with red
  // else check if that variable still holds right state of the terminate button
  // by reading incoming message
  if (!connection_established) {
    connection_established = checkSerialConnection();
    if (connection_established) {
      RGBLEDConnectionSetColor(0, 1, 0);
    } else {
      if (red_led_flip) {
        RGBLEDConnectionSetColor(1, 1, 0);
        red_led_flip = false;
        //delay(300);
        return;
      } else {
        RGBLEDConnectionSetColor(1, 1, 1);
        red_led_flip = true;
        //delay(300);
        return;
      }
    }
  }
  //else {
    // TODO [lpavic]: check inside _linkDisconnected if TerminationButton is disconnected
    // and read from qgc for closing message, something like "TERMINATION_BUTTON_DISCONNECTED"
    // if (incomingMessage == "TERMINATION_BUTTON_DISCONNECTED") {
    // connection_established = false;
    // }
  //}

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
      Serial.println(CONFIRMATION_OUTPUT_MESSAGE);
      terminated = true;
      RGBLEDConnectionSetColor(1, 0, 0);
    }
  } else {
    switch_was_on = false;
    digitalWrite(PIN_TERMINATE_TEST, LOW);
  }
}
