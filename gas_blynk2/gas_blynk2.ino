// Blynk Credentials
#define BLYNK_TEMPLATE_ID "TMPL3f3v-ntuJ"
#define BLYNK_TEMPLATE_NAME "Gas Leakage Detector"
#define BLYNK_AUTH_TOKEN "kJMPjpCYHwCkWqFw_RtV9Qm578tuZbtr"

#define BLYNK_PRINT Serial

#include <ESP8266_Lib.h>
#include <BlynkSimpleShieldEsp8266.h>
#include <SoftwareSerial.h>
#include <Servo.h>

// Wi-Fi Credentials
char auth[] = BLYNK_AUTH_TOKEN;
char ssid[] = "ROBO-LAB";
char pass[] = "Robo@123";

// Hardware Pin Definitions for Arduino Uno
const int MQ2_PIN    = A0;  // MQ-2 Analog pin
const int RELAY1_PIN = 7;   // Relay 1 Control
const int RELAY2_PIN = 8;   // Relay 2 Control
const int SERVO_PIN  = 9;   // Servo Signal pin

// ESP8266 Wi-Fi module communication pins
SoftwareSerial EspSerial(2, 3); // RX = Pin 2, TX = Pin 3
#define ESP8266_BAUD 9600
ESP8266 wifi(&EspSerial);

const int GAS_THRESHOLD = 100; // Change to 200 if you want a higher threshold

const int RELAY_ON  = LOW;
const int RELAY_OFF = HIGH;

Servo valveServo;
BlynkTimer timer;

int gasValue = 0;
bool gasDetected = false;
bool lastGasState = false;

void readGasSensor() {
  gasValue = analogRead(MQ2_PIN);
  gasDetected = (gasValue >= GAS_THRESHOLD);

  Serial.print("MQ-2 Value: ");
  Serial.print(gasValue);
  Serial.print(" | Gas Status: ");

  // Send live reading to Blynk app (Datastream V0)
  Blynk.virtualWrite(V0, gasValue);

  if (gasDetected) {
    Serial.println("GAS DETECTED!");

    // Safety Response: Close valve, switch relays
    digitalWrite(RELAY1_PIN, RELAY_OFF);
    digitalWrite(RELAY2_PIN, RELAY_ON);
    valveServo.write(180);

    // Update status in Blynk app (Datastream V1)
    Blynk.virtualWrite(V1, "GAS DETECTED!");

    // Send Push Notification & Email on phone when leak starts
    if (!lastGasState) {
      Blynk.logEvent("gas_alert", "WARNING: Gas Leakage Detected! Valve closed.");
      Serial.println(">>> Alert sent to phone and email! <<<");
    }
  } else {
    Serial.println("NORMAL");

    // Normal condition: Reset valve and relays
    digitalWrite(RELAY1_PIN, RELAY_ON);
    digitalWrite(RELAY2_PIN, RELAY_OFF);
    valveServo.write(0);

    // Update status in Blynk app (Datastream V1)
    Blynk.virtualWrite(V1, "NORMAL");
  }

  lastGasState = gasDetected;
}

void setup() {
  Serial.begin(9600);

  pinMode(MQ2_PIN, INPUT);
  pinMode(RELAY1_PIN, OUTPUT);
  pinMode(RELAY2_PIN, OUTPUT);

  // Set initial relay states
  digitalWrite(RELAY1_PIN, RELAY_ON);
  digitalWrite(RELAY2_PIN, RELAY_OFF);

  // Set initial servo position
  valveServo.attach(SERVO_PIN);
  valveServo.write(0);

  // Setup ESP8266 serial communication
  EspSerial.begin(ESP8266_BAUD);
  delay(100);

  Serial.println("\n--- Gas Leakage Detection System ---");

  // Configure your India-region Blynk server cluster (blr1.blynk.cloud:80)
  Blynk.config(wifi, auth, "blr1.blynk.cloud", 80);

  // Connect to Wi-Fi
  Serial.println("Connecting to Wi-Fi...");
  Blynk.connectWiFi(ssid, pass);

  // Connect to Blynk Cloud with internal event loop
  Serial.println("Connecting to Blynk Cloud server...");
  Blynk.connect(15000);

  if (Blynk.connected()) {
    Serial.println(">>> SUCCESS: Device is ONLINE on Blynk Cloud! <<<");
  } else {
    Serial.println(">>> Connecting in background while running sensor loop... <<<");
  }

  // Check gas sensor every 500 milliseconds (non-blocking)
  timer.setInterval(500L, readGasSensor);

  Serial.println("System Ready!\n");
}

void loop() {
  Blynk.run();
  timer.run();
}