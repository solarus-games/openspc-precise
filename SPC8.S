/*

 SPC700 opcodes 0x80-0x8F:
    80: SETC            1,2
    81: TCALL 8         1,8
    82: SET1 dp.4       2,4
    83: BBS dp.4,rel    3,5/7
    84: ADC A,dp        2,3
    85: ADC A,labs      3,4
    86: ADC A,(X)       1,3
    87: ADC A,(dp+X)    2,6
    88: ADC A,#imm      2,2
    89: ADC dp(d),dp(s) 3,6
    8A: EOR1 C,mem.bit  3,5
    8B: DEC dp          2,4
    8C: DEC labs        3,5
    8D: MOV Y,#imm      2,2
    8E: POP PSW         1,4
    8F: MOV dp,#imm     3,5

*/

/* 80 */

.balign 16
SPC_SETC:
    movw %bx,_PC
    SET_FLAG_SPC (SPC_FLAG_C)
    jmp SPC_BACK

/* 81 */

/* TCALL: Call through table in pageable 64-bytes of RAM */
.balign 16
SPC_TCALL_8:
    TCALL 8
    jmp SPC_BACK

/* 82 */
/* SPC_SET1 in SPCmain.S */

/* 83 */
/* SPC_BBS in SPCmain.S */

/* 84 */

.balign 16
SPC_ADC_A_dp:
    SPC_ADC_A dp
    jmp SPC_BACK

/* 85 */

.balign 16
SPC_ADC_A_abs:
    SPC_ADC_A ABS
    jmp SPC_BACK

/* 86 */

.balign 16
SPC_ADC_A_OXO:
    SPC_ADC_A OXO
    jmp SPC_BACK

/* 87 */

.balign 16
SPC_ADC_A_OOdp_XOO:
    SPC_ADC_A OOdp_XOO
    jmp SPC_BACK

/* 88 */

.balign 16
SPC_ADC_A_IM:
    movb 1(%esi),%al
    incl %ebx
    CLR_FLAG_SPC(SPC_FLAG_V)    // Done cos STORE_FLAGS cant alter V!
    movw %bx,_PC
    MAKE_CARRY
    adcb %al,_A
    lahf
    jno 1f
    SET_FLAG_SPC(SPC_FLAG_V)
1:  STORE_FLAGS_SPC_FROM SPC_FLAG_NHZC,%ah
    jmp SPC_BACK

/* 89 */

.balign 16
SPC_ADC_dp_dp:
    SPC_ADC_mem dp_dp,%al
    jmp SPC_BACK

/* 8A */

.balign 16
SPC_EOR1:       // Carry flag = Carry flag EOR mem.bit
    SPC_ADDR_membit     // %bx contains mem and %dx contains bit number
    GET_BYTE_SPC        // Get byte at location
    btl %edx,%eax
    jnc SPC_BACK        // C = C EOR 0 -> C = C
    CPL_FLAG_SPC (SPC_FLAG_C)   // C = C EOR 1 -> C = !C
    jmp SPC_BACK

/* 8B */

.balign 16
SPC_DEC_dp:
    SPC_DEC dp
    jmp SPC_BACK

/* 8C */

.balign 16
SPC_DEC_abs:
    SPC_DEC ABS
    jmp SPC_BACK

/* 8D */

.balign 16
SPC_MOV_Y_IM:
    movb 1(%esi),%al
    incl %ebx
    testb %al,%al
    movb %al,_Y
    movw %bx,_PC
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
    jmp SPC_BACK

/* 8E */

.balign 16
SPC_POP_PSW:
    movw %bx,_PC
    POP_B
    RESTOREFLAGS_SPC
    jmp SPC_BACK

/* 8F */

.balign 16
SPC_MOV_dp_IM:
    SPC_ADDR_dp_IM
    movb 1(%esi),%al    // immediate byte in %al
    SET_BYTE_SPC
    jmp SPC_BACK
