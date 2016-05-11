;===============================================================================
; ZONA I: Definicao de constantes
;         Pseudo-instrucao : EQU
;===============================================================================

; TEMPORIZACAO
DELAYVALUE      EQU     5000h

; STACK POINTER
SP_INICIAL      EQU     FDFFh

; I/O a partir de FF00H
IO_CURSOR       EQU     FFFCh
IO_WRITE        EQU     FFFEh
IO_PRESSED      EQU     FFFDh
IO_READ         EQU     FFFFh

; INTERRUPCOES
INT_MASK        EQU     FFFAh
TAB_INT0        EQU     FE00h
TAB_TEMP        EQU     FE0Fh

TEMP_UNIT       EQU     FFF6h
TEMP_CONTROL    EQU     FFF7h
TEMP_DELAY      EQU     0001h

LIMPAR_JANELA   EQU     FFFFh
FIM_TEXTO       EQU     '@'

POS_STR         EQU     0614h
POS_veiculo_ini EQU     1627h 

POS_alien_ini   EQU     0101h

;===============================================================================
; ZONA II: Definicao de variaveis
;          Pseudo-instrucoes : WORD - palavra (16 bits)
;                              STR  - sequencia de caracteres.
;          Cada caracter ocupa 1 palavra
;===============================================================================

                ORIG    8000h
str_start       STR     'Prima I0 para iniciar o jogo', FIM_TEXTO
INT0_global     WORD    0000h
parede_h        STR     '|------------------------------------------------------------------------------|', FIM_TEXTO

veiculo         STR     'O-^-O', FIM_TEXTO
POS_veiculo     WORD    POS_veiculo_ini

alien           STR     'OVO', FIM_TEXTO
alien_vec       TAB     28       ; vector de 28 posições

;===============================================================================
; ZONA III: Codigo
;           conjunto de instrucoes Assembly, ordenadas de forma a realizar
;           as funcoes pretendidas
;===============================================================================
                ORIG    0000h
                JMP     inicio


;===============================================================================
; LimpaJanela: Rotina que limpa a janela de texto.
;               Entradas: --
;               Saidas: ---
;               Efeitos: ---
;===============================================================================

LimpaJanela:    PUSH    R2
                MOV     R2, LIMPAR_JANELA
                MOV     M[IO_CURSOR], R2
                POP     R2
                RET

;===============================================================================
; EscString: Rotina que efectua a escrita de uma cadeia de caracter, terminada
;            pelo caracter FIM_TEXTO, na janela de texto numa posicao 
;            especificada. Pode-se definir como terminador qualquer caracter 
;            ASCII. 
;               Entradas: pilha - posicao para escrita do primeiro carater 
;                         pilha - apontador para o inicio da "string"
;               Saidas: ---
;               Efeitos: ---
;===============================================================================

EscString:      PUSH    R1
                PUSH    R2
                PUSH    R3
                MOV     R2, M[SP+6]   ; Apontador para inicio da "string"
                MOV     R3, M[SP+5]   ; Localizacao do primeiro carater
Ciclo:          MOV     M[IO_CURSOR], R3
                MOV     R1, M[R2]
                CMP     R1, FIM_TEXTO
                BR.Z    FimEsc
                CALL    EscCar
                INC     R2
                INC     R3
                BR      Ciclo
FimEsc:         POP     R3
                POP     R2
                POP     R1
                RETN    2                ; Actualiza STACK

;===============================================================================
; EscCar: Rotina que efectua a escrita de um caracter para o ecran.
;         O caracter pode ser visualizado na janela de texto.
;               Entradas: R1 - Caracter a escrever
;               Saidas: ---
;               Efeitos: alteracao da posicao de memoria M[IO]
;===============================================================================
EscCar:         MOV     M[IO_WRITE], R1
                RET                     

;===============================================================================
; RotinaInt0: Rotina de interrupção 0
;               Entradas: ---
;               Saidas: ---
;               Efeitos: ---
;===============================================================================
RotinaInt0:    PUSH     R1
               MOV      R1, 0001h
               MOV      M[INT0_global], R1
               POP      R1
               RTI

;===============================================================================
; RotinaIntTemp: Rotina de interrupção 0
;               Entradas: ---
;               Saidas: ---
;               Efeitos: ---
;===============================================================================
RotinaIntTemp: CALL     EscAliens
               PUSH     R1
               MOV      R1, TEMP_DELAY  
               MOV      M[TEMP_UNIT], R1
               MOV      R1, 0001h   ; activar temporizador
               MOV      M[TEMP_CONTROL], R1
               POP      R1
               RTI
;
;===============================================================================
; Delay: Rotina que permite gerar um atraso
;               Entradas: ---
;               Saidas: ---
;               Efeitos: ---
;===============================================================================
Delay:          PUSH    R1
                MOV     R1, DELAYVALUE
DelayLoop:      DEC     R1
                BR.NZ   DelayLoop
                POP     R1
                RET
               
;===============================================================================
; EspacoFill: Preenche setup do espaco de jogo com parede vertical e horizontal
;               Entradas: ---
;               Saidas: ---
;               Efeitos: ---
;===============================================================================
EspacoFill:    PUSH     R1
               PUSH     R2

               PUSH     parede_h
               PUSH     0000h           
               CALL     EscString       ; parede horizontal superior
               PUSH     parede_h
               PUSH     1700h           
               CALL     EscString       ; parede horizontal inferior

               MOV      R1, 1600h
               MOV      R2, '|'
vertical_loop: ADD      R1, 004Fh       ; preencher paredes verticais
               MOV      M[IO_CURSOR], R1
               MOV      M[IO_WRITE], R2
               SUB      R1, 004Fh
               MOV      M[IO_CURSOR], R1
               MOV      M[IO_WRITE], R2
               SUB      R1, 0100h
               BR.NZ    vertical_loop
               
               POP      R2
               POP      R1
               RET         

;===============================================================================
; MoveVeiculo:  Dependendo do input do utilizador, move o veiculo ou dispara
;               Entradas: ---
;               Saidas: ---
;               Efeitos: Altera M[POS_veiculo] no caso de movimento
;===============================================================================
MoveVeiculo:   PUSH     R1
               PUSH     R2
               PUSH     R3

               MOV      R1, M[POS_veiculo]

               MOV      R2, M[IO_READ]
               CMP      R2, 'a'
               BR.NZ    nota
               DEC      R1
               BR       testcolision
nota:          CMP      R2, 'd'
               BR.NZ    notd
               INC      R1
               BR       testcolision
notd:          CMP      R2, ' '
               BR.NZ    endMove
               CALL     Disparar
testcolision:  CMP      R1, 1600h          ; testar limite esquerdo xx00h
               BR.Z     endMove
               CMP      R1, 164Bh          ; testar limite direito 
                                           ; contar com espaço á direita do veic
               BR.Z     endMove

               MOV      R2, M[POS_veiculo] ; apagar 'restos' do veiculo
               MOV      R3, ' '
               MOV      M[IO_CURSOR], R2
               MOV      M[IO_WRITE], R3
               ADD      R2, 0004h
               MOV      M[IO_CURSOR], R2
               MOV      M[IO_WRITE], R3
               
               MOV      M[POS_veiculo], R1
               PUSH     veiculo
               PUSH     R1
               CALL     EscString

endMove:       POP      R3
               POP      R2
               POP      R1
               RET

;===============================================================================
; Disparar:  Função que realiza o disparo de um tiro
;               Entradas: ---
;               Saidas: ---
;               Efeitos: ---
;===============================================================================
Disparar:      PUSH     R1  
               PUSH     R2
               PUSH     R3
               
               MOV      R1, M[POS_veiculo]
               MOV      R2, '*'
               SUB      R1, 0100h        ; R1 = primeira posicao do tiro
               ADD      R1, 0002h        ; centrar tiro
shootloop:     MOV      M[IO_CURSOR], R1
               MOV      M[IO_WRITE], R2
               SUB      R1, 0100h
               CALL     Delay
               CMP      R1, 00FFh
               BR.NN    shootloop

               MOV      R2, ' '
               MOV      R3, M[POS_veiculo]
               SUB      R3, 0100h
               ADD      R3, 0002h
eraseshoot:    MOV      M[IO_CURSOR], R3
               MOV      M[IO_WRITE], R2
               SUB      R3, 0100h
               CMP      R3, R1
               BR.NZ    eraseshoot

               POP      R3
               POP      R2
               POP      R1
               
               RET
;===============================================================================
; EscAliens: representa os aliens na placa de texto com base no aliens_vec e 
;movimenta-os 1 posição
;               Entradas: ---
;               Saidas: ---
;               Efeitos: ---
;===============================================================================
EscAliens:    PUSH      R1
              PUSH      R2
              PUSH      R3
              PUSH      R4
              PUSH      R5
              PUSH      R6

              MOV       R6, ' '

              MOV       R1, 001Ch       ; contador
              MOV       R2, alien_vec

printalien:   MOV       R4, 0002h       ; apagar alien anterior
              MOV       R5, M[R2]
cleanalien:   MOV       M[IO_CURSOR], R5
              MOV       M[IO_WRITE], R6
              INC       R5
              DEC       R4
              BR.NN     cleanalien

              MOV       R3, M[R2] 
              INC       R3
              MOV       M[R2], R3

              PUSH      alien
              PUSH      R3
              CALL      EscString

              INC       R2
              DEC       R1
              BR.NZ     printalien

              POP       R6
              POP       R5
              POP       R4
              POP       R3
              POP       R2
              POP       R1
              RET

;===============================================================================
;                                Programa prinicipal
;===============================================================================
inicio:        MOV      R1, SP_INICIAL  ; setup (SP; Interrupções) 
               MOV      SP, R1

               ENI
               MOV      R1, 8001h
               MOV      M[INT_MASK], R1 ; Activar INT0
               MOV      R1, RotinaInt0
               MOV      M[TAB_INT0], R1 ; preencher int vector pos I0

               ;temporizador
               MOV      R1, TEMP_DELAY
               MOV      M[TEMP_UNIT], R1
               MOV      R1, 0001h
               MOV      M[TEMP_CONTROL], R1
               MOV      R1, RotinaIntTemp
               MOV      M[TAB_TEMP], R1

               CALL     LimpaJanela  
               CALL     EspacoFill
               PUSH     str_start
               PUSH     POS_STR  
               CALL     EscString
               PUSH     veiculo
               PUSH     POS_veiculo_ini
               CALL     EscString

; comentado por agora para debug mais rapido
;               MOV      R1, 0000h
;waitstart:     MOV      R1, M[INT0_global] 
;               CMP      R1, 0000h       ; espera por INT0 para activar R1
;               BR.Z     waitstart
;               MOV      R1, 0000h
;               MOV      M[INT0_global], R1

               ; setup aliens, posicionar aliens no vector alien_vec
               MOV      R2, 0004h
               MOV      R3, POS_alien_ini
               MOV      R5, alien_vec
linealien:     MOV      R1, 0007h
colalien:      MOV      M[R5], R3
               INC      R5
               ADD      R3, 0006h        ; passar para o alien á direita
               DEC      R1
               BR.NZ    colalien
               MOV      R4, POS_alien_ini
               AND      R4, 00FFh
               AND      R3, FF00h        ; passar para alien mais á esquerda prox linha
               OR       R3, R4
               ADD      R3, 0400h
               DEC      R2
               BR.NZ    linealien

mainloop:      MOV      R1, M[IO_PRESSED]
               CMP      R1, 0000h
               BR.Z     mainloop
               
               CALL     MoveVeiculo
               BR       mainloop

Fim:           BR       Fim
;===============================================================================
