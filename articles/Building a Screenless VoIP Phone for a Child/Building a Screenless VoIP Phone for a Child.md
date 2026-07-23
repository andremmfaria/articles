---
title: Building a Screenless VoIP Phone for a Child
description: 'A small design for a child-friendly phone: big buttons, no screen, restricted calls, and voice messages routed through Home Assistant.'
published: false
tags:
  - homeassistant
  - voip
  - homelab
  - diy
id: 4213939
date: '2026-07-23T10:13:33Z'
---

I started with a simple idea: I wanted a phone my son could use to reach me or his grandparents.

Not a smartphone. Not a tablet with an app. Not another glowing rectangle with notifications, updates, accounts, and the usual nonsense attached. Just a physical phone with large buttons. Pick it up, press the picture of the person you want, talk.

The extra requirement was the interesting part: I also wanted one of the buttons to let him leave a recorded message that would reach me through Home Assistant.

That sounds like a custom device at first, but it does not need to be. The right design is almost disappointingly old-fashioned:

```text
big-button analogue phone -> VoIP ATA -> Asterisk -> SIP trunk / Home Assistant
```

The phone itself stays dumb. That is the point.

## The phone is not the brain

An RJ11 analogue phone does not understand VoIP, Home Assistant, messages, automations, or routing. It expects a telephone line to provide dial tone, line voltage, ringing, and an audio path.

That is useful. A simple phone is robust, familiar, and child-friendly. The physical interface is the feature.

The intelligence lives behind it, in two layers:

- an **ATA**, which pretends to be a landline
- a **PBX**, which decides what each dialled code means

ATA means analogue telephone adapter. For this build, the important detail is that it needs an **FXS** port. FXS is the port that powers an analogue phone. FXO is the opposite: it connects to a real landline. Easy mistake, annoying return.

The ATA I settled on is a **Grandstream HT812 V2**. It has two FXS ports, which is more than I need for one phone but useful for testing or a second handset later. The HT818 also exists, but that has eight FXS ports. Lovely if you are building a small hotel phone system. Mildly ridiculous for one child phone.

## The PBX is where the behaviour lives

The ATA connects to Asterisk, running as a Home Assistant add-on. Asterisk is the PBX: the private branch exchange, or in less historical language, the call brain.

The child phone registers as a SIP endpoint, maybe extension `200`. The physical buttons on the phone are programmed to dial internal codes:

```text
101 = call Dad
102 = call Mum
103 = call grandparents
104 = leave Dad a message
105 = leave Mum a message
```

The child never needs to know those numbers. The buttons get labels or photos. The PBX maps the codes to actions.

So pressing a button is not really "dialling a number". It is triggering a controlled workflow:

```text
button press -> ATA -> Asterisk dialplan -> action
```

For live calls, Asterisk dials exactly one configured phone number through a SIP provider:

```text
101 -> Dial Dad's mobile
103 -> Dial grandparents
```

For messages, Asterisk answers locally:

```text
104 -> answer -> beep -> record -> notify parent
```

That is the architectural trick. Do not make the phone clever. Make the backend clever.

## Default deny, because children press buttons

The safety model matters more than the telephony.

The child phone should never inherit a general outbound dial plan. In Asterisk, that means the endpoint gets its own restricted context. It can dial only the internal codes we explicitly allow.

Something like this conceptually:

```asterisk
[child-phone-only]
exten => 101,1,Dial(PJSIP/+353XXXXXXXXX@voip-provider)
exten => 103,1,Dial(PJSIP/+353YYYYYYYYY@voip-provider)
exten => 104,1,Goto(child-message,s,1)
```

There should be no fallback like "if it looks like a number, send it to the trunk". That is how you accidentally build a normal phone.

The ATA should also be restricted. Grandstream devices support dial plans/digit maps, so the ATA can be configured to accept only the internal codes:

```text
101|102|103|104|105
```

The PBX remains the real security boundary, but the ATA becomes a useful second guardrail. If the phone has a keypad, random button mashing should go nowhere.

## Recording a message is just another extension

The message feature does not need a separate product.

Asterisk can record audio from a call. A dialplan extension can answer, play a short prompt or beep, record until hang-up or timeout, then run a fixed script.

The flow looks like this:

```text
child presses Message
phone dials 104
Asterisk answers
Asterisk records WAV
Asterisk runs a script
script notifies Home Assistant
Home Assistant notifies parent
```

There are several ways to bridge Asterisk to Home Assistant:

- call a Home Assistant webhook
- publish an MQTT event
- call the Home Assistant REST API

I would use MQTT or a webhook first. It is simple, local, and easy to reason about.

The important rule is not to pass arbitrary dialled input into shell commands. Each button maps to a known extension, and each extension runs a known action. No dynamic "execute whatever was dialled" cleverness. Cleverness is where future you loses an evening.

## Home Assistant and Asterisk

There is a useful Home Assistant ecosystem around this already.

The project I found is the TECH7Fox/SIP-HASS Asterisk add-on. It runs Asterisk inside Home Assistant and exposes the real Asterisk configuration files under the add-on config directory.

There is also a HACS Asterisk integration that connects to Asterisk over AMI, the Asterisk Manager Interface. That can expose device state, registration state, connected line, DTMF events, and a generic `send_action` service for AMI commands like `Ping`, `Originate`, or `Hangup`.

For this build, I would use them differently:

- **Asterisk add-on**: the actual PBX and dialplan engine
- **Asterisk integration**: monitoring and control from Home Assistant

I would not make the Home Assistant integration the core path for the child button actions. That belongs in the Asterisk dialplan. It is lower-level, more deterministic, and less likely to break because a Home Assistant custom integration changed an entity model.

Home Assistant should observe and react. Asterisk should decide what a dialled code means.

## The emergency-call problem

There is one uncomfortable detail: this thing looks like a landline.

That means everyone in the house may assume it can call emergency services. If it cannot call `999` or `112`, that needs to be explicit. If it can, then emergency support becomes a proper requirement:

- SIP provider support for Irish emergency calls
- correct caller ID
- registered location/address handling
- UPS for ATA, PBX, switch, router, and internet handoff
- tested routing
- fallback if internet or power is down

For the first version, I would not pretend it is an emergency phone. I would build it as a family communication device and label it accordingly.

Half-supporting emergency calls is worse than not supporting them. It creates confidence where there should be caution.

## The build, in one page

The first version is simple:

```text
big-button RJ11 phone
  -> Grandstream HT812 V2
  -> Asterisk Home Assistant add-on
  -> SIP trunk for family calls
  -> MQTT/webhook into Home Assistant for messages
```

The first milestone is not "full telephone system". It is:

- child phone gets dial tone
- Dad button calls exactly Dad
- grandparents button calls exactly grandparents
- message button records audio
- Home Assistant tells me a message arrived
- random dialling is rejected
- Home Assistant alerts if the phone/PBX goes offline

That is enough.

It keeps the child-facing device physical and boring, which is exactly what I want. All the complexity stays in software, where it can be inspected, backed up, changed, and locked down.

Sometimes the right smart device is a dumb device with a better backend.
