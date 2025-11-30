`timescale 10ns/1ps
// =====================================================================
// Generates three phase-shifted SPWM signals using sine lookup ROM
// with 6-switch outputs and configurable dead-time for inverter control.
// =====================================================================

module spwm_3phase #(
    // ============================================================== 
    // User Parameters
    // ============================================================== 
    parameter integer CLK_FREQ_HZ   = 100_000_000, // FPGA clock frequency
    parameter integer CARRIER_FREQ  = 1_000,       // Carrier PWM frequency (Hz)
    parameter integer FUND_FREQ     = 50,          // Fundamental sine frequency (Hz)
    parameter integer MOD_INDEX_PCT = 80,          // Modulation index (0-100%)
    parameter integer SINE_RES      = 360          // Resolution: 360 points per sine cycle
)(
    input  wire clk,            // 100 MHz system clock
    input  wire rst_n,          // Active-low reset

    // Internal SPWM signals
    output reg pwm_a,
    output reg pwm_b,
    output reg pwm_c,

    // 6-Switch Outputs for inverter
    output reg pwm_a_high,      
    output reg pwm_a_low,       
    output reg pwm_b_high,      
    output reg pwm_b_low,       
    output reg pwm_c_high,      
    output reg pwm_c_low        
);

    // ==============================================================
    // Derived Constants
    // ==============================================================
    localparam integer PERIOD_CYCLES    = CLK_FREQ_HZ / CARRIER_FREQ;
    localparam integer STEP_UPDATE      = FUND_FREQ * SINE_RES / CARRIER_FREQ;
    localparam integer AMPLITUDE        = (PERIOD_CYCLES / 2) * MOD_INDEX_PCT / 100;
    localparam integer DATA_WIDTH       = 16;
    localparam integer DEADTIME_CYCLES  = 50; // Example: 50 cycles = 500 ns at 100 MHz

    // ==============================================================
    // Internal Registers
    // ==============================================================
    reg [$clog2(PERIOD_CYCLES):0] carrier_cnt = 0;
    reg carrier_dir = 1'b0; // 0 = up, 1 = down

    reg [8:0] sine_idx_a = 0;
    reg [8:0] sine_idx_b = 120;
    reg [8:0] sine_idx_c = 240;

    wire [31:0] sine_val_a, sine_val_b, sine_val_c;
    wire [31:0] carrier_val;

    // Dead-time registers for low-side switches
    reg [15:0] dt_cnt_a = 0;
    reg [15:0] dt_cnt_b = 0;
    reg [15:0] dt_cnt_c = 0;

    reg pwm_a_low_int = 1;
    reg pwm_b_low_int = 1;
    reg pwm_c_low_int = 1;

    // ==============================================================
  // Triangle Carrier Generator (0 -> max -> 0)
    // ==============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            carrier_cnt <= 0;
            carrier_dir <= 1'b0;
        end else begin
            if (!carrier_dir) begin
                if (carrier_cnt < PERIOD_CYCLES-1)
                    carrier_cnt <= carrier_cnt + 1;
                else
                    carrier_dir <= 1'b1;
            end else begin
                if (carrier_cnt > 0)
                    carrier_cnt <= carrier_cnt - 1;
                else
                    carrier_dir <= 1'b0;
            end
        end
    end

    assign carrier_val = carrier_cnt[DATA_WIDTH-1:0]; // 16 bit comparisson 

    // ==============================================================
    // Sine Wave Index Update (mod SINE_RES)
    // ==============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sine_idx_a <= 0;
            sine_idx_b <= 120 % SINE_RES;
            sine_idx_c <= 240 % SINE_RES;
        end else if (carrier_cnt == 0) begin    // time to trriger PWM as one carrier period completed
            sine_idx_a <= (sine_idx_a + STEP_UPDATE) % SINE_RES;
            sine_idx_b <= (sine_idx_b + STEP_UPDATE) % SINE_RES;
            sine_idx_c <= (sine_idx_c + STEP_UPDATE) % SINE_RES;
        end
    end

    // ==============================================================
    // Sine Lookup ROM (precomputed hex file)
    // ==============================================================
    reg [DATA_WIDTH-1:0] sine_rom [0:SINE_RES-1];

    initial begin   
        $readmemh("sine_lut.hex", sine_rom);
//        $display("SINE_LUT loaded: PERIOD_CYCLES=%0d, AMPLITUDE=%0d, SINE_RES=%0d, DATA_WIDTH=%0d",
//                 PERIOD_CYCLES, AMPLITUDE, SINE_RES, DATA_WIDTH);
//        $display("STEP_UPDATE=%0d", STEP_UPDATE);
    end

    // initial begin
    //     integer i;
    //     for (i = 0; i < SINE_RES; i = i + 1)
    //         sine_rom[i] = (PERIOD_CYCLES/2) + AMPLITUDE * $sin(2 * 3.14159265 * i / SINE_RES);
    // end
    
    assign sine_val_a = sine_rom[sine_idx_a];
    assign sine_val_b = sine_rom[sine_idx_b];
    assign sine_val_c = sine_rom[sine_idx_c];

    // ==============================================================
    // Generate base SPWM signals
    // ==============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pwm_a <= 0; pwm_b <= 0; pwm_c <= 0;
        end else begin
            pwm_a <= (sine_val_a > carrier_val);
            pwm_b <= (sine_val_b > carrier_val);
            pwm_c <= (sine_val_c > carrier_val);
        end
    end

    // ==============================================================
    // Generate 6-switch PWM outputs with dead-time
    // ==============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pwm_a_high <= 0; pwm_b_high <= 0; pwm_c_high <= 0;
            pwm_a_low_int <= 1; pwm_b_low_int <= 1; pwm_c_low_int <= 1;
            dt_cnt_a <= 0; dt_cnt_b <= 0; dt_cnt_c <= 0;
        end else begin
            // High-side signals directly from SPWM
            pwm_a_high <= pwm_a;
            pwm_b_high <= pwm_b;
            pwm_c_high <= pwm_c;

            // Phase A low-side dead-time logic
            if (pwm_a_high) begin
                if (dt_cnt_a < DEADTIME_CYCLES) begin
                    dt_cnt_a <= dt_cnt_a + 1;
                    pwm_a_low_int <= 1;
                end else
                    pwm_a_low_int <= 0;
            end else begin
                dt_cnt_a <= 0;
                pwm_a_low_int <= 1;
            end

            // Phase B low-side
            if (pwm_b_high) begin
                if (dt_cnt_b < DEADTIME_CYCLES) begin
                    dt_cnt_b <= dt_cnt_b + 1;
                    pwm_b_low_int <= 1;
                end else
                    pwm_b_low_int <= 0;
            end else begin
                dt_cnt_b <= 0;
                pwm_b_low_int <= 1;
            end

            // Phase C low-side
            if (pwm_c_high) begin
                if (dt_cnt_c < DEADTIME_CYCLES) begin
                    dt_cnt_c <= dt_cnt_c + 1;
                    pwm_c_low_int <= 1;
                end else
                    pwm_c_low_int <= 0;
            end else begin
                dt_cnt_c <= 0;
                pwm_c_low_int <= 1;
            end
        end
    end

    // Assign low-side outputs
    always @(*) begin
        pwm_a_low = pwm_a_low_int;
        pwm_b_low = pwm_b_low_int;
        pwm_c_low = pwm_c_low_int;
    end

endmodule

