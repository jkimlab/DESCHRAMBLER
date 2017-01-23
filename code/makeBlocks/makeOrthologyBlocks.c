/* *****************************************************************
 * The program generates orthology blocks. In each orthology block,
 * there is one piece of genomic sequence from descendant species.
 * In addition, it contains zero or multiple pieces from outgroup 
 * species. 
 * ****************************************************************/

#include "util.h"
#include "species.h"

static int rs;

int random_piece(struct seg_list *sg) {
	char buf[500];
	int ru = 0;

	strncpy(buf, sg->chr, 3);
	buf[3] = '\0';

	if (!same_string(buf, "chr")) ru = 1; 
	else if (strstr(sg->chr, "chrUn") != NULL || strstr(sg->chr, "random") || strstr(sg->chr, "chrY") != NULL || strstr(sg->chr, "chrM") != NULL)
		ru = 1;
	
	return ru;
}

int illegal_block(struct block_list *blk) {
    struct block_list *p;
    int i, len, illegal, numinspc, totalinspc;

    illegal = 0;
    p = blk;
    len = p->speseg[rs]->end - p->speseg[rs]->beg;
    if (len < MINLEN) {
        illegal = 1;
	}
    
	for (i = 0; i < Spesz; i++) {
        if (Spetag[i] == 1 && p->speseg[i] != NULL
                && p->speseg[i]->end - p->speseg[i]->beg < len * MINDESSEG) {
			return 1;
		}
    }

	numinspc = 0;
	totalinspc = 0;
    for (i = 0; i < Spesz; i++) {
		if (Spetag[i] == 0 || Spetag[i] == 1) totalinspc++;

        if (Spetag[i] == 1 && (p->speseg[i] == NULL
                || p->speseg[i]->end - p->speseg[i]->beg < len * MINDESSEG)) {
			continue;
		}

		if (Spetag[i] == 0 || Spetag[i] == 1) numinspc++;
    }
    
	return illegal;
}

void trim(struct block_list **blockhead) {
	struct block_list *p, *q;
	q = NULL;
	for (p = *blockhead; p != NULL;) {
		if (illegal_block(p)) {
			if (q == NULL) {
				q = p;
				p = p->next;
				*blockhead = p;
				q->next = NULL;
				free_block_list(q);
				q = NULL;
			}
			else {
				q->next = p->next;
				p->next = NULL;
				free_block_list(p);
				p = q->next;
			}
		}
		else {
			q = p;
			p = p->next;
		}
	}
}

int overlap(struct seg_list *x, struct seg_list *y) {
	int ovlp;
	int b1, e1, b2, e2, len1, len2;
	b1 = x->beg;
	e1 = x->end;
	b2 = y->beg;
	e2 = y->end;
	len1 = e1 - b1;
	len2 = e2 - b2;
	if (same_string(x->chr, y->chr) &&
			((b1 >= b2 && e1 <= e2) || (b1 <= b2 && e1 >= e2)
				|| (b1 < b2 && e1 > b2 && e1 - b2 > MINOVL * MIN(len1, len2))
				|| (b1 < e2 && e1 > e2 && e2 - b1 > MINOVL * MIN(len1, len2)) ))
		ovlp = 1;
	else
		ovlp = 0;
	return ovlp;
}

int contain_all(struct block_list *blst) {
	int i;
	for (i = 0; i < Spesz; i++)
		if (Spetag[i] == 1 && blst->speseg[i] == NULL)
			break;
	return (i == Spesz) ? 1 : 0;
}

int messy_piece(struct seg_list *sg, struct block_list *blk, int idx) {
	struct block_list *b;
	struct seg_list *p;
	int b1, e1, b2, e2, len1, len2, messy;
	b1 = sg->beg;
	e1 = sg->end;
	len1 = e1 - b1;
	messy = 0;
	for (b = blk; b != NULL; b = b->next) {
		if ((p = b->speseg[idx]) != NULL ) { 
			if (p == sg) 
				continue;
			b2 = p->beg;
			e2 = p->end;
			len2 = e2 - b2;
			if (same_string(p->chr, sg->chr) &&
					((b1 >= b2 && e1 <= e2)
				|| (b1 <= b2 && e1 <= e2 && e1 > b2 && b2 - b1 < AFEW * len1 && len1 <= len2)
				|| (b1 >= b2 && e1 >= e2 && b1 < e2 && e1 - e2 < AFEW * len1 && len1 <= len2))) { 
				messy = 1;
				break;
			}
		}
	}
	return messy;
}

void clean_up(struct block_list **head) {
	struct block_list *p, *q;
	int i, lenp, lenq, stotal, ovtotal;
	for (p = *head; p != NULL; p = p->next) {
		for (q = p->next; q != NULL; q = q->next) {
			stotal = 0;
			ovtotal = 0;
			for (i = 0; i < Spesz; i++) {
				if ((Spetag[i] == 0 || Spetag[i] == 1) && p->speseg[i] != NULL && q->speseg[i] != NULL) {
					stotal++;
					if (overlap(p->speseg[i], q->speseg[i])) ovtotal++;
				}
			}
			lenp = p->speseg[rs]->end - p->speseg[rs]->beg;
			lenq = q->speseg[rs]->end - q->speseg[rs]->beg;
			if (stotal == ovtotal) {
				if (lenp < lenq)
					p->isdup = 1;
				else
					q->isdup = 1;
			}
		}
	}
	
	q = NULL;
	for (p = *head; p != NULL;) {
		if (p->isdup) {
			if (q == NULL) {
				q = p;
				p = p->next;
				*head = p;
				q->next = NULL;
				free_block_list(q);
				q = NULL;
			}
			else {
				q->next = p->next;
				p->next = NULL;
				free_block_list(p);
				p = q->next;
			}
		}
		else {
			q = p;
			p = p->next;
		}
	}
}

void clean_up_again(struct block_list *head) {
	struct block_list *p;
	struct seg_list *sg, *tg;
	int i;
	for (p = head; p != NULL; p = p->next) {
		for (i = 0; i < Spesz; i++) {
			if (i == rs)
				continue;
			for (sg = p->speseg[i]; sg != NULL; ) {
				if ((Spechrassm[i] == 1 && random_piece(sg)) || messy_piece(sg, head, i)) {
					if (sg == p->speseg[i]) {
						p->speseg[i] = sg->next;
						free(sg);
						tg = sg = p->speseg[i];
					}
					else {
						tg->next = sg->next;
						free(sg);
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

int main(int argc, char *argv[]) {
	int i;
	struct seg_list *sg;
	struct block_list *commonblocklist, *blist;
	
	if (argc != 3)
		fatal("args: configure-file building-block-list");

	get_spename(argv[1]);
	get_minlen(argv[1]);
	rs = ref_spe_idx();

	commonblocklist = get_block_list(argv[2]);
	
	clean_up(&commonblocklist);
	clean_up_again(commonblocklist);
	trim(&commonblocklist);

	assign_states(commonblocklist);
	assign_orders(commonblocklist);
	
	for (blist = commonblocklist; blist != NULL; blist = blist->next) {
		printf(">%d\n", blist->id);
		for (i = 0; i < Spesz; i++) {
			for (sg = blist->speseg[i]; sg != NULL; sg = sg->next) 
				printf("%s.%s:%d-%d %c [%d] (%d)\n", 
						Spename[i], sg->chr, sg->beg, sg->end, sg->orient, sg->state, sg->chid);
		}
		printf("\n");
	}

	free_block_list(commonblocklist);

	return 0;
}
