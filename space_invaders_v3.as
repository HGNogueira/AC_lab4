;===============================================================================
; ZONA I: Definicao de constantes
;         Pseudo-instrucao : EQU
;===============================================================================
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
TEMP_DELAY      EQU     0001h     ; tempo de delay 0.1s

LCD_WRITE       EQU     FFF5h
LCD_CONTROL     EQU     FFF4h

LEDS            EQU     FFF8h     ; posição de mem de activação de leds

RELOGIO_RIGHT   EQU     FFF0h     ; algarismo mais á direita display 7 seg

LIMPAR_JANELA   EQU     FFFFh
FIM_TEXTO       EQU     '@'

POS_STR         EQU     091Ah
POS_MESSAGE     EQU     0624h

PONTO           EQU     0005h     ; valor de um ponto

POS_veiculo_ini EQU     1627h     ; posição inicial do veiculo

POS_alien_ini   EQU     0101h     ; posição inicial alien esquerda cima
POS_ld_alien    EQU     0A01h     ; posição inicial alien esquerda baixo
LIMITE_direita  EQU     0028h     ; limite dir para posição de alien esq
LIMITE_esquerda EQU     0001h     ; limite esq para posição alien esq
GROUND_LIMIT    EQU     1700h     ; limite baixo
ALIEN_DEAD      EQU     DEADh     ; posição de alien destruido
MOVE_DOWN       EQU     0100h     ; incremento de posição movimento para baixo
MOVE_RIGHT      EQU     0001h     ; incremento de posição movimento direita
MOVE_LEFT       EQU     FFFFh     ; incremente de posição movimento esquerda

;===============================================================================
; ZONA II: Definicao de variaveis
;          Pseudo-instrucoes : WORD - palavra (16 bits)
;                              STR  - sequencia de caracteres
;                              TAB  - vector de dimensão 'const'
;===============================================================================

                ORIG    8000h
str_start       STR     ' Prima I0 para iniciar o jogo', FIM_TEXTO
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
str_game_won    STR     ' Ganhou!', FIM_TEXTO
game_over       WORD    0000h
str_game_over   STR     'GAME OVER', FIM_TEXTO

pontuacao       WORD    0000h
str_pontos      STR     'Pontuacao: ', FIM_TEXTO

running         WORD    0
restart         WORD    0

mode            WORD    0               ; modo de jogo; 0: normal | 1: superspeed

temp_flag		WORD	0000h
relogio_flag    WORD    0000h

tempo           WORD    0000h           ; contabiliza n interrupções de timer

;===============================================================================
; ZONA III: Codigo
;           conjunto de instrucoes Assembly, ordenadas de forma a realizar
;           as funcoes pretendidas
;===============================================================================
                ORIG    0000h
                JMP     inicio

;===============================================================================
; IntInit: Inicialização das interrupções, default
;               Entradas: ---
;               Saidas: ---
;               Efeitos: preenche M[INT_MASK], tabela de interrupções, unidades
; do timer e ENI
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
; RotinaInt0: Rotina de interrupção associado ao botão de pressão 0
;               Entradas: ---
;               Saidas: ---
;               Efeitos: activa M[restart] permitindo sair do loop waitstart,
;reinicia nº de aliens destruidos numa ronda colocando M[n_alien_shot] = 0
;===============================================================================
RotinaInt0:    PUSH     R1
               MOV      R1, 1
               MOV      M[restart], R1
               MOV      M[n_alien_shot], R0 
               POP      R1
               RTI
;===============================================================================
; RotinaInt7: Rotina de interrupção associada ao botão de pressão 7
;               Entradas: ---
;               Saidas: ---
;               Efeitos: toggle M[mode] permitindo alternar entre modo
;superspeed e normal
;===============================================================================
RotinaInt7:    PUSH     R1
               MOV      R1, M[mode]
               XOR      R1, 1
               MOV      M[mode], R1        ; toggle modo superspeed/normal
               POP      R1
               RTI

;===============================================================================
; RotinaIntA: Rotina de interrupção associada ao botão de pressão A
;               Entradas: ---
;               Saidas: ---
;               Efeitos: toggle M[running] permitindo alternar entre programa
;a correr ou em pausa
;===============================================================================
RotinaIntA:    PUSH     R1
               MOV      R1, M[running]
               XOR      R1, 0001h          ; toggle ao bit de pausa
               MOV      M[running], R1
               POP      R1
               RTI

;===============================================================================
; RotinaIntTemp: Rotina de interrupção associado ao Timer
;               Entradas: ---
;               Saidas: ---
;               Efeitos: incrementa M[tempo], volta a recolocar unidades 
;do timer (M[TEMP_UNIT]=TEMP_DELAY), activa contagem do Timer (M[TEMP_COMTROL]=1)
;, activa M[relogio_flag] permitindo ser chamada a função de escrita de tempo,
;activa M[temp_flag] se jogo estiver a ser corrido (vs pausa)
;===============================================================================
RotinaIntTemp: PUSH     R1

               MOV      R1, M[tempo]
               ADD      R1, M[running]        ; incrementa se jogo a correr
               MOV      M[tempo], R1

               MOV      R1, TEMP_DELAY
               MOV      M[TEMP_UNIT], R1
               MOV      R1, 1
               MOV      M[TEMP_CONTROL], R1
               MOV      M[relogio_flag], R1
               MOV      R1, M[running]
	       MOV	M[temp_flag], R1      ; só é activada enquanto modo running

               POP      R1
               RTI

;===============================================================================
; LimpaJanela: Rotina que limpa a janela de texto.
;               Entradas: --
;               Saidas: ---
;               Efeitos: IO janela de texto é totalmente limpa
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
; EspacoFill: Preenche setup do espaco de jogo com parede vertical e horizontal
;               Entradas: ---
;               Saidas: ---
;               Efeitos: preenche IO janela de texto com o setup gráfico inicial
;M[IO_CURSOR] é alterada
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
; Setup: Rotina de setup de aliens inicial
;               Entradas: ---
;               Saidas: ---
;               Efeitos: volta a preencher IO janela de texto com setup inicial,
;cálcula posições iniciais dos aliens e escreve no vector alien_position
;===============================================================================
Setup:         PUSH     R1
               PUSH     R2
               PUSH     R3 
               PUSH     R4 
               PUSH     R5

               CALL     LimpaJanela  
               CALL     EspacoFill

               PUSH     veiculo         ; voltar a colocar veiculo no ecran
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
; MoveVeiculo:  Dependendo do input do utilizador, move o veiculo ou dispara
;               Entradas: ---
;               Saidas: ---
;               Efeitos: Caso movimento: altera M[POS_veiculo] de acordo com
;input do utilizador
;                        Caso disparo: é chamada a funcao Disparar que irá
;representar o tiro na janela de texto
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
;               Efeitos: LEDS acendem momentaneamente, é impresso na janela de
;texto o rasto do tiro que se extende até ao teto ou até ao primeiro alien que
;acertar, neste caso o vector 'alien_vec' é alterado na posição respectiva do 
;alien disparado colocando o seu valor para ALIEN_DEAD de modo a não ser mais
;impresso na janela de texto, incrementa M[alien_shot] caso o tiro atinja aliens
;===============================================================================
Disparar:      PUSH     R1
               PUSH     R2
               PUSH     R3
               PUSH     R4
               PUSH     R5
               PUSH     R6

               MOV      R1, FFFFh
               MOV      M[LEDS], R1      ; acender LEDS momentaneamente
               
               MOV      R1, M[POS_veiculo]
               MOV      R2, '*'
               ADD      R1, 0002h        ; centrar tiro
shootloop:     SUB      R1, 0100h
               MOV      M[IO_CURSOR], R1
               MOV      M[IO_WRITE], R2
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
               CMP      R6, 0002h        ; se tiro acertou no alien 
               BR.N     alienshot
               DEC      R3
               DEC      R5
               BR.NZ    checkhit
               
               MOV      R6, R1
               AND      R6, FF00h
               CMP      R6, 0100h
               BR.NZ    shootloop        ; verificar que ainda nao atingiu teto
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
               CALL     UpdateTempo
               MOV      M[temp_flag], R0
               DEC      R6
               CMP      R6, 0
               BR.NZ    temp_delay

               MOV      M[temp_flag], R4

eraseshoot:    MOV      M[IO_CURSOR], R3
               MOV      M[IO_WRITE], R2
               SUB      R3, 0100h
               CMP      R3, R1
               BR.NN    eraseshoot

               MOV      R1, 1

               MOV      M[LEDS], R0      ; apagar LEDS

               POP      R6
               POP      R5
               POP      R4
               POP      R3
               POP      R2
               POP      R1
               RET

;===============================================================================
; UpdatePontos: Incrementa pontuacao e chama rotina de escrita de pontos no LCD
;               Entradas: 
;               Saidas: ---
;               Efeitos: incrementa M[pontuacao]
;===============================================================================
UpdatePontos: PUSH     R1
              MOV      R1, M[pontuacao]
              ADD      R1, PONTO
              MOV      M[pontuacao], R1
              CALL     WritePontos
              POP      R1
              RET

;===============================================================================
; WritePontos: Converte pontos para decimal e escreve pontuacao no ecran LCD
;               Entradas: ---
;               Saidas: ---
;               Efeitos: ---
;===============================================================================
WritePontos:  PUSH     R1
              PUSH     R2
              PUSH     R3
              PUSH     R4
            
              ; escrever string Pontuacao
              MOV      R1, 8010h
              MOV      M[LCD_CONTROL], R1    ; limpa display
              MOV      R1, 8000h
              MOV      R2, str_pontos
lcd_w_loop:   MOV      R3, M[R2]
              CMP      R3, FIM_TEXTO
              BR.Z     lcd_w_number
              MOV      M[LCD_CONTROL], R1
              MOV      M[LCD_WRITE], R3
              INC      R2
              INC      R1
              CMP      R1, 800Fh
              BR.P     lcd_w_number
              BR       lcd_w_loop

              ; escrita dos pontos em decimal
lcd_w_number: MOV      R1, 800Fh            ; começar na pos mais à direita
              MOV      R4, M[pontuacao] 
lcd_divloop:  MOV      R2, 000Ah
              DIV      R4, R2 
              MOV      R3, R2
              ADD      R3, '0'              ; offset ASCI
              MOV      M[LCD_CONTROL], R1
              DEC      R1
              MOV      M[LCD_WRITE], R3
              CMP      R4, 0
              BR.NZ    lcd_divloop

endWP:        POP      R4 
              POP      R3
              POP      R2
              POP      R1
              RET

;===============================================================================
; UpdateTempo: Chama rotina de escrita de tempo se passaram 10 decimas de segundo
;desde a última escrita
;               Entradas:---
;               Saidas: ---
;               Efeitos: desactiva M[relogio_flag]
;===============================================================================
UpdateTempo:  PUSH     R1
              PUSH     R2

              MOV      R2, 10
              MOV      R1, M[tempo]
              DIV      R1, R2
              CMP      R2, 0             
              CALL.Z   WriteTempo           ; Update se passou 10 decimas de sec

              MOV      M[relogio_flag], R0

              POP      R2
              POP      R1
              RET

;===============================================================================
; WriteTempo: converte tempo para segundos e minutos e escreve valor no display
;de 7 segmentos
;               Entradas: ---
;               Saidas: ---
;               Efeitos: altera posições de memória respectivas ao IO display de
;7 segmentos
;===============================================================================
WriteTempo:   PUSH     R1
              PUSH     R2
              PUSH     R3
              PUSH     R4

              MOV      R1, M[tempo]
              MOV      R2, 10
              DIV      R1, R2               ; passar de decimas de sec para sec
              MOV      R2, 60

              DIV      R1, R2               ; R1: minutos, R2, segundos

              MOV      R3, RELOGIO_RIGHT

              MOV      R4, 10               ; escrever segundos em dec
              DIV      R2, R4
              MOV      M[R3], R4
              INC      R3
              MOV      M[R3], R2
              INC      R3
            
              MOV      R4, 000Ah            ; escrever minutos em dec
              DIV      R1, R4
              MOV      M[R3], R4
              INC      R3
              MOV      M[R3], R1

              POP      R4
              POP      R3
              POP      R2
              POP      R1
              RET

;===============================================================================
;MovAliens: representa os aliens na placa de texto com base no aliens_vec e 
;movimenta-os 1 posição
;               Entradas: ---
;               Saidas: ---
;               Efeitos: altera M[alien_position] de acordo com direção movida
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
	      MOV	M[temp_flag], R1       ; desactiva temp_flag modo 0
                                               ; vs modo superspeed

              POP       R7
              POP       R6
              POP       R5
              POP       R4
              POP       R3
              POP       R2
              POP       R1
              RET

;===============================================================================
; EscUmAlien: Escreve aliens e altera as suas posições individualmente de acordo
;com a direção movida
;               Entradas: R7 e R2, respectivamente direção e indice do alien a
; mover
;               Saidas: ---
;               Efeitos: altera M[R2] com a nova posição do respectivo alien,
;escreve esse alien no ecran
;===============================================================================
EscUmAlien:   PUSH      R3
              PUSH      R4
              PUSH      R5

              MOV       R5, M[R2]

              CMP       R5, ALIEN_DEAD  ; ver se alien já foi atingido
              JMP.Z     fimUmAlien

cont_print:   PUSH      alien_clean     ; apaga alien anterior
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
              POP       R5              ; distancia horiz alien-veiculo
              CMP       R5, 0003h       ; verificar embate com nave
              MOV       R4, 0001h  
              BR.NN     testground
              MOV       M[game_over], R4
testground:   AND       R3, FF00h
              CMP       R3, GROUND_LIMIT
              BR.NZ     fimUmAlien
              MOV       M[game_over], R4

fimUmAlien:   POP       R5 
              POP       R4
              POP       R3
              RET



;===============================================================================
; GameLost: rotina chamada após derrota 
;               Entradas: ---
;               Saidas: ---
;               Efeitos: desactiva M[running], escreve mensagem de derrota no
;ecran, reinicia nº de aliens desctruidos na ronda
;===============================================================================
GameLost:    PUSH     R1
             MOV      M[running], R0
             PUSH     str_game_over
             PUSH     POS_MESSAGE
             CALL     EscString
             PUSH     str_restart
             PUSH     POS_STR
             CALL     EscString

             MOV      M[n_alien_shot], R0
             MOV      M[game_over], R0

             POP      R1
             RET

;===============================================================================
; GameWon: rotina chamada após victória numa ronda
;               Entradas: ---
;               Saidas: ---
;               Efeitos: desactiva M[running], escreve mensagem de victória
;, desactiva M[victory], reinicia nº de aliens destruidos
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
             MOV      M[victory], R0

             POP      R1
             RET
 
;===============================================================================
;                                Programa principal
;===============================================================================
inicio:        MOV      R1, SP_INICIAL  ; setup (SP; Interrupções) 
               MOV      SP, R1

               ; default screen
               CALL     LimpaJanela  		;inicializacao de todo o display
               CALL     EspacoFill		; gráfico inicial
               PUSH     str_start
               PUSH     POS_STR  
               CALL     EscString

               MOV      R1, POS_veiculo_ini	;desenho do veiculo
               MOV      M[POS_veiculo], R1
               PUSH     veiculo
               PUSH     R1
               CALL     EscString

	       CALL     IntInit			;inicializacao das interrupcoes

               MOV      M[pontuacao], R0	;inicializacao dos pontos a 0
               CALL     WritePontos		;escrita na Janela da Placa
               MOV      M[tempo], R0		;inicializacao do tempo a 0
               CALL     WriteTempo		;escrita na Janela da Placa

waitstart:     MOV      R1, M[restart] 
               CMP      R1, 0001h       ; esperar pelo sinal restart para seguir
               BR.NZ    waitstart

	       ; correcao de alguns valores para inicio do jogo
               CALL     Setup		
               MOV      M[restart], R0
               MOV      M[TEMP_CONTROL], R1
               MOV      M[running], R1

mainloop:      MOV	R1, M[temp_flag]	;verifica se decorreu 0.1s
	       CMP	R1, 1
	       CALL.Z   MovAliens		;move os aliens
               MOV      R1, M[relogio_flag]	;verifica se decorreu 1s
               CMP      R1, 1
               CALL.Z   UpdateTempo		;atualiza o tempo
               MOV      R1, M[running]		;verifica se o jogo foi colocado
               CMP      R1, 0			; em pausa
               JMP.Z    pausaloop
continua:      MOV      R1, M[IO_PRESSED]	;verifica se alguma tecla foi
               CMP      R1, 1			;  pressionada
               CALL.Z   MoveVeiculo		;move veículo ou dispara
	       MOV      R1, M[game_over]	;verifica se ganhou
               CMP      R1, 1
               BR.Z     perdeu
               MOV      R1, M[victory]		;verifica se perdeu
               CMP      R1, 1
               BR.Z     ganhou
               JMP      mainloop

ganhou:        CALL     GameWon 
               MOV      M[running], R0	  ; Para o Jogo
               MOV      M[restart], R0    ; evitar restart automático
               JMP      waitstart

perdeu:        CALL     GameLost
               MOV      M[running], R0	  ; Para o Jogo
               MOV      M[restart], R0    ; evitar restart automático
               JMP      waitstart

pausaloop:     MOV      R1, M[running]	  ; Permanece neste loop enquanto 
               CMP      R1, 0000h	  ;  o jogo estiver em pausa
               BR.Z     pausaloop
               JMP      continua
;===============================================================================