---
title: Turning a Wii Remote into a Home Assistant Controller with ESP32
description: 'A follow-up to the ESP32 Wiimote library work: using a real ESP32, a USB serial bridge, MQTT, and a Home Assistant add-on to trigger automations from a Wii Remote.'
published: false
cover_image: 'https://raw.githubusercontent.com/andremmfaria/articles/main/articles/Turning%20a%20Wii%20Remote%20into%20a%20Home%20Assistant%20Controller%20with%20ESP32/cover-wiimote-home-assistant-controller.png'
tags:
  - homeassistant
  - esp32
  - mqtt
  - iot
date: '2026-08-10T00:00:00Z'
---
## 1. From Library Work to a Real Button

In the [previous article](https://dev.to/andremmfaria/improving-the-esp32-wiimote-library-from-prototype-to-production-ready-arduino-library-448e), I wrote about improving the ESP32 Wiimote library. That work was useful on its own. The original library already made it possible to connect a Nintendo Wii Remote to an ESP32 over Bluetooth Classic, but I wanted it to behave more like something you could build a real project on top of: clearer project structure, better examples, runtime logging, connection state, battery reporting, and Arduino Library Manager support.

At the time, the real reason for doing it was only hinted at. I wanted to use a Wii Remote as a physical controller for Home Assistant.

Not as a novelty dashboard. Not as another app. A real object with real buttons that can sit on a table and trigger automations without unlocking a phone, opening a web UI, or explaining to a voice assistant that no, I did not ask for the living room lamp to become a podcast.

The shape is simple:

```text
Wii Remote
  -> Bluetooth Classic
ESP32
  -> USB serial
Home Assistant add-on
  -> MQTT
Home Assistant automations
```

The ESP32 handles the awkward Bluetooth side. Home Assistant handles the useful automation side. MQTT sits between them as the boring, reliable contract.

That split is the important part of the design.

---

## 2. Why a Wii Remote Makes Sense

A Wii Remote is an odd thing to put in a home automation system, but only if you think of it as a game controller.

If you look at it as a cheap wireless input device, it starts to make more sense.

It has:

* directional buttons
* A and B buttons
* plus, minus, home, one, and two
* a familiar handheld shape
* Bluetooth
* battery power
* accelerometer hardware for future gesture work

Most smart home controls are either too abstract or too fragile. Phones are powerful, but they are not good shared controls. Voice assistants are convenient until they mishear you, lose context, or need the cloud to be in a good mood. Wall switches are reliable, but fixed.

A Wii Remote sits in a useful middle ground.

It is physical, cheap, wireless, programmable, and already designed to be held without looking at it. The buttons are distinct enough that you can build muscle memory around them. For some automations, that matters more than having a beautiful UI.

For example:

* `A` toggles a light
* `B` turns everything in a room off
* `PLUS` increases media volume
* `MINUS` decreases media volume
* `HOME` activates a scene
* the D-pad controls media playback or dashboard navigation

This is not meant to replace every Home Assistant interface. It is meant to be one small, reliable interaction surface.

Sometimes the best UI is a button that does exactly one thing.

---

## 3. The Hardware Boundary

The firmware runs on an ESP32-WROOM-32 development board connected to the Home Assistant host over USB.

The ESP32 needs Bluetooth Classic support. That detail matters because not every ESP32-family board is suitable. Some newer or smaller variants focus on Wi-Fi and BLE, but the Wii Remote uses Bluetooth Classic HID.

The hardware list is deliberately short:

* one ESP32-WROOM-32 development board
* one Nintendo Wii Remote
* one USB cable that carries data, not only power
* a Home Assistant host with add-on support
* an MQTT broker, usually the Mosquitto add-on

The ESP32 does not need Wi-Fi for this project.

That was intentional.

It would be possible to make the ESP32 connect directly to Wi-Fi and publish MQTT itself. In fact, that is probably the first version many people would imagine. But it also means putting Wi-Fi credentials, MQTT configuration, reconnect logic, TLS decisions, and broker behavior into a tiny firmware project whose real job is already tricky enough: Bluetooth HID with a Wii Remote.

Instead, the ESP32 stays narrow.

It pairs with the Wii Remote, reads controller state, and writes JSON lines to USB serial.

That gives the firmware a clean responsibility:

```text
Bluetooth input -> serial events
```

Everything network-related stays on the Home Assistant side, where it is easier to observe, configure, update, and recover.

---

## 4. The ESP32 Firmware

The firmware lives in the bridge repository under:

```text
esp32/wiimote-serial-bridge/
```

It uses the improved `ESP32Wiimote` library from the previous article:

```shell
arduino-cli lib install ESP32Wiimote
```

The firmware itself is not complicated, and that is one of its strengths.

On startup it:

1. starts serial at `115200`
2. initializes the Wiimote library
3. reduces library logging to warnings and errors
4. emits a firmware-ready message
5. prompts the user to pair the Wii Remote

Pairing is the standard Wii Remote flow: press `1 + 2`.

When the controller connects, the firmware emits:

```json
{"type":"status","wiimote":1,"connected":true}
```

Button transitions are emitted as JSON too:

```json
{"type":"btn","wiimote":1,"btn":"A","down":true}
{"type":"btn","wiimote":1,"btn":"A","down":false}
```

Battery changes are emitted when known:

```json
{"type":"battery","wiimote":1,"level":87}
```

And every ten seconds the firmware emits a heartbeat:

```json
{"type":"heartbeat","device":"esp32","wiimote":1,"connected":true,"battery":87}
```

The protocol is line-delimited JSON. One object per line. No binary framing. No custom transport. No cleverness hiding in the walls.

That makes it easy to debug with a serial monitor. If the ESP32 is working, you can see the messages before Home Assistant is involved at all.

That property is worth more than it looks. When an integration spans Bluetooth, firmware, USB, containers, MQTT, and Home Assistant automations, the ability to isolate one boundary with a serial monitor saves a lot of guessing.

---

## 5. Avoiding False Button Events

One small firmware detail is worth calling out because it is the kind of thing that makes prototypes feel haunted.

When the Wii Remote first connects, the firmware does not immediately emit button events from the first packet. It captures that first observed state as a baseline.

Only after that does it emit transitions.

The reason is simple: on connection, you do not want the first read to look like a meaningful change if it is only the controller settling into its initial state. A real automation system should not turn on a light because a Bluetooth controller happened to reconnect.

The firmware loop is built around that distinction:

```cpp
if (!baselineCaptured) {
  lastButtons = buttons;
  baselineCaptured = true;
} else {
  emitButtonsChanged(buttons);
}
```

This is the difference between "I can read a button" and "I trust this enough to let it touch the house."

The same philosophy appears elsewhere:

* connection changes are explicit status messages
* heartbeat messages prove the firmware is still alive
* battery updates are separate from button events
* waiting messages are emitted while no controller is connected

The firmware does not need to know what the `A` button does. It only needs to report, accurately and predictably, that `A` was pressed or released.

---

## 6. The Home Assistant Add-on

The other half of the project is a Home Assistant add-on called **WiiMote Bridge**.

It is a Python application packaged as an add-on container. Its job is to read the ESP32 serial stream and publish MQTT messages that Home Assistant can consume.

The add-on configuration looks like this:

```yaml
radios:
  - port: /dev/ttyUSB0
    baud: 115200
    controller_id: 1
mqtt:
  host: core-mosquitto
  port: 0
  username: ""
  password: ""
  transport: tcp
  ssl: false
  ssl_insecure: false
  topic_prefix: wiimote
  discover_enabled: true
log_level: info
```

Each `radios` entry represents one ESP32 connected to the Home Assistant host. The `controller_id` becomes part of the MQTT topic path.

For example, controller `1` publishes under:

```text
wiimote/1/...
```

The add-on opens the serial port, reads each line, parses the JSON, and maps it to MQTT.

A firmware button message like this:

```json
{"type":"btn","wiimote":1,"btn":"A","down":true}
```

becomes:

```text
topic: wiimote/1/button/A
payload: ON
```

The matching release becomes:

```text
topic: wiimote/1/button/A
payload: OFF
```

That gives Home Assistant the simplest possible automation trigger: subscribe to a topic and react to `ON`.

---

## 7. MQTT as the Contract

MQTT is not glamorous, which is one of its better qualities.

For this project, it gives the bridge a stable interface that is usable by Home Assistant but not trapped inside Home Assistant. Anything that can consume MQTT can consume the Wii Remote events.

The bridge publishes several topic families:

```text
wiimote/1/button/A
wiimote/1/button/B
wiimote/1/button/PLUS
wiimote/1/status/connected
wiimote/1/status/heartbeat
wiimote/1/status/battery
wiimote/1/events/status
wiimote/device/esp32/events/status
```

There are two styles here.

The first style is convenience topics. These are optimized for automations:

```text
wiimote/1/button/A -> ON
wiimote/1/status/battery -> 87
wiimote/1/status/connected -> true
```

The second style is passthrough event topics. Every valid firmware JSON message is forwarded as JSON under an event topic:

```text
wiimote/1/events/btn
wiimote/1/events/status
wiimote/1/events/battery
```

That means newer firmware events can still be observed even before the add-on grows a dedicated high-level topic for them.

This keeps the protocol extensible without making the first working version too broad.

---

## 8. Home Assistant Discovery

The first version of this idea could have stopped at raw MQTT automations.

That would work:

```yaml
alias: Toggle living room light from Wii Remote A
trigger:
  - platform: mqtt
    topic: wiimote/1/button/A
    payload: "ON"
action:
  - service: light.toggle
    target:
      entity_id: light.living_room
mode: single
```

But a good Home Assistant integration should also feel native once it is installed.

So the add-on supports MQTT Discovery.

When discovery is enabled, it publishes retained discovery topics so Home Assistant creates entities automatically:

* one connection binary sensor per controller
* one battery sensor per controller
* one binary sensor per supported button

That means the Wii Remote shows up in Home Assistant as something you can inspect, not just a pile of hidden MQTT topics.

The discovery payloads are retained and republished after MQTT reconnects. That matters because Home Assistant, the broker, and the add-on are separate processes. Restarting one of them should not make the entities disappear forever.

This is one of those unglamorous reliability details that makes the project feel much less like a weekend sketch.

---

## 9. Triggering Real Automations

Once the ESP32 is flashed and the add-on is running, the working loop is satisfyingly direct.

Press `1 + 2` on the Wii Remote. The controller connects to the ESP32. The add-on logs the connection status. MQTT receives button topics. Home Assistant reacts.

The raw automation form is useful when you want precise control:

```yaml
alias: Wii Remote A toggles the desk lamp
trigger:
  - platform: mqtt
    topic: wiimote/1/button/A
    payload: "ON"
action:
  - service: light.toggle
    target:
      entity_id: light.desk_lamp
mode: single
```

For common mappings, the repository also ships a Home Assistant automation blueprint:

```text
blueprints/automation/wiimote_common.yaml
```

The blueprint exposes actions for:

* `A`
* `HOME`
* `PLUS`

That is intentionally modest. It is enough to make common button mappings easy while keeping the lower-level MQTT topics available for anything more specific.

The pattern I like is:

```text
A     -> toggle the local light
HOME  -> activate the room default scene
PLUS  -> media volume up
MINUS -> media volume down
B     -> turn the room off
```

The exact mapping is personal. The important part is that Home Assistant sees the Wii Remote as a stream of deterministic events.

Once it is an event stream, it can do anything Home Assistant can do.

---

## 10. Scaling to Multiple Wii Remotes

The current ESP32 Wiimote stack is effectively one controller per ESP32 radio.

That sounds like a limitation, but it is a manageable one.

The add-on supports multiple radios in a single instance:

```yaml
radios:
  - port: /dev/ttyUSB0
    baud: 115200
    controller_id: 1
  - port: /dev/ttyUSB1
    baud: 115200
    controller_id: 2
```

Each ESP32 gets its own serial reader thread and its own controller ID. MQTT topics stay separated:

```text
wiimote/1/button/A
wiimote/2/button/A
```

That keeps automations readable. A Wii Remote in the living room and a Wii Remote in the office do not need to share state or identity.

Could the firmware eventually support multiple controllers on one ESP32? Maybe. But for this project, the cleaner path is one cheap ESP32 per Wii Remote.

It is not elegant in the abstract. It is robust in the real world.

I will take robust.

---

## 11. Failure Modes and Recovery

The full system crosses several boundaries, so recovery behavior matters.

The project is designed to make common failures visible:

* if the ESP32 boots, it emits a `ready` status
* if the Wii Remote is not connected, it emits waiting and pairing hints
* if the Wii Remote disconnects, it emits `connected: false`
* if the serial device disappears, the add-on retries
* if MQTT reconnects, discovery is republished
* if button events are visible but entities are missing, retained discovery topics can be inspected

The most common setup issue is usually the least interesting one: the wrong serial device path.

On Home Assistant OS, the ESP32 will normally appear as something like:

```text
/dev/ttyUSB0
/dev/ttyUSB1
/dev/ttyACM0
```

The second most common issue is a charge-only USB cable. It powers the ESP32 but creates no serial device. This is deeply annoying because it looks almost like success until you try to read from it.

The third common issue is MQTT configuration. The add-on defaults are meant to work with the official Mosquitto add-on:

```text
core-mosquitto
```

But if you run MQTT elsewhere, the host, credentials, transport, and TLS settings need to match that broker.

None of this is exotic. That is good. The failure modes are boring enough to diagnose.

---

## 12. What Is Still Missing

The bridge currently focuses on button events, connection state, heartbeat, and battery.

That is enough to make it useful, but the Wii Remote has more hardware available.

The obvious future work is:

* accelerometer MQTT topics
* gesture events
* Home Assistant commands back to the firmware
* rumble control
* LED control
* richer automation blueprints

The accelerometer is the most interesting next step, but also the easiest one to overdo.

Raw accelerometer data is noisy. Gesture recognition needs thresholds, timing, and some restraint. A good version should probably expose both raw events and a few interpreted gestures, but not pretend that every flick of the wrist is a meaningful command.

For now, buttons are the correct foundation.

Buttons are boring. Buttons work.

---

## Conclusion

The previous ESP32Wiimote work made the library usable as a foundation. This project turns that foundation into an actual Home Assistant input device.

The final architecture is deliberately split:

```text
Wii Remote
  -> ESP32 firmware
  -> USB serial JSON
  -> Home Assistant add-on
  -> MQTT
  -> automations
```

That separation keeps the ESP32 firmware small, keeps Bluetooth away from Home Assistant, and gives the automation layer a simple MQTT contract.

The bridge is available here:

* [https://github.com/andremmfaria/ha-wiimote-bridge](https://github.com/andremmfaria/ha-wiimote-bridge)

And the improved ESP32 Wiimote library is here:

* [https://github.com/andremmfaria/ESP32Wiimote](https://github.com/andremmfaria/ESP32Wiimote)

It is a slightly ridiculous project, but in the useful way. An old game controller, a cheap ESP32, and a few lines of MQTT can become a real physical interface for a smart home.

That is the kind of ridiculous I can defend.
