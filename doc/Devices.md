# Device Administration

## Profiles

(Device) Profile represents one particular hardware and all static settings in the
firmware, common for a group of devices. The configuration includes:
 * Reference to a particular Network
 * Ability of the device to perform ADR or provide battery status
 * Application (syntax and semantics of the frames)

For each Profile you can set:
 - **Name** of the profile.
 - **Network** for which are the devices in this profile configured.
 - **Application** the devices are using.
 - **App Identifier**, which is a custom application id.
 - **Can Join?** flag that allows you to prevent the device from joining.
 - **FCnt Check** to be used for this device
   - **Strict 16-bit** (default) or *Strict 32-bit* indicate a standard compliant counter.
   - **Reset on zero** behaves like a "less strict 16-bit", which allows personalised (ABP)
     devices to reset the counter.
     This weakens device security a bit as more reply attacks are possible.
   - **Disabled** disables the check for faulty devices.
     This destroys the device security.
 - **TX Window** to be used for downlinks to this device:
   - **Auto** to choose the earliest feasible option, either RX1 or RX2
   - **RX1** to always use the first RX window
   - **RX2** to always use the second RX window

In addition to that, each Profile may belong to one or more multicast channels.

### Adaptive Data Rate (ADR)

Transmissions (uplinks) of each node can use different transmission power, data
rate and channels (frequencies). Depending on the *ADR Mode* this can either be
manually defined by the administrator or automatically determined by the server.

Note this functionality must be also enabled in the device, which is indicated
by the *Use ADR* flag.

For each device Profile you can define "desired" ADR parameters:
 - **ADR Mode** determines the ADR mechanism for this device: Disabled, Auto-Adjust,
   or Maintain (see below);
 - **Set Power** defines the power (in dBm);
 - **Set Data Rate** defines the data rate;
 - **Max Data Rate** defines the maximal data rate supported by the devices;
 - **Set Channels** defines the set of channels. The channels are given
   as a comma-separated list of interfaces, e.g. `0-2` (for EU) or `0-71` (for US).
 - **Set RX1 DR Offset** defines the offset between the uplink and the RX1 slot
   downlink data rates
 - **Set RX2 DR** defines the data rate for the second reception slot (RX2).
 - **Set RX2 Freq** defines the default frequency in the RX2 receive window.
 - **Request Status** flag, which can be used to disable the status requests for
   simple devices that do not support it (by default true).

In all ADR modes the server will:

 * Assume that after reset or join the device uses the ADR settings defined by
   the initial Network ADR parameters.
 * Request the ADR change whenever the Node "Set" ADR parameters differ from
   the Node "Used" ADR parameters.
   * Upon success, the Node "Set" parameters will be cleared;
   * Upon failure, an error flag will be set and the ADR will be disabled until
     the flag gets cleared by the user.

#### Disabled

In this mode the server will never attempt to modify the Node "Set" ADR
parameters. User can then make individual changes to these parameters.

#### Auto-Adjust

When ADR Mode is *Auto-Adjust* and the Node "Used" ADR parameters didn't
change for the last 20 frames the server will automatically adjust the Node
"Set" ADR parameters depending on the uplink signal quality:
 * The *Data Rate* (Spreading Factor) is defined so that the LoRa demodulator SNR
   for the target *Data Rate* matches the observed average uplink SNR.
 * When the highest *Data Rate* is reached, the *Power* is decreased, so the
   RSSI stays above -100 dbB, which is an expected sensitivity for the highest rate.

When the "Used" *Power* and *Data Rate* parameters change, the 20 frames buffer
gets flushed and the server will wait for 20 frames more before any further
adjustment will be made.

At any time user can make individual changes to the Node "Set" parameters, but
after 20 frames the server may decide to change the parameters again.

#### Maintain

This mode is useful to manually control ADR parameters of a large group of
devices. In this mode the server will try to maintain the Profile "Set" ADR
parameters for all devices in the group.

Whenever the Node "Used" parameters will differ, the server will change the Node
"Set" ADR parameters to update the Node ADR back to the Profile "Set" parameters.

Individual changes to Node "Set" parameters shouldn't be made as the server will
always revert back to the Profile "Set" values.


## Commissioned

This list contains devices that can join the LoRaWAN network using the
over-the-air activation (OTAA). The active network nodes that either have
already joined or have been activated-by-personalization (ABP) are listed on the
[Nodes](Nodes.md) page.

For each device, which may connect to your network, you can set:
 - **DevEUI** of the device
 - **Profile** that this device uses
 - **App Arguments**, which is an opaque string with application-specific settings.
 - **AppEUI** and **AppKey**
 - **Last Join** is a timestamp of the last successful Join request.

Once the device joins the network, the *Node* field will contain a reference to the *Nodes* list.

To clone an existing device, simply save it under a different *DevEUI*.


## Activated Nodes

This list contains active network nodes that either have already joined the network
using the over-the-air activation (OTAA) or have been activated-by-personalization
(ABP). All devices that can join the network using OTAA are listed on the
[Devices](Devices.md) list.

![alt tag](https://raw.githubusercontent.com/gotthardp/lorawan-server/master/doc/images/admin-node.png)

For each active network Node you can set:
 - **DevAddr** of the node
 - **Profile** that this Node uses
 - **App Arguments**, which is an opaque string with application-specific settings.
 - **NwkSKey** and **AppSKey**
 - **FCnt Up** and **FCnt Down** frame counters
 - **Last Reset** indicates time of the last Join or reset
 - **Last RX** indicates time of the last uplink frame
 - **Device** shows a link to a corresponding Commissioned device
 - **Gateways** that received the last uplink frame

The **Downlinks** table contains frames created by the application, which are
scheduled for transmission. Class A devices listen for downlinks only for 2 seconds
after an uplink transmission, so it may take a while until all messages are
transmitted. Class C downlinks are not listed there as these are scheduled immediately.

To clone an existing node, simply save it under a different *DevAddr*.

### ADR

![alt tag](https://raw.githubusercontent.com/gotthardp/lorawan-server/master/doc/images/admin-adr.png)

Each Node follows the ADR Mode defined in the Device Profile (see above). The
Node ADR parameters include:
 - **ADR Support** indicates whether the node can do ADR;
 - **Set Power** defines the power (in dBm);
 - **Set Data Rate** defines the data rate;
 - **Set Channels** defines the set of channels. The channels are given
   as a comma-separated list of interfaces, e.g. `0-2` (for EU) or `0-71` (for US).
 - **Used Channels** indicates the set of channels used;
 - **ADR Failed** flag will indicate the device refused the last ADR command.
   The user is expected to resolve and clear this field before ADR will continue.
 - **Used RX1 DR Offset** indicates the offset used;
 - **Used RX2 DR** indicates the RX2 data rate used;
 - **Used RX2 Freq** indicates the RX2 frequency used (in MHz);
 - **RX Change Failed** flag will indicate the device refused the last command.

Below the configuration options you can monitor the performance of the node. You
can see the assumed ADR parameters and two graphs that display the last 50 received
frames.
 - **RX** graph indicates the device Power (dBm), Data Rate and Frequency (MHz);
 - **RX Quality** graph indicates the SNR (dB) and RSSI (dBm).

Note that the (Google) graphs will not be displayed when the Internet connectivity
is not available, e.g. in an isolated network.

### Status

This tab shows:
 - **Alerts** that may need your attention:
   * `battery_low` when the device battery is below 20% its capacity;
   * `downlink_noise` when the indicated D/L SNR is close to the sensitivity limit;
   * `many_resets` when the device sent multiple Join requests without sending
     any other frames.
 - **Status Time** and **Status FCnt** indicating when was the status last
   received by the server;
 - **Device Status** graph that shows the recent device **Battery** level (0-255)
   and the Signal-to-Noise-Ratio of received downlinks (**D/L SNR**).

The server requests the device status upon join or reset and then at given
time/fcnt intervals defined by the `devstat_gap` parameter. By default
`{devstat_gap, {432000, 96}}`, which requests the status every 5 days or
every 96 frames (whatever occurs first).

The server also requests device status when the ADR parameters change.


## Ignored Nodes

If two networks operate in the same area the server will receive frames from
devices using the other network. Each time such device sends a frame, the
`unknown_devaddr` error will be displayed.

To suppress warnings from a specific device, enter its *DevAddr* and
`FFFFFFFF` as the *Mask*.

To suppress warnings from all devices in a given network, enter a *DevAddr* of
one device and `FE000000` as the *Mask*. The 7 upper bits (MSB) match in the
address match the 7 lower bits (LSB) in the network identifier.
