#include <stdlib.h>
#include "sound.h"
#include "it.h"
#include "emu.h"

struct riffhdr {
	char    riff[4];      /* 'RIFF' */
	long    filesize;     /* minus these 8 bytes */
	char    rifftype[4];     /* 'WAVE' */
};

struct chunk {
	char    chunkid[4];   /* 4-character chunk ID */
	long    chunksize;    /* minus these 8 bytes */
};

struct fmt {
	short   fmttag;       /* 1= WAVE_FORMAT_PCM */
	short   channels;     /* 1= mono, 2= stereo */
	long    samplerate;   /* 11025, 22050 ... */
	long    bytespersec;  /* bytes per second */
	short   blockalign;   /* datasize*channels/8 */
	short   datasize;     /* 8= 8-bit, 16= 16-bit */
};

union pcm {
	unsigned char 	*d8;
        signed short	*d16;
};

void Usage(void)
{
	printf("Usage: OSPCLITE [options] <filename>\n");
        printf("Where <filename> is any .SPC, .ZST, .SP#, or .ZS# file\n\n");
        printf("Available switches:\n");
        printf("    -i		Enables IT and disables WAV dumping.  	[WAV default]\n");
	printf("    -u xxx	Specify update rate			[100 default]\n");
        printf("    -t x:xx	Specify a time limit			[unlimited default]\n");
        printf("    -d xxxxxxxx Voices to disable (1-8)			[none default]\n");
        printf("    -f xxxxx	Specify output frequency (WAV only)	[44100 default]\n");
        printf("    -8		Enable 8 bit output (WAV only)		[16 bit default]\n");
        printf("    -m		Specify mono output (WAV only)		[stereo default]\n");
        printf("    -r xxx	Specify rows per pattern (IT only)	[200 default]\n");
	printf("    -l          Disables SPC Internal Time Limit        [Enabled by default]\n");
}

static FILE *wavtmp;
static int wavcnt;

int WAVStart(void)
{
	wavtmp=fopen("wavtemp.tmp","wb");
        if(wavtmp==NULL)
        	return 1;
        wavcnt=0;
        return 0;
}

int WAVUpdate(void)
{
	if(SNDbits&sd8bit)
        	if(SNDbits&sdStereo)
                	fwrite(SNDoptbuf,2,SNDmixlen,wavtmp);
                else	fwrite(SNDoptbuf,1,SNDmixlen,wavtmp);
        else	if(SNDbits&sdStereo)
        		fwrite(SNDoptbuf,4,SNDmixlen,wavtmp);
                else	fwrite(SNDoptbuf,2,SNDmixlen,wavtmp);
	wavcnt++;
}

void WAVWrite(char *fn)
{
        struct riffhdr hdr={"RIFF",0,"WAVE"};
        struct chunk chinfo;
        struct fmt fmt;
        void *buf;
        FILE *f;
	int size;
	fclose(wavtmp);
        f=fopen(fn,"wb");
	if(f==NULL)
        {
        	printf("Couldn't write file '%s'!\n",fn);
                return;
        }
        wavcnt*=SNDmixlen;
        size=1;
        fmt.fmttag=1;
        fmt.channels=1;
        fmt.datasize=8;
        if(SNDbits&sdStereo)
        {
		size<<=1;
                fmt.channels=2;
        }
        if(!(SNDbits&sd8bit))
        {
        	size<<=1;
                fmt.datasize=16;
        }
        wavcnt*=size;
        hdr.filesize=(4+sizeof(struct chunk)*2+sizeof(struct fmt)+wavcnt);
        fwrite(&hdr,sizeof(struct riffhdr),1,f);
        strcpy(chinfo.chunkid,"fmt ");
        chinfo.chunksize=sizeof(struct fmt);
        fwrite(&chinfo,sizeof(struct chunk),1,f);

        fmt.samplerate=SNDfreq;
	fmt.bytespersec=SNDfreq*size;
        fmt.blockalign=size;
        fwrite(&fmt,sizeof(struct fmt),1,f);
        strcpy(chinfo.chunkid,"data");
        chinfo.chunksize=wavcnt;
	fwrite(&chinfo,sizeof(struct chunk),1,f);

        wavtmp=fopen("wavtemp.tmp","rb");
        if(wavtmp==NULL)
        {
        	printf("Unexpected error, unable to complete WAV dump!\n");
                fclose(f);
                remove(fn);
                return;
        }
        buf=malloc(65536);
        for(;wavcnt>65536;wavcnt-=65536)
        {
        	fread(buf,1,65536,wavtmp);
                fwrite(buf,1,65536,f);
        }
	for(;wavcnt;wavcnt--)
		fputc(fgetc(wavtmp),f);
        fclose(wavtmp);
        fclose(f);
        remove("wavtemp.tmp");
}

void Shutdown(void)
{
// No Allegro to shut down...
}

int main(int argc, char **argv)
{
        int freq,urate,cursx,cursy,stereo,bit8,inlimit;
        int seconds,limit,done,voices,v;
        char fn[64];
        int i;
        printf("\nOpenSPC v.301 *Lite* (direct to disk version)\n");
        printf(" Primary Author: Butcha\n");
        printf(" Other contributors: Cyber Warrior X, Crono, Kadar, Cait Sith 2\n");
        printf("Thanks to:\n");
        printf("        Savoury SnaX and Charles Bilyu‚ for SNEeSe's SPC core\n");
	fn[0]=0;
        ITdump=0;
        SNDmix=1;	// Default WAV dumping
        urate=100;	// Default 100Hz update rate
        freq=44100;	// Default 44100Hz freq (WAV only)
        stereo=1;	// Default stereo (WAV only)
        bit8=0;		// Default 8 bit (WAV only)
        ITrows=200;	// Default 200 rows/pattern (IT only)
        limit=0;	// Default no time limit
	inlimit=1;	// Internal SPC limit enabled
        voices=0;	// Default no voices disabled
        for(i=1;i<argc;i++)
        {
        	if(argv[i][0]=='-')
                    switch(argv[i][1])
                    {
                    case 'i': 	ITdump=1;SNDmix=0;break;
                    case 'u': 	i++;
                    		urate=atoi(argv[i]);
                                break;
                    case 'f':	i++;
                    		freq=atoi(argv[i]);
                                break;
                    case '8':	bit8=1;break;
                    case 'm':	stereo=0;break;
                    case 'r':	i++;
                    		ITrows=atoi(argv[i]);
                                break;
                    case 't':	i++;
                    		sscanf(argv[i],"%d:%d",&limit,&seconds);
                                limit*=60;
                                limit+=seconds;
                                break;
                    case 'd':	i++;
                    		for(v=0;argv[i][v]!=0;v++)
                                	voices|=1<<(argv[i][v]-'1');
                                break;
		    case 'l':   inlimit=0;
                                break;
                    default:	printf("Warning, unrecognized option '-%c'!\n",argv[i][1]);
                    }
                else strcpy(fn,argv[i]);
        }
        if(fn[0]==0)
        {
        	Usage();
                exit(0);
        }
        if(ITdump)
        {
		if(urate>102)
                {
                	printf("Error: Can only record to IT at 102 updates/sec or less!\n");
                        exit(1);
                }
        }
        else	if(urate>1000)
        	{
                	printf("Error: Max update rate is 1000\n");
                        exit(1);
                }
	printf("\nFilename:	%s\n",fn);

        if(SPCInit(fn))	//Reset SPC and load state
        {
        	printf("Failed to initialize emulation!\n");
                exit(1);
        }

        if(!limit&&inlimit&&SPCtime)
                limit=SPCtime;
        printf("Time limit:	");
        if(limit)
        	printf("%d:%02d\n",limit/60,limit%60);
        else 	printf("none\n");
        printf("Voices disabled: ");
        if(voices)
        {
        	for(v=0;v<8;v++)
                	if(voices&(1<<v))
                        	printf("%d",v+1);
                printf("\n");
        }
        else printf("none\n");
        printf("Output format:	");
        if(ITdump)
        {
        	printf("IT\n");
                printf("Parameters:\n");
	        printf("	Update rate:	%d\n",urate);
                printf("	Rows/pattern:	%d\n",ITrows);
        }
        else
        {
        	printf("WAV\n");
                printf("Parameters:\n");
	        printf("	Update rate:	%d\n",urate);
                printf("	Frequency:	%d\n",freq);
                printf("	Quality:	");
                if(bit8)
                	printf("8 bit ");
                else    printf("16 bit ");
                if(stereo)
                	printf("stereo\n");
                else 	printf("mono\n");
        }

        if(SPCname[0]||SPCtname[0]||SPCdname[0]||SPCcomment[0]||SPCdate[0])
        {
                printf("ID info:\n");
                printf("        Song name:              %s\n",SPCname);
                printf("        Game name:              %s\n",SPCtname);
                printf("        Person who Dumped SPC:  %s\n",SPCdname);
                printf("        Comments:               %s\n",SPCcomment);
                printf("        Dumped on date:         %s\n",SPCdate);
        }
	if(SNDInit(freq,urate,1,stereo,bit8))
        {
        	printf("Init Sound failed!\n");
                exit(1);
        }
        SNDvmask=~voices;
        if(ITdump&&ITStart())
        {
        	printf("Failed to init pattern buffers!\n");
                exit(1);
        }
        if(SNDmix&&WAVStart())
        {
              	printf("Failed to init WAV dump!\n");
                exit(1);
        }
        SNDNoteOn(SPC_DSP_Buffer[0x4c]);
        if(limit)
        	printf("Progress: ");
        else	printf("Play time: ");
        fflush(stdout);
        cursx=wherex();
        printf("\nPress a key to end capture\n");
        cursy=wherey()-2;
        seconds=SNDratecnt=done=0;
	SNDNoteOn(SPC_DSP_Buffer[0x4c]); //Turn on voices that were on when saved
        while(!done)
        {
                SNDMix();
                if(ITdump)
		{
                	if(ITUpdate())
                        	break;
                }
                if(SNDmix)
                	WAVUpdate();

        	if(SNDratecnt>=urate)
                {
                        if(kbhit())
                        	done=1;
                	SNDratecnt-=urate;
	                seconds++;
	        	gotoxy(cursx,cursy);
                        if(limit)
                        {
                        	if(seconds==limit)
                                	done=1;
                                printf("%3d%%",seconds*100/limit);
                        }
                        else
		                printf("%2d:%02d",seconds/60,seconds%60);
	                fflush(stdout);
                }
        }
        printf("\n\nSaving file...\n");
	for(i=0;i<64;i++)
        	if(fn[i]==0)
        		break;
        for(;i>0;i--)
        	if(fn[i]=='.')
                	strcpy(&fn[i+1],ITdump?"IT":"WAV");
        if(ITdump)
	{
        	if(ITWrite(fn))
                       	printf("Failed at writing %s.\n",fn);
                else    printf("Wrote %s successfully.\n",fn);
	}
	if(SNDmix)
	{
                WAVWrite(fn);
                printf("Wrote %s successfully.\n",fn);
        }
        return(0);
}
