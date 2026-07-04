#include <M5Unified.h>
#include <BLE2902.h>
#include <BLEAdvertising.h>
#include <BLEDevice.h>
#include <BLEHIDDevice.h>
#include <BLEServer.h>
#include <BLESecurity.h>

namespace {
constexpr const char* kDeviceName = "Vibe Coding Remote";
constexpr const char* kVibeBatteryServiceUUID = "7A8B0101-6D3B-4C1A-8D4F-9E2B5C7A1000";
constexpr const char* kVibeBatteryLevelUUID = "7A8B0102-6D3B-4C1A-8D4F-9E2B5C7A1000";

constexpr uint8_t HID_F13 = 0x68;
constexpr uint8_t HID_F14 = 0x69;
constexpr uint8_t HID_F15 = 0x6A;

constexpr uint32_t kVoiceHoldThresholdMs = 180;
constexpr uint32_t kDoubleClickWindowMs = 360;
constexpr uint32_t kDebounceMs = 25;
constexpr uint32_t kBatteryUpdateMs = 30000;
constexpr uint32_t kScreenDimAfterMs = 10000;
constexpr uint8_t kDisplayActiveBrightness = 150;
constexpr uint8_t kDisplayDimBrightness = 24;

BLEHIDDevice* hid = nullptr;
BLECharacteristic* inputReport = nullptr;
BLECharacteristic* vibeBatteryLevel = nullptr;
BLEAdvertising* advertising = nullptr;

bool bleConnected = false;
bool bleStateChanged = false;

bool blueWasDown = false;
bool voiceActive = false;
bool waitingSecondClick = false;
uint32_t blueDownAt = 0;
uint32_t blueUpAt = 0;
uint32_t lastBlueEdgeAt = 0;

bool sideWasDown = false;
uint32_t sideEdgeAt = 0;

int lastBatteryPercent = -1;
uint32_t lastBatteryUpdateAt = 0;
uint32_t lastDisplayActivityAt = 0;
bool displayDimmed = false;

const uint8_t kKeyboardReportMap[] = {
    0x05, 0x01,        // Usage Page (Generic Desktop)
    0x09, 0x06,        // Usage (Keyboard)
    0xA1, 0x01,        // Collection (Application)
    0x85, 0x01,        // Report ID (1)
    0x05, 0x07,        // Usage Page (Keyboard/Keypad)
    0x19, 0xE0,        // Usage Minimum (Keyboard LeftControl)
    0x29, 0xE7,        // Usage Maximum (Keyboard Right GUI)
    0x15, 0x00,        // Logical Minimum (0)
    0x25, 0x01,        // Logical Maximum (1)
    0x75, 0x01,        // Report Size (1)
    0x95, 0x08,        // Report Count (8)
    0x81, 0x02,        // Input (Data, Variable, Absolute)
    0x95, 0x01,        // Report Count (1)
    0x75, 0x08,        // Report Size (8)
    0x81, 0x01,        // Input (Constant)
    0x95, 0x06,        // Report Count (6)
    0x75, 0x08,        // Report Size (8)
    0x15, 0x00,        // Logical Minimum (0)
    0x25, 0x73,        // Logical Maximum (115)
    0x05, 0x07,        // Usage Page (Keyboard/Keypad)
    0x19, 0x00,        // Usage Minimum (Reserved)
    0x29, 0x73,        // Usage Maximum (Keyboard Application)
    0x81, 0x00,        // Input (Data, Array)
    0xC0               // End Collection
};

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer*) override {
    bleConnected = true;
    bleStateChanged = true;
  }

  void onDisconnect(BLEServer*) override {
    bleConnected = false;
    bleStateChanged = true;
    if (advertising) {
      advertising->start();
    }
  }
};

int readBatteryPercent() {
  int level = M5.Power.getBatteryLevel();
  if (level < 0) {
    return -1;
  }
  if (level > 100) {
    return 100;
  }
  return level;
}

void wakeDisplay() {
  lastDisplayActivityAt = millis();
  if (displayDimmed) {
    M5.Display.setBrightness(kDisplayActiveBrightness);
    displayDimmed = false;
  }
}

void updateDisplayPower(uint32_t now) {
  if (!displayDimmed && now - lastDisplayActivityAt >= kScreenDimAfterMs) {
    M5.Display.setBrightness(kDisplayDimBrightness);
    displayDimmed = true;
  }
}

bool updateBatteryLevel(bool force = false) {
  const uint32_t now = millis();
  if (!force && now - lastBatteryUpdateAt < kBatteryUpdateMs) {
    return false;
  }

  lastBatteryUpdateAt = now;
  const int level = readBatteryPercent();
  if (level < 0) {
    return false;
  }

  const bool changed = (level != lastBatteryPercent);
  lastBatteryPercent = level;
  if (hid) {
    hid->setBatteryLevel(static_cast<uint8_t>(level));
  }
  if (vibeBatteryLevel) {
    uint8_t batteryByte = static_cast<uint8_t>(level);
    vibeBatteryLevel->setValue(&batteryByte, 1);
    if (bleConnected && changed) {
      vibeBatteryLevel->notify();
    }
  }
  return changed;
}

uint16_t batteryColor(int level) {
  if (level < 0) {
    return TFT_DARKGREY;
  }
  if (level <= 20) {
    return TFT_RED;
  }
  if (level <= 40) {
    return TFT_ORANGE;
  }
  return TFT_GREEN;
}

void drawBatteryBar() {
  char percentText[8];
  const int level = lastBatteryPercent >= 0 ? lastBatteryPercent : readBatteryPercent();
  if (level >= 0) {
    snprintf(percentText, sizeof(percentText), "%d%%", level);
  } else {
    snprintf(percentText, sizeof(percentText), "--%%");
  }

  const int screenWidth = M5.Display.width();
  const int barX = 44;
  const int barY = 4;
  const int barWidth = 70;
  const int barHeight = 12;
  const int fillWidth = level >= 0 ? (barWidth - 4) * level / 100 : 0;

  M5.Display.fillRect(0, 0, screenWidth, 20, TFT_BLACK);
  M5.Display.setFont(&fonts::efontCN_12);
  M5.Display.setTextColor(TFT_LIGHTGREY, TFT_BLACK);
  M5.Display.setTextDatum(top_left);
  M5.Display.drawString("电量", 6, 5);

  M5.Display.drawRoundRect(barX, barY, barWidth, barHeight, 3, TFT_LIGHTGREY);
  if (fillWidth > 0) {
    M5.Display.fillRoundRect(barX + 2, barY + 2, fillWidth, barHeight - 4, 2, batteryColor(level));
  }

  M5.Display.setFont(&fonts::efontCN_16);
  M5.Display.setTextColor(level >= 0 ? batteryColor(level) : TFT_LIGHTGREY, TFT_BLACK);
  M5.Display.setTextDatum(top_right);
  M5.Display.drawString(percentText, screenWidth - 6, 2);
}

void drawStatus(const char* line1, const char* line2 = "", bool force = false) {
  wakeDisplay();
  M5.Display.fillScreen(TFT_BLACK);
  drawBatteryBar();
  M5.Display.setTextColor(TFT_WHITE, TFT_BLACK);
  M5.Display.setTextDatum(middle_center);
  M5.Display.setFont(&fonts::efontCN_24);
  M5.Display.drawString(line1, M5.Display.width() / 2, 48);
  M5.Display.setFont(&fonts::efontCN_16);
  M5.Display.drawString(line2, M5.Display.width() / 2, 72);
}

void sendKeyReport(uint8_t usage) {
  if (!bleConnected || inputReport == nullptr) {
    drawStatus("等待连接", kDeviceName);
    return;
  }

  uint8_t report[8] = {0, 0, usage, 0, 0, 0, 0, 0};
  inputReport->setValue(report, sizeof(report));
  inputReport->notify();
}

void releaseKeys() {
  if (!bleConnected || inputReport == nullptr) {
    return;
  }

  uint8_t report[8] = {0, 0, 0, 0, 0, 0, 0, 0};
  inputReport->setValue(report, sizeof(report));
  inputReport->notify();
}

void tapKey(uint8_t usage) {
  sendKeyReport(usage);
  delay(20);
  releaseKeys();
}

void startBleKeyboard() {
  BLEDevice::init(kDeviceName);
  BLEDevice::setEncryptionLevel(ESP_BLE_SEC_ENCRYPT_NO_MITM);

  auto* security = new BLESecurity();
  security->setAuthenticationMode(ESP_LE_AUTH_BOND);
  security->setCapability(ESP_IO_CAP_NONE);
  security->setInitEncryptionKey(ESP_BLE_ENC_KEY_MASK | ESP_BLE_ID_KEY_MASK);

  BLEServer* server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());

  hid = new BLEHIDDevice(server);
  inputReport = hid->inputReport(1);
  hid->manufacturer();
  hid->manufacturer("M5Stack");
  hid->pnp(0x02, 0x303A, 0x1001, 0x0100);
  hid->hidInfo(0x00, 0x02);
  hid->reportMap((uint8_t*)kKeyboardReportMap, sizeof(kKeyboardReportMap));
  hid->startServices();

  BLEService* vibeBatteryService = server->createService(kVibeBatteryServiceUUID);
  vibeBatteryLevel = vibeBatteryService->createCharacteristic(
      kVibeBatteryLevelUUID,
      BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  vibeBatteryLevel->addDescriptor(new BLE2902());
  vibeBatteryService->start();

  updateBatteryLevel(true);

  advertising = BLEDevice::getAdvertising();
  advertising->setAppearance(HID_KEYBOARD);
  advertising->addServiceUUID(hid->hidService()->getUUID());
  advertising->setScanResponse(true);
  advertising->setMinPreferred(0x06);
  advertising->setMaxPreferred(0x12);
  advertising->start();
  drawStatus("蓝牙已开启", kDeviceName);
}

void startVoice() {
  if (voiceActive) {
    return;
  }
  voiceActive = true;
  waitingSecondClick = false;
  sendKeyReport(HID_F14);
  drawStatus("语音输入", "松开结束");
}

void stopVoice() {
  if (!voiceActive) {
    return;
  }
  releaseKeys();
  voiceActive = false;
  drawStatus(bleConnected ? "已连接" : "等待连接", "右键打开软件");
}

void sendCodex() {
  tapKey(HID_F15);
  drawStatus("已发送", "蓝键双击");
}

void openCodex() {
  tapKey(HID_F13);
  drawStatus("打开软件", "目标应用");
}

void handleBlueButton(bool down, uint32_t now) {
  if (down != blueWasDown && now - lastBlueEdgeAt < kDebounceMs) {
    return;
  }

  if (down != blueWasDown) {
    lastBlueEdgeAt = now;
    blueWasDown = down;

    if (down) {
      blueDownAt = now;
    } else {
      if (voiceActive) {
        stopVoice();
      } else {
        if (waitingSecondClick && now - blueUpAt <= kDoubleClickWindowMs) {
          waitingSecondClick = false;
          sendCodex();
        } else {
          waitingSecondClick = true;
          blueUpAt = now;
        }
      }
    }
  }

  if (down && !voiceActive && now - blueDownAt >= kVoiceHoldThresholdMs) {
    startVoice();
  }

  if (waitingSecondClick && now - blueUpAt > kDoubleClickWindowMs) {
    waitingSecondClick = false;
    drawStatus(bleConnected ? "已连接" : "等待连接", "按住语音 双击发送");
  }
}

void handleRightButton(bool down, uint32_t now) {
  if (down != sideWasDown && now - sideEdgeAt < kDebounceMs) {
    return;
  }

  if (down != sideWasDown) {
    sideEdgeAt = now;
    sideWasDown = down;
    if (!down) {
      openCodex();
    }
  }
}
}

void setup() {
  auto cfg = M5.config();
  cfg.fallback_board = m5::board_t::board_M5StickS3;
  cfg.clear_display = true;
  cfg.led_brightness = 8;
  M5.begin(cfg);

  M5.Display.setRotation(1);
  M5.Display.setBrightness(kDisplayActiveBrightness);
  lastDisplayActivityAt = millis();
  drawStatus("等待连接", kDeviceName, true);

  startBleKeyboard();
}

void loop() {
  M5.update();
  const uint32_t now = millis();

  // On StickS3, the front blue button is usually BtnA and the side business
  // button is usually BtnB. The left power/reset button is intentionally unused.
  handleBlueButton(M5.BtnA.isPressed(), now);
  handleRightButton(M5.BtnB.isPressed(), now);

  if (bleStateChanged) {
    bleStateChanged = false;
    drawStatus(bleConnected ? "已连接" : "等待连接", bleConnected ? "可以使用" : kDeviceName);
  }

  if (updateBatteryLevel()) {
    drawBatteryBar();
  }
  updateDisplayPower(now);

  delay(10);
}
