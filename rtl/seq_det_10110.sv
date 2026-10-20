//==============================================================================
// File        : seq_det_10110.sv
// Description : 5-Bit ("10110") Mealy and Moore Sequence Detector
//               Supports runtime Overlapping/Non-Overlapping mode (ovlp_en)
//               and input data valid qualification (din_valid).
//==============================================================================

module seq_det_10110 (
  input  logic clk,
  input  logic rst_n,
  input  logic din,
  input  logic din_valid, // 1 = din is valid this clock cycle
  input  logic ovlp_en,   // 1 = Overlapping mode, 0 = Non-overlapping mode
  output logic mealy_out,
  output logic moore_out
);

  // 6 States total:
  // - Mealy uses S_IDLE..S_1011 (5 states)
  // - Moore uses S_IDLE..S_10110 (6 states)
  typedef enum logic [2:0] {
    S_IDLE  = 3'd0,
    S_1     = 3'd1,
    S_10    = 3'd2,
    S_101   = 3'd3,
    S_1011  = 3'd4,
    S_10110 = 3'd5   // Used only by Moore FSM
  } state_t;

  state_t mealy_state, mealy_next;
  state_t moore_state, moore_next;

  //============================================================================
  // 1. Sequential State Registers
  //============================================================================
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mealy_state <= S_IDLE;
      moore_state <= S_IDLE;
    end else if (din_valid) begin
      mealy_state <= mealy_next;
      moore_state <= moore_next;
    end
  end

  //============================================================================
  // 2. Mealy Next-State & Output Logic (5 States)
  //============================================================================
  always_comb begin
    mealy_next = mealy_state;
    mealy_out  = 1'b0;

    if (din_valid) begin
      unique case (mealy_state)
        S_IDLE:  mealy_next = din ? S_1    : S_IDLE;
        S_1:     mealy_next = din ? S_1    : S_10;
        S_10:    mealy_next = din ? S_101  : S_IDLE;
        S_101:   mealy_next = din ? S_1011 : S_10;   // "101" + "0" -> last 2 bits are "10"
        S_1011: begin
          if (!din) begin
            mealy_out  = 1'b1;                       // "1011" + "0" = 10110 MATCH!
            mealy_next = ovlp_en ? S_10 : S_IDLE;    // Overlap reuses trailing "10"
          end else begin
            mealy_next = S_1;                        // "1011" + "1" -> last bit is "1"
          end
        end
        default: mealy_next = S_IDLE;
      endcase
    end
  end

  //============================================================================
  // 3. Moore Next-State & Output Logic (6 States)
  //============================================================================
  always_comb begin
    moore_next = moore_state;
    unique case (moore_state)
      S_IDLE:  moore_next = din ? S_1    : S_IDLE;
      S_1:     moore_next = din ? S_1    : S_10;
      S_10:    moore_next = din ? S_101  : S_IDLE;
      S_101:   moore_next = din ? S_1011 : S_10;
      S_1011:  moore_next = din ? S_1    : S_10110;  // "0" enters the 6th Moore state
      S_10110: begin
        if (ovlp_en) begin
          // Trailing "10" is already overlapped:
          // din=1 -> "101" (S_101); din=0 -> "100" (S_IDLE)
          moore_next = din ? S_101 : S_IDLE;
        end else begin
          // Non-overlapping: treat as fresh start from S_IDLE
          moore_next = din ? S_1   : S_IDLE;
        end
      end
      default: moore_next = S_IDLE;
    endcase
  end

  // Moore output depends strictly on the current state
  assign moore_out = (moore_state == S_10110);

endmodule