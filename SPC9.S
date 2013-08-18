/*

 SPC700 opcodes 0x90-0x9F:
    90: BCC rel         2,2/4
    91: TCALL 9         1,8
    92: CLR1 dp.4       2,4
    93: BBC dp.4,rel    3,5/7
    94: ADC A,dp+X      2,4
    95: ADC A,labs+X    3,5
    96: ADC A,labs+Y    3,5
    97: ADC A,(dp)+Y    2,6
    98: ADC dp,#imm     3,5
    99: ADC (X),(Y)     1,5
    9A: SUBW YA,dp      2,5
    9B: DEC dp+X        2,5
    9C: DEC A           1,2
    9D: MOV X,SP        1,2
    9E: DIV YA,X        1,12
    9F: XCN A           1,5

*/

/* 90 */

.balign 16
SPC_BCC:
    SPC_BFC SPC_FLAG_C
    jmp SPC_BACK

/* 91 */

/* TCALL: Call through table in pageable 64-bytes of RAM */
.balign 16
SPC_TCALL_9:
    TCALL 9
    jmp SPC_BACK

/* 92 */
/* SPC_CLR1 in SPCmain.S */

/* 93 */
/* SPC_BBC in SPCmain.S */

/* 94 */

.balign 16
SPC_ADC_A_Odp_XO:
    SPC_ADC_A Odp_XO
    jmp SPC_BACK

/* 95 */

.balign 16
SPC_ADC_A_Oabs_XO:
    SPC_ADC_A OABS_XO
    jmp SPC_BACK

/* 96 */

.balign 16
SPC_ADC_A_Oabs_YO:
    SPC_ADC_A OABS_YO
    jmp SPC_BACK

/* 97 */

.balign 16
SPC_ADC_A_OOdpO_YO:
    SPC_ADC_A OOdpO_YO
    jmp SPC_BACK

/* 98 */

.balign 16
SPC_ADC_dp_IM:
    SPC_ADC_mem dp_IM,1(%esi)
    jmp SPC_BACK

/* 99 */

.balign 16
SPC_ADC_OXO_OYO:
    SPC_ADC_mem OXO_OYO,%al
    jmp SPC_BACK

/* 9A */

.balign 16
SPC_SUBW_YA_dp:
    SPC_ADDR_dp
    CLR_FLAG_SPC(SPC_FLAG_V)    // Done cos STORE_FLAGS cant alter V!
    movl _YA,%edx
    GET_WORD_SPC        // get DP word
    subw %ax,%dx
    cmc
    lahf
    jno 1f
    SET_FLAG_SPC(SPC_FLAG_V)
1:  STORE_FLAGS_SPC_FROM SPC_FLAG_NHZC,%ah
    movl %edx,_YA
    jmp SPC_BACK

/* 9B */

.balign 16
SPC_DEC_Odp_XO:
    SPC_DEC Odp_XO
    jmp SPC_BACK

/* 9C */

.balign 16
SPC_DEC_A:
    movw %bx,_PC
    decb _A
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
    jmp SPC_BACK

/* 9D */

.balign 16
SPC_MOV_X_SP:
    movw %bx,_PC
    movb _SP,%al
    testb %al,%al
    movb %al,_X
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
    jmp SPC_BACK

/* 9E */

.balign 16
SPC_DIV:                // This may not be 100% due to overflow checking!
    movw %bx,_PC
    xorl %ebx,%ebx
    movb _X,%bl
    testb %bl,%bl       // If zero skip divide!
    jz SPC_DIV_OVERFLOW
    movl _YA,%eax       // Dividend
    xorl %edx,%edx
    divw %bx            // Result is ax=quotient,dx=remainder
    testb %ah,%ah       // Check for overflow
    jnz SPC_DIV_OVERFLOW    // (0.33) Butcha - fixed stack corruption
SPC_DIV_NO_OVERFLOW:
    movb %al,_A         // Quotient in A
    movb %dl,_Y         // Remainder in Y
    CLR_FLAG_SPC (SPC_FLAG_V)
    testb %al,%al
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
    jmp SPC_BACK
.balign 16
SPC_DIV_OVERFLOW:
    SET_FLAG_SPC (SPC_FLAG_N+SPC_FLAG_V)
    CLR_FLAG_SPC (SPC_FLAG_Z)
    movl $0xFFFF,_YA
    jmp SPC_BACK

/* 9F */

.balign 16
SPC_XCN:
    movb _A,%al
    rolb $4,%al
    movw %bx,_PC
    testb %al,%al
    movb %al,_A
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
    jmp SPC_BACK
