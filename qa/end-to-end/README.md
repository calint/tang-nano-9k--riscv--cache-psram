# end-to-end test

Run `test.sh` and follow instructions.

Assumed firmware on FPGA is `/os`.

## note
* on Ubuntu and derivatives: if `ttyUSBx` hangs do: `sudo modprobe -r xhci_pci && sleep 5 && sudo modprobe xhci_pci` to reset the USB system
* check that no `cat` of the tty is active