* 64 MB card is addressed in multiples of 512 bytes
* 8 GB and 32 GB card is addressed in sectors of 512 bytes

see `src/sdcard.sv` parameter `SectorToSDCardAddressShiftLeft`

8 GB card:
* max sector 15,728,639

32 GB card:
* sector 62,000,000: ok
