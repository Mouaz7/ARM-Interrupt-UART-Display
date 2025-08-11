# ARM-Interrupt-UART-Display

ARM Cortex-A9 assembly project that handles button interrupts, reads UART commands, and updates a 7-segment display.

## Overview

This project demonstrates an event-driven embedded application written entirely in ARM assembly. It features:

- **Button Interrupts (IRQ)** — Increment or decrement a counter using physical buttons (ID 73 in the GIC).
- **UART Polling** — Adjust the counter by sending 'u' (up) or 'd' (down) via a UART terminal.
- **7-Segment Display Update** — Display the current counter value (0–F) on a 7-segment display using a lookup table.
- **Recursive & Modular Code Structure** — Clear separation of interrupt handling, polling, and display update.

## Memory Map (Platform-specific)

| Peripheral        | Base Address   | Notes                              |
|-------------------|----------------|------------------------------------|
| Buttons           | 0xFF200050     | INT_MASK_OFF=+0x08, EDGE_OFF=+0x0C |
| Display           | 0xFF200020     |                                    |
| UART Data         | 0xFF201000     | Bit 15 (0x8000) = RVALID           |
| UART Control      | 0xFF201004     |                                    |
| GIC CPU IF        | 0xFFFEC100     | ICCIAR=+0x0C, ICCEOIR=+0x10        |
| GIC Distributor   | 0xFFFED000     |                                    |
| IRQ Stack Base    | 0xFFFFFFFF-3   |                                    |
| SVC Stack Base    | 0x3FFFFFFF-3   |                                    |

> Make sure these addresses match your hardware.

## Build Instructions

Requires an ARM toolchain such as `arm-none-eabi` and an ARM Cortex-A9 platform (e.g., DE1-SoC).

```bash
# Assemble
arm-none-eabi-as -mcpu=cortex-a9 -o interrupt_counter.o interrupt_counter.s

# Link
arm-none-eabi-ld -Ttext=0x0 -o interrupt_counter.elf interrupt_counter.o

# Convert to binary (optional)
arm-none-eabi-objcopy -O binary interrupt_counter.elf interrupt_counter.bin
```

## Run Instructions

1. Load the ELF/BIN onto your board or emulator.
2. Open a UART terminal connected to the board.
3. Press:
   - **Button 0** — Decrement counter
   - **Button 1** — Increment counter
   - **'u'** via UART — Increment counter
   - **'d'** via UART — Decrement counter
4. The 7-segment display will update with the current counter value in hex.

## Example Output

On the 7-segment display:
```
0, 1, 2, ... 9, A, b, C, d, E, F
```

## License

This project is released under the MIT License.
