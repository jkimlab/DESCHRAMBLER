#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

/* -------------------------------------------------------------------------- */

struct cBlock {
	struct cBlock *next;
	int size;
	int dt;
	int dq;
};       

struct chain {
	struct chain *next;
	struct cBlock *blockList;
	double score;
	char *tName;
	int tSize;
	int tStart,tEnd;
	char *qName;
	int qSize;
	char qStrand;
	int qStart,qEnd;
	int id;
};                                                          

struct fd_entry {
	struct fd_entry *next;
	char *chrom;
	FILE *fd;
};

/* -------------------------------------------------------------------------- */

/* program name */
static char *prog = "splitChain";

/* for line read in from chain file */
static char line[LINE_MAX];
static char tName[LINE_MAX];
static char qName[LINE_MAX];

/* file descriptor list */
static struct fd_entry *fd_head = NULL;
static struct fd_entry *fd_tail = NULL;

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
	".chain"
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
		printf("  -i   combined chain file to split [defaults to stdin]\n");
		printf("  -o   directory where the split chains will be placed\n");
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

static FILE *get_descriptor(char *chrom) {
	struct fd_entry *p, *new;
	char *filename;
	int filename_len;

	/* find the matching entry */
	for (p = fd_head; p != NULL; p = p->next) {
		if (strcmp(p->chrom, chrom) == 0) {
			break;
		}
	}

	/* no match, need to add an entry */
	if (p == NULL) {
		/* create the new entry */
		new = (struct fd_entry *) Malloc(sizeof(struct fd_entry));
		new->next = NULL;
		new->chrom = Strdup(chrom);

		/* build the filename */
		filename_len = opt.out_dir_len + (int) strlen(chrom) + (int) strlen(opt.suffix) + 2;
		filename = (char *) Malloc (filename_len * sizeof(char));

		strcpy(filename, opt.out_dir);
		strcat(filename, "/");
		strcat(filename, chrom);
		strcat(filename, opt.suffix);

		new->fd = Fopen(filename, "w");
		free(filename);

		/* add the fd entry */
		if (fd_head == NULL) {
			fd_head = new;
		} else {
			fd_tail->next = new;
		}

		fd_tail = new;
		p = new;
	}

	return(p->fd);
}

/* -------------------------------------------------------------------------- */

/* print a chain */
static void print_chain(struct chain *c) {
	struct cBlock *p;
	FILE *fd;

	fd = get_descriptor(c->tName);

	/* print out the header line */
	fprintf(fd, "chain %.0f %s %d + %d %d %s %d %c %d %d %d\n",
				c->score, c->tName, c->tSize, c->tStart,
				c->tEnd, c->qName, c->qSize, c->qStrand,
				c->qStart, c->qEnd, c->id);

	/* print out the data lines */
	for (p = c->blockList; p != NULL; p = p->next) {
		if (p->next != NULL) {
			fprintf(fd, "%d\t%d\t%d\n", p->size, p->dt, p->dq);
		} else {
			fprintf(fd, "%d\n", p->size);
		}
	}

	fprintf(fd, "\n");
}

/* read in the blocks for the argument chain */
static void read_blocks(struct chain *c, FILE *input) {
	struct cBlock *new, *tail;
	int count;

	tail = c->blockList;

	while (1) {
		if (Fgets(line, LINE_MAX, input) == NULL) {
			break;
		}

		/* allocate a new block */
		new = (struct cBlock *) Malloc(sizeof(struct cBlock));
		new->next = NULL;

		count = sscanf(line, "%d %d %d", &new->size, &new->dt, &new->dq);

		if (count != 1 && count != 3) {
			if (line[0] == '\n') {
				free(new);
				break;
			} else {
				fprintf(stderr, "%s: Can't parse the following data line:\n", prog);
				fprintf(stderr, "%s\n", line);
				exit(EXIT_FAILURE);
			}
		}

		/* add the block to the list */
		if (c->blockList == NULL) {
			c->blockList = new;
		} else {
			tail->next = new;
		}
		tail = new;
	}

}

/* read in the next chain */
static struct chain *get_next_chain(FILE *input) {
	struct chain *c;

	/* skip comments in chain file */
	line[0] = '#';
	while (line[0] == '#') {
		if (Fgets(line, LINE_MAX, input) == NULL) {
			return(NULL);
		}
	}

	/* allocate a new chain */
	c = (struct chain *) Malloc(sizeof(struct chain));

	/* read in the chain header line */
	if (sscanf(line, "chain %lf %s %d + %d %d %s %d %[+-] %d %d %d", &c->score,
			tName, &c->tSize, &c->tStart, &c->tEnd, qName, &c->qSize,
			&c->qStrand, &c->qStart, &c->qEnd, &c->id) != 11) {
		fprintf(stderr, "%s: Can't parse the following header line:\n", prog);
		fprintf(stderr, "%s\n", line);
		exit(EXIT_FAILURE);
	}

	/* copy the chromosome names */
	c->tName = Strdup(tName);
	c->qName = Strdup(qName);

	/* initialize pointers */
	c->next = NULL;
	c->blockList = NULL;

	/* read in the blocks */
	read_blocks(c, input);

	return(c);
}

/* free a chain */
static void free_chain(struct chain **c) {
	struct chain *p;
	struct cBlock *q;

	while(*c != NULL) {
		p = (*c)->next;

		free((*c)->tName);
		free((*c)->qName);

		/* free up the block list */
		while((*c)->blockList != NULL) {
			q = (*c)->blockList->next;

			free((*c)->blockList);

			(*c)->blockList = q;
		}

		free(*c);
		*c = p;
	}
}

/* split a chain file */
static void split_chain(void) {
	FILE *input;
	struct chain *c;

	input = Fopen(opt.in_file, "r");

	/* make the output directory */
	if ((mkdir(opt.out_dir, S_IRWXU | S_IRWXG | S_IRWXO) == -1)) {
		if (errno != EEXIST) {
			unix_error("mkdir failed");
		}
	}

	/* read and print each chain to the appropriate file */
	while((c = get_next_chain(input)) != NULL) {
		print_chain(c);
		free_chain(&c);
	}

	Fclose(input);
}

/* -------------------------------------------------------------------------- */

int main(int argc, char **argv) {
	prog = argv[0];

	parse_args(argc, argv);
	split_chain();
	
	return(EXIT_SUCCESS);
}
