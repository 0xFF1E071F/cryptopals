; ----------------------------------------------
; Solves the first of the cryptopal challenges:
; convert a hex string to base64
; ----------------------------------------------

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

  global _start

  section .text

println:
  push  rbp
  mov   rbp, rsp
  push  rcx
  push  rdi
  push  rsi
  xor   rcx, rcx
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
  ;; trap
  int   3

.done_nibble:
 
  and   rax, 0xFF
  pop   rcx
  mov   rsp, rbp
  pop   rbp
  ;; value of nibble should be in rax
  ret


exit_success:
  mov   rax, success_msg
  mov   rbx, STDERR
  call  println

  mov   rax, SYS_EXIT
  mov   rdi, SUCCESS
  syscall

exit_fail:
  mov   rax, fail_msg
  mov   rbx, STDERR
  call  println

  mov   rax, SYS_EXIT
  mov   rdi, FAILURE
  syscall          ;; exit with exit code 1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Basic memory allocation function. Expects size on stack. ;;
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
  
  push  0x2000
  call  allocate
  mov   [raw_start], rax
  
  push  0x1000
  call  allocate
  mov   [b64_start], rax

.breakpoint_0:
                                      ;; let's read the hex string into hex_start
  mov   rax, [hex_start]
  mov   rbx, STDIN
  call  readln
  mov   bytes_read, rax                ;; store number of bytes read on stack 
                                      ;; printing hex back out, to test
  mov   rax, [hex_start]
  mov   rbx, STDOUT
  call  println

  mov   rax, bytes_read
  dec   rax                           ;; we don't want to count the '\n' at the end
  push  QWORD rax
  push  QWORD [raw_start]
  push  QWORD [hex_start]
  
  call  decode_hexstring

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

stack_start:
  dq 0x0000000000000000

test_msg:
  db "Hello, world!", 0x0A, 0x00

