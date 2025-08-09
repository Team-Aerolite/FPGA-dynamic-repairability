module combined_spi_and_matrix_demo(
    input wire clk,         // 50MHz clock input
    input wire reset_n,     // active low reset

    // SPI signals
    input wire spi_sck,
    input wire spi_mosi,
    input wire spi_ss,
    output reg spi_miso,

    // Board keys (active LOW: pressed = 0)
    input wire btn1,
    input wire btn2,
    input wire btn3,

    // LED matrix outputs
    output reg [7:0] row_select,
    output reg [7:0] col_drive,

    // 4 board LEDs output for SPI status
    output reg [3:0] led_out
);

    // -----------------------------------------------------
    // ==== SPI Input Synchronization ====
    reg [1:0] sck_sync, mosi_sync, ss_sync;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            sck_sync <= 2'b00;
            mosi_sync <= 2'b00;
            ss_sync <= 2'b11;
        end else begin
            sck_sync <= {sck_sync[0], spi_sck};
            mosi_sync <= {mosi_sync[0], spi_mosi};
            ss_sync <= {ss_sync[0], spi_ss};
        end
    end

    wire sck_rising = (sck_sync == 2'b01);
    wire sck_falling = (sck_sync == 2'b10);
    wire ss_active = (ss_sync[1] == 1'b0);

    // -----------------------------------------------------
    // ==== SPI Reception ====
    reg [2:0] bit_count = 0;
    reg [7:0] rx_byte = 0;
    reg byte_received = 0;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            bit_count <= 0;
            rx_byte <= 8'b0;
            byte_received <= 0;
        end else if (!ss_active) begin
            bit_count <= 0;
            byte_received <= 0;
        end else if (sck_rising) begin
            rx_byte <= {rx_byte[6:0], mosi_sync[1]};
            bit_count <= bit_count + 1;
            if (bit_count == 7) begin
                byte_received <= 1;
                bit_count <= 0;
            end else begin
                byte_received <= 0;
            end
        end else begin
            byte_received <= 0;
        end
    end

    // -----------------------------------------------------
    // ==== SPI Config and Logic ====
    reg [1:0] logic_function = 2'b00;
    reg [1:0] input_a = 2'b00;
    reg [1:0] input_b = 2'b00;
    reg [1:0] logic_result;
	 reg error_flag = 1'b00;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            logic_function <= 2'b00;
            input_a <= 2'b00;
            input_b <= 2'b00;
        end else if (byte_received) begin
            case (rx_byte[7:6])
                2'b00: logic_function <= rx_byte[1:0];
                2'b01: input_a <= rx_byte[1:0];
                2'b10: input_b <= rx_byte[1:0];
                2'b11: ;
            endcase
        end
    end

    always @(*) begin
        case (logic_function)
            2'b00: logic_result = input_a & input_b;
            2'b01: logic_result = input_a | input_b;
            2'b10: logic_result = input_a ^ input_b;
            2'b11: logic_result = ~(input_a & input_b);
            default: logic_result = 2'b00;
        endcase
    end

    // -----------------------------------------------------
    // ==== SPI Transmit (MISO) ====
    reg [7:0] tx_byte = 8'b0;
    reg [2:0] tx_bit_count = 0;
    reg ss_sync_d;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            ss_sync_d <= 1'b1;
        else
            ss_sync_d <= ss_sync[1];
    end

    wire ss_falling_edge = (ss_sync_d & ~ss_sync[1]);

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            tx_byte <= 8'b0;
            tx_bit_count <= 0;
            spi_miso <= 1'b0;
        end else if (ss_falling_edge) begin
            tx_byte <= {2'b00, logic_function, logic_result, 1'b00, error_flag};
            tx_bit_count <= 0;
            spi_miso <= tx_byte[7];
        end else if (ss_active && sck_falling) begin
            tx_byte <= {tx_byte[6:0], 1'b0};
            tx_bit_count <= tx_bit_count + 1;
            spi_miso <= tx_byte[6];
        end else if (ss_sync[1]) begin
            spi_miso <= 1'b0;
            tx_bit_count <= 0;
        end
    end

    // -----------------------------------------------------
    // ==== LED Board Indicator ====
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            led_out <= 4'b0000;
        else
            led_out <= {logic_result, logic_function};
    end

    // -----------------------------------------------------
    // ==== LED Matrix Patterns ====
    localparam [63:0] PATTERN_SMILEY_MAIN = {
        8'b00000000,  // Row7
        8'b00000000,  // Row6
        8'b00000000,  // Row5
        8'b11111000,  // Row4
        8'b01110000,  // Row3
        8'b00100000,  // Row2
        8'b01110000,  // Row1
        8'b11111000   // Row0
    };

    localparam [63:0] PATTERN_HEART_MAIN = {
        8'b00000000,
        8'b00000000,
        8'b00000000,
        8'b10001000,
        8'b11011000,
        8'b11111000,
        8'b11011000,
        8'b10001000
    };

    localparam [63:0] PATTERN_DIAMOND_MAIN = {
        8'b00000000,
        8'b00000000,
        8'b00000000,
        8'b11111000,
        8'b11111000,
        8'b11111000,
        8'b11111000,
        8'b11111000
    };

    // ==== Shifted patterns ====

    localparam [63:0] PATTERN_SMILEY_SHIFTED = {
        8'b00000000, // Row7
        8'b00000000, // Row6
        8'b00000000, // Row5
        8'b00011111, // Row4
        8'b00001110, // Row3
        8'b00000100, // Row2
        8'b00001110, // Row1
        8'b10011111  // Row0
    };

    localparam [63:0] PATTERN_HEART_SHIFTED = {
        8'b00000000,
        8'b00000000,
        8'b00000000,
        8'b00010001,
        8'b00011011,
        8'b00011111,
        8'b00011011,
        8'b10010001
    };

    localparam [63:0] PATTERN_DIAMOND_SHIFTED = {
        8'b00000000,
        8'b00000000,
        8'b00000000,
        8'b00011111,
        8'b00011111,
        8'b00011111,
        8'b00011111,
        8'b10011111
    };

    // -----------------------------------------------------
    // ==== Key Input Processing ====
    reg hold_flag;

    always @(posedge clk or negedge reset_n) begin
         if (!reset_n) begin
            hold_flag <= 0;
				error_flag <= 0;
         end else if (~btn1 | ~btn2 | ~btn3) begin
            hold_flag <= 1;
				error_flag <= 1;
			end
    end

    // -----------------------------------------------------
    // ==== Pattern Cycling Logic ====
    reg [1:0] pattern_select = 0;
    reg [31:0] pattern_timer = 0;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            pattern_timer <= 0;
            pattern_select <= 0;
        end else begin
            if (pattern_timer == 12_500_000 - 1) begin
                pattern_timer <= 0;
                pattern_select <= pattern_select + 1;
            end else begin
                pattern_timer <= pattern_timer + 1;
            end
        end
    end

    reg [63:0] current_pattern;
    reg [63:0] shifted_pattern;

    always @(*) begin
        case (pattern_select)
            2'd0: begin
                current_pattern = PATTERN_SMILEY_MAIN;
                shifted_pattern = PATTERN_SMILEY_SHIFTED;
            end
            2'd1: begin
                current_pattern = PATTERN_HEART_MAIN;
                shifted_pattern = PATTERN_HEART_SHIFTED;
            end
            2'd2: begin
                current_pattern = PATTERN_DIAMOND_MAIN;
                shifted_pattern = PATTERN_DIAMOND_SHIFTED;
            end
            default: begin
                current_pattern = PATTERN_SMILEY_MAIN;
                shifted_pattern = PATTERN_SMILEY_SHIFTED;
            end
        endcase
    end

    reg [63:0] display_pattern;

    always @(*) begin
        if (hold_flag)
            display_pattern = shifted_pattern | 64'h1;
        else
            display_pattern = current_pattern;
    end

    // -----------------------------------------------------
    // ==== LED Matrix Drive Scan ====

    reg [15:0] scan_divider = 0;
    reg [2:0] current_row = 0;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            scan_divider <= 0;
            current_row <= 0;
        end else begin
            scan_divider <= scan_divider + 1;
            if (scan_divider == 50_000) begin
                scan_divider <= 0;
                current_row <= current_row + 1;
            end
        end
    end

    always @(*) begin
        case (current_row)
            3'd0: row_select = 8'b00000001;
            3'd1: row_select = 8'b00000010;
            3'd2: row_select = 8'b00000100;
            3'd3: row_select = 8'b00001000;
            3'd4: row_select = 8'b00010000;
            3'd5: row_select = 8'b00100000;
            3'd6: row_select = 8'b01000000;
            3'd7: row_select = 8'b10000000;
            default: row_select = 8'b00000000;
        endcase

        case (current_row)
            3'd0: col_drive = ~display_pattern[7:0];
            3'd1: col_drive = ~display_pattern[15:8];
            3'd2: col_drive = ~display_pattern[23:16];
            3'd3: col_drive = ~display_pattern[31:24];
            3'd4: col_drive = ~display_pattern[39:32];
            3'd5: col_drive = ~display_pattern[47:40];
            3'd6: col_drive = ~display_pattern[55:48];
            3'd7: col_drive = ~display_pattern[63:56];
            default: col_drive = 8'b11111111;
        endcase
    end

endmodule
