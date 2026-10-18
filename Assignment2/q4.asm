[ORG 0x100]
JMP start

obs:        dw 0x6552, 0x2C91, 0x7FA3
numObs:     db 3

weights:
    db 2, -3, -1, 10      ; NORMAL: W1, W2, W3, Bias
    db 1, 4, 2, 0         ; SUSPICIOUS: W1, W2, W3, Bias
    db -2, 5, 4, -5       ; ATTACK: W1, W2, W3, Bias

normScore:   dw 0, 0, 0
susScore:    dw 0, 0, 0
atkScore:    dw 0, 0, 0
predFlag:    db 0, 0, 0

x1:         dw 0
x2:         dw 0
x3:         dw 0

class:      db 0 ; 0=NORMAL, 1=SUSPICIOUS, 2=ATTACK
classCount: db 3
obsCount:   db 0
signFlag:   db 0
mulValue:   dw 0

start:
    mov si, 0
    mov byte [obsCount], 0

obs_loop:
    mov ax, [obs+si]

    mov bx, ax
    and bx, 0000000000011111b
    sub bx, 16 ; X3

    mov cx, ax
    and cx, 0000001111100000b
    shr cx, 5
    sub cx, 8  ; X2

    mov dx, ax
    and dx, 1111110000000000b
    shr dx, 10
    sub dx, 20 ; X1

    mov [x1], dx
    mov [x2], cx
    mov [x3], bx

    mov di, weights
    mov byte [class], 0 ; normal
    mov byte [classCount], 3

weights_loop:
    mov bp, 0                     ; BP = current score

    ; X1 x W1
    mov ax, [x1] ; ax = X1 (signed 16-bit)
    mov bl, [di] ; bl = W1 (signed 8-bit)

    mov bh, 0
    test bl, 10000000b
    jz w1_extended
    mov bh, 0FFh
w1_extended:
    ; BX now sign-extended weight

    mov byte [signFlag], 0

    cmp ax, 0
    jge x_pos_1
    neg ax
    mov byte [signFlag], 1
x_pos_1:
    cmp bx, 0
    jge w_pos_1
    neg bx
    xor byte [signFlag], 1 ; toggle
w_pos_1:
    mul bx
    cmp byte [signFlag], 0
    je mul_done_1
    neg ax ; if signs differ, negate result
mul_done_1:
    add bp, ax ; accumulate

    ; X2 x W2
    mov ax, [x2]
    mov bl, [di+1]

    mov bh, 0
    test bl, 10000000b
    jz w2_extended
    mov bh, 0FFh
w2_extended:
    ; BX now sign-extended weight

    mov byte [signFlag], 0

    cmp ax, 0
    jge x_pos_2
    neg ax
    mov byte [signFlag], 1
x_pos_2:
    cmp bx, 0
    jge w_pos_2
    neg bx
    xor byte [signFlag], 1 ; toggle
w_pos_2:
    mul bx
    cmp byte [signFlag], 0
    je mul_done_2
    neg ax ; if signs differ, negate result
mul_done_2:
    add bp, ax ; accumulate

    ; X3 x W3
    mov ax, [x3]
    mov bl, [di+2]

    mov bh, 0
    test bl, 10000000b
    jz w3_extended
    mov bh, 0FFh
w3_extended:
    ; BX now sign-extended weight

    mov byte [signFlag], 0

    cmp ax, 0
    jge x_pos_3
    neg ax
    mov byte [signFlag], 1
x_pos_3:
    cmp bx, 0
    jge w_pos_3
    neg bx
    xor byte [signFlag], 1 ; toggle
w_pos_3:
    mul bx
    cmp byte [signFlag], 0
    je mul_done_3
    neg ax ; if signs differ, negate result
mul_done_3:
    add bp, ax ; accumulate

    ; Bias
    mov al, [di+3] ; loaded 8bit bias
    mov ah, 0
    test al, 10000000b
    jz bias_extended
    mov ah, 0FFh
bias_extended:
    add bp, ax ; accumulate

    ; Store score according to class
    cmp byte [class], 0
    je store_normal

    cmp byte [class], 1
    je store_suspicious

    mov [atkScore+si], bp
    jmp store_done

store_normal:
    mov [normScore+si], bp
    jmp store_done

store_suspicious:
    mov [susScore+si], bp

store_done:
    add di, 4 ; 4bytes per class , move to next class's weights
    inc byte [class] ; move to next class's index

    dec byte [classCount]
    jnz weights_loop

    ; Compare scores and find the highest
    mov ax, [normScore+si]
    cmp ax, [susScore+si]
    jge normal_highest

    mov ax, [susScore+si]
    cmp ax, [atkScore+si]
    jge suspicious_highest

    jmp attack_highest

normal_highest:
    cmp ax, [atkScore+si]
    jge normal_prediction
    jmp attack_highest

suspicious_highest:
    mov bx, si ;byte offset (0,2,4)
    shr bx, 1 ;/2 (0,1,2)
    mov byte [predFlag+bx], 2     ; SUSP
    jmp prediction_done

attack_highest:
    mov bx, si ;byte offset (0,2,4)
    shr bx, 1 ;/2 (0,1,2)
    mov byte [predFlag+bx], 3     ; ATK
    jmp prediction_done

normal_prediction:
    mov bx, si ;byte offset (0,2,4)
    shr bx, 1 ;/2 (0,1,2)
    mov byte [predFlag+bx], 1   ; NORM

prediction_done:
    inc byte [obsCount]

    mov al, [numObs]
    cmp byte [obsCount], al
    je program_done

    add si, 2
    jmp obs_loop

program_done:
    mov ax, 0x4C00
    int 0x21