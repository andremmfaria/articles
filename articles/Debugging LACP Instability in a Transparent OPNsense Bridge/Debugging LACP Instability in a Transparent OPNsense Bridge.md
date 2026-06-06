---
title: Debugging LACP Instability in a Transparent OPNsense Bridge
published: true
description: A technical postmortem of a transparent OPNsense bridge where LACP instability looked like vague network slowness before the physical-layer evidence became clear.
cover_image: 'https://raw.githubusercontent.com/andremmfaria/articles/main/articles/Debugging%20LACP%20Instability%20in%20a%20Transparent%20OPNsense%20Bridge/cover-lacp-instability.jpg'
tags:
  - opnsense
  - networking
  - homelab
id: 3831123
date: '2026-06-06T00:12:00Z'
---

I run a [transparent OPNsense bridge](https://docs.opnsense.org/manual/other-interfaces.html#bridge) between a UniFi Dream Machine Pro and the rest of my LAN. It is deliberately boring at Layer 3: the UDM keeps routing, DHCP, DNS, firewall policy, WAN handling, and VLAN definitions. OPNsense sits inline as a Layer 2 bump in the wire.

The interesting part is that both sides of that bump use [LACP](https://www.ieee802.org/1/pages/802.1AX-rev.html).

I already wrote the build/configuration guide for this setup here: [Building a Transparent LAGG (LACP) Bridge with OPNsense, UDM, and UniFi - A Practical Guide](https://dev.to/andremmfaria/building-a-transparent-lagg-lacp-bridge-with-opnsense-udm-and-unifi-a-practical-guide-1d21). That article explains how the bridge was built, how the LAGG devices were configured, and why I wanted the firewall to remain transparent.

This article is the other half of the story: what happens when that kind of setup fails in a non-obvious way.

Not a clean outage. Not a single "the network is down" moment. Just enough instability to make everything feel wrong.

## 1. Topology and Failure Surface

The topology looked like this:

```text
                          +----------------------+
                          | UniFi Dream Machine  |
                          | kantharos-udm-pro    |
                          +----------+-----------+
                                     |
                         LACP aggregate, 2 x 1G
                                     |
                            OPNsense lagg0
                            "ingresslagg"
                          igc1 + igc2, LACP
                                     |
                          +----------v-----------+
                          | OPNsense bridge0     |
                          | "laggbridge"         |
                          +----------+-----------+
                                     |
                            OPNsense lagg1
                            "egresslagg"
                          igc4 + igc5, LACP
                                     |
                         LACP aggregate, 2 x 1G
                                     |
                          +----------v-----------+
                          | UniFi USW-Lite-16    |
                          | downstream LAN       |
                          +----------------------+
```

On OPNsense, the relevant interfaces were:

```text
igc1 + igc2 -> lagg0 -> ingresslagg -> toward UDM
igc4 + igc5 -> lagg1 -> egresslagg  -> toward USW
lagg0 + lagg1 -> bridge0 -> laggbridge
```

The bridge is a FreeBSD bridge. The aggregates are [FreeBSD `lagg(4)`](https://man.freebsd.org/cgi/man.cgi?query=if_lagg&sektion=4) interfaces using LACP. OPNsense exposes those through its [Interfaces > Devices](https://docs.opnsense.org/manual/other-interfaces.html#lagg) UI.

The expected healthy OPNsense state is:

```text
laggproto lacp
status: active
laggport: igcX flags=<ACTIVE,COLLECTING,DISTRIBUTING>
laggport: igcY flags=<ACTIVE,COLLECTING,DISTRIBUTING>
```

Those three member states matter:

- `ACTIVE`: the member is participating in the LACP bundle.
- `COLLECTING`: the member may receive traffic.
- `DISTRIBUTING`: the member may transmit traffic.

For an LACP link, carrier alone is not enough. A cable can show link, but if the member is not collecting and distributing, it is not a healthy participant in the aggregate.

In a transparent bridge, that distinction matters more than usual. OPNsense is not routing around the problem. It is forwarding Ethernet frames between two aggregated links, much like the [OPNsense bridge documentation](https://docs.opnsense.org/manual/other-interfaces.html#bridge) describes for Layer 2 forwarding and MAC learning. If one LACP member misbehaves, the symptoms can leak across the whole Layer 2 segment.

## 2. Symptoms: Instability, Not Interruption

The failure did not present as a clean interruption.

There was no single point where the whole LAN died and stayed dead. Instead, the network became unstable:

- traffic slowed down
- clients behaved inconsistently
- management sessions became flaky
- UniFi and OPNsense did not always describe the same state
- LACP state changed underneath the transparent bridge
- the bridge looked partially alive and partially broken

This is exactly the sort of fault LACP makes annoying.

With a single Ethernet cable, a physical failure is usually obvious. The link drops. The port goes down. The device disappears.

With LACP, a single member can become marginal while the logical aggregate still exists. The point of a [Link Aggregation Group](https://www.ieee802.org/1/pages/802.1AX-rev.html) is that multiple full-duplex point-to-point links are treated as one logical link, but the physical members still exist underneath. Some traffic survives. Some traffic lands on the bad member. Some flows stall, some retry, and some keep working. The user-facing symptom becomes "the network is weird", which is among the least useful sentences in infrastructure.

The reason is hashing. LACP does not normally split one flow across all cables like a striped disk. The [FreeBSD handbook](https://docs.freebsd.org/en/books/handbook/advanced-networking/#network-aggregation) notes that Ethernet frame ordering means traffic between two stations stays on the same physical link, while the transmit algorithm tries to distinguish flows and balance them across the aggregate. Depending on the device and configuration, that hash may use Layer 2, Layer 3, or Layer 4 fields. In my OPNsense setup, the LAGG hash was Layer 2:

```text
laggproto lacp lagghash l2
```

A simplified model:

```text
flow A -> member 1 -> works
flow B -> member 2 -> stalls
flow C -> member 1 -> works
flow D -> member 2 -> retries
```

That creates a failure mode which feels like congestion, DNS trouble, Wi-Fi trouble, controller weirdness, or firewall slowness. It is not always obvious that the problem is a physical member inside an aggregate.

This is the central trap: partial LACP failure can masquerade as general network degradation.

## 3. OPNsense Evidence: The Bundle Was Actually Flapping

The strongest evidence came from OPNsense logs in the system log files (`/var/log/system/system_20260605.log`). Two windows mattered:

```text
2026-06-05 02:26:32-02:28:01 UTC
2026-06-05 20:08:27-21:22:31 UTC
```

During the earlier window, OPNsense saw:

```text
igc1 and igc2 went down/up repeatedly
lagg0: link state changed to DOWN
lagg0: link state changed to UP
igc4/igc5: Interface stopped DISTRIBUTING, possible flapping
```

During the major evening window:

```text
20:08:27  lagg1 went DOWN
20:10:19  lagg1 came UP
20:19:12  lagg1 went DOWN again
20:24-20:41 igc4/igc5 continued bouncing
20:26:47  lagg0 dropped
20:34:36  lagg0 came back
21:05:10  lagg1 dropped again
21:05:44  lagg1 came back
21:22:28  lagg0 detached during final bypass/reset activity
21:22:31  lagg1 detached during final bypass/reset activity
```

The most useful phrase was:

```text
Interface stopped DISTRIBUTING, possible flapping
```

That is not an application-layer symptom. It is not DNS. It is not an IP routing issue. It is not a firewall rule. It means the LACP member state changed at the link aggregation layer. A simplified [LACP](https://docs.freebsd.org/en/books/handbook/advanced-networking/#network-aggregation) health path looks like this:

```text
Physical carrier up
  v
LACP peer detected
  v
Correct partner/system/key information
  v
Member selected into aggregator
  v
Member allowed to collect and distribute traffic
```

If a member stops distributing, the aggregate may still exist, but it is no longer healthy. The device has decided that member should not transmit traffic as a valid part of the bundle. The current healthy state after reconnecting the bridge looked like this:

```text
lagg0:
  laggproto lacp lagghash l2
  laggport: igc1 flags=<ACTIVE,COLLECTING,DISTRIBUTING>
  laggport: igc2 flags=<ACTIVE,COLLECTING,DISTRIBUTING>
  status: active

lagg1:
  laggproto lacp lagghash l2
  laggport: igc4 flags=<ACTIVE,COLLECTING,DISTRIBUTING>
  laggport: igc5 flags=<ACTIVE,COLLECTING,DISTRIBUTING>
  status: active
```

And the bridge itself:

```text
bridge0:
  member: lagg1
    role root
    state forwarding

  member: lagg0
    role designated
    state forwarding
```

That contrast matters. During the incident, OPNsense saw real LAGG instability. After remediation, it saw active LACP members and a forwarding bridge. This matches the healthy FreeBSD example where `ifconfig lagg0` reports `status: active` and member ports with `ACTIVE,COLLECTING,DISTRIBUTING` flags in the [FreeBSD link aggregation documentation](https://docs.freebsd.org/en/books/handbook/advanced-networking/#network-aggregation).

## 4. UniFi Evidence: Correct Controller State, Weird UDM Internals

The UniFi side complicated the investigation because the UDM Pro did not expose this like a normal Linux LACP bond. UniFi's own [Port Aggregation FAQ](https://help.ui.com/hc/en-us/articles/360007279753-Port-Aggregation-FAQs) says static LAG is not supported and aggregation uses LACP, while also calling out that gateway support is limited to specific models including the UDM Pro.

Over SSH, the UDM showed:

```text
eth6@switch0 UP
eth7@switch0 UP
lacp6 LOWER_UP
lacp7 LOWER_UP
lag0 DOWN / NO-CARRIER
```

And `/proc/net/bonding/lag0` showed:

```text
Ethernet Channel Bonding Driver: v3.7.1
Bonding Mode: load balancing (round-robin)
MII Status: down
```

The sysfs bonding view was suspicious too:

```text
/sys/class/net/lag0/bonding/mode       balance-rr 0
/sys/class/net/lag0/bonding/slaves     empty
/sys/class/net/lag0/carrier            0
/sys/class/net/lag0/operstate          down
```

For a normal [Linux bonding](https://www.kernel.org/doc/html/latest/networking/bonding.html) LACP bond, this would be terrible. Linux bonding documentation describes enslaving interfaces through `/sys/class/net/<bond>/bonding/slaves` and shows `/proc/net/bonding/<bond>` output listing the slave interfaces and their MII status. I would expect something closer to:

```text
Bonding Mode: IEEE 802.3ad Dynamic link aggregation
Slave Interface: ...
MII Status: up
Aggregator ID: ...
Partner Mac Address: ...
```

That is not what the UDM showed, but the UniFi controller showed a more coherent story.

On the UDM:

```text
Port 7:
  op_mode: aggregate
  aggregate_members: [7, 8]
  up: true
  speed: 1000

Port 8:
  aggregated_by: 7
  masked: true
  up: true
  speed: 1000
```

On the USW-Lite-16-PoE:

```text
Port 7:
  op_mode: aggregate
  aggregate_members: [7, 8]
  aggregate_num_ports: 2
  lacp_state:
    - member_port: 7, active: true, speed: 1000
    - member_port: 8, active: true, speed: 1000
  partner_system_id: e4:3a:6e:5d:a0:00
  stp_state: forwarding

Port 8:
  aggregated_by: 7
  lag_member: true
  stp_state: forwarding
```

The `partner_system_id` is important. It matched the OPNsense `lagg1` MAC:

```text
e4:3a:6e:5d:a0:00
```

That told me the USW was actually negotiating LACP with OPNsense. The UDM also had `lagd` involved:

```text
Created LACP interface mapping: lacp6 -> eth6
LAG lag0: Interface mapping eth6 -> lacp6
Created LACP interface mapping: lacp7 -> eth7
LAG lag0: Interface mapping eth7 -> lacp7
LAG lag0: Switch port driver: RealtekTag, use_realtek_tag: false
```

The SSH details for the UDM interfaces showed Realtek switch abstractions:

```text
eth6@switch0:
  vlan protocol 802.1ad id 4088

eth7@switch0:
  vlan protocol 802.1ad id 4087

lacp6:
  rtk_sw_netdev

lacp7:
  rtk_sw_netdev
```

So the UDM Pro was not behaving like a simple Linux host with two Ethernet slaves under an `802.3ad` bond. It appeared to model LACP through UniFi's `lagd` and Realtek switch pseudo-interfaces. The Linux `lag0` object looked like a control-plane artefact, not the whole dataplane truth.

That was the debugging lesson: on appliance hardware, not every OS-level network interface is equally authoritative. The better sources of truth were:

- UniFi controller aggregate state
- USW `lacp_state`
- OPNsense `ACTIVE,COLLECTING,DISTRIBUTING`
- STP forwarding state
- packet counters moving without errors
- successful pings through the bridge

In this incident, the UDM `lag0 DOWN` output was suspicious, but not decisive.

## 5. Root-Cause Analysis: Following the Physical Evidence

The most useful UniFi historical lines came from the UDM `lagd` logs:

```text
lag0: eth7: carrier state is DOWN dropping received LACP PDU.
lag0: Failed to send PDU from eth6: Failed to write LACP data: Network is down (os error 100)
lag0: Failed to send PDU from eth7: Failed to write LACP data: Network is down (os error 100)
```

This is where the investigation stopped being abstract. LACP depends on LACPDUs exchanged between the actor and partner; the [Linux bonding documentation](https://www.kernel.org/doc/html/latest/networking/bonding.html) describes the LACPDU exchange used by `802.3ad` mode, and the UniFi FAQ describes LACP as the protocol that helps both ends agree on aggregation settings. If a device cannot send LACP PDUs because the interface is down, or if it drops received LACP PDUs because carrier is down, the aggregate cannot stay stable.

That is different from: `The two devices disagree about configuration`.
It is closer to: `The link is physically unstable enough that LACP control traffic cannot reliably move`.

That points toward physical-layer causes such as a bad cable, a bad termination, a damaged connector, marginal port, electrical noise or PHY/link partner issue. The USW counters supported the same direction. The aggregate ports had the worst link-down history:

```text
USW Port 7:
  link_down_count: 26
  tx_errors: 5
  tx_dropped: 5
  lag_member: true
  lacp_state: active

USW Port 8:
  link_down_count: 8
  lag_member: true
```

For comparison, several ordinary ports had much lower link-down counts:

```text
Port 1:  link_down_count 1
Port 2:  link_down_count 2
Port 3:  link_down_count 1
Port 9:  link_down_count 1
Port 11: link_down_count 1
Port 13: link_down_count 1
Port 14: link_down_count 1
```

Counters alone do not prove causality. Ports can accumulate link-down counts from normal reboots, unplugging, reprovisioning, or moving devices. But combined with OPNsense LACP distribution failures and UniFi carrier/PDU errors, they become strong supporting evidence.

There was also a reset/recovery window on the USW:

```text
2026-06-05 20:27:31 UTC
  USW-Lite-16-PoE adopted_at marker

2026-06-05 21:21:28 UTC
  switch disconnected

2026-06-05 21:22:13 UTC
  switch connected

2026-06-05 21:22:52 UTC
  switch provisioned

2026-06-05 21:23:05 UTC
  DHCPACK for USW-Lite-16-PoE, 192.168.1.21

2026-06-05 21:23:08 UTC
  controller state back ON
```

That lined up with OPNsense seeing final LAG detach events around:

```text
2026-06-05 21:22:28 UTC
2026-06-05 21:22:31 UTC
```

That distinction matters. The reset caused some link events. The earlier instability was the thing being investigated. This is also why I kept the OPNsense and UniFi timelines separate: link events created by a deliberate reset are not the same kind of evidence as repeated LACP distribution failures before the reset.

After replacing the OPNsense-to-USW cable pair and restoring the bridge, the state became boring again:

```text
igc1   up  1000baseT full-duplex
igc2   up  1000baseT full-duplex
igc4   up  1000baseT full-duplex
igc5   up  1000baseT full-duplex
lagg0  up
lagg1  up
bridge0 up
```

The expected evidence for a marginal cable pair would be:

```text
LACP member flaps on OPNsense egress LAG
USW aggregate ports show high link-down counts
UniFi logs show carrier down or LACP PDU failures
Symptoms are intermittent rather than hard-down
Replacing the cables restores stable LACP state
```

The observed evidence was:

```text
OPNsense lagg1 and igc4/igc5 flapped.
OPNsense logged "stopped DISTRIBUTING, possible flapping".
USW aggregate ports 7/8 had high link-down counts.
UDM lagd logged carrier-down and LACP PDU send failures.
After replacing the cable pair, OPNsense showed all members ACTIVE,COLLECTING,DISTRIBUTING.
USW showed both LACP members active.
Bridge forwarding and traffic counters looked normal.
```

That is a good match, although other possible causes still existed (like a bad physical port on the USW, bad physical port on the OPNsense box, UniFi LAG implementation bug triggered by reset/provisioning, transient controller reprovisioning issue, electrical noise near the cable run or two separate faults overlapping).

But the cable-pair theory was the simplest explanation that fit the observed data and the successful fix.

My final classification:

```text
Likely root cause:
  marginal/bad cable pair on the OPNsense-to-USW LACP bundle

Contributing factors:
  transparent bridge made symptoms appear wider than the failed segment
  LACP hashing made the failure intermittent rather than total
  UniFi's UDM LAG representation was misleading through /proc/net/bonding
  manual reset/bypass actions added extra log noise

Confirmed recovery condition:
  OPNsense LAG members active/collecting/distributing
  USW LACP state active
  bridge members forwarding
  packet counters moving without errors
  management reachability restored
```

Not absolute proof. Physical-layer incidents rarely hand you a signed confession. But the logs, counters, and recovery behavior all pointed in the same direction.

## 6. Commands, Checks, and Lessons

These were the commands and checks that mattered.

### OPNsense: check LACP state

```shell
ifconfig lagg0
ifconfig lagg1
```

Healthy output, matching the examples in the [FreeBSD handbook](https://docs.freebsd.org/en/books/handbook/advanced-networking/#network-aggregation):

```text
laggproto lacp
status: active
laggport: igc1 flags=<ACTIVE,COLLECTING,DISTRIBUTING>
laggport: igc2 flags=<ACTIVE,COLLECTING,DISTRIBUTING>
```

For the USW-facing side:

```text
laggport: igc4 flags=<ACTIVE,COLLECTING,DISTRIBUTING>
laggport: igc5 flags=<ACTIVE,COLLECTING,DISTRIBUTING>
```

### OPNsense: check the bridge

```shell
ifconfig bridge0
```

Healthy output. OPNsense's bridge documentation describes bridges as Layer 2 switching constructs with MAC learning, and optionally [RSTP/STP](https://docs.opnsense.org/manual/other-interfaces.html#bridge) to prevent loops:

```text
member: lagg1
  state forwarding

member: lagg0
  state forwarding
```

### OPNsense: watch logs during reconnection

```shell
tail -f /var/log/system/latest.log
```

Bad signs:

```text
lagg0: link state changed to DOWN
lagg1: link state changed to DOWN
Interface stopped DISTRIBUTING, possible flapping
igc4: link state changed to DOWN
igc5: link state changed to DOWN
```

### OPNsense: sample counters

```shell
netstat -I lagg0 -w 1
netstat -I lagg1 -w 1
```

Good signs:

```text
packets increasing
bytes increasing
errs 0
colls 0
```

### UDM: inspect UniFi's LAG surface

```shell
ip -d link show dev eth6
ip -d link show dev eth7
ip -d link show dev lacp6
ip -d link show dev lacp7
ip -d link show dev lag0
```

In this case, the relevant details were:

```text
eth6@switch0 UP
eth7@switch0 UP
lacp6 rtk_sw_netdev
lacp7 rtk_sw_netdev
lag0 bond mode balance-rr, no slaves, carrier 0
```

The lesson: do not panic at `lag0 DOWN` alone on the UDM Pro. It may not represent the actual hardware dataplane.

### UDM: inspect `lagd`

```shell
tail -n 160 /var/log/lagd.log
```

Bad lines:

```text
carrier state is DOWN dropping received LACP PDU
Failed to send PDU ... Network is down
Starting deconfiguration
Removing LACP interface
```

Normal lines:

```text
Created LACP interface mapping: lacp6 -> eth6
Created LACP interface mapping: lacp7 -> eth7
```

### UniFi controller API: inspect device port state

The controller view should agree with UniFi's [port aggregation model](https://help.ui.com/hc/en-us/articles/360007279753-Port-Aggregation-FAQs): sequential aggregate member ports, LACP rather than static LAG, and forwarding state on the aggregate.

For the USW:

```json
{
  "port_idx": 7,
  "op_mode": "aggregate",
  "aggregate_members": [7, 8],
  "lacp_state": [
    { "active": true, "member_port": 7, "speed": 1000 },
    { "active": true, "member_port": 8, "speed": 1000 }
  ],
  "partner_system_id": "e4:3a:6e:5d:a0:00",
  "stp_state": "forwarding"
}
```

For the UDM:

```json
{
  "port_idx": 7,
  "op_mode": "aggregate",
  "aggregate_members": [7, 8],
  "up": true,
  "speed": 1000
}
```

And port 8:

```json
{
  "port_idx": 8,
  "aggregated_by": 7,
  "masked": true,
  "up": true,
  "speed": 1000
}
```

### What to monitor after the fix

On OPNsense:

```text
status: active
all members ACTIVE,COLLECTING,DISTRIBUTING
```

On UniFi:

```text
lacp_state active on both members
stp_state forwarding
link_down_count not increasing
errors not increasing
drops not increasing
```

End-to-end:

```text
UDM can reach OPNsense management
OPNsense can reach the UDM gateway
clients keep stable DHCP/DNS
no VLAN-specific weirdness appears
```

The important thing is not the absolute historical counter value. Historical counters may already be dirty. The important thing is whether they continue increasing after the fix.

The lessons were simple:

- LACP instability often looks like general network weirdness.
- Link up is not enough; LACP member state matters.
- Appliance operating systems can hide the real dataplane behind strange abstractions.
- Label physical topology before you need to debug it under pressure.
- Replace suspect cables earlier than pride wants you to.

The technical explanation was deep. The fix was still copper.
