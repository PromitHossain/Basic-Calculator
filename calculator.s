.global _start

// need these constants
constant_10000: .word 10000
constant_99999: .word 99999

.equ SW_ADDR, 0xFF200040
.equ LED_ADDR, 0xFF200000
.equ DISP_ADDR1, 0xFF200020 // 1st display for HEX 3-0
.equ DISP_ADDR2, 0xFF200030 // 2nd display for HEX 5-4
.equ PB, 0xff200050
.equ mask, 0xff200058
.equ capture, 0xff20005c 

// read_PB_data_ASM
	// args: n/a
	// returns: indices of currently pressed PBs in a1
// PB_data_is_pressed_ASM
	// args: indices of PBs in a1
	// returns: 0/1 if PBs not/are pressed in a1
// read_PB_edgecp_ASM
	// args: n/a
	// returns: indices of pressed and released pushbuttons in a1
// PB_edgecp_is_pressed_ASM
	// args: indices of PBs in a1
	// returns: 0/1 if PBs not/are pressed and released in a1
// PB_clear_edgecp_ASM
	// args: //
	// returns: n/a

_start:
	BL PB_clear_edgecp_ASM
	MOV a1, #0x0000001F // start up displays "00000"
	MOV a2, #0
	BL HEX_write_ASM
	MOV v4, #1 // v4 is a boolean value regarding whether display has been cleared or not
	LDR v5, =constant_99999
	LDR v6, [v5] // v6 = 99999
	MVN v7, v6
	ADD v7, v7, #1 // v7 = -99999
	MOV v8, #0 // 0 if no overflow; 1 if overflow
POLL_PB:
	// summary of this loop: keep polling if no PBs have been pressed
	BL read_slider_switches_ASM
	BL write_LEDs_ASM
	
	LDR v1, =LED_ADDR 
	LDR v2, [v1] // loading content of LED reg 
	MOV v3, v2 // duplicating LED content
	LSL v2, v2, #28 // extract right 4 bits from LED and in v2
	LSR v2, v2, #28 // 
	LSL v3, v3, #24 // get rid of bits from switch 9 & 8 (just in case)
	LSR v3, v3, #28 // extract left 4 bits from LED and in v3
					// correct content is now in v2 & v3
	
	BL read_PB_data_ASM // load currently pressed PB indices in a1
	CMP a1, #0
	BEQ POLL_PB // continue reading if nothing is pressed

polling_pb:
	// copy pasted here to allow modifying LEDs while polling for released button
	// --------
	BL read_slider_switches_ASM
	BL write_LEDs_ASM
	LDR v1, =LED_ADDR 
	LDR v2, [v1]  
	MOV v3, v2 
	LSL v2, v2, #28 
	LSR v2, v2, #28  
	LSL v3, v3, #24 
	LSR v3, v3, #28 
	// ---------
			
	// generalizing the polling of the capture register until something is released
	BL read_PB_edgecp_ASM // relevant part of polling for capture
	CMP a1, #0 		      //
	BEQ polling_pb        //
	
	MOV a1, #1 
	BL PB_edgecp_is_pressed_ASM // check if PB 1 has been pressed and released
	CMP a1, #1 
	BEQ CLEAR // if PB 1 has been pressed and released, can do CLEAR
	
	MOV a1, #2
	BL PB_edgecp_is_pressed_ASM  
	CMP a1, #1 
	BEQ MULTIPLICATION
	
	MOV a1, #4 
	BL PB_edgecp_is_pressed_ASM 
	CMP a1, #1 
	BEQ SUBTRACTION
	
	MOV a1, #8 
	BL PB_edgecp_is_pressed_ASM  
	CMP a1, #1 
	BEQ ADDITION
	
	BL PB_clear_edgecp_ASM // looks likre a useless line...
	B POLL_PB // if none of the capture bits were 1, start over
	
CLEAR:
	MOV v8, #0
	MOV v4, #1 // onluy operation where v4 becomes 1 again; in every other ops, it becomes 0
	BL PB_clear_edgecp_ASM // only want 3 0s and 1 1 in capture bits at a time, so always clear before operation
	MOV a1, #0x0000001f // hex index
	MOV a2, #0 // hex value
	BL HEX_write_ASM
	MOV a1, #0x00000020 
	BL HEX_clear_ASM
	B POLL_PB // going back to POLL_PB bc once PB released, bc will reenter capture polling until last button is unreleased

// start modifying bottom 3 ops
MULTIPLICATION:
	BL PB_clear_edgecp_ASM
	
	CMP v4, #1 // compare display status to see if it has been cleared or not
	BNE MULTIPLY_DISPLAY // if not cleared, multiply value with left 4 LEDs input
	MOV v4, #0 // once computed in display for first time, display being cleared is false
	MUL a3, v3, v2
	BL binary_decimal // value now appears in display
	B POLL_PB 
	MULTIPLY_DISPLAY:
		BL decimal_binary // extract display value into binary
		MOV v3, a1
		MUL a3, v3, v2
		CMP a3, v6
		BGT OVERFLOW
		CMP a3, v7
		BLT OVERFLOW
		CMP v8, #1
		BEQ OVERFLOW
		BL binary_decimal
		B POLL_PB 
		
SUBTRACTION:
	BL PB_clear_edgecp_ASM
	
	CMP v4, #1 
	BNE SUBTRACT_DISPLAY 
	MOV v4, #0 
	SUB a3, v2, v3 // left 4 bits - right 4 bits
	BL binary_decimal 
	B POLL_PB 
	SUBTRACT_DISPLAY:
		BL decimal_binary 
		MOV v3, a1
		SUB a3, v3, v2
		CMP a3, v7
		BLT OVERFLOW
		CMP v8, #1
		BEQ OVERFLOW
		BL binary_decimal
		B POLL_PB 

ADDITION:
	//-----
	BL PB_clear_edgecp_ASM
	
	CMP v4, #1 
	BNE ADD_DISPLAY 
	MOV v4, #0 
	ADD a3, v3, v2 // left 4 bits + right 4 bits
	BL binary_decimal 
	B POLL_PB 
	ADD_DISPLAY:
		BL decimal_binary 
		MOV v3, a1
		ADD a3, v3, v2
		CMP a3, v6
		BGT OVERFLOW
		CMP v8, #1
		BEQ OVERFLOW
		BL binary_decimal
		B POLL_PB
	
	//-----
OVERFLOW:
	BL HEX_clear_ASM
	MOV v8, #1 // setting 1 for overflow
	
	MOV a1, #0x00000021
	MOV a2, #10
	BL HEX_write_ASM
	
	MOV a1, #0x00000010
	MOV a2, #11
	BL HEX_write_ASM
	
	MOV a1, #0x00000008
	MOV a2, #12
	BL HEX_write_ASM
	
	MOV a1, #0x00000004
	MOV a2, #13
	BL HEX_write_ASM
	
	MOV a1, #0x00000002
	MOV a2, #14
	BL HEX_write_ASM
	
	B POLL_PB
	
	decimal_binary:
		PUSH {v1, v2, v3, v4, v5, v6, v7, v8}
		// v1 = col#1, ... v5 = col#5, v6 = col#6, v7 is multiplier and final value, v8 is display address
		MOV v1, #0 
		MOV v2, #0 
		MOV v3, #0
		MOV v4, #0
		MOV v5, #0
		MOV v6, #0
		MOV v7, #0
		LDR v8, =DISP_ADDR1
		
		// gen steps
			// wanna extract x column's value, then go through its content to see what it matches from segment_numbers array
			// 63, 6, 91, 79, 102, 109, 125, 7, 127, 103 ([0, ..., 9])
		DECIMAL0:
			LDRB v7, [v8, #0] // maybe generalize this part
			CHECK0_0:
				CMP v7, #63
				BNE CHECK1_0
				MOV v1, #0
				B ASSIGN_VALUE0 // check next decimal column
			CHECK1_0:
				CMP v7, #6
				BNE CHECK2_0
				MOV v1, #1
				B ASSIGN_VALUE0
			CHECK2_0:
				CMP v7, #91
				BNE CHECK3_0
				MOV v1, #2
				B ASSIGN_VALUE0
			CHECK3_0:
				CMP v7, #79
				BNE CHECK4_0
				MOV v1, #3
				B ASSIGN_VALUE0
			CHECK4_0:
				CMP v7, #102
				BNE CHECK5_0
				MOV v1, #4
				B ASSIGN_VALUE0
			CHECK5_0:
				CMP v7, #109
				BNE CHECK6_0
				MOV v1, #5
				B ASSIGN_VALUE0
			CHECK6_0:
				CMP v7, #125
				BNE CHECK7_0
				MOV v1, #6
				B ASSIGN_VALUE0
			CHECK7_0:
				CMP v7, #7
				BNE CHECK8_0
				MOV v1, #7
				B ASSIGN_VALUE0
			CHECK8_0:
				CMP v7, #127
				BNE CHECK9_0
				MOV v1, #8
				B ASSIGN_VALUE0
			CHECK9_0:
				MOV v1, #9
		
		ASSIGN_VALUE0:
			MOV v7, #1 // v7 acts as both a multiplier and total sum
			MUL v1, v1, v7
				
		DECIMAL1:
			LDRB v7, [v8, #1] 
			CHECK0_1:
				CMP v7, #63
				BNE CHECK1_1
				MOV v2, #0
				B ASSIGN_VALUE1 
			CHECK1_1:
				CMP v7, #6
				BNE CHECK2_1
				MOV v2, #1
				B ASSIGN_VALUE1
			CHECK2_1:
				CMP v7, #91
				BNE CHECK3_1
				MOV v2, #2
				B ASSIGN_VALUE1
			CHECK3_1:
				CMP v7, #79
				BNE CHECK4_1
				MOV v2, #3
				B ASSIGN_VALUE1
			CHECK4_1:
				CMP v7, #102
				BNE CHECK5_1
				MOV v2, #4
				B ASSIGN_VALUE1
			CHECK5_1:
				CMP v7, #109
				BNE CHECK6_1
				MOV v2, #5
				B ASSIGN_VALUE1
			CHECK6_1:
				CMP v7, #125
				BNE CHECK7_1
				MOV v2, #6
				B ASSIGN_VALUE1
			CHECK7_1:
				CMP v7, #7
				BNE CHECK8_1
				MOV v2, #7
				B ASSIGN_VALUE1
			CHECK8_1:
				CMP v7, #127
				BNE CHECK9_1
				MOV v2, #8
				B ASSIGN_VALUE1
			CHECK9_1:
				MOV v2, #9
				
		ASSIGN_VALUE1:
			MOV v7, #10 
			MUL v2, v2, v7
		
		DECIMAL2:
			LDRB v7, [v8, #2] 
			CHECK0_2:
				CMP v7, #63
				BNE CHECK1_2
				MOV v3, #0
				B ASSIGN_VALUE2
			CHECK1_2:
				CMP v7, #6
				BNE CHECK2_2
				MOV v3, #1
				B ASSIGN_VALUE2
			CHECK2_2:
				CMP v7, #91
				BNE CHECK3_2
				MOV v3, #2
				B ASSIGN_VALUE2
			CHECK3_2:
				CMP v7, #79
				BNE CHECK4_2
				MOV v3, #3
				B ASSIGN_VALUE2
			CHECK4_2:
				CMP v7, #102
				BNE CHECK5_2
				MOV v3, #4
				B ASSIGN_VALUE2
			CHECK5_2:
				CMP v7, #109
				BNE CHECK6_2
				MOV v3, #5
				B ASSIGN_VALUE2
			CHECK6_2:
				CMP v7, #125
				BNE CHECK7_2
				MOV v3, #6
				B ASSIGN_VALUE2
			CHECK7_2:
				CMP v7, #7
				BNE CHECK8_2
				MOV v3, #7
				B ASSIGN_VALUE2
			CHECK8_2:
				CMP v7, #127
				BNE CHECK9_2
				MOV v3, #8
				B ASSIGN_VALUE2
			CHECK9_2:
				MOV v3, #9
			
		ASSIGN_VALUE2:
			MOV v7, #100 
			MUL v3, v3, v7
				
		DECIMAL3:
			LDRB v7, [v8, #3] 
			CHECK0_3:
				CMP v7, #63
				BNE CHECK1_3
				MOV v4, #0
				B ASSIGN_VALUE3 
			CHECK1_3:
				CMP v7, #6
				BNE CHECK2_3
				MOV v4, #1
				B ASSIGN_VALUE3
			CHECK2_3:
				CMP v7, #91
				BNE CHECK3_3
				MOV v4, #2
				B ASSIGN_VALUE3
			CHECK3_3:
				CMP v7, #79
				BNE CHECK4_3
				MOV v4, #3
				B ASSIGN_VALUE3
			CHECK4_3:
				CMP v7, #102
				BNE CHECK5_3
				MOV v4, #4
				B ASSIGN_VALUE3
			CHECK5_3:
				CMP v7, #109
				BNE CHECK6_3
				MOV v4, #5
				B ASSIGN_VALUE3
			CHECK6_3:
				CMP v7, #125
				BNE CHECK7_3
				MOV v4, #6
				B ASSIGN_VALUE3
			CHECK7_3:
				CMP v7, #7
				BNE CHECK8_3
				MOV v4, #7
				B ASSIGN_VALUE3
			CHECK8_3:
				CMP v7, #127
				BNE CHECK9_3
				MOV v4, #8
				B ASSIGN_VALUE3
			CHECK9_3:
				MOV v4, #9
		
		ASSIGN_VALUE3:
			MOV v7, #1000 
			MUL v4, v4, v7
		
		LDR v8, =DISP_ADDR2 // now checking last 2 HEXs
		
		DECIMAL4:
			LDRB v7, [v8, #0] 
			CHECK0_4:
				CMP v7, #63
				BNE CHECK1_4
				MOV v5, #0
				B ASSIGN_VALUE4 // check next decimal column
			CHECK1_4:
				CMP v7, #6
				BNE CHECK2_4
				MOV v5, #1
				B ASSIGN_VALUE4
			CHECK2_4:
				CMP v7, #91
				BNE CHECK3_4
				MOV v5, #2
				B ASSIGN_VALUE4
			CHECK3_4:
				CMP v7, #79
				BNE CHECK4_4
				MOV v5, #3
				B ASSIGN_VALUE4
			CHECK4_4:
				CMP v7, #102
				BNE CHECK5_4
				MOV v5, #4
				B ASSIGN_VALUE4
			CHECK5_4:
				CMP v7, #109
				BNE CHECK6_4
				MOV v5, #5
				B ASSIGN_VALUE4
			CHECK6_4:
				CMP v7, #125
				BNE CHECK7_4
				MOV v5, #6
				B ASSIGN_VALUE4
			CHECK7_4:
				CMP v7, #7
				BNE CHECK8_4
				MOV v5, #7
				B ASSIGN_VALUE4
			CHECK8_4:
				CMP v7, #127
				BNE CHECK9_4
				MOV v5, #8
				B ASSIGN_VALUE4
			CHECK9_4:
				MOV v5, #9
		
		ASSIGN_VALUE4:
			LDR v8, =constant_10000
			LDR v7, [v8] // address of DISPLAY2 not useful at this stage anymore until next HEX reached
			MUL v5, v5, v7
			
		DECIMAL5:
			LDR v8, =DISP_ADDR2
			LDRB v7, [v8, #1] 
			
			CHECK_NEGATIVE:
				CMP v7, #64
				BNE ASSIGN_VALUE5
				MOV v6, #1
				MVN v6, v6
				ADD v6, v6, #1 // getting 2s complement to convert 1 to -1
				B COMBINE // skip to COMBINE immediately
		ASSIGN_VALUE5:
			MOV v6, #1
		
		COMBINE:
			MOV v7, #0 // get rid of address of HEX2
			ADD v7, v7, v1
			ADD v7, v7, v2
			ADD v7, v7, v3
			ADD v7, v7, v4
			ADD v7, v7, v5
			MUL v7, v7, v6  // getting the value
			
		MOV a1, v7 // result will be sent back to a1
		POP {v1, v2, v3, v4, v5, v6, v7, v8}
		BX LR
	
	binary_decimal:
		PUSH {a1, a2, v1, v2, v3, v4, v5, v6, v7, v8}
		// v1 = col#1, ... v5 = col#5
		// v6 = counter and will be used for the sign after all other cols displayed
		// v7 and v8 needed to build bigger immediate values
		
		
		CMP a3, #0
		//----
		BGE CARRY_ON
		MVN a3, a3 
		ADD a3, a3, #1
		MOV a1, #0x00000020
		MOV a2, #16 
		PUSH {LR}
		BL HEX_write_ASM
		POP {LR}
		//----
		CARRY_ON:
		MOV v1, a3
		MOV v2, #0 // ensuring all original values of registers get reset 
		MOV v3, #0
		MOV v4, #0
		MOV v5, #0
		MOV v6, #0
		MOV v7, #0
		MOV v8, #0
		
		CMP v1, #10 // if value is 0 <= x < 10, just insert it immediately into display
		BLT FINAL_INSERT
		
		LOOP_COL1:
			SUB v1, v1, #10
			CMP v1, #10
			BGE LOOP_COL1
			
		MOV v2, a3 
		CMP v2, #100 // if value is x < 100, go immediately into counting nb of 10s
		BLT LOOP_COL2_ADD
		
		LOOP_COL2_SUB: // subtracting all the hundreds away and then counting nb of 10s 
			SUB v2, v2, #100
			CMP v2, #100
			BGE LOOP_COL2_SUB
		LOOP_COL2_ADD: 
			CMP v2, #10
			BLT BEGIN_COL3
			SUB v2, v2, #10
			ADD v6, v6, #1
			CMP v2, #10
			BGE LOOP_COL2_ADD

		BEGIN_COL3:
			MOV v2, v6 // moving counter value to v2 bc that will be col's value
			MOV v6, #0 // resetting counter v6 to 0
		
			MOV v3, a3 
			CMP v3, #1000 // if value is x < 1000, counter number of 100s
			BLT LOOP_COL3_ADD
		LOOP_COL3_SUB: // subtracting all the thousands away and then counting nb of 100s
			SUB v3, v3, #1000
			CMP v3, #1000
			BGE LOOP_COL3_SUB
		LOOP_COL3_ADD: 
			CMP v3, #100 
			BLT BEGIN_COL4
			SUB v3, v3, #100
			ADD v6, v6, #1
			CMP v3, #100
			BGE LOOP_COL3_ADD
			
		BEGIN_COL4:
			MOV v3, v6 
			MOV v6, #0 
		
			MOV v4, a3	
			LDR v7, =constant_10000 // loading 10000 into v7
			LDR v8, [v7]            //
		
			CMP v4, v8
			BLT LOOP_COL4_ADD
		LOOP_COL4_SUB:
			SUB v4, v4, v8
			CMP v4, v8
			BGE LOOP_COL4_SUB
		LOOP_COL4_ADD: 
			CMP v4, #1000
			BLT BEGIN_COL5
			SUB v4, v4, #1000
			ADD v6, v6, #1
			CMP v4, #1000
			BGE LOOP_COL4_ADD
			
		BEGIN_COL5:
			MOV v4, v6 
			MOV v6, #0
			MOV v5, a3
		
			CMP v5, v8
			BLT SKIP_LAST
		LOOP_COL5_ADD: // unlike middle 3 cols, keep looping till it's less than 10000
			SUB v5, v5, v8
			ADD v6, v6, #1
			CMP v5, v8
			BGE LOOP_COL5_ADD
		
		MOV v5, v6
		MOV v6, #0
		B FINAL_INSERT
		
		SKIP_LAST:
			MOV v5, #0
			B FINAL_INSERT
		
		FINAL_INSERT:
			MOV a1, #0x00000001
			MOV a2, v1
			PUSH {LR}
			BL HEX_write_ASM
			POP {LR}

			MOV a1, #0x00000002
			MOV a2, v2
			PUSH {LR}
			BL HEX_write_ASM
			POP {LR}

			MOV a1, #0x00000004
			MOV a2, v3
			PUSH {LR}
			BL HEX_write_ASM
			POP {LR}

			MOV a1, #0x00000008
			MOV a2, v4
			PUSH {LR}
			BL HEX_write_ASM
			POP {LR}

			MOV a1, #0x00000010
			MOV a2, v5
			PUSH {LR}
			BL HEX_write_ASM
			POP {LR}
			
			
			CMP a3, #0 // writing sign or not depending on if input is/not negative
			BGT STOP_SIGN
			
			PUSH {LR}
			MOV a1, #32
			BL HEX_clear_ASM 
			POP {LR}
			
			
		STOP_SIGN:
			POP {a1, a2, v1, v2, v3, v4, v5, v6, v7, v8}
			BX LR
	
	read_slider_switches_ASM:
		// deviates from doc implementation to free up a2
		PUSH {v1}
		LDR v1, =SW_ADDR       // load the address of slider switch state
		LDR a3, [v1] 	       // read slider switch state
		POP {v1}
		BX LR
	write_LEDs_ASM:
		// deviates from doc implementation to free up a2
		PUSH {v1}
		LDR v1, =LED_ADDR      // load address of LED's state
		STR a3, [v1]           // update LED state with the contents of a1
							   // since it's a 1:1 bit relation, can just store switch state address into led address
		POP {v1}
		BX LR
	
	HEX_flood_ASM:
			// summary of goal
			// do bit wise AND on input 6 times
			// if find out LSB is 1, access the display address and store full byte so long as counter is <4
			// if find out LSB is 0, do not access address but add to counter anyway
			// when counter reaches > 3, reset counter back to 0 and start accessing 2nd display when LSB is 1
			// do LSR before looping back to do another bitwise AND 
			// end loop when counter reaches 6
			PUSH {v1, v2, v3, v4, v5, v6, v7, v8}
			MOV v1, #0 // soft counter 
			MOV v2, #0 // hard counter
			MOV v3, #0 // result of AND operation to check if LSB is 1 or 0
			LDR v4, =DISP_ADDR1 // base address of current hex
			MOV v5, #127 // 0b01111111 into byte of addresses
			LDR v6, =DISP_ADDR1 //adress that will be result of EA
			MOV v7, #1 // byte constant

			MOV v8, a1 // store input into v8 to not lose input
		LOOP1:	
			AND v3, a1, #1 // isolate LSB to see if it's a 1 or 0
			CMP v3, #0
			BEQ INCREMENT1 // proceed to increment immediately if LSB is 0
			CMP v2, #3 // compare the reached hard limit
			BGT SWITCH1
		RESUME1:	
			MLA v6, v7, v1, v4 // EA = byte * soft + basse address
			STRB v5, [v6] // store byte
			MOV v6, v4 // reset v6 address back to first element
		INCREMENT1:	
			ADD v2, v2, #1
			ADD v1, v1, #1
			CMP v1, #4
			BEQ MODULO1
		SHIFTBITS1:	
			LSR a1, a1, #1
			CMP v2, #6 // if counter = 6, exit loop since visited every hex before v1=6
			BEQ END1
			B LOOP1
		END1:
			MOV a1, v8
			POP {v1, v2, v3, v4, v5, v6, v7, v8}
			BX LR
		SWITCH1:
			LDR v4, =DISP_ADDR2
			LDR v6, =DISP_ADDR2
			B RESUME1
		MODULO1:
			MOV v1, #0 // if soft counter reaches 4 immediately reset to 0
			B SHIFTBITS1


	HEX_clear_ASM:
			PUSH {v1, v2, v3, v4, v5, v6, v7, v8}
			MOV v1, #0 // soft counter 
			MOV v2, #0 // hard counter
			MOV v3, #0 // result of AND operation to check if LSB is 1 or 0
			LDR v4, =DISP_ADDR1 // base address of current hex
			MOV v5, #0 // 0b00000000 into byte of addresses
			LDR v6, =DISP_ADDR1 //adress that will be result of EA
			MOV v7, #1 // byte constant

			MOV v8, a1 // store input into v8 to not lose input
		LOOP2:	
			AND v3, a1, #1 // isolate LSB to see if it's a 1 or 0
			CMP v3, #0
			BEQ INCREMENT2 // proceed to increment immediately if LSB is 0
			CMP v2, #3 // compare the reached hard limit
			BGT SWITCH2
		RESUME2:	
			MLA v6, v7, v1, v4 // EA = byte * soft + basse address
			STRB v5, [v6] // store byte
			MOV v6, v4 // reset v6 address back to first element
		INCREMENT2:	
			ADD v2, v2, #1
			ADD v1, v1, #1
			CMP v1, #4
			BEQ MODULO2
		SHIFTBITS2:	
			LSR a1, a1, #1
			CMP v2, #6 // if counter = 6, exit loop since visited every hex before v1=6
			BEQ END2
			B LOOP2
		END2:
			MOV a1, v8
			POP {v1, v2, v3, v4, v5, v6, v7, v8}
			BX LR
		SWITCH2:
			LDR v4, =DISP_ADDR2
			LDR v6, =DISP_ADDR2
			B RESUME2
		MODULO2:
			MOV v1, #0 // if soft counter reaches 4 immediately reset to 0
			B SHIFTBITS2

	HEX_write_ASM:
			PUSH {v1, v2, v3, v4, v5, v6, v7, v8}
			MOV v1, #0 // soft counter 
			MOV v2, #0 // hard counter
			MOV v3, #0 // result of AND operation to check if LSB is 1 or 0
			LDR v4, =DISP_ADDR1 // base address of current hex

			CMP a2, #0
			BNE MOVETO1
		DEFAULT:	
			MOV v5, #63 // 0b00111111 to represent 0
			B SELECTED
		MOVETO1:
			CMP a2, #1
			BNE MOVETO2
			MOV v5, #6 // 0b00000110 to represent 1
			B SELECTED
		MOVETO2:
			CMP a2, #2
			BNE MOVETO3
			MOV v5, #91 // 0b01011011 to represent 2
			B SELECTED
		MOVETO3:
			CMP a2, #3
			BNE MOVETO4
			MOV v5, #79 // 0b01001111 to represent 3
			B SELECTED
		MOVETO4:
			CMP a2, #4
			BNE MOVETO5
			MOV v5, #102 // 0b01100110 to represent 4
			B SELECTED
		MOVETO5:
			CMP a2, #5
			BNE MOVETO6
			MOV v5, #109 // 0b01101101 to represent 5
			B SELECTED
		MOVETO6:
			CMP a2, #6
			BNE MOVETO7
			MOV v5, #125 // 0b01111101 to represent 6
			B SELECTED
		MOVETO7:
			CMP a2, #7
			BNE MOVETO8
			MOV v5, #7 // 0b00000111 to represent 7
			B SELECTED
		MOVETO8:
			CMP a2, #8
			BNE MOVETO9
			MOV v5, #127 // 0b01111111 to represent 8
			B SELECTED
		MOVETO9:
			CMP a2, #9
			BNE MOVETO_O
			MOV v5, #103 // 0b01100111 to represent 9
			B SELECTED
		MOVETO_O:
			CMP a2, #10
			BNE MOVETO_V
			MOV v5, #92 // 0b01011100 to represent o
			B SELECTED
		MOVETO_V:
			CMP a2, #11
			BNE MOVETO_R
			MOV v5, #62 // 0b00111110 to represent V
			B SELECTED
		MOVETO_R:
			CMP a2, #12
			BNE MOVETO_F
			MOV v5, #80 // 0b01010000 to represent r
			B SELECTED
		MOVETO_F:
			CMP a2, #13
			BNE MOVETO_L
			MOV v5, #113 // 0b01110001 to represent F
			B SELECTED
		MOVETO_L:
			CMP a2, #14
			BNE MOVETO16
			MOV v5, #56 // 0b00111000 to represent L
			B SELECTED
		MOVETO16:
		  	CMP a2, #16
			BNE DEFAULT
			MOV v5, #64
			B SELECTED
		SELECTED:	
			LDR v6, =DISP_ADDR1 //adress that will be result of EA
			MOV v7, #1 // byte constant
			MOV v8, a1 // store input into v8 to not lose input
		LOOP3:	
			AND v3, a1, #1 // isolate LSB to see if it's a 1 or 0
			CMP v3, #0
			BEQ INCREMENT3 // proceed to increment immediately if LSB is 0
			CMP v2, #3 // compare the reached hard limit
			BGT SWITCH3
		RESUME3:	
			MLA v6, v7, v1, v4 // EA = byte * soft + basse address
			STRB v5, [v6] // store byte
			MOV v6, v4 // reset v6 address back to first element
		INCREMENT3:	
			ADD v2, v2, #1
			ADD v1, v1, #1
			CMP v1, #4
			BEQ MODULO3
		SHIFTBITS3:	
			LSR a1, a1, #1
			CMP v2, #6 // if counter = 6, exit loop since visited every hex before v1=6
			BEQ END3
			B LOOP3
		END3:
			MOV a1, v8
			POP {v1, v2, v3, v4, v5, v6, v7, v8}
			BX LR
		SWITCH3:
			LDR v4, =DISP_ADDR2
			LDR v6, =DISP_ADDR2
			B RESUME3
		MODULO3:
			MOV v1, #0 // if soft counter reaches 4 immediately reset to 0
			B SHIFTBITS3
	
	read_PB_data_ASM:
			PUSH {v1}
			LDR v1, =PB // storing address of push button into v1
			LDR a1, [v1] // load/returns the state indices of pushbuttons into a1
			POP {v1}
			BX LR

	PB_data_is_pressed_ASM:
			PUSH {v1, v2, v3}
			LDR v3, =PB // storing address of push button into v3
			LDR v2, [v3] // load state indices of pushbuttons into v2

			ORR v1, v2, a1 // v1 = v2 (state of indices) OR a1 (indice argument)
			CMP a1, v2

			BEQ GIVE1
			MOV a1, #0
			POP {v1, v2, v3}
			BX LR
		GIVE1:
			MOV a1, #1
			POP {v1, v2, v3}
			BX LR

	read_PB_edgecp_ASM:
			PUSH {v1}
			LDR v1, =capture // storing address of edge capture register into v1 
			LDR a1, [v1] // load the state of edge capture register
			POP {v1}
			BX LR

	PB_edgecp_is_pressed_ASM:
			PUSH {v1, v2, v3}
			LDR v3, =capture // storing address of capture register into v3
			LDR v2, [v3] // load state indices of pushbuttons into v2

			ORR v1, v2, a1 // v1 = v2 (state of capture) OR a1 (capture indice argument)
			CMP a1, v2

			BEQ GIVE2
			MOV a1, #0
			POP {v1, v2, v3}
			BX LR
		GIVE2:
			MOV a1, #1
			POP {v1, v2, v3}
			BX LR


	PB_clear_edgecp_ASM:
			PUSH {v1, v2}
			LDR v1, =capture // storing address of edge capture register into v1 

			LDR v2, [v1] //load the content and store it back to the register to initiate clearing by CPU 
			STR v2, [v1]
			POP {v1, v2}
			BX LR
