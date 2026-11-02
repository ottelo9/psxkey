# Restart in MS-DOS mode (Windows 98)

`restart_in_ms-dos_mode.pif` restarts Windows 98 into real MS-DOS mode with its own
CONFIG.SYS/AUTOEXEC.BAT and a boot menu:

| # | Menu item | Loads |
|---|---|---|
| 1 | EMC | HIMEM, EMM386 (EMS), mouse, CD-ROM |
| 2 | XMC | HIMEM, mouse, CD-ROM |
| 3 | CMC | mouse, CD-ROM |
| 4 | EM  | HIMEM, EMM386 (EMS), mouse |
| 5 | XM  | HIMEM, mouse |
| 6 | CM  | mouse |
| 7 | E   | HIMEM, EMM386 (EMS) |
| 8 | X   | HIMEM |
| 9 | C   | nothing |

"Mouse" also loads the USB driver `USBDDOS.EXE /HID`. The PIF loads `KEYB GR`
(German keyboard layout); change it in the PIF properties if needed.

Setup: copy `C/Drivers` to `C:\DRIVERS` on the Windows 98 machine and the PIF to the
desktop (or the game folder). Double-click it to restart into DOS.

Which menu item a game needs is noted at the top of its `PSXKEY.INI` in `ini/`.

Source: based on "MS-DOS Mode Super Easy" by Phil's Computer Lab,
<https://www.philscomputerlab.com/ms-dos-mode-super-easy.html>
