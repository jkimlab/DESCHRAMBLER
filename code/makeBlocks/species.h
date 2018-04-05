/* ****************************************
 * a configuration file is needed
 * ***************************************/

#ifndef _SPE_H_
#define _SPE_H_

#define MAXSPE		100		
#define MAXCHR		50000	
#define MAXORDER	900000	

#define MINOVL		0.4
#define AFEW			0.3
#define MINOUTSEG	0.05
#define MINDESSEG	0.05
#define MAXNUM		500000000

#define ORT(x) ((x == '+') ? '-' : '+')

enum segstate {FIRST = 0, LAST, BOTH, MIDDLE};

struct seg_list {
	int id, beg, end, subid, chid, chnum;
	int *cidlist;
	char chr[50];
	char orient;
	enum segstate state;
	struct seg_list *next;
};

struct block_list {
	int id, isdup;
	int left, right;
	struct seg_list *speseg[MAXSPE];
	struct block_list *next;
};

extern int Spesz;	
extern char Spename[MAXSPE][100];	
extern int Spetag[MAXSPE];	
extern int Chrassmz;	 
extern int Spechrassm[MAXSPE]; 
extern char Treestr[500];	
extern char Treestr2[500];
extern char Netdir[500];	
extern char Chaindir[500];	
extern int MINLEN;
extern int HSACHR;

int spe_idx(char *sname);	
int ref_spe_idx();  
int des_spe_idx();	
void get_spename(char *configfile);	
void get_treestr(char *configfile);	
void get_treestr2(char *configfile);
void get_chaindir(char *configfile);	
void get_netdir(char *configfile);	
void get_minlen(char *configfile);	
void get_numchr(char *configfile);	

struct block_list *get_block_list(char *block_file);
struct block_list *allocate_newblock();
void assign_states(struct block_list *blk);
void assign_orders(struct block_list *blk);
void merge_chlist(struct block_list *blk);
void free_seg_list(struct seg_list *sg);
void free_block_list(struct block_list *blk);

#endif
