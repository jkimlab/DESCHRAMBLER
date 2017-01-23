#include "common.h"
#include "errabort.h"
#include "linefile.h"
#include "options.h"
#include "uthash.h"
#include <math.h>

#define LEFT 0
#define RIGHT 1
#define YES	0x01
#define NO	0x00
#define HI	0xFF
#define D		sizeof(double)
#define STACKSZ	50000
#define DESC 0.35

#define CHR 0
#define NONCHR 1

struct chromList {
	struct chromList *next;
	int eleNum;
	int *eleOrder;
	int type;	// CHR or NONCHR	
};

struct phyloTree {
	struct phyloTree *next;
	struct phyloTree *parent, *child[2];
	int chromNum;
	boolean outgroup;
	double distalpha;
	char *name;
	struct chromList *genome;
};

struct nodeList {
	struct nodeList *next;
	struct phyloTree *addr;
	unsigned char *P, *S, *there;
};

struct matrix {
	struct matrix *next;
	int x;
	double val;
};

struct edgeList {
	struct edgeList *next;
	int i, j;
	double wei;
};

struct hash_key {
    struct phyloTree* node;
    int i;
    int j;
};

struct hash_entry {
    struct hash_key key;
    double value;
    UT_hash_handle hh;
};

static boolean oj = TRUE;
static struct phyloTree *Phylo = NULL, *Ances = NULL;
static struct nodeList *Leaf = NULL;
static int X = 8 * sizeof(unsigned char);
static int A = 0, T = 0, N = 0, Z = 0; 
static unsigned char *DPPI, *DSPI, *G;
static struct matrix *PLH, *SLH, *PPP, *SPP;
static struct edgeList *Edgelist = NULL;
static double alpha = 0.0;

static struct hash_entry *lp_cache = NULL;
static struct hash_entry *ll_cache = NULL;

void usage() {
	errAbort(
		"inferAdjProb - inferring the posterior probability of block adjacency\n"
        "  usage: inferAdjProb refspc parameter-alpha tree-file genome-file\n"
	);
}

static struct optionSpec options[] = {
	{"oj", OPTION_BOOLEAN},
	{NULL, 0},
};

static boolean isSepSymbol(char ch) {
	if (ch == ',' || ch == '(' || ch == ')' || ch == ';' || ch == ':')
		return TRUE;
	return FALSE;
}

static void allocTreeNode(struct phyloTree **node, struct phyloTree **last) {
	struct phyloTree *p;
	AllocVar(*node);
	p = *node;
	p->child[LEFT] = p->child[RIGHT] = p->parent = p->next = NULL;
	p->chromNum = 0;
	p->name = NULL;
	p->genome = NULL;
	if (last) {
		if (*last == NULL)
			*last = p;
		else {
			(*last)->next = p;
			*last = p;
		}
	}
}

static void adjustTreeList(struct phyloTree *node, struct phyloTree **last) {
	if (node) {
		node->next = NULL;
		if (*last == NULL)
			*last = node;
		else {
			(*last)->next = node;
			*last = node;
		}
		adjustTreeList(node->child[LEFT], last);
		adjustTreeList(node->child[RIGHT], last);
	}
}

static void adjustNextInTree(struct phyloTree *root) {
	struct phyloTree *last = NULL;
	adjustTreeList(root, &last);
}

static boolean isLeaf(struct phyloTree *node) {
	if (node->child[LEFT] == NULL && node->child[RIGHT] == NULL)
		return TRUE;
	return FALSE;
}

static struct phyloTree *readTreeString(char *treeString) {
	struct phyloTree *last = NULL, *p = NULL, *q;
	struct phyloTree *stack[STACKSZ];
	char buf[500];
	char *pt;
	int i, top = 0, count = 0;
	double dcap = 0;
	
  eraseWhiteSpace(treeString);
	pt = treeString;
	while (*pt != '\0' && *pt != ';') {
		if (!isSepSymbol(*pt)) {
			allocTreeNode(&p, &last);
			for (i = 0; !isSepSymbol(*pt); pt++)
				buf[i++] = *pt;
			buf[i] = 0;
			if (i == 0) 
				sprintf(buf, "IN%d", ++count);
			p->name = cloneString(buf);
		}
		switch (*pt) {
			case ':': {
				pt++;
				if (sscanf(pt, "%lf", &dcap) != 1)
					errAbort("# cannot parse %s", pt);
				while (!isSepSymbol(*pt))
					pt++;
				break;
			}
			case '(': {
				allocTreeNode(&p, &last);
				if (top + 1 > STACKSZ)
					errAbort("# stack overflow %d", STACKSZ);
				stack[top++] = p;
				pt++;
				break;
			}
			case ',': {
				q = stack[top-1];
				q->child[LEFT] = p;
				p->parent = q;
				p->distalpha = dcap*alpha;
				pt++;
				break;
			}
			case ')': {
				q = stack[--top];
				q->child[RIGHT] = p;
				p->parent = q;
				p->distalpha = dcap*alpha;
				pt++;	
				if (*pt == '@') {
					Ances = q;
					++pt;
				}
				for (i = 0; !isSepSymbol(*pt); pt++) 
					buf[i++] = *pt;
				buf[i] = 0;
				if (i == 0) 
					sprintf(buf, "IN%d", ++count);
				q->name = cloneString(buf); 
				p = q;
				break;
			}
			case ';':
				break;
			default:
				errAbort("# illegal symbol %c : %s", *pt, treeString );
		}
	}
	if (Ances == NULL)
		Ances = p;
	if (top != 0)
		errAbort("# unbalanced tree %s", treeString);
	adjustNextInTree(p);
	return p;
}

static struct phyloTree *readTreeFile(char *treeFile) {
	struct phyloTree *root = NULL;
  struct lineFile *lf = lineFileOpen(treeFile, TRUE);
	char *str;
	int len;
	if (lineFileNext(lf, &str, &len) && len > 0)
		root = readTreeString(str);
	lineFileClose(&lf);
	return root;
}

static void initLeafList(struct phyloTree *tree) {
	struct nodeList *nl;
	struct phyloTree *tr;
	for (tr = tree; tr; tr = tr->next) {
		if (isLeaf(tr)) {
			AllocVar(nl);
			nl->addr = tr;
			slAddHead(&Leaf, nl);
		}
	}
	slReverse(&Leaf);
}

static void identifyOutgroup(struct phyloTree *tree) {
	struct phyloTree *tr, *tt;
	for (tr = tree; tr; tr = tr->next) {
		if (isLeaf(tr)) {

			for (tt = tr; tt; tt = tt->parent) {
				if (tt == Ances) 
					break;
			}
			if (tt == NULL) {
				tr->outgroup = TRUE;
			} else {
				tr->outgroup = FALSE;
			}

		}
	}
}

static int countAtomInChromString(char *chromString) {
  int i = 0;
	char *tt, *pt, *orgStr;
	pt = orgStr = cloneString(chromString);
	while ((tt = nextWord(&pt)) && *tt != '$')
		++i;
	freeMem(orgStr);
	return i;
}

static struct chromList *readChromString(char *chromString) {
	char *pt, *tt;
	int elementNum, i;
	struct chromList *chrom = NULL;
	
	elementNum = countAtomInChromString(chromString);
	if (elementNum == 0)
		return NULL;
	AllocVar(chrom);
	chrom->eleNum = elementNum;
	AllocArray(chrom->eleOrder, chrom->eleNum);
	i = 0;
	pt = chromString;
	while ((tt = nextWord(&pt))) {
		if (*tt == '$') 
			break;
		chrom->eleOrder[i] = atoi(tt);
		++i;
	}
	return chrom;
}

static struct chromList *readLeafGenomes(char *fileName, char *genomeName) {
  struct chromList *genome = NULL, *chrom;
	struct lineFile *fp;
	char *str;
	char buf[500];
	int chromNum = 0, i;
	boolean found = FALSE;
	int gtype = CHR;
fprintf(stderr, "readLeafGenomes: %s\n", genomeName);	
	fp = lineFileOpen(fileName, TRUE);
	while (lineFileNext(fp, &str, NULL)) {
		if (str[0] == '>') {
			if (sscanf(str, ">%s %d", buf, &(chromNum)) != 2)
				errAbort("# cannot parse %s", str);
			if (sameString(buf, genomeName)) {
				found = TRUE;
				for (i = 0; i < chromNum; i++) {
					if (!(lineFileNext(fp, &str, NULL)))
						errAbort("# bad file %s", fileName);
					if (str[0] == '#') {
						if (sscanf(str, "# chr%s", buf) != 1)
							gtype = NONCHR;
						else 						
							gtype = CHR;
						if (!(lineFileNext(fp, &str, NULL)))
							errAbort("# bad file %s", fileName);
					}
					chrom = readChromString(str);
					chrom->type = gtype;
					slAddHead(&genome, chrom);
				}
			}
		}
		if (found)
			break;
	}
	if (!found)
		errAbort("# no genome for %s", genomeName);
	lineFileClose(&fp);
	slReverse(&genome);
	return genome; 
}

static void readGenomes(char *genomeFile) {
	struct phyloTree *tr;
	for (tr = Phylo; tr; tr = tr->next) {
		if (isLeaf(tr)) {
			if (tr->outgroup == TRUE && oj == TRUE) 
				continue;
			tr->genome = readLeafGenomes(genomeFile, tr->name);
		}
	}
}

static int map(int i) {
	if (i == A)
		return Z;
	if (i == Z)
		return A;
	return (i <= T) ? (i + T) : (i - T);
}

static int pam(int i) {
	if (i == Z)
		return A;
	return (i <= T) ? i : -(i - T);
}

static unsigned char Val(unsigned char *H, int i, int j) {
	int pos = i * N + j;
	int a = pos / X;
	int b = pos % X;
	unsigned char *v = H + a;
	return (*v >> b) & 0x1;
}

static void Set(unsigned char *H, int i, int j, unsigned char value) {
	unsigned char g;
	unsigned char *v;
	int pos, a, b;

	if (i < 0)
		i = map(-i);
	if (j < 0)
		j = map(-j);
	if (j == A)
		j = Z;

	pos = i * N + j;
	a = pos / X;
	b = pos % X;
	v = H + a;
	if (value == 1) {
		g = 0x01 << b;
		*v = (*v | g);
	}
	else {
		g = 0x01 << b;
		g = HI - g;
		*v = (*v & g);
	}
}

static double PVal(struct matrix *H, int i, int j) {
	struct matrix *pt;
	
	for (pt = H+j; pt; pt = pt->next)
		if (pt->x == i)
			break;
	if (pt)
		return pt->val;
	else 
		return 0;
}

static void PSet(struct matrix *H, int i, int j, double value) {
	struct matrix *pt, *lst;
	
	if (i < 0)
		i = map(-i);
	if (j < 0)
		j = map(-j);
	if (j == A)
		j = Z;

	for (pt = lst = H+j; pt; ) {
		if (pt->x == i)
			break;
		else {
			lst = pt;
			pt = pt->next;
		}
	}
	if (pt == NULL) {
		AllocVar(pt);
		pt->next = NULL;
		lst->next = pt;
		pt->x = i;
		pt->val = value;
	}
	else 
		pt->val = value;
}

static double SVal(struct matrix *H, int i, int j) {
	struct matrix *pt;
	
  for (pt = H+i; pt; pt = pt->next)
		if (pt->x == j)
			break;
	if (pt)
		return pt->val;
	else
		return 0;
}

static void SSet(struct matrix *H, int i, int j, double value) {
	struct matrix *pt, *lst;

	if (i < 0)
		i = map(-i);
	if (j < 0)
		j = map(-j);
	if (j == A)
		j = Z;
	
	for (pt = lst = H+i; pt; ) {
		if (pt->x == j)
			break;
		else {
			lst = pt;
			pt = pt->next;
		}
	}
	if (pt == NULL) {
		AllocVar(pt);
		pt->next = NULL;
		lst->next = pt;
		pt->x = j;
		pt->val = value;
	}
	else 
		pt->val = value;
}

static void updatePS(struct nodeList *b, int i, int j) {
	if (j < 0)
		j = map(-j);
	if (i < 0)
		i = map(-i);
	if (i == A) 
		b->there[j] = YES;
	else if (j == Z) 
		b->there[map(i)] = YES;
	else 
		b->there[j] = b->there[map(i)] = YES;
}
																												
static void initSets(struct nodeList *leaves) {
	struct nodeList *b;
	struct phyloTree *node;
	int i, x, y;
	struct chromList *ch;
	char tmp[50], buf[500];
	FILE *fp;
	
	Z = 2 * T + 1;
	N = Z + 1;
	
	AllocArray(DPPI, N*N/X+1);
	AllocArray(DSPI, N*N/X+1);
  for (b = leaves; b; b = b->next) {
		AllocArray(b->P, N*N/X+1);
		AllocArray(b->S, N*N/X+1);
		AllocArray(b->there, N);
	}
	
	AllocArray(G, N*N/X+1);
	AllocArray(PLH, N);
	AllocArray(SLH, N);
	AllocArray(PPP, N);
	AllocArray(SPP, N);
	
	for (b = leaves; b; b = b->next) {
		node = b->addr;
		if (node->outgroup && oj)
			continue;
		ch = node->genome;
		fprintf(stderr, "Initializing %s (ingroup)\n", node->name);
		for (ch = node->genome; ch; ch = ch->next) {
			i = 0;
			Set(b->P, A, ch->eleOrder[i], YES);
			Set(b->P, -ch->eleOrder[i], Z, YES);
			Set(DPPI, A, ch->eleOrder[i], YES);
			Set(DPPI, -ch->eleOrder[i], Z, YES);
			updatePS(b, A, ch->eleOrder[i]);
			for (++i; i < ch->eleNum; ++i) {
				Set(b->P, ch->eleOrder[i-1], ch->eleOrder[i], YES);
				Set(b->P, -ch->eleOrder[i], -ch->eleOrder[i-1], YES);
				Set(DPPI, ch->eleOrder[i-1], ch->eleOrder[i], YES);
				Set(DPPI, -ch->eleOrder[i], -ch->eleOrder[i-1], YES);
				updatePS(b, ch->eleOrder[i-1], ch->eleOrder[i]);
			}
			Set(b->P, ch->eleOrder[i-1], Z, YES);
			Set(b->P, A, -ch->eleOrder[i-1], YES);
			Set(DPPI, ch->eleOrder[i-1], Z, YES);
			Set(DPPI, A, -ch->eleOrder[i-1], YES);
			updatePS(b, ch->eleOrder[i-1], Z);
		}
	}

	if (oj) {
		for (b = leaves; b; b = b->next) {
			node = b->addr;
			ch = node->genome;
			if (!node->outgroup)
				continue;
			fprintf(stderr, "Initializing %s (outgroup)\n", node->name);
			sprintf(tmp, "%s.joins", node->name);
			fp = mustOpen(tmp, "r");
			while(fgets(buf, 500, fp)) {
				if (buf[0] == '#')
					continue;
				if (sscanf(buf, "%d %d\n", &x, &y) != 2)
					errAbort("# bad join file: %s", buf);
				if (x == 0 && y != 0) {
					Set(b->P, A, y, YES);
					Set(b->P, -y, Z, YES);
					Set(DPPI, A, y, YES);
					Set(DPPI, -y, Z, YES);
					updatePS(b, A, y);
				} else if (x != 0 && y == 0) {
					Set(b->P, x, Z, YES);
					Set(b->P, A, -x, YES);
					Set(DPPI, x, Z, YES);
					Set(DPPI, A, -x, YES);
					updatePS(b, x, Z);
				} else if (x != 0 && y != 0) {
					Set(b->P, x, y, YES);
					Set(b->P, -y, -x, YES);
					Set(DPPI, x, y, YES);
					Set(DPPI, -y, -x, YES);
					updatePS(b, x, y);
				}
			}
			fclose(fp);
		} 
	} 
}

static void freeSets(struct nodeList *leaves) {
	struct nodeList *b;
	freeMem(DPPI);
	freeMem(DSPI);
  for (b = leaves; b; b = b->next) {
		freeMem(b->P);
		freeMem(b->S);
		freeMem(b->there);
	}
	
	freeMem(G);
	freeMem(PLH);
	freeMem(SLH);
	freeMem(PPP);
	freeMem(SPP);
}

static double prob(struct phyloTree *son, int i, int s) {
	double pb, ttaa;
	double n = (double)T;
	ttaa = son->distalpha;
	
	if (i == s) {
		pb = (1/(2*n-1) + (2*n-2)/(2*n-1) * exp(-(2*n-1) * ttaa)); 
	} else {
		pb = (1/(2*n-1) - 1/(2*n-1) * exp(-(2*n-1) * ttaa));
	}	

	return pb;
}

static struct nodeList *findTreeNode(char *name) {
	struct nodeList *lf;
	for (lf = Leaf; lf; lf = lf->next) {
		if (sameString(lf->addr->name, name))
			break;
	}
	if (lf == NULL)
		errAbort("# no leaf %s", name);
	return lf;
}

static double getLP(struct phyloTree* node, int i, int j) {
    struct hash_key hkey;
    struct hash_entry *hentry, *newentry;
    double val;
    
    memset(&hkey, 0, sizeof(struct hash_key));
    hkey.node = node;
    hkey.i = i; 
    hkey.j = j;
    HASH_FIND(hh, lp_cache, &hkey, sizeof(struct hash_key), hentry);
    if (hentry != NULL) {                                                 
        val = hentry->value;                                              
    } else {                                                              
        val = prob(node, i, j);                                           
        newentry = (struct hash_entry*)malloc(sizeof(struct hash_entry)); 
        newentry->key.node = node;                                        
        newentry->key.i = i;                                              
        newentry->key.j = j;                                              
        newentry->value = val;                                            
        HASH_ADD(hh, lp_cache, key, sizeof(struct hash_key), newentry);     
    }                                                                     
                                                                          
    return val;                                                           
}                       

static double preLikelihood(struct phyloTree *anc, int i, int j);         
                                                                          
static double getLL(struct phyloTree *node, int i, int j) {               
    struct hash_key hkey;                                                 
    struct hash_entry *hentry, *newentry;                                 
    double val;                                                           
                                                                          
    memset(&hkey, 0, sizeof(struct hash_key));                            
    hkey.node = node;                                                     
    hkey.i = i;                                                           
    hkey.j = j;                                                           
    HASH_FIND(hh, ll_cache, &hkey, sizeof(struct hash_key), hentry);        
    if (hentry != NULL) {                                                 
        val = hentry->value;                                              
    } else {                                                              
        val = preLikelihood(node, i, j);                                  
        newentry = (struct hash_entry*)malloc(sizeof(struct hash_entry));   
        newentry->key.node = node;                                        
        newentry->key.i = i;                                              
        newentry->key.j = j;                                              
        newentry->value = val;                                            
        HASH_ADD(hh, ll_cache, key, sizeof(struct hash_key), newentry);     
    }                                                                     
                                                                          
    return val;                                                           
}                       

static double preLikelihood(struct phyloTree *anc, int i, int j) {
	int s;
	double left, right;
	struct nodeList *lf;
	double val;
    struct phyloTree *node;
	struct chromList *ch;
	
	left = right = 0;
	
	if (isLeaf(anc)) {
		lf = findTreeNode(anc->name);
		node = lf->addr;
		ch = node->genome;
		if (lf->there[j] == YES) {
			return Val(lf->P, i, j);
		} else {
			return 1;
		}
	}
	
	if (anc->child[LEFT] == NULL)
		left = 1;
	else {
		for (s = A; s < Z; s++) {
			if (Val(DPPI, s, j) == YES) {
				left += getLP(anc->child[LEFT], i, s) * getLL(anc->child[LEFT], s, j);
			}
		}
	}
	
	if (anc->child[RIGHT] == NULL)
		right = 1;
	else {
		for (s = A; s < Z; s++) {
			if (Val(DPPI, s, j) == YES) {
	
				right += getLP(anc->child[RIGHT], i, s) * getLL(anc->child[RIGHT], s, j);
			}
		}
	}
	
	val = log(left) + log(right);
	val = exp(val);
	return (left * right);
}

static void normalize() {
	int i;
	double psum, ssum;
	struct matrix *pt;
	for (i = A+1; i < Z; i++) {
		psum = 0;
		for (pt = PLH+i; pt; pt = pt->next)
			psum += pt->val;
		for (pt = PLH+i; pt; pt = pt->next) {
			PSet(PPP, pt->x, i, pt->val/psum);
		}
	}
	for (i = A+1; i < Z; i++) {
		ssum = 0;
		for (pt = SLH+i; pt; pt = pt->next)
			ssum += pt->val;
		for (pt = SLH+i; pt; pt = pt->next) {
			SSet(SPP, i, pt->x, pt->val/ssum);
		}
	}
	for (i = A+1; i < Z; i++) {
		if (Val(DPPI, A, i) == YES)
			SSet(SPP, A, i, PVal(PPP, A, i));
	}
	for (i = A+1; i < Z; i++) {
		if (Val(DPPI, i, Z) == YES)
			PSet(PPP, i, Z, SVal(SPP, i, Z));
	}
}

static void getPredecessor() {
	int i, j;
	double val;
	for (j = A+1; j < Z; j++) {
		for (i = A; i < Z; i++) {
			if (Val(DPPI, i, j) == NO) {
				continue;
			} else {
				val = preLikelihood(Ances, i, j);
				PSet(PLH, i, j, val);
			}
		}
	}
}

static void getSuccessor() {
	int i, j;
	double v;
	struct matrix *pt;
	for (j = A; j <= Z; j++) {
		v = PVal(PLH, A, map(j));
		if (v > 0) {
			SSet(SLH, j, Z, v);
		}
	}
	for (i = A+1; i < Z; i++) {
		for (pt = PLH+i; pt; pt = pt->next) {
			if (pt->val > 0) { 
				SSet(SLH, map(i), map(pt->x), pt->val);
			}
		}
	}
}

static int calculateTotalEle(char* refspc, struct phyloTree *tree) {
	struct phyloTree *tr;
	struct chromList *chr;
	int i = 0;
	for (tr = tree; tr; tr = tr->next) {
		if (tr->genome && sameString(refspc, tr->name)) {
			for (chr = tr->genome; chr; chr = chr->next) {
				i += chr->eleNum;
			}
			break;
		}
	}
	return i;
}

static struct phyloTree *rerootTree(struct phyloTree *node) {
	struct phyloTree *p, *r, *v, *g;
	r = v = node;
	p = node->parent;
	while (p) {
		if (v == p->child[RIGHT])
			p->child[RIGHT] = NULL;
		else
			p->child[LEFT] = NULL;
		if (v->child[RIGHT] == NULL)
			v->child[RIGHT] = p;
		else
			v->child[LEFT] = p;
		g = p->parent;
		p->parent = v;
		v = p;
		p = g;
	}
	r->parent = NULL;
	return r;
}

static void modifyBranchLen(struct phyloTree *node, struct phyloTree *child) {
	if (node == NULL)
		return;
	modifyBranchLen(node->parent, node);
	node->distalpha = child->distalpha;
}

static void modifyTree() {
	struct phyloTree *anc, *nr;
	AllocVar(anc);
	anc->parent = NULL;
	anc->distalpha = 0;
	anc->name = cloneString("NEWROOT");
	modifyBranchLen(Ances->parent, Ances);
	Ances->distalpha = 0;
	nr = Ances->parent;
	if (Ances == nr->child[RIGHT]) {
		anc->child[LEFT] = NULL;
		anc->child[RIGHT] = Ances;
		Ances->parent = anc;
		nr->child[RIGHT] = NULL;
	}
	else {
		anc->child[RIGHT] = NULL;
		anc->child[LEFT] = Ances;
		Ances->parent = anc;
		nr->child[LEFT] = NULL;
	}
	nr = rerootTree(nr);
	if (anc->child[LEFT] == NULL)
		anc->child[LEFT] = nr;
	else
		anc->child[RIGHT] = nr;
	Ances = anc;
	adjustNextInTree(Ances);
	Phylo = Ances;
}

static void sortWeightedEdges() {
	struct edgeList *q, *p;
	int i, j;
	double val;
	for (i = A; i < Z; i++) {
		for (j = A; j < Z; j++) {
			if (Val(DPPI, i, j) == NO)
				continue;
			if ((val = PVal(PPP, i, j)) > 0) {
				AllocVar(p);
				p->i = i;
				p->j = j;
				p->wei = val;
				if (Edgelist == NULL)
					Edgelist = p;
				else if (p->wei > Edgelist->wei) {
					p->next = Edgelist;
					Edgelist = p;
				}
				else {
					for (q = Edgelist; q->next; q = q->next) {
						if (p->wei > q->next->wei 
							|| (q->i == map(p->j) && q->j == map(p->i)))
							break;
					}
					p->next = q->next;
					q->next = p;
				}
			}
		}				
	}
}

static void modifyAuxGraph() {
	int i;
	struct edgeList *p;
	int start[N], end[N];
	for (i = A; i < N; i++)
		start[i] = end[i] = 0;
	for (p = Edgelist; p; p = p->next) {
		if (start[p->i] == 0 && end[p->j] == 0) {
			Set(G, p->i, p->j, YES);
			Set(G, map(p->j), map(p->i), YES);
			if (p->i != A) 
				start[p->i] = end[map(p->i)] = 1;
			if (p->j != Z) 
				end[p->j] = start[map(p->j)] = 1;
		}
	}
}

static void removeCycles() {
	int i, j, s, starti, total;
	int mini, minj;
	double minwei = 2.0;
	int used[N], buf[N];
	mini = minj = 0;
	for (i = A; i < N; i++)
		used[i] = 0;
	for (;;) {
		for (i = A+1; i < Z; i++)
			if (used[i] == 0)
				break;
		if (i == Z)
			break;
		starti = i;
		total = 0;
		for (;;) {
			buf[total++] = i;
			used[i] = 1;
			for (j = A+1; j < Z; j++)
				if (Val(G, i, j) && used[j] == 0)
					break;
			if (j == Z) {
				if (Val(G, i, starti)) {
					for (s = 0; s < total; s++) {
						if (PVal(PPP, buf[s], buf[(s+1)%total]) < minwei) {
							mini = buf[s];
							minj = buf[(s+1)%total];
							minwei = PVal(PPP, buf[s], buf[(s+1)%total]);
						}
					}
					Set(G, mini, minj, NO);
					mini = minj = 0;
					minwei = 2.0;
				}					
				break;
			}
			else 
				i = j;
		}
	}
}

static void freeTreeNode(struct phyloTree **node) {
	struct phyloTree *p = *node;
	freeMem(p->name);
	slFreeList(&(p->genome));
	freez(node);
}

static void freeTreeSpace(struct phyloTree **root) {
	struct phyloTree **ppt = root;
	struct phyloTree *next = *ppt;
	struct phyloTree *node;
	while (next != NULL) {
		node = next;
		next = node->next;
		freeTreeNode(&node);
	}
	*ppt = NULL;
}

static void printTree(struct phyloTree *node) {
    struct phyloTree *p = node;
    struct phyloTree *pleft = p->child[LEFT];
    struct phyloTree *pright = p->child[RIGHT];

    if (p->next != NULL)
        fprintf(stderr, "Node %s(%.4f, next=%s)\n", p->name, p->distalpha, p->next->name);
    else
        fprintf(stderr, "Node %s(%.4f, next=NULL)\n", p->name, p->distalpha);

    if (pleft != NULL) {
        if (pleft->next != NULL)
            fprintf(stderr, "\tLeft %s(%.4f, next=%s)\n", pleft->name, pleft->distalpha, pleft->next->name);
        else
            fprintf(stderr, "\tLeft %s(%.4f, next=NULL)\n", pleft->name, pleft->distalpha);
    }
    if (pright != NULL) {
        if (pright->next != NULL)
            fprintf(stderr, "\tRight %s(%.4f, next=%s)\n", pright->name, pright->distalpha, pright->next->name);
        else
            fprintf(stderr, "\tRight %s(%.4f, next=NULL)\n", pright->name, pright->distalpha);
    }

    if (pleft != NULL) printTree(pleft);
    if (pright != NULL) printTree(pright);
}


static void calculatePostProb() {
    int i, j;
    double pprob, pprob2, pmin, pmax, val;
    FILE *joinprobfile;

    joinprobfile = mustOpen("adjacencies.prob", "w");
    fprintf(joinprobfile, "#%d\n", T);
   
	pmin = pmax = 1; 
	for (i = A; i <= Z; i++) {
        for (j = A; j <= Z; j++) {
            if (pam(i) == 0 || pam(j) == 0) continue;
            if (Val(DPPI, i, j) == 0)
                continue;
            
			val = log(PVal(PLH, i, j)) + log(SVal(SLH, i, j));
			if (pmin == 1) pmin = val;
			else {
				if (val < pmin) pmin = val;
			}
			
			if (pmax == 1) pmax = val;
			else {
				if (val > pmax) pmax = val;
			}
		}
	}

    for (i = A; i <= Z; i++) {
        for (j = A; j <= Z; j++) {
            if (pam(i) == 0 && pam(j) == 0) continue;

            if (Val(DPPI, i, j) == 0)
                continue;
            pprob2 = PVal(PLH, i, j)*SVal(SLH, i, j);
            pprob = PVal(PPP, i, j) * SVal(SPP, i, j);
            fprintf(joinprobfile, "%d %d\t%e\n", pam(i), pam(j), pprob);
        }
    }

    fclose(joinprobfile);
}

int main(int argc, char *argv[]) {
	optionInit(&argc, argv, options);
	if (argc != 5)
		usage();
	alpha = atof(argv[2]);
	printf("alpha=%f\n", alpha);
	Phylo = readTreeFile(argv[3]);
	identifyOutgroup(Phylo);
	if (Ances != Phylo)
		modifyTree();
	assert(Ances == Phylo);
	initLeafList(Phylo);
	readGenomes(argv[4]);
	T = calculateTotalEle(argv[1], Phylo);
	fprintf(stderr, "T=%d\n", T);
	initSets(Leaf);
	fprintf(stderr, "Computing posterior probabilities ...\n");
	getPredecessor();
	getSuccessor();
	normalize();
	calculatePostProb();
	freeTreeSpace(&Phylo);
	freeSets(Leaf);
	slFreeList(&Leaf);
	slFreeList(&Edgelist);
	return 0;
}

