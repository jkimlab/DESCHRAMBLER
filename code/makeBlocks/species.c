#include "util.h"
#include "species.h"

int Spesz = 0;
int Spetag[MAXSPE];
int Chrassmz = 0;
int Spechrassm[MAXSPE];
char Spename[MAXSPE][100] = {"\0"};
char Treestr[500] = "\0";
char Treestr2[500] = "\0";
char Netdir[500] = "\0";
char Chaindir[500] = "\0";
int MINLEN = 0;
int HSACHR = 0;

int spe_idx(char *sname) {
	int i;
	for (i = 0; i < Spesz; i++)
		if (same_string(Spename[i], sname))
			break;
	if (i == Spesz)
		fatalf("unkonwn species %s", sname);
	return i;
}

int ref_spe_idx() {
	int i;
	for (i = 0; i < Spesz; i++)
		if (Spetag[i] == 0)
			break;
	if (i == Spesz)
		fatal("ref species not specified");
	return i;
}

// JK
int des_spe_idx() {
	int i;
	for (i = 0; i < Spesz; i++)
		if (Spetag[i] == 1)
			break;
	if (i == Spesz)
		fatal("des species not specified");
	return i;
}

void get_spename(char *configfile) {
	FILE *fp;
	char buf[500], sn[20];
	int tag, die, r, i, chrassm;
	
	fp = ckopen(configfile, "r");
	die = 0;
	while(fgets(buf, 500, fp)) {
		if (buf[0] == '>' && strstr(buf, "species") != NULL) {
			die = 1;
			while(fgets(buf, 500, fp)) {
				if (buf[0] == '#')
					continue;
				if (buf[0] == '\n')
					break;
				if (sscanf(buf, "%s %d %d", sn, &tag, &chrassm) != 3)
					fatalf("cannot parse species %s", buf);
				strcpy(Spename[Spesz], sn);
				Spetag[Spesz] = tag;

				Spechrassm[Spesz] = chrassm;
				if (chrassm > Chrassmz) Chrassmz = chrassm;
				++Spesz;
			}
		}
		if (die == 1)
			break;
	}
	fclose(fp);
	if (Spesz > MAXSPE)
		fatalf("MAXSPE %d too small (%d)", MAXSPE, Spesz);
	for (i = r = 0; i < Spesz; i++)
		if (Spetag[i] == 0)
			++r;
	if (r == 0)
		fatal("ref species not specified");
	if (r > 1)
		fatal("ref speices more than one");
}

void get_treestr(char *configfile) {
	FILE *fp;
	char buf[500];

	fp = ckopen(configfile, "r");
	while(fgets(buf, 500, fp)) {
		if (buf[0] == '>' && strstr(buf, "tree") != NULL) {
			if (fgets(buf, 500, fp) && sscanf(buf, "%s", Treestr) != 1)
				fatalf("missing tree string in config file.");
			break;
		}
	}
	fclose(fp);
	if (Treestr[0] == '\0')
		fatalf("missing tree string in config file.");
}

void get_treestr2(char *configfile) {
	FILE *fp;
	char buf[500];

	fp = ckopen(configfile, "r");
	while(fgets(buf, 500, fp)) {
		if (buf[0] == '>' && strstr(buf, "tree2") != NULL) {
			if (fgets(buf, 500, fp) && sscanf(buf, "%s", Treestr2) != 1)
				fatalf("missing tree string in config file.");
			break;
		}
	}
	fclose(fp);
	if (Treestr2[0] == '\0')
		fatalf("missing tree string in config file.");
}

void get_netdir(char *configfile) {
	FILE *fp;
	char buf[500];
	
	fp = ckopen(configfile, "r");
	while(fgets(buf, 500, fp)) {
		if (buf[0] == '>' && strstr(buf, "netdir") != NULL) {
			if (fgets(buf, 500, fp) && sscanf(buf, "%s", Netdir) != 1)
				fatalf("missing netdir string in config file.");
			break;
		}
	}
	fclose(fp);
	if (Netdir[0] == '\0')
		fatalf("missing netdir string in config file.");
}

void get_minlen(char *configfile) {
	FILE *fp;
	char buf[500];
	
	fp = ckopen(configfile, "r");
	while(fgets(buf, 500, fp)) {
		if (buf[0] == '>' && strstr(buf, "resolution") != NULL) {
			if (fgets(buf, 500, fp) && sscanf(buf, "%d", &MINLEN) != 1)
				fatalf("missing resolution string in config file.");
			break;
		}
	}
	fclose(fp);
	if (MINLEN == 0)
		fatalf("missing resolution string in config file.");
}

void get_numchr(char *configfile) {
	FILE *fp;
	char buf[500];
	
	fp = ckopen(configfile, "r");
	while(fgets(buf, 500, fp)) {
		if (buf[0] == '>' && strstr(buf, "numchr") != NULL) {
			if (fgets(buf, 500, fp) && sscanf(buf, "%d", &HSACHR) != 1)
				fatalf("missing numchr string in config file.");
			break;
		}
	}
	fclose(fp);
	if (HSACHR == 0)
		fatalf("missing numchr string in config file.");
}

void get_chaindir(char *configfile) {
	FILE *fp;
	char buf[500];
	
	fp = ckopen(configfile, "r");
	while(fgets(buf, 500, fp)) {
		if (buf[0] == '#' || buf[0] == '\n')
			continue;
		if (buf[0] == '>' && strstr(buf, "chaindir") != NULL) {
			if (fgets(buf, 500, fp) && sscanf(buf, "%s", Chaindir) != 1)
				fatalf("missing chaindir string in config file.");
			break;
		}
	}
	fclose(fp);
	if (Chaindir[0] == '\0')
		fatalf("missing chaindir string in config file.");
}

void free_seg_list(struct seg_list *sg) {
	struct seg_list *p, *q;
	p = sg;
	for (;;) {
		q = p->next;
		if (p->cidlist != NULL)
			free(p->cidlist);
		free(p);
		if (q == NULL)
			break;
		else
			p = q;
	}
}

void free_block_list(struct block_list *blk) {
	struct block_list *p, *q;
	int i;
	p = blk;
	for (;;) {
		q = p->next;
		for (i = 0; i < Spesz; i++)
			if (p->speseg[i] != NULL)
				free_seg_list(p->speseg[i]);
		free(p);
		if (q == NULL)
			break;
		else
			p = q;
	}
}

struct block_list *allocate_newblock() {
	struct block_list *nb;
	int i;
	nb = (struct block_list *)ckalloc(sizeof(struct block_list));
	nb->next = NULL;
	for (i = 0; i < Spesz; i++)
		nb->speseg[i] = NULL;
	nb->isdup = nb->id = 0;
	return nb;
}

struct block_list *get_block_list(char *fname) {
	FILE *fp;
	char buf[5000], spe[50];
	int idx, num, st, mid, sid, cid, cnum, i, j;
	char *pt;
	struct block_list *blist, *nb, *last;
	struct seg_list *p, *q;
	
	blist = nb = last = NULL; 
	fp = ckopen(fname, "r");
	while(fgets(buf, 5000, fp)) {
		if (buf[0] == '\n' || buf[0] == '#')
			continue;
		if (buf[0] == '>') {
			nb = allocate_newblock();
			if (blist == NULL)
				blist = last = nb;
			else {
				last->next = nb;
				last = nb;
			}
			if (sscanf(buf, ">%d", &num) == 1)
				nb->id = num;
			continue;
		}
		p = (struct seg_list *)ckalloc(sizeof(struct seg_list));
		p->chnum = 0;
		p->cidlist = NULL;
		p->next = NULL;
		if (sscanf(buf, "%[^.].%[^:]:%d-%d %c",
					spe, p->chr, &(p->beg), &(p->end), &(p->orient)) != 5)
			fatalf("%s", buf);
		if ((pt = strchr(buf, '[')) != NULL) {
			if (sscanf(pt, "[%d]", &st) != 1)
				fatalf("cannot parse: %s", buf);
			p->state = st;
			++pt;
			if ((pt = strchr(pt, '[')) != NULL) {
				if (sscanf(pt, "[%d.%d]", &mid, &sid) != 2)
					fatalf("cannot parse: %s", buf);
				p->id = mid;
				p->subid = sid;
				++pt;
			}
		}
		else
			p->id = nb->id;
		if ((pt = strchr(buf, '(')) != NULL) {
			if (sscanf(pt, "(%d)", &cid) != 1)
				fatalf("cannot parse: %s", buf);
			p->chid = cid;
		}
		if ((pt = strchr(buf, '{')) != NULL) {
			++pt;
			if (sscanf(pt, "%d", &cnum) != 1)
				fatalf("cannot parse: %s", buf);
			p->chnum = cnum;
			p->cidlist = (int *)ckalloc(sizeof(int) * cnum);
			j = 0;
			while((pt = strchr(pt, ',')) != NULL) {
				++pt;
				if (sscanf(pt, "%d", &i) != 1)
					fatalf("cannot parse: %s", buf);
				p->cidlist[j++] = i;
			}
			if (j != cnum)
				fatalf("not enough cid: %s", buf);
		}
		else {
			p->chnum = 0;
			p->cidlist = NULL;
		}
		idx = spe_idx(spe);
		if (nb->speseg[idx] == NULL)
			nb->speseg[idx] = p;
		else {
			for (q = nb->speseg[idx]; q->next != NULL; q = q->next)
					;
			q->next = p;
		}
	}
	fclose(fp);
	assign_states(blist);
	assign_orders(blist);
	return blist;
}

void assign_states(struct block_list *head) {
	struct block_list *blk;
	struct seg_list *sg;
	int i;
	
	for (blk = head; blk != NULL; blk = blk->next) {
		for (i = 0; i < Spesz; i++) {
			if (blk->speseg[i] != NULL) {
				blk->speseg[i]->state = FIRST;
				for (sg = blk->speseg[i]->next; sg != NULL && sg->next != NULL; sg = sg->next)
					sg->state = MIDDLE;
				if (sg != NULL)
					sg->state = LAST;
				if (blk->speseg[i]->next == NULL)
					blk->speseg[i]->state = BOTH;
			}
		}
	}
}

void assign_orders(struct block_list *head) {
	struct block_list *blk;
	struct seg_list *sg;
	int id, subid, i;
	for (id = 0, blk = head; blk != NULL; blk = blk->next) {
		blk->id = ++id;
		for (i = 0; i < Spesz; i++) {
			subid = 0;
			for (sg = blk->speseg[i]; sg != NULL; sg = sg->next) {
				sg->id = blk->id;
				sg->subid = ++subid;
			}
		}
	}
}

void merge_chlist(struct block_list *head) {
	struct block_list *blk;
	struct seg_list *sg;
	int buf[5000], j, prev, i, k;
	
	for (blk = head; blk != NULL; blk = blk->next) {
		for (i = 0; i < Spesz; i++) {
			if (Spetag[i] == 0)
				continue;
			for (sg = blk->speseg[i]; sg != NULL; sg = sg->next) {
				prev = j = 0;
				for (k = 0; k < sg->chnum; k++) {
					if (sg->cidlist[k] != prev) {
						buf[j++] = sg->cidlist[k];
						prev = sg->cidlist[k];
					}
				}
				if (j != sg->chnum) {
					sg->chnum = j;
					free(sg->cidlist);
					sg->cidlist = (int *)ckalloc(sizeof(int) * j);
					for (k = 0; k < j; k++)
						sg->cidlist[k] = buf[k];			
				}
			}
		}
	}
	
}

