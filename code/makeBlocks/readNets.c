/* ***************************************************************** 
 * Nets files can be downloaded directly from UCSC Genome Browser:
 * 		http://hgdownload.cse.ucsc.edu/downloads.html
 * This program retains large pieces longer than a certain 
 * length for further analysis.
 * *****************************************************************/

#include "util.h"
#include "species.h"
#include <dirent.h>
#include <string.h>
#include <libgen.h>

#define MAXDEP	30
#define SUFFIX	"raw.segs"

int get_level(char *s) {
	int i = 0;
	while (s[i] == ' ')
		++i;
	if (i > MAXDEP)
		fatalf("MAXDEP = %d not enough", MAXDEP);
	return i;
}

int main (int argc, char* argv[]) {
	FILE *nf, *of;
	char buf[500], type[20], chrom[50], refchrom[50], netfile[500], outfile[500], netdir[500];
	char gapchrom[MAXDEP][50], gaporient[MAXDEP];
	int level, fbeg, flen, sbeg, slen, cid, i, j, rs, ss;
	int fgapbeg[MAXDEP], fgapend[MAXDEP], sgapbeg[MAXDEP], sgapend[MAXDEP];
	int val[MAXDEP];
	char orient;

	DIR *dir;
    struct dirent *ent;
    char chrname[MAXCHR][100];
    char* token;
    char* fname;
    int chrcnt = 0;
    int ci;
	
	if (argc != 2)
		fatal("arg = configure-file");

	get_spename(argv[1]);
	get_netdir(argv[1]);
	get_minlen(argv[1]);
	rs = ref_spe_idx();
printf("MINLEN=%d\n", MINLEN); 

	// get list of reference chromosomes
    sprintf(netdir, "%s/%s/%s/net", Netdir, Spename[0], Spename[1]);
    if ((dir = opendir (netdir)) != NULL) {
        while ((ent = readdir(dir)) != NULL) {
            fname = basename(ent->d_name);
            token = strtok(fname, ".");
            if (token == NULL) continue;
            strcpy(chrname[chrcnt], token);
            chrcnt++;
        }
        closedir(dir);
    } else {
        fprintf(stderr, "Error - Could not open net dir %s\n", netdir);
        return 0;
    }

	// generate raw.segs files for each species
	for (ss = 0; ss < Spesz; ss++) {
		if (rs == ss)
			continue;
		sprintf(outfile, "%s.%s", Spename[ss], SUFFIX);
		of = ckopen(outfile, "w");
	
		for (ci = 0; ci < chrcnt; ci++) {

			sprintf(refchrom, "%s", chrname[ci]);

			sprintf(netfile, "%s/%s/%s/net/%s.net", 
								Netdir, Spename[0], Spename[ss], refchrom);
			
			if (access(netfile, F_OK) == -1) {
                		fprintf(stderr, "- skip %s (file not exists)\n", netfile);
                		continue;
           		}
			
			fprintf(stderr, "- reading %s\n", netfile);
			nf = ckopen(netfile, "r");

			for (i = 0; i < MAXDEP; i++)
				val[i] = 0;
		
			while (fgets(buf, 500, nf) != NULL) {
				if (buf[0] != '#')
					break;
			}
			if (feof(nf)) break;

			if (sscanf(buf, "net %s %*d", refchrom) != 1)
				fatalf("cannot parse: %s", buf);
			
			while (fgets(buf, 500, nf)) {
				if (sscanf(buf, "%s %*s", type) != 1)
					fatalf("cannot parse: %s", buf);
				if (same_string(type, "gap")) {
					level = get_level(buf);
					level /= 2;
					--level;
					if (sscanf(buf, "%*s %d %d %s %c %d %d %*s",
						   &(fgapbeg[level]), &(fgapend[level]), 
						   gapchrom[level], &(gaporient[level]),
						   &(sgapbeg[level]), &(sgapend[level])) != 6)
						fatalf("cannot parse: %s", buf);
					fgapend[level] += fgapbeg[level];
					sgapend[level] += sgapbeg[level];
					if (sgapend[level] - sgapbeg[level] > MINLEN) {
						fprintf(of, "%d g %s.%s:%d-%d %s.%s:%d-%d %c\n",
								level, Spename[rs], refchrom,
								fgapbeg[level], fgapend[level],
								Spename[ss], gapchrom[level],
								sgapbeg[level], sgapend[level],
								gaporient[level]);
					}
				}	 
				else if (same_string(type, "fill")) {
					level = get_level(buf);
					level /= 2;
					for (i = level; i < MAXDEP; i++)
						val[i] = 0;
					if (sscanf(buf, "%*s %d %d %s %c %d %d id %d %*s",
							   &fbeg, &flen, chrom, &orient, &sbeg, &slen, &cid) != 7)
						fatalf("cannot parse: %s", buf);
					if (flen > MINLEN || slen > MINLEN) {
						val[level] = 1;
						fprintf(of, "%d s %s.%s:%d-%d %s.%s:%d-%d %c %d",
								level, Spename[rs], refchrom, fbeg, fbeg + flen,
								Spename[ss], chrom, sbeg, sbeg + slen, orient, cid);
						if (level == 0)
							fprintf(of, "\n");
						else {
							for (j = level-1; j >= 0; j--)
								if (val[j] == 1)
									break;
							if (j < 0)
								fprintf(of, " [NP]\n");
							else
								fprintf(of, " [%d %d %s %d %d %c]\n",
											fgapbeg[j], fgapend[j], gapchrom[j],
											sgapbeg[j], sgapend[j], gaporient[j]);
						}
					}
				}
			}
			fclose(nf);
		}
		fclose(of);
	}	
	return 0;
}

