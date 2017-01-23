/* **************************************************************
 * This procedure maps a base in species 1 to the aligned based
 * in species 2. The alignment corresponds to whole genome best
 * alignment given in the Nets.
 * This is similar to the function of liftOver.
 * Chain files are needed.
 * **************************************************************/

#ifndef _BASE_H_
#define _BASE_H_

/* **************************************************************
 * Input:		cid			-	chain id
 * 					rspe		- reference species
 * 					rchr		-	reference chr 
 * 					rpos		-	position in the reference chr
 *					sspe		-	secondary species
 *					schr		-	secondary chr
 *					orient	-	orientation of secondary species
 *					side		-	"left" or "right", relative to rpos, useful
 *										if rpos correponds to a gap position
 *
 * Output:	spos		-	position in the secondary chr
 * 					newrpos	-	adjusted position in reference chr
 * **************************************************************/
void mapbase(int cid, char *rspe, char *rchr, int rpos, 
					char *sspe, char *schr, char orient, char *side, 
					int *spos, int *newrpos);

void free_chain_space(int sspe_idx);
#endif
