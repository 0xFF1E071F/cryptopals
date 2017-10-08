; ----------------------------------------------
; Solves the first of the cryptopal challenges:
; convert a hex string to base64
; ----------------------------------------------


  global _start

  section .text
  
hexnibble:
  push  rbp
  mov   rbp, rsp
  push  rcx
  push  rax
  ;; stack now: rbp, ret addr, ptr param
  mov   rcx, [rbp + 4] ;; pointer to first of two characters
  mov   rax, [rcx] ;; dereference pointer
  
  cmp   rax, '0'
  jl    .bad
  cmp   rax, '9'
  jg    .uppercase

.numerical:
  sub   rax, '0'
  jmp   .done_nibble

.uppercase:
  cmp   rax, 'F'
  jg    .lowercase
  sub   rax, 'A'
  add   rax, 0x0a
  jmp   .done_nibble

.lowercase:
  cmp   rax, 'a'
  jl    .bad
  cmp   rax, 'f'
  jg    .bad
  sub   rax, 'a'
  add   rax, 0x0a
  jmp   .done_nibble

.bad:
  ;; trap
  int   3

.done_nibble:
  ret
  

  mov rsp, rbp
  pop rbp
  ret

_start:
  


