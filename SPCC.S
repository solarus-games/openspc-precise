/*

 SPC700 opcodes 0xC0-0xCF:
    C0: DI              1,3
    C1: TCALL 12        1,8
    C2: SET1 dp.6       2,4
    C3: BBS dp.6,rel    3,5/7
    C4: MOV dp,A        2,4
    C5: MOV labs,A      3,5
    C6: MOV (X),A       1,4
    C7: MOV (dp+X),A    2,7
    C8: CMP X,#imm      2,2
    C9: MOV labs,X      3,5
    CA: MOV1 mem.bit,C  3,6
    CB: MOV dp,Y        2,4
    CC: MOV labs,Y      3,5
    CD: MOV X,#imm      2,2
    CE: POP X           1,4
    CF: MUL YA          1,9

*/

/* C0 */

.balign 16
SPC_DI:
    movw %bx,_PC
    CLR_FLAG_SPC(SPC_FLAG_I)
    jmp SPC_BACK

/* C1 */

/* TCALL: Call through table in pageable 64-bytes of RAM */
.balign 16
SPC_TCALL_12:
    TCALL 12
    jmp SPC_BACK

/* C2 */
/* SPC_SET1 in SPCmain.S */

/* C3 */
/* SPC_BBS in SPCmain.S */

/* C4 */

.balign 16
SPC_MOV_dp_A:
    SPC_MOV__A dp
    jmp SPC_BACK

/* C5 */

.balign 16
SPC_MOV_abs_A:
    SPC_MOV__A ABS
    jmp SPC_BACK

/* C6 */

.balign 16
SPC_MOV_OXO_A:
    SPC_MOV__A OXO
    jmp SPC_BACK

/* C7 */

.balign 16
SPC_MOV_OOdp_XOO_A:
    SPC_MOV__A OOdp_XOO
    jmp SPC_BACK

/* C8 */

.balign 16
SPC_CMP_X_IM:
    movb 1(%esi),%al
    incl %ebx
    cmpb %al,_X
    cmc
    movw %bx,_PC
    STORE_FLAGS_SPC (SPC_FLAG_NZC)
    jmp SPC_BACK

/* C9 */

.balign 16
SPC_MOV_abs_X:
    SPC_MOV__X ABS
    jmp SPC_BACK

/* CA */

.balign 16
SPC_MOV1__C:        // mem.bit = Carry flag
    SPC_ADDR_membit     // %bx contains mem and %dx contains bit number
    GET_BYTE_SPC
    TEST_FLAG_SPC (SPC_FLAG_C)
    jz  0f
    btsl %edx,%eax
    SET_BYTE_SPC
    jmp SPC_BACK
.balign 16
0:  btrl %edx,%eax
    SET_BYTE_SPC
    jmp SPC_BACK

/* CB */

.balign 16
SPC_MOV_dp_Y:
    SPC_MOV__Y dp
    jmp SPC_BACK

/* CC */

.balign 16
SPC_MOV_abs_Y:
    SPC_MOV__Y ABS
    jmp SPC_BACK

/* CD */

.balign 16
SPC_MOV_X_IM:
    movb 1(%esi),%al
    incl %ebx
    testb %al,%al
    movb %al,_X
    movw %bx,_PC
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
    jmp SPC_BACK

/* CE */

.balign 16
SPC_POP_X:
    movw %bx,_PC
    POP_B
    movb %al,_X
    jmp SPC_BACK

/* CF */

.balign 16
SPC_MUL:
    movw %bx,_PC
    movb _Y,%al
    mulb _A
    testw %ax,%ax
    movl %eax,_YA
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
    jmp SPC_BACK
