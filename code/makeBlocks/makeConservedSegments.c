#include "util.h"
#include "species.h"

void merge_blocks(struct block_list *blkhead, int start, int terminal) {
	struct block_list *p, *q;
	struct seg_list *b;
	int i, j;
	if (terminal < start)
		fatalf("DIE: start >terminal %d %d", start, terminal);
	
	for (p = blkhead; p != NULL; p = p->next) 
		if (p->id == start)
			break;
	
	if (start == terminal) {
		for (i = 0; i < Spesz; i++) {
			if (Spetag[i] == 1) {
				b = p->speseg[i];
				if (b != NULL) {
					b->chnum = 1;
					b->cidlist = (int *)ckalloc(sizeof(int) * b->chnum);
					b->cidlist[0] = b->chid;
				}
			}
		}
		return;
	}

	for (q = p; q != NULL && q->id <= terminal; q = q->next) {
		for (i = 0; i < Spesz; i++) {
			if (Spetag[i] == 2)
				continue;
			if (q->speseg[i]->next != NULL)
				fatalf("DIE: illegal block %d", q->id);
		}
	}

	for (i = 0; i < Spesz; i++) {
		q = p;
		if (Spetag[i] == 1) {
			b = q->speseg[i];
			b->chnum = terminal - start + 1;
			b->cidlist = (int *)ckalloc(sizeof(int) * b->chnum);
			j = 0;
			while (q != NULL && q->id <= terminal) {
				b->cidlist[j++] = q->speseg[i]->chid;
				q = q->next;
			}
		}
	}

	q = p->next;
	while (q != NULL && q->id <= terminal) {
		p->next = q->next;
		q->next = NULL;
		for (i = 0; i < Spesz; i++) {
			if (Spetag[i] == 2)
				continue;
			p->speseg[i]->beg = MIN(p->speseg[i]->beg, q->speseg[i]->beg);
			p->speseg[i]->end = MAX(p->speseg[i]->end, q->speseg[i]->end);
		}
		for (i = 0; i < Spesz; i++) {
			if (Spetag[i] != 2)
				continue;
			if (p->speseg[i] == NULL)
				p->speseg[i] = q->speseg[i];
			else {
				for (b = p->speseg[i]; b->next != NULL; b = b->next)
					;
				b->next = q->speseg[i];
			}
		}
		for (i = 0; i < Spesz; i++)
			q->speseg[i] = NULL;
		free_block_list(q);
		q = p->next;
	}
}

int main(int argc, char* argv[]) {
	FILE *orthorder;
	char buf[50000], spe[20];
	struct block_list *blkhead, *blklast, *s;
	int i, j, rs, num, total, k, terminal, count, **perm;
	int status[MAXSPE];
	char *pt;
	struct seg_list *p;
	
	if (argc != 4)
		fatal("args: config.file orthology-blocks orthology-orders");

	blkhead = blklast = s = NULL;
	total = count = 0;
	get_spename(argv[1]);
	rs = ref_spe_idx();
	blkhead = get_block_list(argv[2]);
	
	for (s = blkhead; s != NULL; s = s->next)
		++total;
		
	perm = malloc(sizeof(int*) * MAXSPE);
	for (i = 0; i < Spesz; i++) {
		perm[i] = malloc(sizeof(int) * MAXORDER);
		if (Spetag[i] == 2)
			continue;
		for (j = 0; j < MAXORDER; j++)
			perm[i][j] = 0;
	}

	orthorder = ckopen(argv[3], "r");
	while (fgets(buf, 50000, orthorder)) {
		if (buf[0] == '\n' || buf[0] == '#')
			continue;
		if (buf[0] == '>') {
			if (sscanf(buf, ">%s", spe) != 1)
				fatalf("cannot parse: %s", buf);
			i = spe_idx(spe);
			j = 1;
			continue;
		}
		pt = buf;
		while (sscanf(pt, "%d", &num) == 1) {
			perm[i][j] = num;
			j++;
			pt = strchr(pt, ' ');
			if (pt == NULL || (pt != NULL && *(pt+1) == '$'))
				break;
			else
				pt++;
		}
		j++;
	}
	fclose(orthorder);

	terminal = 1;
	while (terminal <= total) {
		for (i = 0; i < Spesz; i++)
			status[i] = 0;
		for (i = 0; i < Spesz; i++) {
			if (Spetag[i] == 2)
				continue;
			for (k = 0; k < MAXORDER; k++)
				if (abs(perm[i][k]) == terminal)
					break;
			if ((perm[i][k] > 0 && perm[i][k+1] == terminal + 1)
				|| (perm[i][k] < 0 && perm[i][k-1] == -terminal - 1))
				status[i] = 1;
		}
		for (i = 0; i < Spesz; i++) {
			if (i == rs || Spetag[i] == 2)
				continue;
			status[rs] = status[rs] & status[i];
		}
		terminal++;
	}

	assign_states(blkhead);
	assign_orders(blkhead);

	for (s = blkhead; s != NULL; s = s->next) {
		printf(">%d\n", s->id);
		for (i = 0; i < Spesz; i++) {
			for (p = s->speseg[i]; p != NULL; p = p->next) {
				printf("%s.%s:%d-%d %c [%d]", Spename[i], p->chr,
						p->beg, p->end, p->orient, p->state);
				if (Spetag[i] == 0) {
					printf("\n");
					continue;
				}
				else if (Spetag[i] == 1) {
					printf(" {%d", p->chnum);
					for (j = 0; j < p->chnum; j++)
						printf(",%d", p->cidlist[j]);
					printf("}\n");
				}
				else {
					printf(" (%d)\n", p->chid);
				}
			}
		}
		printf("\n");
	}
	
	free_block_list(blkhead);

	return 0;
}
