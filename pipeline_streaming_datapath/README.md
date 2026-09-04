# Pipelined Streaming Arithmetic Datapath

A parameterised 3-stage SystemVerilog streaming arithmetic datapath implementing

$$
y = (x + A) \times B + C
$$

The design uses a **ready/valid streaming interface**, allowing transactions to be processed continuously at **one transaction per clock cycle** once the pipeline is full. Backpressure propagates through the pipeline so that the entire datapath can safely stall when the downstream consumer is unable to accept data.

The project focuses on practical RTL concepts including pipelining, throughput vs. latency, ready/valid handshaking, backpressure, datapath sizing, and self-checking verification.

## Features

* Parameterised input data width
* Parameterised arithmetic constants `A`, `B`, and `C`
* 3-stage arithmetic pipeline
* Ready/valid streaming interface
* Full pipeline backpressure support
* 3-cycle pipeline latency
* 1 transaction/cycle throughput after pipeline fill
* Explicit datapath width management
* Self-checking SystemVerilog testbench
* Reference-model FIFO for transaction ordering
* Verification of reset, continuous streaming, and pipeline stalls
* Waveform generation for inspection with GTKWave
* Designed to be synthesizable SystemVerilog

---

## Architecture

The datapath implements:

```text
                 ┌────────────┐
in_data ────────►│   Stage 0  │
                 │    x + A   │
                 └─────┬──────┘
                       │
                       ▼
                 ┌────────────┐
                 │   Stage 1  │
                 │     × B    │
                 └─────┬──────┘
                       │
                       ▼
                 ┌────────────┐
                 │   Stage 2  │
                 │    + C     │
                 └─────┬──────┘
                       │
                       ▼
                    out_data
```

Each stage contains a register boundary, allowing the arithmetic operations to be distributed across multiple clock cycles.

The resulting pipeline has:

* **Latency:** 3 clock cycles
* **Maximum throughput:** 1 transaction per clock cycle

For example, after the pipeline has filled:

```text
Clock       Stage 0       Stage 1       Stage 2
------------------------------------------------
1           A5
2           3C            A5
3           7F            3C            A5
4           12            7F            3C
5           E1            12            7F
```

At clock 4, the pipeline can simultaneously:

* accept `12`
* move `7F` into Stage 2
* move `3C` into Stage 1
* produce/consume `A5`

This allows the pipeline to maintain one transaction per cycle despite the three-cycle latency.

---

## Ready/Valid Interface

The datapath uses a standard ready/valid streaming interface.

### Input

A transaction is accepted when:

```text
in_valid && in_ready
```

### Output

A transaction is consumed when:

```text
out_valid && out_ready
```

The pipeline calculates readiness backwards from the output:

```systemverilog
assign ready1   = !out_valid || out_ready;
assign ready0   = !valid1 || ready1;
assign in_ready = !valid0 || ready0;
```

This allows backpressure from the output to propagate through all three stages.

When the downstream consumer deasserts `out_ready` while the pipeline is full:

```text
out_ready = 0
     │
     ▼
Stage 2 cannot advance
     │
     ▼
Stage 1 cannot advance
     │
     ▼
Stage 0 cannot advance
     │
     ▼
in_ready = 0
```

The pipeline therefore freezes without losing or overwriting transactions.

---

## Datapath Widths

The design explicitly widens operands before arithmetic operations to prevent significant bits, particularly carries, from being lost.

For an input width of `W`:

### Stage 0 — Addition

```text
x + A
```

Both operands are extended to `W + 1` bits.

```systemverilog
data_reg0 <= {1'b0, in_data} + {1'b0, A};
```

Stage 0 therefore stores:

```text
W + 1 bits
```

### Stage 1 — Multiplication

The Stage 0 result is explicitly extended before multiplication.

```systemverilog
data_reg1 <= {{DATA_WIDTH{1'b0}}, data_reg0} * B;
```

Stage 1 stores:

```text
2W + 1 bits
```

### Stage 2 — Final Addition

The Stage 1 result is extended before adding `C`.

```systemverilog
out_data <= {1'b0, data_reg1}
          + {{(DATA_WIDTH+1){1'b0}}, C};
```

The final output is:

```text
2W + 2 bits
```

This explicit width management makes the intended arithmetic widths clear and avoids relying on implicit SystemVerilog expression sizing.

---

## Backpressure and Pipeline Stalling

The design supports full pipeline stalls.

When:

```systemverilog
out_ready = 1'b0;
```

the output cannot be consumed.

If all internal stages are occupied, this eventually causes:

```systemverilog
in_ready = 1'b0;
```

The pipeline then holds its state until the downstream consumer becomes ready again.

The testbench verifies that during a stall:

* `in_ready` is deasserted
* `out_valid` remains asserted
* `out_data` remains unchanged
* transactions remain in order
* the pipeline resumes correctly when `out_ready` is reasserted

---

## Verification

The testbench is self-checking and contains a reference model based on a SystemVerilog queue.

For each expected transaction, the testbench independently calculates:

```text
expected = (input + A) × B + C
```

The resulting value is stored in:

```systemverilog
logic [2*DATA_WIDTH+1:0] ref_expected [$];
```

This acts as a FIFO of expected output transactions.

The testbench verifies that outputs are produced in the same order as inputs and that the arithmetic result is correct.

### Tests

#### 1. Reset

Verifies that after reset:

* `in_ready` is asserted
* `out_valid` is deasserted
* the pipeline contains no valid transactions
* the reference queue is cleared

#### 2. Single Arithmetic Transaction

A single input transaction is injected and the testbench verifies that:

* the transaction is accepted
* the pipeline introduces the expected 3-cycle latency
* the output becomes valid
* the arithmetic result matches the reference model

#### 3. Continuous Arithmetic Stream

Multiple values are injected on consecutive cycles:

```text
A5
3C
7F
12
E1
```

The test verifies that the pipeline can accept a new transaction every clock cycle and that the corresponding results emerge in the correct order.

This demonstrates the distinction between:

```text
Latency   = 3 cycles
Throughput = 1 transaction/cycle
```

#### 4. Arithmetic Stall

The pipeline is first filled and then:

```systemverilog
out_ready = 1'b0;
```

Backpressure is applied for multiple cycles.

The testbench verifies that:

* the pipeline stops advancing
* `in_ready` becomes deasserted
* the output remains stable
* no transactions are lost
* no transactions are duplicated
* the original ordering is maintained

The pipeline is then released by setting:

```systemverilog
out_ready = 1'b1;
```

and the remaining transactions are verified as they leave the pipeline.

---

## Example Configuration

The testbench uses:

```systemverilog
parameter DATA_WIDTH = 8;
parameter logic [DATA_WIDTH-1:0] A = 2;
parameter logic [DATA_WIDTH-1:0] B = 3;
parameter logic [DATA_WIDTH-1:0] C = 4;
```

Therefore:

```text
y = (x + 2) × 3 + 4
```

For example, with:

```text
x = 0xA5 = 165
```

the expected result is:

```text
(165 + 2) × 3 + 4
= 167 × 3 + 4
= 505
= 0x1F9
```

---

## Simulation

The testbench generates a VCD waveform:

```text
sim/arithmetic_datapath.vcd
```

The waveform can be inspected using GTKWave to observe:

* pipeline filling
* three-cycle latency
* simultaneous input/output handshakes
* `in_ready` propagation
* output backpressure
* pipeline freezing
* pipeline recovery

Example simulation flow:

```bash
verilator --binary --timing --assert \
    --trace \
    rtl/arithmetic_datapath.sv \
    tb/arithmetic_datapath_tb.sv

./obj_dir/Varithmetic_datapath_tb
```

The exact compilation command may vary depending on the project directory structure and simulator configuration.

To inspect the waveform:

```bash
gtkwave sim/arithmetic_datapath.vcd
```

---

## Project Structure

A typical project structure is:

```text
arithmetic-datapath/
├── rtl/
│   └── arithmetic_datapath.sv
├── tb/
│   └── arithmetic_datapath_tb.sv
├── sim/
│   └── arithmetic_datapath.vcd
└── README.md
```

---

## Key Concepts Demonstrated

This project demonstrates several important RTL design concepts:

### Pipelining

Breaking a datapath into multiple registered stages allows a higher clock frequency and increased throughput.

### Latency vs. Throughput

The design has three cycles of latency but can accept and produce one transaction per cycle once full.

### Ready/Valid Handshaking

Transactions are transferred only when both sides agree:

```text
valid && ready
```

### Backpressure

A downstream stall propagates backwards through the pipeline, preventing new data from entering when there is no available storage.

### Elastic Pipeline Behaviour

Each stage effectively behaves as a one-entry storage element whose ability to accept new data depends on whether the following stage can advance.

### Arithmetic Width Management

Explicit operand extension is used to preserve carries and ensure that intermediate arithmetic has sufficient width.

### Self-Checking Verification

The testbench independently calculates expected results and compares them against the DUT rather than relying solely on waveform inspection.

---

## Learning Outcomes

This project builds on basic synchronous RTL, FSMs, FIFOs, and protocol-style designs by combining them into a pipelined streaming datapath.

The main lessons are:

1. How to partition arithmetic across pipeline stages.
2. How pipeline latency differs from throughput.
3. How ready/valid handshaking enables continuous streaming.
4. How backpressure propagates through a multi-stage pipeline.
5. How to safely stall and resume a pipeline without losing transactions.
6. Why SystemVerilog expression sizing needs to be considered carefully in arithmetic RTL.
7. How to build a transaction-level reference model for a pipelined DUT.
8. How to use waveforms to reason about cycle-by-cycle RTL behaviour.

---

## Future Extensions

Possible extensions, if this datapath were developed further, include:

* Randomised input/output backpressure
* Randomised transaction streams
* Parameterised pipeline depth
* Runtime-configurable arithmetic constants
* Additional arithmetic operations
* Formal verification of ready/valid properties
* Synthesis and static timing analysis
* FPGA implementation and resource utilisation analysis
* Comparison of pipelined and combinational implementations

For the purposes of this project, the core RTL and verification objectives are complete.
