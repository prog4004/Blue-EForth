\ KEYBOARD.F  RUN A PS2/AT KEYBOARD
\ PB IS CHOSEN BECAUSE IT IS 5V TOLERENT
\ PB-8 to PB-14 ARE PAR DATA
\ PB-15 IS THE STROBE
\ PB-6 IS KEYBOARD CLOCK
\ PB-7 IS KEYBOARD DATA  SIMPLEST DATA HANDLING
\
HEX

: BIT ( PIN# - BIT ) \ USED AS A GENERAL PORT MASK VALUE
   1 SWAP LSHIFT ;

: CONF ( PIN# - MASK OFFSET ) \ USED FOR MODE AND CONFIG
   4 * 20 /MOD
   4 *
   0F ROT LSHIFT
   SWAP ;

\ MODE MASK FIRST THEN MODIFIERS
CCCCCCCC CONSTANT INMODE
33333333 CONSTANT OUT50
11111111 CONSTANT OUT10
22222222 CONSTANT OUT2

\ CONFIG MODIFIERS
  \ INPUT MODIFIERS
: ANALOG 0 AND ;
: FLOAT 44444444 AND ;
: UP/DN 88888888 AND ;

  \ OUTS TYPE MODIFIERS
: ALT   88888888 OR ;
: P/P ;
: DRAIN 44444444 OR ;

\ GPIO DATA PORTS OFFSETS

08 PB+ CONSTANT InB
0C PB+ CONSTANT OutB

7 CONSTANT Data#
0FF00 CONSTANT ParMsk \ PORT + STROBE MASK
8000 CONSTANT StrobeMsk
VARIABLE Strobe \ NEED TO ADD CODE TO SET + OR - STROBE

0 PB+ CONSTANT PortB
Data# BIT CONSTANT Data ( 10000000B )
: +Data ( - ) Data PortB SET! ;
: -Data ( - ) Data PortB CLR! ;
6 CONSTANT Clk#
Clk# BIT CONSTANT Clk
: +Clk ( - ) Clk PortB SET! ;
: -Clk ( - ) Clk PortB CLR! ;

: SetPB
   OUT10 DRAIN Data#  CONF PB+ MSK!
   OUT10 DRAIN Clk# CONF PB+ MSK!
   OUT10 DRAIN 0F CONF PB+ MSK! \ STROBE
   OUT10 DRAIN 0E CONF PB+ MSK! \ PARALLEL BITS
   OUT10 DRAIN 0D CONF PB+ MSK!
   OUT10 DRAIN 0C CONF PB+ MSK!
   OUT10 DRAIN 0B CONF PB+ MSK!
   OUT10 DRAIN 0A CONF PB+ MSK!
   OUT10 DRAIN 09 CONF PB+ MSK!
   OUT10 DRAIN 08 CONF PB+ MSK! ;

CREATE Table 80 ALLOT
Table 80 0 FILL
: X SWAP Table + C! ;
( 0 TO 60H )
0D 09 X
0E 60 X
15 71 X
16 31 X
1A 7A X
1B 73 X
1C 61 X
1D 77 X
1E 32 X
21 63 X
22 78 X
23 64 X
24 65 X
25 34 X
26 33 X
29 20 X
2A 76 X
2B 66 X
2C 74 X
2D 72 X
2E 35 X
31 6E X
32 62 X
33 68 X
34 67 X
35 79 X
36 36 X
3A 6D X
3B 6A X
3C 75 X
3D 37 X
3E 38 X
0E 60 X
4E 2D X
41 2C X
42 6B X
43 69 X
44 6F X
45 30 X
46 39 X
49 2E X
4A 2F X
4B 6C X
4C 3B X
4D 70 X
52 27 X
54 5B X
55 3D X
5A 0D X
5B 5D X
5D 5C X
66 08 X
76 1B X

CREATE ShfTable 14 ALLOT
: Z SWAP 2C - ShfTable + C! ;
2C 3C Z
2D 5F Z
2E 3E Z
2F 3F Z
30 29 Z
31 21 Z
32 40 Z
33 23 Z
34 24 Z
35 25 Z
36 5E Z
37 26 Z
38 2A Z
39 28 Z
3A 22 Z
3B 27 Z
3C 3C Z
3D 2B Z
3E 3E Z
3F 3F Z

CREATE ShftTable2 6 ALLOT HERE ALIGNED CP !

: W SWAP 5B - ShftTable2 + C! ;

5B 7B W
5C 7C W
5D 7D W
5E 5E W
5F 5F W
60 7E W

\ SPECIAL CASE SHIFT 60 7E
\ CONTROL ARE 40 TO 5A INCLUSIVE AND 60 T0 7A


\ SHIFT 12 59
\ CNTRL L 14  R E0 14
\ CAPS LOCK 58
\ NUM 77
\ BACK SPACE 66
VARIABLE Parity


: 40uS ( - ) 3 FOR 4 5 / DROP NEXT ;
: Clk@ ( - BIT )  InB @ Clk AND ;
: Data@ ( - BIT ) InB @ Data AND ;

: Cycle
   BEGIN Clk@ UNTIL
   BEGIN Clk@ 0 = UNTIL ;

 : Bit@ ( - BIT )
   Cycle Data@ ;

: WaitStart
   +Data +Clk
   BEGIN
    Cycle
    Data@ 0 =
   UNTIL ;

: GetByte ( - BYTE )
   WaitStart
   0 Parity !
   0
   7 FOR
     2/ Bit@ DUP Parity @ XOR Parity ! OR
   NEXT
   DUP DROP DUP DROP \ little delay
   Bit@ Parity @ XOR 0 =
   IF ."  Parity Eror " THEN ;


CREATE FIFO 80 ALLOT
VARIABLE InFIFO 0 InFIFO !
VARIABLE OutFIFO 0 OutFIFO !

: FIFO! ( BYTE - )
   InFIFO @ 1+
   7F AND DUP InFIFO !
   FIFO + C! ;

: GetKey ( - BYTE )
   OutFIFO @ DUP InFIFO @ -
   IF \ IN FIFO
     DUP FIFO + C@
     SWAP 1+ 7F AND OutFIFO !
   ELSE \ NEED TO FETCH MORE
     DROP
     BEGIN
       GetByte
       Bit@ 0 =
     WHILE  \ NOT STOP
       FIFO!
     REPEAT
     -Clk
   THEN ;

 : Bit! ( BYTE - BYTE/2 )
   DUP 1 AND DUP \ DATA BIT BIT
   BEGIN Clk@ 0 = UNTIL
   IF +Data ELSE -Data THEN
   Parity @ XOR Parity !
   2/
   BEGIN Clk@ UNTIL ;

VARIABLE CNT

: WaitIdle
   +Data +Clk
   BEGIN Clk@ 0 = Data@ 0 = OR 0 = UNTIL ;

: Response ( - byte )
  +Data
  GetByte
  Bit@ DROP ;

: SendByte ( BYTE - )
  WaitIdle
  1 Parity !
  +Clk BEGIN Clk@ UNTIL \ WAIT IDLE
  -Clk 40uS 40uS 40uS \ MAKE SURE KB KNOWS WE ARE IN CONTROL
  -Data 40uS \ START BIT
  +Clk
  BEGIN Clk@ UNTIL  \ KB CLOCKS NOW
  7 FOR
    Bit!
  NEXT DROP
  Parity @ Bit! DROP \ SEND PARITY
  1 Bit! DROP ;

: Command ( Cmd - )
  SendByte
  Response
  FA - IF ." Cmd Fails " THEN ;

: Watch
    0 CNT !
    InB @ C0 AND
   BEGIN
    DUP InB @ C0 AND -
    IF InB @ C0 AND 1 CNT +! THEN
    ?KEY CNT @ 30 = OR
   UNTIL
    CNT @ FOR . CR NEXT ;

: Led ( N - )
  ED Command Command ;
\  SendByte
\  Watch ;

VARIABLE Shift
VARIABLE CapLk
VARIABLE Cntrl
12 CONSTANT LShft
59 CONSTANT RShft
14 CONSTANT LCntrl
28 CONSTANT RCntrl ( ARBITRARY VALUE DIFFERENT THAN LCNTRL )
58 CONSTANT CapKey


: 2ASCII ( BYTE - ) \ SEND BYTE TO PORT AS ASCII
  Table + C@ ;

\ KEYBOARD HANDLING CODE HERE
: DoCntrl ( Char - Char )
   DUP 60 7B WITHIN \ CAN BE CONTROL
   IF 1F AND THEN ;

: DoCapLk ( CHAR - CHAR ) \ ONLY FOR LETTER
     DUP 61 7B WITHIN \ LOWER CASE LETTER
     IF 5F AND THEN ;

: DoShift ( CHAR - CHAR )
   CapLk @ 0 = IF DoCapLk THEN
   DUP 2C 40 WITHIN \ SPECIAL CASE
   IF 2C - ShfTable + C@ THEN
   DUP 5B 61 WITHIN
   IF 5B - ShftTable2 + C@ THEN
   DUP 27 =
   IF DROP 22 THEN ;

: F0Key ( - ) \ MOSTLY KEY RELEASES SO MOST IGNORED
  GetKey >R
  R@ E0 =
  IF \ ONLY RCNTRL FOR NOW
    GetKey
    DUP LCntrl =
    IF RCntrl NOT RCntrl Cntrl MSK! THEN
    DROP
  ELSE \ not E0
    R@ LShft = R@ RShft = OR
    IF R@ NOT R@ Shift MSK! THEN
    R@ LCntrl =
    IF R@ NOT R@ Cntrl MSK! THEN
    R@ CapKey =
    IF CapLk @ CapKey XOR DUP CapLk !
        IF 4 ELSE 0 THEN Led THEN
  THEN R> DROP ;

: E0Key ( - ) \ ONLY RCntrl
   GetKey DUP F0 =
   IF
     DROP
     GetKey LCntrl = \ actually right Cntrl
     IF RCntrl NOT RCntrl Cntrl MSK! THEN
   ELSE
     LCntrl =
     IF RCntrl DUP Cntrl MSK! THEN
   THEN ;

: C, HERE C! 1 ALLOT ;
CREATE EasterEgg
  31 C, 32 C, 33 C, 34 C, 54 C, 48 C, HERE ALIGNED CP !
VARIABLE Egg

: Par! ( Char - ) \ Output to parallel port
  DUP Egg @ EasterEgg + C@ =
  IF Egg @ 5 =
     IF 0 Egg ! QUIT ELSE 1 Egg +! THEN
  ELSE
     0 Egg !
  THEN
  8 LSHIFT
  Strobe @ 0 = StrobeMsk AND OR
  DUP ParMsk OutB MSK!
  14 FOR 40uS NEXT
  StrobeMsk XOR
  ParMsk OutB MSK! ;

: DoText ( key - )
  2ASCII
  Cntrl @
  IF DoCntrl
  ELSE
   Shift @
   IF
     DoShift
   ELSE
     CapLk @ IF DoCapLk THEN
   THEN
  THEN
  DUP . Par! ;

: DoKey ( - )
  GetKey >R
  R@ F0 =
  IF F0Key
  ELSE
    R@ E0 =
    IF E0Key
    ELSE
      R@ LCntrl = IF R@ DUP Cntrl MSK!
      ELSE
        R@ LShft = R@ RShft = R@ CapKey = OR OR
        IF R@ CapKey = NOT
          IF R@ DUP Shift MSK! THEN
        ELSE R@ DoText THEN THEN THEN
  THEN
  R> DROP ;

: Run
   BEGIN DoKey AGAIN ;

: T 5 5 BEGIN DoKey ?KEY UNTIL GetKey . GetKey . ;

: CLEAR +Clk +Data ;

: Init ( FOR AUTO BOOT INCLUDE KEY PROCESSING )
   ( CHECK DESIRED STROBE ) 0 Strobe !
   ( CHECK STROBE POLARITY )
   Strobe @ -1 XOR StrobeMsk OutB MSK!
   -Clk SetPB +Data
   ParMsk OutB SET!
   0 Shift ! 0 CapLk ! 0 Cntrl !
    0 InFIFO ! 0 OutFIFO !
    0 Egg !
;

Init

: DEBUG
   GetKey . ;

: Q DEBUG DEBUG DEBUG ;


