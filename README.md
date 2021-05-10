Single-Cycle-datapath
This is an implementation of single cycle datapath of MIPS Architecture Computer Organisation and Design (The Hardware/ Software Interface) 4th Edition by David A. Patterson and John L. Hennessy. It is based on the Chapter 4 of the mentioned textbook.
The code works for add, addi, sub, and, or, slt, lw, sw, beq and j instructions.
The attached report contains the modelsim simulation results for a clock of 100 ns
The instruction memory contains following program:
      addi $t0, $zero, 32 
      addi $t1, $zero, 55 
      add $s0, $t0, $t1 
      sub $s1, $t0, $t1 
      and $s2, $t0, $t1 
      or $s3, $t0, $t1
LOOP: slt $s4, $t0, $t1
      beq $s4, $zero, EXIT
      add $t2, $t0, $t1 
      add $t2, $t2, $t1
      add $t3, $t2, $t0 
      lw $s5, 4($zero) 
      add $s6, $t2, $s5
      add $s7, $s5, $t3 
EXIT: sw $s5, 8($zero)
      j LOOP
