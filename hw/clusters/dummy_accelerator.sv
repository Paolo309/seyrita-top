//
// Dummy accelerator
//
// - Acts only as an AXI slave;
// - On a write request, it captures the data, starts a countdown, and immediately
//   sends the write response (B channel);
// - When the countdown finishes, it stores double the captured value in an internal register;
// - On a read request:
//   - if the countdown is in progress, it responds with a default value (e.g. 0);
//   - if the countdown is finished, it responds with the value stored in the register, multiplied by 2.

module dummy_accelerator
  import chimera_pkg::*;
  import cheshire_pkg::*;
#(
  parameter type     axi_req_t       = logic,
  parameter type     axi_resp_t      = logic,
  parameter int      CountdownCycles = 10,     // to simulate processing time
  parameter unsigned BusyValue       = '0
) (
  input  logic      clk_i,
  input  logic      rst_ni,
  input  axi_req_t  slv_req_i,
  output axi_resp_t slv_resp_o
);

  // for identifying transactions
  logic slv_aw_fire, slv_w_fire, slv_ar_fire, slv_b_fire, slv_r_fire;

  assign slv_aw_fire = slv_resp_o.aw_ready && slv_req_i.aw_valid;
  assign slv_w_fire  = slv_resp_o.w_ready && slv_req_i.w_valid;
  assign slv_ar_fire = slv_resp_o.ar_ready && slv_req_i.ar_valid;
  assign slv_b_fire  = slv_resp_o.b_valid && slv_req_i.b_ready;
  assign slv_r_fire  = slv_resp_o.r_valid && slv_req_i.r_ready;

  typedef enum logic [0:0] {
    Idle,
    Counting
  } internal_state_e;

  // FSM for AXI reads
  typedef enum logic [0:0] {
    ReadIdle,
    ReadSendData
  } slv_read_state_e;

  // Next-state logic signals (_d) and state-holding registers (_q).
  internal_state_e internal_state_d, internal_state_q;
  logic [$bits(slv_req_i.w.data)-1:0] result_d, result_q;
  logic [$bits(slv_req_i.w.data)-1:0] input_value_d, input_value_q;
  logic [$clog2(CountdownCycles+1)-1:0] countdown_d, countdown_q;

  logic slv_b_valid_d, slv_b_valid_q;
  logic [$bits(slv_req_i.aw.id)-1:0] slv_b_id_d, slv_b_id_q;

  slv_read_state_e slv_read_state_d, slv_read_state_q;
  logic [$bits(slv_req_i.ar.len)-1:0] slv_beat_cnt_d, slv_beat_cnt_q;
  logic [$bits(slv_req_i.ar.id)-1:0] slv_r_id_d, slv_r_id_q;
  logic [$bits(slv_req_i.ar.len)-1:0] slv_r_len_d, slv_r_len_q;


  always_comb begin
    internal_state_d = internal_state_q;
    result_d         = result_q;
    input_value_d    = input_value_q;
    countdown_d      = countdown_q;
    slv_b_valid_d    = slv_b_valid_q;
    slv_b_id_d       = slv_b_id_q;
    slv_read_state_d = slv_read_state_q;
    slv_beat_cnt_d   = slv_beat_cnt_q;
    slv_r_id_d       = slv_r_id_q;
    slv_r_len_d      = slv_r_len_q;

    // --- contdown ---
    case (internal_state_q)
      Idle: begin
        if (slv_w_fire) begin  // write transaction accepted
          $display("[%0t] AXI Slave Stub: Value %0d received. Starting countdown", $time,
                   slv_req_i.w.data);
          internal_state_d = Counting;
          input_value_d    = slv_req_i.w.data;
          countdown_d      = CountdownCycles;
        end
      end
      Counting: begin
        if (countdown_q > 0) begin  // countdown
          countdown_d = countdown_q - 1;
        end else begin
          $display("[%0t] AXI Slave Stub: Countdown finished. Result: %0d", $time,
                   input_value_q * 2);
          internal_state_d = Idle;
          result_d         = input_value_q * 2;
        end
      end
    endcase

    // --- AXI response ---
    if (slv_b_fire) begin
      slv_b_valid_d = 1'b0;
    end else if (slv_w_fire) begin
      slv_b_valid_d = 1'b1;
    end
    if (slv_aw_fire) begin
      slv_b_id_d = slv_req_i.aw.id;
    end

    // --- AXI reads ---
    case (slv_read_state_q)
      ReadIdle: begin
        if (slv_ar_fire) begin
          slv_read_state_d = ReadSendData;
          slv_beat_cnt_d   = '0;
          slv_r_id_d       = slv_req_i.ar.id;
          slv_r_len_d      = slv_req_i.ar.len;
        end
      end
      ReadSendData: begin
        if (slv_r_fire) begin
          if (slv_beat_cnt_q == slv_r_len_q) begin  // last beat sent
            slv_read_state_d = ReadIdle;
          end else begin
            slv_beat_cnt_d = slv_beat_cnt_q + 1;
          end
        end
      end
    endcase
  end


  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      internal_state_q <= Idle;
      result_q         <= '0;
      input_value_q    <= '0;
      countdown_q      <= '0;
      slv_b_valid_q    <= 1'b0;
      slv_b_id_q       <= '0;
      slv_read_state_q <= ReadIdle;
      slv_beat_cnt_q   <= '0;
      slv_r_id_q       <= '0;
      slv_r_len_q      <= '0;
    end else begin
      internal_state_q <= internal_state_d;
      result_q         <= result_d;
      input_value_q    <= input_value_d;
      countdown_q      <= countdown_d;
      slv_b_valid_q    <= slv_b_valid_d;
      slv_b_id_q       <= slv_b_id_d;
      slv_read_state_q <= slv_read_state_d;
      slv_beat_cnt_q   <= slv_beat_cnt_d;
      slv_r_id_q       <= slv_r_id_d;
      slv_r_len_q      <= slv_r_len_d;
    end
  end


  assign slv_resp_o.aw_ready = 1'b1;
  // only accept write data when not processing
  assign slv_resp_o.w_ready  = (internal_state_q == Idle);
  // only accept read requests when not sending data
  assign slv_resp_o.ar_ready = (slv_read_state_q == ReadIdle);

  assign slv_resp_o.b_valid  = slv_b_valid_q;
  assign slv_resp_o.b.id     = slv_b_id_q;
  assign slv_resp_o.b.resp   = 2'b00;

  assign slv_resp_o.r_valid  = (slv_read_state_q == ReadSendData);
  // only send results when finished processing
  assign slv_resp_o.r.data   = (internal_state_q == Counting) ? BusyValue : result_q;
  assign slv_resp_o.r.id     = slv_r_id_q;
  assign slv_resp_o.r.resp   = 2'b00;
  assign slv_resp_o.r.last   = (slv_beat_cnt_q == slv_r_len_q);
  assign slv_resp_o.r.user   = '0;

endmodule

