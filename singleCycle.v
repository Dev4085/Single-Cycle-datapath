
module singleCycle(clk,reset,writeData);
	input clk,reset;	// clock period = 100ns
	output [31:0] writeData;
	wire [31:0]PC,PC_in; // input to the program counter
	assign PC = PC_in;
	//initial PC = 0;

	wire [31:0]PC_out; // program counter output
	programCounter F0(clk,reset,PC,PC_out);

	wire [31:0]PC_4_out;// program counter + 4
	assign PC_4_out = PC_out + 4;

	wire [31:0]instruction;	// conntains the instruction to be executed
	instructionMemory F1(reset,PC_out,instruction);	// fetches the instruction

	wire [31:0]jumpAddress;	// contains address of jump instruction
	shiftLeft_jump F2(instruction[25:0],PC_4_out[31:28],jumpAddress); // module for finding jump address

	wire regDst,jump,branch,memRead,memToReg,memWrite,ALUSrc,regWrite;	// control signals
	wire [1:0]ALUOp;	// control signal
	// module for determining state of control signal
	controlSignal F3(instruction[31:26],regDst,jump,branch,memRead,memToReg,ALUOp,memWrite,ALUSrc,regWrite);

	wire [4:0]writeRegister;
	// write register selection mux
	regDst_mux F4(instruction[20:16],instruction[15:11],regDst,writeRegister);

	wire [31:0]readData1,readData2;
	//module for read register block
	readRegister F5(clk,reset,regWrite,instruction[25:21],instruction[20:16],writeRegister,readData1,readData2,writeData);

	wire [31:0]signExtendedData;
	// sign extends instruction[15:0] to 32 bits
	signExtend F6(instruction[15:0],signExtendedData);

	wire [31:0]branchOffset;	// sign extended branch offset
	wire [31:0]branchAddress;
	assign branchOffset = {signExtendedData<<2}; // multiplies offset by four
	assign branchAddress = branchOffset + PC_4_out; // address after branching

	wire [31:0]ALUinput; // contains read data 2 value or sign extended data value
	ALUSrc_mux F7(readData2,signExtendedData,ALUSrc,ALUinput);

	wire [3:0]ALUcontrolOutput; // output of ALU control unit
	ALUcontrolUnit F8(ALUOp,instruction[5:0],ALUcontrolOutput);

	wire [31:0]ALUresult; // ALU output
	wire zero;	// zero = 1, if sub operation gives output zero
	ALU F9(readData1,ALUinput,ALUcontrolOutput,ALUresult,zero);

	wire [31:0]PC_in0;	// output of branch mux
	wire temp = branch & zero;	// control signal for mux
	branch_mux F10(PC_4_out,branchAddress,temp,PC_in0);

	wire [31:0]readData; // output of data memory
	dataMemory F11(reset,ALUresult,readData2,memRead,memWrite,readData);

	jump_mux F12(PC_in0,jumpAddress,jump,PC_in); // jump selection mux
	
	// module selects data to be written back to the register
	memToReg_mux F13(readData,ALUresult,memToReg,writeData);

endmodule

module programCounter(clk,reset,PC_in,PC_out);
	input clk,reset;
	input [31:0]PC_in;
	output reg [31:0]PC_out;

	always @(posedge clk or posedge reset) begin
		if(reset == 1) begin	// resets the cycle
			PC_out = 0;
		end else begin
			PC_out = PC_in;	
		end
	end
endmodule

//module for fetching instruction
module instructionMemory(reset,readAddress,instruction);
	input reset;
	input [31:0]readAddress; // PC counter pointing address
	output [31:0]instruction; // instruction corresponding to the address
	reg [31:0]memory[63:0]; // instruction memory
	wire [31:0]shiftedReadAddress;
	integer k;

	// memory for this code increments by 1 because 32 bit memory
	assign shiftedReadAddress = {readAddress>>2}; // divide by 4
	assign instruction = memory[shiftedReadAddress];
	
	always @(posedge reset) begin
		for (k=4; k<64; k=k+1) begin// here Ou changes k=0 to k=16
			memory[k] = 8'b0;
		end
		if(reset == 1) begin
			memory[0] = 32'b00100000000010000000000000100000; //addi $t0, $zero, 32 
			memory[1] = 32'b00100000000010010000000000110111; //addi $t1, $zero, 55 
			memory[2] = 32'b00000001000010011000000000100000; //add $s0, $t0, $t1 
			memory[3] = 32'b00000001000010011000100000100010; //sub $s1, $t0, $t1 
			memory[4] = 32'b00000001000010011001000000100100; //and $s2, $t0, $t1 
			memory[5] = 32'b00000001000010011001100000100101; //or $s3, $t0, $t1 
			memory[6] = 32'b00000001000010011010000000101010; //slt $s4, $t0, $t1 (Loop) 
			memory[7] = 32'b00010010100000000000000000000110; //beq $s4, $0, EXIT 
			memory[8] = 32'b00000001000010010101000000100000; //add $t2, $t0, $t1 
			memory[9] = 32'b00000001010010010101000000100000; //add $t2, $t2, $t1 
			memory[10] =32'b00000001010010000101100000100000; //add $t3, $t2, $t0
			memory[11] =32'b10001100000101010000000000000100; // lw $s5,4($zero)
			memory[12] =32'b00000001010101011011000000100000; //add $s6,$t2,$s5
			memory[13] =32'b00000010101010111011100000100000; //add $s7,$s5,$t3
			memory[14] =32'b00100000000101010000000000001000; //addi$s5,$zero,8
			memory[15] = 32'b10101100000101010000000000001000; //sw $s5,8($zero) (Exit)
			memory[16] =32'b00001000000000000000000000000110; // j Loop
		end
	end
endmodule

// module for finding jump address for jump instruction
module shiftLeft_jump(instruction,PC_4_out,jumpAddress);
	input [25:0]instruction;
	input [3:0]PC_4_out;
	output [31:0]jumpAddress;

	wire [27:0]temp;

	assign temp[27:2] = instruction; // shifted instruction by two bits
	assign temp[1:0] = 0;
	assign jumpAddress[31:28] = PC_4_out; 
	assign jumpAddress[27:0] = temp;	// address for jump instruction

endmodule
// module for determining state of control signal using PLA
module controlSignal(opcode,regDst,jump,branch,memRead,memToReg,ALUOp,memWrite,ALUSrc,regWrite);
	input [5:0]opcode;
	output regDst,jump,branch,memRead,memToReg,memWrite,ALUSrc,regWrite;
	output [1:0]ALUOp;

	assign regDst = ((~opcode[5])&(~opcode[4])&(~opcode[3])&(~opcode[2])&(~opcode[1])&(~opcode[0]));
	assign jump = ((~opcode[5])&(~opcode[4])&(~opcode[3])&(~opcode[2])&(opcode[1])&(~opcode[0]));
	assign branch = ((~opcode[5])&(~opcode[4])&(~opcode[3])&(opcode[2])&(~opcode[1])&(~opcode[0]));
	assign memRead = ((opcode[5])&(~opcode[4])&(~opcode[3])&(~opcode[2])&(opcode[1])&(opcode[0]));
	assign memToReg = memRead;
	assign ALUOp[0] = branch;
	assign ALUOp[1] = ((~opcode[5])&(~opcode[4])&(~opcode[3])&(~opcode[2])&(~opcode[1])&(~opcode[0]));
	assign memWrite = ((opcode[5])&(~opcode[4])&(opcode[3])&(~opcode[2])&(opcode[1])&(opcode[0]));
	assign ALUSrc = ((opcode[5])&(~opcode[4])&(~opcode[3])&(~opcode[2])&(opcode[1])&(opcode[0])) | ((opcode[5])&(~opcode[4])&(opcode[3])&(~opcode[2])&(opcode[1])&(opcode[0])) | ((~opcode[5])&(~opcode[4])&(opcode[3])&(~opcode[2])&(~opcode[1])&(~opcode[0]));
	assign regWrite = ((opcode[5])&(~opcode[4])&(~opcode[3])&(~opcode[2])&(opcode[1])&(opcode[0])) | ((~opcode[5])&(~opcode[4])&(~opcode[3])&(~opcode[2])&(~opcode[1])&(~opcode[0])) | ((~opcode[5])&(~opcode[4])&(opcode[3])&(~opcode[2])&(~opcode[1])&(~opcode[0]));

endmodule

// selects from rt and rd for write register
module regDst_mux(rt,rd,regDst,writeRegister);
	input [4:0]rt,rd;
	input regDst;
	output reg [4:0]writeRegister;

	always @(*) begin
		if(regDst == 0) begin
			writeRegister = rt;
		end else begin
			writeRegister = rd;
		end
	end
endmodule

// module for register read and write
module readRegister(clk,reset,regWrite,readRegister1,readRegister2,writeRegister,readData1,readData2,writeData);
	input [4:0]readRegister1,readRegister2,writeRegister;	// register addresses
	input [31:0]writeData;	// data which is written back
	input clk,reset,regWrite;
	output [31:0]readData1,readData2;	// read data from the register

	reg [31:0]regFile[31:0]; // file containing data of registers S0-S7 and t0-t7
	// S0-S7, k = 16-23
	// t0-t7, k = 8-15
	integer k;

	assign readData1 = regFile[readRegister1];
	assign readData2 = regFile[readRegister2];

	always @(posedge clk or posedge reset) begin
		if(reset == 1) begin 
			for (k=0; k<32; k=k+1) 
			begin
				regFile[k] = 0;
			end
		end
		if(regWrite == 1 && reset == 0) begin
			regFile[writeRegister] = writeData;
		end
	end

endmodule

// module for sign extending instruction[15:0]
module signExtend(sign_in,signExtendedData);
	input [15:0]sign_in;
	output reg [31:0]signExtendedData;

	always @(*) begin
		signExtendedData[15:0] = sign_in;
		if(sign_in[15] == 0) begin	// positive number
			signExtendedData[31:16] = 0;
		end else begin	// negative number
			signExtendedData[31:16] = 16'b1111111111111111;
		end
	end
endmodule

//module for selecting between read data 2 and sign extended data
module ALUSrc_mux(readData2,signExtendedData,ALUSrc,ALUinput);
	input [31:0]readData2,signExtendedData;
	input ALUSrc;
	output reg [31:0]ALUinput;

	always @(*) begin
		if(ALUSrc == 0) begin
			ALUinput = readData2;
		end else begin
			ALUinput = signExtendedData;
		end
	end
	
endmodule

//module ALU control signal
module ALUcontrolUnit(ALUOp,funct,ALUcontrolOutput);
	input [1:0]ALUOp;
	input [5:0]funct; // instruction[5:0]
	output [3:0]ALUcontrolOutput;

	assign ALUcontrolOutput[3] = 0;
	assign ALUcontrolOutput[2] = ((~ALUOp[1])&(ALUOp[0])) | ((ALUOp[1])&(~ALUOp[0])&(~funct[3])&(~funct[2])&(funct[1])&(~funct[0])) | ((ALUOp[1])&(~ALUOp[0])&(funct[3])&(~funct[2])&(funct[1])&(~funct[0]));
	assign ALUcontrolOutput[1] = ((~ALUOp[1])&(~ALUOp[0])) | ((~ALUOp[1])&(ALUOp[0])) | ((ALUOp[1])&(~ALUOp[0])&(~funct[3])&(~funct[2])&(~funct[1])&(~funct[0])) | ((ALUOp[1])&(~ALUOp[0])&(~funct[3])&(~funct[2])&(funct[1])&(~funct[0])) | ((ALUOp[1])&(~ALUOp[0])&(funct[3])&(~funct[2])&(funct[1])&(~funct[0]));
	assign ALUcontrolOutput[0] = ((ALUOp[1])&(~ALUOp[0])&(~funct[3])&(funct[2])&(~funct[1])&(funct[0])) | ((ALUOp[1])&(~ALUOp[0])&(funct[3])&(~funct[2])&(funct[1])&(~funct[0]));

endmodule


module ALU(readData1,ALUinput,ALUcontrolOutput,ALUresult,zero);
	input [31:0]readData1,ALUinput;
	input [3:0]ALUcontrolOutput;	// ALU control signal
	output reg [31:0]ALUresult;	// ALU output
	output reg zero;	// zero = 1, if sub operation gives output zero

	always @(*) begin
		if(ALUcontrolOutput == 4'b0010) begin	// additon operation
			ALUresult = readData1 + ALUinput;
			zero = 0;
		end
		if(ALUcontrolOutput == 4'b0110) begin	// subtraction operation
			ALUresult = readData1 - ALUinput;	
			if(ALUresult == 0) begin	// ALU result = 0
				zero = 1;
			end else begin
				zero = 0;
			end
		end
		if(ALUcontrolOutput == 4'b0000) begin	// and operation
			ALUresult = readData1 & ALUinput;
			zero = 0;
		end
		if(ALUcontrolOutput == 4'b0001) begin	// or operatio
			ALUresult = readData1 | ALUinput;
			zero = 0;
		end
		if(ALUcontrolOutput == 4'b0111) begin	// set on less than operation
			zero = 0;
			if(readData1 > ALUinput) begin
				ALUresult = 0;
			end else begin
				ALUresult = 1;
			end
		end
	end
endmodule

// module for selection between branch address and PC+4
module branch_mux(PC_4_out,branchAddress,control,PC_in0);
	input [31:0]PC_4_out;
	input [31:0]branchAddress;
	input control;	// control =1, if beq instruction executed
	output reg [31:0]PC_in0;

	always @(*) begin
		if(control == 1) begin
			PC_in0 = branchAddress;
		end else begin
			PC_in0 = PC_4_out;
		end
	end
endmodule

//module for read/write of data memory
module dataMemory(reset,address,writeData,memRead,memWrite,readData);
	input [31:0]address,writeData;	// address = ALU result
	input memWrite,memRead;	// control signals
	input reset;
	output reg [31:0]readData;	// output of data memory
	wire [31:0]shiftAddress;

	// memory is of 32 bit
	assign shiftAddress = {address>>2}; //divide by 4
	integer k;

	reg [31:0]memory[127:0];	// memory file
	always @(*) begin
		if (reset == 1'b1) begin	// resets the memory
			for (k=0; k<128; k=k+1) begin
				memory[k] = 32'b0;
			end
		end
		if(reset == 0 && memRead == 1) begin
			readData = memory[shiftAddress];
		end
		if(reset == 0 && memWrite == 1) begin
			memory[shiftAddress] = writeData;
		end
	end
endmodule

//module for selection of jump instruction address
module jump_mux(PC_in0,jumpAddress,jump,PC_in);
	input [31:0]PC_in0;	
	input [31:0]jumpAddress;
	input jump;
	output reg [31:0]PC_in;

	always @(*) begin
		if(jump == 1) begin	// jump instruction is being executed
			PC_in = jumpAddress;
		end else begin	// not a jump instruction
			PC_in = PC_in0;
		end
	end
endmodule

// module for selecting write back data
module memToReg_mux(readData,ALUresult,memToReg,writeData);
	input [31:0]readData,ALUresult;
	input memToReg;
	output reg [31:0]writeData;

	always @(*) begin
		if(memToReg == 0) begin	// register data
			writeData = ALUresult;
		end else begin	// memory data
			writeData = readData;	
		end
	end
endmodule


module singleCycle_Testbench();
	reg clk;
	reg reset;
	wire [31:0]writeData;
	initial clk = 1;
	singleCycle uut (.clk(clk),.reset(reset),.writeData(writeData));
	initial begin
	reset = 1;
	#10;
	reset = 0;
	end
	always #50 clk = ~clk;
	
endmodule

