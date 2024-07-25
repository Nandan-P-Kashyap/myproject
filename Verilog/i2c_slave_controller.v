`timescale 1ns / 1ps

module i2c_slave_controller(
    // Bidirectional I2C Lines
    inout sda, // I2C Data line
    inout scl  // I2C Clock line
);

    // I2C Address for this slave device
    localparam ADDRESS = 7'b0101010;

    // State Encoding
    localparam READ_ADDR = 0; // State to read the address
    localparam SEND_ACK = 1;  // State to send an ACK
    localparam READ_DATA = 2; // State to read data from the master
    localparam WRITE_DATA = 3; // State to write data to the master
    localparam SEND_ACK2 = 4;  // State to send an ACK after data reception

    // Internal Registers
    reg [7:0] addr;       // Register to store the received address
    reg [7:0] counter;    // Bit counter
    reg [7:0] state = 0;  // State register
    reg [7:0] data_in = 0; // Register to store the received data
    reg [7:0] data_out = 8'b11001100; // Data to be sent to the master
    reg sda_out = 0;      // Data to be driven on SDA line
    reg sda_in = 0;       // Input data from SDA line
    reg start = 0;        // Start condition flag
    reg write_enable = 0; // Control signal to enable SDA as output

    // Control I2C data line
    assign sda = (write_enable == 1) ? sda_out : 'bz;

    // Detect Start Condition (SDA goes low while SCL is high)
    always @(negedge sda) begin
        if ((start == 0) && (scl == 1)) begin
            start <= 1;  
            counter <= 7; // Initialize bit counter
        end
    end

    // Detect Stop Condition (SDA goes high while SCL is high)
    always @(posedge sda) begin
        if ((start == 1) && (scl == 1)) begin
            state <= READ_ADDR; // Move to read address state
            start <= 0;
            write_enable <= 0;
        end
    end

    // State Machine to process I2C signals
    always @(posedge scl) begin
        if (start == 1) begin
            case(state)
                READ_ADDR: begin
                    addr[counter] <= sda; // Capture address bit
                    if(counter == 0) state <= SEND_ACK; // Move to send ACK state
                    else counter <= counter - 1;                    
                end

                SEND_ACK: begin
                    if(addr[7:1] == ADDRESS) begin // Check if address matches
                        counter <= 7;
                        if(addr[0] == 0) begin 
                            state <= READ_DATA; // If write operation, move to read data state
                        end else state <= WRITE_DATA; // If read operation, move to write data state
                    end
                end

                READ_DATA: begin
                    data_in[counter] <= sda; // Capture data bit
                    if(counter == 0) begin
                        state <= SEND_ACK2; // Move to send ACK after data reception
                    end else counter <= counter - 1;
                end

                SEND_ACK2: begin
                    state <= READ_ADDR; // Move to read address state after sending ACK                    
                end

                WRITE_DATA: begin
                    if(counter == 0) state <= READ_ADDR; // Move to read address state after data transmission
                    else counter <= counter - 1;        
                end

            endcase
        end
    end

    // Control SDA line based on state
    always @(negedge scl) begin
        case(state)

            READ_ADDR: begin
                write_enable <= 0;            
            end

            SEND_ACK: begin
                sda_out <= 0; // Send ACK bit
                write_enable <= 1;    
            end

            READ_DATA: begin
                write_enable <= 0;
            end

            WRITE_DATA: begin
                sda_out <= data_out[counter]; // Send data bit
                write_enable <= 1;
            end

            SEND_ACK2: begin
                sda_out <= 0; // Send ACK bit after data reception
                write_enable <= 1;
            end
        endcase
    end
endmodule
