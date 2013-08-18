/************************************************************************
 *                      MAIN.C, from OpenSPC source                     *
 *      Please see documentation for license and authoring information  *
 ************************************************************************/

// Allegro Defines. (if we don't define these,
// the size of the file will be larger)
#define  alleg_joystick_unused
#define  alleg_flic_unused
#define  alleg_math_unused
#define  alleg_gui_unused

#include "allegro.h"

BEGIN_GFX_DRIVER_LIST
	GFX_DRIVER_VESA3
        GFX_DRIVER_VESA2L
        GFX_DRIVER_VESA2B
        GFX_DRIVER_VESA1
END_GFX_DRIVER_LIST
BEGIN_COLOR_DEPTH_LIST
	COLOR_DEPTH_8
END_COLOR_DEPTH_LIST
BEGIN_DIGI_DRIVER_LIST
	DIGI_DRIVER_SOUNDSCAPE
        DIGI_DRIVER_AUDIODRIVE
        DIGI_DRIVER_SB
END_DIGI_DRIVER_LIST
BEGIN_MIDI_DRIVER_LIST
END_MIDI_DRIVER_LIST

#include "emu.h"
#include "it.h"

#include <conio.h>
#include <dos.h>

//#define DEBUGINFO
#define MINBUFSIZE 2048

// for display stuff
const static char notestrng[12][3]={"C","C#","D","D#","E","F","F#","G","G#",
 "A","A#","B"};
static int fadespd;
static int seconds;
static int clr_data,clr_label,clr_grph_lo,clr_grph_md,clr_grph_hi;

// Allegro stuff
static BITMAP *double_buffer;
static AUDIOSTREAM *stream;
static int mult;

static void Usage(void)
{
	printf("Usage: OPENSPC [options] <filename>\n");
        printf("Where <filename> is any .SPC, .ZST, .SP#, or .ZS# file\n\n");
        printf("If no options specified, defaults loaded from OPENSPC.CFG file.\n");
        printf("Available switches:\n");
        printf("    -g x        Specify display option (see cfg)        [0 by default]\n");
        printf("    -i		Enables IT dumping.			[off by default]\n");
	printf("    -u xxx	Specify update rate			[100 default]\n");
        printf("    -t x:xx	Specify a time limit			[unlimited default]\n");
        printf("    -d xxxxxxxx Voices to disable (1-8)			[none default]\n");
        printf("    -f xxxxx    Specify output frequency                [22050 default]\n");
        printf("    -8		Enable 8 bit output			[16 bit default]\n");
        printf("    -m		Specify mono output			[stereo default]\n");
        printf("    -r xxx	Specify rows per IT pattern		[200 default]\n");
	printf("    -s		Swap stereo channels			[unswapped default]\n");
	printf("    -l		Disables Internal Time limit		[Enabled by default]\n");
}

static void fade(BITMAP *buf,int x1,int y1,int x2,int y2)
{
	int x,y,c;
        for(y=y1;y<y2;y++)
        	for(x=x1;x<x2;x++)
                {
                 	c=buf->line[y][x]+(fadespd<<4);
                        if(c>255)c=0;
                        buf->line[y][x]=c;
                }
}

static void Status(void)
{
        int voice,temp,lvol,rvol,total,i,pan;
        double ratio;

        // First fade previous results, so we can write over them
        fade(double_buffer,32,24,401,88);
        fade(double_buffer,128,96,640,112);
#ifdef DEBUGINFO
        fade(double_buffer,0,128,192,192);
#endif
        textprintf(double_buffer,font,542,0,clr_data,"%2d:%02d",seconds/60,seconds%60);
        for(voice=0;voice<8;voice++)
        {
                // Post which voice channel it is
                if(SNDvmask&(1<<voice))
                	textprintf(double_buffer,font,8,24+(voice<<3),
                	  clr_label,"V%d:",voice+1);
                else 	textprintf(double_buffer,font,8,24+(voice<<3),
                	  clr_label,"XX:");
                // Now Post the sample
                if(SNDkeys&(1<<voice))
                {
                        temp=SPC_DSP_Buffer[(voice<<4)+4];
                        textprintf(double_buffer,font,32,24+(voice<<3),
                          clr_data,"%3d ",temp);
                        // Figure out the Pitch
                        temp=SNDPitchToNote((int)(*(unsigned short *)
                           &SPC_DSP_Buffer[(voice<<4)+2])<<3,
                          SNDvoices[voice].cursamp->freq);
                        textprintf(double_buffer,font,72,24+(voice<<3),
                          clr_data,"%2s%2d",notestrng[temp%12], temp/12);
#ifdef DEBUGINFO
                        switch(SNDvoices[voice].envstate)
                        {
                        case ATTACK:	textprintf(double_buffer,font,0,
                        		  128+(voice<<3),clr_data,
                        		  "ATTACK   :");
                                        break;
                        case DECAY:	textprintf(double_buffer,font,0,
                        		  128+(voice<<3),clr_data,
                        		  "DECAY    :");
                        		break;
                        case SUSTAIN:	textprintf(double_buffer,font,0,
                        		  128+(voice<<3),clr_data,
                        		  "SUSTAIN  :");
                        		break;
                        case RELEASE:	textprintf(double_buffer,font,0,
                        		  128+(voice<<3),clr_data,
                        		  "RELEASE  :");
                                        break;
                        case DECREASE:	textprintf(double_buffer,font,0,
                        		  128+(voice<<3),clr_data,
                        		  "DECREASE :");
                                        break;
                        case EXP:	textprintf(double_buffer,font,0,
                        		  128+(voice<<3),clr_data,
                        		  "EXP      :");
                        		break;
                        case INCREASE:	textprintf(double_buffer,font,0,
                        		  128+(voice<<3),clr_data,
                        		  "INCREASE :");
                        		break;
                        case BENT:	textprintf(double_buffer,font,0,
                        		  128+(voice<<3),clr_data,
                        		  "BENT     :");
                        		break;
                        case DIRECT:	textprintf(double_buffer,font,0,
                        		  128+(voice<<3),clr_data,
                        		  "DIRECT   :");
                        		break;
			}
			textprintf(double_buffer,font,88,128+(voice<<3),
			  clr_data,"%2X/%2X/%2X  %2X",
			  SPC_DSP_Buffer[(voice<<4)+5],
			  SPC_DSP_Buffer[(voice<<4)+6],
			  SPC_DSP_Buffer[(voice<<4)+7],
			  SNDvoices[voice].envx>>24);
#endif
                }

                lvol=SPC_DSP_Buffer[voice<<4]&127;
                rvol=SPC_DSP_Buffer[(voice<<4)+1]&127;
                total=lvol+rvol;
                temp=SNDvoices[voice].ave>>6;
                // Post the volume of each sample
                if(temp>128)
                	temp=128;
                for(i=0;(i<temp)&&(i<64);i++)
                        vline(double_buffer,144+(i<<1),24+(voice<<3),
                          30+(voice<<3),clr_grph_lo);
                for(;(i<temp)&&(i<96);i++)
                        vline(double_buffer,144+(i<<1),24+(voice<<3),
                          30+(voice<<3),clr_grph_md);
                for(;i<temp;i++)
                        vline(double_buffer,144+(i<<1),24+(voice<<3),
                          30+(voice<<3),clr_grph_hi);
                // Panning stuff
                if(total!=0)
                {
                        textprintf(double_buffer,font,408,20+(voice<<3),0,"                  ");
                        ratio=(double)rvol/(double)total;
                        pan=ratio*128;
                        hline(double_buffer,416,24+(voice<<3),552,clr_label);
                        vline(double_buffer,483,21+(voice<<3),27+(voice<<3),
                          clr_label);
                        circlefill(double_buffer,419+pan,24+(voice<<3),3,
                          clr_data);
        	}
	}
        // Overall Volume
        lvol=SNDlevl>>6;
        if(lvol>256)
        	lvol=256;
        rvol=SNDlevr>>6;
        if(rvol>256)
        	rvol=256;
        textprintf(double_buffer, font, 80, 96,clr_label, "L");
        for(i=0;(i<lvol)&&(i<128);i++)
                vline(double_buffer,128+(i<<1),96,102,clr_grph_lo);
        for(;(i<lvol)&&(i<192);i++)
                vline(double_buffer,128+(i<<1),96,102,clr_grph_md);
        for(;i<lvol;i++)
                vline(double_buffer,128+(i<<1),96,102,clr_grph_hi);
        textprintf(double_buffer,font,80,104,clr_label,"R");
        for(i=0;(i<rvol)&&(i<128);i++)
                vline(double_buffer,128+(i<<1),104,110,clr_grph_lo);
        for(;(i<rvol)&&(i<192);i++)
                vline(double_buffer,128+(i<<1),104,110,clr_grph_md);
        for(;i<rvol;i++)
                vline(double_buffer,128+(i<<1),104,110,clr_grph_hi);
#ifdef DEBUGINFO
        if(SPC_CTRL&1)
        {
                temp=TotalCycles-CycleLatch0;
                i=(temp>>8)+SPC_TIMER0;
                if(SPC_TIMT0)
                	total=i/SPC_TIMT0;
                else	total=i>>8;
        	textprintf(double_buffer,font,0,200,clr_data,
        	 "T0 (%02X): %08X /  %06X /  %06X\n",SPC_TIMT0,
        	 temp,i,total);
        }
        if(SPC_CTRL&2)
        {
                temp=TotalCycles-CycleLatch1;
                i=(temp>>8)+SPC_TIMER1;
                if(SPC_TIMT1)
                	total=i/SPC_TIMT1;
                else	total=i>>8;
        	textprintf(double_buffer,font,0,208,clr_data,
        	 "T1 (%02X): %08X /  %06X /  %06X\n",SPC_TIMT1,
        	 temp,i,total);
        }
        if(SPC_CTRL&4)
        {
                temp=TotalCycles-CycleLatch2;
                i=(temp>>5)+SPC_TIMER2;
                if(SPC_TIMT2)
                	total=i/SPC_TIMT2;
                else	total=i>>8;
        	textprintf(double_buffer,font,0,216,clr_data,
        	 "T2 (%02X): %08X / %07X / %07X\n",SPC_TIMT2,
        	 temp,i,total);
        }
#endif
        blit(double_buffer, screen, 0, 0, 0, 0, 640, 480);
}

static void OldStatus(void)
{
        int voice,temp,lvol,rvol,total,i,pan;
        double ratio;

        gotoxy(68,1);
        textattr(clr_data);
        cprintf("%2d:%02d",seconds/60,seconds%60);
        for(voice=0;voice<8;voice++)
        {
	        gotoxy(2,4+voice);
                textattr(clr_label);
                // Post which voice channel it is
                if(SNDvmask&(1<<voice))
                	cprintf("V%d:",voice+1);
                else
                {
	        	putch('X');putch('X');putch(':');
                }
                // Now Post the sample
                if(SNDkeys&(1<<voice))
                {
                        temp=SPC_DSP_Buffer[(voice<<4)+4];
                        gotoxy(5,4+voice);
                        textattr(clr_data);
                        cprintf("%3d",temp);
                        // Figure out the Pitch
                        temp=SNDPitchToNote((int)(*(unsigned short *)&SPC_DSP_Buffer[(voice<<4)+2])<<3,SNDvoices[voice].cursamp->freq);
			gotoxy(10,4+voice);
                        cprintf("%2s%2d",notestrng[temp%12], temp/12);
#ifdef DEBUGINFO
                        gotoxy(1,17+voice);
			switch(SNDvoices[voice].envstate)
                        {
                        case ATTACK:	cprintf("ATTACK   :");
                                        break;
                        case DECAY:	cprintf("DECAY    :");
                        		break;
                        case SUSTAIN:	cprintf("SUSTAIN  :");
                        		break;
                        case RELEASE:	cprintf("RELEASE  :");
                                        break;
                        case DECREASE:	cprintf("DECREASE :");
                                        break;
                        case EXP:	cprintf("EXP      :");
                        		break;
                        case INCREASE:	cprintf("INCREASE :");
                        		break;
                        case BENT:	cprintf("BENT     :");
                        		break;
                        case DIRECT:	cprintf("DIRECT   :");
                        		break;
			}
			cprintf(" %2X/%2X/%2X  %2X",
			  SPC_DSP_Buffer[(voice<<4)+5],
			  SPC_DSP_Buffer[(voice<<4)+6],
			  SPC_DSP_Buffer[(voice<<4)+7],
			  SNDvoices[voice].envx>>24);
#endif
                }
                else
                {
                	gotoxy(5,4+voice);
                	for(i=0;i<11;i++)
                        	putch(' ');
#ifdef DEBUGINFO
			gotoxy(1,17+voice);
                	for(i=0;i<27;i++)
                        	putch(' ');
#endif
                }
                lvol=SPC_DSP_Buffer[voice<<4]&127;
                rvol=SPC_DSP_Buffer[(voice<<4)+1]&127;
                total=lvol+rvol;
                temp=SNDvoices[voice].ave>>6;
                // Post the volume of each sample
                if(temp>128)
                	temp=128;
                gotoxy(19,4+voice);
                textattr(clr_grph_lo);
                for(i=0;(i<temp)&&(i<64);i+=4)
                        putch(']');
                textattr(clr_grph_md);
                for(;(i<temp)&&(i<96);i+=4)
                        putch(']');
                textattr(clr_grph_hi);
                for(;i<temp;i+=4)
                        putch(']');
                for(;i<128;i+=4)
                	putch(' ');
                // Panning stuff
                if(total!=0)
                {
                        ratio=(double)rvol/(double)total;
	                pan=ratio*16;
                        gotoxy(53,4+voice);
                        textattr(clr_label);
                        for(i=0;i<pan;i++)
	                       	putch(i==8?'|':'-');
                        textattr(clr_data);
	                putch('O');
                        textattr(clr_label);
                        i++;
	                for(;i<17;i++)
	                	putch(i==8?'|':'-');
        	}
	}
        // Overall Volume
        lvol=SNDlevl>>6;
        if(lvol>256)
        	lvol=256;
        rvol=SNDlevr>>6;
        if(rvol>256)
        	rvol=256;
        gotoxy(11,13);
        textattr(clr_label);
        cprintf("L");
        gotoxy(17,13);
        textattr(clr_grph_lo);
        for(i=0;(i<lvol)&&(i<128);i+=4)
                putch(']');
        textattr(clr_grph_md);
        for(;(i<lvol)&&(i<192);i+=4)
                putch(']');
        textattr(clr_grph_hi);
        for(;i<lvol;i+=4)
                putch(']');
        textattr(clr_label);
        for(;i<256;i+=4)
        	putch(' ');
        gotoxy(11,14);
        cprintf("R");
        gotoxy(17,14);
        textattr(clr_grph_lo);
        for(i=0;(i<rvol)&&(i<128);i+=4)
                putch(']');
        textattr(clr_grph_md);
        for(;(i<rvol)&&(i<192);i+=4)
                putch(']');
        textattr(clr_grph_hi);
        for(;i<rvol;i+=4)
                putch(']');
        for(;i<256;i+=4)
        	putch(' ');
#ifdef DEBUGINFO
        if(ScreenRows()>=28)
        {
        	if(SPC_CTRL&1)
	        {
	                temp=TotalCycles-CycleLatch0;
	                i=(temp>>8)+SPC_TIMER0;
	                if(SPC_TIMT0)
	                	total=i/SPC_TIMT0;
	                else	total=i>>8;
	                gotoxy(1,26);
                        textattr(clr_data);
	                cprintf("T0 (%02X): %08X /  %06X /  %06X\n",SPC_TIMT0,
	                  temp,i,total);
	        }
	        if(SPC_CTRL&2)
	        {
	                temp=TotalCycles-CycleLatch1;
	                i=(temp>>8)+SPC_TIMER1;
	                if(SPC_TIMT1)
	                	total=i/SPC_TIMT1;
	                else	total=i>>8;
	                gotoxy(1,27);
                        textattr(clr_data);
	                cprintf("T1 (%02X): %08X /  %06X /  %06X\n",SPC_TIMT1,
	                  temp,i,total);
	        }
	        if(SPC_CTRL&4)
	        {
	                temp=TotalCycles-CycleLatch2;
	                i=(temp>>5)+SPC_TIMER2;
	                if(SPC_TIMT2)
	                	total=i/SPC_TIMT2;
	                else	total=i>>8;
	                gotoxy(1,28);
                        textattr(clr_data);
	        	cprintf("T2 (%02X): %08X / %07X / %07X\n",SPC_TIMT2,
	        	  temp,i,total);
	        }
        	gotoxy(1,29);
        }
        else
                gotoxy(1,24);
#else
        gotoxy(1,17);
#endif
	textattr(7);
}

static int InitScreen(void)
{
        PALLETE p;
        RGB c,base;
        int color,shade,err_vmode;
	// Allegro stuff
        err_vmode=set_gfx_mode(GFX_AUTODETECT,640,480,0,0);
        if(err_vmode)
        {
	        printf("Error setting graphics mode\n%s\n\n",allegro_error);
	        // Shut down Allegro
	        allegro_exit();
	        return 1;
        }

        // Setup palette
        p[ 0].b= 0;p[ 0].g= 0;p[ 0].r= 0;
        p[ 1].b=56;p[ 1].g= 0;p[ 1].r= 0;
        p[ 2].b= 0;p[ 2].g=56;p[ 2].r= 0;
        p[ 3].b=48;p[ 3].g=48;p[ 3].r= 0;
        p[ 4].b= 0;p[ 4].g= 0;p[ 4].r=56;
        p[ 5].b=48;p[ 5].g= 0;p[ 5].r=48;
        p[ 6].b= 0;p[ 6].g=32;p[ 6].r=48;
        p[ 7].b=48;p[ 7].g=48;p[ 7].r=48;
        p[ 8].b=32;p[ 8].g=32;p[ 8].r=32;
        p[ 9].b=63;p[ 9].g=32;p[ 9].r=32;
        p[10].b=32;p[10].g=63;p[10].r=32;
        p[11].b=63;p[11].g=63;p[11].r= 0;
        p[12].b=24;p[12].g=24;p[12].r=63;
        p[13].b=63;p[13].g= 0;p[13].r=63;
        p[14].b= 0;p[14].g=63;p[14].r=63;
        p[15].b=63;p[15].g=63;p[15].r=63;


        base=p[0]; //Base is whatever bg color is (color 0)
        //Background should never fade
        for(shade=0;shade<16;shade++)
        	p[shade<<4]=base;
        //Fade all other colors into bg color
        for(color=1;color<16;color++)
        {
                c=p[color];
                for(shade=0;shade<16;shade++)
                {
        		p[color+(shade<<4)].r=(((int)c.r*(16-shade))>>4)+(((int)base.r*shade)>>4);
        		p[color+(shade<<4)].g=(((int)c.g*(16-shade))>>4)+(((int)base.g*shade)>>4);
        		p[color+(shade<<4)].b=(((int)c.b*(16-shade))>>4)+(((int)base.b*shade)>>4);
                }
        }
        set_palette(p);
        // create and clear a double_buffer
        double_buffer=create_bitmap(640,480);
        clear(double_buffer);
        textprintf(double_buffer,font,24,8,clr_label,
         "SMP#  PITCH                 LEVEL");
        textprintf(double_buffer,font,472,8,clr_label,"PAN");
        textprintf(double_buffer,font,8,120,clr_label,
          "Press keys 1-8 to toggle voices, any other key to exit");
        blit(double_buffer,screen,0,0,0,0,640,480);
        return 0;
}

static int StartOutput(int card, int freq, int stereo, int bit8)
{
        reserve_voices(1,0);
        switch(card)
        {
        case 0:	card=DIGI_AUTODETECT;break;
        case 1: card=DIGI_SB20;break;
        case 2: card=DIGI_SB10;break;
        case 3: card=DIGI_SBPRO;break;
        case 4: card=DIGI_SB16;break;
        case 5: card=DIGI_SOUNDSCAPE;break;
        case 6: card=DIGI_AUDIODRIVE;break;
        default:        printf("Error: Unknown sound driver %d!\n",card);
                        return 1;
        }
        if(install_sound(card,MIDI_NONE,NULL))
        {
                printf("Error: %s\n",allegro_error);
                return 1;
        }
        mult=1;
        while(SNDmixlen*mult<MINBUFSIZE)
        	mult++;
        stream=play_audio_stream(SNDmixlen*mult,bit8?8:16,stereo?TRUE:FALSE,
         freq,255,128);
        if(stream==NULL)
	        return 1;
        return 0;
}

static void StopOutput(void)
{
	stop_audio_stream(stream);
        remove_sound();
}

void Shutdown(void)
{
       	StopOutput();	//Shut down sound hardware
        allegro_exit();
        _setcursortype(_NORMALCURSOR);
        textattr(7);
}

int main(int argc, char **argv)
{
	int freq,card,gui,i,limit,v,voices,stereo,bit8,inlimit;
	double urate;
        char fn[64];
        unsigned char key;
        printf("OpenSPC v.301\n");
        printf(" Primary Author: Butcha\n");
        printf(" Other contributors: Cyber Warrior X, Crono, Kadar, Cait Sith 2\n");
        printf("\nThanks to:\n");
        printf("        Savoury SnaX and Charles Bilyu‚ for SNEeSe's SPC core\n");
        printf("        Shawn Hargreaves, et al, for Allegro\n\n");
        allegro_init();
        // Let's open the config file and get the data
        set_config_file("openspc.cfg");
        card=get_config_int(NULL,"setcard",0);
        freq=get_config_int(NULL,"setfreq",22050);
        urate=get_config_float(NULL,"seturate",100.0);
        stereo=get_config_int(NULL,"stereo",1);
        bit8=get_config_int(NULL,"bit8",0);
        gui=get_config_int(NULL,"setgui",0);
        ITdump=get_config_int(NULL,"setdump",0);
        fadespd=get_config_int(NULL,"fadespeed",1);
        ITrows=get_config_int(NULL,"IT_rows",200);
        SNDrvs=get_config_int(NULL,"reverse_stereo",0);
        clr_data=get_config_int(NULL,"clr_data",15);
        clr_label=get_config_int(NULL,"clr_label",7);
        clr_grph_lo=get_config_int(NULL,"clr_grph_lo",2);
        clr_grph_md=get_config_int(NULL,"clr_grph_md",14);
        clr_grph_hi=get_config_int(NULL,"clr_grph_hi",4);
	inlimit=get_config_int(NULL,"internal_limit",1);
        SNDmix=1;
        limit=0;
        voices=0;
        fn[0]=0;
        for(i=1;i<argc;i++)
        {
        	if(argv[i][0]=='-')
                    switch(argv[i][1])
                    {
                    case 'g':	i++;
                    		gui=atoi(argv[i]);
                                break;
                    case 'i': 	ITdump=1;break;
                    case 'u': 	i++;
                    		urate=atof(argv[i]);
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
                    case 's':	SNDrvs=1;
                    		break;
		    case 'l':	inlimit=0;
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
        SNDvmask=~voices;
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
        if(SPCInit(fn))	//Reset SPC and load state
        {
        	printf("Failed to initialize emulation!\n");
                exit(1);
        }
        if(!limit&&inlimit&&SPCtime)
                limit=SPCtime;
        if(SNDInit(freq,urate,0,stereo,bit8))	//0 means Allegro requires
	{					//UNSIGNED 16 bit data (weird)
                printf("Init Sound failed!\n");
		exit(1);
        }
        if(gui==2)
        {
		clrscr();
                _setcursortype(_NOCURSOR);
                textattr(clr_label);
                gotoxy(75,1);
                if(limit)
                	cprintf("/%2d:%02d\n",limit/60,limit%60);
                else	cprintf("/ INF\n");
		gotoxy(4,2);
		cprintf("SMP#  PITCH                 LEVEL\n");
                gotoxy(60,2);
                cprintf("PAN\n");
		gotoxy(2,16);
		cprintf("Press keys 1-8 to toggle voices, any other key to exit.\n");
        }
        else if(gui==1)
	{
        	InitScreen();
                if(limit)
		        textprintf(double_buffer,font,592,0,clr_label,
		          "/%2d:%02d",limit/60,limit%60);
                else	textprintf(double_buffer,font,592,0,clr_label,
                	  "/ INF");
                delay(1000);	//My monitor, and probably yours too, takes a
        }			//little while to switch modes
        else
        {
                if(limit)
                        printf("Time limit set at %d:%02d\n",limit/60,
                          limit%60);
                if(SPCname[0]||SPCtname[0]||SPCdname[0]||SPCcomment[0]||SPCdate[0])
                {
                        printf("ID info:\n");
                        printf("        Song name:              %s\n",SPCname);
                        printf("        Game name:              %s\n",SPCtname);
                        printf("        Person who Dumped SPC:  %s\n",SPCdname);
                        printf("        Comments:               %s\n",SPCcomment);
                        printf("        Dumped on date:         %s\n",SPCdate);
                }
                printf("\nPress keys 1-8 to toggle voices, any other key to exit.\n");
        }
        if(ITdump&&ITStart())
        {
                allegro_exit();
        	printf("Failed to init pattern buffers!\n");
                exit(1);
        }
	SNDNoteOn(SPC_DSP_Buffer[0x4c]); //Turn on voices that were on when saved
        seconds=SNDratecnt=0;
        if(StartOutput(card,freq,stereo,bit8))	//Begin playing
        {
        	allegro_exit();
                printf("Soundcard init failed!\n");
                exit(1);
        }
        clear_keybuf();
        
        for(;;)	//Main loop
        {
                if((SNDoptbuf=get_audio_stream_buffer(stream))!=NULL)
                {
                	for(i=0;i<mult;i++)
                	{
                		SNDMix();
                                SNDoptbuf+=bit8?(stereo?SNDmixlen<<1:SNDmixlen):(stereo?SNDmixlen<<2:SNDmixlen<<1);
                        }
                        free_audio_stream_buffer(stream);
                }
                else if(gui==1)
                	Status();    	//show the user whats going on
                else if(gui==2)
                	OldStatus();
                if(ITdump)
                	if(ITUpdate())	//dump buffers if neccessary
                		break;
                if(SNDratecnt>=urate)
                {
                	SNDratecnt-=urate;
                        seconds++;
                        if(seconds==limit)
                        	break;
                }
                if(kbhit())		//If key pressed...
                {
                	key=getch();
                        if((key-='1')<=7)
                        {
                       		SNDvmask^=(1<<key);	//...user wants to
	                        SNDNoteOff(1<<key);	//toggle a voice
                        }
                        else 	break;
       	        }
	}
        Shutdown();
	if(ITdump)
	{
                for(i=0;i<64;i++)
	        	if(fn[i]=='.')
                        {
                        	fn[i+1]='I';
                                fn[i+2]='T';
                                fn[i+3]=0;
                                break;
                        }
        	if(ITWrite(fn))
                       	printf("Failed at writing %s.\n",fn);
                else    printf("Wrote %s successfully.\n",fn);
	}
	return(0);	//Get the %#$@ outta here
}
