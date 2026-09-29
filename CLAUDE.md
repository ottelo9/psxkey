# PSXKEY – project knowledge for Claude

MS-DOS TSR (NASM, .COM) that bit-bangs a PlayStation controller on the parallel port (LPT) and injects keystrokes at keyboard-controller level (8042 command `0xD2`). Games with their own INT 9 handler (e.g. Commander Keen) therefore see the keys.

Author: ottelo – ottelo.jimdofree.com – github.com/ottelo9 (remote `https://github.com/ottelo9/psxkey.git`, branch `main`).

## Build

`nasm -f bin PSXKEY.asm -o PSXKEY.COM` after every change to the ASM file; the built COM is committed.

## Files

| File | Content |
|---|---|
| `PSXKEY.asm` | entire source (comments German, messages English) |
| `PSXKEY.COM` | build (~8 KB), resident **469 bytes / 30 paragraphs** |
| `README.md` | English docs (wiring, INI, LPT mode/IRQ, auto port, delay, test mode, 3.3 V ports, source map) |
| `docs/index.html` | GitHub Pages help page, DE/EN switchable (`data-lang`, `localStorage 'psxkey-lang'`), light/dark; images are copies in `docs/` |
| `img/` | `psxkey_converter.jpg`, `psxkey_start.jpg`, `psxkey_testmode.jpg`, `psxkey_game_keen.jpg` (last three have EXIF orientation 6 = portrait, so width limited to 420–440 px), `wiring.svg` |

## Structure of PSXKEY.asm

Everything **before the label `install`** stays resident. Keep size is computed from the install offset; the file starts with `jmp install` (E9 rel16).

Resident part:
- Data: `oldint8`, `oldint2f`, `busy`, `dport` (default 0x3BC), `dly` (default 0x0300), `recv[5]`, `cnt[14]` (last state per button), `keymap[14]` (word: low = scancode, high bit0 = E0 prefix), `btnoff`/`btnmask` (byte/bit in recv, active-low)
- `int2f`: multiplex ID `0xC9` (install check, AL=0 → 0xFF, BX=CS)
- `isr8`: timer ISR with `busy` reentrancy lock → `pollpad` → edge detection per button → `sendmake`/`sendbreak`; state is only committed on success (CF=0), otherwise retried next tick
- `kbcbyte`: IBF wait → `out 64h,D2h` → IBF wait → `out 60h,scancode` → OBF wait; timeout → CF=1
- `pollpad`/`xchg`/`delay`: PSX protocol, poll `01 42 00 00 00`, LSB first; `recv[1]` = ID (0x41 digital, 0x73 analog), `recv[2]` = 0x5A (data marker), `recv[3]/[4]` = buttons

Transient part: `install` (banner → `getini` → `parse` → `showini` → `doauto` → with `/T` run `testmode` and exit, else hook INT 8 + INT 2F and go TSR), `unload` (/U, only if vectors still point to us), `parsecmd` (/U /T /? /H), `doauto`/`autodet`/`probe`/`initctl`/`ecpspp`/`dumpraw`, `testmode` (INT 10h screen, 14 buttons live as `*`/`.`, raw line, ESC quits), `getini` (INI name = program path from environment with .ini extension; if missing, `defini` is written), `parse`/`matchbtn`/`mapval`/`lcval`/`isdly`/`isport`/`streq`/`parsehex`.

## Hardware / LPT

- Data port `base`: D0 (pin 2) = CMD, D1 (pin 3) = ATT, D2 (pin 4) = CLK, D4–D7 (pins 6–9, `POWER = 0xF0`) = supply via 4 diodes → +V. Status `base+1` bit 6 (pin 10) = DATA. GND = pins 18–25.
- Control `base+2`: `initctl` writes 0x0C (output, IRQ off). ECP ECR at `base+0x402`; `ecpspp` detects it (write 0x34 → read 0x35) and sets mode 000 (SPP).
- BIOS: SPP/Normal or Bi-Direct; no IRQ needed (polled from timer).
- `port = auto`: tests LPT base addresses from BIOS data area `0040:0008`, per port a delay sweep over `dlytab` (0x300, 0x100, 0x80, 0x800, 0x1800, 0x4000) unless `delay` is set in the INI. No hit: first port, delay 0x300, "no pad found" + raw dump.
- **Timing is CPU dependent** (delay loop): ThinkPad 380XD (P-MMX 233, 0x3BC) → 0x0300; Toshiba Satellite Pro 4600 (P-III, 0x378) → 0x0800. That was the real cause of the Toshiba problems, not the voltage.
- Some laptops (Toshiba) have 3.3 V ports (~3.4 V high).
- Runs only in real DOS or Win98 "MS-DOS mode", not in a DOS box (I/O is virtualized). No EMM386.

## INI (PSXKEY.INI)

`button = key` per line; `[...]`, `;` and `//` are ignored. Buttons: up down left right start select cross circle triangle box l1 l2 r1 r2. Keys: a–z, 0–9, space return enter esc tab, up/down/left/right (E0), ctrl alt shift. Plus `port = auto | 0x378` and `delay = 0x0800` (hex).

Key combos: currently only across two buttons (e.g. `l1 = ctrl`, `cross = e`). A combo on a single button (`cross = ctrl+e`) is not implemented. Possible design: modifier bits in the keymap high byte; make = modifier first, then key; break in reverse order.
