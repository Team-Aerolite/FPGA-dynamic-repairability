# FPGA-dynamic-repairability
To demonstrate the repairability functionality of the FPGA, a scenario is presented in which a signal wire becomes physically damaged and an error message is delivered to the monitoring interface through an MCU via SPI.

# Demonstration goals
The primary objective of this demonstration is to illustrate the system's capability to dynamically self-repair in the event of hardware failure detection, by reconfiguring the internal hardware connections of the FPGA logic on the fly.
In this demonstration, an LED matrix continuously cycles through patterns in parallel with the bitwise operation shown in Demonstration 1. When a failure is detected, the pattern on the LED matrix is shifted while an error indicator is displayed.

The following functionalities of the backplane can be observed in this demonstration:

* Monitoring hardware failures within the subsystems
* Operation of the housekeeping unit
* Immediate transition to a fault-tolerant state upon error detection
* Ability to reconfigure data flows to avoid faulty components while maintaining overall system functionality
* Propagation of error flags through multiple subsystems for comprehensive fault handling
* LED dot matrix:
  * Cycles through three LED patterns
  * Shifts the pattern upon detecting a fault, lighting up an error indicator
* Sends an error detection notification to the Serial Monitor, simulating the delivery of satellite housekeeping data to the ground station.
* Executes all error-handling processes in parallel with the bitwise operations from Demonstration 1.

# Hardware Setup
* FPGA: Intel Altera Cyclone IV FPGA Development Board
* Microcontroller: Arduino Uno
* Communication protocol: SPI (Serial Peripheral Interface)
* Peripheral I/O: 4 onboard user LEDs for status display, Reset button, 8x8 LED dot-matrix

# Files
* combined_spi_and_matrix_demo.v: Verilog code file of the bitwise operation demonstration, LED dot matrix shift, error detection with SPI communication enabled
* reconfigDemo_MCU.ino: Code file of the Arduino Uno MCU
