#!/bin/sh
# Puck Mon 65C816 - Apple IIGS bootable disk for MAME
# Generates a .2mg disk image and boots it

# ============================================================
# .2MG Header (64 bytes)
# ============================================================
# Magic: 2IMG, Creator: PUCK, Header size: 64, Version: 1
# Format: 1 (ProDOS order), Blocks: 1600 (800K disk)
printf '\x32\x49\x4D\x47'         # 2IMG
printf '\x50\x55\x43\x4B'         # PUCK
printf '\x40\x00'                 # header size 64
printf '\x01\x00'                 # version 1
printf '\x01\x00\x00\x00'         # ProDOS order
printf '\x00\x00\x00\x00'         # flags
printf '\x40\x06\x00\x00'         # 1600 blocks
printf '\x40\x00\x00\x00'         # data offset 64
printf '\x00\x80\x0C\x00'         # data length 819200
printf '\x00\x00\x00\x00'         # comment offset
printf '\x00\x00\x00\x00'         # comment len
printf '\x00\x00\x00\x00'         # creator offset
printf '\x00\x00\x00\x00'         # creator len
# reserved (16 bytes)
dd if=/dev/zero bs=1 count=16 2>/dev/null

# ============================================================
# Block 0: Boot Block (512 bytes) loaded at $0800
# ============================================================
# $0800: BRA +3 past header bytes
printf '\x80\x03\xEA\xEA'

# $0804: Switch to native 65C816 mode, 8-bit regs
#   CLC (clear carry) then XCE (exchange carry with emulation)
#   SEP #$30 (set M and X flags = 8-bit accumulator/index)
printf '\x18\xFB\xE2\x30'

# $080A: Clear text screen ($0400-$07FF) with spaces
printf '\xA9\x20'                 # LDA #$20 (space)
printf '\xA0\x00'                 # LDY #0
printf '\xA2\x00'                 # LDX #0
printf '\x99\x00\x04'             # .loop STA $0400,Y
printf '\x99\x00\x05'             # STA $0500,Y
printf '\x99\x00\x06'             # STA $0600,Y
printf '\x99\x00\x07'             # STA $0700,Y
printf '\xC8'                     # INY
printf '\xD0\xF1'                 # BNE .loop (branch to $0814 - back 15 bytes)

# $081B: Print banner via COUT ($FDED)
printf '\xA2\x00'                 # LDX #0
printf '\xBD\xCE\x08'             # .banner LDA banner,X (banner at $08CE)
printf '\xF0\x09'                 # BEQ .bdone
printf '\x20\xED\xFD'             # JSR $FDED (COUT)
printf '\xE8'                     # INX
printf '\x80\xF5'                 # BRA .banner (back -11)
# .bdone: (falls through)

# $082B: REPL - print prompt "p] "
printf '\xA9\x70'                 # LDA #'p'
printf '\x20\xED\xFD'             # JSR COUT
printf '\xA9\x5D'                 # LDA #']'
printf '\x20\xED\xFD'             # JSR COUT
printf '\xA9\x20'                 # LDA #' '
printf '\x20\xED\xFD'             # JSR COUT

# $083B: Read keyboard into buffer at $0900
printf '\xA0\x00'                 # LDY #0
printf '\xAD\x00\xC0'             # .key LDA $C000
printf '\x10\xFB'                 # BPL .key (wait for keypress)
printf '\x99\x00\x09'             # STA $0900,Y
printf '\xC8'                     # INY
printf '\x48'                     # PHA
printf '\xAD\x10\xC0'             # LDA $C010 (clear strobe)
printf '\x68'                     # PLA
printf '\xC9\x0D'                 # CMP #$0D (Enter?)
printf '\xF0\x07'                 # BEQ .endline
printf '\xC0\x20'                 # CPY #$20 (max 32)
printf '\xF0\x03'                 # BEQ .endline
printf '\x80\xEC'                 # BRA .key
# .endline:
printf '\xA9\x00'                 # LDA #0
printf '\x99\x00\x09'             # STA $0900,Y (null terminate)
# Print newline
printf '\xA9\x8D'                 # LDA #$8D (CR)
printf '\x20\xED\xFD'             # JSR COUT

# $0862: Check for empty line
printf '\xAD\x00\x09'             # LDA $0900
printf '\xF0\xC6'                 # BEQ REPL (back to $082B)

# $0868: Dispatch on first char
printf '\xC9\x3F'                 # CMP #'?'
printf '\xF0\x1E'                 # BEQ cmd_peek
printf '\xC9\x21'                 # CMP #'!'
printf '\xF0\x2C'                 # BEQ cmd_poke
printf '\xC9\x53'                 # CMP #'S'
printf '\xF0\x3A'                 # BEQ cmd_sys
printf '\xC9\x48'                 # CMP #'H'
printf '\xF0\x44'                 # BEQ cmd_help

# $087A: Not a command - hex number display
printf '\x20\xA2\x08'             # JSR parse_hex ($08A2)
printf '\xA5\x06'                 # LDA $06 (digit count)
printf '\xF0\xAC'                 # BEQ REPL (no digits, back to $082B)
# Print hex, dec, bin
printf '\x20\xD4\x08'             # JSR print_hex_word
printf '\xA9\x20'                 # LDA #' '
printf '\x20\xED\xFD'             # JSR COUT
printf '\x20\xEC\x08'             # JSR print_dec
printf '\xA9\x20'                 # LDA #' '
printf '\x20\xED\xFD'             # JSR COUT
printf '\x4C\x2B\x08'             # JMP REPL

# $0898: cmd_peek (?)
printf '\xA9\x3F'                 # LDA #'?'
printf '\x20\xED\xFD'             # JSR COUT
printf '\x4C\x2B\x08'             # JMP REPL

# $08A1: cmd_poke (!)
printf '\xA9\x21'                 # LDA #'!'
printf '\x20\xED\xFD'             # JSR COUT
printf '\x4C\x2B\x08'             # JMP REPL

# $08AA: cmd_sys (S)
printf '\xA9\x53'                 # LDA #'S'
printf '\x20\xED\xFD'             # JSR COUT
printf '\x4C\x2B\x08'             # JMP REPL

# $08B3: cmd_help (H)
printf '\xA2\x00'                 # LDX #0
printf '\xBD\xD8\x08'             # .help LDA help_msg,X
printf '\xF0\x06'                 # BEQ .hdone
printf '\x20\xED\xFD'             # JSR COUT
printf '\xE8'                     # INX
printf '\x80\xF5'                 # BRA .help
# .hdone:
printf '\x4C\x2B\x08'             # JMP REPL

# $08C6: parse_hex (subroutine - parses hex at $0900 into $04/$05, count in $06)
printf '\xA0\x00'                 # LDY #0
printf '\x64\x04'                 # STZ $04 (value lo)
printf '\x64\x05'                 # STZ $05 (value hi)
printf '\x64\x06'                 # STZ $06 (count)
printf '\xB9\x00\x09'             # .hloop LDA $0900,Y
printf '\xF0\x17'                 # BEQ .hret
printf '\xC9\x30'                 # CMP #'0'
printf '\x90\x14'                 # BCC .hret
printf '\xC9\x47'                 # CMP #'G'
printf '\xB0\x10'                 # BCS .hret (skip non-hex)
printf '\xC9\x3A'                 # CMP #':'
printf '\x90\x04'                 # BCC .digit (0-9)
printf '\xC9\x41'                 # CMP #'A'
printf '\x90\x09'                 # BCC .hret (skip :;<=>?@)
printf '\x38'                     # SEC
printf '\xE9\x07'                 # SBC #7 (adjust for A-F gap)
# .digit:
printf '\x29\x0F'                 # AND #$0F
printf '\x06\x04'                 # ASL $04 (value << 4)
printf '\x26\x05'                 # ROL $05
printf '\x06\x04'                 # x2
printf '\x26\x05'
printf '\x06\x04'                 # x3
printf '\x26\x05'
printf '\x06\x04'                 # x4
printf '\x26\x05'
printf '\x05\x04'                 # ORA $04 (combine)
printf '\x85\x04'                 # STA $04
printf '\xE6\x06'                 # INC $06 (count++)
printf '\xC8'                     # INY
printf '\x80\xDA'                 # BRA .hloop
# .hret:
printf '\x60'                     # RTS

# $08F8: print_hex_word (prints $04/$05 as 4 hex chars via COUT)
printf '\xA5\x05'                 # LDA $05 (high byte)
printf '\x20\x00\x09'             # JSR print_hex_byte
printf '\xA5\x04'                 # LDA $04 (low byte)
# fall through to print_hex_byte

# $08FE: print_hex_byte (A -> two hex chars)
printf '\x48'                     # PHA
printf '\x4A'                     # LSR A
printf '\x4A'                     # LSR A
printf '\x4A'                     # LSR A
printf '\x4A'                     # LSR A
printf '\x20\x08\x09'             # JSR print_nibble
printf '\x68'                     # PLA
printf '\x29\x0F'                 # AND #$0F
# fall through to print_nibble

# $090A: print_nibble (low nibble of A -> hex)  
printf '\x09\x30'                 # ORA #'0'
printf '\xC9\x3A'                 # CMP #':'
printf '\x90\x02'                 # BCC .ok
printf '\x69\x06'                 # ADC #6 (adjust to 'A'-'9'-1 = 6 + carry)
# .ok:
printf '\x20\xED\xFD'             # JSR COUT
printf '\x60'                     # RTS

# $0914: print_dec (prints $04/$05 as decimal)
printf '\xA2\x00'                 # LDX #0 (placeholder - decimal is complex)
printf '\x60'                     # RTS (skip for now)

# =========== DATA ===========
# $0918: banner
printf '\x50\x75\x63\x6B\x20\x4D\x6F\x6E'  # Puck Mon
printf '\x20\x76\x30\x2E\x31\x20\x36\x35'  #  v0.1 65
printf '\x63\x38\x31\x36\x0D\x00'          # c816\r\0

# $092E: help_msg
printf '\x3F\x20\x70\x65\x65\x6B\x20\x21'  # ? peek !
printf '\x20\x70\x6F\x6B\x65\x20\x53\x20'  #  poke S 
printf '\x73\x79\x73\x20\x48\x20\x68\x65'  # sys H he
printf '\x6C\x70\x0D\x00'                  # lp\r\0

# ============================================================
# Pad to 512 bytes, then add empty blocks to fill 800K
# ============================================================
# Fill rest of block 0
CURRENT=$(wc -c < /dev/stdin 2>/dev/null || echo 0)
# Actually just pad with a single printf
printf '\x00%.0s' {1..200} > /dev/null  # dummy
# We'll use dd to pad

# Write everything to a temp file, then pad
cat > /tmp/puckmon_hex.hex << '__HEX_END__'
# (we'll use a different approach)
__HEX_END__

# ============================================================
# Build disk image using python for precise control
# ============================================================
python3 -c "
import struct, os

# 64-byte .2mg header
hdr = struct.pack('<4s4sHHIIIIIIII16s',
    b'2IMG',       # magic
    b'PUCK',       # creator
    64,            # header size
    1,             # version
    1,             # format (ProDOS order)
    0,             # flags
    1600,          # blocks
    64,            # data offset
    819200,        # data length (800K)
    0, 0,          # comment offset/len
    0, 0,          # creator offset/len
    bytes(16))     # reserved

# Boot block hex
boot_hex = (
    # Offset 000: BRA +3 skip header
    '8003EAEA'
    # Offset 004: CLC XCE SEP #\$30 (native 8-bit mode)
    '18FBE230'
    # Offset 008: Clear screen \$0400-\$07FF
    'A920A000A200990004990005990006990007C8D0F1'
    # Offset 01B: Print banner
    'A200BDCE08F00920EDFDE880F5'
    # Offset 02B: REPL prompt \"p] \"
    'A97020EDFDA95D20EDFDA92020EDFD'
    # Offset 03B: Read keyboard to \$0900
    'A000AD00C010FB990009C848AD10C068C90DF007C020F00380EC'
    'A900990009A98D20EDFD'
    # Offset 062: Check empty line
    'AD0009F0C6'
    # Offset 068: Dispatch
    'C93FF01EC921F02CC953F03AC948F044'
    # Offset 07A: Hex number display
    '20A208A506F0ACA9A520EDFD20D408A92020EDFD20EC08A92020EDFD4C2B08'
    # Offset 098: cmd_peek stub
    'A93F20EDFD4C2B08'
    # Offset 0A1: cmd_poke stub
    'A92120EDFD4C2B08'
    # Offset 0AA: cmd_sys stub
    'A95320EDFD4C2B08'
    # Offset 0B3: cmd_help
    'A200BDD808F00620EDFDE880F54C2B08'
    # Offset 0C6: parse_hex subroutine
    'A000640464056406B90009F017C9309014C94DB00CC93A9004C941900938E907290F'
    '06042605060426050604260505048504E606C880DA60'
    # Offset 0F8: print_hex_word
    'A50520FE08A504'
    # Offset 0FE: print_hex_byte
    '484A4A4A4A20080968290F'
    # Offset 10A: print_nibble
    '0930C93A9002690620EDFD60'
    # Offset 114: print_dec placeholder
    'A20060'
    # Offset 118: banner \"Puck Mon v0.1 65c816\\r\\0\"
    '5075636B204D6F6E2076302E31203635633831360D00'
    # Offset 12E: help_msg \"? peek ! poke S sys H help\\r\\0\"
    '3F207065656B2021706F6B6520532073797320482068656C700D00'
)

boot_bytes = bytes.fromhex(boot_hex)
boot_block = boot_bytes + bytes(512 - len(boot_bytes))

# Build disk image
disk = bytearray(hdr)
disk.extend(boot_block)
disk.extend(bytes(512 * 1599))  # remaining blocks

# Write image
with open('puckmon.2mg', 'wb') as f:
    f.write(disk)

print(f'Puck Mon disk image created: puckmon.2mg ({len(disk)} bytes)')
print(f'Boot block size: {len(boot_bytes)} bytes')
print(f'Remaining: {512 - len(boot_bytes)} bytes free')
"

# ============================================================
# Boot with MAME
# ============================================================
mame apple2gs -flop3 puckmon.2mg -nomouse -window 2>/dev/null || \
mame apple2gs -flop3 puckmon.2mg