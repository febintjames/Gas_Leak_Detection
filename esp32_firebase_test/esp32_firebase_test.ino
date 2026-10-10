/*
  Step 3 test: ESP32 -> Firebase (no sensor yet)

  Fill in secrets.h first. Serial Monitor at 115200 baud, then type:
    p = send a test push notification to every phone with the app (topic "gas_alert")
    w = write a test gas status to the Realtime Database

  Library: FirebaseClient by Mobizt (Library Manager)
*/

#define ENABLE_SERVICE_AUTH
#define ENABLE_MESSAGING
#define ENABLE_DATABASE

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <FirebaseClient.h>
#include "secrets.h"

#define DATABASE_URL "https://gas-dectactor-default-rtdb.firebaseio.com"
#define FCM_TOPIC "gas_alert"         // the app subscribes to this topic
#define DEVICE_PATH "/devices/gas01"  // where this detector stores its status

ServiceAuth sa_auth(FIREBASE_CLIENT_EMAIL, FIREBASE_PROJECT_ID, FIREBASE_PRIVATE_KEY, 3000);
FirebaseApp app;
WiFiClientSecure ssl_client;
AsyncClientClass aClient(ssl_client);
Messaging messaging;
RealtimeDatabase Database;

// Prints the progress and result of every Firebase task
void printResult(AsyncResult &aResult) {
  if (aResult.isEvent())
    Firebase.printf("[%s] %s\n", aResult.uid().c_str(), aResult.eventLog().message().c_str());

  if (aResult.isError())
    Firebase.printf("[%s] ERROR: %s (code %d)\n", aResult.uid().c_str(),
                    aResult.error().message().c_str(), aResult.error().code());

  if (aResult.available())
    Firebase.printf("[%s] OK: %s\n", aResult.uid().c_str(), aResult.c_str());
}

// The service account login needs the correct time
void syncTime() {
  Serial.print("Getting time from internet");
  configTime(0, 0, "pool.ntp.org", "time.google.com");
  while (time(nullptr) < 1700000000) {
    Serial.print(".");
    delay(300);
  }
  Serial.println(" OK");
  app.setTime(time(nullptr));
}

void sendTestPush() {
  Messages::Message msg;
  msg.topic(FCM_TOPIC);

  Messages::Notification notification;
  notification.title("Gas leak detected!").body("Test message from ESP32");
  msg.notification(notification);

  // High priority + the app's loud "gas_alert" channel
  Messages::AndroidNotification androidNotification;
  androidNotification.channel_id("gas_alert");
  Messages::AndroidConfig androidConfig;
  androidConfig.priority(Messages::AndroidMessagePriority::_HIGH);
  androidConfig.notification(androidNotification);
  msg.android(androidConfig);

  Serial.println("Sending test push...");
  messaging.send(aClient, Messages::Parent(FIREBASE_PROJECT_ID), msg, printResult, "push");
}

void writeTestStatus() {
  // {".sv":"timestamp"} = Firebase fills in its own current time
  String json = "{\"gas\":true,\"value\":999,\"updatedAt\":{\".sv\":\"timestamp\"}}";

  Serial.println("Writing test status to database...");
  Database.set<object_t>(aClient, DEVICE_PATH "/state", object_t(json), printResult, "dbWrite");
}

void setup() {
  Serial.begin(115200);

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    Serial.print(".");
    delay(300);
  }
  Serial.print("\nWiFi OK, IP: ");
  Serial.println(WiFi.localIP());

  ssl_client.setInsecure();  // demo: skip the HTTPS certificate check
  syncTime();

  initializeApp(aClient, app, getAuth(sa_auth), printResult, "auth");
  app.getApp<Messaging>(messaging);
  app.getApp<RealtimeDatabase>(Database);
  Database.url(DATABASE_URL);

  Serial.println("Type p = test push, w = test database write");
}

void loop() {
  app.loop();  // keeps the Firebase login alive and runs the tasks

  if (Serial.available()) {
    char c = Serial.read();
    if (c != 'p' && c != 'w') return;

    if (!app.ready()) {
      Serial.println("Firebase is still logging in, try again in a few seconds");
      return;
    }
    if (c == 'p') sendTestPush();
    if (c == 'w') writeTestStatus();
  }
}
