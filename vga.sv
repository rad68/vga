`timescale 1ns/1ps

/*
  VGA Interface:

  Target: Genesys 2

  Default: SVGA 800 x 600 @ 60 Hz

  HOWTO:
  After reset modules starts sending data to the VGA port.
  When module accepts values on the rgb line it sets "ready" signal high.
  User can send colors to the rgb line with a valid signal set high
  otherwise rgb are set to zero. A "frame" signal is set high 
  for one cycle to signal that at the next cycle module will
  restart from the left top corner.

*/

typedef enum logic [2:0]
{
   IDLE         = 3'b000
  ,DISPLAY      = 3'b001
  ,FRONT_PORCH  = 3'b010
  ,SYNC_PULSE   = 3'b011
  ,BACK_PORCH   = 3'b100
  ,XXX = 'x
} state;

module vga
#(
   parameter  FREQ  = 40_000_000
  //External horizontal parameters (in pixels)
  ,parameter  X_HOR = 800
  ,parameter  X_HFP = 40
  ,parameter  X_HSP = 128
  ,parameter  X_HBP = 88
  //External vertical parameters (in lines)
  ,parameter  X_VER = 600
  ,parameter  X_VFP = 1
  ,parameter  X_VSP = 4
  ,parameter  X_VBP = 23
  //VGA PHY
  ,parameter  BB  = 5
  ,parameter  GB  = 6
  ,parameter  RB  = 5
)(
   input                  resetn
  ,input                  clock

  ,input                  valid
  ,output logic           frame
  ,output logic           ready
  ,input        [RB-1:0]  r_in
  ,input        [GB-1:0]  g_in
  ,input        [BB-1:0]  b_in

  ,output logic [RB-1:0]  r_out
  ,output logic [GB-1:0]  g_out
  ,output logic [BB-1:0]  b_out
  ,output logic           hs
  ,output logic           vs

);

//Horizontal parameters (in pixels)
localparam  HOR =     X_HOR;
localparam  HFP = HOR+X_HFP;
localparam  HSP = HFP+X_HSP;
localparam  HBP = HSP+X_HBP;

//Vertical parameters (in lines)
localparam  VER =     X_VER;
localparam  VFP = VER+X_VFP;
localparam  VSP = VFP+X_VSP;
localparam  VBP = VSP+X_VBP;

logic [15:0] h_cnt, h_cnt_next;
logic hs_next;
logic [15:0] v_cnt, v_cnt_next;
logic vs_next;
logic frame_next;
logic ready_next;

logic [RB-1:0] r_next;
logic [GB-1:0] g_next;
logic [BB-1:0] b_next;

/*
  Horizontal control
*/
state h_state, v_state;
state h_next_state, v_next_state;

always_ff @(posedge clock)
if (!resetn)  h_state <= IDLE;
else          h_state <= h_next_state;

always_comb begin
  h_next_state = XXX;
  case (h_state)
    IDLE        : if (frame)          h_next_state = DISPLAY;
                  else                h_next_state = IDLE;
    DISPLAY     : if (h_cnt == HOR-1) h_next_state = FRONT_PORCH;
                  else                h_next_state = DISPLAY;
    FRONT_PORCH : if (h_cnt == HFP-1) h_next_state = SYNC_PULSE;
                  else                h_next_state = FRONT_PORCH;
    SYNC_PULSE  : if (h_cnt == HSP-1) h_next_state = BACK_PORCH;
                  else                h_next_state = SYNC_PULSE;
    BACK_PORCH  : if (h_cnt == HBP-1) h_next_state = DISPLAY;
                  else                h_next_state = BACK_PORCH;
    default     :                     h_next_state = XXX;
  endcase
end

always_ff @(posedge clock)
if (!resetn)  v_state <= IDLE;
else          v_state <= v_next_state;

always_comb begin
  v_next_state = XXX;
  case (v_state)
    IDLE        : if (frame)                            v_next_state = DISPLAY;
                  else                                  v_next_state = IDLE;
    DISPLAY     : if (v_cnt == VER-1 && h_cnt == HBP-1) v_next_state = FRONT_PORCH;
                  else                                  v_next_state = DISPLAY;
    FRONT_PORCH : if (v_cnt == VFP-1 && h_cnt == HBP-1) v_next_state = SYNC_PULSE;
                  else                                  v_next_state = FRONT_PORCH;
    SYNC_PULSE  : if (v_cnt == VSP-1 && h_cnt == HBP-1) v_next_state = BACK_PORCH;
                  else                                  v_next_state = SYNC_PULSE;
    BACK_PORCH  : if (v_cnt == VBP-1 && h_cnt == HBP-1) v_next_state = DISPLAY;
                  else                                  v_next_state = BACK_PORCH;
    default     :                                       v_next_state = XXX;
  endcase
end

/*
  Horizontal datapath
*/
always_ff @(posedge clock)
if (!resetn)  begin
  h_cnt <= '0;
  hs    <= '1;
  {r_out, g_out, b_out} <= '0;
  ready <= '0;
end
else begin
  h_cnt <= h_cnt_next;
  hs    <= hs_next;
  {r_out, g_out, b_out} <= {r_next, g_next, b_next};
  ready <= ready_next;
end

always_comb begin
  h_cnt_next  = '0;
  hs_next     = '1;
  {r_next, g_next, b_next} = '0;
  ready_next  = '0;
  case (h_next_state)
    IDLE    : 
      begin
        h_cnt_next  = HBP-1;
        hs_next     = '1;
        ready_next  = '0;
      end
    DISPLAY :
      begin
        if (h_cnt == HBP-1) h_cnt_next = '0;
        else                h_cnt_next  = h_cnt + 1;

        if (v_next_state == DISPLAY)  ready_next = '1;
        else                          ready_next = '0;

        hs_next = '1;
        {r_next, g_next, b_next} = valid ? {r_in, g_in, b_in} : '0;
      end
    FRONT_PORCH :
      begin
        h_cnt_next  = h_cnt + 1'b1;
        ready_next  = '0;
        hs_next = '1;
        {r_next, g_next, b_next} = '0;
      end
    SYNC_PULSE  : 
      begin
        h_cnt_next  = h_cnt + 1'b1;
        ready_next  = '0;
        hs_next = '0;
        {r_next, g_next, b_next} = '0;
      end
    BACK_PORCH  :
      begin
        h_cnt_next  = h_cnt + 1'b1;
        ready_next  = '0;
        hs_next = '1;
        {r_next, g_next, b_next} = '0;
      end
    default : 
      begin
        h_cnt_next  = 'x;
        ready_next  = 'x;
        hs_next     = 'x;
        {r_next, g_next, b_next} = 'x;
      end
  endcase
end

/*
  Vertical datapath
*/
always_ff @(posedge clock)
if (!resetn)  begin
  v_cnt <= '0;
  vs    <= '1;
  frame <= '0;
end
else begin
  v_cnt <= v_cnt_next;
  vs    <= vs_next;
  frame <= frame_next;
end

always_comb begin
  v_cnt_next  = '0;
  vs_next     = '1;
  frame_next  = '0;
  case (v_next_state)
    IDLE    : 
      begin
        v_cnt_next  = VBP-1;
        vs_next     = '1;
        frame_next  = '1;
      end
    DISPLAY :
      begin
        if (v_cnt == VBP-1 && h_cnt == HBP-1) v_cnt_next  = '0;
        else if (h_cnt == HBP-1)              v_cnt_next  = v_cnt + 1'b1;
        else                                  v_cnt_next  = v_cnt;

        vs_next     = '1;
        frame_next  = '0;
      end
    FRONT_PORCH :
      begin
        if (h_cnt == HBP-1) v_cnt_next  = v_cnt + 1'b1;
        else                v_cnt_next  = v_cnt;

        vs_next     = '1;
        frame_next  = '0;
      end
    SYNC_PULSE  : 
      begin
        if (h_cnt == HBP-1) v_cnt_next  = v_cnt + 1'b1;
        else                v_cnt_next  = v_cnt;

        vs_next     = '0;
        frame_next  = '0;
      end
    BACK_PORCH  :
      begin
        if (h_cnt == HBP-1) v_cnt_next  = v_cnt + 1'b1;
        else                v_cnt_next  = v_cnt;

        vs_next = '1;

        if (v_cnt == VBP-1 && h_cnt == HBP-2) frame_next  = '1;
        else                                  frame_next  = '0;
      end
    default : 
      begin
        v_cnt_next  = 'x;
        vs_next     = 'x;
        frame_next  = 'x;
      end
  endcase
end

endmodule
