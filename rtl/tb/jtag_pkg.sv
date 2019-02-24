// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

/*
 * jtag_pkg.sv
 * Francesco Conti <fconti@iis.ee.ethz.ch>
 * Antonio Pullini <pullinia@iis.ee.ethz.ch>
 */

package jtag_pkg;

   parameter int unsigned JTAG_SOC_INSTR_WIDTH                                 = 5;
   parameter logic [JTAG_SOC_INSTR_WIDTH-1:0]  JTAG_SOC_IDCODE                 = 5'b00001;
   parameter logic [JTAG_SOC_INSTR_WIDTH-1:0]  JTAG_SOC_DTMCSR                 = 5'b10000;
   parameter logic [JTAG_SOC_INSTR_WIDTH-1:0]  JTAG_SOC_DMIACCESS              = 5'b10001;
   parameter logic [JTAG_SOC_INSTR_WIDTH-1:0]  JTAG_SOC_AXIREG                 = 5'b00100;
   parameter logic [JTAG_SOC_INSTR_WIDTH-1:0]  JTAG_SOC_BBMUXREG               = 5'b00101;
   parameter logic [JTAG_SOC_INSTR_WIDTH-1:0]  JTAG_SOC_CONFREG                = 5'b00110;
   parameter logic [JTAG_SOC_INSTR_WIDTH-1:0]  JTAG_SOC_TESTMODEREG            = 5'b01000;
   parameter logic [JTAG_SOC_INSTR_WIDTH-1:0]  JTAG_SOC_BISTREG                = 5'b01001;
   parameter logic [JTAG_SOC_INSTR_WIDTH-1:0]  JTAG_SOC_BYPASS                 = 5'b11111;
   parameter int unsigned JTAG_SOC_IDCODE_WIDTH                                = 32;
   parameter int unsigned JTAG_SOC_BBMUXREG_WIDTH                              = 21;
   parameter int unsigned JTAG_SOC_CLKGATEREG_WIDTH                            = 11;
   parameter int unsigned JTAG_SOC_CONFREG_WIDTH                               = 16;
   parameter int unsigned JTAG_SOC_TESTMODEREG_WIDTH                           =  4;
   parameter int unsigned JTAG_SOC_BISTREG_WIDTH                               = 20;

   parameter int unsigned JTAG_CLUSTER_INSTR_WIDTH                             = 5;
   parameter logic [JTAG_CLUSTER_INSTR_WIDTH-1:0]  JTAG_CLUSTER_IDCODE         = 5'b0010;
   parameter logic [JTAG_CLUSTER_INSTR_WIDTH-1:0]  JTAG_CLUSTER_SAMPLE_PRELOAD = 5'b0001;
   parameter logic [JTAG_CLUSTER_INSTR_WIDTH-1:0]  JTAG_CLUSTER_EXTEST         = 5'b0000;
   parameter logic [JTAG_CLUSTER_INSTR_WIDTH-1:0]  JTAG_CLUSTER_DEBUG          = 5'b1000;
   parameter logic [JTAG_CLUSTER_INSTR_WIDTH-1:0]  JTAG_CLUSTER_MBIST          = 5'b1001;
   parameter logic [JTAG_CLUSTER_INSTR_WIDTH-1:0]  JTAG_CLUSTER_BYPASS         = 5'b1111;
   parameter int unsigned JTAG_CLUSTER_IDCODE_WIDTH                            = 32;

   parameter int unsigned JTAG_IDCODE_WIDTH                                    = JTAG_SOC_IDCODE_WIDTH;
   parameter int unsigned JTAG_INSTR_WIDTH                                     = JTAG_SOC_INSTR_WIDTH;

   parameter DMI_SIZE = 32+7+2;

   task automatic jtag_wait_halfperiod(input int cycles);
      #(50000*cycles);
   endtask

   task automatic jtag_clock(
      input int cycles,
      ref logic s_tck
   );
      for(int i=0; i<cycles; i=i+1) begin
         s_tck = 1'b0;
         jtag_wait_halfperiod(1);
         s_tck = 1'b1;
         jtag_wait_halfperiod(1);
         s_tck = 1'b0;
      end
   endtask

   task automatic jtag_reset(
      ref logic s_tck,
      ref logic s_tms,
      ref logic s_trstn,
      ref logic s_tdi
   );
      s_tms   = 1'b0;
      s_tck   = 1'b0;
      s_trstn = 1'b0;
      s_tdi   = 1'b0;
      jtag_wait_halfperiod(2);
      s_trstn = 1'b1;
   endtask

   task automatic jtag_softreset(
      ref logic s_tck,
      ref logic s_tms,
      ref logic s_trstn,
      ref logic s_tdi
   );
      s_tms   = 1'b1;
      s_trstn = 1'b1;
      s_tdi   = 1'b0;
      jtag_clock(5, s_tck); //enter RST
      s_tms   = 1'b0;
      jtag_clock(1, s_tck); // back to IDLE
      $display("JTAG: SoftReset Done(%t)",$realtime);

   endtask

   class JTAG_reg #(int unsigned size = 32, logic [(JTAG_CLUSTER_INSTR_WIDTH+JTAG_SOC_INSTR_WIDTH)-1:0] instr = 'h0);

      task idle(
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi
      );
         s_trstn = 1'b1;
         // from SHIFT_DR to RUN_TEST : tms sequence 10
         s_tms   = 1'b1;
         s_tdi   = 1'b0;
         jtag_clock(1, s_tck);
         s_tms   = 1'b0;
         jtag_clock(1, s_tck);
      endtask

      task update_and_goto_shift(
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi
      );
         s_trstn = 1'b1;
         // from SHIFT_DR to RUN_TEST : tms sequence 110
         s_tms   = 1'b1;
         s_tdi   = 1'b0;
         jtag_clock(1, s_tck);
         s_tms   = 1'b1;
         jtag_clock(1, s_tck);
         s_tms   = 1'b0;
         jtag_clock(1, s_tck);
         jtag_clock(1, s_tck);
      endtask

      task jtag_goto_SHIFT_IR(
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi
      );
         s_trstn = 1'b1;
         s_tdi   = 1'b0;
         // from IDLE to SHIFT_IR : tms sequence 1100
         s_tms   = 1'b1;
         jtag_clock(2, s_tck);
         s_tms   = 1'b0;
         jtag_clock(2, s_tck);
      endtask

      task jtag_goto_SHIFT_DR(
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi
      );
         s_trstn = 1'b1;
         s_tdi   = 1'b0;
         // from IDLE to SHIFT_IR : tms sequence 100
         s_tms   = 1'b1;
         jtag_clock(1, s_tck);
         s_tms   = 1'b0;
         jtag_clock(2, s_tck);
      endtask

      task jtag_goto_UPDATE_DR_FROM_SHIFT_DR(
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi
      );
         //$display("I am at jtag_goto_UPDATE_DR_FROM_SHIFT_DR (%t)",$realtime);
         s_trstn = 1'b1;
         s_tdi   = 1'b1;
         // from SHIFT DR to UPDATE DR : tms sequence 11
         s_tms   = 1'b1;
         jtag_clock(1, s_tck);
         // back to Idle : tms sequence 0
         s_tms   = 1'b0;
         //wait a bit
         jtag_clock(50, s_tck);
      endtask

      task jtag_goto_CAPTURE_DR_FROM_UPDATE_DR_GETDATA(
         output logic [DMI_SIZE-1:0] dataout,
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         ref logic s_tdo
      );
         //$display("I am at jtag_goto_CAPTURE_DR_FROM_UPDATE_DR_GETDATA (%t)",$realtime);
         s_trstn = 1'b1;
         s_tdi   = 1'b1;
         // from UPDATE DR to CAPTURE DR : tms sequence 10
         s_tms   = 1'b1;
         jtag_clock(1, s_tck);
         s_tms   = 1'b0;
         jtag_clock(1, s_tck);
         //back to Idle: tms sequence 110
         s_tms   = 1'b1;
         jtag_clock(2, s_tck);
         s_tms   = 1'b0;
         jtag_clock(1, s_tck);
         // go to SHIFT DR: tms sequence 100
         s_tms   = 1'b1;
         jtag_clock(1, s_tck);
         s_tms   = 1'b0;
         jtag_clock(2, s_tck);
         s_tms   = 1'b0;
         for(int i=0; i<DMI_SIZE; i=i+1) begin
            if (i == (DMI_SIZE-1))
               s_tms = 1'b1;
            s_tdi = 1'b0;
            jtag_clock(1, s_tck);
            dataout[i] = s_tdo;
         end

      endtask

      task jtag_goto_CAPTURE_DR_FROM_SHIFT_DR_GETDATA(
         output logic [DMI_SIZE-1:0] dataout,
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         ref logic s_tdo
      );
         //$display("I am at jtag_goto_CAPTURE_DR_FROM_SHIFT_DR_GETDATA (%t)",$realtime);
         s_trstn = 1'b1;
         s_tdi   = 1'b1;
         // from UPDATE DR to CAPTURE DR : tms sequence 110
         s_tms   = 1'b1;
         jtag_clock(2, s_tck);
         s_tms   = 1'b0;
         jtag_clock(1, s_tck);
         // go to SHIFT DR
         s_tms   = 1'b0;
         jtag_clock(1, s_tck);
         s_tms   = 1'b0;
         for(int i=0; i<DMI_SIZE; i=i+1) begin
            if (i == (DMI_SIZE-1))
               s_tms = 1'b1;
            s_tdi = 1'b0;
            jtag_clock(1, s_tck);
            dataout[i] = s_tdo;
         end

      endtask

      task jtag_shift_SHIFT_IR(
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi
      );
         s_trstn = 1'b1;
         s_tms   = 1'b0;
         for(int i=0; i<JTAG_SOC_INSTR_WIDTH + JTAG_CLUSTER_INSTR_WIDTH; i=i+1) begin
            if (i==(JTAG_SOC_INSTR_WIDTH+JTAG_CLUSTER_INSTR_WIDTH-1))
                 s_tms = 1'b1;
            s_tdi = instr[i];
            jtag_clock(1, s_tck);
         end
      endtask

      task jtag_shift_NBITS_SHIFT_DR (
         input int unsigned     numbits,
         input logic[size-1:0]  datain,
         output logic[size-1:0] dataout,
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         ref logic s_tdo
      );
         s_trstn = 1'b1;
         s_tms   = 1'b0;
         for(int i=0; i<numbits; i=i+1) begin
            if (i == (numbits-1))
               s_tms = 1'b1;
            s_tdi = datain[i];
            jtag_clock(1, s_tck);
            dataout[i] = s_tdo;
         end
      endtask

      task shift_nbits_noex(
         input int unsigned     numbits,
         input logic[size-1:0]  datain,
         output logic[size-1:0] dataout,
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         ref logic s_tdo
      );
         s_trstn = 1'b1;
         s_tms   = 1'b0;
         for(int i=0; i<numbits; i=i+1) begin
            s_tdi = datain[i];
            jtag_clock(1, s_tck);
            dataout[i] = s_tdo;
         end
      endtask

      task start_shift(
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi
      );
         this.jtag_goto_SHIFT_DR(s_tck, s_tms, s_trstn, s_tdi);
      endtask

      task shift_nbits(
         input int unsigned     numbits,
         input logic[size-1:0]  datain,
         output logic[size-1:0] dataout,
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         ref logic s_tdo
      );
           this.jtag_shift_NBITS_SHIFT_DR(numbits, datain, dataout, s_tck, s_tms, s_trstn, s_tdi, s_tdo);
      endtask

      task setIR(
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi
      );
         this.jtag_goto_SHIFT_IR(s_tck, s_tms, s_trstn, s_tdi);
         this.jtag_shift_SHIFT_IR(s_tck, s_tms, s_trstn, s_tdi);
         this.idle(s_tck, s_tms, s_trstn, s_tdi);
      endtask

      task shift(
         input logic[size-1:0]  datain,
         output logic[size-1:0] dataout,
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         ref logic s_tdo
      );
         this.jtag_goto_SHIFT_DR(s_tck, s_tms, s_trstn, s_tdi);
         this.jtag_shift_NBITS_SHIFT_DR(size, datain, dataout, s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         this.idle(s_tck, s_tms, s_trstn, s_tdi);
      endtask

   endclass

   task automatic jtag_get_idcode(
      ref logic s_tck,
      ref logic s_tms,
      ref logic s_trstn,
      ref logic s_tdi,
      ref logic s_tdo
   );
      automatic JTAG_reg #(.size(JTAG_IDCODE_WIDTH+1), .instr({JTAG_SOC_IDCODE, JTAG_SOC_BYPASS})) jtag_idcode = new;
      //as we have two tap in Daisy Chain, always one bit more for the bypass
      logic [31+1:0] s_idcode;
      jtag_idcode.setIR(s_tck, s_tms, s_trstn, s_tdi);
      jtag_idcode.shift('0, s_idcode, s_tck, s_tms, s_trstn, s_tdi, s_tdo);
      $display("JTAG: Tap ID: %h (%t)",s_idcode[32:1], $realtime);
      if(s_idcode[32:1] != 32'h249511C3) begin
         $display("JTAG: Tap ID Test FAILED (%t)", $realtime);
      end else begin
         $display("JTAG: Tap ID Test PASSED (%t)", $realtime);
      end
   endtask

   task automatic jtag_bypass_test(
      ref logic s_tck,
      ref logic s_tms,
      ref logic s_trstn,
      ref logic s_tdi,
      ref logic s_tdo
   );
      automatic JTAG_reg #(.size(255), .instr({JTAG_SOC_BYPASS, JTAG_SOC_BYPASS})) jtag_bypass = new;
                logic [255:0] result_data;
      automatic logic [255:0] test_data = {     32'hDEADBEEF, 32'h0BADF00D, 32'h01234567, 32'h89ABCDEF,
                                                32'hAAAABBBB, 32'hCCCCDDDD, 32'hEEEEFFFF, 32'h00001111};
      jtag_bypass.setIR(s_tck, s_tms, s_trstn, s_tdi);
      jtag_bypass.shift(test_data, result_data, s_tck, s_tms, s_trstn, s_tdi, s_tdo);
      if (test_data[253:0] == result_data[255:2])
         $display("JTAG: Bypass Test Passed (%t)", $realtime);
      else
      begin
         $display("JTAG: Bypass Test Failed");
         $display("JTAG:   LSB WORD TEST = %h (%t)",test_data[31:0], $realtime);
         $display("JTAG:   LSB WORD RES  = %h (%t)",result_data[32:1], $realtime);
      end
   endtask

   class test_mode_if_t;

      task init(
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi
      );
         JTAG_reg #(.size(256), .instr({JTAG_SOC_BYPASS, JTAG_SOC_CONFREG})) jtag_soc_dbg = new;
         jtag_soc_dbg.setIR(s_tck, s_tms, s_trstn, s_tdi);
         $display("[test_mode_if] %t - Init", $realtime);
      endtask

      task set_confreg(
         input  logic [8:0] confreg,
         output logic [8:0] dataout,
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         ref logic s_tdo
      );
         logic [8+1:0] confreg_int, dataout_int; //extra bit for bypass
         JTAG_reg #(.size(256), .instr({JTAG_SOC_BYPASS, JTAG_SOC_CONFREG})) jtag_soc_dbg = new;

         confreg_int = {1'b0, confreg};

         jtag_soc_dbg.start_shift(s_tck, s_tms, s_trstn, s_tdi);
         jtag_soc_dbg.shift_nbits(9+1, confreg_int, dataout_int, s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         jtag_soc_dbg.idle(s_tck, s_tms, s_trstn, s_tdi);
         dataout = dataout_int[8:0];
         $display("[test_mode_if] %t - Setting confreg to value %X.", $realtime, confreg);
      endtask

      task get_confreg(
         input logic [8:0] confreg,
         output bit  [8:0] rec,
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         ref logic s_tdo
      );
         logic [8+1:0] dataout; //extra bit for bypass
         JTAG_reg #(.size(256), .instr({JTAG_SOC_BYPASS, JTAG_SOC_CONFREG})) jtag_soc_dbg = new;
         jtag_soc_dbg.start_shift(s_tck, s_tms, s_trstn, s_tdi);
         jtag_soc_dbg.shift_nbits(9+1, confreg, dataout, s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         jtag_soc_dbg.idle(s_tck, s_tms, s_trstn, s_tdi);
         rec = dataout [8:0];
         // `DEBUG_MANAGER_INST.printf(STDOUT, 0, $sformatf("%s[TEST_MODE_IF] %s%t - %sGet confreg value = %X%s\n", `ESC_BLUE_BOLD, `ESC_WHITE, $realtime, `ESC_MAGENTA, rec, `ESC_DEFAULT));
      endtask

   endclass

   class debug_mode_if_t;

      task init(
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         ref logic s_tdo
      );

          logic [1:0]  dm_op;
          logic [6:0]  dm_addr;
          logic [31:0] dm_data;
         //Read Info
         JTAG_reg #(.size(32+1), .instr({JTAG_SOC_DTMCSR, JTAG_SOC_BYPASS})) jtag_soc_dbg = new;
         jtag_soc_dbg.setIR(s_tck, s_tms, s_trstn, s_tdi);
         $display("[debug_mode_if_t] %t - Init", $realtime);
         this.read_dtmcs(
               dm_data,
               s_tck,
               s_tms,
               s_trstn,
               s_tdi,
               s_tdo
            );
          // TODO: constants
         $display("[debug_mode_if] %t - dtmcs %x: \n \
                                        dmihardreset %x \n \
                                        dmireset %x \n \
                                        idle %x \n \
                                        dmistat %x \n \
                                        abits %x \n \
                                        version %x \n",
                  $realtime, dm_data, dm_data[17], dm_data[16], dm_data[14:12], dm_data[11:10], dm_data[9:4], dm_data[3:0]);

         this.init_dmi(
               s_tck,
               s_tms,
               s_trstn,
               s_tdi
            );
          // TODO: use constants
         this.set_dmi(
               2'b01, //read
               7'h11, //DMStatus
               32'h0, //whatever
               {dm_addr, dm_data, dm_op},
               s_tck,
               s_tms,
               s_trstn,
               s_tdi,
               s_tdo
            );
          // TODO: use constants
         $display("PULPissimo Debug version: \
                 impebreak %x\n \
                 allhavereset %x\n \
                 anyhavereset %x\n \
                 allrunning %x\n \
                 anyrunning %x\n \
                 allhalted %x\n \
                 anyhalted %x\n \
                 version %x\n \
              ", dm_data[22], dm_data[19], dm_data[18], dm_data[11], dm_data[10], dm_data[9], dm_data[8], dm_data[3:0]);

      endtask


      task set_haltreq(
         input logic haltreq,
         ref logic   s_tck,
         ref logic   s_tms,
         ref logic   s_trstn,
         ref logic   s_tdi,
         ref logic   s_tdo
      );

          logic [1:0]     dm_op;
          logic [6:0]     dm_addr;
          logic [31:0]    dm_data;
          dm::dmcontrol_t dmcontrol;

         // TODO: we probably don't need to rescan IR
         this.init_dmi(s_tck, s_tms, s_trstn, s_tdi);
         this.read_debug_reg(dm::DMControl, dmcontrol,
                             s_tck, s_tms, s_trstn, s_tdi, s_tdo);

         dmcontrol.haltreq = haltreq;

         this.write_debug_reg(dm::DMControl, dmcontrol,
                              s_tck, s_tms, s_trstn, s_tdi, s_tdo);


         //wait the core to be stalled
         dm_data = '0;
         while(dm_data[8] == 1'b0) begin //anyhalted
            this.set_dmi(
                  2'b01, //read
                  7'h11, //dmstatus
                  32'h0, //whatever
                  {dm_addr, dm_data, dm_op},
                  s_tck,
                  s_tms,
                  s_trstn,
                  s_tdi,
                  s_tdo
               );
         end

      endtask

      task set_resumereq(
         input logic resumereq,
         ref logic   s_tck,
         ref logic   s_tms,
         ref logic   s_trstn,
         ref logic   s_tdi,
         ref logic   s_tdo
      );

          logic [1:0]     dm_op;
          logic [6:0]     dm_addr;
          logic [31:0]    dm_data;
          dm::dmcontrol_t dmcontrol;

         // TODO: we probably don't need to rescan IR
         this.init_dmi(s_tck, s_tms, s_trstn, s_tdi);
         this.read_debug_reg(dm::DMControl, dmcontrol,
                             s_tck, s_tms, s_trstn, s_tdi, s_tdo);

         dmcontrol.resumereq = resumereq;

         this.write_debug_reg(dm::DMControl, dmcontrol,
                              s_tck, s_tms, s_trstn, s_tdi, s_tdo);

      endtask


      task halt_harts(
         ref logic   s_tck,
         ref logic   s_tms,
         ref logic   s_trstn,
         ref logic   s_tdi,
         ref logic   s_tdo
      );

         dm::dmcontrol_t dmcontrol;
         dm::dmstatus_t  dmstatus;

         // stop the hart by setting haltreq
         this.read_debug_reg(dm::DMControl, dmcontrol,
                             s_tck, s_tms, s_trstn, s_tdi, s_tdo);

         dmcontrol.haltreq = 1'b1;

         this.write_debug_reg(dm::DMControl, dmcontrol,
                              s_tck, s_tms, s_trstn, s_tdi, s_tdo);

         // wait until hart is halted
         do begin
            this.read_debug_reg(dm::DMStatus, dmstatus,
                                s_tck, s_tms, s_trstn, s_tdi, s_tdo);

         end while(dmstatus.allhalted != 1'b1);

         // clear haltreq
         dmcontrol.haltreq = 1'b0;
         this.write_debug_reg(dm::DMControl, dmcontrol,
                              s_tck, s_tms, s_trstn, s_tdi, s_tdo);

      endtask


      task resume_harts(
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         ref logic s_tdo
      );

         dm::dmcontrol_t dmcontrol;
         dm::dmstatus_t  dmstatus;

         // resume the hart by setting resumereq
         this.read_debug_reg(dm::DMControl, dmcontrol,
                             s_tck, s_tms, s_trstn, s_tdi, s_tdo);

         dmcontrol.resumereq = 1'b1;

         this.write_debug_reg(dm::DMControl, dmcontrol,
                              s_tck, s_tms, s_trstn, s_tdi, s_tdo);

         // wait until hart resumed
         do begin
            this.read_debug_reg(dm::DMStatus, dmstatus,
                                s_tck, s_tms, s_trstn, s_tdi, s_tdo);

         end while(dmstatus.allresumeack != 1'b1);

         // clear resumereq
         dmcontrol.resumereq = 1'b0;
         this.write_debug_reg(dm::DMControl, dmcontrol,
                              s_tck, s_tms, s_trstn, s_tdi, s_tdo);

      endtask

      task block_until_any_halt(
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         ref logic s_tdo
      );

         logic [1:0]  dm_op;
         logic [6:0]  dm_addr;
         logic [31:0] dm_data;
         dm::dmstatus_t dmstatus;

         dmstatus = '0;
         dm_data  = '0;

         while(dmstatus.anyhalted == 1'b0) begin //anyhalted
            this.set_dmi(
                  2'b01, //read
                  7'h11, //dmstatus
                  32'h0, //whatever
                  {dm_addr, dm_data, dm_op},
                  s_tck,
                  s_tms,
                  s_trstn,
                  s_tdi,
                  s_tdo
            );
            dmstatus = dm::dmstatus_t'(dm_data);
         end

      endtask

      task writeArg (
         input logic arg,
         input logic [31:0] val,
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         ref logic s_tdo
      );


          logic [1:0]  dm_op;
          logic [6:0]  dm_addr;
          logic [31:0] dm_data;

         dm_addr = arg ? 7'd8 : 7'd4;

         this.set_dmi(
               2'b10,    //write
               dm_addr, //data0 or data1
               val,     //whatever
               {dm_addr, dm_data, dm_op},
               s_tck,
               s_tms,
               s_trstn,
               s_tdi,
               s_tdo
            );
      endtask

      task writePrgramBuff (
         input logic [2:0]  arg,
         input logic [31:0] val,
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         ref logic s_tdo
      );


          logic [1:0]  dm_op;
          logic [6:0]  dm_addr;
          logic [31:0] dm_data;

         dm_addr = 7'h20 + arg;

         this.set_dmi(
               2'b10,    //write
               dm_addr, //progbuffer_i
               val,     //whatever
               {dm_addr, dm_data, dm_op},
               s_tck,
               s_tms,
               s_trstn,
               s_tdi,
               s_tdo
            );

      endtask

      task read_abstractcs (
         output logic [31:0] abstractcs,
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         ref logic s_tdo
      );


          logic [1:0]  dm_op;
          logic [6:0]  dm_addr;
          logic [31:0] dm_data;

         this.set_dmi(
               2'b01, //read
               7'h16, //abstracts
               32'h0, //whatever
               {dm_addr, dm_data, dm_op},
               s_tck,
               s_tms,
               s_trstn,
               s_tdi,
               s_tdo
            );
         abstractcs = dm_data;

      endtask

      task wait_command (
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         ref logic s_tdo
      );

         logic [1:0]  dm_op;
         logic [6:0]  dm_addr;
         logic [31:0] dm_data;

         dm_data = '1;

         while(dm_data[12] == 1'b1)
         begin
            this.read_abstractcs(
                  dm_data,
                  s_tck,
                  s_tms,
                  s_trstn,
                  s_tdi,
                  s_tdo
               );
            #5us;
         end

      endtask


      task set_command (
         input logic [31:0] command,
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         ref logic s_tdo
      );


          logic [1:0]  dm_op;
          logic [6:0]  dm_addr;
          logic [31:0] dm_data;

         this.set_dmi(
               2'b10,   //write
               7'h17,   //command
               command, //whatever
               {dm_addr, dm_data, dm_op},
               s_tck,
               s_tms,
               s_trstn,
               s_tdi,
               s_tdo
            );

         this.wait_command(
               s_tck,
               s_tms,
               s_trstn,
               s_tdi,
               s_tdo
            );

      endtask

      task init_dmi(
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi
      );
         //Read Info
         JTAG_reg #(.size(32+1), .instr({JTAG_SOC_DMIACCESS, JTAG_SOC_BYPASS})) jtag_soc_dbg = new;
         // we should almost never be necessary to scan IR (see ricsv-debug p.71)
         jtag_soc_dbg.setIR(s_tck, s_tms, s_trstn, s_tdi);
//         $display("[debug_mode_if_t] %t - Init DMI Access", $realtime);

      endtask

      task read_dtmcs(
         output logic [31:0] dtmcs,
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         ref logic s_tdo
      );
         logic [31+1:0] dataout;
         JTAG_reg #(.size(32+1), .instr({JTAG_SOC_DTMCSR, JTAG_SOC_BYPASS})) jtag_soc_dbg = new;
         jtag_soc_dbg.start_shift(s_tck, s_tms, s_trstn, s_tdi);
         jtag_soc_dbg.shift_nbits(32+1, '0, dataout, s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         jtag_soc_dbg.idle(s_tck, s_tms, s_trstn, s_tdi);
         dtmcs = dataout[32:1];
      endtask

      task write_dtmcs(
         input logic [31:0] dtmcs,
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         ref logic s_tdo
      );
         logic [31+1:0] dataout;
         JTAG_reg #(.size(32+1), .instr({JTAG_SOC_DTMCSR, JTAG_SOC_BYPASS})) jtag_soc_dbg = new;
         jtag_soc_dbg.start_shift(s_tck, s_tms, s_trstn, s_tdi);
         jtag_soc_dbg.shift_nbits(32+1, {dtmcs, 1'b0}, dataout, s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         jtag_soc_dbg.idle(s_tck, s_tms, s_trstn, s_tdi);

      endtask


      task read_sbcs(
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         ref logic s_tdo
      );

         logic [1:0]         dm_op;
         logic [31:0]        dm_data;
         logic [6:0]         dm_addr;

         this.set_dmi(
               2'b01, //read
               7'h38, //sbcs,
               32'h0, //whatever
               {dm_addr, dm_data, dm_op},
               s_tck,
               s_tms,
               s_trstn,
               s_tdi,
               s_tdo
            );

           $display("PULPissimo System Bus Access Control and Status: \
                 sbbusy  %x\n \
                 sbreadonaddr %x\n \
                 sbaccess  %x\n \
                 sbautoincrement  %x\n \
                 sbreadondata  %x\n \
                 sberror %x\n \
                 sbasize %x\n \
                 sbaccess32 %x\n \
              ", dm_data[21], dm_data[20], dm_data[19:17], dm_data[16], dm_data[15], dm_data[14:12], dm_data[11:5], dm_data[2]);

      endtask

      task set_dmi(
         input  logic [1:0]  op_i,
         input  logic [6:0]  address_i,
         input  logic [31:0] data_i,
         output logic [DMI_SIZE-1:0]  data_o,
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         ref logic s_tdo
      );
         logic [DMI_SIZE-1+1:0] buffer;
         logic [DMI_SIZE-1:0]   buffer_riscv;
         JTAG_reg #(.size(DMI_SIZE+1), .instr({JTAG_SOC_DMIACCESS, JTAG_SOC_BYPASS})) jtag_soc_dbg = new;
         jtag_soc_dbg.start_shift(s_tck, s_tms, s_trstn, s_tdi);
         jtag_soc_dbg.shift_nbits(DMI_SIZE+1, {address_i,data_i,op_i, 1'b0}, buffer, s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         jtag_soc_dbg.jtag_goto_UPDATE_DR_FROM_SHIFT_DR(s_tck, s_tms, s_trstn, s_tdi);
         jtag_soc_dbg.jtag_goto_CAPTURE_DR_FROM_UPDATE_DR_GETDATA(buffer, s_tck, s_tms, s_trstn, s_tdi,s_tdo);
         buffer_riscv = buffer[DMI_SIZE:1];
         //while(buffer_riscv[1:0] == 2'b11) begin
         //   //$display("buffer is set_dmi is %x (OP %x address %x datain %x) (%t)",buffer, buffer[1:0], buffer[8:2], buffer[DMI_SIZE-1:9], $realtime);
         //   jtag_soc_dbg.jtag_goto_CAPTURE_DR_FROM_SHIFT_DR_GETDATA(buffer, s_tck, s_tms, s_trstn, s_tdi,s_tdo);
         //   buffer_riscv = buffer[DMI_SIZE:1];
         //end
         //$display("dataout is set_dmi is %x (OP %x address %x datain %x) (%t)",buffer, buffer[1:0], buffer[40:34],  buffer[33:2], $realtime);
         data_o[1:0]   = buffer_riscv[1:0];
         data_o[40:34] = buffer_riscv[40:34];
         data_o[33:2]  = buffer_riscv[33:2];
         jtag_soc_dbg.idle(s_tck, s_tms, s_trstn, s_tdi);

      endtask

      task dmi_reset(
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         ref logic s_tdo
      );
         logic [31:0] buffer;
         JTAG_reg #(.size(32+1), .instr({JTAG_SOC_DTMCSR, JTAG_SOC_BYPASS})) jtag_soc_dbg = new;
         jtag_soc_dbg.setIR(s_tck, s_tms, s_trstn, s_tdi);
         this.read_dtmcs(
               buffer,
               s_tck,
               s_tms,
               s_trstn,
               s_tdi,
               s_tdo
            );
         buffer[16] = 1'b1;
         this.write_dtmcs(
               buffer,
               s_tck,
               s_tms,
               s_trstn,
               s_tdi,
               s_tdo
            );
         buffer[16] = 1'b0;
         this.write_dtmcs(
               buffer,
               s_tck,
               s_tms,
               s_trstn,
               s_tdi,
               s_tdo
            );
      endtask

      task set_dmactive(
         input logic dmactive,
         ref   logic s_tck,
         ref   logic s_tms,
         ref   logic s_trstn,
         ref   logic s_tdi,
         ref   logic s_tdo
      );

         logic [1:0]         dm_op;
         logic [31:0]        dm_data;
         logic [6:0]         dm_addr;

         this.set_dmi(
               2'b10, //Write
               7'h10, //DMControl
               {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 10'b0, 10'b0, 2'b0, 1'b0, 1'b0, 1'b0, dmactive},
               {dm_addr, dm_data, dm_op},
               s_tck,
               s_tms,
               s_trstn,
               s_tdi,
               s_tdo
            );

      endtask

      task set_harsel(
         input logic [9:0] hartselli,
         input logic [9:0] hartsello,
         ref   logic s_tck,
         ref   logic s_tms,
         ref   logic s_trstn,
         ref   logic s_tdi,
         ref   logic s_tdo
      );

         logic [1:0]         dm_op;
         logic [31:0]        dm_data;
         logic [6:0]         dm_addr;

         this.set_dmi(
               2'b01, //read
               7'h10, //DMControl
               32'h0, //whatever
               {dm_addr, dm_data, dm_op},
               s_tck,
               s_tms,
               s_trstn,
               s_tdi,
               s_tdo
            );

         //haltreq
         dm_data[25:16] = hartsello;
         dm_data[15: 6] = hartselli;

         this.set_dmi(
               2'b10, //Write
               7'h10, //DMControl
               dm_data,
               {dm_addr, dm_data, dm_op},
               s_tck,
               s_tms,
               s_trstn,
               s_tdi,
               s_tdo
            );

      endtask


      task set_sbreadonaddr(
         input logic sbreadonaddr,
         ref   logic s_tck,
         ref   logic s_tms,
         ref   logic s_trstn,
         ref   logic s_tdi,
         ref   logic s_tdo
      );

         logic [1:0]         dm_op;
         logic [31:0]        dm_data;
         logic [6:0]         dm_addr;

         this.set_dmi(
            2'b01, //read
            7'h38, //sbcs,
            32'h0, //whatever
            {dm_addr, dm_data, dm_op},
            s_tck,
            s_tms,
            s_trstn,
            s_tdi,
            s_tdo
         );
         dm_data[20] = sbreadonaddr;
         this.set_dmi(
            2'b10, //write
            7'h38, //sbcs,
            dm_data, //whatever
            {dm_addr, dm_data, dm_op},
            s_tck,
            s_tms,
            s_trstn,
            s_tdi,
            s_tdo
         );
      endtask

      task set_sbautoincrement(
         input logic sbautoincrement,
         ref   logic s_tck,
         ref   logic s_tms,
         ref   logic s_trstn,
         ref   logic s_tdi,
         ref   logic s_tdo
      );

         logic [1:0]         dm_op;
         logic [31:0]        dm_data;
         logic [6:0]         dm_addr;

         this.set_dmi(
            2'b01, //read
            7'h38, //sbcs,
            32'h0, //whatever
            {dm_addr, dm_data, dm_op},
            s_tck,
            s_tms,
            s_trstn,
            s_tdi,
            s_tdo
         );
         dm_data[16] = sbautoincrement;
         this.set_dmi(
            2'b10, //write
            7'h38, //sbcs,
            dm_data, //whatever
            {dm_addr, dm_data, dm_op},
            s_tck,
            s_tms,
            s_trstn,
            s_tdi,
            s_tdo
         );
      endtask

      // access (read) debug module register according to riscv-debug p. 71
      task read_debug_reg(
         input logic [6:0]   dmi_addr_i,
         output logic [31:0] data_o,
         ref logic           s_tck,
         ref logic           s_tms,
         ref logic           s_trstn,
         ref logic           s_tdi,
         ref logic           s_tdo
      );

         logic [1:0]         dmi_op;
         logic [31:0]        dmi_data;
         logic [6:0]         dmi_addr;

         // TODO: widen wait between Capture-DR and Update-DR when failing
         do begin
             this.set_dmi(
                   2'b01, //read
                   dmi_addr_i,
                   32'h0, // don't care
                   {dmi_addr, dmi_data, dmi_op},
                   s_tck,
                   s_tms,
                   s_trstn,
                   s_tdi,
                   s_tdo
             );
             if (dmi_op == 2'h2) begin
                 $display("[TB] %t dmi previous operation failed, not handled", $realtime);
                 dmi_op = 2'h0; // TODO: for now we just force completion
             end

             if (dmi_op == 2'h3) begin
                 $display("[TB] %t retrying debug reg access", $realtime);
                 this.dmi_reset(s_tck,s_tms,s_trstn,s_tdi,s_tdo);
             end

         end while (dmi_op != 2'h0);

         data_o = dmi_data;
      endtask

      // access (write) debug module register according to riscv-debug p. 71
      task write_debug_reg(
         input logic [6:0]   dmi_addr_i,
         input logic [31:0]  dmi_data_i,
         ref logic           s_tck,
         ref logic           s_tms,
         ref logic           s_trstn,
         ref logic           s_tdi,
         ref logic           s_tdo
      );

         logic [1:0]     dmi_op;
         logic [31:0]    dmi_data;
         logic [6:0]     dmi_addr;
         dm::dmcontrol_t dmcontrol;
         int             dmsane;

         // According to riscv-debug p. 22 we are only allowed to write at most
         // one bit to resumereq, hartreset, ackhavereset,setresethaltreq and
         // clrresethaltreq. Others must be 0. This assert is for programming
         // errors.
         if(dmi_addr_i == dm::DMControl) begin
            dmcontrol = dmi_data_i;
            dmsane    = dmcontrol.resumereq + dmcontrol.hartreset +
                        dmcontrol.ackhavereset + dmcontrol.setresethaltreq +
                        dmcontrol.clrresethaltreq;

            assert (dmsane <= 1)
                else
                    $error("bad write to dmcontrol: only one of the following may be set to 1: resumereq %b,",
                           dmcontrol.resumereq,
                           "hartreset %b,", dmcontrol.hartreset,
                           "ackhavereset %b,", dmcontrol.ackhavereset,
                           "setresethaltreq %b,", dmcontrol.setresethaltreq,
                           "clrresethaltreq %b", dmcontrol.clrresethaltreq);
         end


         // TODO: widen wait between Capture-DR and Update-DR when failing
         do begin
             this.set_dmi(
                   2'b10, //write
                   dmi_addr_i,
                   dmi_data_i,
                   {dmi_addr, dmi_data, dmi_op},
                   s_tck,
                   s_tms,
                   s_trstn,
                   s_tdi,
                   s_tdo
             );
             if (dmi_op == 2'h2) begin
                 $display("[TB] %t dmi previous operation failed, not handled", $realtime);
                 dmi_op = 2'h0; // TODO: for now we just force completion
             end

             if (dmi_op == 2'h3) begin
                 $display("[TB] %t retrying debug reg access", $realtime);
                 this.dmi_reset(s_tck,s_tms,s_trstn,s_tdi,s_tdo);
             end

         end while (dmi_op != 2'h0);

      endtask


      // access (read) csr, gpr by means of abstract command
      task read_reg_abstract_cmd(
         input logic [15:0]  regno_i,
         output logic [31:0] data_o,
         ref logic           s_tck,
         ref logic           s_tms,
         ref logic           s_trstn,
         ref logic           s_tdi,
         ref logic           s_tdo
      );

         logic [1:0]         dmi_op;
         logic [31:0]        dmi_data;
         logic [31:0]        dmi_command;
         logic [6:0]         dmi_addr;

         // load regno into data0
         dmi_command = {8'h0, 1'b0, 3'd2, 1'b0, 1'b0, 1'b1, 1'b0, regno_i};
         this.set_command(
            dmi_command,
            s_tck,
            s_tms,
            s_trstn,
            s_tdi,
            s_tdo
         );

         this.read_debug_reg(
            dm::Data0,
            dmi_data,
            s_tck,
            s_tms,
            s_trstn,
            s_tdi,
            s_tdo
         );

         data_o = dmi_data;
      endtask


      // access (write) csr, gpr by means of abstract command
      task write_reg_abstract_cmd(
         input logic [15:0] regno_i,
         input logic [31:0] data_i,
         ref logic          s_tck,
         ref logic          s_tms,
         ref logic          s_trstn,
         ref logic          s_tdi,
         ref logic          s_tdo
      );

         logic [1:0]         dmi_op;
         logic [31:0]        dmi_data;
         logic [31:0]        dmi_command;
         logic [6:0]         dmi_addr;

         //write data_i into data0
         this.write_debug_reg(
             dm::Data0,
             data_i,
             s_tck,
             s_tms,
             s_trstn,
             s_tdi,
             s_tdo
         );

         // write data0 to regno_i
         dmi_command = {8'h0, 1'b0, 3'd2, 1'b0, 1'b0, 1'b1, 1'b1, regno_i};
         this.set_command(
            dmi_command,
            s_tck,
            s_tms,
            s_trstn,
            s_tdi,
            s_tdo
         );

      endtask

      // Before starting an abstract command, haltreq=resumereq=ackhavereset=0
      // must be ensured, which is what this task asserts (see debug spec p.11).
      // We use this to catch programming mistakes, not to test functionality
      task assert_rdy_for_abstract_cmd(
         ref logic           s_tck,
         ref logic           s_tms,
         ref logic           s_trstn,
         ref logic           s_tdi,
         ref logic           s_tdo
      );

         dm::dmcontrol_t dmcontrol;
         this.read_debug_reg(dm::DMControl, dmcontrol,
                             s_tck, s_tms, s_trstn, s_tdi, s_tdo);

         assert(dmcontrol.haltreq == 1'b0)
             else $error("haltreq is not zero");
         assert(dmcontrol.resumereq == 1'b0)
             else $error("resumereq is not zero");
         assert(dmcontrol.ackhavereset == 1'b0)
             else $error("ackhavereset is not zero");

      endtask

      // access csr, gpr by means of program buffer
      task read_reg_prog_buff(
         input logic [15:0]  regno_i,
         output logic [31:0] data_o,
         ref logic           s_tck,
         ref logic           s_tms,
         ref logic           s_trstn,
         ref logic           s_tdi,
         ref logic           s_tdo
      );

         logic [1:0]         dmi_op;
         logic [31:0]        dmi_data;
         logic [31:0]        dmi_command;
         logic [6:0]         dmi_addr;

         // load regno into data0
         dmi_command = {8'h0, 1'b0, 3'd2, 1'b0, 1'b0, 1'b1, 1'b0, regno_i};
         this.set_command(
            dmi_command,
            s_tck,
            s_tms,
            s_trstn,
            s_tdi,
            s_tdo
         );

         this.read_debug_reg(
            dm::Data0,
            dmi_data,
            s_tck,
            s_tms,
            s_trstn,
            s_tdi,
            s_tdo
         );

         data_o = dmi_data;
      endtask


      task readMem(
         input  logic [31:0] addr_i,
         output logic [31:0] data_o,
         ref    logic s_tck,
         ref    logic s_tms,
         ref    logic s_trstn,
         ref    logic s_tdi,
         ref    logic s_tdo
      );

         logic [1:0]         dm_op;
         logic [31:0]        dm_data;
         logic [6:0]         dm_addr;

         //NOTE sbreadonaddr must be 1

         dm_op = '1; //error

         while(dm_op == '1) begin
            //Write the Address
            this.set_dmi(
               2'b10,        //write
               7'h39,        //sbaddress0,
               addr_i,       //address
               {dm_addr, dm_data, dm_op},
               s_tck,
               s_tms,
               s_trstn,
               s_tdi,
               s_tdo
            );
            // $display("(sbaddress0) dm_addr %x dm_data %x dm_op %x at time %t", dm_addr, dm_data, dm_op, $realtime,);
            if(dm_op == '1) begin
               $display("dmi_reset at time %t",$realtime);
               this.dmi_reset(s_tck,s_tms,s_trstn,s_tdi,s_tdo);
               this.init_dmi(s_tck,s_tms,s_trstn,s_tdi);
            end

         end

         dm_op = '1; //error

         while(dm_op == '1) begin

            this.set_dmi(
               2'b01,     //read
               7'h3C,     //sbdata0,
               32'h0,     //whatever
               {dm_addr, dm_data, dm_op},
               s_tck,
               s_tms,
               s_trstn,
               s_tdi,
               s_tdo
            );
            // $display("(sbdata0) dm_addr %x dm_data %x dm_op %x at time %t", dm_addr, dm_data, dm_op, $realtime);
               if(dm_op == '1) begin
                  $display("dmi_reset at time %t",$realtime);
                  this.dmi_reset(s_tck,s_tms,s_trstn,s_tdi,s_tdo);
                  this.init_dmi(s_tck,s_tms,s_trstn,s_tdi);
               end

         end
         data_o = dm_data;


      endtask

      task writeMem(
         input  logic [31:0] addr_i,
         input  logic [31:0] data_i,
         ref    logic s_tck,
         ref    logic s_tms,
         ref    logic s_trstn,
         ref    logic s_tdi,
         ref    logic s_tdo
      );

         logic [1:0]         dm_op;
         logic [31:0]        dm_data;
         logic [6:0]         dm_addr;

         //NOTE sbreadonaddr must be 1

         //Write the Address
         this.set_dmi(
            2'b10,        //write
            7'h39,        //sbaddress0,
            addr_i,       //address
            {dm_addr, dm_data, dm_op},
            s_tck,
            s_tms,
            s_trstn,
            s_tdi,
            s_tdo
         );

         this.set_dmi(
            2'b10,        //write
            7'h3C,        //sbdata0,
            data_i,      //data_i
            {dm_addr, dm_data, dm_op},
            s_tck,
            s_tms,
            s_trstn,
            s_tdi,
            s_tdo
         );

      endtask


      task load_L2(
         input int   num_stim,
         ref   logic [95:0] stimuli [100000:0],
         ref   logic s_tck,
         ref   logic s_tms,
         ref   logic s_trstn,
         ref   logic s_tdi,
         ref   logic s_tdo
      );

         logic [1:0][31:0]   jtag_data;
         logic [31:0]        jtag_addr;
         logic [31:0]        spi_addr;
         logic [31:0]        spi_addr_old;
         logic               more_stim = 1;
         logic [1:0]         dm_op;
         logic [31:0]        dm_data;
         logic [6:0]         dm_addr;

         spi_addr        = stimuli[num_stim][95:64]; // assign address
         jtag_data[0]    = stimuli[num_stim][63:0];  // assign data

         this.set_sbreadonaddr(1'b0, s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         this.set_sbautoincrement(1'b0, s_tck, s_tms, s_trstn, s_tdi, s_tdo);

         $display("[JTAG] Loading L2 with jtag interface");

         spi_addr_old = spi_addr - 32'h8;

         while (more_stim) begin // loop until we have no more stimuli

            jtag_addr = stimuli[num_stim][95:64];
            for (int i=0;i<256;i=i+2) begin
               spi_addr       = stimuli[num_stim][95:64]; // assign address
               jtag_data[0]   = stimuli[num_stim][31:0];  // assign data
               jtag_data[1]   = stimuli[num_stim][63:32]; // assign data

               if (spi_addr != (spi_addr_old + 32'h8))
                  begin
                     spi_addr_old = spi_addr - 32'h8;
                     break;
                  end
               else begin
                  num_stim = num_stim + 1;
               end
               if (num_stim > $size(stimuli) || stimuli[num_stim]===96'bx ) begin // make sure we have more stimuli
                  more_stim = 0;                    // if not set variable to 0, will prevent additional stimuli to be applied
                  break;
               end
               spi_addr_old = spi_addr;

               this.set_dmi(
                  2'b10,           //write
                  7'h39,           //sbaddress0,
                  spi_addr[31:0], //bootaddress
                  {dm_addr, dm_data, dm_op},
                  s_tck,
                  s_tms,
                  s_trstn,
                  s_tdi,
                  s_tdo
               );

               this.set_dmi(
                  2'b10,           //write
                  7'h3C,           //sbdata0,
                  jtag_data[0],    //data
                  {dm_addr, dm_data, dm_op},
                  s_tck,
                  s_tms,
                  s_trstn,
                  s_tdi,
                  s_tdo
               );
               //$display("[JTAG] Loading L2 - Written %x at %x (%t)", jtag_data[0], spi_addr[31:0], $realtime);
               this.set_dmi(
                  2'b10,             //write
                  7'h39,             //sbaddress0,
                  spi_addr[31:0]+4, //bootaddress
                  {dm_addr, dm_data, dm_op},
                  s_tck,
                  s_tms,
                  s_trstn,
                  s_tdi,
                  s_tdo
               );

               this.set_dmi(
                  2'b10,           //write
                  7'h3C,           //sbdata0,
                  jtag_data[1],    //data
                  {dm_addr, dm_data, dm_op},
                  s_tck,
                  s_tms,
                  s_trstn,
                  s_tdi,
                  s_tdo
               );
            end
            $display("[JTAG] Loading L2 - Written up to %x (%t)", spi_addr[31:0]+4, $realtime);

         end
         this.set_sbreadonaddr(1'b1, s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         this.set_sbautoincrement(1'b0, s_tck, s_tms, s_trstn, s_tdi, s_tdo);

      endtask

      // discover harts by writting all ones to hartsel and reading it back
      task test_discover_harts(
         output logic        error,
         ref logic           s_tck,
         ref logic           s_tms,
         ref logic           s_trstn,
         ref logic           s_tdi,
         ref logic           s_tdo
      );

         logic [1:0]         dmi_op;
         logic [31:0]        dmi_data;
         logic [31:0]        dmi_command;
         logic [6:0]         dmi_addr;

         error = 1'b0;


         this.read_debug_reg(
            dm::DMControl,
            dmi_data,
            s_tck,
            s_tms,
            s_trstn,
            s_tdi,
            s_tdo
         );
         dmi_data[25:16] = 10'h3ff;
         dmi_data[15: 6] = 10'h3ff;

         this.write_debug_reg(
            dm::DMControl,
            dmi_data,
            s_tck,
            s_tms,
            s_trstn,
            s_tdi,
            s_tdo
         );

         this.read_debug_reg(
            dm::DMControl,
            dmi_data,
            s_tck,
            s_tms,
            s_trstn,
            s_tdi,
            s_tdo
         );

         $display("[TB] %t discovered harts %x",
                  $realtime, {dmi_data[15:6],dmi_data[25:16]});
         // TODO: return error by comparing to constant
      endtask


     // access csr, gpr by means of abstract command
      task test_gpr_read_write_abstract(
         output logic        error,
         ref logic           s_tck,
         ref logic           s_tms,
         ref logic           s_trstn,
         ref logic           s_tdi,
         ref logic           s_tdo
      );

         logic [1:0]         dmi_op;
         logic [31:0]        dmi_data;
         logic [31:0]        dmi_command;
         logic [6:0]         dmi_addr;

         error = 1'b0;

         //write beefdead into data0
         this.writeArg(
            0,
            32'hbeefdead,
            s_tck,
            s_tms,
            s_trstn,
            s_tdi,
            s_tdo
         );

         //Copy data0 to each register from x2 to x31 (abstract command)
         for (logic [15:0] regno = 16'h1002; regno < 16'h1020; regno=regno+1) begin
            dmi_data = {8'h0, 1'b0, 3'd2, 1'b0, 1'b0, 1'b1, 1'b1, regno};
               this.set_command(
                  dmi_data,
                  s_tck,
                  s_tms,
                  s_trstn,
                  s_tdi,
                  s_tdo
               );
         end

         // write ffff_ffff in data0 (some random value so that we can determine
         // whether we really load something form the gprs into data0 or if its
         // just the value from before)
         this.writeArg(
            0,
            32'hffff_ffff,
            s_tck,
            s_tms,
            s_trstn,
            s_tdi,
            s_tdo
         );

         for (logic [15:0] regno = 16'h1002; regno < 16'h1020; regno=regno+1) begin
            dmi_data = {8'h0, 1'b0, 3'd2, 1'b0, 1'b0, 1'b1, 1'b1, regno};
            this.set_command(
               dmi_data,
               s_tck,
               s_tms,
               s_trstn,
               s_tdi,
               s_tdo
            );
               // load regno into data0
            dmi_command = {8'h0, 1'b0, 3'd2, 1'b0, 1'b0, 1'b1, 1'b0, regno};
            this.set_command(
               dmi_command,
               s_tck,
               s_tms,
               s_trstn,
               s_tdi,
               s_tdo
            );


            // this command was tested separately to work
            // get out data0
            this.set_dmi(
               2'b01, //read
               7'h04, //data0
               32'h0, //whatever
               {dmi_addr, dmi_data, dmi_op},
               s_tck,
               s_tms,
               s_trstn,
               s_tdi,
               s_tdo
            );

            assert(dmi_data === 'hbeefdead)
                else begin
                   $error("expected %x, received %x in gpr %x",
                          'hbeefdead, dmi_data, regno);
                   error = 1'b1;
                end
         end

      endtask

      // access csr, gpr by means of abstract command in this version we employ
      // our precise read and write commands which closely follow what is
      // recommended in the debug spec
      task test_gpr_read_write_abstract_high_level(
         output logic        error,
         ref logic           s_tck,
         ref logic           s_tms,
         ref logic           s_trstn,
         ref logic           s_tdi,
         ref logic           s_tdo
      );

         logic [1:0]         dmi_op;
         logic [31:0]        dmi_data;
         logic [31:0]        dmi_command;
         logic [6:0]         dmi_addr;

         error = 1'b0;

         assert_rdy_for_abstract_cmd(s_tck, s_tms, s_trstn, s_tdi, s_tdo);

         //Copy data0 to each register from x2 to x31 (abstract command)
         for (logic [15:0] regno = 16'h1002; regno < 16'h1020; regno=regno+1) begin
             this.write_reg_abstract_cmd(
                 regno,
                 32'hbeefdead, // TODO: want different values for regs
                 s_tck,
                 s_tms,
                 s_trstn,
                 s_tdi,
                 s_tdo
             );

         end

         // write ffff_ffff in data0 (some random value so that we can determine
         // whether we really load something form the gprs into data0 or if its
         // just the value from before)
         this.write_debug_reg(
             dm::Data0,
             32'hffff_ffff,
             s_tck,
             s_tms,
             s_trstn,
             s_tdi,
             s_tdo
         );

         for (logic [15:0] regno = 16'h1002; regno < 16'h1020; regno=regno+1) begin
            read_reg_abstract_cmd(
               regno,
               dmi_data,
               s_tck,
               s_tms,
               s_trstn,
               s_tdi,
               s_tdo
            );
            assert(dmi_data === 'hbeefdead)
                else begin
                   $error("expected %x, received %x in gpr %x",
                          'hbeefdead, dmi_data, regno);
                   error = 1'b1;
                end
         end

      endtask


      task test_wfi_in_program_buffer(
         output logic error,
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         ref logic s_tdo
      );

         logic [31:0]        dm_data;
         this.write_debug_reg(
            dm::ProgBuf0,
            riscv::wfi(), //wfi
            s_tck,
            s_tms,
            s_trstn,
            s_tdi,
            s_tdo
         );

         this.write_debug_reg(
            dm::ProgBuf0 + 1, //progrbuff1
            riscv::ebreak(), //ebreak
            s_tck,
            s_tms,
            s_trstn,
            s_tdi,
            s_tdo
         );
         //execute the program buffer
         dm_data = {8'h0, 1'b0, 3'd2, 1'b0, 1'b1, 1'b0, 1'b0, 16'h0};

         this.set_command(
              dm_data,
              s_tck,
              s_tms,
              s_trstn,
              s_tdi,
              s_tdo
              );
         error = 1'b0;
      endtask


      task testAbstractsCommands_andProgramBuffer(
         output logic error,
         input logic [31:0] address_i,
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         ref logic s_tdo
      );

         logic [1:0]         dm_op;
         logic [31:0]        dm_data;
         logic [6:0]         dm_addr;
         logic [31:0]        key_word = 32'hda41de;

         //write key_word in data0
         this.writeArg(
            0,
            key_word,
            s_tck,
            s_tms,
            s_trstn,
            s_tdi,
            s_tdo
         );

         //Copy data0 to each register from x2 to x31 by means of Access Register abstract commands
         for (logic [15:0] regno = 16'h1002; regno < 16'h1020; regno=regno+1) begin
            dm_data = {8'h0, 1'b0, 3'd2, 1'b0, 1'b0, 1'b1, 1'b1, regno};

               this.set_command(
                  dm_data,
                  s_tck,
                  s_tms,
                  s_trstn,
                  s_tdi,
                  s_tdo
               );
            //$display("[TB] %t Access Register at regno %d",$realtime(), regno[4:0]);

         end

         //Put address_i is x1 by writing it to data0 and then Access Register
         this.writeArg(
            0,
            address_i,
            s_tck,
            s_tms,
            s_trstn,
            s_tdi,
            s_tdo
         );
         dm_data = {8'h0, 1'b0, 3'd2, 1'b0, 1'b0, 1'b1, 1'b1, 16'h1001};
         this.set_command(
            dm_data,
            s_tck,
            s_tms,
            s_trstn,
            s_tdi,
            s_tdo
         );

         //increase every registers x2-x31 by 2-31  store them to *(x1++)
         for (logic [15:0] regno = 16'h1002; regno < 16'h1020; regno=regno+1) begin

               this.writePrgramBuff (
                  0, //progrbuff0
                  { 7'h0, regno[4:0], regno[4:0], 3'b000, regno[4:0], 7'h13 }, // addi xi, xi, i
                  s_tck,
                  s_tms,
                  s_trstn,
                  s_tdi,
                  s_tdo
               );

               this.writePrgramBuff (
                  1, //progrbuff1
                  { 7'h0, regno[4:0], 5'h1, 1'b0, 2'b10, 5'h0, 7'h23 }, //sw xi, 0(x1)
                  s_tck,
                  s_tms,
                  s_trstn,
                  s_tdi,
                  s_tdo
               );

               this.writePrgramBuff (
                  2, //progrbuff2
                  { 12'h4, 5'h1, 3'b000, 5'h1, 7'h13 }, // addi x1, x1, 4
                  s_tck,
                  s_tms,
                  s_trstn,
                  s_tdi,
                  s_tdo
               );

               this.writePrgramBuff (
                  3, //progrbuff3
                  { 32'h00100073 }, //ebreak
                  s_tck,
                  s_tms,
                  s_trstn,
                  s_tdi,
                  s_tdo
               );
               //execute the program buffer
               dm_data = {8'h0, 1'b0, 3'd2, 1'b0, 1'b1, 1'b0, 1'b0, 16'h0};

               this.set_command(
                  dm_data,
                  s_tck,
                  s_tms,
                  s_trstn,
                  s_tdi,
                  s_tdo
               );
               //$display("[TB] %t Store of the value in reg %d",$realtime(), regno[4:0]);
         end

         //Now read them from memory the previous store values

         error = 1'b0;
         for (int incAddr = 2; incAddr < 32; incAddr=incAddr+1) begin
            this.readMem(address_i + (incAddr-2)*4, dm_data, s_tck, s_tms, s_trstn, s_tdi, s_tdo);
            // $display("[TB] %t Read %x from %x",$realtime(), dm_data, address_i + (incAddr-2)*4);
            if(dm_data !== key_word + incAddr) begin
               error = 1'b1;
               $display("[TB - AbstractsCommands_andProgramBuffer] %t Read %x from %x instead of %x",$realtime(), dm_data, address_i + (incAddr-2)*4, key_word + incAddr);
            end
         end

      endtask


      task test_abstract_cmds_prog_buf(
         output logic error,
         input logic [31:0] address_i,
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         ref logic s_tdo
      );

         logic [1:0]         dm_op;
         logic [31:0]        dm_data;
         logic [6:0]         dm_addr;
         logic [31:0]        key_word = 32'hda41de;

         //write key_word in data0
         this.write_debug_reg(
            dm::Data0,
            key_word,
            s_tck,
            s_tms,
            s_trstn,
            s_tdi,
            s_tdo
         );

         assert_rdy_for_abstract_cmd(s_tck, s_tms, s_trstn, s_tdi, s_tdo);

         //Copy data0 to each register from x2 to x31 by means of Access Register abstract commands
         for (logic [15:0] regno = 16'h1002; regno < 16'h1020; regno=regno+1) begin
            dm_data = {8'h0, 1'b0, 3'd2, 1'b0, 1'b0, 1'b1, 1'b1, regno};

               this.set_command(
                  dm_data,
                  s_tck,
                  s_tms,
                  s_trstn,
                  s_tdi,
                  s_tdo
               );
            //$display("[TB] %t Access Register at regno %d",$realtime(), regno[4:0]);

         end

         //Put address_i is x1 by writing it to data0 and then Access Register
         this.write_debug_reg(
            dm::Data0,
            address_i,
            s_tck,
            s_tms,
            s_trstn,
            s_tdi,
            s_tdo
         );

         dm_data = {8'h0, 1'b0, 3'd2, 1'b0, 1'b0, 1'b1, 1'b1, 16'h1001};
         this.set_command(
            dm_data,
            s_tck,
            s_tms,
            s_trstn,
            s_tdi,
            s_tdo
         );

         //increase every registers x2-x31 by 2-31  store them to *(x1++)
         for (logic [15:0] regno = 16'h1002; regno < 16'h1020; regno=regno+1) begin
               this.write_debug_reg(
                  dm::ProgBuf0,
                  { 7'h0, regno[4:0], regno[4:0], 3'b000, regno[4:0], 7'h13 }, // addi xi, xi, i
                  s_tck,
                  s_tms,
                  s_trstn,
                  s_tdi,
                  s_tdo
               );

               this.write_debug_reg(
                  dm::ProgBuf0 + 1,
                  riscv::store(3'b010, regno[4:0], 5'h1, 12'h0), // sw xi, 0(x1)
                  //{ 7'h0, regno[4:0], 5'h1, 1'b0, 2'b10, 5'h0, 7'h23 },
                  s_tck,
                  s_tms,
                  s_trstn,
                  s_tdi,
                  s_tdo
               );

               this.write_debug_reg(
                  dm::ProgBuf0 + 2,
                  { 12'h4, 5'h1, 3'b000, 5'h1, 7'h13 }, // addi x1, x1, 4
                  s_tck,
                  s_tms,
                  s_trstn,
                  s_tdi,
                  s_tdo
               );

               this.write_debug_reg(
                  dm::ProgBuf0 + 3,
                  riscv::ebreak(), //ebreak
                  s_tck,
                  s_tms,
                  s_trstn,
                  s_tdi,
                  s_tdo
               );
               //execute the program buffer
               dm_data = {8'h0, 1'b0, 3'd2, 1'b0, 1'b1, 1'b0, 1'b0, 16'h0};

               this.set_command(
                  dm_data,
                  s_tck,
                  s_tms,
                  s_trstn,
                  s_tdi,
                  s_tdo
               );
               //$display("[TB] %t Store of the value in reg %d",$realtime(), regno[4:0]);
         end

         //Now read them from memory the previous store values

         error = 1'b0;
         for (int incAddr = 2; incAddr < 32; incAddr=incAddr+1) begin
            this.readMem(address_i + (incAddr-2)*4, dm_data, s_tck, s_tms, s_trstn, s_tdi, s_tdo);
            // $display("[TB] %t Read %x from %x",$realtime(), dm_data, address_i + (incAddr-2)*4);
            assert(dm_data === key_word + incAddr)
                else begin
                   $error("read %x from %x instead of %x",
                          dm_data, address_i + (incAddr-2)*4, key_word + incAddr);
                   error = 1'b1;
                end
         end

      endtask


      task test_read_write_dpc(
         output logic error,
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         ref logic s_tdo
      );

         logic [1:0]         dm_op;
         logic [31:0]        dm_data;
         logic [31:0]        saved;
         logic [6:0]         dm_addr;
         logic [31:0]        key_word = 32'hbeefdead;

         error = 1'b0;

         assert_rdy_for_abstract_cmd(s_tck, s_tms, s_trstn, s_tdi, s_tdo);

         this.read_reg_abstract_cmd(
             riscv::CSR_DPC,
             saved,
             s_tck,
             s_tms,
             s_trstn,
             s_tdi,
             s_tdo
         );

         this.write_reg_abstract_cmd(
             riscv::CSR_DPC,
             key_word,
             s_tck,
             s_tms,
             s_trstn,
             s_tdi,
             s_tdo
         );

         this.read_reg_abstract_cmd(
             riscv::CSR_DPC,
             dm_data,
             s_tck,
             s_tms,
             s_trstn,
             s_tdi,
             s_tdo
         );

         assert(key_word === dm_data)
             else begin
                $error("read %x instead of %x", dm_data, key_word);
                error = 1'b1;
             end;

         this.write_reg_abstract_cmd(
             riscv::CSR_DPC,
             saved,
             s_tck,
             s_tms,
             s_trstn,
             s_tdi,
             s_tdo
         );

      endtask


      task test_single_stepping_abstract_cmd(
         output logic error,
         input logic [31:0] addr_i,
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         ref logic s_tdo
      );

         logic [1:0]         dm_op;
         logic [31:0]        dm_data;
         riscv::dcsr_t       dcsr;
         dm::dmstatus_t      dmstatus;
         logic [6:0]         dm_addr;

         error = 1'b0;

        // check if our hart is halted
         this.read_debug_reg(dm::DMStatus, dmstatus,
                             s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         assert(dmstatus.allhalted == 1'b1)
             else begin
                $error("allhalted flag is not set when entering test");
                error = 1'b1;
             end

         // write short program to single step through
         this.writeMem(addr_i, { 7'h0, 5'b1, 5'b1, 3'b000, 5'b1, 7'h13 },  // addi xi, xi, i
                       s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         this.writeMem(addr_i + 4, { 7'h0, 5'b1, 5'b1, 3'b000, 5'b1, 7'h13 },  // addi xi, xi, i
                       s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         this.writeMem(addr_i + 8, { 7'h0, 5'b1, 5'b1, 3'b000, 5'b1, 7'h13 }, // addi xi, xi, i
                       s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         this.writeMem(addr_i + 12, { 7'h0, 5'b1, 5'b1, 3'b000, 5'b1, 7'h13 }, // addi xi, xi, i
                       s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         this.writeMem(addr_i + 16, {20'b0, 5'b0, 7'b1101111}, // J zero offset
                       s_tck, s_tms, s_trstn, s_tdi, s_tdo);

         assert_rdy_for_abstract_cmd(s_tck, s_tms, s_trstn, s_tdi, s_tdo);

         // set step flag in dcsr
         this.read_reg_abstract_cmd(riscv::CSR_DCSR, dcsr,
                                    s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         dcsr.step = 1;
         this.write_reg_abstract_cmd(riscv::CSR_DCSR, dcsr,
                                     s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         this.read_reg_abstract_cmd(riscv::CSR_DCSR, dcsr,
                                    s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         assert(dcsr.step == 1)
             else begin
                $error("couldn't enter single stepping mode");
                error = 1'b1;
             end;

         // write dpc to addr_i so that we know where we resume
         this.write_reg_abstract_cmd(riscv::CSR_DPC, addr_i,
                                     s_tck, s_tms, s_trstn, s_tdi, s_tdo);

         this.read_reg_abstract_cmd(riscv::CSR_DPC, dm_data, s_tck, s_tms,
                                    s_trstn, s_tdi, s_tdo);

         for (int i = 1; i < 4; i++) begin
            // Make a single step. Like openocd we halt the hart manually even
            // though it might suffice to just check if allhalted is set.
            this.resume_harts(s_tck, s_tms, s_trstn, s_tdi, s_tdo);
            this.halt_harts(s_tck, s_tms, s_trstn, s_tdi, s_tdo);
            // this.block_until_any_halt(s_tck, s_tms, s_trstn, s_tdi, s_tdo);

            this.read_reg_abstract_cmd(riscv::CSR_DPC, dm_data,
                                       s_tck, s_tms, s_trstn, s_tdi, s_tdo);
            // check if dpc, dcause and flag bits are ok
            assert(addr_i + 4*i === dm_data) // did dpc increment?
                else begin
                   $error("dpc is %x, expected %x", dm_data, addr_i + 4);
                   error = 1'b1;
                end;
            this.read_reg_abstract_cmd(riscv::CSR_DCSR, dcsr,
                                       s_tck, s_tms, s_trstn, s_tdi, s_tdo);
            assert(3'h4 === dcsr.cause) // is cause properly given as "step"?
                else begin
                   $error("debug cause is %x, expected %x", dcsr.cause, 3'h4);
                   error = 1'b1;
                end;
         end

         // clear step flag in dcsr
         this.read_reg_abstract_cmd(riscv::CSR_DCSR, dcsr,
                                    s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         dcsr.step = 0;
         this.write_reg_abstract_cmd(riscv::CSR_DCSR, dcsr,
                                     s_tck, s_tms, s_trstn, s_tdi, s_tdo);


      endtask


      task test_single_stepping_edge_cases(
         output logic error,
         input logic [31:0] addr_i,
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         ref logic s_tdo
      );

         logic [1:0]         dm_op;
         logic [31:0]        dm_data;
         riscv::dcsr_t       dcsr;
         dm::dmstatus_t      dmstatus;
         logic [6:0]         dm_addr;
         // records the sequence of expected pc changes
         int                 pc_offsets[];

         error = 1'b0;

        // check if our hart is halted
         this.read_debug_reg(dm::DMStatus, dmstatus,
                             s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         assert(dmstatus.allhalted == 1'b1)
             else begin
                $error("allhalted flag is not set when entering test");
                error = 1'b1;
             end

         // write short program to single step through
         pc_offsets = {4, 8, 16, 20, 24, 28, 32};
         this.writeMem(addr_i + 0, riscv::nop(),
                       s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         this.writeMem(addr_i + 4, riscv::nop(),
                       s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         this.writeMem(addr_i + 8, riscv::branch(5'h0, 5'h0, 3'b0, 12'h4), // branch to + 16
                       s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         this.writeMem(addr_i + 12, riscv::nop(),
                       s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         this.writeMem(addr_i + 16, { 7'h0, 5'b1, 5'b1, 3'b000, 5'b1, 7'h13 }, // addi xi, xi, i
                       s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         this.writeMem(addr_i + 20, { 7'h0, 5'b1, 5'b1, 3'b000, 5'b1, 7'h13 }, // addi xi, xi, i
                       s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         this.writeMem(addr_i + 24, riscv::wfi(), // step over wfi
                       s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         this.writeMem(addr_i + 28, { 7'h0, 5'b1, 5'b1, 3'b000, 5'b1, 7'h13 }, // addi xi, xi, i
                       s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         this.writeMem(addr_i + 32, {20'b0, 5'b0, 7'b1101111}, // J zero offset
                       s_tck, s_tms, s_trstn, s_tdi, s_tdo);


         assert_rdy_for_abstract_cmd(s_tck, s_tms, s_trstn, s_tdi, s_tdo);

         // set step flag in dcsr
         this.read_reg_abstract_cmd(riscv::CSR_DCSR, dcsr,
                                    s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         dcsr.step = 1;
         this.write_reg_abstract_cmd(riscv::CSR_DCSR, dcsr,
                                     s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         this.read_reg_abstract_cmd(riscv::CSR_DCSR, dcsr,
                                    s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         assert(dcsr.step == 1)
             else begin
                $error("couldn't enter single stepping mode");
                error = 1'b1;
             end;

         // write dpc to addr_i so that we know where we resume
         this.write_reg_abstract_cmd(riscv::CSR_DPC, addr_i,
                                     s_tck, s_tms, s_trstn, s_tdi, s_tdo);

         this.read_reg_abstract_cmd(riscv::CSR_DPC, dm_data, s_tck, s_tms,
                                    s_trstn, s_tdi, s_tdo);

         for (int i = 0; i < $size(pc_offsets); i++) begin
            // Make a single step. Like openocd we halt the hart manually even
            // though it might suffice to just check if allhalted is set.
            this.resume_harts(s_tck, s_tms, s_trstn, s_tdi, s_tdo);
            this.halt_harts(s_tck, s_tms, s_trstn, s_tdi, s_tdo);
            // this.block_until_any_halt(s_tck, s_tms, s_trstn, s_tdi, s_tdo);

            this.read_reg_abstract_cmd(riscv::CSR_DPC, dm_data,
                                       s_tck, s_tms, s_trstn, s_tdi, s_tdo);
            // check if dpc, dcause and flag bits are ok
            assert(addr_i + pc_offsets[i] === dm_data) // did dpc increment?
                else begin
                   $error("dpc is %x, expected %x", dm_data, addr_i + pc_offsets[i]);
                   error = 1'b1;
                end;
            this.read_reg_abstract_cmd(riscv::CSR_DCSR, dcsr,
                                       s_tck, s_tms, s_trstn, s_tdi, s_tdo);
            assert(3'h4 === dcsr.cause) // is cause properly given as "step"?
                else begin
                   $error("debug cause is %x, expected %x", dcsr.cause, 3'h4);
                   error = 1'b1;
                end;
         end

         // clear step flag in dcsr
         this.read_reg_abstract_cmd(riscv::CSR_DCSR, dcsr,
                                    s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         dcsr.step = 0;
         this.write_reg_abstract_cmd(riscv::CSR_DCSR, dcsr,
                                     s_tck, s_tms, s_trstn, s_tdi, s_tdo);


      endtask



      task test_halt_resume(
         output logic error,
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         ref logic s_tdo
      );
         dm::dmstatus_t dmstatus;
         error = 1'b0;

         // check if our hart is halted
         this.read_debug_reg(dm::DMStatus, dmstatus,
                             s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         assert(dmstatus.allhalted == 1'b1)
             else begin
                $error("allhalted flag is not set when entering test");
                error = 1'b1;
             end

         // resume core and check flags
         this.resume_harts(s_tck, s_tms, s_trstn, s_tdi, s_tdo);

         this.read_debug_reg(dm::DMStatus, dmstatus,
                             s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         assert(dmstatus.allrunning == 1'b1)
             else begin
                $error("allrunning flag is not set after resume request");
                error = 1'b1;
             end

         // halt core and check flags
         this.halt_harts(s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         this.read_debug_reg(dm::DMStatus, dmstatus,
                             s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         assert(dmstatus.allhalted == 1'b1)
             else begin
                $error("allhalted flag is not set after halt request");
                error = 1'b1;
             end

      endtask


   endclass

endpackage

// Local Variables:
// verilog-indent-level: 3
// End:
