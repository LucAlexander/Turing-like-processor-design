module track(
	input reg [7:0] position,
	input write_flag,
	input interrupt_flag,
	input clk,
	output wire state
);
	parameter TRACK_LENGTH = 64;
	reg [TRACK_LENGTH-1:0] tape;

	initial begin
		tape = 44;
	end

	always @ (posedge clk) begin
		if (write_flag == 1)begin
			tape[position] = ~tape[position];
		end
		$display("\tTape:\n\t%b",tape);
	end
	assign state = tape[position];
endmodule;

module tb;
	/* instruction is 6 bits (more instructions to come)

	* bit 0 is instruction start

	* bits 1, 2 are for if the cell is 0
	* bits 3, 4 are for if the cell is 1

	* for the odd bits
		* 0: write 0
		* 1: write 1
		
	* for the even bits
		* 0: move left
		* 1: move right

	* bit 5 is instruction end
	*
	* modifier flips bit at pos when high 
	*
	* (NOTE)
	* 2 bit primitive opcode
	* 1 bit instruction start
	* 2 bit 0 case
	* 2 bit 1 case
	* 1 bit instruction end
	* happens to be 8 bits :)
	*
	* (NOTE)
	* 2 bit label instead of opcode
		* 2 bit 0 case
		* 	1 bit write
		* 	1 bit move
		* 2 bit 0 goto
		* 2 bit 1 case
		* 	1 bit write
		* 	1 bit move
		* 2 bit 1 goto
	* 10 bits
	*
		* state entry  [2] [8]
		* write if 0   [1] [7]
		* move if 0    [1] [6]
		* state exit 0 [2] [4]
		* write if 1   [1] [3]
		* move if 1    [1] [2]
		* state exit 1 [2] [0]
	* 	
	* 	add one program
	* 	  s1 wr ex wl s2
		* 01 10 00 11 10
	*	  s2 wr ex wl s2
		* 10 10 00 11 10
	*
	* 8 bit revised version, using the page line as the opcode
		* write if 0   [1] [7]
		* move if 0    [1] [6]
		* state exit 0 [2] [4]
		* write if 1   [1] [3]
		* move if 1    [1] [2]
		* state exit 1 [2] [0]
	*
	* 16 bit version has 6 bit jump labels
	*/

	parameter INSTRUCTION_SET_LENGTH = 16;
	reg [INSTRUCTION_SET_LENGTH-1:0] program_page [255:0];
	reg [INSTRUCTION_SET_LENGTH-1:0] current_instruction_set;
	reg [2:0] current_instruction; // position in current_instruction_set

	reg clk = 0;

	wire value = 0;
	reg write_flag = 0;
	reg interrupt_flag = 0;
	reg shift_flag = 0;
	reg [7:0] position = 1;
	reg [5:0] next_op = 1;
	track memory(position, write_flag, interrupt_flag, clk, value);
	
	task try_write_to_address(
		input reg instruction_at,
		output cell_write
	);begin
		cell_write = instruction_at;
	end endtask

	task move_address(
		input reg instruction_at,
		input reg [7:0] mem_address,
		output interrupt_flag,
		output shift_flag
	);begin
		if (((mem_address == 0) && (instruction_at == 0)) || ((mem_address == 63) && (instruction_at == 1)))begin
			$display("\tinterrupt at out of bounds");
			interrupt_flag = 1;
		end
		shift_flag = instruction_at;
	end endtask

	task evaluate_instruction_set(
		input reg [15:0] instruction_set,
		output write_flag,
		output interrupt_flag,
		input cell_state,
		input reg [7:0] mem_address,
		inout shift_flag,
		inout reg [5:0] next_op
	);begin
	        if (cell_state == 0)begin
			write_flag = instruction_set[15];
			move_address(instruction_set[14], mem_address, interrupt_flag, shift_flag);
			next_op[0] = instruction_set[8];
			next_op[1] = instruction_set[9];
			next_op[2] = instruction_set[10];
			next_op[3] = instruction_set[11];
			next_op[4] = instruction_set[12];
			next_op[5] = instruction_set[13];
			if (next_op == 0)begin
				$display("\t interrupt at -> 0");
				interrupt_flag = 1;
			end
		end
		else begin
			write_flag = instruction_set[7];
			move_address(instruction_set[6], mem_address, interrupt_flag, shift_flag);
			next_op[0] = instruction_set[0];
			next_op[1] = instruction_set[1];
			next_op[2] = instruction_set[2];
			next_op[3] = instruction_set[3];
			next_op[4] = instruction_set[4];
			next_op[5] = instruction_set[5];
			if (next_op == 0)begin
				$display("\t interrupt at -> 0");
				interrupt_flag = 1;
			end
		end
	end endtask

	always #10 clk = ~clk;

	initial begin
		for (integer line = 0;line < 256;line = line+1) begin
			program_page[line] = 16'b0000000000000000;
		end
		$readmemb("sub1.tbc", program_page);
		$display("start @ %b", next_op);
		for (integer i = 0;i<256;i = i+1) begin
			repeat (1) @ (negedge clk) begin
				if (interrupt_flag == 1) begin
					i = 256;
					$display("program end");
				end
				else begin
					write_flag = 0;
					interrupt_flag = 0;
					position = position + (shift_flag ? 1 : -1);
					shift_flag = 0;
					$write("\t");
					for (integer k = 0;k<(63-position);++k)begin
						$write(" ");
					end
					$display("\033[1;32m^\033[0m");
					$display("\tset %b:%b:", next_op, program_page[next_op]);
					evaluate_instruction_set(
						program_page[next_op],
						write_flag,
						interrupt_flag,
						value,
						position,
						shift_flag,
						next_op
					);
					$display("\tnext_op: %b",next_op);
				end
			end
		end
		$display("finish");
		$finish;
	end

endmodule;
