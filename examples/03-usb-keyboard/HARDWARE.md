# USB HID Keyboard - Hardware Connections

## Tang Nano 9K to USB Type-A Male Plug

```
Tang Nano 9K                    USB Type-A Male Plug
┌─────────────┐                 ┌───────────────────┐
│             │                 │                   │
│  pin 27 ───┼─── 1.5kΩ ──────┼─── D+ (pin 3)     │
│             │                 │                   │
│  pin 25 ───┼─── 22Ω ────────┼─── D+ (pin 3)     │
│             │                 │                   │
│  pin 26 ───┼─── 22Ω ────────┼─── D- (pin 2)     │
│             │                 │                   │
│  GND ───────┼────────────────┼─── GND (pin 4)    │
│             │                 │                   │
│  3.3V ──────┼─── 1kΩ ───────┼─── VBUS (pin 1)   │
│             │                 │                   │
└─────────────┘                 └───────────────────┘
```

## Pin Assignments

| FPGA Pin | Signal     | Direction | Notes                              |
|----------|------------|-----------|------------------------------------|
| 25       | usb_dp     | Bidir     | USB D+ data line (Bank 2, 3.3V)   |
| 26       | usb_dn     | Bidir     | USB D- data line (Bank 2, 3.3V)   |
| 27       | usb_dp_pull| Output    | D+ pull-up control (Bank 2, 3.3V) |
| 52       | clk_27mhz  | Input     | 27MHz on-board oscillator          |
| 3        | btn        | Input     | User button (active-low)           |
| 10       | led        | Output    | USB connected indicator            |

## Schematic

```
                           Tang Nano 9K
                        ┌───────────────┐
                        │               │
              3.3V ─────┤               │
                │       │               │
               [1kΩ]    │               │
                │       │               │
USB VBUS ───────┴───────┤               │
                        │               │
USB D+ ──────┬──────────┤ pin 25        │
             │          │               │
            [22Ω]       │               │
             │          │               │
            [1.5kΩ]     │               │
             │          │               │
USB D- ──┬───┴──────────┤ pin 26        │
         │              │               │
        [22Ω]           │               │
         │              │               │
USB GND ─┼──────────────┤ GND           │
         │              │               │
        GND             │               │
                        │  pin 27 ──────┤── 1.5kΩ ── USB D+
                        │               │
                        └───────────────┘

Optional protection (recommended):
USB D+ ──┬── 3.6V Zener (cathode) ── GND
USB D- ──┬── 3.6V Zener (cathode) ── GND
```

## Bill of Materials

| Component | Value  | Quantity | Notes                        |
|-----------|--------|----------|------------------------------|
| Resistor  | 1.5kΩ  | 1        | D+ pull-up to 3.3V           |
| Resistor  | 22Ω    | 2        | Series resistors for D+/D-   |
| Resistor  | 1kΩ    | 1        | VBUS detect (optional)        |
| Zener     | 3.6V   | 2        | Overvoltage protection (optional) |
| Connector | USB Type-A male | 1 | Cut cable or breakout board   |

## Quick Start (Minimal)

For first test, only 3 resistors needed:

```
pin 27 ── 1.5kΩ ── USB D+
pin 25 ── 22Ω ──── USB D+
pin 26 ── 22Ω ──── USB D-
GND ────────────── USB GND
```

## Programming

```bash
openFPGALoader -b tangnano9k build/usb-keyboard-tangnano9k.fs
```

## Testing

1. Build: `make -C boards/tangnano9k TOP=usb-keyboard-tangnano9k -B`
2. Program: `openFPGALoader -b tangnano9k build/usb-keyboard-tangnano9k.fs`
3. Connect USB Type-A male plug to host PC
4. LED on pin 10 should light up (USB connected)
5. Host should enumerate as HID keyboard
6. Keyboard will auto-press keys a-z, 0-9 every 2 seconds

## Notes

- Pins 25-27 are in Bank 2 (3.3V LVCMOS33), fully unconnected GPIO with no
  onboard peripheral conflicts.
- Pins 17-18 are shared with the BL702 UART bridge and should be avoided for
  soft USB to prevent bus contention.
- Pin 20 is VCCFlash (power pin), not a GPIO — do not use for I/O.
