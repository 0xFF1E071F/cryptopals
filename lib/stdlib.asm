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

global min, memset
global print_to, read_to, read0, print0, terpri, pos
global println, readln, decode_hexstr, allocate, exit_fail, exit_success
global zerocool, initial_break, current_break, base64
global is_ascii, allbytes, memcpy, xorbufs
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

;-=-=-=-=-=-=-;
 section .text
;-=-=-=-=-=-=-;
min:
  push  rbp
  mov   rbp, rsp
  push  rbx
  mov   rbx, FIRST_ARG
  mov   rax, SECOND_ARG
  cmp   rax, rbx
  jle   .done
  xchg  rax, rbx
.done:
  pop   rbx
  mov   rsp, rbp
  pop   rbp
  ret

swpmin: ;; takes values in rax and rbx. sets smaller in rax, larger in rbx
  cmp   rax, rbx
  jle   .done
  xchg  rax, rbx
.done:
  ret

;;;;;;;;;;
;; first arg:  buffer
;; second arg: byte
;;;;;;;;;;;;;;;;;;;;;;
pos:
  push  rbp
  mov   rbp, rsp
  push  rcx
  push  rsi
  xor   rax, rax
  mov   rsi, FIRST_ARG
  mov   rcx, SECOND_ARG

.loop:
  cmp   cl, BYTE [rsi]
  je    .done
  inc   rax
  inc   rsi
  jmp   .loop
.done:
  pop   rsi
  pop   rcx
  mov   rsp, rbp
  pop   rbp
  ret

;;;;;;;
;; Prints a newline to fd in FIRST_ARG
;;;;;;;
terpri:
  push  rbp
  mov   rbp, rsp
  push  rdi
  push  rsi
  mov   rdi, FIRST_ARG
  push  NEWLINE
  mov   rsi, rsp
  mov   rax, SYS_WRITE
  mov   rdx, 1
  syscall
  pop   rsi
  pop   rsi
  pop   rdi
  mov   rsp, rbp
  pop   rbp
  ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; prints the buffer pointed to by rax, to the file descriptor in rbx ;;
;; parameters: buffer, stream, delimiter                              ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
print_to:
  push  rbp
  mov   rbp, rsp
  push  rcx
  push  rdi
  push  rsi
  push  r8
  xor   rcx, rcx
  
  mov   rax, FIRST_ARG   ;; the buffer
  mov   rbx, SECOND_ARG  ;; the stream
  mov   r8,  THIRD_ARG   ;; the delimiter

  mov   rsi, rax
  mov   rdi, rbx  ;; copy the file descriptor to rdi
  mov   rdx, 1    ;; one character at a time

.loop:
  mov   cl, BYTE [rsi]
  mov   rax, r8
  cmp   cl, al
  mov   rax, SYS_WRITE
  je    .done
  syscall

  inc   rsi
  jmp   .loop
    
.done:
;; last character: the newline
;;  mov   rax, SYS_WRITE
;;  mov   rcx, rsi
;;  syscall

  pop   r8
  pop   rsi
  pop   rdi
  pop   rcx
  mov   rsp, rbp
  pop   rbp
  ret

println:
  push  rbp
  mov   rbp, rsp
  push  NEWLINE
  push  QWORD SECOND_ARG
  push  QWORD FIRST_ARG
  call  print_to
  push  QWORD SECOND_ARG
  ;; might already be on the stack. check debugger.
  call  terpri
  mov   rsp, rbp
  pop   rbp
  ret

print0:
  push  rbp
  mov   rbp, rsp
  push  0x00
  push  QWORD SECOND_ARG
  push  QWORD FIRST_ARG
  call  print_to
  mov   rsp, rbp
  pop   rbp
  ret


;; Dispose of this on the next cleanup
println_alt:
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

read_to:
  push  rbp
  mov   rbp, rsp
  push  rdi
  push  rsi
  push  rcx   ;; counter
  push  rdx
  push  r8


  xor   rcx, rcx
  push  rcx
  
  mov   rax, FIRST_ARG
  mov   rbx, SECOND_ARG
  mov   r8,  THIRD_ARG

  mov   rsi, rax
  ;; rsi now points to the buffer to write to

  mov   rdi, rbx

.loop:  
  mov   rdx, 1    ;; one char at a time
  mov   rax, SYS_READ
  syscall
  add   [rsp], rdx

  cmp   rax, EOF
  je    .done

  mov   al, BYTE [rsi]
  mov   rdx, r8
  cmp   al, dl
  je    .done

  inc   rsi
  jmp   .loop

.done:

  pop   rax     ;; number of bytes written
  pop   r8
  pop   rdx
  pop   rcx
  pop   rsi
  pop   rdi
  mov   rsp, rbp
  pop   rbp
  ret

  mov   rcx, rsi

readln:
  push  rbp
  mov   rbp, rsp
  push  NEWLINE
  push  QWORD SECOND_ARG
  push  QWORD FIRST_ARG
  call  read_to
  mov   rsp, rbp
  pop   rbp
  ret

read0:
  push  rbp
  mov   rsp, rbp
  push  0x00
  push  QWORD SECOND_ARG
  push  QWORD FIRST_ARG
  call  read_to
  mov   rsp, rbp
  pop   rbp
  ret


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
  mov   [rdi], BYTE NEWLINE
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
;; decode_hexstr(src, dst, count);                               ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
decode_hexstr:
  push  rbp
  mov   rbp, rsp
  push  rsi
  push  rdi
  push  rcx
  push  r8
  push  r9

  mov   rsi, FIRST_ARG    ;; SRC
  mov   rdi, SECOND_ARG   ;; DST
  mov   rcx, THIRD_ARG    ;; byte count (of hex encoding)

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


;;;;;
;; memset (ptr, len, byte);
;;;;
memset:
  
  push  rbp
  mov   rbp, rsp
  push  rbx
  push  rcx 

  mov   rax, FIRST_ARG   ;; pointer to memory
  mov   rbx, SECOND_ARG  ;; length
  mov   cl,  BYTE THIRD_ARG   ;; byte

.loop:
  
  mov   BYTE [rax], cl
  inc   rax
  dec   rbx
  test  rbx, rbx
  jg    .loop

  pop   rcx
  pop   rbx
  mov   rsp, rbp
  pop   rbp
  ret

memcpy:
  push  rbp
  mov   rbp, rsp
  push  rbx
  push  rcx
  push  rdx
  
  xor   rdx, rdx
  mov   rax, FIRST_ARG  ;; destination
  mov   rbx, SECOND_ARG ;; source
  mov   rcx, THIRD_ARG  ;; length

.loop:
  mov   dl, BYTE [rbx]
  mov   BYTE [rax], dl
  dec   rcx
  test  rcx, rcx
  jg    .loop

  pop   rcx
  pop   rbx
  mov   rsp, rbp
  pop   rbp
  ret

;;;;;;
;; xorbufs (&buf1, &mut buf2, len) 
;;;;;
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

is_ascii:
  push  rbp
  mov   rbp, rsp
  push  rbx
  xor   rbx, rbx
  mov   al, BYTE FIRST_ARG
  sub   al, 0x20
  test  al, al
  jl    .no
  add   al, 0x20
  shr   al, 7
  test  al, al
  jg    .no
  inc   rbx
.no:
  mov   rax, rbx
  pop   rbx
  mov   rsp, rbp
  pop   rbp
  ret

;;
;; allbytes(buffer, length, predicate) -> 1 or 0
allbytes:
  push  rbp
  mov   rbp, rsp
  push  rbx
  push  rcx
  push  rdx
  mov   rbx, FIRST_ARG      ;; buffer
  mov   rcx, SECOND_ARG     ;; length
  mov   rdx, THIRD_ARG      ;; predicate
.loop:
  xor   rax, rax
  mov   al, BYTE [rbx]
  push  rax
  call  rdx ;; predicate
  sub   rsp, 8
  test  rax, rax
  jz    .false
  inc   rbx
  dec   rcx
  test  rcx, rcx
  jg    .loop
  ;; rax should have return value already in it
.false:
  pop   rdx
  pop   rcx
  pop   rbx
  mov   rsp, rbp
  pop   rbp
  ret

