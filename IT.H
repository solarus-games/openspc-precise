#ifndef IT
#define IT

#define NUM_PATT_BUFS 3

typedef struct {
	int mask,pitch,lvol,rvol;
        unsigned char note;
} itdata;

extern itdata ITdata[8];
//Temp memory for patterns before going to file
extern unsigned char *ITpattbuf[NUM_PATT_BUFS];
extern int ITpattlen[NUM_PATT_BUFS];	//lengths of each pattern
extern int ITlastmasks[16];		//Used for pattern compression
extern int ITcurbuf,ITbufpos,ITcurrow;	//Pointers into temp pattern buffers
extern int ITrows;			//Number of rows per pattern
extern int ITdump;

int ITStart(void);	//Opens temp file, inits writing
int ITUpdate(void);	//Dumps pattern buffers to file
int ITWrite(char *fn);	//Stops recording and writes IT file from temp data

#endif