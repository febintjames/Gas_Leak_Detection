/*
  Gas leak detector + Blynk IoT push notification (ESP32)

  Blynk Console setup (blynk.cloud -> Developer Zone -> My Templates -> your template):
    1. Events & Notifications -> + Create Event
         Event code : gas_leak          (must match the code used in Blynk.logEvent below)
         Type       : Critical
         Notifications tab : Enable notifications, Push -> Device Owner
         Limit Period      : set to the lowest value
         Event Counter     : set to the lowest value (notify on every event)
    2. Datastreams -> Virtual Pin V0, Integer, 0..4095, name "Gas Value" (for a gauge widget)
    3. Save, then copy Template ID / Template Name / Auth Token into the defines below.

  Phone: allow notifications for the Blynk app and turn OFF battery optimization for it,
  otherwise Android can hold the push back for many minutes.
*/

// Must be defined before the Blynk includes
#define BLYNK_TEMPLATE_ID   "TMPLxxxxxxxx"
#define BLYNK_TEMPLATE_NAME "Gas Detector"
#define BLYNK_AUTH_TOKEN    "YourAuthToken"

#define BLYNK_PRINT Serial

#include <WiFi.h>
#include <BlynkSimpleEsp32.h>
#include <ESP32Servo.h>

const char WIFI_SSID[] = "YourWiFiName";
const char WIFI_PASS[] = "YourWiFiPassword";

const int MQ2_PIN = 34;     // ADC1 pin - ADC2 pins stop working when WiFi is on
const int RELAY1_PIN = 26;  // LED
const int RELAY2_PIN = 27;  // Exhaust fan
const int SERVO_PIN = 13;

// ESP32 ADC is 12-bit (0-4095). Calibrate: watch the Serial Monitor in clean air
// and set GAS_THRESHOLD well above that value.
const int GAS_THRESHOLD = 1500;        // gas detected at or above this
const int GAS_CLEAR_THRESHOLD = 1200;  // back to normal only below this

const int RELAY_ON = LOW;
const int RELAY_OFF = HIGH;

Servo valveServo;
BlynkTimer timer;

int gasValue = 0;
bool gasDetected = false;
bool alertPending = false;  // a leak started and the notification is not sent yet

void sendPendingAlert() {
  if (alertPending && Blynk.connected()) {
    Blynk.logEvent("gas_leak", String("Gas leak detected! MQ-2 value: ") + gasValue);
    alertPending = false;
  }
}

void readGasSensor() {
  gasValue = analogRead(MQ2_PIN);

  // Notify only when the state changes from NORMAL to GAS, not on every reading.
  // The gap between the two thresholds stops a value hovering near the limit
  // from flipping the state (and sending events) again and again.
  if (!gasDetected && gasValue >= GAS_THRESHOLD) {
    gasDetected = true;
    alertPending = true;
  } else if (gasDetected && gasValue < GAS_CLEAR_THRESHOLD) {
    gasDetected = false;
  }

  Serial.print("MQ-2 Value: ");
  Serial.print(gasValue);
  Serial.print(" | Gas Status: ");

  if (gasDetected) {
    Serial.println("GAS DETECTED!");

    // Gas detected: activate safety response
    digitalWrite(RELAY1_PIN, RELAY_OFF);
    digitalWrite(RELAY2_PIN, RELAY_ON);
    valveServo.write(180);
  } else {
    Serial.println("NORMAL");

    // Normal condition
    digitalWrite(RELAY1_PIN, RELAY_ON);
    digitalWrite(RELAY2_PIN, RELAY_OFF);
    valveServo.write(0);
  }

  Blynk.virtualWrite(V0, gasValue);
  sendPendingAlert();
}

// A leak that started while offline is sent as soon as Blynk reconnects
BLYNK_CONNECTED() {
  sendPendingAlert();
}

void setup() {
  Serial.begin(115200);

  pinMode(MQ2_PIN, INPUT);
  pinMode(RELAY1_PIN, OUTPUT);
  pinMode(RELAY2_PIN, OUTPUT);

  digitalWrite(RELAY1_PIN, RELAY_ON);
  digitalWrite(RELAY2_PIN, RELAY_OFF);

  valveServo.attach(SERVO_PIN);
  valveServo.write(0);

  Serial.println("Gas Leakage Detector Starting...");
  Serial.println("--------------------------------");

  // Not Blynk.begin(): it blocks until WiFi and Blynk are connected,
  // so the fan/servo/LED would never work while the internet is down.
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  Blynk.config(BLYNK_AUTH_TOKEN);

  // Read sensor every 500 milliseconds without delay(), so Blynk stays connected
  timer.setInterval(500L, readGasSensor);
}

void loop() {
  timer.run();

  if (WiFi.status() == WL_CONNECTED) {
    Blynk.run();
  }
}
