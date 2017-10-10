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

  global println, readln, 
  section .text

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
;; prints the buffer pointed to by rax, to the file descriptor in rbx ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
println:
  push  rbp
  mov   rbp, rsp
  push  rcx
  push  rdi
  push  rsi
  xor   rcx, rcx
  
  mov   rax, FIRST_ARG
  mov   rbx, SECOND_ARG

  mov   rsi, rax
  mov   rdi, rbx  ;; copy the file descriptor to rdi
  mov   rdx, 1    ;; one character at a time

.loop:
  mov   rax, SYS_WRITE
  mov   cl, BYTE [rsi]
  cmp   cl, BYTE NEWLINE 
  je    .done
  syscall

  inc   rsi
  jmp   .loop
    
.done:
;; last character: the newline
  mov   rax, SYS_WRITE
  mov   rcx, rsi
  syscall

  pop   rsi
  pop   rdi
  pop   rcx
  mov   rsp, rbp
  pop   rbp
  ret

readln:
  push  rbp
  mov   rbp, rsp
  push  rdi
  push  rsi
  push  rcx   ;; counter

  xor   rcx, rcx
  push  rcx
  
  mov   rax, FIRST_ARG
  mov   rbx, SECOND_ARG

  mov   rsi, rax
  ;; rsi now points to the buffer to write to

  mov   rax, SYS_READ
  mov   rdi, rbx

  mov   rdx, 1    ;; one char at a time

.loop:  
  mov   rax, SYS_READ
  syscall
  add   [rsp], rdx

  cmp   rax, EOF
  je    .done

  mov   al, BYTE [rsi]
  cmp   al, BYTE NEWLINE
  je    .done

  inc   rsi
  jmp   .loop

.done:

  pop   rax     ;; number of bytes written
  pop   rcx
  pop   rsi
  pop   rdi
  mov   rsp, rbp
  pop   rbp
  ret

  mov   rcx, rsi

hexnibble:
  push  rbp
  mov   rbp, rsp
  push  rcx
  ;; stack now: rbp, ret addr, ptr param
  mov   rcx, FIRST_ARG ;; pointer to first of two characters

  xor   rax, rax

  mov   al, BYTE [rcx] 
  
  cmp   al, '0'
  jl    .bad
  cmp   al, '9'
  jg    .uppercase

.numerical:
  sub   al, '0'
  jmp   .done_nibble

.uppercase:
  cmp   al, 'F'
  jg    .lowercase
  sub   al, 'A'
  add   al, 0x0a
  jmp   .done_nibble

.lowercase:
  cmp   al, 'a'
  jl    .bad
  cmp   al, 'f'
  jg    .bad
  sub   al, 'a'
  add   al, 0x0a
  jmp   .done_nibble

.bad:
  jmp   exit_fail

.done_nibble:
 
  and   rax, 0xFF
  pop   rcx
  mov   rsp, rbp
  pop   rbp
  ;; value of nibble should be in rax
  ret

exit_success:
  ;mov   rax, success_msg
  ;mov   rbx, STDERR
  ;call  println

  mov   rax, SYS_EXIT
  mov   rdi, SUCCESS
  syscall

exit_fail:
  ;mov   rax, fail_msg
  ;mov   rbx, STDERR
  push  STDERR
  push  fail_msg
  call  println

  mov   rax, SYS_EXIT
  mov   rdi, FAILURE
  syscall          ;; exit with exit code 1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Basic memory allocation function. Expects size on stack. ;;
;; Returns pointer to beginning of allocated memory.        ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
allocate:
  push  rbp
  mov   rbp, rsp
  push  rsi
  push  rdi

  mov   rsi, FIRST_ARG        ;; the size to be allocated
    
  mov   rax, [current_break]  
  test  rax, rax
  jne   .already_init
  call  init_mem

.already_init:
  mov   rdi, rax
  add   rdi, rsi
  mov   rax, SYS_BRK
  syscall          ;; sys_brk to allocate 0x1000

  cmp   rax, 0        ;; check return value to make sure it worked
  jl    exit_fail     ;; exit on error
 
  mov   [current_break], rax
  sub   rax, rsi

  pop   rdi
  pop   rsi
  mov   rsp, rbp
  pop   rbp
  ret


init_mem:
  mov   rax, SYS_BRK
  mov   rdi, [initial_break]
  syscall
  ;mov   [current_break], rax
  ret 


%define b64char(i) [b64_chars + i] 
base64:
  push  rbp
  mov   rbp, rsp
  sub   rsp, 8
  push  rsi
  push  rdi
  push  rcx
  push  rbx
  push  r8
  push  rdx
  xor   rax, rax
  xor   rcx, rcx

  mov   rsi, FIRST_ARG                  ;; source buffer of raw bytes
  mov   rdi, SECOND_ARG                 ;; destination buffer for base64 bytes
  mov   rax, THIRD_ARG                  ;; length of raw byte buffer

  ;; get third_arg mod 3
  xor   rdx, rdx
  mov   rbx, 3
  div   rbx                             ;; ok, now length % 3 is in rdx
  
  mov   [rbp-8], rdx


.break:
  mov   rbx, THIRD_ARG

.loop:
  test  rbx, rbx
  jle   .done
  
  ;; load the first three bytes of the cleartext, in big-endian
  xor   rax, rax
  mov   BYTE ah, [rsi]
  shl   rax, 8
  mov   BYTE ah, [rsi + 1]
  mov   BYTE al, [rsi + 2]
  add   rsi, 3
  sub   rbx, 3

  xor   cl, cl
.loop2:                             ;; now break it up into 4 6bit numbers
  mov   r8, rax
  shr   r8, cl
  and   r8, 0b111111
  push  r8
  
  cmp   cl, 18
  jge   .done2
  add   cl, 6
  jmp   .loop2
.done2:                             ;; 4 6bit nums are now on the stack
.loop3:                             ;; now we translate them into characters
  pop   r8                          ;; get the next base64 index
  mov   al, BYTE b64char(r8)        ;; lookup the encoded character
  mov   [rdi], al                   ;; write the encoded char to the b64 buffer
  inc   rdi                         ;; increment the ptr to the encoded buffer

  test  cl, cl                      ;; check to see if we've handled all four cipher for these three clear
  jle    .done3
  sub   cl, 6                       ;; what we're doing here is counting down
  jmp   .loop3 

.done3:
  jmp   .loop

.done:
  ;; now take care of the '=' padding
  mov   rax, [rbp - 8]
  test  rax, rax
  jz    .donepad
  mov   rdx, 4
  sub   rdx, rax
  dec   rdx
  sub   rdi, rdx
.padloop:
  test  rdx, rdx
  jz    .donepad
  mov   [rdi], BYTE '='
  inc   rdi
  dec   rdx
  jmp   .padloop
.donepad:
  
  ;inc   rdi
  mov   [rdi], BYTE 0x0A
  pop   rdx
  pop   r8
  pop   rbx
  pop   rcx
  pop   rdi
  pop   rsi
  mov   rsp, rbp
  pop   rbp
  ret

  
   
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Converts a hex-encoded string to a buffer of bytes half as long  ;;
;; decode_hexstring(src, dst, count);                               ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
decode_hexstring:
  push  rbp
  mov   rbp, rsp
  push  rsi
  push  rdi
  push  rcx
  push  r8
  push  r9

  mov   rsi, FIRST_ARG    ;; SRC
  mov   rdi, SECOND_ARG   ;; DST
  mov   rcx, THIRD_ARG    ;; byte count

  xor   r8, r8
  xor   r9, r9

.loop:
  
  push  rsi
  call  hexnibble
;  mov   BYTE [rdi], al
;; now, instead of just copying the byte in, we need to OR in
  mov   r9, 1
  test  r8, r8
  jne   .noshift
  shl   al, 4
  xor   r9, r9
.noshift:
  or    BYTE [rdi], al

  inc   rsi
  add   rdi, r9     ;; increment r9 ONLY when not shifting
  dec   rcx
  test  rcx, rcx
  not   r8          ;; r8 is a toggle. when high, shift. when low, don't.
  jne   .loop
  
.done:
  
  pop   r9
  pop   r8
  pop   rcx
  pop   rdi
  pop   rsi
  mov   rsp, rbp
  pop   rbp
  ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; memset to zero, basically ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
zerocool:

  push  rbp
  mov   rbp, rsp

  mov   rax, FIRST_ARG
  mov   rbx, SECOND_ARG

.loop:
  
  mov   BYTE [rax], 0
  inc   rax
  dec   rbx
  test  rbx, rbx
  jg    .loop

  mov   rsp, rbp
  pop   rbp
  ret

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
  
  call  decode_hexstring

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

initial_break:
  dq 0x0000000000000000
current_break:
  dq 0x0000000000000000

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


