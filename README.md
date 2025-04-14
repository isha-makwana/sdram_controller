# SDRAM Controller – Pipelined Read/Write with FIFO Buffers

This repository contains the Verilog implementation of a pipelined, JEDEC-compliant SDRAM controller. The design supports burst-based read and write operations, interleaved scheduling, and FIFO buffering for enhanced throughput. It is validated using a mock SDRAM model and testbench with QuestaSim.

## 📌 Features

- ✅ Full JEDEC-compliant initialization sequence
- 🔁 Pipelined and interleaved read/write execution
- 📦 FIFO-based buffering for non-blocking access
- 🎯 FSM-driven modular architecture (init, read, write)
- 🧪 Verified using functional testbench and waveform analysis
- 🛠️ Targeted for FPGA deployment (DE10-Lite, Intel MAX 10)

---

## 📁 File Structure

| File                          | Description                                                  |
|-------------------------------|--------------------------------------------------------------|
| `pipelined_multiple_sdram_controller.v` | Top-level controller module integrating all FSMs and FIFOs |
| `sdram_initialize.v`          | FSM for JEDEC-compliant power-on and configuration sequence |
| `sdram_read.v`                | FSM for burst read handling with address and latency logic   |
| `sdram_write.v`               | FSM for burst write with data latching and control timing    |
| `mock_sdram.v`                | Behavioral SDRAM model simulating JEDEC operations           |
| `multiple_RW_calcs_tb.v`      | SystemVerilog testbench performing multiple reads/writes     |
| `Waveform_QuestaSim_PipelinedController.jpeg` | QuestaSim simulation showing pipelined R/W operation    |
| `Controller_Block_Diagram.jpeg` | (Assume image added) Visual representation of the controller pipeline |

---

## ⚙️ Architecture Overview

The SDRAM controller is built from the ground up using modular FSMs and signal arbitration logic:

### 🧩 Initialization FSM
- Powers up and configures the SDRAM with `PRECHARGE`, `AUTO REFRESH`, and `LOAD MODE REGISTER` commands.
- Finishes with a `oinit_done` signal before normal operation.

### ✍️ Write FSM
- Pops data from write FIFO (`150-bit`: addr + 128-bit data).
- Issues `ACTIVE`, followed by `WRITE`, and outputs 4 16-bit beats of data.
- Pulses `write_fin` once burst is completed.

### 📖 Read FSM
- Pops only addresses from read FIFO.
- Issues `ACTIVE` + `READ`, waits for CAS latency, and captures incoming burst into a 128-bit register.
- Pulses `read_fin` once read burst is done.

### 🔄 Interleaved Scheduling FSM
- Top-level controller FSM prioritizes requests dynamically:
  - WRITE → ACK → if read pending, go to READ; else IDLE.
  - READ → ACK → if write pending, go to WRITE; else IDLE.
- Reduces idle cycles and improves bus utilization.

---

## 🧪 Testbench

- The testbench `multiple_RW_calcs_tb.v` performs:
  - 8 write and 8 read transactions with known 128-bit data patterns
  - Logging of latency and bandwidth
  - Assertion checks for data correctness

#### ✅ Waveform Snapshot

![Waveform Simulation](Waveform_QuestaSim_PipelinedController.jpeg)

- **`iwrite_req`** triggers burst writes to sequential addresses.
- **`iread_req`** follows with reads from the same addresses.
- **`owrite_ack`** and **`oread_ack`** show completion handshakes.
- **`oread_data`** confirms exact data recovery.
- Timing markers show latency and sustained bandwidth.

---

## 🔌 Signal Mapping (JEDEC Pins)

| Controller Signal | SDRAM Signal | Description                             |
|------------------|--------------|-----------------------------------------|
| `DRAM_ADDR`      | Address bus  | 13-bit multiplexed address              |
| `DRAM_BA`        | Bank address | 2-bit bank selection                    |
| `DRAM_DQ`        | Data bus     | 16-bit bidirectional data bus           |
| `DRAM_CAS_N`     | Column strobe| Active low column select                |
| `DRAM_RAS_N`     | Row strobe   | Active low row select                   |
| `DRAM_WE_N`      | Write enable | Active low write                        |
| `DRAM_CS_N`      | Chip select  | Active low controller enable            |
| `DRAM_CKE`       | Clock enable | Tied high                               |
| `DRAM_CLK`       | Clock        | Sourced from FPGA                       |
| `DRAM_LDQM/UDQM` | DQM signals  | Byte masking (unused = 0)               |

---

## 📈 Performance Metrics (from waveform)

- **Latency per burst:** ~130 ns
- **Bandwidth:** ~0.98 Gbps sustained across multiple bursts
- **Total testbench runtime:** ~1.87 µs

---

## 🚀 Running the Simulation

### Prerequisites:
- ModelSim/QuestaSim
- Verilog/SystemVerilog support

### Run:
```sh
vsim -do run.do
