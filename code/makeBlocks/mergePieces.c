#include "util.h"

#define BIGNUM 500000000
#define Z 5000

struct block {
	char species[50], chrom[50];
	int beg, end;
	char orient;
};

int Total = 0;
int Order[Z];

void print_block(struct block *B) {
	int i;
	printf("%s.%s:%d-%d %c", 
			B->species,
			B->chrom,
			B->beg,
			B->end,
			B->orient);
	printf("\t");
	for (i = 0; i < Total; i++) {
		if (i == 0)
			printf("[%d", Order[i]);
		else
			printf(",%d", Order[i]);
	}
	printf("]\n");
}

void init_block(struct block *B) {
	B->species[0] = '\0';
	B->chrom[0] = '\0';
	B->orient = 'x';
	B->beg = BIGNUM;
	B->end = 0;
	Total = 0;
}

void add_to_block(struct block *B, char *spe, char *chr, 
				  int beg, int end, char ori, int num) {
	if (Total != 0) {
		if (!same_string(spe, B->species)
			|| !same_string(chr, B->chrom))
			fatalf("inconsistent: %d %s %s %s %s", num, spe, chr, B->species, B->chrom);
	}
	strcpy(B->species, spe);
	strcpy(B->chrom, chr);
	B->beg = MIN(B->beg, beg);
	B->end = MAX(B->end, end);
	B->orient = ori;
	Order[Total] = num;
	Total++;
}

int is_a_bp(int curr, char *fname) {
	FILE *fp;
	char buf[500];
	int isbp = 0;
	int a, b, prev = Order[Total-1];

	fp = ckopen(fname, "r");
	while(fgets(buf, 500, fp)) {
		if (sscanf(buf, "%d %d", &a, &b) != 2)
			fatalf("%s", buf);
		if ((prev == a && curr == b) || (prev == -b && curr == -a)) {
			isbp = 1;
			break;
		}
	}

	fclose(fp);
	return isbp;
}

int main(int argc, char *argv[]) {
	FILE *fp;
	char buf[500], spe[50], chr[50], ori;
	char *bpfile;
	int beg, end, num, k, bp;
	struct block B;
	
	if (argc != 3)
		fatal("arg: car-file breakpoints");
	
	bpfile = argv[2];
	fp = ckopen(argv[1], "r");
	
	while(fgets(buf, 500, fp)) {
		if (buf[0] == '#') {
			sscanf(buf, "#%d", &k);
			if (k > 1) 
				print_block(&B);
			printf("%s", buf);
			init_block(&B);
			continue;
		}
		if (sscanf(buf, "%[^.].%[^:]:%d-%d %c [%d]", 
						spe, chr, &beg, &end, &ori, &num) != 6)
			fatalf("%s", buf);
		if (ori =='-')
			num = -num;
		if (Total == 0) 
			add_to_block(&B, spe, chr, beg, end, ori, num);
		else {
			bp = is_a_bp(num, bpfile);
			if (bp == 1) {
				print_block(&B);
				init_block(&B);
				add_to_block(&B, spe, chr, beg, end, ori, num);			
			}
			else
				add_to_block(&B, spe, chr, beg, end, ori, num);

		}
	}
	print_block(&B);
	fclose(fp);

	return 0;
}
