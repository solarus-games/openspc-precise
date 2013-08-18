/*

 SPC700 opcodes 0xF0-0xFF:
    F0: BEQ rel         2,2/4
    F1: TCALL 15        1,8
    F2: CLR1 dp.7       2,4
    F3: BBC dp.7,rel    3,5/7
    F4: MOV A,dp+X      2,4
    F5: MOV A,labs+X    3,5
    F6: MOV A,labs+Y    3,5
    F7: MOV A,(dp)+Y    2,6
    F8: MOV X,dp        2,3
    F9: MOV X,dp+Y      2,4
    FA: MOV dp(d),dp(s) 3,5
    FB: MOV Y,dp+X      2,4
    FC: INC Y           1,2
    FD: MOV Y,A         1,2
    FE: DBNZ Y,rel      2,4/6
    FF: STOP            1,3

*/

/* F0 */

.balign 16
SPC_BEQ:
    SPC_BFS SPC_FLAG_Z
    jmp SPC_BACK

/* F1 */

/* TCALL: Call through table in pageable 64-bytes of RAM */
.balign 16
SPC_TCALL_15:
    TCALL 15
    jmp SPC_BACK

/* F2 */
/* SPC_CLR1 in SPCmain.S */

/* F3 */
/* SPC_BBC in SPCmain.S */

/* F4 */

.balign 16
SPC_MOV_A_Odp_XO:
    SPC_MOV_A_ Odp_XO
    jmp SPC_BACK

/* F5 */

.balign 16
SPC_MOV_A_Oabs_XO:
    SPC_MOV_A_ OABS_XO
    jmp SPC_BACK

/* F6 */

.balign 16
SPC_MOV_A_Oabs_YO:
    SPC_MOV_A_ OABS_YO
    jmp SPC_BACK

/* F7 */

.balign 16
SPC_MOV_A_OOdpO_YO:
    SPC_MOV_A_ OOdpO_YO
    jmp SPC_BACK

/* F8 */

.balign 16
SPC_MOV_X_dp:
    SPC_MOV_X_ dp
    jmp SPC_BACK

/* F9 */

.balign 16
SPC_MOV_X_Odp_YO:
    SPC_MOV_X_ Odp_YO
    jmp SPC_BACK

/* FA */

.balign 16
SPC_MOV_dp_dp:
    SPC_ADDR_dp_dp      // %al is (s), %bx d
    SET_BYTE_SPC
    jmp SPC_BACK

/* FB */

.balign 16
SPC_MOV_Y_Odp_XO:
    SPC_MOV_Y_ Odp_XO
    jmp SPC_BACK

/* FC */

.balign 16
SPC_INC_Y:
    movw %bx,_PC
    incb _Y
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
    jmp SPC_BACK

/* FD */

.balign 16
SPC_MOV_Y_A:
    movw %bx,_PC
    movb _A,%al
    testb %al,%al
    movb %al,_Y
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
    jmp SPC_BACK

/* FE */

.balign 16
SPC_DBNZ_Y:
    decb _Y
    jz  9f
    movsbl 1(%esi),%eax // sign extend for addition
    addl $2,%ebp        // Branch taken
    addl %eax,%ebx
//  addl $2,_TotalCycles    // (0.32) Butcha - fix 'lost' SPC timer ticks!
9:  incl %ebx
    movw %bx,_PC
    jmp SPC_BACK

/* FF */

.balign 16
SPC_STOP:
    movw %bx,_PC
    decw _PC
    jmp SPC_BACK        // What else can stop do?
