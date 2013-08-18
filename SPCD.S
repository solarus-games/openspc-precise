/*

 SPC700 opcodes 0xD0-0xDF:
    D0: BNE rel         2,2/4
    D1: TCALL 13        1,8
    D2: CLR1 dp.6       2,4
    D3: BBC dp.6,rel    3,5/7
    D4: MOV dp+X,A      2,5
    D5: MOV labs+X,A    3,6
    D6: MOV labs+Y,A    3,6
    D7: MOV (dp)+Y,A    2,7
    D8: MOV dp,X        2,4
    D9: MOV dp+Y,X      2,5
    DA: MOVW dp,YA      2,4
    DB: MOV dp+X,Y      2,5
    DC: DEC Y           1,2
    DD: MOV A,Y         1,2
    DE: CBNE dp+X,rel   3,6/8
    DF: DAA A           1,3

*/

/* D0 */

.balign 16
SPC_BNE:
    SPC_BFC SPC_FLAG_Z
    jmp SPC_BACK

/* D1 */

/* TCALL: Call through table in pageable 64-bytes of RAM */
.balign 16
SPC_TCALL_13:
    TCALL 13
    jmp SPC_BACK

/* D2 */
/* SPC_CLR1 in SPCmain.S */

/* D3 */
/* SPC_BBC in SPCmain.S */

/* D4 */

.balign 16
SPC_MOV_Odp_XO_A:
    SPC_MOV__A Odp_XO
    jmp SPC_BACK

/* D5 */

.balign 16
SPC_MOV_Oabs_XO_A:
    SPC_MOV__A OABS_XO
    jmp SPC_BACK

/* D6 */

.balign 16
SPC_MOV_Oabs_YO_A:
    SPC_MOV__A OABS_YO
    jmp SPC_BACK

/* D7 */

.balign 16
SPC_MOV_OOdpO_YO_A:
    SPC_MOV__A OOdpO_YO
    jmp SPC_BACK

/* D8 */

.balign 16
SPC_MOV_dp_X:
    SPC_MOV__X dp
    jmp SPC_BACK

/* D9 */

.balign 16
SPC_MOV_Odp_YO_X:
    SPC_MOV__X Odp_YO
    jmp SPC_BACK

/* DA */

.balign 16
SPC_MOV_dp_YA:
    SPC_ADDR_dp
    movl _YA,%eax
    SET_WORD_SPC
    jmp SPC_BACK

/* DB */

.balign 16
SPC_MOV_Odp_XO_Y:
    SPC_MOV__Y Odp_XO
    jmp SPC_BACK

/* DC */

.balign 16
SPC_DEC_Y:
    movw %bx,_PC
    decb _Y
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
    jmp SPC_BACK

/* DD */

.balign 16
SPC_MOV_A_Y:
    movw %bx,_PC
    movb _Y,%al
    testb %al,%al
    movb %al,_A
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
    jmp SPC_BACK

/* DE */

.balign 16
SPC_CBNE_Odp_XO:
    pushl %ebx
    movl SPC_PAGE,%ebx
    movb _X,%dl
    movb 1(%esi),%bl    // get dp
    addb %dl,%bl

    GET_BYTE_SPC        // Get (dp)
    cmpb %al,_A
    popl %ebx
    je  9f
    movsbl 2(%esi),%eax // sign extend for addition
    addl $2,%ebp        // Branch taken
    addl %eax,%ebx
//  addl $2,_TotalCycles
9:  addl $2,%ebx
    movw %bx,_PC
    jmp SPC_BACK

/* DF */

/* DAA - not yet implemented */
