; ----------------------------------------------
; Solves the first of the cryptopal challenges:
; convert a hex string to base64
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

global _start

extern println, readln, decode_hexstr, allocate, exit_fail, exit_success
extern zerocool, initial_break, current_break, base64

section .text

%define bytes_read [rbp - 4]
_start:
  ;; first, let's look at the command line arguments
  pop   r10           ;; argc
  pop   r11           ;; argv
  mov   rbp, rsp
  sub   rsp, 0x10
   
  push  0x1000
  call  allocate
  mov   [hex_start], rax
  push  0x1000
  push  rax
  call  zerocool

  push  0x2000
  call  allocate
  mov   [raw_start], rax
  push  0x2000
  push  rax
  call  zerocool

  push  0x1000
  call  allocate
  mov   [b64_start], rax
  push  0x1000
  push  rax
  call  zerocool
                                      ;; let's read the hex string into hex_start
  ;mov   rax, [hex_start]
  ;mov   rbx, STDIN
  push  QWORD STDIN
  push  QWORD [hex_start]
  call  readln
  dec   rax                           ;; we don't want to count the '\n' at the end
  mov   bytes_read, rax               ;; store number of bytes read on stack 
                                      ;; printing hex back out, to test
  ;mov   rax, [hex_start]
  ;mov   rbx, STDOUT
  ;call  println

  mov   rax, bytes_read
  push  QWORD rax
  push  QWORD [raw_start]
  push  QWORD [hex_start]
  
  call  decode_hexstr

  mov   rax, bytes_read
  shr   rax, 1                        ;; two characters have been read for each byte, so divide by 2
  push  QWORD rax
  push  QWORD [b64_start]
  push  QWORD [raw_start]
 
  call  base64
  
  ;mov   rax, [b64_start]
  ;mov   rbx, STDOUT
  push  STDOUT
  push  QWORD [b64_start]
  call  println
  jmp   exit_success



;-------------;
 section .data
;-------------;

fail_msg      db    "FAILED", 0x0A, 0x00
success_msg   db    "SUCCESS", 0x0A, 0x00

hex_start:
  dq 0x0000000000000000
raw_start:
  dq 0x0000000000000000
b64_start:
  dq 0x0000000000000000

hex_size:
  dd 0x1000
byte_size:
  dd 0x2000
b64_size:
  dd 0x1000

b64_chars:
  db "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/", 0x00

test_msg:
  db "Hello, world!", 0x0A, 0x00


