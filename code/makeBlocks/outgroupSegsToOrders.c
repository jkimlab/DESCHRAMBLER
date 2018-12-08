/* *****************************************************************
 * from block list to orders for outgroup species
 * ****************************************************************/

#include "util.h"
#include "species.h"

int main(int argc, char* argv[]) {
	int i, j;
	struct block_list *blkhead, *bk;
	struct seg_list ***head;
	struct seg_list *pp, *p, *q, *sg;
	int total[MAXSPE];
	
	if (argc != 3)
		fatal("arg: config.file block-list");
	
	head = malloc(sizeof(struct seg_list**) * MAXSPE);
	for (j = 0; j < MAXSPE; j++) {
		total[j] = 0;
		head[j] = malloc(sizeof(struct seg_list*) * MAXCHR);
		for (i = 0; i < MAXCHR; i++)
			head[j][i] = NULL;
	}
	get_spename(argv[1]);
	blkhead = get_block_list(argv[2]);

	for (bk = blkhead; bk != NULL; bk = bk->next) {
		for (i = 0; i < Spesz; i++) {
			if (Spetag[i] != 2)
				continue;
			for (sg = bk->speseg[i]; sg != NULL; sg = sg->next) {
				for (j = 0; j < total[i]; j++)
					if (same_string((head[i][j])->chr, sg->chr))
						break;
				q = (struct seg_list *)ckalloc(sizeof(struct seg_list));
				q->cidlist = NULL;
				q->next = NULL;
				q->id = sg->id;
				q->subid = sg->subid;
				q->beg = sg->beg;
				q->end = sg->end;
				q->orient = sg->orient;
				strcpy(q->chr, sg->chr);
	
				if (j == total[i]) {
					head[i][j] = q;
					++total[i];
				}
				else {
					pp = NULL;
					for (p = head[i][j]; p != NULL; p = p->next) {
						if ((pp == NULL && q->beg < p->beg)
								|| (pp != NULL && q->beg < p->beg && q->beg > pp->beg))
							break;
						pp = p;
					}
					if (pp == NULL) {
						q->next = p;
						head[i][j] = q;
					}
					else {
						q->next = pp->next;
						pp->next = q;
					}
				}
			}
		}
	}

	for (i = 0; i < Spesz; i++) {
		if (Spetag[i] != 2)
			continue;
		printf(">%s\n", Spename[i]);
		for (j = 0; j < total[i]; j++) {
			printf("# %s\n", head[i][j]->chr);
			for (p = head[i][j]; p != NULL; p = p->next) {
				if (p->orient == '+')
					printf("%d.%d ", p->id, p->subid);
				else
					printf("-%d.%d ", p->id, p->subid);
			}
			printf("$\n");
		}
		printf("\n");
	}

	for (i = 0; i < Spesz; i++) {
		for (j = 0; j < total[i]; j++)
			free_seg_list(head[i][j]);
	}

	free_block_list(blkhead);
	
	return 0;
}
