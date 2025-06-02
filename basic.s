.arch armv7-a
.arm
.section .data
    DEV_MEM:
        .asciz "/dev/mem"

    .global file_descriptor
    file_descriptor:
      .word 0

    .global axi_address
    axi_address:
      .word 0

    .global data_in_ptr
    data_in_ptr:
      .word 0

    .global data_out_ptr
    data_out_ptr:
      .word 0

.section .text

.extern data_out
.extern flags

.equ NO_OP,      0
.equ STORE_OP,   2
.equ LOAD_OP,    1
.equ ADD_OP,     3
.equ SUB_OP,     4
.equ MUL_OP,     6
.equ SCL_OP,     5
.equ RST_OP,     7

.equ SYS_OPEN,   5
.equ SYS_MMAP,   192
.equ SYS_CLOSE,  6
.equ SYS_MUNMAP, 91
.equ AXI_SPAN,   0x5000
.equ AXI_BASE,   0xff200

 @ -----------------------------------------------------------------------------
 @ init_mpu: Mapeia a memória para acessar AXI bridge
 @ Entrada:  Nenhum
 @ Saída:    Nenhuma
 @ Afeta:    R0, R1, R2, R3, R4, R5, R6, R7, file_descriptor, axi_addr, data_in_ptr, data_out_ptr
 @ -----------------------------------------------------------------------------
.global init_mpu
.type init_mpu, %function
init_mpu:
    push {r4 - r11, lr}

    ldr r0, =DEV_MEM     @ Carrega o ENDEREÇO da string "/dev/mem" em r0
    mov r1, #2           @ Define r1 para 2 (O_RDWR para a syscall open)
    ldr r7, =SYS_OPEN    @ Carrega o número da syscall para open (5) em r7
    svc #0               @ Invoca a syscall

    ldr r4, =file_descriptor @ Carrega o endereço da variável global file_descriptor em r4
    str r0, [r4]         @ Armazena o descritor de arquivo (retornado em r0 por open) em file_descriptor

    mov r0, #0           @ Define r0 para 0 (addr para mmap, geralmente NULL para o kernel escolher)
    ldr r1, =AXI_SPAN    @ Carrega o tamanho do span AXI (0x5000) em r1 (length para mmap)
    mov r2, #3           @ Define r2 para 3 (PROT_READ | PROT_WRITE para mmap)
    mov r3, #1           @ Define r3 para 1 (MAP_SHARED para mmap)
    ldr r4, [r4]
    ldr r5, =AXI_BASE    @ Carrega o endereço base AXI (0xFF200) em r5 (offset para mmap)
    ldr r7, =SYS_MMAP    @ Carrega o número da syscall para mmap (192) em r7
    svc #0               @ Invoca a syscall

    add r1, r0, #0    @ data_in_ptr = (int*)(axi_address + 0)
    add r2, r0, #0x10 @ data_out_ptr = (int*)(axi_address + 0x10)
    ldr r3, =data_in_ptr
    str r1, [r3]
    ldr r3, =data_out_ptr
    str r2, [r3]

    ldr r6, =axi_address @ Carrega o endereço da variável global axi_addr em r6
    str r0, [r6]         @ Armazena o endereço mapeado (retornado em r0 por mmap) em axi_address

    pop {r4 - r11, lr}
    bx  lr

 @ -----------------------------------------------------------------------------
 @ finish_mpu: Desfaz o mapeamento da memória AXI e fecha o descritor de arquivo.
 @ Entrada:  Nenhum
 @ Saída:    Nenhum
 @ Afeta:    R0, R1, R7
 @ -----------------------------------------------------------------------------
.global finish_mpu
.type finish_mpu, %function
finish_mpu:
    push {r4 -r11, lr}
    ldr r0, =axi_address     @ Carrega o ENDEREÇO de axi_addr
    ldr r0, [r0]             @ Carrega o VALOR de axi_addr (o ponteiro mapeado) em r0 (addr para munmap)
    ldr r1, =AXI_SPAN        @ Carrega a constante AXI_SPAN em r1 (length para munmap)
    ldr r7, =SYS_MUNMAP      @ Carrega o número da syscall para munmap (91) em r7
    svc #0                   @ Invoca a syscall

    ldr r0, =file_descriptor @ Carrega o ENDEREÇO de file_descriptor
    ldr r0, [r0]             @ Carrega o VALOR de file_descriptor em r0 (fd para close)
    ldr r7, =SYS_CLOSE       @ Carrega o número da syscall para close (6) em r7
    svc #0                   @ Invoca a syscall

    pop {r4 - r11, lr}
    bx  lr

 @ -----------------------------------------------------------------------------
 @ format_instruction: Formata os componentes de uma instrução em um único valor de 32 bits.
 @ Entrada:  R0 = Ponteiro para uma struct Instruction que contém os componentes da instrução (op_code, id, row, col, value)
 @ Saída:    R0 = Instrução formatada de 32 bits
 @ Afeta:    R0, R1, R2, R3, R4, R5, R6
 @ -----------------------------------------------------------------------------
.global format_instruction
.type format_instruction, %function
format_instruction:
    push {r4 - r11, lr}

    ldrb r1, [r0, #0]  @ op_code (bits 0-2)
    ldrb r2, [r0, #4]  @ id (bit 3)
    ldrb r4, [r0, #8]  @ row (bits 4-6)
    ldrb r3, [r0, #12] @ col (bits 7-9)
    ldrb r5, [r0, #16] @ value (bits 10-17)

    mov r0, #0       @ uint32_t instr;
    orr r0, r0, r1   @ instr |= op_code;

    lsl r2, r2, #3
    cmp r1, #STORE_OP
    orreq r0, r0, r2 @ instr |= op_code == STORE ? id << 3 : 0;

    lsl r3, r3, #3   @ r4 = row << 3
    lsl r4, r4, #6   @ r3 = col << 6
    cmp r1, #LOAD_OP
    orreq r0, r0, r3
    orreq r0, r0, r4
    lsl r3, r3, #1   @ r4 = row << 4
    lsl r4, r4, #1   @ r3 = col << 7
    cmp r1, #STORE_OP
    orreq r0, r0, r3
    orreq r0, r0, r4

    lsl r5, r5, #3
    cmp r1, #SCL_OP
    orreq r0, r0, r5
    lsl r5, r5, #7
    cmp r1, #STORE_OP
    orreq r0, r0, r5

    mov r6, #1
    lsl r6, r6, #18
    orreq r0, r0, r6 @ se for instrução de store, envia sinal de escrita

    pop {r4 - r11, lr}
    bx  lr

 @ -----------------------------------------------------------------------------
 @ send_instruction: Envia uma instrução para a MPU e, caso não seja uma instrução que retorne flag, não espera por uma resposta.
 @ Entrada:  R0 = wait_flags (0 para não esperar, 1 para esperar)
 @           R1 = instruction (instrução formatada de 32 bits)
 @ Saída:    Nenhum
 @ Afeta:    R0, R1, R2, R3, R4, R5, R6, R7, R8, data_in_ptr, data_out_ptr, data_out, flags
 @ -----------------------------------------------------------------------------
.global send_instruction
.type send_instruction, %function
send_instruction:
    push {r4 - r11, lr}

    ldr r2, =data_in_ptr
    ldr r2, [r2]
    str r1, [r2]           @ *data_in_ptr = instruction

    cmp r0, #0
    ldr r3, =data_out      @ r3 = &data_out
    ldr r4, =data_out_ptr  @ r4 = &data_out_ptr
    ldr r4, [r4]           @ r4 = data_out_ptr
    ldr r5, =flags         @ r5 = &flags
    beq break_waiting      @ if (wait_flags) while(!flags)

while_waiting:
    ldr r6, [r4]  @ r6 = *data_out_ptr
    str r6, [r3]  @ data_out = *data_out_ptr

    ldr r7, [r3]
    lsr r8, r7, #8
    str r8, [r5]  @flags = data_out >> 8

    cmp r8, #0
    bne while_waiting

break_waiting:
    mov r3, #0
    str r3, [r2]

    pop {r4 - r11, lr}
    bx lr

 @ -----------------------------------------------------------------------------
 @ mpu_add: Envia uma instrução de adição para a MPU.
 @ Entrada:  Nenhum
 @ Saída:    Nenhum
 @ Afeta:    R0, R1, data_in_ptr, data_out_ptr, data_out, flags
 @ -----------------------------------------------------------------------------
.global mpu_add
.type mpu_add, %function
mpu_add:
  push {r4 - r11, lr}

  @ cria uma struct Instruction e inicializa seus elementos de acordo com os parametros da instrução
  sub sp, sp, #20
  mov r0, #ADD_OP
  str r0, [sp, #0]

  mov r0, #0
  str r0, [sp, #4]
  str r0, [sp, #8]
  str r0, [sp, #12]
  str r0, [sp, #16]

  mov r0, sp

  bl format_instruction

  @ libera o espaço da struct e organiza as entradas wait_flags(nesse caso é 1) e a instrução retornada pela função anterior
  add sp, sp, #20
  mov r1, r0
  mov r0, #1

  bl send_instruction

  pop {r4 - r11, lr}
  bx lr

 @ -----------------------------------------------------------------------------
 @ mpu_sub: Envia uma instrução de subtração para a MPU.
 @ Entrada:  Nenhum
 @ Saída:    Nenhum
 @ Afeta:    R0, R1, data_in_ptr, data_out_ptr, data_out, flags
 @ -----------------------------------------------------------------------------
.global mpu_sub
.type mpu_sub, %function
mpu_sub:
  push {r4 - r11, lr}

  @ cria uma struct Instruction e inicializa seus elementos de acordo com os parametros da instrução
  sub sp, sp, #20
  mov r0, #SUB_OP
  str r0, [sp, #0]

  mov r0, #0
  str r0, [sp, #4]
  str r0, [sp, #8]
  str r0, [sp, #12]
  str r0, [sp, #16]

  mov r0, sp

  bl format_instruction

  @ libera o espaço da struct e organiza as entradas wait_flags(nesse caso é 1) e a instrução retornada pela função anterior
  add sp, sp, #20
  mov r1, r0
  mov r0, #1

  bl send_instruction

  pop {r4 - r11, lr}
  bx lr

 @ -----------------------------------------------------------------------------
 @ mpu_mul: Envia uma instrução de multiplicação para a MPU.
 @ Entrada:  Nenhum
 @ Saída:    Nenhum
 @ Afeta:    R0, R1, data_in_ptr, data_out_ptr, data_out, flags
 @ -----------------------------------------------------------------------------
.global mpu_mul
.type mpu_mul, %function
mpu_mul:
  push {r4 - r11, lr}

  @ cria uma struct Instruction e inicializa seus elementos de acordo com os parametros da instrução
  sub sp, sp, #20
  mov r0, #MUL_OP
  str r0, [sp, #0]

  mov r0, #0
  str r0, [sp, #4]
  str r0, [sp, #8]
  str r0, [sp, #12]
  str r0, [sp, #16]

  mov r0, sp

  bl format_instruction

  @ libera o espaço da struct e organiza as entradas wait_flags(nesse caso é 1) e a instrução retornada pela função anterior
  add sp, sp, #20
  mov r1, r0
  mov r0, #1

  bl send_instruction

  pop {r4 - r11, lr}
  bx lr

 @ -----------------------------------------------------------------------------
 @ mpu_scl: Envia uma instrução de multiplicação por escalar para a MPU.
 @ Entrada:  R0 = scalar (valor escalar a ser usado)
 @ Saída:    Nenhum
 @ Afeta:    R0, R1, data_in_ptr, data_out_ptr, data_out, flags
 @ -----------------------------------------------------------------------------
.global mpu_scl
.type mpu_scl, %function
mpu_scl:
  push {r4 - r11, lr}

  @ cria uma struct Instruction e inicializa seus elementos de acordo com os parametros da instrução
  sub sp, sp, #20

  mov r1, #SCL_OP
  str r1, [sp, #0]
  mov r1, #0
  str r1, [sp, #4]
  str r1, [sp, #8]
  str r1, [sp, #12]
  str r0, [sp, #16] @ i->value = scalar

  mov r0, sp

  bl format_instruction

  @ libera o espaço da struct e organiza as entradas wait_flags(nesse caso é 1) e a instrução retornada pela função anterior
  add sp, sp, #20
  mov r1, r0
  mov r0, #1

  bl send_instruction

  pop {r4 - r11, lr}
  bx lr

 @ -----------------------------------------------------------------------------
 @ mpu_store: Envia uma instrução de armazenamento para a MPU.
 @ Entrada:  R0 = id    (ID da matriz)
 @           R1 = row   (linha da matriz)
 @           R2 = col   (coluna da matriz)
 @           R3 = value (valor a ser armazenado)
 @ Saída:    Nenhum
 @ Afeta:    R0, R1, R2, R3, R4, data_in_ptr, data_out_ptr, data_out, flags
 @ -----------------------------------------------------------------------------
.global mpu_store
.type mpu_store, %function
mpu_store:
  push {r4 - r11, lr}

  @ cria uma struct Instruction e inicializa seus elementos de acordo com os parametros da instrução
  sub sp, sp, #20

  mov r4, #STORE_OP
  str r4, [sp, #0]
  str r0, [sp, #4]
  str r1, [sp, #8]
  str r2, [sp, #12]
  str r3, [sp, #16]

  mov r0, sp

  bl format_instruction

  @ libera o espaço da struct e organiza as entradas wait_flags(nesse caso é 1) e a instrução retornada pela função anterior
  add sp, sp, #20
  mov r1, r0
  mov r0, #1

  bl send_instruction

  pop {r4 - r11, lr}
  bx lr

 @ -----------------------------------------------------------------------------
 @ mpu_load: Envia uma instrução de carga para a MPU.
 @ Entrada:  R0 = row (linha da matriz)
 @           R1 = col (coluna da matriz)
 @ Saída:    Nenhum
 @ Afeta:    R0, R1, R4, data_in_ptr, data_out_ptr, data_out, flags
 @ -----------------------------------------------------------------------------
.global mpu_load
.type mpu_load, %function
mpu_load:
  push {r4 - r11, lr}

  @ cria uma struct Instruction e inicializa seus elementos de acordo com os parametros da instrução
  sub sp, sp, #20

  mov r4, #LOAD_OP
  str r4, [sp, #0]
  mov r4, #0
  str r4, [sp, #4]
  str r0, [sp, #8]
  str r1, [sp, #12]
  str r4, [sp, #16]

  mov r0, sp

  bl format_instruction

  @ libera o espaço da struct e organiza as entradas wait_flags(nesse caso é 1) e a instrução retornada pela função anterior
  add sp, sp, #20
  mov r1, r0
  mov r0, #1

  bl send_instruction

  pop {r4 - r11, lr}
  bx lr

 @ -----------------------------------------------------------------------------
 @ mpu_reset: Envia uma instrução de reset para a MPU.
 @ Entrada:  Nenhum
 @ Saída:    Nenhum
 @ Afeta:    R0, R4, data_in_ptr, data_out_ptr, data_out, flags
 @ -----------------------------------------------------------------------------
.global mpu_reset
.type mpu_reset, %function
mpu_reset:
  push {r4 - r11, lr}

  @ cria uma struct Instruction e inicializa seus elementos de acordo com os parametros da instrução
  sub sp, sp, #20

  mov r4, #RST_OP
  str r4, [sp, #0]
  mov r4, #0
  str r4, [sp, #4]
  str r4, [sp, #8]
  str r4, [sp, #12]
  str r4, [sp, #16]

  mov r0, sp

  bl format_instruction

  @ libera o espaço da struct e organiza as entradas wait_flags(único caso em que é 0) e a instrução retornada pela função anterior
  add sp, sp, #20
  mov r1, r0
  mov r0, #0

  bl send_instruction

  pop {r4 - r11, lr}
  bx lr
