.option norvc
.text
.globl _start

_start:
.Ltarget:
    bne x31, x31, .Ltarget
