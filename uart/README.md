# UART Transmitter & Receiver

A parameterised UART implementation written in SystemVerilog, with self-checking simulation testbenches for both the transmitter (TX) and receiver (RX).

This project was built to develop practical understanding of synchronous RTL design, finite-state machines, baud-rate timing, clock-domain crossing (CDC), metastability mitigation, serial/parallel data conversion, assertions, and waveform-based debugging.

## Features

* Parameterised clock frequency, baud rate, and data width
* UART transmitter

  * Start, data, and stop bit generation
  * LSB-first transmission
  * `busy` status signal
  * Input data captured when transmission begins
* UART receiver

  * Start-bit detection and validation
  * LSB-first reception
  * 2-flop synchroniser for the asynchronous RX input
  * Half-bit sampling for start-bit validation
  * Centre-of-bit sampling for received data
  * Stop-bit validation
  * `data_valid` indication
* Self-checking SystemVerilog testbenches
* Assertions for functional verification
* VCD waveform generation
* Waveform inspection using GTKWave

---

## Project Structure

```text
uart/
├── rtl/
│   ├── uart_tx.sv
│   └── uart_rx.sv
│
├── tb/
│   ├── uart_tx_tb.sv
│   └── uart_rx_tb.sv
│
└── sim/
    ├── uart_tx.vcd
    └── uart_rx.vcd
```

---

## UART Protocol

The implementation uses a standard asynchronous UART frame consisting of:

```text
Idle     Start       Data (LSB first)       Stop
  1         0          D0 D1 ... D7           1
  ────────┐   ┌──────────────────────────┐   ┌──────
          └───┘                          └───┘
```

For the default `DATA_WIDTH = 8`, each frame contains:

* 1 start bit (`0`)
* 8 data bits
* 1 stop bit (`1`)
* No parity bit

Data is transmitted and received **least-significant bit first**.

---

# UART Transmitter

## Interface

| Signal     | Direction | Description               |
| ---------- | --------- | ------------------------- |
| `clk`      | Input     | System clock              |
| `reset`    | Input     | Synchronous reset         |
| `data_in`  | Input     | Parallel data to transmit |
| `tx_start` | Input     | Starts a transmission     |
| `tx`       | Output    | Serial UART output        |
| `busy`     | Output    | High while transmitting   |

## Operation

When `tx_start` is asserted while the transmitter is idle, `data_in` is captured into an internal register.

The transmitter then progresses through the following states:

```text
IDLE → START → DATA → STOP → IDLE
```

The serial output is determined by the current state:

```text
IDLE   → 1
START  → 0
DATA   → tx_data[bit_count]
STOP   → 1
```

The transmitter uses a baud counter to generate a tick every `CLKS_PER_BIT` system-clock cycles.

The data counter advances on each baud tick, causing the next serial data bit to be presented.

### `busy`

The transmitter exposes a `busy` signal:

```systemverilog
assign busy = (state != IDLE);
```

Therefore:

* `busy = 0` when the transmitter is idle
* `busy = 1` during the start, data, and stop portions of a transmission

External logic can use this signal to determine when another transmission can be started.

---

# UART Receiver

## Interface

| Signal       | Direction | Description                      |
| ------------ | --------- | -------------------------------- |
| `clk`        | Input     | System clock                     |
| `reset`      | Input     | Synchronous reset                |
| `rx`         | Input     | Asynchronous UART input          |
| `data_out`   | Output    | Received parallel data           |
| `data_valid` | Output    | Indicates a valid received frame |

## Clock-Domain Crossing

The external `rx` signal is asynchronous relative to the receiver's `clk` domain.

A two-flop synchroniser is therefore used:

```text
rx
 │
 ▼
┌─────────┐
│ rx_meta │
└────┬────┘
     │
     ▼
┌─────────┐
│ rx_sync │
└────┬────┘
     │
     ▼
 RX logic
```

The first flip-flop can become metastable if the asynchronous input changes close to a clock edge.

The second flip-flop gives the metastability time to resolve before the signal is used by the rest of the receiver.

The synchroniser therefore **does not eliminate metastability**. Instead, it makes the probability of metastability propagating into the receiving logic extremely small.

The associated two-clock-cycle latency is acceptable because the UART input is asynchronous and the receiver performs its timing relative to the synchronised signal.

---

## Receiver State Machine

The receiver uses four states:

```text
IDLE
START
DATA
STOP
```

with the following general flow:

```text
          rx_sync = 0
IDLE ──────────────────► START
                          │
                    half-bit sample
                          │
                    valid start bit
                          ▼
                         DATA
                          │
                    all bits received
                          ▼
                         STOP
                          │
                     stop-bit sample
                          │
                          ▼
                         IDLE
```

### Start-Bit Detection

UART remains high while idle.

When `rx_sync` becomes low, the receiver assumes that a start bit may have begun and enters the `START` state.

Rather than immediately accepting the bit, the receiver waits for half a bit period:

```text
Start bit
0────────────────────────0
          ▲
          │
     sample here
      half-bit
```

At this point:

* If `rx_sync` is still low, the start bit is accepted.
* If `rx_sync` has returned high, the start bit is rejected.

This prevents short glitches or pulses on the RX line from being interpreted as valid UART frames.

---

## Data Sampling

Once a valid start bit has been confirmed, the receiver enters `DATA`.

The receiver samples the input once per bit period.

The sampled data is shifted into `data_out`:

```systemverilog
data_out <= {rx_sync, data_out[DATA_WIDTH-1:1]};
```

Since UART transmits the least-significant bit first, this shift operation reconstructs the original parallel value.

For example:

```text
Transmitted:

D0 → D1 → D2 → D3 → D4 → D5 → D6 → D7

Received shift register:

D0
D1 D0
D2 D1 D0
...
D7 D6 D5 D4 D3 D2 D1 D0
```

Result:

```text
data_out = D7 D6 D5 D4 D3 D2 D1 D0
```

---

## Stop-Bit Validation

After receiving all data bits, the receiver enters `STOP`.

A valid UART stop bit must be high.

`data_valid` is therefore only asserted when the receiver reaches the end of the stop bit and `rx_sync` is high:

```systemverilog
assign data_valid = (state == STOP && baud_tick && rx_sync);
```

An invalid stop bit does not produce a valid-data indication.

---

# Baud-Rate Generation

Both TX and RX derive the number of system-clock cycles per UART bit from:

```text
CLKS_PER_BIT = CLOCK_FREQ / BAUD_RATE
```

For the simulation testbenches:

```text
CLOCK_FREQ = 10 MHz
BAUD_RATE  = 1 MHz

CLKS_PER_BIT = 10
```

The RX additionally calculates:

```text
HALF_CLKS_PER_BIT = CLKS_PER_BIT / 2
```

which is used to sample the start bit approximately halfway through its duration.

### Timing Example

With `CLKS_PER_BIT = 10`:

```text
System clock:

↑   ↑   ↑   ↑   ↑   ↑   ↑   ↑   ↑   ↑
|<----------- 10 clock cycles ----------->|

UART bit:

┌─────────────────────────────────────────┐
│                  1 bit                  │
└─────────────────────────────────────────┘
                    ▲
                    │
              centre sample
```

The design currently uses integer division when calculating `CLKS_PER_BIT`, so the achievable baud-rate accuracy depends on the relationship between the system clock frequency and requested baud rate.

---

# Verification

Both modules have dedicated self-checking SystemVerilog testbenches.

The testbenches use:

* SystemVerilog tasks
* Assertions
* Clock-driven stimulus
* Automated data checking
* VCD waveform generation
* GTKWave waveform inspection

The intention is to verify the behaviour of the RTL automatically rather than relying solely on visual waveform inspection.

---

## TX Verification

The TX testbench verifies:

### Reset and Idle

* TX is high while idle
* TX is not busy after reset
* Reset returns the transmitter to `IDLE`

### Start Bit

After `tx_start`:

* `busy` becomes high
* TX outputs a low start bit

### Data Transmission

The testbench checks:

* Correct first data bit
* Correct transmission of all data bits
* LSB-first ordering
* Correct baud timing

For example:

```text
data_in = 1010_0110
```

is checked bit-by-bit against the serial TX output.

### Stop Bit

The testbench verifies:

* Stop bit is high
* TX remains busy during the stop bit
* TX returns to the idle state afterwards
* TX remains high in idle

### Continuous Operation

Back-to-back transmissions are tested to ensure that the transmitter can begin a new frame immediately after completing the previous one.

### Reset During Transmission

Reset is also asserted in the middle of an active transmission.

The testbench verifies that the transmitter immediately returns to the expected idle state:

```text
tx   = 1
busy = 0
```

---

# RX Verification

The RX testbench verifies:

### Reset

After reset:

* `data_out` is zero
* `data_valid` is not asserted
* RX returns to `IDLE`

### Invalid Start Bit

A start pulse shorter than half a bit period is generated.

The receiver must reject it and must not produce:

```text
data_valid
```

The testbench also verifies that `data_out` remains unchanged.

### Valid Start Bit

A valid low start bit is generated and the receiver's behaviour is inspected in GTKWave.

This verifies the relationship between:

```text
rx
rx_meta
rx_sync
half_baud_tick
state
```

---

## Data Pattern Testing

Several data patterns are tested:

```text
1010_0101
0000_0000
1111_1111
0101_1010
0000_0001
1000_0000
```

These patterns provide coverage of:

* All zeros
* All ones
* Alternating bits
* LSB-only data
* MSB-only data

The LSB-only and MSB-only patterns are particularly useful for detecting incorrect bit ordering or shifting behaviour.

---

## Back-to-Back Frames

The receiver is tested with consecutive frames without resetting the receiver between them.

For example:

```text
B2 → 5C
```

This verifies that the receiver can correctly transition from:

```text
STOP → IDLE → START → DATA
```

and process a new frame immediately after the previous one.

---

## Consecutive Identical Frames

The receiver is also tested with multiple identical frames:

```text
09 → 09 → 09 → 09
```

and:

```text
10 → 10 → 10 → 10 → 10 → 10 → 10
```

This ensures that the receiver can continuously process frames even when the data contents do not change between frames.

---

## Invalid Stop Bit

Frames with an invalid low stop bit are deliberately generated.

The expected behaviour is:

```text
START → DATA → invalid STOP
```

without asserting:

```text
data_valid
```

Multiple data patterns are tested to ensure that the invalid-stop behaviour is independent of the received data.

---

# Waveform Analysis

Simulation produces VCD files in the `sim/` directory.

The RX waveform is particularly useful for examining:

```text
rx
rx_meta
rx_sync
count
baud_tick
half_baud_tick
state
next_state
bit_count
data_out
data_valid
```

The waveforms allow the relationship between the asynchronous input, synchroniser, FSM, baud counter, and sampling points to be inspected at clock-cycle level.

For example, the RX waveform demonstrates:

```text
Asynchronous RX
      │
      ▼
  Synchroniser
      │
      ▼
Start detection
      │
      ▼
Half-bit validation
      │
      ▼
Data sampling
      │
      ▼
Stop-bit validation
      │
      ▼
data_valid
```

This was used alongside the self-checking testbench to understand and verify the internal operation of the receiver.

---

# Design Limitations

This project is intended as a learning and RTL-design project rather than production UART IP.

Current limitations and assumptions include:

* `CLOCK_FREQ / BAUD_RATE` uses integer division.
* Very small parameter values require additional care when using `$clog2`.
* The implementation assumes one start bit, no parity, and one stop bit.
* The receiver uses a two-flop synchroniser for the single-bit asynchronous RX input.
* No hardware flow control is implemented.
* No parity generation or checking is implemented.
* No configurable number of stop bits is implemented.
* Parameterisation and more extensive timing/edge-case verification could be expanded in future versions.

---

# Tools

The project was developed using:

* **SystemVerilog**
* **Verilator**
* **GTKWave**

Verilator is used for RTL simulation and automated assertion checking, while GTKWave is used for detailed waveform inspection.

---

# Key Concepts Demonstrated

This project demonstrates practical experience with:

* Synchronous RTL design
* Finite-state machines
* Parameterised SystemVerilog
* Clock/baud-rate counters
* Serial-to-parallel conversion
* Parallel-to-serial conversion
* UART framing
* Clock-domain crossing
* Metastability mitigation
* Two-flop synchronisers
* Timing-based sampling
* SystemVerilog assertions
* Self-checking testbenches
* Testbench tasks
* Continuous frame processing
* Error-condition testing
* VCD generation
* Waveform debugging with GTKWave

The project focuses on understanding **why the RTL works**, not just producing a functioning UART.
