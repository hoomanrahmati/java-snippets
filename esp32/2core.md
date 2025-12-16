```cpp
void blinkLed(){
  while(1){
    rgbLedWrite(97, 0, 5, 0);
    Serial.println("green");
    delay(2000);
    rgbLedWrite(97, 5, 0, 0);
    Serial.println("red");
    delay(2000);
  }
}

void buttonPressed(){
  while(1){
    bool isPressed = digitalRead(4);

    if(!isPressed){
      rgbLedWrite(97, 0, 5, 5);
    }
    delay(1);
  }
}

void setup() {
  pinMode(4, INPUT_PULLUP);
  pinMode(97, OUTPUT);
  Serial.begin(115200);

  xTaskCreatePinnedToCore(
    [](void * param){
      buttonPressed();
    }, // lambda function
    "Wire_Press", //  tag name
    5000, // Workbench size (stack memory)
    NULL, // No extra tools needed
    1, // Priority level (1 = normal)
    NULL, // Don't need to track core 0
    1 // Put this task on CORE 1
  );

}

void loop() {
  blinkLed();
}
```
