
; ----------------------------------------------
; Solves the second of the cryptopal challenges:
; xor one buffer with another
; ----------------------------------------------
; :asmsyntax=nasm

%define FIRST_ARG   [rbp + 0x10]
%define SECOND_ARG  [rbp + 0x18]
%define THIRD_ARG   [rbp + 0x20]

%define WORDSIZE    8

%define SYS_BRK     0x0C
%define SYS_OPEN    0x02
%define SYS_WRITE   0x01 ;0x04
%define SYS_READ    0x00
%define SYS_CLOSE   0x03
%define SYS_EXIT    0x3C

%define O_RDONLY              0000q
%define O_CREATE_WRONLY_TRUNC 3101q

%define STDIN   0
%define STDOUT  1
%define STDERR  2

%define SUCCESS     0x00
%define FAILURE     0x01
%define EOF         0x00

%define NEWLINE     0x0A

%define END_STRING 0x00

%define ARGV(i) [rbp + (8 * (i+1))]
%define ARGC    [rbp]

extern  xorbufs, print0, read0, base64, decode_hexstr, allocate, zerocool
extern  exit_fail, exit_success, terpri, memset, println, pos
extern  is_ascii, allbytes, memcpy

global _start


_start:
  mov   rbp, rsp
  sub   rsp, 0x10
  cmp   BYTE ARGC, 2
  je    .argc_ok
  push  STDERR
  push  QWORD usage_msg
  call  println
  jmp   exit_fail

.argc_ok:

.loading_ciphertext:
  push  0x00
  push  QWORD ARGV(1)
  call  pos
  mov   rdx, rax    ;; stow away length

;;;;;;;;;;;;
;.first_an_experiment:
;  push  is_ascii
;  push  rdx
;  push  QWORD ARGV(1)
;  call  allbytes
;  test  rax, rax
;  jz    exit_fail
;  push  STDOUT
;  push  all_ascii
;  call  println
;;;;;;;;;;;;;

  push  rax
  call  allocate
  mov   QWORD [ciphertext], rax
  push  rdx
  call  allocate
  sub   rsp, WORDSIZE
  mov   QWORD [scratch], rax
  sub   rsp, WORDSIZE
  push  rdx
  push  QWORD [ciphertext]
  push  QWORD ARGV(1)
  call  decode_hexstr
  sub   rsp, WORDSIZE
  
  shr   rdx, 1          ;; half as many bytes as chars in the hex string
  mov   QWORD [rbp - 8], rdx  ;; save length on the stack

.brute_forcing:
  xor   rdx, rdx
.loop:
  push  rdx  ;; make sure rdx isn't polluted at any point in this loop
  push  QWORD [rbp - 8]
  push  QWORD [scratch]
  call  memset
.check_stack_breakpoint:
  ;; now, the correct arguments *should* already be on the stack
  push  QWORD [ciphertext]
  call  xorbufs
  sub   rsp, WORDSIZE ;; pop the FIRST_ARG of xorbugs (buffer 1) from stack
  pop   rax ;; rax should be pointing to the scratch buffer now
  push  is_ascii
  push  QWORD [rbp - 8] ;; the length variable
  push  rax ;; pointer to scratch buffer
  call  allbytes
  sub   rsp, (3 * WORDSIZE)
  test  rax, rax
  jz    .skip_print
  push  STDOUT
  push  QWORD [scratch]
  call  print0
  sub   rsp, WORDSIZE
  call  terpri
.skip_print:
  not   dl
  test  dl, dl
  jz    .done    ;; ~ 0xFF == 0x00
  not   dl
  inc   dl
  jmp   .loop
.done:
    

  
  jmp   exit_success

  

section .data

usage_msg:
  db  "Usage: ./freq <ciphertext>", 0x0A, 0x00

repeated:
  dq 0x0000000000000000

ciphertext:
  dq 0x0000000000000000

scratch:
  dq 0x0000000000000000


all_ascii:
  db "All ascii!", 0x0A, 0x00
