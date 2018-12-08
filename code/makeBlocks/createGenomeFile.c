/* *****************************************************************
 * 1) create Genome file to be used in inferring CARs.
 * 2) generate species.joins files.
 * ****************************************************************/

#include "util.h"
#include "species.h"

void print_join(FILE *fp, int l, char ol, int r, char or) {
	if (l == r)
		return;
	if (ol == '-')
		l = -l;
	fprintf(fp, "%*d", 5, l);
	if (or == '-')
		r = -r;
	fprintf(fp, "\t%*d\n", 5, r);
}

int main(int argc, char* argv[]) {
	FILE *jfp;
	int i, j, count;
	char buf[500];
	struct seg_list ***head;
	struct seg_list *pp, *p, *q, *sg;
	struct block_list *blkhead, *bk;
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
				q->state = sg->state;
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
		if (Spetag[i] == 2)
			continue;
		printf(">%s\t%d\n", Spename[i], total[i]);
		for (j = 0; j < total[i]; j++) {
			printf("# %s\n", head[i][j]->chr);
			for (p = head[i][j]; p != NULL; p = p->next) {
				if (p->orient == '+')
					printf("%d ", p->id);
				else
					printf("-%d ", p->id);
			}
			printf("$\n");
		}
		printf("\n");
	}
	
	for (count = 0, bk = blkhead; bk != NULL; bk = bk->next)
		++count;

	for (i = 0; i < Spesz; i++) {
		sprintf(buf, "%s.joins", Spename[i]);
		jfp = ckopen(buf, "w");
		fprintf(jfp, "#%d\n", count);
		for (j = 0; j < total[i]; j++) {
			p = head[i][j];
			if (p == NULL)
				continue;
			if (Spetag[i] != 2)
				if ((p->state == FIRST && p->orient == '+') || p->state == BOTH
						|| (p->state == LAST && p->orient == '-'))
					print_join(jfp, 0, '+', p->id, p->orient);
			for (; p->next != NULL; p = p->next) {
				q = p->next;
				if (((p->state == FIRST && p->orient == '-') || (p->state == LAST && p->orient == '+'))
						&& ((q->state == FIRST && q->orient == '+') || (q->state == LAST && q->orient == '-')))
					print_join(jfp, p->id, p->orient, q->id, q->orient);
				if (p->state == BOTH && ((q->state == FIRST && q->orient == '+')
					||(q->state == LAST && q->orient == '-')))
					print_join(jfp, p->id, p->orient, q->id, q->orient);
				if (((p->state == FIRST && p->orient == '-') || (p->state == LAST && p->orient == '+'))
						&& q->state == BOTH)
					print_join(jfp, p->id, p->orient, q->id, q->orient);
				if (p->state == BOTH && q->state == BOTH)
					print_join(jfp, p->id, p->orient, q->id, q->orient);
			}
			if (Spetag[i] != 2)
				if (p->state == BOTH || (p->state == LAST && p->orient == '+')
						|| (p->state == FIRST && p->orient == '-'))
					print_join(jfp, p->id, p->orient, 0, '+');
		}
		fclose(jfp);
	}

	for (i = 0; i < Spesz; i++) {
		for (j = 0; j < total[i]; j++)
			free_seg_list(head[i][j]);
	}
	
	free_block_list(blkhead);

	return 0;
}
