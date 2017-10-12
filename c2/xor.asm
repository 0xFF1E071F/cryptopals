
; ----------------------------------------------
; Solves the second of the cryptopal challenges:
; xor one buffer with another
; ----------------------------------------------
; :asmsyntax=nasm

%define FIRST_ARG   [rbp + 0x10]
%define SECOND_ARG  [rbp + 0x18]
%define THIRD_ARG   [rbp + 0x20]

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

global  _start
extern  print0, read0, println, readln, decode_hexstr
extern  terpri, exit_fail, exit_success, pos, min
extern  allocate, base64

section .text


xorbufs:
;; destroys SECOND_ARG (well, sort of. it is just xor, after all)
  push  rbp
  mov   rbp, rsp
  push  rsi
  push  rcx
  push  rdi
  mov   rsi, FIRST_ARG   ;; buffer 1
  mov   rax, SECOND_ARG  ;; buffer 2
  mov   rcx, THIRD_ARG   ;; length
  
.loop:
  ;; assuming that the length >= 1
  mov   rdi, QWORD [rsi]
  xor   QWORD [rax], rdi
  add   rax, 8
  add   rsi, 8
  sub   rcx, 8
  ;; note that this might overshoot the buffer. 
  ;; but this should be harmless, so long as the buffers
  ;; have at least a word of elbow room
  test  rcx, rcx
  jg    .loop 
  
  mov   rax, SECOND_ARG ;; send the pointer back to the start of buffer
  pop   rdi
  pop   rcx
  pop   rsi
  mov   rsp, rbp
  pop   rbp
  ret


%define ARGV(i) [rbp + (8 * (i+1))]
%define ARGC    [rbp]
%define shortest [rbp - 4]
_start: 
  mov   rbp, rsp
  cmp   BYTE ARGC, 3
  je    .argc_okay
  push  QWORD usage_msg
  call  println
  call  exit_fail

  sub   rsp, 0x20

.argc_okay:
  ;push  STDOUT
  ;push  QWORD ARGV(1) ;;QWORD [rbp + 0x10]
  ;call  print0
  ;push  STDOUT
  ;call  terpri
  
.calculating_lengths:

  push  0x00
  push  QWORD ARGV(1)
  call  pos
  mov   rbx, rax
  push  0x00
  push  QWORD ARGV(2)
  call  pos
  push  rax
  push  rbx
  call  min
  mov   QWORD shortest, rax

.allocating_memory:

  shl   rax, 1  ;; just to be safe, double it
  push  rax
  call  allocate
  mov   [buf1_start], rax
 
  ;; same arg should be on stack, still
  call  allocate
  mov   [buf2_start], rax

  call  allocate
  mov   [out_start], rax

.decoding_hex:

  mov   rax, QWORD shortest
  push  rax  ;; length of shortest buffer
  push  QWORD [buf2_start]
  push  QWORD ARGV(2)
  call  decode_hexstr

  mov   rax, QWORD shortest
  push  rax
  push  QWORD [buf1_start]
  push  QWORD ARGV(1)
  call  decode_hexstr

.ready_to_xor:

  mov   rax, QWORD shortest
  shr   rax, 1              ;; divide by 2 - byte -> nibble
  push  rax
  push  QWORD [buf2_start]
  push  QWORD [buf1_start]
  call  xorbufs

  mov   rbx, shortest
  shr   rbx, 1
  push  rbx
  push  QWORD [out_start]
  push  QWORD [buf2_start]
  call  base64

  push  STDOUT
  push  QWORD [out_start]
  call  println

  
  jmp   exit_success

section .data

usage_msg:
  db  "Usage: ./xor <hexstring> <hexstring>", NEWLINE, 0x00

buf1_start:
  dq 0x0000000000000000

buf2_start:
  dq 0x0000000000000000

out_start:
  dq 0x0000000000000000
