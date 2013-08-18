/************************************************************************
 *                      IT.C, from OpenSPC source                       *
 *    Please see documentation for license and authoring information    *
 ************************************************************************/

#include "it.h"
#include "sound.h"
#include "emu.h"

#include <stdlib.h>

itdata ITdata[8];
//Temp memory for patterns before going to file
unsigned char *ITpattbuf[NUM_PATT_BUFS];
int ITpattlen[NUM_PATT_BUFS];	//lengths of each pattern
int ITlastmasks[16];		//Used for pattern compression
int ITcurbuf,ITbufpos,ITcurrow;	//Pointers into temp pattern buffers
int ITrows;			//Number of rows per pattern
int ITdump;			//Flag: dumping enabled

static int offset[199];	//table of offsets into temp file to each pattern
static FILE *ittmp;	//Temp file for mass pattern storage
static int curpatt;	//which pattern we are on in temp file
static int curoffs;	//where we are in file

static const char nullstr[25]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                               0,0};

static void ITSSave(sndsamp *s, FILE *f)
{
        unsigned long tmp;
        int loopto=-1;
        int length=0;
        int freq=0;
        int ofs;
        fgetpos(f,(fpos_t *)&ofs);
        if(s!=NULL)
        {
        	loopto=s->loopto;
                length=s->length;
                freq=s->freq;
        }
        if (length)
        fputs("IMPSITSAMPLE.ITS",f); else
        {
         fputs("IMPS",f);
         fwrite(&nullstr,1,12,f);
        }
	fputc(0,f);
        fputc(64,f);
        tmp=2;
        if((loopto!=-1)&&(length))
                tmp|=16;
        if(length)
        	tmp|=1;
        fputc(tmp,f);
       	fputc(64,f);
        if (length)
        fputs("SPC Sample               ",f); else
        {
         fwrite (&nullstr,1,25,f);
         freq   = 8363;
         loopto = 0;
        }
        fputc(0,f);
        fputc(1,f);
        fputc(0,f);
        fwrite(&length,1,4,f);
        tmp=0;
        if(loopto!=-1)
        {
        	fwrite(&loopto,1,4,f);
	        fwrite(&length,1,4,f);
        }
        else
        {
        	fwrite(&tmp,1,4,f);
        	fwrite(&tmp,1,4,f);
        }
        fwrite(&freq,1,4,f);
        fwrite(&tmp,1,4,f);
        fwrite(&tmp,1,4,f);
        ofs+=0x50;
       	fwrite(&ofs,1,4,f);
        fwrite(&tmp,1,4,f);
	if(length)
		fwrite(s->buf,s->length,2,f);
}

int ITStart(void)	//Opens up temporary file and inits writing
{
	int i;
        ittmp=fopen("ittemp.tmp","wb");
        if(ittmp==NULL)
        	return 1;
        for(i=0;i<NUM_PATT_BUFS;i++)
	{
                ITpattbuf[i]=malloc(65536);
                if(ITpattbuf[i]==NULL)
                	return 1;
		ITpattlen[i]=0;
        }
        ITcurbuf=ITbufpos=ITcurrow=0;
        curoffs=0;
        for(i=0;i<199;i++)
        	offset[i]=-1;		//-1 means unused pattern
        curpatt=0;

        for(i=0;i<8;i++)
        	ITdata[i].mask=0;
        return 0;
}

int ITUpdate(void)	//Dumps pattern buffers to file
{			//Return 1 means recording ended
        unsigned char *tmpptr;
	int i;
        for(i=0;i<ITcurbuf;i++)
        {
        	offset[curpatt]=curoffs;
                fwrite(&ITpattlen[i],2,1,ittmp);
                fwrite(&ITrows,2,1,ittmp);
                i=0;
                fwrite(&i,4,1,ittmp);
        	fwrite(ITpattbuf[i],ITpattlen[i],1,ittmp);
                curoffs+=ITpattlen[i]+8;
                if(curpatt<198)
	                curpatt++;
                else return 1;
	}
        tmpptr=ITpattbuf[0];
        ITpattbuf[0]=ITpattbuf[ITcurbuf];
        ITpattbuf[ITcurbuf]=tmpptr;
        ITcurbuf=0;
	return 0;
}

int ITWrite(char *fn)
{
	FILE *f;
        int i,t,numsamps,ofs;
        char tmpstr[30];
        if(fn==NULL)
        {
                fclose(ittmp);
	        remove("ittemp.tmp");
        	return 0;
        }
        //Stop all notes and loop back to the beginning
        for(i=0;i<15;i++)	//Save the last channel to put loop in
        {
		ITpattbuf[ITcurbuf][ITbufpos++]=i+129;
		ITpattbuf[ITcurbuf][ITbufpos++]=1;
		ITpattbuf[ITcurbuf][ITbufpos++]=254;
                ITlastmasks[i] = 1;
        }
        //Now do last channel
	ITpattbuf[ITcurbuf][ITbufpos++]=144;
	ITpattbuf[ITcurbuf][ITbufpos++]=9;
	ITpattbuf[ITcurbuf][ITbufpos++]=254;
	ITpattbuf[ITcurbuf][ITbufpos++]=2;	//Effect B: jump to...
	ITpattbuf[ITcurbuf][ITbufpos++]=0;	//...order 0
	while(ITcurrow++<ITrows)
        	ITpattbuf[ITcurbuf][ITbufpos++]=0;	//end-of-row

	ITpattlen[ITcurbuf++]=ITbufpos;
        ITUpdate();	//Save the changes we just made
        fclose(ittmp);
        f=fopen(fn,"wb");
        if(f==NULL)
        {
		printf("Error, can't write IT file!  Aborting...\n");
                return 1;
        }
        fputs("IMPM",f);
        if(SPCname[0])
        {
                strcpy(tmpstr,"                         ");
                for(i=0;(SPCname[i]!=0)&&(i<25);i++)
                        tmpstr[i]=SPCname[i];
                fputs(tmpstr,f);
        }
        else    fputs(".SPC -> .IT conversion   ",f);
        i=0;
        fwrite(&i,3,1,f);
        i=curpatt+1;
        fwrite(&i,2,1,f);	//# of orders (same as # patterns+1 for end)
	i=0;
        fwrite(&i,2,1,f);	//# of instruments (none)
        for(numsamps=99;SNDsamples[numsamps]==NULL;numsamps--);
        numsamps++;
        fwrite(&numsamps,2,1,f);//# of samples
        fwrite(&curpatt,2,1,f);	//# of patterns
	i=0x214;		//Created with tracker version
        fwrite(&i,2,1,f);
        i=0x200;		//Compatible with tracker version
        fwrite(&i,2,1,f);
	i=9;			//Flags-stereo,linear slides, no MIDI, etc.
        fwrite(&i,2,1,f);
	i=0;			//Special- ??
        fwrite(&i,2,1,f);
        fputc(128,f);		//Global volume
        fputc(100,f);		//Mix volume
        fputc(1,f);		//Initial speed (fastest)
        i=(int)((double)SNDurate*2.5);
        fputc(i,f);		//Initial tempo (determined by update rate)
        fputc(128,f);		//Stereo separation (max)
        fputc(0,f);		//Pitch wheel depth (unused)
        i=0;
        fwrite(&i,2,1,f);	//Message length (we have no message)
        fwrite(&i,4,1,f);	//Message offset (we have no message)
        fwrite(&i,4,1,f);	//Reserved
        i=0;			//Channel pan- set 8 channels to left
        fwrite(&i,4,1,f);
        fwrite(&i,4,1,f);
        i=0x40404040;		//set 8 channels to right
        fwrite(&i,1,4,f);
        fwrite(&i,1,4,f);
	i=0x80808080;           //disable the rest of the channels
        fwrite(&i,1,4,f);
        fwrite(&i,1,4,f);
        fwrite(&i,1,4,f);
        fwrite(&i,1,4,f);
        fwrite(&i,1,4,f);
        fwrite(&i,1,4,f);
        fwrite(&i,1,4,f);
        fwrite(&i,1,4,f);
        fwrite(&i,1,4,f);
        fwrite(&i,1,4,f);
        fwrite(&i,1,4,f);
        fwrite(&i,1,4,f);
        i=0x40404040;		//Channel Vol- set 16 channels loud
        fwrite(&i,1,4,f);
        fwrite(&i,1,4,f);
        fwrite(&i,1,4,f);
        fwrite(&i,1,4,f);
	i=0;			//disable the rest
        fwrite(&i,1,4,f);
        fwrite(&i,1,4,f);
        fwrite(&i,1,4,f);
        fwrite(&i,1,4,f);
        fwrite(&i,1,4,f);
        fwrite(&i,1,4,f);
        fwrite(&i,1,4,f);
        fwrite(&i,1,4,f);
        fwrite(&i,1,4,f);
        fwrite(&i,1,4,f);
        fwrite(&i,1,4,f);
        fwrite(&i,1,4,f);
        //orders
        for(i=0;i<curpatt;i++)
        	fputc(i,f);	//Each order has one corresponding pattern
	fputc(255,f);		//End of song order
        //sample ptrs
        ofs=0xC1+curpatt+((numsamps+curpatt)<<2);
        for(i=0;i<numsamps;i++)
        {
        	fwrite(&ofs,1,4,f);
                ofs+=0x50;
                if(SNDsamples[i]!=NULL)
                	ofs+=(SNDsamples[i]->length<<1);
        }
        //Pattern ptrs
        for(i=0;i<curpatt;i++)
        {
		t=offset[i]+ofs;
                fwrite(&t,4,1,f);
        }
        //samples
        for(i=0;i<numsamps;i++)
        	ITSSave(SNDsamples[i],f);
        //patterns
        ittmp=fopen("ittemp.tmp","rb");
        if(ittmp==NULL)
        {
		printf("Error, can't find temp file!  Aborting...\n");
                return 1;
        }
        while((i=fgetc(ittmp))!=EOF)
        	fputc(i,f);
        fclose(ittmp);
        fclose(f);
        remove("ittemp.tmp");
        return 0;
}
