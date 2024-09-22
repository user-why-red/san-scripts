.global _start

.section .data
count: .quad 1000000000
result: .skip 8
multiplier1: .quad 12345
multiplier2: .quad 67890
array_size: .quad 1000000

.section .bss
array1: .skip 4000000
array2: .skip 4000000

.section .text
_start:
    ldr x0, =count
    ldr x0, [x0]
    mov x1, 0
    ldr x2, =multiplier1
    ldr x2, [x2]
    ldr x3, =multiplier2
    ldr x3, [x3]

    ldr x4, =array_size
    ldr x4, [x4]
    ldr x5, =array1
    ldr x6, =array2
    mov x7, 1
initialize_arrays:
    str w7, [x5]
    str w7, [x6]
    add x5, x5, 4
    add x6, x6, 4
    subs x4, x4, 1
    bne initialize_arrays

benchmark_loop:
    mul x8, x2, x3
    add x1, x1, x8

    ldr x9, =array1
    ldr x10, =array2
    ldr w11, [x9]
    ldr w12, [x10]
    add w11, w11, w12
    str w11, [x9]

    add x11, x11, x12
    mul x12, x11, x12
    add x1, x1, x12

    subs x0, x0, 1
    bne benchmark_loop

    ldr x5, =result
    str x1, [x5]

    mov x8, 93
    mov x0, 0
    svc 0
