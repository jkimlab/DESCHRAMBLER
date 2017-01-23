#include "util.h"

int main(int argc, char *argv[]) {
	FILE *fp;
	char buf[500];
	char spe[20];
	if (argc != 3)
		fatal("arg: species-name car");
	fp = ckopen(argv[2], "r");
	while(fgets(buf, 500, fp)) {
		if (buf[0] == '\n')
			continue;
		if (buf[0] == '#') {
			printf("%s", buf);
			continue;
		}
		if (sscanf(buf, "%[^.].%*s", spe) != 1)
			fatalf("%s", buf);
		if (same_string(spe, argv[1]))
			printf("%s", buf);			
	}
	fclose(fp);
	return 0;
}
