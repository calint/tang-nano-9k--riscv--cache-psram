# quality assurance

* `./qa.sh` to run numbered tests
* `./testbench.sh <num>` to run a specific test
* `end-to-end/test.sh` sends, receives and compares expected output with actual output
  - assumes `/dev/ttyUSB1`, 115200 baud, 8 bit data, 1 stop bit, no parity, no flow control
