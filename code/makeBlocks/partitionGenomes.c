/* ****************************************************************
 *	partition the genomes into blocks using one species as reference
 * ***************************************************************/

#include "util.h"
#include "base.h"
#include "species.h"

struct my_seg_list {
	char fchrom[50], schrom[50];
	int  fbeg, fend, sbeg, send;
	char orient;
	int cid;
	struct my_seg_list *next;
};

struct my_block_list {
	char refchrom[50];
	int  refbeg, refend;
	struct my_seg_list *speseg[MAXSPE];
	struct my_block_list *next;
};

struct my_seg_list *get_my_seglist(char *filename) {
	FILE *fp;
	char buf[500];
	struct my_seg_list *sg, *last, *p;

	sg = last = NULL;
	fp = ckopen(filename, "r");

	fprintf(stderr, "- getting segments from %s\n", filename);
	
	while (fgets(buf, 500, fp)) {
		if (buf[0] == '#')
			continue;
		p = (struct my_seg_list *)ckalloc(sizeof(struct my_seg_list));
		p->next = NULL;
		if (sscanf(buf, "%*[^.].%[^:]:%d-%d %*[^.].%[^:]:%d-%d %c %d",
				p->fchrom, &(p->fbeg), &(p->fend),
				p->schrom, &(p->sbeg), &(p->send), &(p->orient), &(p->cid)) != 8)
			fatalf("%s: cannot parse\n %s\n", filename, buf);
		if (p->fbeg > p->fend || p->sbeg > p->send)
			fatalf("%s: cannot parse\n %s\n", filename, buf);
		if (sg == NULL)
			sg = last = p;
		else {
			last->next = p;
			last = p;
		}
	} 
	fclose(fp);
	return sg;
} 

struct my_block_list *my_allocate_newblock() {
	struct my_block_list *newblock;
	int i;
	newblock = (struct my_block_list *)ckalloc(sizeof(struct my_block_list));
	newblock->next = NULL;
	for (i = 0; i < Spesz; i++)
		newblock->speseg[i] = NULL;
	newblock->refbeg = MAXNUM;
	newblock->refend = 0;
	newblock->refchrom[0] = '\0';
	return newblock;
}

void find_insert_position(struct my_seg_list *sg, struct my_block_list *blockhead, 
								struct my_block_list *last, struct my_block_list **prv, 
								struct my_block_list **nxt, struct my_block_list **fst,
								struct my_block_list **lst) { 

	// prv <= fst <= lst <= nxt
	// The insertion pos will be between prv and nxt. 
	// fst and lst are the first and last block covered by sg respectively.
	// fst and lst could be NULL if no existing block is covered by sg.
	// prv == NULL if insertion pos is before head.
	// nxt == NULL if insertion pos is after tail.

	struct my_block_list *p, *pp;
	*prv = *nxt = *fst = *lst = NULL;
	pp = NULL;
	if (last != NULL)
		p = last;
	else 
		p = blockhead;
	for (; p != NULL; p = p->next) {
		if (!same_string(p->refchrom, sg->fchrom) && p->next != NULL 
				&& same_string(p->next->refchrom, sg->fchrom))
			pp = p;
		else if (same_string(p->refchrom, sg->fchrom)) {
			if ((p->next != NULL && same_string(p->next->refchrom, sg->fchrom) 
					&& p->refend <= sg->fbeg && sg->fend <= p->next->refbeg)
				|| ((p->next == NULL || !same_string(p->next->refchrom, sg->fchrom))
					&& p->refend <= sg->fbeg)) {
				// no break, insert between prv and nxt, nxt == prv->next
				*prv = p;
				*nxt = p->next;
				*fst = *lst = NULL;
				break;
			}
			if (((pp != NULL && p == pp->next) || (pp == NULL && p == blockhead)) 
					&& p->refbeg >= sg->fend) {
				// no break, insert before nxt
				*prv = pp;
				*nxt = p;
				*fst = *lst = NULL;
				break;
			}
			
			// determine prv and fst
			if (p->refbeg <= sg->fbeg && sg->fbeg < p->refend)
				*prv = *fst = p;
			else if (((pp != NULL && p == pp->next) || (pp == NULL && p == blockhead))
						&& p->refbeg > sg->fbeg && p->refbeg < sg->fend) {
				*prv = pp;
				*fst = p;
			}
			else if ((p->next != NULL && same_string(p->next->refchrom, sg->fchrom)
						&& p->refend <= sg->fbeg && sg->fbeg < p->next->refbeg)) {
				*prv = p;
				*fst = p->next;
			}
			
			// determine lst and nxt
			if (p->refbeg < sg->fend && sg->fend <= p->refend) {
				*lst = *nxt = p;
				break;
			}
			else if ((p->next != NULL && same_string(p->next->refchrom, sg->fchrom)
						&& p->refend < sg->fend && sg->fend <= p->next->refbeg)
					|| ((p->next == NULL || !same_string(p->next->refchrom, sg->fchrom))
						&& p->refend < sg->fend)) {
				*lst = p;
				*nxt = p->next;
				break;
			}
		}
	}
}

void fill_block(struct my_block_list *blck, int idx, struct my_seg_list *sg) {
	struct my_seg_list *newsg;
	
	if (blck->refchrom[0] == '\0')
		strcpy(blck->refchrom, sg->fchrom);
	else if (!same_string(blck->refchrom, sg->fchrom))
			fatalf("CHROM DISAGREE: %s %s", blck->refchrom, sg->fchrom);
	
	blck->refbeg = MIN(blck->refbeg, sg->fbeg);
	blck->refend = MAX(blck->refend, sg->fend);

	newsg = (struct my_seg_list *)ckalloc(sizeof(struct my_seg_list));
	newsg->next = NULL;
	strcpy(newsg->fchrom, sg->fchrom);
	strcpy(newsg->schrom, sg->schrom);
	newsg->fbeg = sg->fbeg;
	newsg->fend = sg->fend;
	newsg->sbeg = sg->sbeg;
	newsg->send = sg->send;
	newsg->orient = sg->orient;
	newsg->cid = sg->cid;
	
	blck->speseg[idx] = newsg;
}

void fill_block_out(struct my_block_list *blck, int idx, struct my_seg_list *sg) {
	struct my_seg_list *newsg, *p;
	
	newsg = (struct my_seg_list *)ckalloc(sizeof(struct my_seg_list));
	newsg->next = NULL;
	strcpy(newsg->fchrom, sg->fchrom);
	strcpy(newsg->schrom, sg->schrom);
	newsg->fbeg = sg->fbeg;
	newsg->fend = sg->fend;
	newsg->sbeg = sg->sbeg;
	newsg->send = sg->send;
	newsg->orient = sg->orient;
	newsg->cid = sg->cid;
	
	if (blck->speseg[idx] == NULL)
		blck->speseg[idx] = newsg;
	else {
		for (p = blck->speseg[idx]; p->next != NULL; p = p->next)
			;
		p->next = newsg;
	}
}

void break_segment_position(struct my_seg_list *sg, int pos, int idx) {
	struct my_seg_list *newsg;
	int lnewpos, rnewpos;
	
	newsg = (struct my_seg_list *)ckalloc(sizeof(struct my_seg_list));
	newsg->next = sg->next;
	sg->next = newsg;
	strcpy(newsg->fchrom, sg->fchrom);
	strcpy(newsg->schrom, sg->schrom);
	newsg->fend = sg->fend;
	newsg->orient = sg->orient;
	newsg->cid = sg->cid;
	
	if (sg->orient == '+') {
		newsg->send = sg->send;
		mapbase(sg->cid, Spename[0], sg->fchrom, pos, Spename[idx], sg->schrom, 
						sg->orient,"left", &(sg->send), &(lnewpos));
		mapbase(sg->cid, Spename[0], sg->fchrom, pos, Spename[idx], sg->schrom, 
						sg->orient, "right", &(newsg->sbeg), &(rnewpos));
	}
	else {
		newsg->sbeg = sg->sbeg;
		mapbase(sg->cid, Spename[0], sg->fchrom, pos, Spename[idx], sg->schrom, 
						sg->orient, "left", &(sg->sbeg), &(lnewpos));
		mapbase(sg->cid, Spename[0], sg->fchrom, pos, Spename[idx], sg->schrom, 
						sg->orient, "right", &(newsg->send), &(rnewpos));
	}
	sg->fend = lnewpos;
	newsg->fbeg = rnewpos;
}

void break_block_position(struct my_block_list *blk, int pos) {
	int i, rs;
	struct my_block_list *newblk;
	struct my_seg_list *sg;
	
	newblk = my_allocate_newblock();
	strcpy(newblk->refchrom, blk->refchrom);
	newblk->refbeg = pos;
	newblk->refend = blk->refend;
	blk->refend = pos;
	
	rs = ref_spe_idx();
	for (i = 0; i < Spesz; i++) {
		if (i == rs)
			continue;
		sg = blk->speseg[i];
		if (sg == NULL)
			continue;
		if (pos <= sg->fbeg) {
			fill_block(newblk, i, sg);
			blk->speseg[i] = NULL;
			free(sg);
		}
		else if (pos >= sg->fend) {
			continue;
		}
		else {
			break_segment_position(sg, pos, i);
			fill_block(newblk, i, sg->next);
			sg = sg->next;
			blk->speseg[i]->next = NULL;
			free(sg);
		}
	}
	newblk->next = blk->next;
	blk->next = newblk;
}

void add_descendent_segs(struct my_block_list **blkhead, int idx, struct my_seg_list *sglist) {
	struct my_seg_list *sg;
	struct my_block_list *blocklist, *lastblock, *newblock, *last;
	struct my_block_list *prv, *nxt, *fst, *lst;
	int pos, count;
	char prevchr[50];
	
	prevchr[0] = '\0';
	blocklist = lastblock = NULL;
	if (*blkhead == NULL) {
		for (sg = sglist; sg != NULL; sg = sg->next) {
			if (!same_string(prevchr, sg->fchrom)) {
				fprintf(stderr, "\n  in ref %s ", sg->fchrom);
				strcpy(prevchr, sg->fchrom);
				count = 0;
			}
			++count;
			if (count%5 == 0)
				fprintf(stderr, ".");
			newblock = my_allocate_newblock();
			fill_block(newblock, idx, sg);
			if (blocklist == NULL)
				blocklist = lastblock = newblock;
			else {
				lastblock->next = newblock;
				lastblock = newblock;
			}
		}
		*blkhead = blocklist;
	}
	else {
		last = NULL;
	 	for (sg = sglist; sg != NULL; sg = sg->next) {
			if (!same_string(prevchr, sg->fchrom)) {
				fprintf(stderr, "\n  in ref %s ", sg->fchrom);
				strcpy(prevchr, sg->fchrom);
				count = 0;
			}
			++count;
			if (count%5 == 0)
				fprintf(stderr, ".");
			find_insert_position(sg, *blkhead, last, &prv, &nxt, &fst, &lst);
			last = prv;
			if (fst == NULL && lst == NULL) { 
				newblock = my_allocate_newblock();
				fill_block(newblock, idx, sg);
				if (prv == NULL && nxt == NULL) continue;
				if (prv != NULL && nxt != NULL && nxt == prv->next) {
					newblock->next = prv->next;
					prv->next = newblock;
				}
				else if (prv == NULL) {
					newblock->next = *blkhead;
					*blkhead = newblock;
				}
				else if (nxt == NULL) 
					prv->next = newblock;
			}
			else if (fst == lst) {
				if (fst->speseg[idx] == NULL) {
					fill_block(fst, idx, sg);				
				} else {
					pos = (fst->speseg[idx]->fend + sg->fbeg) / 2;
					break_block_position(fst, pos);
					fst = fst->next;
					fill_block(fst, idx, sg);
				}
			}
			else {
				if (fst == NULL || lst == NULL) {
					continue;
				}
				if (fst->speseg[idx] != NULL) { 
					pos = (fst->speseg[idx]->fend + sg->fbeg) / 2;
					break_block_position(fst, pos);
					fst = fst->next;
				}
				for (; fst != lst; fst = fst->next) {
					pos = (fst->refend + fst->next->refbeg) / 2;
					if (pos <= sg->fbeg)
						continue;
					break_segment_position(sg, pos, idx);
					fill_block(fst, idx, sg);
					sg = sg->next;
				}
				fill_block(fst, idx, sg);
			}
		}
	}
	fprintf(stderr, "\n");
}

void add_outgroup_segs(struct my_block_list *head, int idx, struct my_seg_list *sglist) {
	struct my_seg_list *sg;
	struct my_block_list *prv, *nxt, *fst, *lst, *last;
	int pos, count;
	char prevchr[50];
	
	last = NULL;
	prevchr[0] = '\0';
	for (sg = sglist; sg != NULL; sg = sg->next) {
		if (!same_string(prevchr, sg->fchrom)) {
			fprintf(stderr, "\n  in ref %s ", sg->fchrom);
			strcpy(prevchr, sg->fchrom);
			count = 0;
		}
		++count;
		if (count%5 == 0)
			fprintf(stderr, ".");
		find_insert_position(sg, head, last, &prv, &nxt, &fst, &lst);
		last = prv;
		if (fst == NULL && lst == NULL)
			continue;
		if (fst == lst)
			fill_block_out(fst, idx, sg);
		else {
			if (fst == NULL || lst == NULL) {
				continue;
			}
			for (; fst != lst; fst = fst->next) {
				pos = (fst->refend + fst->next->refbeg) / 2;
				if (pos <= sg->fbeg)
					continue;
				break_segment_position(sg, pos, idx);
				fill_block_out(fst, idx, sg);
				sg = sg->next;
			}
			fill_block_out(fst, idx, sg);
		}
	}
	fprintf(stderr, "\n");
}

void free_my_seg_list(struct my_seg_list *sg) {
	struct my_seg_list *p, *q;
	p = sg;
	for (;;) {
		q = p->next;
		free(p);
		if (q == NULL)
			break;
		else
			p = q;
	}
}

void free_my_block_list(struct my_block_list *blk) {
	struct my_block_list *p, *q;
	int i;
	p = blk;
	for (;;) {
		q = p->next;
		for (i = 0; i < Spesz; i++)
			if (p->speseg[i] != NULL)
				free_my_seg_list(p->speseg[i]);
		free(p);
		if (q == NULL)
			break;
		else
			p = q;
	}
}

int main(int argc, char *argv[]) {
	int ss, rs;
	char segfile[200];
	struct my_seg_list *spesegs[MAXSPE], *sg;
	struct my_block_list *commonblocklist, *blk;
	
	if (argc != 2)
		fatal("args: configure-file");
	
	get_spename(argv[1]);
	get_chaindir(argv[1]);
	get_minlen(argv[1]);	
	rs = ref_spe_idx();
	
	// read processed seg files
	for (ss = 0; ss < Spesz; ss++) {
		if (rs == ss)
			continue;
		sprintf(segfile, "%s.processed.segs", Spename[ss]);
		spesegs[ss] = get_my_seglist(segfile);
	}

	commonblocklist = NULL;
	// add pieces from descendents
	for (ss = 0; ss < Spesz; ss++) {
		if (Spetag[ss] == 1) {
			fprintf(stderr, "- adding descendent %s", Spename[ss]);
			add_descendent_segs(&commonblocklist, ss, spesegs[ss]);
		}
	}
	// add pieces from outgroups
	for (ss = 0; ss < Spesz; ss++) {
		if (Spetag[ss] == 2) {
			fprintf(stderr, "- adding outgroup %s", Spename[ss]);
			add_outgroup_segs(commonblocklist, ss, spesegs[ss]);
		}
	}
	for (ss = 0; ss < Spesz; ss++) {
		if (ss == rs)
			continue;
		else
			free_chain_space(ss);
	}
	
	// sanity check
	for (blk = commonblocklist; blk->next != NULL; blk = blk->next) {
		if (blk->refbeg >= blk->refend)
			fatalf("end >= beg: %s.%s:%d-%d", 
							Spename[rs], blk->refchrom, blk->refbeg, blk->refend);
		if (same_string(blk->refchrom, blk->next->refchrom)) {
			if (blk->refend > blk->next->refbeg) {
				fatalf("out of order:\n%s.%s:%d-%d %s.%s:%d-%d",
							Spename[rs], blk->refchrom, blk->refbeg, blk->refend,
							Spename[rs], blk->next->refchrom, blk->next->refbeg, blk->next->refend);
			}
		}
	}
	
	// print building blocks
	for (blk = commonblocklist; blk != NULL; blk = blk->next) {
		printf(">\n");
		printf("%s.%s:%d-%d +\n", 
						Spename[rs], blk->refchrom, blk->refbeg, blk->refend);
		for (ss = 0; ss < Spesz; ss++) {
			if (rs == ss)
				continue;
			for (sg = blk->speseg[ss]; sg != NULL; sg = sg->next) 
				printf("%s.%s:%d-%d %c (%d)\n",Spename[ss], sg->schrom, sg->sbeg, sg->send, sg->orient, sg->cid);
		}
		printf("\n");
	}
	
	for (ss = 0; ss < Spesz; ss++) {
		if (rs == ss)
			continue;
		free_my_seg_list(spesegs[ss]);
	}
	
	free_my_block_list(commonblocklist);
	
	return 0;
}
