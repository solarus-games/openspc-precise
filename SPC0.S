/*

 SPC700 opcodes 0x00-0x0F:
    00: NOP             1,2
    01: TCALL 0         1,8
    02: SET1 dp.0       2,4
    03: BBS dp.0,rel    3,5/7
    04: OR  A,dp        2,3
    05: OR  A,labs      3,4
    06: OR  A,(X)       1,3
    07: OR  A,(dp+X)    2,6
    08: OR  A,#imm      2,2
    09: OR  dp(d),dp(s) 3,6
    0A: OR1 C,mem.bit   3,5
    0B: ASL dp          2,4
    0C: ASL labs        3,5
    0D: PUSH PSW        1,4
    0E: TSET1 labs      3,6
    0F: BRK             1,8

*/

/* 00 */

.balign 16
SPC_NOP:
    movw %bx,_PC
    jmp SPC_BACK

/* 01 */

/* TCALL: Call through table in pageable 64-bytes of RAM */
.balign 16
SPC_TCALL_0:
    TCALL 0
    jmp SPC_BACK

/* 02 */
/* SPC_SET1 in SPCmain.S */

/* 03 */
/* SPC_BBS in SPCmain.S */

/* 04 */

.balign 16
SPC_OR_A_dp:
    SPC_OR_A dp
    jmp SPC_BACK

/* 05 */

.balign 16
SPC_OR_A_abs:
    SPC_OR_A ABS
    jmp SPC_BACK

/* 06 */

.balign 16
SPC_OR_A_OXO:
    SPC_OR_A OXO
    jmp SPC_BACK

/* 07 */

.balign 16
SPC_OR_A_OOdp_XOO:
    SPC_OR_A OOdp_XOO
    jmp SPC_BACK

/* 08 */

.balign 16
SPC_OR_A_IM:
    movb 1(%esi),%al
    incl %ebx
    orb %al,_A
    movw %bx,_PC
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
    jmp SPC_BACK

/* 09 */

.balign 16
SPC_OR_dp_dp:
    SPC_ADDR_dp_dp      // %dl is source byte, %bx dest address
    movb %al,%dl        // source byte in %dl
    GET_BYTE_SPC        // %al contains byte at dest address
    orb %dl,%al
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
    SET_BYTE_SPC
    jmp SPC_BACK

/* 0A */

.balign 16
SPC_OR1:        // Carry flag = Carry flag OR mem.bit
    SPC_ADDR_membit     // %bx contains mem and %dx contains bit number
    GET_BYTE_SPC        // Get byte at location
    btl %edx,%eax
    jnc SPC_BACK        // C | 0 = C
    SET_FLAG_SPC (SPC_FLAG_C)   // C | 1 = 1
    jmp SPC_BACK

/* 0B */

.balign 16
SPC_ASL_dp:
    SPC_ASL dp
    jmp SPC_BACK

/* 0C */

.balign 16
SPC_ASL_abs:
    SPC_ASL ABS
    jmp SPC_BACK

/* 0D */

.balign 16
SPC_PUSH_PSW:
    movw %bx,_PC
    SETUPFLAGS_SPC
    PUSH_B
    jmp SPC_BACK

/* 0E */

.balign 16
SPC_TSET1:          // I have done this as TSB (65816) including the flag setting based on AND
    SPC_ADDR_ABS
    GET_BYTE_SPC    // Get byte
    movb _A,%dl
    testb %al,%dl   // NZ set for: mem & A
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
    orb %dl,%al
    SET_BYTE_SPC    // mem |= A
    jmp SPC_BACK

/* 0F */

/* BRK - Not yet implemented (maybe never) */
