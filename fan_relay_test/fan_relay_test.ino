#if defined(ESP32)
#include <ESP32Servo.h>

// ESP32: GPIO 6-11 are used by the flash chip, so the Uno pins 7/8/9 can't be used
const int MQ2_PIN = 34;      // ADC1 pin (ADC2 pins stop working when WiFi is on)
const int RELAY1_PIN = 26;   // LED
const int RELAY2_PIN = 27;   // Exhaust fan
const int SERVO_PIN = 13;

// ESP32 ADC is 12-bit (0-4095): calibrate in clean air using the Serial Monitor
const int GAS_THRESHOLD = 400;
#else
#include <Servo.h>

const int MQ2_PIN = A0;
const int RELAY1_PIN = 7;    // LED
const int RELAY2_PIN = 8;    // Exhaust fan
const int SERVO_PIN = 9;

const int GAS_THRESHOLD = 100;
#endif

// Most relay modules switch ON when IN is LOW.
// If the fan runs when it should be OFF, swap LOW and HIGH here.
const int RELAY_ON = LOW;
const int RELAY_OFF = HIGH;

void setFan(bool on) {
  digitalWrite(RELAY2_PIN, on ? RELAY_ON : RELAY_OFF);
  Serial.print("Exhaust fan: ");
  Serial.println(on ? "ON" : "OFF");
}

void setup() {
  Serial.begin(115200);

  pinMode(RELAY2_PIN, OUTPUT);
  setFan(false);
  delay(1000);

  // Auto test: listen for the relay click and watch the fan
  Serial.println("Fan relay test: ON 3 s / OFF 3 s, 3 times");
  for (int i = 0; i < 3; i++) {
    setFan(true);
    delay(3000);
    setFan(false);
    delay(3000);
  }

  Serial.println("Test done. Type 1 = fan ON, 0 = fan OFF");
}

void loop() {
  if (Serial.available()) {
    char c = Serial.read();
    if (c == '1') setFan(true);
    if (c == '0') setFan(false);
  }
}
