#include <Arduino.h>
#include <IRremoteESP8266.h>
#include <IRsend.h>
#include <ArduinoJson.h>
#include <EEPROM.h>
#include <ESP8266WiFi.h>
#include <WebSocketsClient.h>
#include <Esp.h>

// ========== HARDWARE SETTINGS ==========
#define SEND_PIN D2         // IR LED control pin
#define EEPROM_SIZE 16      // EEPROM storage size

// ========== SYSTEM SETTINGS ==========
#define DEBUG_MEMORY_INTERVAL 60000  // Memory status output interval (1 minute)
#define WATCHDOG_TIMEOUT 15000       // Watchdog timeout (15 seconds)
#define JSON_BUFFER_SIZE 512         // JSON parsing buffer size
#define MIN_HEAP_SIZE 4000           // Minimum heap memory warning threshold

// ========== DATA STRUCTURE ==========
struct MyData {
  uint8_t powerOn;          // Power state (0=off, 1=on)
  uint8_t r;                // Red value (0-255)
  uint8_t g;                // Green value (0-255)
  uint8_t b;                // Blue value (0-255)
};

// ========== IR REMOTE CODES ==========
// Basic control codes
uint32_t ir_enterDiy = 0xFF30CF;     // Enter DIY mode
uint32_t ir_power    = 0xFF02FD;     // Power ON/OFF
// Color adjustment codes
uint32_t ir_rup      = 0xFF28D7;     // Red increase
uint32_t ir_rdown    = 0xFF08F7;     // Red decrease
uint32_t ir_gup      = 0xFFA857;     // Green increase
uint32_t ir_gdown    = 0xFF8877;     // Green decrease
uint32_t ir_bup      = 0xFF6897;     // Blue increase
uint32_t ir_bdown    = 0xFF48B7;     // Blue decrease
uint32_t ir_dynamic  = 0;            // Dynamic IR code

// Mode control codes
uint32_t ir_auto     = 0xFFC837;     // Auto mode
uint32_t ir_slow     = 0xFFC837;     // Slow transition (same as AUTO)
uint32_t ir_quick    = 0xFFF00F;     // Quick transition
uint32_t ir_flash    = 0xFFD02F;     // Flash mode
uint32_t ir_fade7    = 0xFFE01F;     // 7-color fade
uint32_t ir_fade3    = 0xFF609F;     // 3-color fade
uint32_t ir_jump7    = 0xFFA05F;     // 7-color jump
uint32_t ir_jump3    = 0xFF20DF;     // 3-color jump
// Music response modes
uint32_t ir_music1   = 0xFF12ED;     // Music mode 1
uint32_t ir_music2   = 0xFF32CD;     // Music mode 2
uint32_t ir_music3   = 0xFFF807;     // Music mode 3
uint32_t ir_music4   = 0xFFD827;     // Music mode 4

// ========== NETWORK SETTINGS ==========
const char* ssid = "Denison-Play";   // WiFi SSID
const char* password = "";           // WiFi password (public network)
const char* wsHost = "40jv468tgk.execute-api.us-east-1.amazonaws.com"; // WebSocket server
const int wsPort = 443;              // WebSocket port (SSL)
const char* wsPath = "/develop";     // WebSocket path
const char* uuid = "testuser2";      // Device identifier
const char* mac = "C4:D8:D5:03:75:8E"; // MAC address

// ========== TIMER SETTINGS ==========
const int wifi_timeout = 30000;                  // WiFi connection attempt time (30 seconds)
const unsigned long WIFI_CHECK_INTERVAL = 60000; // WiFi status check interval (1 minute)
const unsigned long WS_RECONNECT_INTERVAL = 10000; // WebSocket reconnection interval (10 seconds)
const unsigned long STATE_REPORT_INTERVAL = 30000; // Status reporting interval (30 seconds)

// ========== SYSTEM STATUS VARIABLES ==========
unsigned long lastMemoryReport = 0;     // Last memory report time
unsigned long lastWifiCheck = 0;        // Last WiFi check time
unsigned long lastWebSocketReconnect = 0; // Last WebSocket reconnection time
unsigned long lastActivityTime = 0;     // Last activity time
unsigned long lastStateReport = 0;      // Last status report time
unsigned int reconnectAttempts = 0;     // Reconnection attempt count

// ========== OBJECT INITIALIZATION ==========
IRsend irsend(SEND_PIN);               // IR transmission object
WebSocketsClient webSocket;            // WebSocket client
MyData currentData;                    // Currently stored data

// ========== STATUS VARIABLES ==========
bool webSocketConnected = false;       // WebSocket connection status
bool powerOn = false;                  // Power status
bool eepromNeedsSave = false;          // EEPROM save required flag
int rgb[3] = {0, 0, 0};                // Current RGB values
bool processingMessage = false;        // Message processing status
// Remove dynamicModeActive variable as it's not needed

// ========== DIAGNOSTIC INFORMATION ==========
int lastWSError = 0;                   // Last WebSocket error code
String lastWSErrorMessage = "";        // Last WebSocket error message
bool receivedInitialResponse = false;  // Initial response received flag

// ========== FUNCTION DECLARATIONS ==========
void setupWiFi();                      // WiFi setup and connection
void setupWebSocket();                 // WebSocket setup
void handleWebSocketEvent(WStype_t type, uint8_t * payload, size_t length); // WebSocket event handler
void sendDeviceState();                // Send device state
void processJsonMessage(const JsonDocument& doc); // Process JSON message
String getWiFiStatusString(int status); // Get WiFi status string
void loadFromEEPROM();                 // Load data from EEPROM
void saveToEEPROM();                   // Save data to EEPROM
void markActivity();                   // Record activity
void handleSerialJson();               // Handle serial JSON commands
void adjustRGB(int targetR, int targetG, int targetB); // Adjust RGB values
bool sendIRCode(uint32_t code, bool withDelay = false); // Send IR code
void sendUpDownSequence(uint32_t updownCode, int count); // Send sequential IR codes
void reportCurrentState();             // Report current state
bool parseAndProcessJson(uint8_t * payload, size_t length); // Parse and process JSON
void checkHeapMemory();                // Check memory status

// ========== INITIAL SETUP ==========
void setup() {
  Serial.begin(115200);
  delay(500);

  // Watchdog timer setup
  ESP.wdtDisable();
  ESP.wdtEnable(WATCHDOG_TIMEOUT);

  // EEPROM initialization and data load
  EEPROM.begin(EEPROM_SIZE);
  loadFromEEPROM();

  // IR transmission initialization
  irsend.begin();

  Serial.println(F("=== IoT IR Controller Initialization ==="));
  Serial.printf("[Initialization] State: %s, RGB=[%d, %d, %d]\n", 
               powerOn ? "On" : "Off", rgb[0], rgb[1], rgb[2]);

  // WiFi connection setup
  setupWiFi();
}

// ========== MAIN LOOP ==========
void loop() {
  unsigned long currentMillis = millis();
  
  // Watchdog feeding
  ESP.wdtFeed();
  
  // WiFi connection status check and management (interval increased)
  if (currentMillis - lastWifiCheck > WIFI_CHECK_INTERVAL) {
    lastWifiCheck = currentMillis;
    
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("[WiFi] Reconnecting");
      setupWiFi();
    }
    
    // Memory check (executed with WiFi check to save timer)
    checkHeapMemory();
  }

  // WebSocket processing (simplified)
  if (WiFi.status() == WL_CONNECTED) {
    webSocket.loop();
    
    // Reconnect if disconnected
    if (!webSocketConnected && (currentMillis - lastWebSocketReconnect > WS_RECONNECT_INTERVAL)) {
      lastWebSocketReconnect = currentMillis;
      webSocket.disconnect();
      delay(200);
      setupWebSocket();
    }
  }

  // Periodic status reporting (interval increased and conditional execution)
  if (currentMillis - lastStateReport > STATE_REPORT_INTERVAL) {
    lastStateReport = currentMillis;
    // Report status only when connected
    if (webSocketConnected) {
      reportCurrentState();
    }
  }

  // Handle serial commands
  handleSerialJson();

  // Handle EEPROM save if needed
  if (eepromNeedsSave && (currentMillis - lastActivityTime > 1000)) {
    saveToEEPROM();
  }
}

//------------------------------------------------------------------------------
// WiFi setup and connection
//------------------------------------------------------------------------------
void setupWiFi() {
  WiFi.disconnect(true);
  delay(300);
  WiFi.persistent(false);
  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);

  WiFi.begin(ssid, password);
  
  unsigned long startTime = millis();
  bool connected = false;
  
  while (millis() - startTime < wifi_timeout) {
    if (WiFi.status() == WL_CONNECTED) {
      connected = true;
      break;
    }
    delay(500);
  }
  
  if (connected) {
    Serial.printf("[WiFi] Connected: %s\n", WiFi.localIP().toString().c_str());
    setupWebSocket();
  }
}

//------------------------------------------------------------------------------
// WebSocket setup
//------------------------------------------------------------------------------
void setupWebSocket() {
  String wsFullPath = String(wsPath);
  if (!wsFullPath.startsWith("/")) {
    wsFullPath = "/" + wsFullPath;
  }
  wsFullPath += "?uuid=" + String(uuid);
  
  webSocket.beginSSL(wsHost, wsPort, wsFullPath.c_str());
  webSocket.onEvent(handleWebSocketEvent);
  webSocket.setReconnectInterval(WS_RECONNECT_INTERVAL);
  
  lastWebSocketReconnect = millis();
}

//------------------------------------------------------------------------------
// WebSocket event handler
//------------------------------------------------------------------------------
void handleWebSocketEvent(WStype_t type, uint8_t * payload, size_t length) {
  ESP.wdtFeed();
  
  switch (type) {
    case WStype_DISCONNECTED:
      webSocketConnected = false;
      break;
      
    case WStype_CONNECTED:
      webSocketConnected = true;
      reconnectAttempts = 0;
      sendDeviceState();
      break;
    
    case WStype_TEXT:
      // Skip if already processing
      if (processingMessage) return;
      
      processingMessage = true;
      
      // Length check for safety
      if (length > 0 && length < 1500) {
        parseAndProcessJson(payload, length);
      }
      
      processingMessage = false;
      break;
    
    case WStype_ERROR:
      webSocketConnected = false;
      break;
    
    default:
      break;
  }
}

//------------------------------------------------------------------------------
// Send current device state
//------------------------------------------------------------------------------
void sendDeviceState() {
  if (!webSocketConnected) return;
  
  StaticJsonDocument<192> doc;
  
  doc["action"] = "sendmessage";
  doc["state"] = powerOn ? "on" : "off";
  doc["uuid"] = uuid;
  
  JsonArray rgbArr = doc.createNestedArray("rgb");
  rgbArr.add(rgb[0]);
  rgbArr.add(rgb[1]);
  rgbArr.add(rgb[2]);
  
  // Remove dynamicMode field from the state report
  
  String jsonString;
  serializeJson(doc, jsonString);
  webSocket.sendTXT(jsonString);
}

//------------------------------------------------------------------------------
// Parse and process JSON
//------------------------------------------------------------------------------
bool parseAndProcessJson(uint8_t * payload, size_t length) {
  // Debug - Print raw received payload
  Serial.println(F("[Received] Raw message:"));
  Serial.write(payload, length);
  Serial.println();
  
  DynamicJsonDocument doc(JSON_BUFFER_SIZE);
  DeserializationError error = deserializeJson(doc, payload, length);
  
  if (error) {
    Serial.printf("[JSON] Parsing error: %s\n", error.c_str());
    return false;
  }
  
  // Debug - Print parsed JSON for debugging
  Serial.println(F("[Received] Parsed JSON:"));
  serializeJson(doc, Serial);
  Serial.println();
  
  // Filter out system messages like "Unsupported route: $default"
  if (doc.containsKey("message")) {
    JsonVariant message = doc["message"];
    
    // Check if message is a system error message
    if (message.is<const char*>()) {
      const char* msgStr = message.as<const char*>();
      if (msgStr && strstr(msgStr, "Unsupported route") != NULL) {
        Serial.println(F("[System] Ignoring API Gateway system message"));
        return true; // Return true but don't process the message further
      }
    }
    
    // If message is a string (text format JSON)
    if (message.is<const char*>()) {
      const char* msgStr = message.as<const char*>();
      if (msgStr && strlen(msgStr) > 0) {
        Serial.println(F("[Received] Processing message string"));
        
        // Try to parse the message string as JSON
        doc.clear();
        error = deserializeJson(doc, msgStr);
        if (!error) {
          processJsonMessage(doc);
          return true;
        }
      }
    }
    // If message is already a JSON object
    else if (message.is<JsonObject>()) {
      Serial.println(F("[Received] Processing message object"));
      JsonObject msgObj = message.as<JsonObject>();
      
      // Extract and process the message object directly
      DynamicJsonDocument msgDoc(JSON_BUFFER_SIZE);
      for (JsonPair kv : msgObj) {
        msgDoc[kv.key()] = kv.value();
      }
      
      processJsonMessage(msgDoc);
      return true;
    }
  }
  
  // If none of the above matched, just try to process the original document
  Serial.println(F("[Received] Processing direct command"));
  processJsonMessage(doc);
  return true;
}

//------------------------------------------------------------------------------
// Process JSON message
//------------------------------------------------------------------------------
void processJsonMessage(const JsonDocument& doc) {
  // Check for dynamic IR code first
  if (doc.containsKey("dynamicIr")) {
    const char* dynamicValue = doc["dynamicIr"];
    
    // Only process if dynamicIr has a non-empty value
    if (dynamicValue && strlen(dynamicValue) > 0) {
      // Convert hex string to uint32_t properly
      // Ensure proper format by adding 0x prefix if not present
      char hexBuffer[16] = {0};
      if (strncmp(dynamicValue, "0x", 2) != 0 && strncmp(dynamicValue, "0X", 2) != 0) {
        snprintf(hexBuffer, sizeof(hexBuffer), "0x%s", dynamicValue);
        ir_dynamic = strtoul(hexBuffer, NULL, 0);
      } else {
        ir_dynamic = strtoul(dynamicValue, NULL, 0);
      }
      
      // If device is OFF, turn it ON first
      if (!powerOn) {
        Serial.println("[Dynamic Mode] Device is OFF, turning ON first");
        sendIRCode(ir_power, true);
        powerOn = true;
        markActivity();
        delay(150); // Wait for device to initialize
      }
      
      // Debug output with proper hex formatting
      Serial.printf("[Dynamic Mode] Received IR code: %s (0x%08X)\n", dynamicValue, ir_dynamic);
      
      // Send the IR code with more robust approach
      bool success = sendIRCode(ir_dynamic, true);
      Serial.printf("[Dynamic Mode] Sent IR code: 0x%08X (Success: %s)\n", 
                    ir_dynamic, success ? "Yes" : "No");
      
      // Exit early - don't process any other controls when in dynamic mode
      return;
    }
    // If dynamicIr is present but empty, continue with normal processing
  }
  
  // Normal processing for all other cases (when no valid dynamicIr is present)
  
  // Update IR codes in memory - handle null values properly
  const char* irCommands[] = {
    "enterDiy", "power", "rup", "rdown", "gup", "gdown", "bup", "bdown",
    "auto", "slow", "quick", "flash", "fade7", "fade3", "jump7", "jump3", 
    "music1", "music2", "music3", "music4"
  };
  uint32_t* irCodes[] = {
    &ir_enterDiy, &ir_power, &ir_rup, &ir_rdown, &ir_gup, &ir_gdown, &ir_bup, &ir_bdown,
    &ir_auto, &ir_slow, &ir_quick, &ir_flash, &ir_fade7, &ir_fade3, &ir_jump7, &ir_jump3, 
    &ir_music1, &ir_music2, &ir_music3, &ir_music4
  };
  
  // Process IR code updates from JSON - with improved null handling
  for (int i = 0; i < sizeof(irCommands)/sizeof(irCommands[0]); i++) {
    if (doc.containsKey(irCommands[i])) {
      // Check for null value
      if (doc[irCommands[i]].isNull()) {
        Serial.printf("[IR] Skipping null value for %s\n", irCommands[i]);
        continue;
      }
      
      const char* irValue = doc[irCommands[i]];
      if (irValue && strlen(irValue) > 0) {
        // Convert hex string to uint32_t properly
        char hexBuffer[16] = {0};
        if (strncmp(irValue, "0x", 2) != 0 && strncmp(irValue, "0X", 2) != 0) {
          snprintf(hexBuffer, sizeof(hexBuffer), "0x%s", irValue);
          *irCodes[i] = strtoul(hexBuffer, NULL, 0);
        } else {
          *irCodes[i] = strtoul(irValue, NULL, 0);
        }
        Serial.printf("[IR] Updated %s code: %s (0x%08X)\n", irCommands[i], irValue, *irCodes[i]);
      }
    }
  }

  // Power control - modified logic
  if (doc.containsKey("powerOn")) {
    bool newPowerState = doc["powerOn"];  // Auto conversion
    if (newPowerState != powerOn) {
      sendIRCode(ir_power, true);
      powerOn = newPowerState;
      Serial.printf("[Control] Power %s\n", powerOn ? "On" : "Off");
      markActivity();
      
      // Apply RGB values only when turning on (OFF→ON)
      if (powerOn && doc.containsKey("rgbCode")) {
        // Wait a bit after turning on
        delay(150);
        
        // Process RGB code here instead of in the separate block below
        if (doc["rgbCode"].size() == 3) {
          int targetR = doc["rgbCode"][0];
          int targetG = doc["rgbCode"][1];
          int targetB = doc["rgbCode"][2];
          
          // Constrain to valid range
          targetR = constrain(targetR, 0, 255);
          targetG = constrain(targetG, 0, 255);
          targetB = constrain(targetB, 0, 255);
          
          // Adjust RGB (power is already on)
          if (targetR != rgb[0] || targetG != rgb[1] || targetB != rgb[2]) {
            adjustRGB(targetR, targetG, targetB);
          }
        }
        // Skip the RGB processing block below as it has already been handled
        return;
      }
    }
  }

  // Adjust RGB - only when power is on
  if (powerOn && doc.containsKey("rgbCode")) {
    if (doc["rgbCode"].size() == 3) {
      int targetR = doc["rgbCode"][0];
      int targetG = doc["rgbCode"][1];
      int targetB = doc["rgbCode"][2];
      
      // Constrain to valid range
      targetR = constrain(targetR, 0, 255);
      targetG = constrain(targetG, 0, 255);
      targetB = constrain(targetB, 0, 255);

      // Process only if values have changed
      if (targetR != rgb[0] || targetG != rgb[1] || targetB != rgb[2]) {
        // Adjust RGB (only when power is on)
        adjustRGB(targetR, targetG, targetB);
      }
    }
  } 
  // Additional IR code commands - only processed if no dynamicIr was present
  else if (doc.containsKey("music1")) sendIRCode(ir_music1, true);
  else if (doc.containsKey("music2")) sendIRCode(ir_music2, true);
  else if (doc.containsKey("music3")) sendIRCode(ir_music3, true);
  else if (doc.containsKey("music4")) sendIRCode(ir_music4, true);
  else if (doc.containsKey("auto")) sendIRCode(ir_auto, true);
  else if (doc.containsKey("flash")) sendIRCode(ir_flash, true);
  else if (doc.containsKey("fade7")) sendIRCode(ir_fade7, true);
  else if (doc.containsKey("fade3")) sendIRCode(ir_fade3, true);
  else if (doc.containsKey("jump7")) sendIRCode(ir_jump7, true);
  else if (doc.containsKey("jump3")) sendIRCode(ir_jump3, true);
  else if (doc.containsKey("quick")) sendIRCode(ir_quick, true);
  else if (doc.containsKey("slow")) sendIRCode(ir_slow, true);
}

//------------------------------------------------------------------------------
// Handle serial JSON commands
//------------------------------------------------------------------------------
void handleSerialJson() {
  if (Serial.available() > 0) {
    String jsonString = Serial.readStringUntil('\n');
    
    // Debug - Echo received serial command
    Serial.println(F("[Serial] Received command:"));
    Serial.println(jsonString);
    
    StaticJsonDocument<256> doc;
    DeserializationError error = deserializeJson(doc, jsonString);
    
    if (error) {
      Serial.printf("[Serial] JSON parsing failed: %s\n", error.c_str());
      return;
    }
    
    processJsonMessage(doc);
  }
}

//------------------------------------------------------------------------------
// Adjust RGB values
//------------------------------------------------------------------------------
void adjustRGB(int targetR, int targetG, int targetB) {
  // Prevent unnecessary IR transmission if values are already the same
  if (targetR == rgb[0] && targetG == rgb[1] && targetB == rgb[2]) {
    return;
  }
  
  int rDiff = targetR - rgb[0];
  int gDiff = targetG - rgb[1];
  int bDiff = targetB - rgb[2];

  Serial.printf("[RGB] Adjusting: [%d,%d,%d] → [%d,%d,%d]\n", 
               rgb[0], rgb[1], rgb[2], targetR, targetG, targetB);

  // Check if IR codes are valid before proceeding
  if (ir_enterDiy == 0 || ir_rup == 0 || ir_rdown == 0 || 
      ir_gup == 0 || ir_gdown == 0 || ir_bup == 0 || ir_bdown == 0) {
    Serial.println("[RGB] Error: One or more required IR codes are invalid (zero)");
    Serial.printf("[RGB] DIY=%08X, RUP=%08X, RDOWN=%08X, GUP=%08X, GDOWN=%08X, BUP=%08X, BDOWN=%08X\n",
                 ir_enterDiy, ir_rup, ir_rdown, ir_gup, ir_gdown, ir_bup, ir_bdown);
    return;
  }

  // Enter DIY mode (attempt twice to account for possible transmission failure)
  sendIRCode(ir_enterDiy, true);
  delay(150); // Increased wait time after first DIY command
  sendIRCode(ir_enterDiy, true);
  delay(200); // Increased wait time for DIY mode activation

  // Adjust channels with larger differences first for efficiency
  struct Channel {  
    int diff;
    uint32_t upCode;
    uint32_t downCode;
    int index;
  } channels[3] = {
    {abs(rDiff), ir_rup, ir_rdown, 0},
    {abs(gDiff), ir_gup, ir_gdown, 1},
    {abs(bDiff), ir_bup, ir_bdown, 2}
  };
  
  // Sort by largest difference
  for (int i = 0; i < 2; i++) {
    for (int j = 0; j < 2 - i; j++) {
      if (channels[j].diff < channels[j+1].diff) {
        Channel temp = channels[j];
        channels[j] = channels[j+1];
        channels[j+1] = temp;
      }
    }
  }

  // Adjust channels with largest differences first
  for (int i = 0; i < 3; i++) {
    int idx = channels[i].index;
    int diff = (idx == 0) ? rDiff : (idx == 1 ? gDiff : bDiff);
    if (diff != 0) {
      uint32_t code = (diff > 0) ? channels[i].upCode : channels[i].downCode;
      int count = abs(diff);
      
      // Add slight delay between each color adjustment
      if (i > 0) delay(100);
      
      sendUpDownSequence(code, count);
      
      // Update current value
      rgb[idx] = (idx == 0) ? targetR : (idx == 1 ? targetG : targetB);
    }
  }

  markActivity();
  Serial.println("[RGB] Adjustment complete");
}

//------------------------------------------------------------------------------
// Send IR code - fixed to handle void return type of sendNEC
//------------------------------------------------------------------------------
bool sendIRCode(uint32_t code, bool withDelay) {
  if (code == 0) {
    Serial.println("[IR] Error: Attempted to send IR code 0");
    return false;
  }
  
  // Debug the IR transmission
  Serial.printf("[IR] Sending NEC code: 0x%08X\n", code);
  
  // Turn on the built-in LED to indicate transmission
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, LOW); // LOW turns on the LED on most ESP boards
  
  // Send the IR code - function returns void, not a boolean
  irsend.sendNEC(code, 32);
  
  // Turn off LED
  digitalWrite(LED_BUILTIN, HIGH); // HIGH turns off the LED
  
  if (withDelay) delay(50); // Increased from 20ms to 50ms for better reliability
  
  // Assume success if we get this far
  return true;
}

//------------------------------------------------------------------------------
// Send sequential IR codes - improved reliability
//------------------------------------------------------------------------------
void sendUpDownSequence(uint32_t updownCode, int count) {
  if (updownCode == 0) {
    Serial.println("[IR] Error: Attempted to send zero IR code in sequence");
    return;
  }
  
  // IR code interval adjustment (70ms for better reliability)
  const int IR_SIGNAL_GAP = 70;
  
  Serial.printf("[IR] Sending sequence of %d codes (0x%08X)\n", count, updownCode);
  
  for (int i = 0; i < count; i++) {
    bool success = sendIRCode(updownCode, false);
    
    if (!success) {
      Serial.printf("[IR] Failed to send code at step %d\n", i);
    }
    
    // Reset watchdog and maintain interval
    ESP.wdtFeed();
    delay(IR_SIGNAL_GAP);
    
    // Additional wait time for many signals
    if (count > 10 && i % 10 == 9) {
      delay(70); // Increased from 50ms to 100ms for reliability
    }
  }
}

//------------------------------------------------------------------------------
// Load state from EEPROM
//------------------------------------------------------------------------------
void loadFromEEPROM() {
  EEPROM.get(0, currentData);
  
  // Validity check
  if (currentData.powerOn > 1) {
    currentData.powerOn = 0;
    currentData.r = currentData.g = currentData.b = 0;
  }
  
  powerOn = (currentData.powerOn == 1);
  rgb[0] = currentData.r;
  rgb[1] = currentData.g;
  rgb[2] = currentData.b;
}

//------------------------------------------------------------------------------
// Save state to EEPROM
//------------------------------------------------------------------------------
void saveToEEPROM() {
  currentData.powerOn = powerOn ? 1 : 0;
  currentData.r = constrain(rgb[0], 0, 255);
  currentData.g = constrain(rgb[1], 0, 255);
  currentData.b = constrain(rgb[2], 0, 255);

  EEPROM.put(0, currentData);
  EEPROM.commit();

  Serial.printf("[Save] State saved: Power=%s, RGB=[%d,%d,%d]\n",
                powerOn ? "On" : "Off", rgb[0], rgb[1], rgb[2]);
  eepromNeedsSave = false;
}

//------------------------------------------------------------------------------
// Record activity and schedule save
//------------------------------------------------------------------------------
void markActivity() {
  lastActivityTime = millis();
  eepromNeedsSave = true;
}

//------------------------------------------------------------------------------
// Return WiFi status text
//------------------------------------------------------------------------------
String getWiFiStatusString(int status) {
  switch (status) {
    case WL_CONNECTED: return "Connected";
    case WL_NO_SHIELD: return "No WiFi Shield";
    case WL_IDLE_STATUS: return "Idle";
    case WL_NO_SSID_AVAIL: return "SSID Unavailable";
    case WL_SCAN_COMPLETED: return "Scan Completed";
    case WL_CONNECT_FAILED: return "Connection Failed";
    case WL_CONNECTION_LOST: return "Connection Lost";
    case WL_DISCONNECTED: return "Disconnected";
    default: return "Unknown";
  }
}

//------------------------------------------------------------------------------
// Check memory status and take action
//------------------------------------------------------------------------------
void checkHeapMemory() {
  uint32_t freeHeap = ESP.getFreeHeap();
  
  if (freeHeap < MIN_HEAP_SIZE) {
    Serial.printf("[Memory] Warning! Remaining heap: %u bytes\n", freeHeap);
    
    // Restart if memory is low
    if (reconnectAttempts > 5 && freeHeap < MIN_HEAP_SIZE / 2) {
      Serial.println("[Memory] Low memory - preparing to restart");
      
      // Save final state
      if (eepromNeedsSave) {
        saveToEEPROM();
      }
      
      delay(500);
      ESP.restart();
    }
  }
}

//------------------------------------------------------------------------------
// Report current device state
//------------------------------------------------------------------------------
void reportCurrentState() {
  Serial.printf("[State] Power: %s, RGB=[%d, %d, %d]\n", 
               powerOn ? "On" : "Off", rgb[0], rgb[1], rgb[2]);
  
  sendDeviceState();
}