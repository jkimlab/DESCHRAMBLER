#include "util.h"
#include "species.h"
#include "base.h"

struct gf_list {
	int size, fgap, sgap;
	struct gf_list *next;
};

struct chain_list {
	int cid;
	char fchr[50], schr[50];
	int fbeg, fend, sbeg, send, slen;
	char forient, sorient;
	struct gf_list *gf;
	struct chain_list *next;
};

static struct chain_list *chainlist[MAXSPE] = {NULL};
static char refchr[MAXSPE][MAXCHR] = {"\0"};

static struct chain_list *read_chain(char *chainfile) {
	FILE *fp;
	char buf[500];
	struct chain_list *chainlist, *clast, *cp;
	struct gf_list *gflast, *gp;

	fp = ckopen(chainfile, "r");
	chainlist = clast = NULL;
	while(fgets(buf, 500, fp)) {
		if (buf[0] == '\n' || buf[0] == '#')
			continue;
		if (buf[0] == 'c') {
			cp = (struct chain_list *)ckalloc(sizeof(struct chain_list));
			cp->next = NULL;	
			cp->gf = NULL;
			if (sscanf(buf, "chain %*d %s %*d %c %d %d %s %d %c %d %d %d",
											cp->fchr, &(cp->forient), &(cp->fbeg), &(cp->fend),
											cp->schr, &(cp->slen), &(cp->sorient), &(cp->sbeg), &(cp->send), 
											&(cp->cid)) != 10)
				fatalf("cannot parse: %s", buf);
			if (chainlist == NULL)
				chainlist = clast = cp;
			else {
				clast->next = cp;
				clast = cp;
			}
		}
		else {
			gp = (struct gf_list *)ckalloc(sizeof(struct gf_list));
			gp->next = NULL;
			gp->fgap = gp->sgap = 0;
			if (sscanf(buf, "%d %d %d", &(gp->size), &(gp->fgap), &(gp->sgap)) == 3
				|| sscanf(buf, "%d", &(gp->size)) == 1) {
				if (cp->gf == NULL) 
					cp->gf = gflast = gp;
				else {
					gflast->next = gp;
					gflast = gp;
				}
			}
			else
				fatalf("cannot parse: %s", buf);
		}
	}
	fclose(fp);
	return chainlist;
}

static void free_gf_list(struct gf_list *gflist) {
	struct gf_list *p, *q;
	p = gflist;
	for (;;) {
		q = p->next;
		free(p);
		if (q == NULL)
			break;
		else
			p = q;
	}
}

static void free_chain_list(struct chain_list *chainlist) {
	struct chain_list *p, *q;
	p = chainlist;
	for (;;) {
		q = p->next;
		free_gf_list(p->gf);
		free(p);
		if (q == NULL)
			break;
		else
			p = q;
	}
}

void free_chain_space(int ss) {
	if (refchr[ss][0] != '\0')
		free_chain_list(chainlist[ss]);
}

void mapbase(int cid, char *rspe, char *rchr, int rpos, 
						 char *sspe, char *schr, char orient, char *side,
						 int *spos, int *newrpos) {
	char chainfile[200];
	struct chain_list *chain;
	struct gf_list *gfa;
	int rs, ss, ingap, roff, soff, ref, i;

	rs = spe_idx(rspe);
	ss = spe_idx(sspe);
	sprintf(chainfile, "%s/%s/%s/chain/%s.chain", 
					Chaindir, Spename[rs], Spename[ss], rchr);
	
	if (Spetag[ss] == 2) {
		for (i = 0; i < Spesz; i++) {
			if (i == rs || i == ss)
				continue;
			if (refchr[i][0] != '\0') {
				free_chain_list(chainlist[i]);
				refchr[i][0] = '\0';
			}
		}
	}
	
	if (!same_string(refchr[ss], rchr)) {
		if (refchr[ss][0] != '\0')
			free_chain_list(chainlist[ss]);
		strcpy(refchr[ss], rchr);
		chainlist[ss] = read_chain(chainfile);
	}
	
	for (chain = chainlist[ss]; chain != NULL; chain = chain->next)
		if (chain->cid == cid)
			break;
	
	if (chain == NULL)
		fatalf("chain not exist: %d %s %s %d %s %s %c", cid, rspe, rchr, rpos, sspe, schr, orient);
	if (rpos < chain->fbeg || rpos > chain->fend)
    fatalf("wrong ref position: %d %s %s %d %s %s %c", cid, rspe, rchr, rpos, sspe, schr, orient);
	
	roff = soff = ingap = 0;	
	ref = rpos - chain->fbeg; //offset of ref
	
	for (gfa = chain->gf; gfa != NULL; gfa = gfa->next) {
		if (roff + gfa->size > ref) 
			break;
		else {	
			roff += gfa->size;
			soff += gfa->size;
		}
		if (roff + gfa->fgap >= ref) {
			ingap = 1;
			break;
		}
		else {
			roff += gfa->fgap;
			soff += gfa->sgap;
		}
	}
	if (ingap == 1) {
		if (same_string(side, "right")) {
			roff += gfa->fgap;
			soff += gfa->sgap;
		}
	}
	else {
		soff += (ref - roff);
		roff = ref;
	}
	if (orient == '+') {
		*spos = chain->sbeg + soff;
		*newrpos = chain->fbeg + roff;
	}
	else {
		*spos = chain->slen - (chain->sbeg + soff); //rev_comp coordinate
		*newrpos = chain->fbeg + roff;
	}
}
