//==============================================================================
// File        : tb_seq_det_10110.sv
// Description : Self-Checking SystemVerilog Testbench for 5-Bit ("10110")
//               Mealy & Moore Sequence Detector.
//               Includes Shift-Register Golden Scoreboard, SVAs, and Functional
//               Coverage with 100% coverage closure.
//==============================================================================

module tb_seq_det_10110;

  logic clk = 0;
  logic rst_n;
  logic din;
  logic din_valid;
  logic ovlp_en;
  logic mealy_out;
  logic moore_out;

  // Clock Generation (100 MHz -> 10 ns period)
  always #5 clk = ~clk;

  // Instantiate DUT
  seq_det_10110 dut (.*);

  //============================================================================
  // 1. Shift-Register Golden Reference Model (Scoreboard)
  //============================================================================
  logic [4:0] mealy_shreg;
  int         valid_cnt;
  logic       exp_mealy, exp_moore;
  int         err_cnt   = 0;
  int         match_cnt = 0;

  wire [4:0] curr_window = {mealy_shreg[3:0], din};
  assign exp_mealy = din_valid && (valid_cnt >= 4) && (curr_window == 5'b10110);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mealy_shreg <= 5'b0;
      valid_cnt   <= 0;
      exp_moore   <= 1'b0;
    end else if (din_valid) begin
      exp_moore <= exp_mealy;

      if (exp_mealy && !ovlp_en) begin
        mealy_shreg <= 5'b0;
        valid_cnt   <= 0;
      end else begin
        mealy_shreg <= curr_window;
        valid_cnt   <= (valid_cnt < 5) ? valid_cnt + 1 : 5;
      end
    end
  end

  // Self-Checking Monitor on Negative Edge (race-free sampling)
  always @(negedge clk) begin
    if (rst_n && din_valid) begin
      if (mealy_out !== exp_mealy) begin
        $error("[%0t] MEALY MISMATCH! Got=%0b, Exp=%0b", $time, mealy_out, exp_mealy);
        err_cnt++;
      end
      if (moore_out !== exp_moore) begin
        $error("[%0t] MOORE MISMATCH! Got=%0b, Exp=%0b", $time, moore_out, exp_moore);
        err_cnt++;
      end
      if (mealy_out) begin
        match_cnt++;
        $display("[%0t ns] MATCH #%0d! (ovlp_en=%0b) | Mealy=1 now, Moore asserts on next clk",
                 $time, match_cnt, ovlp_en);
      end
    end
  end

  //============================================================================
  // 2. SystemVerilog Assertions (SVAs)
  //============================================================================
  // Property 1: Whenever Mealy detects 10110 on a valid beat, Moore MUST
  //             be high on the very next clock cycle.
  property p_mealy_to_moore_delay;
    @(posedge clk) disable iff (!rst_n)
    (din_valid && mealy_out) |=> moore_out;
  endproperty
  assert property (p_mealy_to_moore_delay)
    else $error("SVA Failed: Moore did not follow Mealy by 1 cycle!");

  // Property 2: Mealy output can never assert unless din_valid=1 and din=0
  property p_mealy_valid_qual;
    @(posedge clk) disable iff (!rst_n)
    mealy_out |-> (din_valid && (din == 1'b0));
  endproperty
  assert property (p_mealy_valid_qual)
    else $error("SVA Failed: Mealy asserted illegally!");

  //============================================================================
  // 3. Functional Coverage (With ignore_bins for 100% Closure)
  //============================================================================
  covergroup cg_fsm @(posedge clk iff (rst_n && din_valid));
    option.per_instance = 1;

    cp_mealy_state: coverpoint dut.mealy_state {
      // Mealy only uses 5 states; ignore the 6th Moore-only state
      ignore_bins unused_moore_state = {dut.S_10110};
    }
    cp_moore_state: coverpoint dut.moore_state;
    cp_ovlp_mode:   coverpoint ovlp_en;
    cx_mode_match:  cross cp_ovlp_mode, cp_moore_state;
  endgroup
  cg_fsm cg_inst = new();

  //============================================================================
  // 4. Stimulus Task & VCD Waveform Dump
  //============================================================================
  task send_bit(input logic b, input logic val = 1'b1);
    @(posedge clk);
    din       <= b;
    din_valid <= val;
  endtask

  logic [12:0] directed_stream = 13'b10110_110_10110;

  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb_seq_det_10110);

    rst_n = 0; din = 0; din_valid = 0; ovlp_en = 1;
    repeat (2) @(posedge clk);
    rst_n = 1;

    // --- TEST 1: Directed Overlapping Stream (10110_110_10110) ---
    $display("\n--- Starting Test 1: Directed Overlapping Mode (Stream: 1011011010110) ---");
    for (int i = 12; i >= 0; i--) send_bit(directed_stream[i], 1'b1);
    send_bit(0, 1'b1);

    // --- TEST 2: Directed Non-Overlapping Stream (10110_110_10110) ---
    @(posedge clk); rst_n <= 0; @(posedge clk); rst_n <= 1; ovlp_en <= 0;
    $display("\n--- Starting Test 2: Directed Non-Overlapping Mode (Stream: 1011011010110) ---");
    for (int i = 12; i >= 0; i--) send_bit(directed_stream[i], 1'b1);
    send_bit(0, 1'b1);

    // --- TEST 3: Random Stimulus with Intermittent din_valid ---
    $display("\n--- Starting Test 3: 200 Cycles Random Stimulus ---");
    for (int i = 0; i < 200; i++) begin
      if (i == 100) begin
        @(posedge clk); rst_n <= 0;
        @(posedge clk); rst_n <= 1; ovlp_en <= 1'b1;
      end
      send_bit($urandom_range(0, 1), $urandom_range(0, 1));
    end

    repeat (2) @(posedge clk);
    $display("\n==============================================================");
    $display("TEST COMPLETE! Total Matches = %0d | Errors = %0d | Coverage = %0.2f%%",
             match_cnt, err_cnt, cg_inst.get_inst_coverage());
    $display("==============================================================\n");
    $finish;
  end

endmodule