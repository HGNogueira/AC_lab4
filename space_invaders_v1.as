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
TAB_INT7        EQU     FE07h
TAB_INTA        EQU     FE0Ah
TAB_TEMP        EQU     FE0Fh
DEFAULTINTMASK  EQU     8481h     ; interrupts [temp,A,7,0]

TEMP_UNIT       EQU     FFF6h
TEMP_CONTROL    EQU     FFF7h
TEMP_DELAY      EQU     0001h

LIMPAR_JANELA   EQU     FFFFh
FIM_TEXTO       EQU     '@'

POS_STR         EQU     121Ch
POS_MESSAGE     EQU     061Ch

PONTO           EQU     0005h

CONTINUAR       EQU     0001h
PARAR           EQU     0000h

POS_veiculo_ini EQU     1627h 

POS_alien_ini   EQU     0101h   
POS_ld_alien    EQU     0A01h
LIMITE_direita  EQU     0028h
LIMITE_esquerda EQU     0001h
GROUND_LIMIT    EQU     1700h
ALIEN_DEAD      EQU     DEADh
MOVE_DOWN       EQU     0100h
MOVE_RIGHT      EQU     0001h
MOVE_LEFT       EQU     FFFFh

;===============================================================================
; ZONA II: Definicao de variaveis
;          Pseudo-instrucoes : WORD - palavra (16 bits)
;                              STR  - sequencia de caracteres.
;          Cada caracter ocupa 1 palavra
;===============================================================================

                ORIG    8000h
str_start       STR     'Prima I0 para iniciar o jogo', FIM_TEXTO
str_restart     STR     'Prima I0 para reiniciar o jogo', FIM_TEXTO
str_clean       STR     '                              ', FIM_TEXTO
parede_h        STR     '|------------------------------------------------------------------------------|', FIM_TEXTO

NW_POSITION     WORD    004Fh             ; posição actual do cursor NumberWrite

veiculo         STR     'O-^-O', FIM_TEXTO
POS_veiculo     WORD    POS_veiculo_ini

alien           STR     'OVO', FIM_TEXTO
alien_clean     STR     '   ', FIM_TEXTO
alien_vec       TAB     28              ; vector de 28 posições
alien_move_dir  WORD    MOVE_DOWN       ; direção default, automáticamente muda MOVE_RIGHT ao inicio
alien_position  WORD    POS_ld_alien    ; contém coordenada do 1º alien
n_alien_shot    WORD    0               ; nº de aliens acertados

victory         WORD    0
str_game_won    STR     'Ganhou!', FIM_TEXTO
game_over       WORD    0000h
str_game_over   STR     'GAME OVER', FIM_TEXTO

pontuacao       WORD    0000h

running         WORD    0
restart         WORD    0

mode            WORD    0               ; modo de jogo; 0: normal | 1: superspeed

temp_flag		WORD	0000h

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
; NumberWrite: Escrever um número dado em R1 na posição CURSOR_POSITION
;               Entradas: R1 - número a escrever
;               Saidas: ---
;               Efeitos: Alteracao da posicao de memoria M[IO_CURSOR], escrita de
;número na posição dada por M[CURSOR_POSITION]
;===============================================================================
NumberWrite:    PUSH    R2
                PUSH    R3
                PUSH    R5
                PUSH    R4
                PUSH    R1

                MOV     R3, R1
                MOV     R5, M[NW_POSITION]

                MOV     R4, 0006h        ; subrotina para limpar espaço a escrever
					 ; limpa 6 caracteres (-65537)
numberclean:   	MOV     M[IO_CURSOR], R5
                MOV     R1, ' '
                CALL    EscCar
                DEC     R5
                DEC     R4
                BR.NZ   numberclean
		
                MOV     R5, M[NW_POSITION]
                CMP     R3, 0000h        ; caso o número seja negativo, usar módulo
                BR.NN   divloop
                NEG     R3

divloop:        MOV     R2, 000Ah	
                DIV     R3, R2        ; resto da divisão em R2, divisao inteira em R3
                MOV     R1, R2
                ADD     R1, '0'
                MOV     M[IO_CURSOR], R5
                DEC     R5
                CALL    EscCar
                CMP     R3, 0000h
                BR.NZ   divloop

                POP     R1
                PUSH    R1

                CMP     R1, 0000h     ; caso número negativo, escrever sinal -
                BR.NN   endNumwrite
                MOV     M[IO_CURSOR], R5
                MOV     R1, '-'
                CALL    EscCar
endNumwrite:	POP     R1
                POP     R4
                POP     R5
                POP     R3
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
; IntInit: Inicialização inicial de interrupções
;               Entradas: ---
;               Saidas: ---
;               Efeitos: ---
;===============================================================================
IntInit:       PUSH     R1 
               MOV      R1, DEFAULTINTMASK
               MOV      M[INT_MASK], R1        

               MOV      R1, RotinaInt0
               MOV      M[TAB_INT0], R1       ; preencher int vector pos I0

               MOV      R1, RotinaInt7
               MOV      M[TAB_INT7], R1  

               MOV      R1, RotinaIntA
               MOV      M[TAB_INTA], R1

               ;temporizador
               MOV      R1, TEMP_DELAY
               MOV      M[TEMP_UNIT], R1
               MOV      M[TEMP_CONTROL], R0   ; esperar por start
               MOV      R1, RotinaIntTemp
               MOV      M[TAB_TEMP], R1
               
               POP      R1

               ENI
               RET

;===============================================================================
; RotinaInt0: Rotina de interrupção 0
;             Setup dos aliens e escrita inicial para o ecrã
;               Entradas: ---
;               Saidas: ---
;               Efeitos: ---
;===============================================================================
RotinaInt0:    PUSH     R1
               MOV      R1, 1
               MOV      M[restart], R1
               MOV      M[n_alien_shot], R0 
               MOV      M[victory], R0
               POP      R1
               RTI
;===============================================================================
; RotinaInt7: Rotina de interrupção 7 - modo ultra rápido
;               Entradas: ---
;               Saidas: ---
;               Efeitos: ---
;===============================================================================
RotinaInt7:    PUSH     R1
               MOV      R1, M[mode]
               XOR      R1, 1
               MOV      M[mode], R1      ; toggle modo superspeed/normal
               POP      R1
               RTI

;===============================================================================
; RotinaIntA: Rotina de interrupção A - Pausa
;               Entradas: ---
;               Saidas: ---
;               Efeitos: ---
;===============================================================================
RotinaIntA:    PUSH     R1
               MOV      R1, M[running]
               XOR      R1, 0001h          ; toggle ao bit de pausa
               MOV      M[running], R1
               POP      R1
               RTI

;===============================================================================
; RotinaIntTemp: Rotina de interrupção 0
;               Entradas: ---
;               Saidas: ---
;               Efeitos: ---
;===============================================================================
RotinaIntTemp: PUSH     R1
               MOV      R1, TEMP_DELAY
               MOV      M[TEMP_UNIT], R1
               MOV      R1, 0001h   ; activar temporizador
               MOV      M[TEMP_CONTROL], R1
               MOV      R1, M[running]
			   MOV		M[temp_flag], R1      ; só activa se jogo estiver a decorrer
               POP      R1
               RTI

;===============================================================================
; Setup: Rotina de setup de aliens inicial
;               Entradas: ---
;               Saidas: ---
;               Efeitos: ---
;===============================================================================
Setup:         PUSH     R1
               PUSH     R2
               PUSH     R3 
               PUSH     R4 
               PUSH     R5

               CALL     LimpaJanela  
               CALL     EspacoFill

               PUSH     veiculo
               MOV      R1, M[POS_veiculo]
               PUSH     R1
               CALL     EscString

               ; setup aliens, posicionar aliens no vector alien_vec
               MOV      R1, MOVE_DOWN
               MOV      M[alien_move_dir], R1

               MOV      R1, POS_ld_alien
               MOV      M[alien_position], R1

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
               ADD      R3, 0300h
               DEC      R2
               BR.NZ    linealien

               POP      R5
               POP      R4
               POP      R3
               POP      R2
               POP      R1
               RET

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
; ABSDIF: Calcula valor absoluto da diferença de 2 números R = |A-B|
;               Entradas:  pilha - operando A
;                          pilha - operando B
;               Saidas:    pilha - resultado R
;               Efeitos: ---
;===============================================================================
ABSDIF:         PUSH    R1
                PUSH    R2

                MOV     R1, M[SP + 4]
                MOV     R2, M[SP + 5]
                SUB     R1, R2
                BR.P    num_positivo
                NEG     R1
num_positivo:   MOV     M[SP + 5], R1
                POP     R2
                POP     R1
                RETN    1
               
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
               PUSH     R4
               PUSH     R5
               PUSH     R6
               
               MOV      R1, M[POS_veiculo]
               MOV      R2, '*'
               SUB      R1, 0100h        ; R1 = primeira posicao do tiro
               ADD      R1, 0002h        ; centrar tiro
shootloop:     MOV      M[IO_CURSOR], R1
               MOV      M[IO_WRITE], R2
               SUB      R1, 0100h
               MOV      R3, alien_vec
               ADD      R3, 001Bh        ; começar check hit de aliens em baixo
               MOV      R5, 001Ch       
checkhit:      MOV      R4, M[R3]
               INC      R4               ; coordenada centro do alien
               PUSH     R4               ; para efeito de cálculo
               PUSH     R1
               CALL     ABSDIF
               DEC      R4               ; voltar a coordenada original
               POP      R6
               CMP      R6, 0002h   ; se tiro acertou no alien 
               BR.N     alienshot
               DEC      R3
               DEC      R5
               BR.NZ    checkhit
               
               CMP      R1, 00FFh
               BR.NN    shootloop
               BR       missedshot

alienshot:     PUSH     alien_clean 
               PUSH     R4
               CALL     EscString
               MOV      R4, ALIEN_DEAD
               MOV      M[R3], R4
               CALL     UpdatePontos
               MOV      R6, M[n_alien_shot]
               INC      R6
               MOV      M[n_alien_shot], R6
               CMP      R6, 28           ; foram abatidos todos os aliens?
               BR.NZ    missedshot
               MOV      R6, 1
               MOV      M[victory], R6

missedshot:    MOV      R2, ' '
               MOV      R3, M[POS_veiculo]
               SUB      R3, 0100h
               ADD      R3, 0002h

               ; delay 0.2s usando temporizador
               ; esperar que a flag do temporizador seja activada 2x
               MOV      R6, 2
               MOV      R4, M[temp_flag]
               MOV      M[temp_flag], R0
temp_delay:    MOV      R5, M[temp_flag]    
               CMP      R5, 0              
               BR.Z     temp_delay
               MOV      M[temp_flag], R0
               DEC      R6
               CMP      R6, 0
               BR.NZ    temp_delay

               MOV      M[temp_flag], R4

eraseshoot:    MOV      M[IO_CURSOR], R3
               MOV      M[IO_WRITE], R2
               SUB      R3, 0100h
               CMP      R3, R1
               BR.NZ    eraseshoot

               MOV      R1, 1

               POP      R6
               POP      R5
               POP      R4
               POP      R3
               POP      R2
               POP      R1
               RET

;===============================================================================
; UpdatePontos
;               Entradas: 
;               Saidas: ---
;               Efeitos: ---
;===============================================================================
UpdatePontos: PUSH     R1
              MOV      R1, M[pontuacao]
              ADD      R1, PONTO
              MOV      R1, M[pontuacao]
              POP      R1
              RET

;===============================================================================
; EscUmAlien: 
;               Entradas: R7 e R2
;               Saidas: ---
;               Efeitos: ---
;===============================================================================
EscUmAlien:   PUSH      R3
              PUSH      R4
              PUSH      R5

              MOV       R5, M[R2]

              CMP       R5, ALIEN_DEAD  ; ver se alien já foi atingido
              JMP.Z     fimUmAlien

cont_print:   PUSH      alien_clean
              PUSH      R5
              CALL      EscString

              MOV       R3, M[R2] 
              ADD       R3, R7          ; mover alien next print, dir R7
              MOV       M[R2], R3

              PUSH      alien
              PUSH      R3
              CALL      EscString
        
              INC       R3              ; centrar alien
              PUSH      R3
              MOV       R5, M[POS_veiculo]
              INC       R5              ; centrar veiculo
              PUSH      R5
              CALL      ABSDIF
              POP       R5
              CMP       R5, 0003h       ; verificar embate com nave
              BR.NN     testground
              MOV       R4, 0001h  
              MOV       M[game_over], R4
testground:   CMP       R3, GROUND_LIMIT
              BR.N      fimUmAlien
              MOV       M[game_over], R4

fimUmAlien:   POP       R5 
              POP       R4
              POP       R3
              RET

;===============================================================================
;MovAliens: representa os aliens na placa de texto com base no aliens_vec e 
;movimenta-os 1 posição
;               Entradas: ---
;               Saidas: ---
;               Efeitos: ---
;===============================================================================
MovAliens:    PUSH      R1
              PUSH      R2
              PUSH      R3
              PUSH      R4
              PUSH      R5
              PUSH      R6
              PUSH      R7

              MOV       R6, ' '
              MOV       R7, M[alien_move_dir]
              MOV       R1, 001Ch           ; contador, 28d nº aliens
              MOV       R2, alien_vec       ; apontador para vector aliens

              CMP       R7, MOVE_DOWN       ; se aliens acabaram de descer
              BR.NZ     fronteira_dir
              MOV       R4, M[alien_position]
              AND       R4, 00FFh  
              CMP       R4, LIMITE_esquerda
              BR.NZ     moveresq
              MOV       R7, MOVE_RIGHT      ; passam a andar para a direita
              MOV       M[alien_move_dir], R7
              BR        printalien
moveresq:     MOV       R7, MOVE_LEFT       ; passam a andar para a esquerda
              MOV       M[alien_move_dir], R7
              BR        printalien

fronteira_dir:MOV       R4, M[alien_position]  ; atingiram parede direita?
              AND       R4, 00FFh
              CMP       R4, LIMITE_direita
              BR.NZ     fronteira_esq
              MOV       R7, MOVE_DOWN          ; mover para baixo
              MOV       M[alien_move_dir], R7  ; update direção
              BR        printalien
fronteira_esq:CMP       R4, LIMITE_esquerda
              BR.NZ     printalien
              MOV       R7, MOVE_DOWN          ; mover para baixo
              MOV       M[alien_move_dir], R7  ; update direção

printalien:   CALL      EscUmAlien
              INC       R2
              DEC       R1
              BR.NZ     printalien

              MOV       R1, M[alien_position]  ; update posicao aliens
              ADD       R1, R7 
              MOV       M[alien_position], R1
			  
              MOV       R1, M[mode]
			  MOV		M[temp_flag], R1       ; só desactiva temp_flag em modo normal (0)

              POP       R7
              POP       R6
              POP       R5
              POP       R4
              POP       R3
              POP       R2
              POP       R1
              RET

;===============================================================================
; GameLost: 
;               Entradas: ---
;               Saidas: ---
;               Efeitos: ---
;===============================================================================
GameLost:    PUSH     R1
             MOV      M[running], R0
             PUSH     str_game_over
             PUSH     POS_MESSAGE
             CALL     EscString
             PUSH     str_restart
             PUSH     POS_STR
             CALL     EscString

             POP      R1
             RET

;===============================================================================
; GameWon: 
;               Entradas: ---
;               Saidas: ---
;               Efeitos: ---
;===============================================================================
GameWon:     PUSH     R1
             MOV      M[running], R0
             PUSH     str_game_won
             PUSH     POS_MESSAGE
             CALL     EscString
             PUSH     str_restart
             PUSH     POS_STR
             CALL     EscString

             MOV      M[n_alien_shot], R0

             POP      R1
             RET
 
;===============================================================================
;                                Programa prinicipal
;===============================================================================
inicio:        MOV      R1, SP_INICIAL  ; setup (SP; Interrupções) 
               MOV      SP, R1

               ; default screen
               CALL     LimpaJanela  
               CALL     EspacoFill
               CALL     IntInit
               PUSH     str_start
               PUSH     POS_STR  
               CALL     EscString
               PUSH     veiculo
               PUSH     POS_veiculo_ini
               CALL     EscString

waitstart:     MOV      R1, M[restart] 
               CMP      R1, 0001h       ; esperar pelo sinal restart para prosseguir
               BR.NZ    waitstart
               CALL     Setup
               MOV      M[restart], R0
               MOV      M[TEMP_CONTROL], R1
               MOV      M[running], R1
               MOV      M[game_over], R0

mainloop:      MOV		R1, M[temp_flag]
			   CMP		R1, 1
			   CALL.Z   MovAliens
			   MOV      R1, M[game_over]
               CMP      R1, 0001h
               BR.Z     perdeu
               MOV      R1, M[victory]
               CMP      R1, 1
               BR.Z     ganhou
               MOV      R1, M[running]
               CMP      R1, 0000h
               BR.Z     pausaloop
               MOV      R1, M[IO_PRESSED]
               CMP      R1, 0000h
               BR.Z     mainloop
               
               CALL     MoveVeiculo
               BR       mainloop

ganhou:        CALL     GameWon
               JMP      waitstart

perdeu:        CALL     GameLost
               JMP      waitstart

pausaloop:     MOV      R1, M[running]
               CMP      R1, 0000h
               BR.Z     pausaloop
               JMP      mainloop
;===============================================================================
