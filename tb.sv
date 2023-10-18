`timescale 1ns/1ps

module tb ();

localparam FREQ = 1000;//40_000_000;
localparam HOR  = 10;//800;
localparam HFP  = 2;//40;
localparam HSP  = 4;//128;
localparam HBP  = 1;//88;
localparam VER  = 10;//600;
localparam VFP  = 3;//1;
localparam VSP  = 6;//4;
localparam VBP  = 2;//23;
localparam BB   = 5;//5;
localparam GB   = 6;//6;
localparam RB   = 5;//5;

logic           resetn;
logic           clock;
logic           valid;
logic           frame;
logic           ready;
logic [RB-1:0]  r_in;
logic [GB-1:0]  g_in;
logic [BB-1:0]  b_in;
logic [RB-1:0]  r_out;
logic [GB-1:0]  g_out;
logic [BB-1:0]  b_out;
logic           hs;
logic           vs;

integer i,j;

initial clock = 0;
always clock = #1 ~clock;

initial begin
  resetn = 1;
  valid = 0;
  r_in = 0;
  g_in = 0;
  b_in = 0;
  repeat (10) @(posedge clock)
  resetn = 0;
  repeat (10) @(posedge clock)
  resetn = #1 1;
  repeat (1) @(posedge clock)
  while (!frame) @(posedge clock)
  @(posedge clock);
  valid = 1;
  //sending a bit more to check if will send zeros
  for (i=0; i<VER+1; i=i+1) begin
    for (j=0; j<HOR+1; j=j+1) begin
      if (ready) begin
        {r_in, g_in, b_in} = $random;
      end
      @(posedge clock);
    end
  end
  valid = 0;
  @(posedge clock);
  $finish;
end

vga
#(
   .FREQ  (FREQ  )
  ,.X_HOR (HOR   )
  ,.X_HFP (HFP   )
  ,.X_HSP (HSP   )
  ,.X_HBP (HBP   )
  ,.X_VER (VER   )
  ,.X_VFP (VFP   )
  ,.X_VSP (VSP   )
  ,.X_VBP (VBP   )
  ,.BB    (BB    )
  ,.GB    (GB    )
  ,.RB    (RB    )
) dut (
   .resetn  (resetn  )
  ,.clock   (clock   )
  ,.valid   (valid   )
  ,.frame   (frame   )
  ,.ready   (ready   )
  ,.r_in    (r_in    )
  ,.g_in    (g_in    )
  ,.b_in    (b_in    )
  ,.r_out   (r_out   )
  ,.g_out   (g_out   )
  ,.b_out   (b_out   )
  ,.hs      (hs      )
  ,.vs      (vs      )
);


endmodule
