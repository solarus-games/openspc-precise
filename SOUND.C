/************************************************************************
 *                     SOUND.C, from OpenSPC source                     *
 *    Please see documentation for license and authoring information    *
 ************************************************************************/

#include "emu.h"
#include "sound.h"
#include "it.h"

#include <math.h>
#include <stdlib.h>
#include <stdbool.h>


sndsamp *SNDsamples[100];
sndvoice SNDvoices[8];
void *SNDoptbuf;
double SNDurate;
int SNDfreq,SNDkeys,SNDvmask,SNDmixlen,SNDrvs;
int SNDlevl,SNDlevr;
int SNDratecnt;
int SNDmix;	//Do or do not mix?
unsigned char SNDbits;

static int ABS[65536];                 //zero at 32768
static const unsigned int C[0x20]={0x0,0x20000,0x18000,0x14000,0x10000,0xC000,
 0xA000,0x8000,0x6000,0x5000,0x4000,0x3000,0x2800,0x2000,0x1800,0x1400,0x1000,
 0xC00,0xA00,0x800,0x600,0x500,0x400,0x300,0x280,0x200,0x180,0x140,0x100,0xC0,
 0x80,0x40};	//How many cycles till adjust ADSR/GAIN
static void *CLIP, *tmpbuf;

//From SPC.S:
void SPC_RUN(void);

//PRIVATE (static) functions:

static sndsamp *NewSamp(int size)
{
	sndsamp *s;
	if(((s=malloc(sizeof(sndsamp)))==NULL)||
         ((s->buf=malloc(size*2))==NULL))
        	return(NULL);
        s->length=size;
        s->loopto=-1;
        s->freq=0;
        return(s);
}

static int decode_samp(unsigned short start, sndsamp **sp)
{
        sndsamp *s;
        unsigned char *src;
	unsigned short end;
	unsigned long brrptr,sampptr=0;
	int i;
	int output;
	unsigned char range,filter;
        src=&SPCRAM[start];
	for(end=0;!(src[end]&1);end+=9);
	i=(end+9)/9*16;
        *sp=s=NewSamp(i);
        if(s==NULL)
        	return 1;
        if(src[end]&2)
        	s->loopto=0;
	for(brrptr=0;brrptr<=end;)
	{
		range=src[brrptr++];
		filter=(range&12)>>2;
		range>>=4;
		for(i=0;i<8;i++,brrptr++)
		{
			output=(src[brrptr]>>4)&0x0F;
			if(output>7)
				output|=0xFFFFFFF0;
			output<<=range;
			if(filter==1)
				output+=(int)((double)s->buf[sampptr-1]/16*15);
			else if(filter==2)
				output+=(int)(((double)s->buf[sampptr-1]*61/32)-((double)s->buf[sampptr-2]*15/16));
			else if(filter==3)
				output+=(int)(((double)s->buf[sampptr-1]*115/64)-((double)s->buf[sampptr-2]*13/16));
                        if(output>32767)
                        	output=32767;
                        else if(output<-32768)
                        	output=-32768;
		        s->buf[sampptr++]=output;
			output=src[brrptr]&0x0F;
			if(output>7)
				output|=0xFFFFFFF0;
			output<<=range;
			if(filter==1)
				output+=(int)((double)s->buf[sampptr-1]/16*15);
			else if(filter==2)
				output+=(int)(((double)s->buf[sampptr-1]*61/32)-((double)s->buf[sampptr-2]*15/16));
			else if(filter==3)
				output+=(int)(((double)s->buf[sampptr-1]*115/64)-((double)s->buf[sampptr-2]*13/16));
                        if(output>32767)
                        	output=32767;
                        else if(output<-32768)
                        	output=-32768;
			s->buf[sampptr++]=output;
		}
	}
	return 0;
}

void update_samples(int s)
{
	int i;
	struct {unsigned short vptr,lptr;}*SRCDIR;
	i=SPC_DSP_Buffer[0x5D]<<8;
	SRCDIR=(void *)&SPCRAM[i];
	if(decode_samp(SRCDIR[s].vptr,&SNDsamples[s]))
		return;
	if(SNDsamples[s]->loopto!=-1)
	{
		SNDsamples[s]->loopto=(SRCDIR[s].lptr-SRCDIR[s].vptr)/9*16;
                if((SNDsamples[s]->loopto>SNDsamples[s]->length)||(SNDsamples[s]->loopto<0))
                	SNDsamples[s]->loopto=-1;
        }
}

//PUBLIC (non-static) functions:

void SNDKillSamp(sndsamp *s)
{
	free(s->buf);
        free(s);
}

int SNDPitchToNote(int pitch, int base)
{
	double tmp;
        int note;
	tmp=log2((double)pitch/(double)base)*12+60;
        if(tmp>127)
           	tmp=127;
        else if(tmp<0)
           	tmp=0;
        note=(int)tmp;
        if((int)(tmp*2)!=(note<<1))
	       	note++;//correct rounding
        return note;
}

int SNDDoEnv(int voice)
{
        unsigned int envx,cyc,c;
	envx=SNDvoices[voice].envx;
        for(;;)
        {
	        cyc=TotalCycles-SNDvoices[voice].envcyc;
	        switch (SNDvoices[voice].envstate)
	        {
	        case ATTACK:
	                c=C[(SNDvoices[voice].ar<<1)+1];
                        if(c==0)
                        {
                                SNDvoices[voice].envcyc=TotalCycles;
                        	return SNDvoices[voice].envx=envx;
                        }
                        if(cyc>c)
                        {
				SNDvoices[voice].envcyc+=c;
                                envx+=0x2000000;	//add 1/64th
                                if(envx>=0x7F000000)
                                {
                                	envx=0x7F000000;
                                        if(SNDvoices[voice].sl!=7)
                                        	SNDvoices[voice].envstate=DECAY;
                                        else	SNDvoices[voice].envstate=SUSTAIN;
                                }
			}
                        else return SNDvoices[voice].envx=envx;
	        break;
	        case DECAY:
                        c=C[(SNDvoices[voice].dr<<1)+0x10];
                        if(c==0)
                        {
                                SNDvoices[voice].envcyc=TotalCycles;
                        	return SNDvoices[voice].envx=envx;
                        }
                        if(cyc>c)
                        {
				SNDvoices[voice].envcyc+=c;
	                        envx=(envx>>8)*255;	//mult by 1-1/256
		                if(envx<=0x10000000*(SNDvoices[voice].sl+1))
		                {
		                 	envx=0x10000000*(SNDvoices[voice].sl+1);
		                        SNDvoices[voice].envstate=SUSTAIN;
		                }
	                }
                        else return SNDvoices[voice].envx=envx;
	        break;
	        case SUSTAIN:
	                c=C[SNDvoices[voice].sr];
                        if(c==0)
                        {
                                SNDvoices[voice].envcyc=TotalCycles;
                        	return SNDvoices[voice].envx=envx;
                        }
                        if(cyc>c)
	                {
				SNDvoices[voice].envcyc+=c;
	                        envx=(envx>>8)*255;	//mult by 1-1/256
	                }
                        else return SNDvoices[voice].envx=envx;
	        break;
	        case RELEASE:
	                //says add 1/256??  That won't release, must be subtract.
	                //But how often?  Oh well, who cares, I'll just
	                //pick a number. :)
	                c=C[0x1A];
                        if(c==0)
                        {
                                SNDvoices[voice].envcyc=TotalCycles;
                        	return SNDvoices[voice].envx=envx;
                        }
                        if(cyc>c)
	                {
				SNDvoices[voice].envcyc+=c;
	                        envx-=0x800000;		//sub 1/256th
		                if((envx==0)||(envx>0x7F000000))
		                {
		                        SNDkeys&=~(1<<voice);
		                   	return SNDvoices[voice].envx=0;
		                }
	                }
                        else return SNDvoices[voice].envx=envx;
	        break;
	        case INCREASE:
	                c=C[SNDvoices[voice].gn];
                        if(c==0)
                        {
                                SNDvoices[voice].envcyc=TotalCycles;
                        	return SNDvoices[voice].envx=envx;
                        }
                        if(cyc>c)
	                {
				SNDvoices[voice].envcyc+=c;
	                        envx+=0x2000000;	//add 1/64th
		                if(envx>0x7F000000)
		                {
                                        SNDvoices[voice].envcyc=TotalCycles;
	                        	return SNDvoices[voice].envx=0x7F000000;
                                }
	                }
                        else return SNDvoices[voice].envx=envx;
	        break;
	        case DECREASE:
	                c=C[SNDvoices[voice].gn];
                        if(c==0)
                        {
                                SNDvoices[voice].envcyc=TotalCycles;
                        	return SNDvoices[voice].envx=envx;
                        }
                        if(cyc>c)
	                {
				SNDvoices[voice].envcyc+=c;
	                        envx-=0x2000000;	//sub 1/64th
		                if(envx>0x7F000000) 	//underflow
		                {
                                        SNDvoices[voice].envcyc=TotalCycles;
	                        	return SNDvoices[voice].envx=0;
                                }
	                }
                        else return SNDvoices[voice].envx=envx;
	        break;
	        case EXP:
	                c=C[SNDvoices[voice].gn];
                        if(c==0)
                        {
                                SNDvoices[voice].envcyc=TotalCycles;
                        	return SNDvoices[voice].envx=envx;
                        }
                        if(cyc>c)
	                {
				SNDvoices[voice].envcyc+=c;
	                        envx=(envx>>8)*255;	//mult by 1-1/256
	                }
                        else return SNDvoices[voice].envx=envx;
	        break;
	        case BENT:
			c=C[SNDvoices[voice].gn];
                        if(c==0)
                        {
                                SNDvoices[voice].envcyc=TotalCycles;
                        	return SNDvoices[voice].envx=envx;
                        }
                        if(cyc>c)
	                {
				SNDvoices[voice].envcyc+=c;
				if(envx<0x60000000)
			                envx+=0x2000000;//add 1/64th
		                else
			                envx+=0x800000;	//add 1/256th
		                if(envx>0x7F000000)
	                        {
                                        SNDvoices[voice].envcyc=TotalCycles;
	                        	return SNDvoices[voice].envx=0x7F000000;
	                        }
	                }
                        else return SNDvoices[voice].envx=envx;
                break;
                case DIRECT:
                	SNDvoices[voice].envcyc=TotalCycles;
                        return envx;
	        }
	}
}

//static int ssmp,voice,ltotal,rtotal;
//static short *sbuf;
//static long ratio,len,loop,sptr;

/*
   These could be optimized by calculating how much to mix *FIRST* by a
   simple algorithm like so :

   mixLeft = SNDmixlen;

   while ( mixLeft )
    {
     mixNow = len - sptr / ratio;
     if ( mixNow > mixLeft ) mixNow = mixLeft;
     mixLeft -= mixNow;
     mix ( mixNow );
    }
*/

static void SNDMixZeroVolume(int voice,int pitch)
{
        int i,sptr,ratio,len,loop;
        ratio=(pitch<<14)/SNDfreq;
        sptr=SNDvoices[voice].sampptr;
        len=SNDvoices[voice].cursamp->length<<14;
        loop=SNDvoices[voice].cursamp->loopto<<14;

        for(i=SNDmixlen;i;i--)
        {
                sptr+=ratio;
                if(sptr>=len)
                {
                	if(loop<0)	//Doesn't loop
                        {
                                i=1;	//Stop mixing
                                SNDkeys&=~(1<<voice);
                                SNDvoices[voice].envx=0;
                        }
                        else    //Preserve any left over
                        {       //to avoid looping artifacts
                                sptr-=len;
                                sptr+=loop;
                        }
                }
        }

     	SNDvoices[voice].sampptr=sptr;
}

static void SNDMixMono(int voice,int lvol,int rvol,int pitch)
{
	int i,temp,vol,ssmp,sptr,optr,ratio,len,loop,total=0;
        short *sbuf;
	if(lvol<0)
                lvol=-lvol;
        if(rvol<0)
                rvol=-rvol;
        vol=(rvol+lvol)>>1;
        ratio=(pitch<<14)/SNDfreq;
        sbuf=SNDvoices[voice].cursamp->buf;
        sptr=SNDvoices[voice].sampptr;
        len=SNDvoices[voice].cursamp->length<<14;
        loop=SNDvoices[voice].cursamp->loopto<<14;

        for(i=SNDmixlen,optr=0;i;i--)
        {
	        ssmp=sbuf[sptr>>14];
                temp=(ssmp*vol)>>6;
                total+=ABS[temp+32768];
                ((int *)tmpbuf)[optr]+=temp;
                optr++;
                sptr+=ratio;
                if(sptr>=len)
	        {
	               	if(loop<0)
	                {
                                i=1;	//Stop mixing
	                       	SNDkeys&=~(1<<voice);
                                SNDvoices[voice].envx=0;
	                }
	                else    //Preserve any left over
	                {       //to avoid looping artifacts
                                sptr-=len;
                                sptr+=loop;
	                }
	        }
	}

        total/=SNDmixlen;
        SNDlevl+=total;
        SNDlevr+=total;
	SNDvoices[voice].ave=total;
     	SNDvoices[voice].sampptr=sptr;
}

static void SNDMixStereo(int voice,int lvol,int rvol,int pitch)
{
	int i,temp,ssmp,sptr,optr,ratio,len,loop,rtotal=0,ltotal=0;
        short *sbuf;
        ratio=(pitch<<14)/SNDfreq;
        sbuf=SNDvoices[voice].cursamp->buf;
        sptr=SNDvoices[voice].sampptr;
        len=SNDvoices[voice].cursamp->length<<14;
        loop=SNDvoices[voice].cursamp->loopto<<14;

        for(i=SNDmixlen,optr=0;i;i--)
        {
        	ssmp=sbuf[sptr>>14];
                //Left
                if(SNDrvs)
                {
                	//Right
                        temp=(ssmp*rvol)>>6;
	                rtotal+=ABS[temp+32768];
	                ((int *)tmpbuf)[optr]+=temp;
	                optr++;
                        //Left
	                temp=(ssmp*lvol)>>6;
	                ltotal+=ABS[temp+32768];
	                ((int *)tmpbuf)[optr]+=temp;
	                optr++;
                }
                else
                {
                        //Left
	                temp=(ssmp*lvol)>>6;
	                ltotal+=ABS[temp+32768];
	                ((int *)tmpbuf)[optr]+=temp;
	                optr++;
                        //Right
                      	temp=(ssmp*rvol)>>6;
	                rtotal+=ABS[temp+32768];
	                ((int *)tmpbuf)[optr]+=temp;
	                optr++;
                }
                sptr+=ratio;
                if(sptr>=len)
	        {
	             	if(loop<0)
	                {
                	        i=1;	//Stop mixing
	                      	SNDkeys&=~(1<<voice);
                                SNDvoices[voice].envx=0;
	                }
	                else    //Preserve any left over
	                {       //to avoid looping artifacts
                                sptr-=len;
                                sptr+=loop;
	                }
	        }
        }

        ltotal/=SNDmixlen;
        SNDlevl+=ltotal;
        rtotal/=SNDmixlen;
        SNDlevr+=rtotal;
        SNDvoices[voice].ave=(ltotal+rtotal)>>1;
     	SNDvoices[voice].sampptr=sptr;
}

void SNDMix(void)
{
        int i=0,pitch,temp=0,lvol=0,rvol=0;
        int envx,voice;

        SNDratecnt++;

        //burn initial CPU cycles?
//       	static bool firstRun = true;
//       	if (firstRun)
//       	{
//       		unsigned long oldSPCcyc = SPCcyc;
//       		SPCcyc /= 2;
//       		SPC_RUN();
//       		SPCcyc = oldSPCcyc;
//       		firstRun=false;
//		}
//		else
		{
			//Emulate some more stuff to play
			SPC_RUN();
		}

        //Now mix
        memset(tmpbuf,0,SNDmixlen<<3);
        SNDlevl=SNDlevr=0;
	for(voice=0;voice<8;voice++)
        {
		if(SNDkeys&(1<<voice))
	        {
                	envx=SNDDoEnv(voice);
		        lvol=((envx>>24)*
                              (int)((signed char)SPC_DSP_Buffer[voice<<4])*
                              (int)((signed char)SPC_DSP_Buffer[0x0C]))>>14;
                        rvol=((envx>>24)*
                              (int)((signed char)SPC_DSP_Buffer[(voice<<4)+1])*
                              (int)((signed char)SPC_DSP_Buffer[0x1C]))>>14;
                        pitch=(int)(*(unsigned short *)&SPC_DSP_Buffer[(voice<<4)+2])<<3;
                        // HOORAY for Zero Volume optimization.
                        if(!SNDmix||((lvol==0)&&(rvol==0))||
                         (((lvol+rvol)>>1==0)&&((SNDbits&sdStereo)==0)))
                         	SNDMixZeroVolume(voice,pitch);
                        else
                        {
                        	if(SNDbits&sdStereo)
	                        	SNDMixStereo(voice,lvol,rvol,pitch);
	                        else 	SNDMixMono(voice,lvol,rvol,pitch);
                        }
                       	if (ITdump)
                       	{
				//adjust for negative volumes
	                       	if(lvol<0)
	                       		lvol=-lvol;
	                        if(rvol<0)
	       	                	rvol=-rvol;
	               	        //lets see if we need to pitch slide
                         	if(pitch&&ITdata[voice].pitch)
                         	{
                                 i=(int)(log2((double)pitch/(double)ITdata[voice].pitch)*768);
                                 if(i)
                                         ITdata[voice].mask|=8;  //enable pitch slide
                        	}
                        	//adjust volume?
                        	if((lvol!=ITdata[voice].lvol)||(rvol!=ITdata[voice].rvol))
                        	{
                                 ITdata[voice].mask|=4;
                                 ITdata[voice].lvol=lvol;
                                 ITdata[voice].rvol=rvol;
                        	}
                       	}
	        }
	        else SNDvoices[voice].ave=0;
                if (ITdump)
                {
                 //Now store IT data
                        if ( ITlastmasks[voice] == ITdata[voice].mask )
                                 ITpattbuf[ITcurbuf][ITbufpos++]=(voice&63)+1;
                                else 
                                {
                                 ITpattbuf[ITcurbuf][ITbufpos++]=((voice&63)+1)|128;
                                 ITpattbuf[ITcurbuf][ITbufpos++]=ITdata[voice].mask;
                                 ITlastmasks[voice] = ITdata[voice].mask;
                                }
                        if(ITdata[voice].mask&1)
                                ITpattbuf[ITcurbuf][ITbufpos++]=ITdata[voice].note;
                        if(ITdata[voice].mask&2)
                                ITpattbuf[ITcurbuf][ITbufpos++]=SPC_DSP_Buffer[(voice<<4)+4]+1;
                        if(ITdata[voice].mask&4)
                                ITpattbuf[ITcurbuf][ITbufpos++]=/*lvol>>1*/(lvol>64)?64:lvol;
                        if(ITdata[voice].mask&8)
                        {
                                if(i>0xF)
                                {
                                        ITpattbuf[ITcurbuf][ITbufpos++]=6; //Effect F
                                        temp=i>>2;
                                        if(temp>0xF)temp=0xF;
                                        temp|=0xF0;     //Fine slide
                                        ITpattbuf[ITcurbuf][ITbufpos++]=temp;
                                }
                                else if(i>0)
                                {
                                        ITpattbuf[ITcurbuf][ITbufpos++]=6; //Effect F
                                        temp=i|0xE0;    //Extra fine
                                        ITpattbuf[ITcurbuf][ITbufpos++]=temp;
                                }
                                else if(i>-0x10)
                                {
                                        ITpattbuf[ITcurbuf][ITbufpos++]=5; //Effect E
                                        temp=(-i)|0xE0; //Extra fine
                                        ITpattbuf[ITcurbuf][ITbufpos++]=temp;
                                }
                                else
                                {
                                        ITpattbuf[ITcurbuf][ITbufpos++]=5; //Effect E
                                        temp=(-i)>>2;
                                        if(temp>0xF)temp=0xF;
                                        temp|=0xF0;     //Fine
                                        ITpattbuf[ITcurbuf][ITbufpos++]=temp;
                                }
                        }
                        if ( ITlastmasks[voice+8] == ITdata[voice].mask )
                                ITpattbuf[ITcurbuf][ITbufpos++]=(voice&63)+9;
                                else 
                                {
                                 ITpattbuf[ITcurbuf][ITbufpos++]=((voice&63)+9)|128;
                                 ITpattbuf[ITcurbuf][ITbufpos++]=ITdata[voice].mask;
                                 ITlastmasks[voice+8] = ITdata[voice].mask;
                                }
                        if(ITdata[voice].mask&1)
                                ITpattbuf[ITcurbuf][ITbufpos++]=ITdata[voice].note;
                        if(ITdata[voice].mask&2)
                                ITpattbuf[ITcurbuf][ITbufpos++]=SPC_DSP_Buffer[(voice<<4)+4]+1;
                        if(ITdata[voice].mask&4)
                                ITpattbuf[ITcurbuf][ITbufpos++]=/*rvol>>1*/(rvol>64)?64:rvol;
                        if(ITdata[voice].mask&8)
                        {
                                if(i>0xF)
                                {
                                        ITpattbuf[ITcurbuf][ITbufpos++]=6; //Effect F
                                        ITpattbuf[ITcurbuf][ITbufpos++]=temp;
                                        ITdata[voice].pitch=(int)((double)ITdata[voice].pitch*pow2((double)((temp&0xF)<<2)/768.0));
                                }
                                else if(i>0)
                                {
                                        ITpattbuf[ITcurbuf][ITbufpos++]=6; //Effect F
                                        ITpattbuf[ITcurbuf][ITbufpos++]=temp;
                                        ITdata[voice].pitch=(int)((double)ITdata[voice].pitch*pow2((double)(temp&0xF)/768.0));
                                }
                                else if(i>-0x10)
                                {
                                        ITpattbuf[ITcurbuf][ITbufpos++]=5; //Effect E
                                        ITpattbuf[ITcurbuf][ITbufpos++]=temp;
                                        ITdata[voice].pitch=(int)((double)ITdata[voice].pitch*pow2((double)(temp&0xF)/-768.0));
                                }
                                else
                                {
                                        ITpattbuf[ITcurbuf][ITbufpos++]=5; //Effect E
                                        ITpattbuf[ITcurbuf][ITbufpos++]=temp;
                                        ITdata[voice].pitch=(int)((double)ITdata[voice].pitch*pow2((double)((temp&0xF)<<2)/-768.0));
                                }
                        }
                        ITdata[voice].mask=0;
                } //end if(ITdump)
	} //end 8-voice loop
        //Clip and convert to 8-bit if necessary
	if(SNDbits&sdStereo)
        {
		if(SNDbits&sd8bit)
                {
	        	for(i=0;i<SNDmixlen<<1;i++)
                		((char *)SNDoptbuf)[i]=((char *)CLIP)[((int *)tmpbuf)[i]+262144];

                }
                else
                {
                	for(i=0;i<SNDmixlen<<1;i++)
                		((short *)SNDoptbuf)[i]=((short *)CLIP)[((int *)tmpbuf)[i]+262144];
		}
        }
	else
	{
		if(SNDbits&sd8bit)
        	{
	        	for(i=0;i<SNDmixlen;i++)
                		((char *)SNDoptbuf)[i]=((char *)CLIP)[((int *)tmpbuf)[i]+262144];
                }
                else
	        {
	        	for(i=0;i<SNDmixlen;i++)
                		((short *)SNDoptbuf)[i]=((short *)CLIP)[((int *)tmpbuf)[i]+262144];
		}
	}
	if (ITdump)
        {
                ITpattbuf[ITcurbuf][ITbufpos++]=0;      //End-of-row
                if(++ITcurrow>=ITrows)
                {
                        ITpattlen[ITcurbuf++]=ITbufpos;
                        ITbufpos=ITcurrow=0;
                        if(ITcurbuf>=NUM_PATT_BUFS)     //Will sound like crap but at
                                ITcurbuf=NUM_PATT_BUFS-1;      //least it won't crash
                        for (i=0;i<16;i++)
        	        	ITlastmasks[i] = -1;
                }
        }
}

void SNDNoteOn(unsigned char v)
{
        int i,cursamp,pitch,adsr1,adsr2,gain;
        v&=SNDvmask;
        for(i=0;i<8;i++)
		if(v&(1<<i))
		{
	        	cursamp=SPC_DSP_Buffer[4+(i<<4)];
                        if(cursamp<100)	//Only 100 samples supported, sorry
	        	{
	        		if(SNDsamples[cursamp]==NULL)
					update_samples(cursamp);
				SNDvoices[i].cursamp=SNDsamples[cursamp];
		                SNDvoices[i].sampptr=0;
		        	SNDkeys|=(1<<i);
                                pitch=(int)(*(unsigned short *)&SPC_DSP_Buffer[(i<<4)+2])<<3;
	                	if(SNDsamples[cursamp]->freq==0)
		                	SNDsamples[cursamp]->freq=pitch;
                                //figure ADSR/GAIN
                                adsr1=SPC_DSP_Buffer[(i<<4)+5];
                                if(adsr1&0x80)
                                {
                                	//ADSR mode
                                        adsr2=SPC_DSP_Buffer[(i<<4)+6];
                                        SNDvoices[i].envx=0;
	                                SNDvoices[i].envcyc=TotalCycles;
                                        SNDvoices[i].envstate=ATTACK;
                                        SNDvoices[i].ar=adsr1&0xF;
                                        SNDvoices[i].dr=adsr1>>4&7;
                                        SNDvoices[i].sr=adsr2&0x1f;
                                        SNDvoices[i].sl=adsr2>>5;
                                }
                                else
                                {
                                	//GAIN mode
                                        gain=SPC_DSP_Buffer[(i<<4)+7];
                                        if(gain&0x80)
                                        {
		                                SNDvoices[i].envcyc=TotalCycles;
                                        	SNDvoices[i].envstate=gain>>5;
                                                SNDvoices[i].gn=gain&0x1F;
                                        }
                                        else
                                        {
                                        	SNDvoices[i].envx=(gain&0x7F)<<24;
	                                        SNDvoices[i].envstate=DIRECT;
                                        }
                                }
		                if((pitch!=0)&&(SNDsamples[cursamp]!=NULL)&&(SNDsamples[cursamp]->freq!=0))
	                        {
	                                ITdata[i].mask|=7; //Update note, samp, and vol for IT
	                                ITdata[i].note=SNDPitchToNote(pitch,SNDsamples[cursamp]->freq);
                                        //find out what pitch we actually told IT :)
                                        ITdata[i].pitch=(int)(pow2(((double)ITdata[i].note-60)/12)*(double)SNDsamples[cursamp]->freq);
                                        ITdata[i].lvol=ITdata[i].rvol=0;
	                        }
                        }
		}
}

void SNDNoteOff(unsigned char v)
{
	int i;
        for(i=0;i<8;i++)
        	if(v&(1<<i))
                {
                        SNDDoEnv(i); 	//Finish up anything that was going on
	        	SNDvoices[i].envstate=RELEASE;
                }
}

int SNDInit(int freq, double urate, int sign, int stereo, int bit8)
{
        int i;
        SNDbits=0;
        SNDfreq=freq;
        SNDurate=urate;
        SPCcyc=2048000.0/SNDurate;	//SPC cycles in one update
        SNDkeys=0;			//Which voices are keyed on (none)
	SNDmixlen=SNDfreq/SNDurate;  	//How long mixing buffer is (samples)
        SNDoptbuf=tmpbuf=malloc(SNDmixlen<<3);    //Mixing buffer
        for(i=-32768;i<32768;i++)	//Init a table to help with graphs
        {
        	if(i<0)
                	ABS[i+32768]=-i;
		else	ABS[i+32768]=i;
        }
        if(stereo)
        	SNDbits|=sdStereo;
        if(bit8)
        {
                SNDbits|=sd8bit;
        	CLIP=malloc(524288);
                if(CLIP==NULL)
                	return 1;
        	for(i=-262144;i<262144;i++)
        	{
                	if(i<-32768)
                        	((char *)CLIP)[i+262144]=0;
                        else if(i>32767)
                        	((char *)CLIP)[i+262144]=255;
                        else	((char *)CLIP)[i+262144]=(i>>8)^0x80;
                }
        }
        else
	{
                CLIP=malloc(1048576);
                if(CLIP==NULL)
                	return 1;
		for(i=-262144;i<262144;i++)
	        {
	        	if(i<-32768)
	                	((unsigned short *)CLIP)[i+262144]=sign?0x8000:0;
	                else if(i>32767)
	                	((unsigned short *)CLIP)[i+262144]=sign?0x7FFF:0xFFFF;
	                else 	((unsigned short *)CLIP)[i+262144]=sign?i:i^0x8000;
	        }
        }
        for(i=0;i<100;i++)		//100 samples all that IT supports
		SNDsamples[i]=NULL;
        for(i=0;i<8;i++)		//8 voices
        {
                SNDvoices[i].sampptr=-1;
                SNDvoices[i].envx=0;
        }
        return(0);
}
