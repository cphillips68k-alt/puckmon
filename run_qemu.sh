#!/bin/sh
# Puck Mon 65C816 - Apple IIGS bootable disk for MAME
# Generates puckmon.2mg and boots it

# Build disk image using python (handles binary cleanly)
python3 << 'PYEOF'
import struct

# Boot block - raw 65C816 machine code
boot_hex = (
    # 000: BRA +3 skip header bytes
    "8003EAEA"
    # 004: Switch to native 65C816 mode, 8-bit regs
    "18FBE230"
    # 008: Clear text screen $0400-$07FF
    "A920A000A200990004990005990006990007C8D0F1"
    # 01B: Print banner via COUT
    "A200BDCE08F00920EDFDE880F5"
    # 02B: REPL prompt "p] "
    "A97020EDFDA95D20EDFDA92020EDFD"
    # 03B: Read keyboard to buffer at $0900
    "A000AD00C010FB990009C848AD10C068C90DF007C020F00380EC"
    "A900990009A98D20EDFD"
    # 062: Check empty line
    "AD0009F0C6"
    # 068: Dispatch
    "C93FF01EC921F02CC953F03AC948F044"
    # 07A: Hex number display
    "20A208A506F0ACA9A520EDFD20D408A92020EDFD20EC08A92020EDFD4C2B08"
    # 098: cmd_peek stub
    "A93F20EDFD4C2B08"
    # 0A1: cmd_poke stub
    "A92120EDFD4C2B08"
    # 0AA: cmd_sys stub
    "A95320EDFD4C2B08"
    # 0B3: cmd_help
    "A200BDD808F00620EDFDE880F54C2B08"
    # 0C6: parse_hex subroutine
    "A000640464056406B90009F017C9309014C94DB00CC93A9004C9419009"
    "38E907290F06042605060426050604260505048504E606C880DA60"
    # 0F8: print_hex_word
    "A50520FE08A504"
    # 0FE: print_hex_byte
    "484A4A4A4A20080968290F"
    # 10A: print_nibble
    "0930C93A9002690620EDFD60"
    # 114: print_dec placeholder
    "A20060"
    # 118: banner "Puck Mon v0.1 65c816\r\0"
    "5075636B204D6F6E2076302E31203635633831360D00"
    # 12E: help_msg "? peek ! poke S sys H help\r\0"
    "3F207065656B2021706F6B6520532073797320482068656C700D00"
)

boot_bytes = bytes.fromhex(boot_hex)
boot_block = boot_bytes + bytes(512 - len(boot_bytes))

# 64-byte .2mg header (ProDOS order, 800K disk)
hdr = struct.pack('<4s4sHHIIIIIIII16s',
    b'2IMG',       # magic
    b'PUCK',       # creator
    64,            # header size
    1,             # version
    1,             # format: ProDOS order
    0,             # flags
    1600,          # total blocks (800K)
    64,            # data offset (header is 64 bytes)
    819200,        # data length
    0, 0,          # comment offset/len
    0, 0,          # creator offset/len
    bytes(16)      # reserved
)

# Build disk
with open('puckmon.2mg', 'wb') as f:
    f.write(hdr)
    f.write(boot_block)
    f.write(bytes(512 * 1599))  # remaining 1599 empty blocks

print(f'Created puckmon.2mg ({len(hdr) + len(boot_block) + 512*1599} bytes)')
print(f'Boot code: {len(boot_bytes)} bytes')
PYEOF

# Boot with MAME
mame apple2gs -flop3 puckmon.2mg -nomouse -window