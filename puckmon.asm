; ============================================================
;  PUCK MON  — 16‑bit real mode, ring 0, <500 bytes
;  Boot sector loads 4 sectors (2KB) to 0x1000:0x0000
; ============================================================

;------------------- Boot Sector (512 bytes) --------------------
; (offsets from 0x7C00)
EB 3C 90               ; jmp 0x7C3E  (skip BPB)
times 0x3B db 0         ; BPB placeholder
; 0x7C3E
31 C0                  ; xor  ax,ax
8E D8                  ; mov  ds,ax
8E C0                  ; mov  es,ax
8E D0                  ; mov  ss,ax
BC 00 7C               ; mov  sp,0x7C00
BE 82 7C               ; mov  si,banner
E8 25 00               ; call print_str
B8 00 10               ; mov  ax,0x1000
8E C0                  ; mov  es,ax
31 DB                  ; xor  bx,bx
B4 02 B0 04            ; mov  ah,0x02 / mov al,4
B5 00 B1 02            ; mov  ch,0 / mov cl,2
B6 00 B2 00            ; mov  dh,0 / mov dl,0
CD 13                  ; int  0x13
72 05                  ; jc   disk_error
EA 00 00 00 10         ; jmp  0x1000:0x0000
; disk_error:
BE 8C 7C               ; mov  si,err_msg
E8 03 00               ; call print_str
F4                     ; hlt
EB FD                  ; jmp  $
; print_str:
AC                     ; lodsb
84 C0                  ; test al,al
74 06                  ; jz   .done
B4 0E B7 00 CD 10      ; BIOS teletype
EB F4                  ; jmp  print_str
C3                     ; .done: ret
banner:   db "Puck Mon",13,10,0       ; 50 75 63 6B 20 4D 6F 6E 0D 0A 00
err_msg:  db "Disk!",13,10,0          ; 44 69 73 6B 21 0D 0A 00
times (510-($-$$)) db 0
dw 0xAA55

;------------------- Puck Mon Monitor (0x1000:0x0000) -----------
; Setup
FA                     ; cli
B8 00 10               ; mov  ax,0x1000
8E D8                  ; mov  ds,ax
8E C0                  ; mov  es,ax
8E D0                  ; mov  ss,ax
BC 00 0C               ; mov  sp,0x0C00        ; stack below monitor
BE 8B 01               ; mov  si,banner_msg    ; offset 0x018B
E8 53 00               ; call print_str

; REPL
BE 9E 01               ; mov  si,prompt        ; "puck] "
E8 4D 00               ; call print_str
E8 2E 00               ; call read_line
E8 19 00               ; call newline
80 3E A4 01 00         ; cmp  byte [input_buf],0
74 F1                  ; je   repl

; Dispatch
BE A4 01               ; mov  si,input_buf
8A 04                  ; mov  al,[si]
3C 3F                  ; cmp  al,'?'          ; peek
74 3C                  ; je   cmd_peek
3C 21                  ; cmp  al,'!'          ; poke
74 4E                  ; je   cmd_poke
3C 53                  ; cmp  al,'S'          ; sys
74 5A                  ; je   cmd_sys
3C 48                  ; cmp  al,'H'          ; help
74 60                  ; je   cmd_help

; Hex number display
E8 62 00               ; call parse_hex
83 F9 00               ; cmp  cx,0
74 D9                  ; je   repl_err        ; no digits
89 D0                  ; mov  ax,dx
E8 7D 00               ; call print_hex_word
E8 65 00               ; call space
89 D0                  ; mov  ax,dx
E8 0F 01               ; call print_dec
E8 5F 00               ; call space
89 D0                  ; mov  ax,dx
E8 24 01               ; call print_bin
E8 4E 00               ; call newline
E9 8E FF               ; jmp  repl

; Error / help / peek / poke / sys handlers (abbreviated)
; ... (full code as in raw hex below)