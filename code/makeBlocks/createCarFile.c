#include "util.h"
#include "species.h"

static void print_block(int t, struct block_list *b, int id) {
	struct block_list *p;
	struct seg_list *s, *pr, *r, *q;
	int orient;
	
	orient = (id > 0) ? 1 : 0;

	for (p = b; p != NULL; p = p->next) {
		if (p->id == abs(id)) {
			if (t == ref_spe_idx()) {
				printf("%s.%s:%d-%d", 
					Spename[t],  p->speseg[t]->chr, 
					p->speseg[t]->beg, p->speseg[t]->end);
				if (orient == 1)
					printf(" + [%d]\n", p->id);
				else
					printf(" - [%d]\n", p->id);
			}
			else {
				if (orient  == 0) {
					pr = NULL;
					r = p->speseg[t];
					while (r != NULL) {
						q = r->next;
						r->next = pr;
						pr = r;
						r = q;
					}
					p->speseg[t] = pr;
				}
				for (s = p->speseg[t]; s != NULL; s = s->next) {
					printf("%s.%s:%d-%d", Spename[t], s->chr, s->beg, s->end);
					if (orient == 1)
						printf(" %c [%d]\n", s->orient, p->id);
					else
						printf(" %c [%d]\n", ORT(s->orient), p->id);
				}
			}
			break;
		}
	}
}

int main (int argc, char* argv[]) {
	FILE *racfile;
	char buf[50000];
	char *pt;
	struct block_list *blist;
	int num, i, count = 0, prev = -1;
	int val[MAXORDER];
	
	if (argc != 4)
		fatal("args = config.file car-order-file conserved-segs-file");
		
	get_spename(argv[1]);
	
	blist = get_block_list(argv[3]);
	
	racfile = ckopen(argv[2], "r");
	
	for (i = 0; i < MAXORDER; i++)
		val[i] = 0;
	
	while (fgets(buf, 50000, racfile) != NULL) {
		if (buf[0] == '\n' || buf[0] == '#' || buf[0] == '>')
			continue;
		printf("#%d\n\n", ++count);
		for (i = 0; i < Spesz; i++) {
			if (Spetag[i] == 2)
				continue;
			pt = buf;
			while (sscanf(pt, "%d", &num) == 1) {
				if (val[abs(num)] != 0 && prev != count)
					fprintf(stderr, "cannot happen: %d [%d]\n", num, count);
				else
					val[abs(num)] = 1;
				print_block(i, blist, num);
				pt = strchr(pt, ' ');
				if (pt != NULL)
					pt++;
				else
					break;
				if (*pt == '$')
					break;
			}	
			printf("\n");
			prev = count;
		}
		prev = count;
	}

	fprintf(stderr, "- Totally %d APCFs\n", count);
	fclose(racfile);
	free_block_list(blist);
	return 0;
}
