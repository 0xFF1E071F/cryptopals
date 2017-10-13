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


global _start
section .text

extern print0, hexword, terpri, allocate

_start:
  
  push  0x1000
  call  allocate
  mov   [buffer], QWORD rax

  sub   rsp, 8
  mov   rdi, rsp
  sub   rsp, 8
  mov   rsi, rsp
  mov   rax, 96
  syscall
  mov   rdx, [rdi]

.loop:
  push  QWORD [buffer]
  push  rdx
  call  hexword
  drop  2
  push  STDOUT
  push  QWORD [buffer]
  call  print0
  drop  1
  call  terpri
  drop  1
  mov   rax, 35
  push  QWORD [time_req]
  mov   rdi, rsp
  push  QWORD [time_req]
  mov   rsi, rsp
  syscall
  inc   rdx
  mov   rax, rdx
  not   rax
  test  rax, rax
  jne   .loop





section .data

breakpad:
  dq  0xCCCCCCCCCCCCCCCC

buffer:
  dq 0x0000000000000000

time_req:
  dq  1
  dq  0

time_rem:
  dq 1
  dq 0
