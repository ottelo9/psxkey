bits 16
org 0x100
DPORT equ 0x3BC
SPORT equ 0x3BD
POWER equ 0xF0
bCMD  equ 0x01
bATT  equ 0x02
bCLK  equ 0x04
MPXID equ 0xC9

%substr VER __?DATE?__,3,8      ; Build-Datum YY-MM-DD (auto bei jedem Assemblieren)

start:  jmp install

; ---------------- resident data ----------------
oldint8  dd 0
oldint2f dd 0
busy     db 0
dport    dw 0x3BC
recv     times 5 db 0
cnt      times 14 db 0
keymap   times 14 dw 0
btnoff   db 3,3,3,3,3,3,4,4,4,4,4,4,4,4
btnmask  db 0x10,0x40,0x80,0x20,0x08,0x01,0x40,0x20,0x10,0x80,0x04,0x01,0x08,0x02

; ---------------- resident INT 2Fh (multiplex) ----------------
int2f:
    cmp ah,MPXID
    jne .chain
    or al,al
    jne .chain
    mov al,0xFF
    mov bx,cs
    iret
.chain:
    jmp far [cs:oldint2f]

; ---------------- resident timer ISR ----------------
isr8:
    push ax
    push bx
    push cx
    push dx
    push si
    push ds
    push es
    mov ax,cs
    mov ds,ax
    cmp byte [busy],0
    jne .out
    mov byte [busy],1
    sti
    call pollpad
    cli
    xor si,si
.bl:
    mov bl,[btnoff+si]
    xor bh,bh
    mov al,[recv+bx]
    mov ah,[btnmask+si]
    xor dl,dl
    test al,ah
    jnz .np
    mov dl,1
.np:
    mov al,[cnt+si]
    cmp al,dl
    je .cont
    or dl,dl
    jz .brk
    call sendmake
    jc .cont
    mov [cnt+si],dl
    jmp .cont
.brk:
    call sendbreak
    jc .cont
    mov [cnt+si],dl
.cont:
    inc si
    cmp si,14
    jne .bl
    mov byte [busy],0
.out:
    pop es
    pop ds
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    jmp far [cs:oldint8]

sendmake:
    push ax
    push bx
    mov bx,si
    shl bx,1
    mov ax,[keymap+bx]
    or al,al
    jz .ok
    test ah,1
    jz .noe
    push ax
    mov al,0xE0
    call kbcbyte
    pop ax
    jc .fail
.noe:
    call kbcbyte
    jc .fail
.ok:
    pop bx
    pop ax
    clc
    ret
.fail:
    pop bx
    pop ax
    stc
    ret

sendbreak:
    push ax
    push bx
    mov bx,si
    shl bx,1
    mov ax,[keymap+bx]
    or al,al
    jz .ok
    test ah,1
    jz .noe
    push ax
    mov al,0xE0
    call kbcbyte
    pop ax
    jc .fail
.noe:
    or al,0x80
    call kbcbyte
    jc .fail
.ok:
    pop bx
    pop ax
    clc
    ret
.fail:
    pop bx
    pop ax
    stc
    ret

kbcbyte:                 ; al=scancode. CF=0 ok, CF=1 abort
    push cx
    push ax
    mov cx,0x0400
.w1:
    in al,0x64
    test al,2
    jz .o1
    loop .w1
    jmp .ab
.o1:
    mov al,0xD2
    out 0x64,al
    mov cx,0x0400
.w2:
    in al,0x64
    test al,2
    jz .o2
    loop .w2
    jmp .ab
.o2:
    pop ax
    out 0x60,al
    sti
    mov cx,0x0400
.w3:
    in al,0x64
    test al,1
    jz .o3
    loop .w3
.o3:
    cli
    pop cx
    clc
    ret
.ab:
    pop ax
    pop cx
    stc
    ret

pollpad:
    mov dx,[dport]
    mov al,POWER|bCLK|bCMD
    out dx,al
    call delay
    xor bx,bx
.n:
    mov al,[cmdseq+bx]
    call xchg
    mov [recv+bx],al
    inc bx
    cmp bx,5
    jne .n
    mov dx,[dport]
    mov al,POWER|bATT|bCLK|bCMD
    out dx,al
    ret

xchg:
    push bx
    push cx
    mov bl,al
    xor bh,bh
    mov cx,8
.l:
    mov al,POWER
    test bl,1
    jz .c0
    or al,bCMD
.c0:
    mov dx,[dport]
    out dx,al
    push ax
    call delay
    mov dx,[dport]
    inc dx
    in al,dx
    clc
    test al,0x40
    jz .z
    stc
.z:
    rcr bh,1
    pop ax
    or al,bCLK
    mov dx,[dport]
    out dx,al
    call delay
    shr bl,1
    dec cx
    jnz .l
    mov al,bh
    pop cx
    pop bx
    ret

delay:
    push cx
    mov cx,0x0300
.d:
    loop .d
    pop cx
    ret

cmdseq db 0x01,0x42,0x00,0x00,0x00

; ================ transient install ================
install:
    call parsecmd
    cmp byte [whelp],0
    jne .help
    mov ax,MPXID*256
    xor bx,bx
    int 0x2F
    cmp al,0xFF
    je .loaded
    ; ---- not loaded ----
    cmp byte [wunload],0
    jne .notld
    call getini
    jnc .p
    mov dx,noini
    mov ah,9
    int 0x21
    jmp .hook
.p:
    call parse
    cmp byte [madedef],0
    je .hook
    mov dx,defmsg
    mov ah,9
    int 0x21
.hook:
    mov ax,0x352F
    int 0x21
    mov [oldint2f],bx
    mov [oldint2f+2],es
    mov dx,int2f
    mov ax,0x252F
    int 0x21
    mov ax,0x3508
    int 0x21
    mov [oldint8],bx
    mov [oldint8+2],es
    mov dx,isr8
    mov ax,0x2508
    int 0x21
    mov dx,okmsg
    mov ah,9
    int 0x21
    mov dx,install
    add dx,15
    mov cl,4
    shr dx,cl
    mov ax,0x3100
    int 0x21
.loaded:                 ; bx = resident segment
    mov [resseg],bx
    cmp byte [wunload],0
    jne .dounload
    mov dx,alrmsg
    jmp .say
.notld:
    mov dx,notldmsg
    jmp .say
.help:
    mov dx,helptxt
.say:
    mov ah,9
    int 0x21
    mov ax,0x4c00
    int 0x21
.dounload:
    call unload
    mov ax,0x4c00
    int 0x21

; ---- unload resident (resseg set) ----
unload:
    mov ax,0x3508
    int 0x21              ; current int8 -> es:bx
    mov ax,es
    cmp ax,[resseg]
    jne .cant
    mov es,[resseg]
    mov dx,[es:oldint8]
    mov ax,[es:oldint8+2]
    push ds
    mov ds,ax
    mov ax,0x2508
    int 0x21
    pop ds
    mov es,[resseg]
    mov dx,[es:oldint2f]
    mov ax,[es:oldint2f+2]
    push ds
    mov ds,ax
    mov ax,0x252F
    int 0x21
    pop ds
    mov es,[resseg]
    mov es,[es:0x2C]
    mov ah,0x49
    int 0x21
    mov es,[resseg]
    mov ah,0x49
    int 0x21
    mov dx,unlmsg
    mov ah,9
    int 0x21
    ret
.cant:
    mov dx,cantmsg
    mov ah,9
    int 0x21
    ret

parsecmd:
    mov si,0x81
.p:
    mov al,[si]
    or al,al
    je .d
    cmp al,13
    je .d
    cmp al,'/'
    jne .n
    mov al,[si+1]
    cmp al,'a'
    jb .u
    cmp al,'z'
    ja .u
    sub al,0x20
.u:
    cmp al,'U'
    jne .c1
    mov byte [wunload],1
    jmp .n
.c1:
    cmp al,'?'
    je .h
    cmp al,'H'
    jne .n
.h:
    mov byte [whelp],1
.n:
    inc si
    jmp .p
.d:
    ret

getini:
    mov ax,[0x2C]
    mov es,ax
    xor di,di
.sc:
    mov al,[es:di]
    inc di
    or al,al
    jnz .sc
    cmp byte [es:di],0
    jne .sc
    inc di
    add di,2
    mov si,di
    mov di,inifile
.cp:
    mov al,[es:si]
    mov [di],al
    inc si
    inc di
    or al,al
    jnz .cp
    dec di
.fd:
    dec di
    mov bx,inifile
    cmp di,bx
    jb .fail
    cmp byte [di],'.'
    jne .fd
    inc di
    mov byte [di],'i'
    inc di
    mov byte [di],'n'
    inc di
    mov byte [di],'i'
    inc di
    mov byte [di],0
    mov dx,inifile
    mov ax,0x3D00
    int 0x21
    jc .create
    mov bx,ax
    mov dx,filebuf
    mov cx,4000
    mov ah,0x3F
    int 0x21
    mov si,ax
    mov byte [filebuf+si],0
    mov ah,0x3E
    int 0x21
    clc
    ret
.create:
    mov dx,inifile
    xor cx,cx
    mov ah,0x3C
    int 0x21
    jc .fail
    mov bx,ax
    mov dx,defini
    mov cx,defini_len
    mov ah,0x40
    int 0x21
    mov ah,0x3E
    int 0x21
    mov si,defini
    mov di,filebuf
    mov cx,defini_len
.cpy:
    mov al,[si]
    mov [di],al
    inc si
    inc di
    dec cx
    jnz .cpy
    mov byte [di],0
    mov byte [madedef],1
    clc
    ret
.fail:
    stc
    ret

parse:
    mov si,filebuf
.line:
    mov al,[si]
    or al,al
    jz .done
    cmp al,' '
    je .a
    cmp al,9
    je .a
    cmp al,13
    je .a
    cmp al,10
    je .a
    cmp al,'['
    je .skip
    cmp al,';'
    je .skip
    cmp al,'/'
    je .skip
    jmp .rk
.a:
    inc si
    jmp .line
.rk:
    mov di,tokbuf
.rk1:
    mov al,[si]
    or al,al
    je .ek
    cmp al,'='
    je .ek
    cmp al,' '
    je .ek
    cmp al,9
    je .ek
    cmp al,13
    je .ek
    cmp al,10
    je .ek
    cmp al,'A'
    jb .st
    cmp al,'Z'
    ja .st
    add al,0x20
.st:
    mov [di],al
    inc di
    inc si
    jmp .rk1
.ek:
    mov byte [di],0
.feq:
    mov al,[si]
    cmp al,' '
    je .aeq
    cmp al,9
    je .aeq
    cmp al,'='
    je .heq
    jmp .skip
.aeq:
    inc si
    jmp .feq
.heq:
    inc si
.sv:
    mov al,[si]
    cmp al,' '
    je .av
    cmp al,9
    je .av
    jmp .rv
.av:
    inc si
    jmp .sv
.rv:
    mov di,valbuf
.rv1:
    mov al,[si]
    or al,al
    je .ev
    cmp al,13
    je .ev
    cmp al,10
    je .ev
    cmp al,' '
    je .ev
    cmp al,9
    je .ev
    cmp al,','
    je .ev
    mov [di],al
    inc di
    inc si
    jmp .rv1
.ev:
    mov byte [di],0
    call isport
    jnc .npt
    push si
    call parsehex
    pop si
    mov [dport],ax
    jmp .nl
.npt:
    call matchbtn
    cmp bx,0xFFFF
    je .nl
    push bx
    push si
    call mapval
    pop si
    pop bx
    mov di,bx
    shl di,1
    mov [keymap+di],ax
.nl:
    mov al,[si]
    or al,al
    jz .done
    cmp al,10
    je .nld
    inc si
    jmp .nl
.nld:
    inc si
    jmp .line
.skip:
    mov al,[si]
    or al,al
    jz .done
    cmp al,10
    je .skd
    inc si
    jmp .skip
.skd:
    inc si
    jmp .line
.done:
    ret

matchbtn:
    push si
    push di
    xor bx,bx
    mov si,btnnames
.m:
    mov di,tokbuf
.c:
    mov al,[si]
    mov ah,[di]
    cmp al,ah
    jne .nm
    or al,al
    jz .mt
    inc si
    inc di
    jmp .c
.nm:
    mov al,[si]
    inc si
    or al,al
    jnz .nm
    inc bx
    cmp bx,14
    jne .m
    mov bx,0xFFFF
.mt:
    pop di
    pop si
    ret

mapval:
    mov si,valbuf
    mov cl,[si]
    or cl,cl
    jz .z
    cmp byte [si+1],0
    jne .multi
    mov al,cl
    cmp al,'0'
    jb .nd
    cmp al,'9'
    ja .nd
    mov bl,al
    sub bl,'0'
    xor bh,bh
    mov al,[digtab+bx]
    xor ah,ah
    ret
.nd:
    cmp al,'A'
    jb .z
    cmp al,'Z'
    jbe .lc
    cmp al,'a'
    jb .z
    cmp al,'z'
    ja .z
    jmp .hl
.lc:
    add al,0x20
.hl:
    mov bl,al
    sub bl,'a'
    xor bh,bh
    mov al,[lettab+bx]
    xor ah,ah
    ret
.multi:
    call lcval
    mov si,nvtab
.nv:
    mov al,[si]
    or al,al
    jz .z
    mov di,valbuf
.nc:
    mov al,[si]
    mov ah,[di]
    cmp al,ah
    jne .nx
    or al,al
    jz .nm2
    inc si
    inc di
    jmp .nc
.nx:
    mov al,[si]
    inc si
    or al,al
    jnz .nx
    inc si
    inc si
    jmp .nv
.nm2:
    mov al,[si+1]
    mov ah,[si+2]
    ret
.z:
    xor ax,ax
    ret

lcval:
    push si
    mov si,valbuf
.l:
    mov al,[si]
    or al,al
    jz .e
    cmp al,'A'
    jb .n
    cmp al,'Z'
    ja .n
    add al,0x20
    mov [si],al
.n:
    inc si
    jmp .l
.e:
    pop si
    ret

isport:
    push si
    push di
    mov si,tokbuf
    mov di,s_port
    call streq
    jc .y
    mov si,tokbuf
    mov di,s_lpt
    call streq
.y:
    pop di
    pop si
    ret

streq:
    push si
    push di
.l:
    mov al,[si]
    mov ah,[di]
    cmp al,ah
    jne .no
    or al,al
    jz .yes
    inc si
    inc di
    jmp .l
.no:
    pop di
    pop si
    clc
    ret
.yes:
    pop di
    pop si
    stc
    ret

parsehex:
    call lcval
    mov si,valbuf
    cmp byte [si],'0'
    jne .go
    cmp byte [si+1],'x'
    jne .go
    add si,2
.go:
    xor bx,bx
.l:
    mov al,[si]
    or al,al
    jz .done
    cmp al,'0'
    jb .done
    cmp al,'9'
    jbe .dig
    cmp al,'a'
    jb .done
    cmp al,'f'
    ja .done
    sub al,0x57
    jmp .add
.dig:
    sub al,'0'
.add:
    mov cl,4
    shl bx,cl
    xor ah,ah
    add bx,ax
    inc si
    jmp .l
.done:
    mov ax,bx
    ret

s_port db "port",0
s_lpt  db "lpt",0

lettab db 0x1E,0x30,0x2E,0x20,0x12,0x21,0x22,0x23,0x17,0x24,0x25,0x26,0x32,0x31,0x18,0x19,0x10,0x13,0x1F,0x14,0x16,0x2F,0x11,0x2D,0x15,0x2C
digtab db 0x0B,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0A
btnnames db "up",0,"down",0,"left",0,"right",0,"start",0,"select",0,"cross",0,"circle",0,"triangle",0,"box",0,"l1",0,"l2",0,"r1",0,"r2",0
nvtab db "space",0,0x39,0,"return",0,0x1C,0,"enter",0,0x1C,0,"esc",0,0x01,0,"tab",0,0x0F,0,"up",0,0x48,1,"down",0,0x50,1,"left",0,0x4B,1,"right",0,0x4D,1,"ctrl",0,0x1D,0,"alt",0,0x38,0,"shift",0,0x2A,0,0

okmsg    db "PSXKEY PSX Controller Driver for LPT and MS-DOS by ottelo (ottelo.jimdofree.com)",13,10
         db "build ",VER,13,10,'$'
alrmsg   db "psxkey already resident.",13,10,'$'
notldmsg db "psxkey not loaded.",13,10,'$'
unlmsg   db "psxkey unloaded.",13,10,'$'
cantmsg  db "psxkey: cannot unload (another TSR loaded after).",13,10,'$'
noini    db "psxkey: .ini not found, no mapping.",13,10,'$'
helptxt  db "PSXKEY - PSX Controller Driver for LPT / MS-DOS  by ottelo",13,10
         db "  ottelo.jimdofree.com",13,10
         db "Usage:",13,10
         db "  PSXKEY       install (reads PSXKEY.INI)",13,10
         db "  PSXKEY /U    unload",13,10
         db "  PSXKEY /?    this help",13,10
         db "INI: 'button = key' per line; 'port = 0x3BC' sets LPT.",13,10
         db "  sections [], ; and // are ignored.",13,10
         db "Buttons: up down left right start select cross circle",13,10
         db "         triangle box l1 l2 r1 r2",13,10
         db "Keys: letters, digits, space return enter esc tab,",13,10
         db "      up down left right, ctrl alt shift.",13,10
         db "Wiring  LPT DB25 (male)  ->  PSX pad:",13,10
         db "  Pin 2  (D0)          -> CMD",13,10
         db "  Pin 3  (D1)          -> ATT",13,10
         db "  Pin 4  (D2)          -> CLK",13,10
         db "  Pin 10               -> DATA",13,10
         db "  Pin 7-9 via diodes   -> +V (3.3-5V)",13,10
         db "  Pin 18-25            -> GND",13,10,'$'

madedef db 0
defmsg  db "psxkey: PSXKEY.INI not found - created default.",13,10,'$'
defini:
    db "[psx]",13,10
    db "port = 0x3BC",13,10
    db "box = a",13,10
    db "cross = x",13,10
    db "circle = o",13,10
    db "triangle = b",13,10
    db "select = space",13,10
    db "start = return",13,10
    db "l1 = 1",13,10
    db "l2 = 2",13,10
    db "r1 = 3",13,10
    db "r2 = 4",13,10
    db "up = up",13,10
    db "down = down",13,10
    db "left = left",13,10
    db "right = right",13,10
defini_end:
defini_len equ defini_end - defini

wunload db 0
whelp   db 0
resseg  dw 0
inifile times 80 db 0
tokbuf  times 20 db 0
valbuf  times 20 db 0
filebuf times 4096 db 0
