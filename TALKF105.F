\ Serial communicator with the STM32F1xx series parts.
\ One can use Talk to run the interactive eForth on the STM32.
\ One can return to Win32Forth with the esc key.
\ Source files can be compiled with LoadF105 ( - | Filename )
\ One can upload the entire RAM into a HEX file with LogHex ( - | FileName )
\ and INTHEX ( Addr Count - ) is run on STM32 client.
\ Default serial is 56K odd partity.
\ There is no boot loader transferred. eForth is directly loaded.
\ Code is here to write to Flash from a Hex file. Use STM32 documents
\ to determine which Flash blocks need to be first erased.

\ serial used for stm32f105 boot loader

\ Written by Andrew McKewan in Visual C++
\ Translated to Forth by Tom Zimmer
\ January 3nd, 1997 tjz
\       Updated to include changes from Skip Inskeep, as well as
\       other changes.
\ February 10th, 1997 by Tom Zimmer
\       Updated with a couple of additional changes from Skip Inskeep.

\ A Win32Forth example program that illustrates how to open COM1 for
\ bi-directional communications and then allows a simple terminal
\ program to communicate with whatever is connected at 9600 baud.

\ define the object for the Device Control Block structure

decimal

:Object DCB        <Super Object

Record: AddrOf
        int   DCBlength
        int   BaudRate
        int   BinaryBits                \ a 32bit cell of bit fields
      1 bits  fBinary                   \ define the bit fields
      1 bits  fParity
      1 bits  fOutxCtsFlow
      1 bits  fOutxDsrFlow             \ SDI changed for Rts to Dsr
      2 bits  fDtrControl
      1 bits  fDtrSensitivity
      1 bits  fTXContinueOnXoff
      1 bits  fOutX
      1 bits  fInx
      1 bits  fErrorChar
      1 bits  fNull
      2 bits  fRtsControl
      1 bits  fAbortOnError
     17 bits  fDummy
        short wReserved
        short XonLim
        short XoffLim
        byte  ByteSize
        byte  Parity
        byte  StopBits
        byte  XonChar
        byte  XoffChar
        byte  ErrorChar
        byte  EofChar
        byte  EvtChar
        short wReserved1
;RecordSize: SIZEOFDCB

:M Reset:       ( -- )
                AddrOf SIZEOFDCB erase
                ;M

:M ClassInit:   ( -- )
                ClassInit: super
                Reset: self             \ create structure as Reset
                ;M

;Object

\ define the field names for the Communications Timeout structure

0       CELL Field+ .ReadIntervalTimeout     nostack
        CELL Field+ .ReadTotalTimeoutMultiplier
        CELL Field+ .ReadTotalTimeoutConstant
        CELL Field+ .WriteTotalTimeoutMultiplier
        CELL Field+ .WriteTotalTimeoutConstant
CONSTANT COMMTIMEOUTSBYTES        nostack1


: ComTimeouts   { cHndl \ CT -- }      \ Initialize the communications timeouts
                COMMTIMEOUTSBYTES LocalAlloc: CT    \ allocate a CT structure
                CT COMMTIMEOUTSBYTES erase          \ initialize it to zeros
        \ set read timeouts to magic value of don't wait, just poll
                -1 CT .ReadIntervalTimeout          !
                 0 CT .ReadTotalTimeoutMultiplier   !
                 0 CT .ReadTotalTimeoutConstant     !
                 1 CT .WriteTotalTimeoutMultiplier  !
                20 CT .WriteTotalTimeoutConstant    !
                CT
                cHndl
                Call SetCommTimeouts drop ;

: ComOpen       ( z1 -- cHndl ) \ Open Com port for z" COM1", or z" COM2"
                >R
                NULL                            \ no template
                NULL                            \ open file attributes
                OPEN_EXISTING                   \ creation distribution
                NULL                            \ no security attributes
                0                               \ exclusive access
                GENERIC_READ GENERIC_WRITE or   \ desired access modes
                R>                              \ zstring filename
                Call CreateFile                 \ returns handle or -1
                dup -1 =                        \ if -1 then error
                Abort" Failed to open COM port!"
                ;                               \ -- chndl ;return handle to port

\ ************************************************************
\ here is a list of valid parameters for ComSetup.  Except for
\ the ByteSize parameter, these are all windows constants.

\ --- BuadRate    CBR_110       CBR_300       CBR_600
\                 CBR_1200      CBR_2400      CBR_4800
\                 CBR_9600      CBR_14400     CBR_56000
\                 CBR_19200     CBR_38400     CBR_57600
\                 CBR_115200    CBR_128000    CBR_256000
\
\ --- ByteSize    5, 6, 7, 8
\
\ --- Parity      NOPARITY      ODDPARITY     MARKPARITY
\                 EVENPARITY    SPACEPARITY
\
\ --- StopBits    ONESTOPBIT    TWOSTOPBITS   ONE5STOPBITS
\
\ ************************************************************

\ Setup the Communications state to the parameters specified

: ComSetup      { baud size parity stop cHndl -- }
                DCB.AddrOf
                cHndl
                Call GetCommState ?win-error

                baud       Put: DCB.BaudRate
                size       Put: DCB.ByteSize
                parity 0<> Put: DCB.fParity             \ parity enabled flag
                parity     Put: DCB.Parity
                stop       Put: DCB.StopBits

                DCB.AddrOf
                cHndl
                Call SetCommState ?win-error ;

: ComClose      ( cHndl -- )    \ close com port if its open
                ?dup
                if      Call CloseHandle drop
                then    ;

:Object COMSTAT        <Super Object

Record: AddrOf
        int   lpComStatBits             \ a 32bit cell of bit fields
      1 bits  fCtsHold                  \ define the bit fields Low to High
      1 bits  fDsrHold
      1 bits  fRlsdHold
      1 bits  fXoffHold
      1 bits  fXoffSent
      1 bits  fEof
      1 bits  fTxim
     25 bits  fReserved
        int   cbInQue
        int   cbOutQue
;RecordSize: SIZEOFCOMSTAT

:M Reset:       ( -- )
                AddrOf SIZEOFCOMSTAT erase
                ;M

:M ClassInit:   ( -- )
                ClassInit: super
                Reset: self             \ create structure as Reset
                ;M

;Object

: ComErrorClear { comhndl \ lpErrors -- f }      \ true = success
                COMSTAT.addrof
                lpErrors
                comhndl Call ClearCommError 0<>  ;

\ Example: Simple terminal program

0  value Com1Hndl
variable Com1key-val            \ a place to save last key received
0  value Com1key-flg?           \ have we already got a key?

: Com1key?      ( -- c1 )       \ get a key from serial port, don't wait long
                Com1key-flg? 0=
                if      Com1key-val 1 Com1Hndl read-file        \ -- len flag
                        abort" Failed to read serial port"      \ -- len
                        to Com1key-flg?
                then    Com1key-flg? ;

: Com1key       ( -- c1 )       \ must return a key
                begin   Com1key?                \ loop till we get one
                until
                Com1key-val c@                  \ return the key
                0 to Com1key-flg? ;             \ clear the save buffer

: Com1emit      { char -- }     \ write a character to the serial port
                &OF char 1 Com1Hndl write-file
                abort" Failed to write serial port" ;

0 value ?ComInit

: do-Com1key    ( c1 -- f1 )    \ process keys pressed on user keyboard
                dup k_ESC =                     \ was ESC pressed?
                if      drop                    \ if so, discard c1 and shut down
                        Com1Hndl ComClose       \ close the com port
                    \    0 to Com1Hndl           \ clear handle value
                        0 to ?ComInit
                        ." Done"          TRUE  \ return TRUE, we are terminating
                else    Com1emit          FALSE \ else emit char and continue
                then    ;


: InitCom
   ?ComInit 0= if
     z" COM3" ComOpen to com1Hndl
     Reset: DCB
     False Put: DCB.fOutxCtsFlow  \ no CTS control
\     CBR_9600
     CBR_56000
\ CBR_57600
\ CBR_115200
\ CBR_38400
\     CBR_2400
     8 EVENPARITY twoSTOPBITs com1Hndl ComSetup
     Com1Hndl comTimeOuts
   then -1 to ?ComInit ;


: Com1talk      ( -- )          \ simple terminal talker to the serial port
                cr ." Initializing Serial Port to: "
                cr ." COM1: baud=56000 parity=E data=8 stop=1"
\                z" COM3" ComOpen to com1Hndl
\                    Reset: DCB
\                FALSE Put: DCB.fOutxCtsFlow      \ Don't pay attention to CTS
 \    CBR_9600 8 noPARITY TWOSTOPBIT com1Hndl ComSetup
\
\   CBR_56000 8 EVENPARITY ONESTOPBIT com1Hndl ComSetup
\                com1Hndl ComTimeouts
       InitCom
                cr ." Press ESC to stop talking." cr
                BEGIN   key?
                        if      key do-Com1key ?EXIT
                        then
                        Com1key?
                        if Com1key
                           dup ( $0D = over ) $0A = \ or
                           if
                            drop cr
                           else
                             dup 8 =
                             if
                               drop getxy swap 1- swap gotoxy
                             else
                               emit
                             then
                           then
                        then
                AGAIN ;

: talk com1talk ;

\ *******************************************************
\ boot loader code for F105
\ Following are the words to program the stm32f105
\ It expects to read an Intel Hex file that it will load into
\ the flash on chip. No loader code is needed if you load eForth.
\ refer to STM32 documents for Flash block sizes

$79 value Ack
$1F value Nack
$7F value StartByte
0 value xcs  \ xor sum to send.

: Oops ( restart com connection if error ) Com1Hndl ComClose 0 to ?ComInit ;

0 value quiet

: safekey ( - key ) \ doesn't hang if no key response.
   begin
     key?
     if ." No Response"
        quit
     else
     Com1Key?
       if Com1Key -1 else 0 then
     then
   until ;

: Ack? ( - ) \ look for Ack or Nack
  safekey \ Com1Key
  dup Ack =
  if drop ." Ack" cr
  else dup Nack =
    if drop ." Nack" cr
    else ." ??" h. quit
    then
  then ;

\ F105 is a STM32F105

: cs+ ( byte - )  ( $FF xor ) xcs xor to xcs ;

: StartF105 ( - ) \ tie boot pins and reset then do this
                  \ checks to see if boot is listening
   InitCom
   0 to xcs
   $7F Com1Emit
   begin
     key? if ." No Response" Oops -1 else
     Com1Key?
     if Ack? -1 else 0 then then
   until ;

: ss startf105 ;

: F105! ( Byte - )  \ low level word
   dup Com1Emit cs+ ;

: F105CS! ( - )  \ Sends accumulated Check Sum low level
   xcs ( $ff xor ) Com1Emit
   Ack?
   0 to xcs ; \ clears xcs for next


: F105 ( Command - ) \ Send a command to F105 low level
   dup
   Com1Emit
   $0FF xor Com1Emit
   0 to xcs
   Ack? ;  \ Expects Ack for every CS ( CheckSum )

: GetF105 ( - ) \ report commands checks version see STM docs
   $00 F105
   SafeKey 1+ 0 do \ BootLoader Version plus command bytes
     SafeKey h. cr
   loop
   Ack? ;

: UnProtRd ( - )  \ Allows reading
   $92 F105
   startf105 ;

: ProtRd ( - ) \ blocks reading
   $82 F105
   startf105 ;


create Buf $10005 allot \ up to 64K

$8000000 value Flash

: Addr ( addr - ) \ Send Address of 4 bytes low level
    0 to xcs
    dup $18 rshift F105!    \ MSB first
    dup $10 rshift $0FF and F105!
    dup $08 rshift $0FF and F105!
                   $0FF and F105! \ LSB last
    F105cs! ;

: (RdMem) ( Addr Count - ) \ Reads Flash into Buf
   $11 F105
   swap Addr
    dup 1 - F105 \ F105! F105CS!
    0 do
      SafeKey i Buf + c!
    loop ;

: .RdMem ( Addr Count - ) \ displays Flash
    dup >r
    (RdMem)
    r> 0 do i buf + c@ h. loop ;

: .Inst ( Addr - ) \ Displays the 32 bit value in listing order
        4 (RdMem) Buf 3 + c@ $1000000 *
        Buf 2 + c@ $10000 *
        Buf 1 + c@ $100 *
        Buf c@ + + +
    base @ >r hex u. r> base ! ;


: GV ( - )
    1 F105
    3 0 do
     SafeKey h.
    loop
    Ack? ;

: xxx dup dup
   4 mod dup if 4 swap - then +
   dup 1- .
   over . swap - . ;

: WM ( WrAddr ByteCount - ) \ gets data from Buf
   \ careful count must be less than or equal to 255
   \ I intend to do blocks of 16 so OK
   \ Note: don't used for options.
   $31 F105 \ Write command
   swap Addr \ send the address
   dup \ actual bytes to write
   dup 4 mod dup if 4 swap - then + \ N+1 must be multiples of 4
   dup 1- F105!  \ N to F105
   over 0 do  \ real desired number of bytes
     i Buf + c@ F105!  \ actual values desired
   loop
   swap - 0
   ?do
     $0FF F105! \ Pad with unprogrammed value
   loop  \ could be as many as 4 but always at least 1
   F105CS! ;


: EM ( 1rstPage#...LastPage# #Pages --- )
 \ erase memory 2K pages ( 800H each )
   $43 F105 \ Write command
   dup 1- F105!
   0 ?do
       F105!
     loop
   F105cs! ;

: UnProtWr ( - )
   $73 F105
   startf105 ; \ Write command


0 value HexFile
create FBuf $200 allot \ Big enough for Intel hex line.
\ Hex file 17 bytes for first line to say 32 bit values
\ 16 bytes will be 45 bytes of hex
\ 1&2 bytes on line
\ 3,4,5&6 address
\ 7&8 byte type ( should be 0 )
\ data at 2d hex
\ data starts at 9
\ bytes on line 2* then checksum 0d 0a
hex

: OpenHex ( - | FileName )
   s" eforth.hex" r/o open-file abort" Can find file"
   to HexFile ;

: ConvHex ( Addr - Byte )
    dup 1+
    2 0 do
     c@ dup $30 $3A within
     if $30 -
     else dup $41 $47 within
       if $37 -
       else ." Not number" quit
       then
     then
     swap
    loop swap $10 * + ;

: GetCount ( - cnt ) \ reads counts from hex string at fbuf
   FBuf 1+ ConvHex ;

0 value Cnt
0 value rd2

: ReadLine ( --- )
   begin
     FBuf 1 HexFile read-file abort" can't read file1" drop
     FBuf c@ $3A =
   until
   FBuf 1+ 2 HexFile read-file abort" can't read file2" drop
   GetCount to cnt
   FBuf 3 + cnt 2* $0A + dup to rd2 HexFile read-file
   abort" can't read file3" drop
   ;

: closeHex HexFile close-file drop ;

: GetType ( - Type )
   FBuf $7 + ConvHex ;

: GetDestAddr ( - Addr ) \ Gets the destination address from hex string in FBuf
   FBuf 3 +
    0  \ acumulator
    2 0 do \ 4 bytes as address
      $100 * over ConvHex +
      swap 2 + swap
    loop swap drop ;

: F>Buf ( Cnt - )
  FBuf $9 + swap
  0 do
    dup ConvHex i Buf + c!
    2 +
  loop drop ;

: download ( - )
   hex
   OpenHex
   ReadLine \ flush first line set high address so ignore
   -1 to quiet
   $8000000
   begin
    dup $0FF and 0= if dup h. cr then
    ReadLine
    GetType 0=
   while
     cnt F>Buf dup
    Cnt WM
 \   Cnt 0 do i buf + c@ . loop cr drop
    Cnt +
   repeat h.
   0 to quiet
   CloseHex ;

: Verifyload ( - )
   OpenHex
   ReadLine \ flush first line
   -1 to quiet
   $8000000
   begin
    dup $0FF and 0= if dup h. cr then
    ReadLine
    GetType 0=
   while
    cnt F>Buf buf dup cnt + cnt cmove
    dup
    cnt (rdmem)
    cnt 0 do i buf + dup cnt +
       c@ swap c@ - if ." error" h. quit then
       loop
    cnt +
   repeat h.
   0 to quiet
   CloseHex ;


create BBuf $4000 allot  \ space for a binary

0 value BAddr

: GetBinData
  OpenHex
  ReadLine \ ignore first line
 begin
  ReadLine GetType 0=
 while
  GetDestAddr to BAddr
  GetCount 0 \ two chars per byte
  ?do
   i 2* 9 + FBuf + ConvHex \ get a byte, two hex chars
   BAddr i + BBuf + c!
  loop
 repeat
 CloseHex ;

: I@ ( Addr - )
  base @ swap hex
  3 + BBuf + dup c@ $1000000 * swap
  1- dup c@ $10000 * swap
  1- dup c@ $100 * swap
  1- c@ + + + u.
  base ! ;



\ reset board
\ startf105
\ unprotwr
\ reset board
\ 0 1 2 3 4 5 6 7 8 9 em  erase flash
\ unprotrd
\ reset board
\ .rdmem
\ unprotwr
\



\ *******************************************
\ cross loader to F105 Forth
\ file words for loading to the F105
\ LoadF105 is used to send a eForth source file to chips like
\ STM32F105 and STM32F103, that have eForth on them.
\ for blue pill
\  black ground
\  white +5v
\  yellow A10
\  green A9
0 value F105.4th  \ handle for file
\ I'll reuse FBuf as I've expansed it to 512 bytes
0 value FBufZ ( how much is in the buffer )
FBuf value FBufPntr
FBuf value FbufEnd

: OpenF105 ( - | fileName )
 \ open a source file to load into the F105
   bl word count
   r/o open-file abort" Can find file"
   to F105.4th
   0 to FBufZ
   FBuf to FBufPntr ;

: CloseF105
  0 to FbufZ
  F105.4th close-file drop
  Com1Hndl ComClose       \ close the com port
  0 to ?ComInit ;

: RD2Buf ( - ) \ Reads up to 512 bytes into buffer
   FBuf $200 F105.4th read-file
   dup if Closef105 then
   abort" Can't Read File "
   to FBufZ
   FBuf to FBufPntr
   FBufZ Fbuf + TO FbufEnd ;

: FByte ( - Char ) \ fetches a byte from the file
  \ Quits when file complete
  FBufZ 0=
  FbufEnd FbufPntr = or
  if \ either there is nothing in the file or we need to load again
    Rd2Buf
    FBufZ 0=
    if \ end of file
      CloseF105 quit
    then
  then
  FBufPntr c@
  1 +TO FBufPntr ;

: Delay ( - ) \ Don't know if I'll need delay yet
   ;

0 value LastByte

: Echo? ( - Char ) \ Echo from board
   Begin
     Com1Key?
     Key? if CloseF105 quit then \ don't get stuck
   until
   Com1Key ;

CREATE LineBuf $100 allot
0 value LineCnt

: \\ ( Char - Char' )
\ looks to see if Char is a \. If so, it dump the rest of the line
\ to the $0D Char and then pick up sending so we don't wait time
\ with long comments that the F105Forth just ignores
 dup $5C =
 if \ was a \ so move to the end of line
   begin
     drop
     Fbyte dup $0D
   until
 then
;

: LoadF105  ( - | FileName )
   0 to LineCnt
   InitCom
   OpenF105  \ Source file to F105
   begin
     FByte
     \ \\  \ ignore these comments to end of line
     dup Com1Emit  \ send bytes out to board
 \    dup to LastByte \ for debug, don't need
     $0D =
     if
       FByte $0A - if ." CrLf mismatch" quit then
       begin
         Echo? dup $0A - \ Wait for $0D to handle cr to terminal
       while
          LineBuf LineCnt + c!
          1 +to LineCnt
\         emit \ might be 'ok' or warning or error so just echo
         Delay \ may need a delay here
        repeat drop
        LineCnt 0 ?do LineBuf I + c@ emit loop
        0 to lineCnt
        cr
      else
         Echo? LineBuf LineCnt + c! \ normal Char handling
         1 +to LineCnt
      then
   again TALK ;

: XEmit
   dup $0A = if drop cr else emit then ;

\ *************************************************************
\ logging an intel hex file sent from outside chip, like stm32f105
\ Use INTHEX ( Addr Count - ) to send out HEX. It uses handshake.
0 value Pntr
\ 0 value LineCnt
0 VALUE TEST
LINEBUF $100 + TO TEST

HEX
: WW 10000 0 DO 4 5 / DROP LOOP ;
: WWW 100 0 DO WW LOOP ;


: LogHex ( - | FileName )
   bl word count                  \ hex file
   r/w create-file abort" Can create file"
   to HexFile
   InitCom
   0 to LineCnt
   begin \ Entire file
     LineBuf to Pntr                \ To store a line
     BEGIN
       WWW  \ SEEM TO NEED SOME DELAY?????????
       $20 COM1EMIT \ $20 COM1EMIT
       COM1KEY?
     UNTIL
     begin                          \ ignore anything but a : as beginning of hex line
       Com1Key ascii : =
     until
     ascii : Pntr c!                                \ same to file
     begin \ hex line
       1 +to Pntr
       PNTR TEST > IF ." TOO LONG " ABORT THEN
       Com1Key dup Pntr c!
       $0A =                                        \ wait for end of line
     until   \ .S CR
     LineBuf Pntr over - 1 +  2dup ( addr size )
     TYPE \   good to watch the prgress
     HexFile write-file abort" Can't Write"      \ write line to file
     LineBuf 1+ dup c@ $30 = swap 1+ c@ $30 = and   \ 0 length hex line is last line
   until
   CloseHex
   $1B do-Com1key drop ;                     \ All Done



\S

: NL  ( - | FileName ) \ not working yet
   0 to LineCnt
   InitCom
   OpenF105  \ Source file to F105
   begin
     begin
       FByte dup LineBuf LineCnt + c!
       dup XEmit
       LineCnt 1+ $0FF min to LineCnt
       $0A =
     until
     LineCnt to LastByte
     -2 +to LineCnt
     LineBuf LineCnt Com1Hndl write-file
                  abort" Failed to write serial port"
     begin
        Com1Key?
        if
          Com1Key dup
          $0A -
          if
            cr
          then
        else 0
        then
        $0A -
     while
        LineCnt LastByte -
        if
          1 +to LineCnt
          LineBuf LineCnt Com1Emit
        then
     repeat





     $0D ComEmit
     Begin

     while
         com1key?
         if com1key XEmit drop ms@ then
     repeat drop
   again ;

\S
need to speed things up. Not sure what is taking so much time.
need to handle reDef needs to pause and ask to continue?
a name with ? is most likely an error. ask to continue


52 F8  4 FB
: ++ 14 0 do + loop . ;
10 22 B0 00 04 43 4F 4C 44 00 00 00 45 F6 00 73 C2 F2 00 03 93 ++
10 22 B0 00 04 43 4F 4C 44 00 00 00 4F F6 00 73 C2 F2 00 03 89 ++

168 reduce the size transferred was 8000 to 4000 for now **
178 not sure it math right here? 5000 is end of RAM for F103
equates  data stack 2000FE00 should be 20004E00 for F103
       TIB was 2000FE00 should be 20004E00
       RP0 was 2000FF00 should be 20004F00
       UP0 was 2000FF00 should be 20004F00
       HERE was 2000FC00 ?? should be end of dictionary
1D0   was 2000FE00 should be 20004E00
check values at 1D4 t0 1F4
check USART1 map for F103?


10 01 D0 00 00 4E 00 20 51 17 00 20 00 00 00 00 00 23 00 20 E6 ++

create buf1 $2400 allot
create buf2 $2400 allot

: upload ( NewBuf - )
  >r $8000000
  begin
    dup $10 (rdmem)
    Buf over $8000000 - r@ + $10 cmove
    $10 + dup $8002300 =
  until r> 2drop ;

: CompBufs
    $2300 0 do
      I Buf1 + c@
      I Buf2 + c@ -
      if
        I . I Buf1 + c@ . I Buf2 + c@ . key $1B = if quit then
      then
    loop ;


