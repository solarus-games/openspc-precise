/************************************************************************
 *                       EMU.C, from OpenSPC source                     *
 *      Please see documentation for license and authoring information  *
 ************************************************************************/

#include "sound.h"
#include <stdio.h>
#include <stdlib.h>

unsigned char SPC_DSP_Buffer[128];
unsigned long Map_Address,SPC_TIMER0,SPC_TIMER1,SPC_TIMER2,SPCcyc,TotalCycles,
 CycleLatch0,CycleLatch1,CycleLatch2;
unsigned short S_SP,S_PC,S_P;
unsigned char S_A,S_X,S_Y;
unsigned char Map_Byte;
unsigned char SPC_TIMT0,SPC_TIMT1,SPC_TIMT2,SPC_TIM0,SPC_TIM1,SPC_TIM2,
 SPC_CNT0,SPC_CNT1,SPC_CNT2,SPC_CTRL,SPC_MASK,SPC_DSP_ADDR,SPC_DSP_DATA;

extern unsigned char SPCRAM[65536];

//ID tag stuff
int SPCtime;
char SPCname[32],SPCtname[32],SPCdname[16],SPCcomment[32],SPCdate[10];

void LOAD_SPC(void);
void Reset_SPC(void);
void Shutdown(void);

//#define NOENVX

static int LoadZState(char *fn)
{
        FILE *f;
        unsigned char temp;
        int i;
        f=fopen(fn,"rb");
        if(f==NULL)
        {
                printf("Cannot open filename specified!\n");
                exit(1);
        }
        for(i=0;fn[i]!=0;i++);
        for(;i>0;i--)
                if(fn[i]=='.')break;
        if(((fn[i+1]=='S')||(fn[i+1]=='s'))&&((fn[i+2]=='P')||(fn[i+2]=='p')))
        {       //File is an SPC file
                fseek(f,37,SEEK_SET);
                fread(&S_PC,2,1,f);
                S_A=fgetc(f);
                S_X=fgetc(f);
                S_Y=fgetc(f);
                S_P=fgetc(f);
                S_SP=0x100+fgetc(f);
                fread(&i,2,1,f);       //Throw two bytes away
                //Read ID tag stuff
                fread(SPCname,1,32,f);
                fread(SPCtname,1,32,f);
                fread(SPCdname,1,16,f);
                fread(SPCcomment,1,32,f);
                fread(SPCdate,1,10,f);
                fgetc(f);              //Throw a byte away
                i=fgetc(f);
                if(i>='0')
                        SPCtime=(i-'0')*100+(fgetc(f)-'0')*10+fgetc(f)-'0';
                else    SPCtime=0;
                fseek(f,256,SEEK_SET);
                fread(SPCRAM,1,65536,f);
                fread(SPC_DSP_Buffer,1,128,f);
        }
        else
        {       //Assume file is a ZST file
                fseek(f,199699,SEEK_SET);
                fread(SPCRAM,1,65536,f);
                fseek(f,265251,SEEK_SET);
                S_PC=fgetc(f)+(fgetc(f)<<8);
                fgetc(f);fgetc(f);
                S_A=fgetc(f);
                fgetc(f);fgetc(f);fgetc(f);
                S_X=fgetc(f);
                fgetc(f);fgetc(f);fgetc(f);
                S_Y=fgetc(f);
                fgetc(f);fgetc(f);fgetc(f);
                S_P=fgetc(f)+(fgetc(f)<<8);
                fgetc(f);fgetc(f);
                temp=fgetc(f);
                fgetc(f);fgetc(f);fgetc(f);
                S_SP=fgetc(f)+(fgetc(f)<<8);
                fgetc(f);fgetc(f);

                if(temp==0)
                        S_P|=2;
                else    S_P&=253;
                if(temp&0x80)
                        S_P|=0x80;
                else    S_P&=0x7f;
                fseek(f,266623,SEEK_SET);
                fread(SPC_DSP_Buffer,1,128,f);
        }
        fclose(f);

        SPC_CTRL=SPCRAM[0xf1];
        SPC_DSP_ADDR=SPCRAM[0xf2];
        SPC_TIMT0=SPC_TIM0=SPCRAM[0xfa];
        SPC_TIMT1=SPC_TIM1=SPCRAM[0xfb];
        SPC_TIMT2=SPC_TIM2=SPCRAM[0xfc];
        LOAD_SPC();
        return(0);
}

//PUBLIC (non-static) functions

int SPCInit(char *fn)
{
        Reset_SPC();
        if(LoadZState(fn))
        	return 1;
        return 0;
}

void Sort_Count0(){
 int SPC_T0 = SPC_TIMT0;
 if (SPC_T0 == 0) SPC_T0 = 256;

 SPC_TIMER0 += (TotalCycles - CycleLatch0) / 256;
 CycleLatch0 += (TotalCycles - CycleLatch0) & ~0xFF;

 SPC_CNT0 = (SPC_CNT0 + (SPC_TIMER0 / SPC_T0)) & 0xF;
 SPC_TIMER0 %= SPC_T0;
}

void Sort_Count1(){
 int SPC_T1 = SPC_TIMT1;
 if (SPC_T1 == 0) SPC_T1 = 256;

 SPC_TIMER1 += (TotalCycles - CycleLatch1) / 256;
 CycleLatch1 += (TotalCycles - CycleLatch1) & ~0xFF;

 SPC_CNT1 = (SPC_CNT1 + (SPC_TIMER1 / SPC_T1)) & 0xF;
 SPC_TIMER1 %= SPC_T1;
}

void Sort_Count2(){
 int SPC_T2 = SPC_TIMT2;
 if (SPC_T2 == 0) SPC_T2 = 256;

 SPC_TIMER2 += (TotalCycles - CycleLatch2) / 32;
 CycleLatch2 += (TotalCycles - CycleLatch2) & ~0x1F;

 SPC_CNT2 = (SPC_CNT2 + (SPC_TIMER2 / SPC_T2)) & 0xF;
 SPC_TIMER2 %= SPC_T2;
}

void InvalidSPCOpcode(void)
{
 char Message[9];
 int c;

 Shutdown();	//Kill any sound or gfx drivers if loaded

 printf("\nS_PC - 0x%04X   S_SP - 0x%04X",S_PC,S_SP);
 printf("\nS_A  - 0x%02X     NZPBHIVC",(unsigned char) S_A);

 for(c = 0; c < 8; c++) Message[7 - c] = (S_P & (1 << c)) ? '1' : '0';
 Message[8] = 0;
 printf("\nS_X  - 0x%02X     %8s",S_X,Message);
 printf("\nS_Y  - 0x%02X",S_Y);

 printf("\nSPC opcode 0x%02X not currently supported, SORRY!",Map_Byte);
 printf("\nAt Address 0x%04X",(unsigned short) Map_Address);

 exit(-1);
}

void SPC_READ_DSP(void)
{
        if((SPC_DSP_ADDR&0xf)==8)	//ENVX
#ifdef NOENVX
                SPC_DSP_Buffer[SPC_DSP_ADDR]=0;
#else
                SPC_DSP_Buffer[SPC_DSP_ADDR]=SNDDoEnv(SPC_DSP_ADDR>>4)>>24;
#endif
}

void SPC_WRITE_DSP(void)
{
        int i;
        int addr_lo=SPC_DSP_ADDR&0xF, addr_hi=SPC_DSP_ADDR>>4;
       	switch(addr_lo)
        {
                //break just means nothing needs to be done right now
		//Commented cases are unsupported registers
                // These go for individual voices
        	case 0:	//Volume left
        		break;
                case 1:	//Volume right
                      	break;
                case 3: //Pitch hi
                	SPC_DSP_DATA&=0x3F;
                        break;
                case 2: //Pitch lo
                       	break;
                case 4:	//Source number
                       	break;
                case 5: //ADSR1
                        if((SNDkeys&(1<<addr_hi))&&
                         ((SPC_DSP_DATA&0x80)!=(SPC_DSP_Buffer[SPC_DSP_ADDR]&0x80)))
                        {
                                //First of all, in case anything was already
                                //going on, finish it up
                                SNDDoEnv(addr_hi);
                        	if(SPC_DSP_DATA&0x80)
                                {
                                	//switch to ADSR--not sure what to do
                                        i=SPC_DSP_Buffer[(addr_hi<<4)+6];
                                        SNDvoices[addr_hi].envstate=ATTACK;
                                        SNDvoices[addr_hi].ar=SPC_DSP_DATA&0xF;
                                        SNDvoices[addr_hi].dr=SPC_DSP_DATA>>4&7;
                                        SNDvoices[addr_hi].sr=i&0x1f;
                                        SNDvoices[addr_hi].sl=i>>5;
                                }
                                else
                                {
                                	//switch to a GAIN mode
                                        i=SPC_DSP_Buffer[(addr_hi<<4)+7];
                                        if(i&0x80)
                                        {
                                        	SNDvoices[addr_hi].envstate=i>>5;
                                                SNDvoices[addr_hi].gn=i&0x1F;
                                        }
                                        else
                                        {
                                        	SNDvoices[addr_hi].envx=(i&0x7F)<<24;
	                                        SNDvoices[addr_hi].envstate=DIRECT;
                                        }
                                }
                        }
                	break;
                case 6: //ADSR2
                        //Finish up what was going on
                        SNDDoEnv(addr_hi);
                        SNDvoices[addr_hi].sr=SPC_DSP_DATA&0x1f;
                        SNDvoices[addr_hi].sl=SPC_DSP_DATA>>5;
                        break;
                case 7: //GAIN
                        if((SNDkeys&(1<<addr_hi))&&
                         (SPC_DSP_DATA!=SPC_DSP_Buffer[SPC_DSP_ADDR])&&
                         !(SPC_DSP_Buffer[(addr_hi<<4)+5]&0x80))
                        {
                                if(SPC_DSP_DATA&0x80)
                                {
		                        //Finish up what was going on
		                        SNDDoEnv(addr_hi);
                                     	SNDvoices[addr_hi].envstate=SPC_DSP_DATA>>5;
                                        SNDvoices[addr_hi].gn=SPC_DSP_DATA&0x1F;
                                }
                                else
                                {
                                      	SNDvoices[addr_hi].envx=(SPC_DSP_DATA&0x7F)<<24;
                                        SNDvoices[addr_hi].envstate=DIRECT;
                                }
                        }
                       	break;
                // These are general registers
                case 0xc:
                	switch(addr_hi)
                        {
                                case 0: //Left main volume
                                      break;
                                case 1: //Right main volume
                                      break;
//                                case 2: //Left echo volume
//                                	break;
//                                case 3: //Right echo volume
//                                	break;
                                case 4: //Key on
                                        SNDNoteOn(SPC_DSP_DATA);
	                                SPC_DSP_DATA=SNDkeys;
                                	break;
                                case 5: //Key off
	                                SNDNoteOff(SPC_DSP_DATA);
                                        SPC_DSP_DATA=0;
                                	break;
//                                case 6: //Clocks
//                                	break;
//                                case 7: //Can't write to this!
//					break;
                        }
                        break;
                case 0xd:
                	switch(addr_hi)
                        {
//                        	case 0: //Echo feedback
//                                	break;
//                                case 1: //Not a valid register
//                                        break;
//                                case 2: //Modulation
//                                	break;
//                                case 3:	//Noise toggle
//                                	break;
//                                case 4: //Echo toggle
//                                	break;
                                case 5:	//Source directory address
                                	break;
//                                case 6:	//Echo start address
//                                	break;
//                                case 7: //Echo delay
//                                	break;
                        }
//                case 0xf:       //FIR Echo filter
//                		break;

	}
        SPC_DSP_Buffer[SPC_DSP_ADDR]=SPC_DSP_DATA;
}
