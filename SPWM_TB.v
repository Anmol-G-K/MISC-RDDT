`timescale 10ns/1ps
// =====================================================================
// Testbench for 3-Phase SPWM Generator (Simulation Mode)
// ---------------------------------------------------------------------
//
// 
// =====================================================================

module tb_spwm_3phase;

    reg clk;
    reg rst_n;
    wire pwm_a, pwm_b, pwm_c;
    wire pwm_a_high, pwm_a_low;
    wire pwm_b_high, pwm_b_low;
    wire pwm_c_high, pwm_c_low;

    wire signed [1:0] pwm_ab; // signed 2-bit to hold -1, 0, +1


    spwm_3phase #(
        .CLK_FREQ_HZ(100_000_000),
        .CARRIER_FREQ(1_000),
        .FUND_FREQ(10),
        .MOD_INDEX_PCT(80),
        .SINE_RES(360)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .pwm_a(pwm_a),
        .pwm_b(pwm_b),
        .pwm_c(pwm_c),
        .pwm_a_high(pwm_a_high),
        .pwm_a_low(pwm_a_low),
        .pwm_b_high(pwm_b_high),
        .pwm_b_low(pwm_b_low),
        .pwm_c_high(pwm_c_high),
        .pwm_c_low(pwm_c_low)
    );
    

    assign pwm_ab = $signed(pwm_a_high) - $signed(pwm_b_high);


    // Clock Generation (100 MHz)
    initial begin
        clk = 0;
        forever #0.5 clk = ~clk; // 10 ns period = 100 MHz
    end

    // Reset
    initial begin
        rst_n = 0;
        #100;
        rst_n = 1;
    end

    // Simulation Control
    initial begin
        $dumpfile("spwm_3phase.vcd");
        // $dumpfile("spwm_3phase.fst");
        $dumpvars(0, tb_spwm_3phase);
        $dumpvars(0, pwm_ab);
        // $dumpvars(0, pwm_a_high, pwm_a_low, pwm_b_high, pwm_b_low, pwm_c_high, pwm_c_low);
        #(10_000_000);  // 10 ms simulation — multiple sine cycles
        $display("Simulation complete.");
        $finish;
    end

endmodule


// =====================================================================
/*
iverilog -g2012 -o spwm_tb.vvp SPWM_TB.v SPWM.v
vvp SPWM_TB.vvp
gtkwave spwm_3phase.vcd

alternatively to reduce memory issues

compile with:
iverilog -g2012 -o spwm_tb.vvp SPWM_TB.v SPWM.v
vvp -fst SPWM_TB.vvp

or convert vcd to fst
vcd2fst spwm_3phase.vcd spwm_3phase.fst
*/
