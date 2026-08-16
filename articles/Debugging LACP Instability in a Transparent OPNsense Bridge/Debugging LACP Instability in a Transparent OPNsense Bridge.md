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

I run a [transparent OPNsense bridge](https://docs.opnsense.org/manual/other-interfaces.html#bridge) between a UniFi Dream Machine Pro and the rest of my LAN. It is deliberately boring at Layer 3. The UDM keeps routing, DHCP, DNS, firewall policy, WAN handling, and VLAN definitions. OPNsense sits inline as a Layer 2 bump in the wire.

The interesting part is that both sides of that bump use [LACP](https://www.ieee802.org/1/pages/802.1AX-rev.html).

I already wrote the build and configuration guide for this setup here. [Building a Transparent LAGG (LACP) Bridge with OPNsense, UDM, and UniFi - A Practical Guide](https://dev.to/andremmfaria/building-a-transparent-lagg-lacp-bridge-with-opnsense-udm-and-unifi-a-practical-guide-1d21). That article explains how the bridge was built, how the LAGG devices were configured, and why I wanted the firewall to remain transparent.

This article is the other half of the story. What happens when that kind of setup fails in a non-obvious way. Not a clean outage. Not a single network down moment. Just enough instability to make everything feel wrong.

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

- `ACTIVE` means the member is participating in the LACP bundle.
- `COLLECTING` means the member may receive traffic.
- `DISTRIBUTING` means the member may transmit traffic.

For an LACP link, carrier alone is not enough. A cable can show link, but if the member is not collecting and distributing, it is not a healthy participant in the aggregate.

In a transparent bridge, that distinction matters more than usual. OPNsense is not routing around the problem. It is forwarding Ethernet frames between two aggregated links, much like the [OPNsense bridge documentation](https://docs.opnsense.org/manual/other-interfaces.html#bridge) describes for Layer 2 forwarding and MAC learning. If one LACP member misbehaves, the symptoms can leak across the whole Layer 2 segment.

## 2. Symptoms and the LACP Trap

The failure did not present as a clean interruption. There was no single point where the whole LAN died and stayed dead. Instead, traffic slowed down, clients behaved inconsistently, management sessions became flaky, UniFi and OPNsense disagreed about state, and the bridge looked partially alive and partially broken.

With a single Ethernet cable, a physical failure is usually obvious. The link drops. The port goes down. The device disappears.

With LACP, a single member can become marginal while the logical aggregate still exists. Some traffic survives. Some traffic lands on the bad member. Some flows stall, some retry, and some keep working. The user-facing symptom becomes "the network is weird", which is among the least useful sentences in infrastructure.

The reason is hashing. LACP does not normally split one flow across all cables like a striped disk. The [FreeBSD handbook](https://docs.freebsd.org/en/books/handbook/advanced-networking/#network-aggregation) notes that Ethernet frame ordering means traffic between two stations stays on the same physical link, while the transmit algorithm tries to balance flows across the aggregate. In my OPNsense setup, the LAGG hash was Layer 2:

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

That creates a failure mode which feels like congestion, DNS trouble, Wi-Fi trouble, controller weirdness, or firewall slowness. The central trap is simple. Partial LACP failure can masquerade as general network degradation.

## 3. OPNsense Evidence That the Bundle Was Actually Flapping

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

## 4. UniFi Evidence and the UDM Trap

The UniFi side complicated the investigation because the UDM Pro did not expose this like a normal Linux LACP bond. UniFi's [Port Aggregation FAQ](https://help.ui.com/hc/en-us/articles/360007279753-Port-Aggregation-FAQs) says static LAG is not supported and aggregation uses LACP, while also calling out that gateway support is limited to specific models including the UDM Pro.

Over SSH, the UDM looked alarming:

```text
eth6@switch0 UP
eth7@switch0 UP
lacp6 LOWER_UP
lacp7 LOWER_UP
lag0 DOWN / NO-CARRIER
```

And `/proc/net/bonding/lag0` showed this:

```text
Ethernet Channel Bonding Driver: v3.7.1
Bonding Mode: load balancing (round-robin)
MII Status: down
```

For a normal [Linux bonding](https://www.kernel.org/doc/html/latest/networking/bonding.html) LACP bond, this would be terrible. I would expect `IEEE 802.3ad`, slave interfaces, MII up, aggregator details, and partner MAC information. That is not what the UDM showed.

The UniFi controller told a more coherent story. On the UDM, port 7 was the aggregate parent and port 8 was masked as a member. On the USW-Lite-16-PoE, ports 7 and 8 were both active LACP members, the aggregate was forwarding, and `partner_system_id` matched the OPNsense `lagg1` MAC:

```text
e4:3a:6e:5d:a0:00
```

The UDM also had `lagd` creating LACP interface mappings for `lacp6` and `lacp7`, while the interface details showed Realtek switch abstractions like `eth6@switch0`, `eth7@switch0`, and `rtk_sw_netdev` devices.

That was the debugging lesson. On appliance hardware, not every OS-level network interface is equally authoritative. The better sources of truth were UniFi controller aggregate state, USW `lacp_state`, OPNsense `ACTIVE,COLLECTING,DISTRIBUTING`, STP forwarding state, packet counters, and successful pings through the bridge. In this incident, the UDM `lag0 DOWN` output was suspicious, but not decisive.

## 5. Root-Cause Analysis

The most useful UniFi historical lines came from the UDM `lagd` logs:

```text
lag0: eth7: carrier state is DOWN dropping received LACP PDU.
lag0: Failed to send PDU from eth6: Failed to write LACP data: Network is down (os error 100)
lag0: Failed to send PDU from eth7: Failed to write LACP data: Network is down (os error 100)
```

This is where the investigation stopped being abstract. LACP depends on LACPDUs exchanged between the actor and partner. If a device cannot send LACP PDUs because the interface is down, or if it drops received LACP PDUs because carrier is down, the aggregate cannot stay stable.

That is different from `the two devices disagree about configuration`. It is closer to `the link is physically unstable enough that LACP control traffic cannot reliably move`.

The USW counters supported the same direction. The aggregate ports had the worst link-down history:

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

Several ordinary ports had much lower link-down counts. Counters alone do not prove causality, but combined with OPNsense LACP distribution failures and UniFi carrier/PDU errors, they became strong supporting evidence.

There was also a reset and recovery window on the USW. That lined up with final OPNsense LAG detach events around `21:22:28` and `21:22:31`. The distinction matters. Link events created by a deliberate reset are not the same kind of evidence as repeated LACP distribution failures before the reset.

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

The diagnosis was not absolute proof. Physical-layer incidents rarely hand you a signed confession. But the evidence lined up well. OPNsense saw `stopped DISTRIBUTING, possible flapping`, the USW aggregate ports had high link-down counts, UDM `lagd` logged carrier-down and PDU send failures, and replacing the cable pair restored stable LACP state.

My final classification was a likely marginal or bad cable pair on the OPNsense-to-USW LACP bundle. The transparent bridge made symptoms appear wider than the failed segment, LACP hashing made the failure intermittent rather than total, the UDM LAG representation added noise, and manual reset actions added extra log events.

## 6. Commands, Checks, and Lessons

These were the checks that mattered.

### OPNsense LACP state

```shell
ifconfig lagg0
ifconfig lagg1
```

Healthy output should show `status: active` and member ports with `ACTIVE,COLLECTING,DISTRIBUTING`, matching the examples in the [FreeBSD handbook](https://docs.freebsd.org/en/books/handbook/advanced-networking/#network-aggregation).

```text
laggproto lacp
status: active
laggport: igc1 flags=<ACTIVE,COLLECTING,DISTRIBUTING>
laggport: igc2 flags=<ACTIVE,COLLECTING,DISTRIBUTING>
```

### OPNsense bridge state

```shell
ifconfig bridge0
```

Healthy output should show both LAGG members forwarding, consistent with OPNsense's [bridge documentation](https://docs.opnsense.org/manual/other-interfaces.html#bridge).

```text
member: lagg1
  state forwarding

member: lagg0
  state forwarding
```

### OPNsense logs and counters

```shell
tail -f /var/log/system/latest.log
netstat -I lagg0 -w 1
netstat -I lagg1 -w 1
```

Bad signs are `lagg0` or `lagg1` link state changes, `Interface stopped DISTRIBUTING`, and repeated member link-down events. Good signs are increasing packets and bytes with no new errors.

### UniFi LAG surface

```shell
ip -d link show dev eth6
ip -d link show dev eth7
ip -d link show dev lacp6
ip -d link show dev lacp7
ip -d link show dev lag0
tail -n 160 /var/log/lagd.log
```

On the UDM Pro, do not panic at `lag0 DOWN` alone. In this case, the more useful signals were `lagd` carrier-down lines, failed PDU sends, and the UniFi controller view of aggregate members.

### UniFi controller state

The controller view should agree with UniFi's [port aggregation model](https://help.ui.com/hc/en-us/articles/360007279753-Port-Aggregation-FAQs). On the USW, look for active LACP members, the expected `partner_system_id`, and `stp_state` set to forwarding. On the UDM, look for the aggregate parent port and the masked member port.

### After the fix

Monitor OPNsense, UniFi, and end-to-end reachability. OPNsense should show active LACP members that collect and distribute. UniFi should show active LACP state, forwarding STP state, and counters that stop increasing after the fix. End-to-end checks should confirm UDM to OPNsense reachability, OPNsense to gateway reachability, stable DHCP and DNS, and no VLAN-specific weirdness.

The important thing is not the absolute historical counter value. Historical counters may already be dirty. The important thing is whether they continue increasing after the fix.

The lessons were simple:

- LACP instability often looks like general network weirdness.
- Link up is not enough. LACP member state matters.
- Appliance operating systems can hide the real dataplane behind strange abstractions.
- Label physical topology before you need to debug it under pressure.
- Replace suspect cables earlier than pride wants you to.

The technical explanation was deep. The fix was still copper.
