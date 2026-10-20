# 5-Bit (`10110`) Mealy & Moore Sequence Detector in SystemVerilog

A synthesizable SystemVerilog implementation and self-checking verification environment for a **5-bit (`10110`) Mealy and Moore Sequence Detector**, featuring runtime **Overlapping / Non-Overlapping** mode selection (`ovlp_en`) and input handshaking (`din_valid`).

## Key Features

### RTL Design (`rtl/seq_det_10110.sv`)
- **Dual Architecture Comparison:** Implements both a **5-state Mealy FSM** (same-cycle combinational output) and a **6-state Moore FSM** (registered state-based output, 1-cycle delayed).
- **Runtime Overlap Control (`ovlp_en`):** Dynamically switches between overlapping detection (reusing trailing `"10"` after a `10110` match) and non-overlapping detection (resetting to `S_IDLE`).
- **Input Qualification (`din_valid`):** Holds FSM state during invalid input cycles.
- **2-Block SystemVerilog Coding Style:** Uses `typedef enum logic [2:0]`, `always_ff`, and `always_comb` with `unique case` for lint-clean synthesis and readable waveform state names.

### Verification Environment (`tb/tb_seq_det_10110.sv`)
- **Orthogonal Shift-Register Scoreboard:** Uses a 5-bit sliding window (`curr_window`) as a Golden Reference Model to auto-verify both Mealy and Moore outputs on every negative clock edge.
- **SystemVerilog Assertions (SVAs):**
  - `p_mealy_to_moore_delay`: Proves that whenever `mealy_out` asserts on a valid cycle, `moore_out` asserts on the very next clock cycle (`|=>`).
  - `p_mealy_valid_qual`: Verifies `mealy_out` never glitches when `din_valid == 0` or `din == 1`.
- **Functional Coverage (`covergroup`):** Tracks state coverage across both FSMs, `ovlp_en` modes, and cross-coverage (`cx_mode_match`), utilizing `ignore_bins` for unreachable Mealy enum states to achieve **100.00% functional coverage**.

---

## State Transition Summary (`10110`)

| Current State | `din = 0` (Next State) | `din = 1` (Next State) | Mealy Out (`din=0 / din=1`) | Moore Out |
| :--- | :--- | :--- | :--- | :--- |
| **`S_IDLE`** | `S_IDLE` | `S_1` | `0 / 0` | `0` |
| **`S_1`** | `S_10` | `S_1` | `0 / 0` | `0` |
| **`S_10`** | `S_IDLE` | `S_101` | `0 / 0` | `0` |
| **`S_101`** | `S_10` | `S_1011` | `0 / 0` | `0` |
| **`S_1011`** | Mealy: `ovlp_en ? S_10 : S_IDLE`<br>Moore: `S_10110` | `S_1` | `1 / 0` | `0` |
| **`S_10110`** *(Moore Only)* | `S_IDLE` | `ovlp_en ? S_101 : S_1` | N/A | `1` |

---

## Simulation Output (QuestaSim)

```text
# --- Starting Test 1: Directed Overlapping Mode (Stream: 1011011010110) ---
# [70 ns] MATCH #1! (ovlp_en=1) | Mealy=1 now, Moore will assert on next valid clk
# [100 ns] MATCH #2! (ovlp_en=1) | Mealy=1 now, Moore will assert on next valid clk
# [150 ns] MATCH #3! (ovlp_en=1) | Mealy=1 now, Moore will assert on next valid clk
# 
# --- Starting Test 2: Directed Non-Overlapping Mode (Stream: 1011011010110) ---
# [230 ns] MATCH #4! (ovlp_en=0) | Mealy=1 now, Moore will assert on next valid clk
# [310 ns] MATCH #5! (ovlp_en=0) | Mealy=1 now, Moore will assert on next valid clk
# 
# --- Starting Test 3: 200 Cycles Random Stimulus ---
# [610 ns] MATCH #6! (ovlp_en=0) | Mealy=1 now, Moore will assert on next valid clk
# [720 ns] MATCH #7! (ovlp_en=0) | Mealy=1 now, Moore will assert on next valid clk
# [2180 ns] MATCH #8! (ovlp_en=1) | Mealy=1 now, Moore will assert on next valid clk
# 
# ==============================================================
# TEST COMPLETE! Total Matches = 8 | Errors = 0 | Coverage = 100.00%
# ==============================================================
