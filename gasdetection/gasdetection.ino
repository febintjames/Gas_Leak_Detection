/*
  Gas leak detector - ESP32 + Firebase push notification

  Gas detected -> LED off, exhaust fan on, servo to 180, push "Gas leak detected!" to every phone
  Gas cleared  -> back to normal, push "Gas cleared"
  The live status is also stored in Firebase at /devices/gas01/state

  WiFi is chosen from your phone, no re-upload needed:
    - If the ESP32 can't join its saved WiFi, it opens the WiFi "GasDetector-Setup" for 3 minutes.
      Connect your phone to it, pick your WiFi, type the password, Save.
    - To switch to a new WiFi at any time: hold the BOOT button for 3 seconds.

  Needs secrets.h (Firebase key) in this folder.
  Libraries: FirebaseClient (Mobizt), ESP32Servo, WiFiManager (tzapu)
  Serial Monitor: 115200 baud. Type t to send a test notification.
*/

#define ENABLE_SERVICE_AUTH
#define ENABLE_MESSAGING
#define ENABLE_DATABASE

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <FirebaseClient.h>
#include <ESP32Servo.h>
#include <WiFiManager.h>
#include "secrets.h"

// Setup WiFi the ESP32 opens when it can't join a saved network
#define SETUP_WIFI_NAME "GasDetector-Setup"
#define SETUP_WIFI_PASSWORD "gas12345"  // at least 8 characters
const int SETUP_BUTTON_PIN = 0;         // BOOT button: hold 3 s to choose a new WiFi

#define DATABASE_URL "https://gas-dectactor-default-rtdb.firebaseio.com"
#define FCM_TOPIC "gas_alert"         // the app subscribes to this topic
#define DEVICE_PATH "/devices/gas01"  // where this detector stores its status

// GPIO 6-11 are used by the flash chip, so the Uno pins 7/8/9 can't be used
const int MQ2_PIN = 34;      // ADC1 pin (ADC2 pins stop working when WiFi is on)
const int RELAY1_PIN = 26;   // LED
const int RELAY2_PIN = 27;   // Exhaust fan
const int SERVO_PIN = 13;

// ESP32 ADC is 12-bit (0-4095). Calibrate: watch the Serial Monitor in clean air
// and set GAS_THRESHOLD well above that value.
const int GAS_THRESHOLD = 400;        // gas detected at or above this
const int GAS_CLEAR_THRESHOLD = 200;  // back to normal only below this

const int RELAY_ON = LOW;
const int RELAY_OFF = HIGH;

const unsigned long READ_INTERVAL_MS = 500;     // read sensor every 500 ms
const unsigned long WARMUP_MS = 60000;          // MQ-2 reads high for the first minute
const unsigned long STATUS_INTERVAL_MS = 60000; // "still alive" update to Firebase

ServiceAuth sa_auth(FIREBASE_CLIENT_EMAIL, FIREBASE_PROJECT_ID, FIREBASE_PRIVATE_KEY, 3000);
FirebaseApp app;
WiFiClientSecure ssl_client;
AsyncClientClass aClient(ssl_client);
Messaging messaging;
RealtimeDatabase Database;

Servo valveServo;
WiFiManager wm;

int gasValue = 0;
bool gasDetected = false;

// Things to send as soon as Firebase is ready (also covers WiFi being down for a while)
bool alertPending = false;
bool clearPending = false;
bool statusPending = true;

bool firebaseStarted = false;
unsigned long lastRead = 0;
unsigned long lastStatusWrite = 0;
unsigned long lastFirebaseTry = 0;
unsigned long lastWifiRetry = 0;
unsigned long buttonDownSince = 0;

// Prints the progress and result of every Firebase task
void printResult(AsyncResult &aResult) {
  if (aResult.isEvent())
    Firebase.printf("[%s] %s\n", aResult.uid().c_str(), aResult.eventLog().message().c_str());

  if (aResult.isError())
    Firebase.printf("[%s] ERROR: %s (code %d)\n", aResult.uid().c_str(),
                    aResult.error().message().c_str(), aResult.error().code());

  if (aResult.available())
    Firebase.printf("[%s] OK\n", aResult.uid().c_str());
}

// Sync the clock (the Firebase key login needs it) and log in
void startFirebase() {
  Serial.print("WiFi OK, IP: ");
  Serial.println(WiFi.localIP());

  configTime(0, 0, "pool.ntp.org", "time.google.com");
  unsigned long start = millis();
  while (time(nullptr) < 1700000000 && millis() - start < 10000) delay(100);
  if (time(nullptr) < 1700000000) {
    Serial.println("Time sync failed, will retry");
    return;
  }

  app.setTime(time(nullptr));
  initializeApp(aClient, app, getAuth(sa_auth), printResult, "auth");
  app.getApp<Messaging>(messaging);
  app.getApp<RealtimeDatabase>(Database);
  Database.url(DATABASE_URL);
  firebaseStarted = true;
}

void sendPush(const String &title, const String &body) {
  Messages::Message msg;
  msg.topic(FCM_TOPIC);

  Messages::Notification notification;
  notification.title(title).body(body);
  msg.notification(notification);

  // High priority + the app's loud "gas_alert" channel
  Messages::AndroidNotification androidNotification;
  androidNotification.channel_id("gas_alert");
  Messages::AndroidConfig androidConfig;
  androidConfig.priority(Messages::AndroidMessagePriority::_HIGH);
  androidConfig.notification(androidNotification);
  msg.android(androidConfig);

  messaging.send(aClient, Messages::Parent(FIREBASE_PROJECT_ID), msg, printResult, "push");
}

void writeStatus() {
  // {".sv":"timestamp"} = Firebase fills in its own current time
  String json = String("{\"gas\":") + (gasDetected ? "true" : "false") +
                ",\"value\":" + gasValue +
                ",\"threshold\":" + GAS_THRESHOLD +
                ",\"updatedAt\":{\".sv\":\"timestamp\"}}";
  Database.set<object_t>(aClient, DEVICE_PATH "/state", object_t(json), printResult, "status");
}

// Adds an entry to the history shown in the app: type is "leak" or "clear"
void logEvent(const char *type) {
  String json = String("{\"type\":\"") + type + "\",\"value\":" + gasValue +
                ",\"at\":{\".sv\":\"timestamp\"}}";
  Database.push<object_t>(aClient, DEVICE_PATH "/events", object_t(json), printResult, "event");
}

void sendPending() {
  if (alertPending) {
    sendPush("Gas leak detected!", "Gas value " + String(gasValue) + ". Fan ON, valve closed.");
    logEvent("leak");
    alertPending = false;
  }
  if (clearPending) {
    sendPush("Gas cleared", "Gas level is back to normal.");
    logEvent("clear");
    clearPending = false;
  }
  if (statusPending || millis() - lastStatusWrite >= STATUS_INTERVAL_MS) {
    writeStatus();
    statusPending = false;
    lastStatusWrite = millis();
  }
}

void readGasSensor() {
  gasValue = analogRead(MQ2_PIN);
  bool warmingUp = millis() < WARMUP_MS;

  // Notify only when the state changes, never on every reading.
  // The gap between the two thresholds stops a value near the limit
  // from flipping the state (and sending pushes) again and again.
  if (!warmingUp && !gasDetected && gasValue >= GAS_THRESHOLD) {
    gasDetected = true;
    alertPending = true;
    statusPending = true;
  } else if (gasDetected && gasValue < GAS_CLEAR_THRESHOLD) {
    gasDetected = false;
    clearPending = true;
    statusPending = true;
  }

  Serial.print("MQ-2 Value: ");
  Serial.print(gasValue);
  Serial.print(" | Gas Status: ");
  Serial.println(warmingUp ? "WARMING UP" : (gasDetected ? "GAS DETECTED!" : "NORMAL"));

  if (gasDetected) {
    // Gas detected: activate safety response
    digitalWrite(RELAY1_PIN, RELAY_OFF);  // LED off
    digitalWrite(RELAY2_PIN, RELAY_ON);   // Exhaust fan on
    valveServo.write(180);
  } else {
    // Normal condition
    digitalWrite(RELAY1_PIN, RELAY_ON);   // LED on
    digitalWrite(RELAY2_PIN, RELAY_OFF);  // Exhaust fan off
    valveServo.write(0);
  }
}

// Hold the BOOT button for 3 s: forget the saved WiFi and open the setup WiFi again
void checkSetupButton() {
  if (digitalRead(SETUP_BUTTON_PIN) == LOW) {
    if (buttonDownSince == 0) buttonDownSince = millis();
    if (millis() - buttonDownSince >= 3000) {
      Serial.println("Forgetting saved WiFi, restarting into setup mode...");
      wm.resetSettings();
      ESP.restart();
    }
  } else {
    buttonDownSince = 0;
  }
}

void handleWiFi() {
  wm.process();  // runs the setup page while it is open
  checkSetupButton();

  // Setup page closed but still offline: keep retrying the saved WiFi,
  // e.g. after a power cut when the router starts slower than the ESP32
  if (!wm.getConfigPortalActive() && WiFi.status() != WL_CONNECTED &&
      millis() - lastWifiRetry >= 30000) {
    lastWifiRetry = millis();
    Serial.println("Retrying saved WiFi...");
    WiFi.begin();
  }
}

void setup() {
  Serial.begin(115200);

  pinMode(SETUP_BUTTON_PIN, INPUT_PULLUP);

  pinMode(MQ2_PIN, INPUT);
  pinMode(RELAY1_PIN, OUTPUT);
  pinMode(RELAY2_PIN, OUTPUT);

  digitalWrite(RELAY1_PIN, RELAY_ON);
  digitalWrite(RELAY2_PIN, RELAY_OFF);

  valveServo.attach(SERVO_PIN);
  valveServo.write(0);

  Serial.println("Gas Leakage Detector Starting...");
  Serial.println("--------------------------------");

  ssl_client.setInsecure();  // demo: skip the HTTPS certificate check

  // Join the saved WiFi. If that fails, open the setup WiFi for 3 minutes.
  // Non-blocking, so the gas detector keeps working while it waits.
  WiFi.mode(WIFI_STA);
  wm.setConfigPortalBlocking(false);
  wm.setConfigPortalTimeout(180);
  wm.setConnectTimeout(15);
  if (wm.autoConnect(SETUP_WIFI_NAME, SETUP_WIFI_PASSWORD)) {
    Serial.println("Joined saved WiFi");
  } else {
    Serial.println("No saved WiFi found: connect your phone to WiFi \"" SETUP_WIFI_NAME
                   "\" (password " SETUP_WIFI_PASSWORD ") to choose one");
  }
}

void loop() {
  if (millis() - lastRead >= READ_INTERVAL_MS) {
    lastRead = millis();
    readGasSensor();
  }

  handleWiFi();

  if (!firebaseStarted) {
    // Log in to Firebase once WiFi is up (retry every 30 s if it fails)
    if (WiFi.status() == WL_CONNECTED &&
        (lastFirebaseTry == 0 || millis() - lastFirebaseTry >= 30000)) {
      lastFirebaseTry = millis();
      startFirebase();
    }
    return;
  }

  app.loop();  // keeps the Firebase login alive and runs the tasks

  if (Serial.available() && Serial.read() == 't') {
    Serial.println("Sending test notification...");
    if (app.ready()) sendPush("Test from gas detector", "Notifications are working.");
    else Serial.println("Firebase is still logging in, try again in a few seconds");
  }

  if (app.ready()) sendPending();
}
