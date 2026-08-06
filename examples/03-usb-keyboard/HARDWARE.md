# USB HID Keyboard - Hardware Connections

## Tang Nano 9K to USB Type-A Male Plug

```
Tang Nano 9K                    USB Type-A Male Plug
┌─────────────┐                 ┌───────────────────┐
│             │                 │                   │
│  pin 17 ───┼─── 1.5kΩ ──────┼─── D+ (pin 3)     │
│             │                 │                   │
│  pin 19 ───┼─── 22Ω ────────┼─── D+ (pin 3)     │
│             │                 │                   │
│  pin 18 ───┼─── 22Ω ────────┼─── D- (pin 2)     │
│             │                 │                   │
│  GND ───────┼────────────────┼─── GND (pin 4)    │
│             │                 │                   │
│  3.3V ──────┼─── 1kΩ ───────┼─── VBUS (pin 1)   │
│             │                 │                   │
└─────────────┘                 └───────────────────┘
```

## Pin Assignments

| FPGA Pin | Signal     | Direction | Notes                        |
|----------|------------|-----------|------------------------------|
| 17       | usb_dp_pull| Output    | D+ pull-up control           |
| 18       | usb_dn     | Bidir     | USB D- data line             |
| 19       | usb_dp     | Bidir     | USB D+ data line             |
| 52       | clk_27mhz  | Input     | 27MHz on-board oscillator    |
| 3        | btn        | Input     | User button (active-low)     |
| 10       | led        | Output    | USB connected indicator      |

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
USB D+ ──────┬──────────┤ pin 19        │
             │          │               │
            [22Ω]       │               │
             │          │               │
            [1.5kΩ]     │               │
             │          │               │
USB D- ──┬───┴──────────┤ pin 18        │
         │              │               │
        [22Ω]           │               │
         │              │               │
USB GND ─┼──────────────┤ GND           │
         │              │               │
        GND             └───────────────┘

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
pin 17 ── 1.5kΩ ── USB D+
pin 19 ── 22Ω ──── USB D+
pin 18 ── 22Ω ──── USB D-
GND ────────────── USB GND
```

## Programming

```bash
openFPGALoader -b tangnano9k build/usb_keyboard.fs
```

## Testing

1. Build: `make -C boards/tangnano9k DESIGN=examples/03-usb-keyboard/usb-keyboard.lisp`
2. Program: `openFPGALoader -b tangnano9k build/usb_keyboard.fs`
3. Connect USB Type-A male plug to host PC
4. LED on pin 10 should light up (USB connected)
5. Host should enumerate as HID keyboard
6. Keyboard will auto-press keys a-z, 0-9 every 2 seconds
