/* *********************************************************
 * make the pieces from outgroups tidy.
 * ********************************************************/

#include "util.h"
#include "species.h"

struct perm_array {
	int id, sid;
};

void merge_segs(struct block_list *blkhead, int id, int ss, int start, int terminal) {
	struct block_list *p;
	struct seg_list *b, *nb;
	int j;
	
	if (terminal < start)
		fatalf("DIE: start > terminal %d %d", start, terminal);
	
	for (p = blkhead; p != NULL; p = p->next) 
		if (p->id == id)
			break;
	
	for (b = p->speseg[ss]; b != NULL; b = b->next)
		if (b->subid == start)
			break;
	
	if (b == NULL)
		fatalf("DIE: illegal subid %d.%d", id, start);
	if (start == terminal) {
		b->chnum = 1;
		b->cidlist = (int *)ckalloc(sizeof(int) * b->chnum);
		b->cidlist[0] = b->chid;
		return;
	}

	b->chnum = terminal - start + 1;
	b->cidlist = (int *)ckalloc(sizeof(int) * b->chnum);
	nb = b;
	j = 0;
	while (nb != NULL && nb->subid <= terminal) {
		b->cidlist[j++] = nb->chid;
		nb = nb->next;
	}

	for (nb = b->next; nb != NULL; ) {
		if (nb->subid <= terminal) {
			b->beg = MIN(b->beg, nb->beg);
			b->end = MAX(b->end, nb->end);
			b->next = nb->next;
			nb->next = NULL;
			free_seg_list(nb);
			nb = b->next;
		}
		else
			break;
	}
}

void remove_tiny_pieces(struct block_list *head) {
  struct block_list *p;
	struct seg_list *sg, *tg;
	int i, len, reflen, rs;
	rs = ref_spe_idx();
	for (p = head; p != NULL; p = p->next) {
		reflen = p->speseg[rs]->end - p->speseg[rs]->beg;
		for (i = 0; i < Spesz; i++) {
			if (Spetag[i] != 2)
				continue;
			for (sg = p->speseg[i]; sg != NULL; ) {
				len = sg->end - sg->beg;
				if (len < MINOUTSEG * reflen) {
					if (sg == p->speseg[i]) {
						p->speseg[i] = sg->next;
						sg->next = NULL;
						free_seg_list(sg);
						tg = sg = p->speseg[i];
					}
					else {
						tg->next = sg->next;
						sg->next = NULL;
						free_seg_list(sg);
						sg = tg->next;
					}
				}
				else {
					tg = sg;
					sg = sg->next;
				}
			}
		}
	} 
}

int main(int argc, char* argv[]) {
	FILE *orthorder;
	char buf[100000], spe[20];
	struct block_list *blkhead, *bk;
	int i, j, num, snum, total, k, start, terminal;
	int outorder[MAXSPE];
	char *pt;
	struct seg_list *p;
	struct perm_array **pmay;
	
	if (argc != 4)
		fatal("args: config.file conserved-segs outgroup-segs-orders");

	get_spename(argv[1]);
	blkhead = get_block_list(argv[2]);
	
	pmay = malloc(sizeof(struct perm_array*) * MAXSPE);
    	for (i = 0; i < MAXSPE; i++) {
        	pmay[i] = malloc(sizeof(struct perm_array) * (MAXORDER*10));
    	}
	
	for (total = 0, bk = blkhead; bk != NULL; bk = bk->next)
		++total;

	for (i = 0; i < Spesz; i++) {
		if (Spetag[i] != 2)
			continue;
		outorder[i] = 0;
		for (j = 0; j < MAXORDER; j++)
			pmay[i][j].id = pmay[i][j].sid = 0;
	}
	
	orthorder = ckopen(argv[3], "r");
	while (fgets(buf, 100000, orthorder)) {
		if (buf[0] == '\n' || buf[0] == '#')
			continue;
		if (buf[0] == '>') {
			if (sscanf(buf, ">%s", spe) != 1)
				fatalf("cannot parse: %s", buf);
			i = spe_idx(spe);
			continue;
		}
		pt = buf;
		while (sscanf(pt, "%d.%d", &num, &snum) == 2) {
			j = ++outorder[i];
			pmay[i][j].id = num;
			pmay[i][j].sid = snum;
			pt = strchr(pt, ' ');
			if (pt == NULL || (pt != NULL && *(pt+1) == '$'))
				break;
			else
				pt++;
		}
		++outorder[i];
	}
	fclose(orthorder);
	
	for (i = 0; i < Spesz; i++) {
		if (Spetag[i] != 2)
			continue;
		start = terminal = 1;
		for (j = 1; j <= total; j++) {
			for (;;) {
				for (k = 0; k <= outorder[i]; k++)
					if (abs(pmay[i][k].id) == j && pmay[i][k].sid == terminal)
						break;
				if (k > outorder[i]) {
					start = terminal = 1;
					break;
				}
				if ((pmay[i][k].id > 0 && pmay[i][k+1].id == pmay[i][k].id && pmay[i][k+1].sid == terminal + 1)
					|| (pmay[i][k].id < 0 && pmay[i][k-1].id == pmay[i][k].id && pmay[i][k-1].sid == terminal + 1))
					terminal++;
				else {
					merge_segs(blkhead, j, i, start, terminal);
					start = terminal + 1;
					terminal = start;
				}
			}
		}
	}
	
	remove_tiny_pieces(blkhead);

	assign_states(blkhead);
	merge_chlist(blkhead);
	for (bk = blkhead; bk != NULL; bk = bk->next) {
		printf(">%d\n", bk->id);
		for (i = 0; i < Spesz; i++) {
			for (p = bk->speseg[i]; p != NULL; p = p->next) {
				printf("%s.%s:%d-%d %c [%d] [%d.%d]", 
						Spename[i], p->chr, p->beg, p->end, p->orient, p->state, p->id, p->subid);
				if (Spetag[i] == 0){
					printf("\n");
					continue;
				}
				printf(" {%d", p->chnum);
				for (j = 0; j < p->chnum; j++)
					printf(",%d", p->cidlist[j]);
				printf("}\n");
			}
		}
		printf("\n");
	}
	free_block_list(blkhead);
	
	for (i = 0; i < MAXSPE; i++) free(pmay[i]);
    	free(pmay);
	
	return 0;
}
