/*
 SNEeSe SPC700 CPU emulation core
 Originally written by Savoury SnaX (Not quite sure if I like AT&T)
 Maintained/rewritten by Charles Bilyue'

 Compile under DJGPP (GNU-AS)
  NOTE - This must have .S (capital) or the # stuff wont be pre-processed!!!

 This file contains:
  SPC700 addressing mode macros

*/

/*
 Immediate (read-only)
  Read 8-bit
    OR  A-08  AND A-28  EOR A-48  CMP A-68  ADC A-88  MOV Y-8D
    SBC A-A8  CMP Y-AD  CMP X-C8  MOV X-CD  MOV A-E8
*/
.macro SPC_ADDR_imm
.endm

/*
 Direct Page
  Read 8-bit
    OR  A-04  AND A-24  CMP X-3E  EOR A-44  CMP A-64  CMP Y-7E  ADC A-84
    SBC A-A4  MOV A-E4  MOV Y-EB  MOV X-F8
  Read 16-bit
    CMP YA-5A ADD YA-7A SUB YA-9A MOV YA-BA
  RMW 8-bit
    ASL-0B  ROL-2B  LSR-4B  ROR-6B  DEC-8B  INC-AB
  RMW 16-bit
    DECW-1A INCW-3A
  Write 8-bit
    MOV A-C4  MOV Y-CB  MOV X-D8
  Write 16-bit
    MOV YA-DA
*/
.macro SPC_ADDR_dp
    incl %ebx
    movw %bx,_PC
    movl SPC_PAGE,%ebx
    movb 1(%esi),%bl    // get dp
.endm

/*
 Direct Page index X
  Read 8-bit
    OR  A-14  AND A-34  EOR A-54  CMP A-74  ADC A-94  SBC A-B4  MOV A-F4
    MOV Y-FB
  RMW 8-bit
    ASL-1B  ROL-3B  LSR-5B  ROR-7B  DEC-9B  INC-BB
  Write 8-bit
    MOV A-D4  MOV Y-DB
*/
.macro SPC_ADDR_Odp_XO
    incl %ebx
    movw %bx,_PC
    movl SPC_PAGE,%ebx
    movb _X,%dl
    movb 1(%esi),%bl    // get dp
    addb %dl,%bl
.endm

/*
 Direct Page index Y
  Read 8-bit
    MOV X-F9
  Write 8-bit
    MOV X-D9
*/
.macro SPC_ADDR_Odp_YO
    incl %ebx
    movw %bx,_PC
    movl SPC_PAGE,%ebx
    movb _Y,%dl
    movb 1(%esi),%bl    // get dp
    addb %dl,%bl
.endm

/*
 Indexed Indirect
  Read 8-bit
    OR  A-07  AND A-27  EOR A-47  CMP A-67  ADC A-87  SBC A-A7  MOV A-E7
  Write 8-bit
    MOV A-C7
*/
.macro SPC_ADDR_OOdp_XOO
    SPC_ADDR_Odp_XO
    GET_WORD_SPC
    movl %eax,%ebx
.endm

/*
 Indirect Indexed
  Read 8-bit
    OR  A-17  AND A-37  EOR A-57  CMP A-77  ADC A-97  SBC A-B7  MOV A-F7
  Write 8-bit
    MOV A-D7
*/
.macro SPC_ADDR_OOdpO_YO
    SPC_ADDR_dp
    GET_WORD_SPC
    xorl %edx,%edx
    movl %eax,%ebx
    movb _Y,%dl
    addw %dx,%bx
.endm

/*
 Direct Page X
  Read 8-bit
    OR  A-06  AND A-26  EOR A-46  CMP A-66  ADC A-86  SBC A-A6  MOV A-E6
  Write 8-bit
    MOV A-C6
*/
.macro SPC_ADDR_OXO
    movl SPC_PAGE,%eax
    movw %bx,_PC
    movb _X,%al
    movl %eax,%ebx
.endm

/*
 Direct Page to Direct Page
  RMW 8-bit
    OR -09  AND-29  EOR-49  CMP-69  ADC-89  SBC-A9  MOV-FA
*/
.macro SPC_ADDR_dp_dp   /* %al contains source byte %bx dest address */
    addl $2,%ebx
    movl SPC_PAGE,%eax
    movw %bx,_PC
    movb 1(%esi),%al    // get src dp
    movl %eax,%ebx
    GET_BYTE_SPC
    movb 2(%esi),%bl    // get dest dp
.endm

/*
 Immediate to Direct Page
  RMW 8-bit
    OR -18  AND-38  EOR-58  CMP-78  MOV-8F  ADC-98  SBC-B8
*/
.macro SPC_ADDR_dp_IM   /* %bx contains dp address, PC +=2 */
    addl $2,%ebx
    movl SPC_PAGE,%eax
    movw %bx,_PC
    movb 2(%esi),%al    // get dp
    movl %eax,%ebx
.endm

/*
 Direct Page Y to Direct Page X
  RMW 8-bit
    OR -19  AND-39  EOR-59  CMP-79  ADC-99  SBC-B9
*/
.macro SPC_ADDR_OXO_OYO /* %al contains (Y) %bx dest address */
    movl SPC_PAGE,%eax
    movw %bx,_PC
    movb _Y,%al
    movl %eax,%ebx
    GET_BYTE_SPC
    movb _X,%bl
.endm

/*
 Direct Page X autoincrement
  Read 8-bit
    MOV A-BF
  Write 8-bit
    MOV A-AF
*/
.macro SPC_ADDR_OXOInc
    movl SPC_PAGE,%eax  // Get Page Variable!
    movw %bx,_PC
    movb _X,%al
    movl %eax,%ebx
    incb _X
.endm

/*
 Absolute
  Read 8-bit
    OR  A-05  CMP X-1E  AND A-25  EOR A-45  CMP Y-5E  CMP A-65  ADC A-85
    SBC A-A5  MOV A-E5  MOV X-E9  MOV Y-EC
  Read 16-bit
    CALL -3F  JMP  -5F
  RMW 8-bit
    ASL  -0C  TSET1-0E  ROL  -2C  LSR  -4C  TCLR1-4E  ROR  -6C  DEC  -8C
    INC  -AC
  Write 8-bit
    MOV A-C5  MOV X-C9  MOV Y-CC
*/
.macro SPC_ADDR_ABS
    addl $2,%ebx
    movb 1(%esi),%al
    movw %bx,_PC
    movb 2(%esi),%ah
    movl %eax,%ebx
.endm

/*
 Absolute index X
  Read 8-bit
    OR  A-15  AND A-35  EOR A-55  CMP A-75  ADC A-95  SBC A-B5  MOV A-F5
  Write 8-bit
    MOV A-D5
*/
.macro SPC_ADDR_OABS_XO
    addl $2,%ebx
    movb _X,%al
    movw %bx,_PC
    movb 1(%esi),%bl
    movb 2(%esi),%bh
    addl %eax,%ebx
    andl $0xFFFF,%ebx
.endm

/*
 Absolute index Y
  Read 8-bit
    OR  A-16  AND A-36  EOR A-56  CMP A-76  ADC A-96  SBC A-B6  MOV A-F6
  Write 8-bit
    MOV A-D6
*/
.macro SPC_ADDR_OABS_YO
    addl $2,%ebx
    movb _Y,%al
    movw %bx,_PC
    movb 1(%esi),%bl
    movb 2(%esi),%bh
    addl %eax,%ebx
    andl $0xFFFF,%ebx
.endm

/*
 mem.bit
  Read 8-bit
    OR1  C -0A  OR1  C/-2A  AND1 C -4A  AND1 C/-6A  EOR1 C -8A
    MOV1 C -AA
  Write 8-bit
    MOV1  C-CA
  RMW 8-bit
    NOT1   -EA
*/
.macro SPC_ADDR_membit  // This is a weird addressing mode!
    addl $2,%ebx
    xorl %edx,%edx
    movw %bx,_PC
    movb 2(%esi),%dl
    movb 1(%esi),%bl
    movb %dl,%bh
    shrl $5,%edx        // Get bit number
    andl $0x1FFF,%ebx   // Get address
.endm
