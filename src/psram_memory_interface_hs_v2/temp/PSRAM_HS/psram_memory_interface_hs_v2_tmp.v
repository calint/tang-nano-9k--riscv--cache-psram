//Copyright (C)2014-2024 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//Tool Version: V1.9.9.03 (64-bit)
//Part Number: GW1NR-LV9QN88PC6/I5
//Device: GW1NR-9
//Device Version: C
//Created Time: Sun Jun 16 19:59:12 2024

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

	PSRAM_Memory_Interface_HS_V2_Top your_instance_name(
		.clk_d(clk_d), //input clk_d
		.memory_clk(memory_clk), //input memory_clk
		.memory_clk_p(memory_clk_p), //input memory_clk_p
		.pll_lock(pll_lock), //input pll_lock
		.rst_n(rst_n), //input rst_n
		.O_psram_ck(O_psram_ck), //output [1:0] O_psram_ck
		.O_psram_ck_n(O_psram_ck_n), //output [1:0] O_psram_ck_n
		.IO_psram_dq(IO_psram_dq), //inout [15:0] IO_psram_dq
		.IO_psram_rwds(IO_psram_rwds), //inout [1:0] IO_psram_rwds
		.O_psram_cs_n(O_psram_cs_n), //output [1:0] O_psram_cs_n
		.O_psram_reset_n(O_psram_reset_n), //output [1:0] O_psram_reset_n
		.wr_data(wr_data), //input [63:0] wr_data
		.rd_data(rd_data), //output [63:0] rd_data
		.rd_data_valid(rd_data_valid), //output rd_data_valid
		.addr(addr), //input [20:0] addr
		.cmd(cmd), //input cmd
		.cmd_en(cmd_en), //input cmd_en
		.init_calib(init_calib), //output init_calib
		.clk_out(clk_out), //output clk_out
		.data_mask(data_mask) //input [7:0] data_mask
	);

//--------Copy end-------------------
