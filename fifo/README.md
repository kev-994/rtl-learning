# Parameterized SystemVerilog FIFO

A parameterized synchronous FIFO (First-In, First-Out) implemented in SystemVerilog and verified using a self-checking testbench.

The project focuses on RTL design fundamentals including FIFO control logic, circular buffer addressing, full/empty detection, reset behavior, simultaneous reads/writes, and constrained randomized verification.

## Features

* Parameterized data width and FIFO depth
* Synchronous read/write operation
* `full` and `empty` status flags
* FIFO ordering guarantee
* Circular buffer / pointer wrap-around
* Protection against writes while full
* Protection against reads while empty
* Simultaneous read/write operation
* Reset handling
* Self-checking SystemVerilog testbench
* Queue-based reference model
* Randomized testing
* Automatic draining and verification after randomized tests

## Project Structure

```text
fifo/
├── rtl/
│   └── fifo.sv
├── tb/
│   └── fifo_tb.sv
└── README.md
```

## FIFO Interface

| Signal    | Direction | Description         |
| --------- | --------- | ------------------- |
| `clk`     | Input     | Clock               |
| `reset`   | Input     | Synchronous reset   |
| `wr_en`   | Input     | Write enable        |
| `rd_en`   | Input     | Read enable         |
| `wr_data` | Input     | Data to write       |
| `rd_data` | Output    | Data read from FIFO |
| `full`    | Output    | FIFO is full        |
| `empty`   | Output    | FIFO is empty       |

The FIFO is parameterized using:

```systemverilog
parameter WIDTH = 8;
parameter DEPTH = 8;
```

This allows the same RTL to be instantiated with different data widths and capacities.

For example:

```systemverilog
fifo #(
    .WIDTH(16),
    .DEPTH(32)
) dut (...);
```

## Verification

The testbench uses a SystemVerilog queue as a **software reference model**:

```systemverilog
logic [WIDTH-1:0] ref_fifo [$];
```

Writes are added to the back of the reference queue:

```systemverilog
ref_fifo.push_back(value);
```

Reads remove the oldest value:

```systemverilog
ref_data = ref_fifo.pop_front();
```

The DUT's output is then compared against the reference model:

```systemverilog
assert (rd_data == ref_data)
    else $error("Reference data doesn't match read data.");
```

This provides an independent model of the expected FIFO behavior rather than relying solely on hard-coded expected values.

## Test Cases

The testbench covers:

### 1. Single-value operation

A single value is written and subsequently read back.

Checks that:

* The value is stored correctly
* The value can be retrieved
* The reference model becomes empty
* The DUT output matches the reference model

### 2. Multiple-value operation

Multiple values are written and read back in sequence.

This verifies the fundamental FIFO property:

```text
First In → First Out
```

### 3. Simultaneous read/write

A read and write are performed during the same clock cycle.

This verifies that the FIFO can accept new data while an existing value is being consumed.

### 4. Read while empty

An attempted read is performed when the FIFO contains no data.

The reference model ensures that an invalid read does not remove anything:

```systemverilog
valid_read = ref_fifo.size() > 0;
```

The test also verifies that:

* `empty` remains asserted
* `full` remains deasserted
* `rd_data` remains at its expected reset value

### 5. Write while full

The FIFO is filled to its parameterized capacity.

An additional write is then attempted.

The reference model does not accept the value when:

```systemverilog
ref_fifo.size() == DEPTH
```

This verifies that data is not written beyond the FIFO's capacity.

### 6. Randomized testing

The testbench performs **1000 randomized transactions**.

Each transaction randomly chooses between a read and a write:

```systemverilog
wr = $urandom % 2;
```

Random data is generated for write transactions:

```systemverilog
random_data = $urandom;
```

The reference model tracks every valid transaction and checks the DUT's output.

The testbench also continuously checks that the reference model's occupancy agrees with the DUT's status flags:

```systemverilog
if (ref_fifo.size() == 0)
    assert (empty);

if (ref_fifo.size() == DEPTH)
    assert (full);
```

### 7. Post-randomization draining

After the randomized test, any remaining values in the reference model are drained:

```systemverilog
while (ref_fifo.size() != 0)
    read();
```

The final state is then checked to ensure that both the reference model and DUT are empty.

## Verification Strategy

The testbench uses a **transaction-level reference model** rather than manually checking every expected output.

Conceptually:

```text
                 ┌─────────────────┐
                 │   Testbench     │
                 │                 │
                 │   write/read    │
                 └────────┬────────┘
                          │
             ┌────────────┴────────────┐
             │                         │
             ▼                         ▼
      ┌─────────────┐          ┌──────────────┐
      │     DUT     │          │   Reference  │
      │    FIFO     │          │     Model    │
      └──────┬──────┘          └──────┬───────┘
             │                        │
             │      rd_data           │ expected data
             └──────────┬─────────────┘
                        ▼
                 ┌─────────────┐
                 │   Compare   │
                 │   & Assert  │
                 └─────────────┘
```

This approach makes it possible to test a large number of transactions without manually specifying the expected result of every operation.

## Simulation

The testbench uses a 10 ns clock period:

```systemverilog
always #5 clk = ~clk;
```

The testbench is designed to be run with a SystemVerilog-compatible simulator such as Verilator.

Example Verilator command:

```bash
verilator --binary --timing --assert \
    rtl/fifo.sv \
    tb/fifo_tb.sv \
    --top-module fifo_tb
```

Then run the generated simulation executable.

## What This Project Demonstrates

This project demonstrates practical RTL and verification concepts including:

* SystemVerilog modules and parameterization
* Synchronous sequential logic
* FIFO architecture
* Read/write pointers
* Circular addressing
* Occupancy tracking
* Full/empty generation
* Reset behavior
* SystemVerilog tasks
* SystemVerilog queues
* Assertions
* Reference-model verification
* Randomized testing
* Self-checking testbenches

## Future Improvements

Potential extensions include:

* Add explicit occupancy tracking to the testbench
* Add SystemVerilog Assertions for FIFO invariants
* Add functional coverage
* Increase randomized test length
* Test different `WIDTH` and `DEPTH` configurations
* Add randomized bursts of consecutive reads/writes
* Test simultaneous read/write at empty and full boundaries
* Add waveform-based debugging with GTKWave
* Run synthesis and static timing analysis using FPGA vendor tools

## Status

**Completed**

The FIFO has been functionally tested using directed tests, a queue-based reference model, assertions, and 1000 randomized transactions.
