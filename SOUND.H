#ifndef SOUND_H
#define SOUND_H

#define ATTACK 0	//A of ADSR
#define DECAY 1		//D of ADSR
#define SUSTAIN 2	//S of ADSR
#define RELEASE 3	//R of ADSR
#define DECREASE 4	//GAIN linear decrease mode
#define EXP 5		//GAIN exponential decrease mode
#define INCREASE 6	//GAIN linear increase mode
#define BENT 7		//GAIN bent line increase mode
#define DIRECT 8	//Directly specify ENVX

typedef struct {
int length;
int loopto;
short *buf;
int freq;
} sndsamp;

typedef struct {
	sndsamp *cursamp;
        long sampptr;
        int ave;
        unsigned int envx,envcyc;
        int envstate;
	int ar,dr,sl,sr,gn;
} sndvoice;

extern sndsamp *SNDsamples[100];
extern sndvoice SNDvoices[8];
extern void *SNDoptbuf;
extern double SNDurate;
extern int SNDfreq,SNDkeys,SNDvmask,SNDmixlen,SNDrvs;
extern int SNDlevl,SNDlevr;
extern unsigned char SNDbits;
extern int SNDratecnt;
extern int SNDmix;

#define sd8bit   1
#define sdStereo 2

void SNDKillSamp(sndsamp *);
int SNDPitchToNote(int,int);
int SNDDoEnv(int);
void SNDMix(void);
void SNDNoteOn(unsigned char);
void SNDNoteOff(unsigned char);
int SNDInit(int,double,int,int,int);

#endif
