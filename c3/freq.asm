
; ----------------------------------------------
; Solves the second of the cryptopal challenges:
; xor one buffer with another
; ----------------------------------------------
; :asmsyntax=nasm

%define FIRST_ARG   [rbp + 0x10]
%define SECOND_ARG  [rbp + 0x18]
%define THIRD_ARG   [rbp + 0x20]



%define WORDSIZE    8
%macro drop 1
  add   rsp, (WORDSIZE * %1)
%endmacro


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
extern  is_ascii, allbytes, memcpy, hexbyte

global _start


print_hexbyte_dash:
  push  rbp
  mov   rbp, rsp
  sub   rsp, 0x10
  mov   rax, FIRST_ARG
  push  QWORD [rbp]
  push  rax
  call  hexbyte
  drop  2
  mov   rax, [rbp]
  mov   DWORD [rax + 2], 0x202d2d20 ;; " -- "
  mov   BYTE [rax + 6],  0x00
  push  STDOUT
  push  rax
  call  print0
  drop  2

  mov   rsp, rbp
  pop   rbp
  ret
  

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
  mov   QWORD [scratch], rax
  call  allocate
  mov   QWORD [scratch2], rax
  drop  1
  push  rdx
  push  QWORD [ciphertext]
  push  QWORD ARGV(1)
  call  decode_hexstr
  drop	1 
  
  shr   rdx, 1          ;; half as many bytes as chars in the hex string
  mov   QWORD [rbp - 8], rdx  ;; save length on the stack

.brute_forcing:
  xor   rdx, rdx
  not   rdx
  and   rdx, 0xFF
.loop: 
;  push  QWORD [scratch2]
;  push  rdx
;  call  hexbyte
;  drop  2
;  push  STDOUT
;  push  QWORD [scratch2]
;  call  print0
;  drop  1
;  call  terpri
;  drop  1

;;; debyggig
;  dec   rdx
;  test  rdx, rdx
;  jmp   .loop


  push  rdx  ;; make sure rdx isn't polluted at any point in this loop
  push  QWORD [rbp - 8]
  push  QWORD [scratch]
  call  memset
.check_stack_breakpoint:
  ;; now, the correct arguments *should* already be on the stack
  push  QWORD [ciphertext]
  call  xorbufs
  drop	1         ;; pop the FIRST_ARG of xorbugs (buffer 1) from stack
  pop   rax ;; rax should be pointing to the scratch buffer now
  push  is_ascii
  push  QWORD [rbp - 8] ;; the length variable
  push  rax ;; pointer to scratch buffer
  call  allbytes
  drop	3 
  test  rax, rax
  jz    .skip_print
.found_ascii_string:
  push  rdx
  call  print_hexbyte_dash
  drop  1
  push  STDOUT
  push  QWORD [scratch]
  call  print0
  drop	1
  call  terpri
.skip_print:
  test  dx, dx
  jz    .done
  dec   dx
  jmp   .loop
;  not   dx
;  test  dx, dx
;  jz    .done    ;; ~ 0xFF == 0x00
;  not   dx
;  inc   dx
; jmp   .loop
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

scratch2:
  dq 0x0000000000000000

all_ascii:
  db "All ascii!", 0x0A, 0x00

canary:
  db "the canary still tweets!"
