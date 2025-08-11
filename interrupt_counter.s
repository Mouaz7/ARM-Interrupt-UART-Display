\
/*
 * interrupt_counter.s
 * ARM assembly: IRQ buttons + UART polling + 7-seg display update.
 * Reconstructed faithfully from the provided PDF, with comments in English.
 *
 * Vectors at 0x00; IRQ = buttons (ID 73). Main loop polls UART for 'u'/'d' and updates display.
 */

    .text

/* ----------------------------
 * Exception Vector Table
 * ---------------------------- */
    .org 0x00
    B _start            /* Reset */
    B SERVICE_UND       /* Undefined */
    B SERVICE_SVC       /* SVC */
    B SERVICE_ABT_INST  /* Prefetch abort */
    B SERVICE_ABT_DATA  /* Data abort */
    .word 0             /* Reserved */
    B SERVICE_IRQ       /* IRQ */
    .word 0             /* FIQ (unused) */

    .global _start

/* ----------------------------
 * Boot / mode setup
 * ---------------------------- */
_start:
    /* Switch to IRQ mode, disable IRQ/FIQ, set IRQ stack. */
    MSR CPSR_c, #0b11010010
    LDR SP, =IRQ_MODE_STACK_BASE

    /* Switch to SVC mode (supervisor), disable IRQ/FIQ, set SVC stack. */
    MSR CPSR_c, #0b11010011
    LDR SP, =SVC_MODE_STACK_BASE

    /* Configure GIC for button interrupt (Interrupt ID = 73). */
    MOV R0, #73
    BL CONFIG_GIC

    /* Enable button interrupts in the button interrupt mask register (buttons 0 and 1). */
    LDR R0, =BTN_INT_MASK_REG
    MOV R1, #0b11
    STR R1, [R0]

    /* Clear edge-capture to discard stale button presses. */
    LDR R0, =BTN_EDGE_REG
    MOV R1, #0b11
    STR R1, [R0]

    /* Enable IRQ in SVC mode (set I=0, keep F=1). */
    MSR CPSR_c, #0b01010011

    B _main

/* ----------------------------
 * Main loop: poll UART + update display
 * ---------------------------- */
_main:
    BL POLL_UART          /* Reads key from UART: 'u' => up, 'd' => down */
    BL UPDATE_DISPLAY     /* Writes current counter value to the 7-seg display */
    B _main

/* ----------------------------
 * IRQ Handler
 * ---------------------------- */
SERVICE_IRQ:
    PUSH {R0-R7, LR}

    /* Read ICCIAR to get the interrupt ID. */
    LDR R4, =GIC_CPU_INTERFACE_BASE
    LDR R5, [R4, #0x0C]

    /* If not button interrupt (ID=73), finish. */
    CMP R5, #73
    BNE SERVICE_IRQ_DONE

    BL HANDLE_BUTTON_INTERRUPT

SERVICE_IRQ_DONE:
    /* Write ICCEOIR to acknowledge end of interrupt. */
    STR R5, [R4, #0x10]
    POP {R0-R7, LR}
    SUBS PC, LR, #4        /* Return from IRQ */

/* ----------------------------
 * Button ISR body
 * ---------------------------- */
HANDLE_BUTTON_INTERRUPT:
    /* Read edge-capture: which button triggered? */
    LDR R0, =BTN_EDGE_REG
    LDR R1, [R0]

    TST R1, #0b01          /* Button 0 => count down */
    BNE COUNT_DOWN

    TST R1, #0b10          /* Button 1 => count up */
    BNE COUNT_UP

BUTTON_DONE:
    /* Clear both edge bits. */
    LDR R0, =BTN_EDGE_REG
    MOV R1, #0b11
    STR R1, [R0]
    BX LR

/* ----------------------------
 * Counter operations (mod 16)
 * ---------------------------- */
COUNT_UP:
    LDR R0, =counter
    LDR R1, [R0]
    ADD R1, R1, #1
    AND R1, R1, #0xF       /* keep in range 0..15 */
    STR R1, [R0]
    B BUTTON_DONE

COUNT_DOWN:
    LDR R0, =counter
    LDR R1, [R0]
    SUB R1, R1, #1
    AND R1, R1, #0xF       /* keep in range 0..15 */
    STR R1, [R0]
    B BUTTON_DONE

/* ----------------------------
 * UART polling: 'u' => up, 'd' => down
 * ---------------------------- */
POLL_UART:
    /* RVALID bit is bit 15 (0x8000) in UART data register on this platform. */
    LDR R0, =UART_DATA_REGISTER
    LDR R1, [R0]
    ANDS R2, R1, #0x8000    /* any data available? */
    BEQ POLL_UART_DONE

    /* Extract the byte and act on 'u'/'d'. */
    AND R1, R1, #0xFF
    CMP R1, #'u'
    BEQ COUNT_UP
    CMP R1, #'d'
    BEQ COUNT_DOWN

POLL_UART_DONE:
    BX LR

/* ----------------------------
 * Update 7-segment display
 * ---------------------------- */
UPDATE_DISPLAY:
    LDR R0, =counter
    LDR R1, [R0]
    LDR R2, =hex_digits
    ADD R2, R2, R1          /* byte table, direct index */
    LDRB R3, [R2]
    LDR R0, =DISPLAY_BASE
    STR R3, [R0]
    BX LR

/* ----------------------------
 * GIC configuration helpers
 * ---------------------------- */
CONFIG_GIC:
    /* Map interrupt ID in R0 to CPU target R1 (here R1=1), enable CPU IF and distributor. */
    PUSH {LR}
    MOV R1, #1
    BL CONFIG_INTERRUPT

    /* Permit all priorities, enable CPU interface. */
    LDR R0, =GIC_CPU_INTERFACE_BASE
    LDR R1, =0xFFFF
    STR R1, [R0, #0x04]
    MOV R1, #1
    STR R1, [R0]

    /* Enable distributor. */
    LDR R0, =GIC_DISTRIBUTOR_BASE
    STR R1, [R0]
    POP {PC}

CONFIG_INTERRUPT:
    /* Program enable set register and CPU target for given interrupt ID in R0. */
    PUSH {R4-R5, LR}

    /* Calculate enable-set register address: 0xFFFED100 + (ID/32)*4; set bit (ID%32). */
    LSR R4, R0, #3
    BIC R4, R4, #3
    LDR R2, =0xFFFED100
    ADD R4, R2, R4
    AND R2, R0, #0x1F
    MOV R5, #1
    LSL R2, R5, R2
    LDR R3, [R4]
    ORR R3, R3, R2
    STR R3, [R4]

    /* CPU target register: 0xFFFED800 + ID/4; byte select by (ID%4). */
    BIC R4, R0, #3
    LDR R2, =0xFFFED800
    ADD R4, R2, R4
    AND R2, R0, #0x3
    ADD R4, R2, R4
    STRB R1, [R4]

    POP {R4-R5, PC}

/* ----------------------------
 * Stub handlers (unused)
 * ---------------------------- */
SERVICE_UND:      B SERVICE_UND
SERVICE_SVC:      B SERVICE_SVC
SERVICE_ABT_INST: B SERVICE_ABT_INST
SERVICE_ABT_DATA: B SERVICE_ABT_DATA

/* ----------------------------
 * MMIO base addresses and constants
 * ---------------------------- */
    .equ BTN_BASE,               0xFF200050
    .equ BTN_INT_MASK_REG,       BTN_BASE + 0x08
    .equ BTN_EDGE_REG,           BTN_BASE + 0x0C

    .equ LED_BASE,               0xFF200000
    .equ DISPLAY_BASE,           0xFF200020

    .equ GIC_CPU_INTERFACE_BASE, 0xFFFEC100
    .equ GIC_DISTRIBUTOR_BASE,   0xFFFED000

    .equ UART_DATA_REGISTER,     0xFF201000
    .equ UART_CONTROL_REGISTER,  0xFF201004

    .equ IRQ_MODE_STACK_BASE,    0xFFFFFFFF - 3
    .equ SVC_MODE_STACK_BASE,    0x3FFFFFFF - 3

/* ----------------------------
 * Data
 * ---------------------------- */
    .data
hex_digits:
    .byte 0x3F,0x06,0x5B,0x4F,0x66,0x6D,0x7D,0x07,0x7F,0x6F
    .byte 0x77,0x7C,0x39,0x5E,0x79,0x71   /* A..F */

counter: .word 0x0
