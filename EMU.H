#ifndef MAIN_H
#define MAIN_H

#include <stdio.h>
#include "sound.h"

extern unsigned char SPC_DSP_Buffer[128];
extern unsigned char SPCRAM[65536];
extern unsigned long SPCcyc,TotalCycles,CycleLatch0,CycleLatch1,CycleLatch2,
 SPC_TIMER0,SPC_TIMER1,SPC_TIMER2;
extern unsigned char SPC_CTRL,SPC_TIMT0,SPC_TIMT1,SPC_TIMT2;

extern int SPCtime;
extern char SPCname[32],SPCtname[32],SPCdname[16],SPCcomment[32],SPCdate[10];

int SPCInit(char *);

#endif
