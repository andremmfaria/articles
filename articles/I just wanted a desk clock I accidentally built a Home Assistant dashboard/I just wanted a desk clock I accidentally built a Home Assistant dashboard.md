---
title: I just wanted a desk clock I accidentally built a Home Assistant dashboard
tags:
  - homeassistant
  - hacking
  - iot
published: false
cover_image: 'https://community-assets.home-assistant.io/optimized/4X/7/5/a/75a87e8573336338538dd3a8798ab353358120ef_2_333x250.jpeg'
---

## **1. The Unexpected Device**

### Purpose 1

Set the context. Explain the mismatch between expectation and reality.

### Include 1

* The original intent:

  * A simple desk clock
  * Wi-Fi sync
  * Minimal setup, plug-and-play mindset
* The actual device:

  * GeekMagic Ultra 4
  * Marketed as a “smart weather clock”
  * Ships with proprietary firmware
* First impressions:

  * Looks polished, but limited
  * Closed ecosystem feel
* The turning point:

  * Realization it’s based on **ESP8266**
  * Meaning: fully flashable, ESPHome-compatible

### Key message 1

This is not a consumer gadget. It’s a **disguised dev board with a display**.

---

## **2. Peeling It Open: Hardware Reality**

### Purpose 2

Ground the reader in what the device actually is under the hood.

### Include 2

* Internal architecture (based on teardown image):

  * ESP8266 module
  * ST7789 240×240 display
  * SPI interface (no CS)
  * PWM-controlled backlight
* Pin mapping realities:

  * GPIO14 / GPIO13 → SPI
  * GPIO0 / GPIO2 → control
  * GPIO5 → backlight
* Constraints:

  * Very limited RAM
  * No PSRAM
  * Display buffering is a problem

### Explain clearly

Why this matters:

* You cannot treat this like an ESP32
* You must design around memory limits

### Key message 2

The device is powerful, but **fragile if misconfigured**.

---

## **3. The Real Work: Community Reverse Engineering**

### Purpose 3

Acknowledge where the solution actually came from.

### Include references

* YouTube baseline:
  * S1Q9PZ95SDM (<https://www.youtube.com/watch?v=S1Q9PZ95SDM>)
* Forum thread:
  * Home Assistant Community thread (<https://community.home-assistant.io/t/installing-esphome-on-geekmagic-smart-weather-clock-smalltv-pro/618029/7>)

### Explain

* The official docs are not enough
* The device is not supported out-of-the-box
* Most knowledge comes from:

  * trial and error
  * shared configs
  * pin mapping discoveries
  * driver changes (`ili9xxx` → `mipi_spi`)

### Highlight key learnings from the thread

* `spi_mode: mode3` is mandatory
* `color_depth: 8` is required
* buffer management is critical
* ESP8266 display = constrained rendering

### Key message 3

This project stands on **community knowledge, not documentation**.

---

## **4. Making It Work: ESPHome + Home Assistant Integration**

### Purpose 4

Explain how the system actually works once everything is wired correctly.

### Architecture to describe

```text
UniFi Dream Machine → Home Assistant → ESPHome → Display
```

### Components involved

* Home Assistant sensors:

  * WAN status
  * RX / TX totals
  * Upload / download speeds
  * External IP
  * uptime
* ESPHome:

  * pulls data via `homeassistant:` platform
  * renders UI via display lambda

### Key design decisions

* No MQTT needed (direct HA API)
* Stateless display (no caching logic)
* Rendering every ~15 seconds

### Explain transformations

* Uptime (seconds → human readable)
* Bytes → KB / MB / GB
* Speeds → relabeled (Kib/s)

### Key message 4

The ESP8266 is not computing — it is **rendering a view of Home Assistant state**.

---

## **5. The UI: Constraints Drive Design**

### Purpose 5

Explain how limitations shaped the interface.

### Constraints

* 240×240 screen
* Limited RAM → no full framebuffer
* Slow rendering warnings (~150ms)
* Font size vs layout trade-offs

### Design choices

* Large time (primary function)
* Date aligned opposite (visual balance)
* WAN + IP split across screen
* Minimal redraw complexity
* No images, only primitives

### Show layout concept

```text
[ TIME          DATE ]
[ WAN UP        IP  ]
---------------------
[ Down / Up ]
[ RX / TX  ]
---------------------
[ Uptime   ]
```

### Explain trade-offs

* Alignment vs clipping
* font_large vs font_medium compromises
* right-aligned text complexity in ESPHome

### Key message 5

The UI is not aesthetic-first.
It is **performance-constrained engineering**.

---

## **6. What This Became (and Why It’s Better Than a Clock)**

### Purpose 6

Close the article with reflection and value.

### Contrast

What you wanted:

* Simple clock
* Wi-Fi sync
* Set-and-forget

What you got:

* Fully programmable display
* Real-time network monitor
* Home Assistant integration node
* Extendable platform

### Expand possibilities

* Add alerts (WAN down flashing)
* Add MQTT control
* Add pages / screens
* Add touch or button interaction (if hardware allows)
* Extend to other dashboards (weather, sensors, etc.)

### Reflection angle

* Accidental complexity → intentional system
* Consumer device → infrastructure component

### Key message 6

This is not a clock anymore.
It is a **tiny, network-aware dashboard terminal**.
