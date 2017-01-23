#include "util.h"

#define YES	0x01
#define NO	0x00
#define X	(sizeof(unsigned char))

static int A = 0; //first
static int T = 0; //# of ancestral elements
static int N = 0; //# of items in the array
static int Z = 0; //last one

static int map(int i) {
	if (i == A)
		return A;
	if (i == Z)
		return Z;
	return (i <= T) ? (i + T) : (i - T);
}

static unsigned char Val(unsigned char *H, int i, int j) {
	if (j < 0)
		j = map(-j);
	if (i < 0)
		i = map(-i);
	return *(H + (X * (i * N + j)));
}

static void Set(unsigned char *H, int i, int j, unsigned char value) {
	unsigned char *g;
	if (i < 0)
		i = map(-i);
	if (j < 0)
		j = map(-j);
	g = (H + (X * (i * N + j)));
	*g = value;
}

int main(int argc, char *argv[]) {
	FILE *realgenome, *predictedgenome;
	char buf[500];
	int total;
	int i, j;
	int rightjoin;
	unsigned char *R;
	if (argc !=3 && argc != 4)
		fatal("args: real_genome_joins_info predicted_genome_joins_info");
	predictedgenome = ckopen(argv[2], "r");
	if (fgets(buf, 500, predictedgenome) == NULL)
		fatalf("%s bad file", argv[1]);
	if (sscanf(buf, "#%d", &total) != 1)
		fatalf("bad file: %s", buf);
	T = total;
	Z = 2 * T + 1;
	A = 0;
	N = Z + 2;
	R = (unsigned char *)ckalloc(N*N*X);
	for (i = A; i < N; i++) {
		for (j = A; j < N; j++)
			Set(R, i, j, NO);
	}
	while(fgets(buf, 500, predictedgenome)) {
		if (sscanf(buf, "%d %d", &i, &j) != 2)
			fatalf("bad %s", buf);
		if (j == 0)
			Set(R, i, Z, YES);
		else
			Set(R, i, j, YES);
		if (i == 0)
			Set(R, -j, Z, YES);
		else
			Set(R, -j, -i, YES);
	}
	fclose(predictedgenome);
	
	realgenome = ckopen(argv[1], "r");
	while (fgets(buf, 500, realgenome)) {
		if (buf[0] == '#')
			continue;
		if (sscanf(buf, "%d %d", &i, &j) != 2)
			fatalf("bad %s", buf);
		if (j == 0) j = Z;
		if (Val(R, i, j) || Val(R, -j, -i))
			rightjoin = 1;
		else 
			rightjoin = 0;
		if (j == Z)
			j = 0;
		if (rightjoin == 0)
			printf("%d %d\n", i, j);
	}
	fclose(realgenome);
	free(R);
	return 0;
}
