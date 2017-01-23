#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

/* -------------------------------------------------------------------------- */

/* program name */
static char *prog = "splitNet";

/* for line read in from net file */
static char line[LINE_MAX];
static char chrom[LINE_MAX];

/* command line options, defaults */
static struct options {
	char *in_file;
	char *out_dir;
	int out_dir_len;
	char *suffix;
} opt = {
	"/dev/stdin",
	NULL,
	0,
	".net"
};

/* -------------------------------------------------------------------------- */

/* unix-like error message */
static void unix_error(char *msg) {
	fprintf(stderr, "%s: %s: %s\n", prog, msg, strerror(errno));
	exit(EXIT_FAILURE);
}   

/* strdup, check for errors */
static char *Strdup(const char *s1) {
	char *p;

	if ((p = strdup(s1)) == NULL) {
		unix_error("stdrup failed");
	}

	return(p);
}

/* fopen, check for errors */
static FILE *Fopen(const char *filename, const char *mode) {
	FILE *p;

	if ((p = fopen(filename, mode)) == NULL) {
		unix_error("fopen failed");
	}

	return(p);
}

/* fgets, check for errors */
static char *Fgets(char *s, int n, FILE *stream) {
	char *p;

	if ((p = fgets(s, n, stream)) == NULL) {
		if (feof(stream) != 0) {
			return(NULL);
		} else if (ferror(stream) != 0) {
			unix_error("fgets failed");
		} else {
			fprintf(stderr, "%s: fgets failed really badly\n", prog);
			exit(EXIT_FAILURE);
		}
	}

	return(p);
}

/* malloc, checking for errors */
void *Malloc(size_t size) {
	void *p;

	if ((p = malloc(size)) == NULL) {
		unix_error("malloc failed");
	}

	return(p);
}

/* fclose, checking for erros */
void Fclose(FILE *stream) {
	if (fclose(stream) == EOF) {
		unix_error("fclose failed");
	}
}

/* -------------------------------------------------------------------------- */

/* print usage information */
static void usage(int status) {
	if (status == EXIT_SUCCESS) {
		printf("Usage: %s [-h] [-i <input file>] -o <output dir>\n", prog);
		printf("  -h   help\n");
		printf("  -i   combined net file to split [defaults to stdin]\n");
		printf("  -o   directory where the split nets will be placed\n");
	} else {
		fprintf(stderr, "%s: Try '%s -h' for usage information.\n", prog, prog);
	}

	exit(status);
}

/* process command line arguments */
static void parse_args(int argc, char **argv) {
	extern char *optarg;
	extern int optopt;
	int c;

	while((c = getopt(argc, argv, ":hi:o:")) != -1) {
		switch(c) {
		case 'h':
			usage(EXIT_SUCCESS);
			break;
		case 'i':
			opt.in_file = Strdup((const char *) optarg);
			break;
		case 'o':
			opt.out_dir = Strdup((const char *) optarg);
			opt.out_dir_len = (int) strlen(opt.out_dir);
			break;
		case ':':
			fprintf(stderr, "%s: Missing argument for -%c.\n", prog, (char) optopt);
			usage(EXIT_FAILURE);
			break;
		case '?':
			fprintf(stderr, "%s: Unrecognized option -%c.\n", prog, (char) optopt);
			usage(EXIT_FAILURE);
		}
	}

	if (opt.out_dir == NULL) {
		fprintf(stderr, "%s: -o argument required\n", prog);
		usage(EXIT_FAILURE);
	}
}

/* -------------------------------------------------------------------------- */

/* split a net file */
static void split_net(void) {
	FILE *input;
	FILE *output;
	int filename_len;
	char *filename;
	int open = 0;

	input = Fopen(opt.in_file, "r");

	/* make the output directory */
	if ((mkdir(opt.out_dir, S_IRWXU | S_IRWXG | S_IRWXO) == -1)) {
		if (errno != EEXIST) {
			unix_error("mkdir failed");
		}
	}

	/* very simple splitter */
	while (Fgets(line, LINE_MAX, input) != NULL) {
		/* find the net line */
		if (strstr(line, "net") == line) {
			/* get the chrom name */
			if (sscanf(line, "net %s ", chrom) != 1) {
				fprintf(stderr, "%s: Can't parse the following line:\n", prog);
				fprintf(stderr, "%s", line);
				exit(EXIT_FAILURE);
			}

			/* build the output filename */
			filename_len = opt.out_dir_len + (int) strlen(chrom) + (int) strlen(opt.suffix) + 2;
			filename = (char *) Malloc (filename_len * sizeof(char));
			
			strcpy(filename, opt.out_dir);
			strcat(filename, "/");
			strcat(filename, chrom);
			strcat(filename, opt.suffix);

			/* close if necessary */
			if (open) {
				Fclose(output);
			}

			output = Fopen(filename, "w");
			free(filename);

			fprintf(output, "%s", line);

			open = 1;

			continue;
		}

		if (! open) {
			fprintf(stderr, "Out of synch (didn't find net line?)\n");
			exit(EXIT_FAILURE);
		}

		fprintf(output, "%s", line);
	}

	Fclose(input);
}

/* -------------------------------------------------------------------------- */

int main(int argc, char **argv) {
	prog = argv[0];

	parse_args(argc, argv);
	split_net();
	
	return(EXIT_SUCCESS);
}
