#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <io_lib/Read.h>

int staden_write_trace(SV *self, FILE *fh, int format,
		       char *seq, int len, SV *qual, char *id, char *desc) {
  Read *read;
  SV *val;
  AV *qualarr;
  unsigned char qval;
  int i, n;
  
  read = read_allocate(0, len);
  memcpy(read->base, seq, len + 1);

  if (NULL == (read->ident = (char *) xcalloc(strlen(id) + 1, 1))) {
    read_deallocate(read); return -2;
  }
  strcpy(read->ident, id);

  if (NULL == (read->info = (char *) xcalloc(strlen(desc) + 1, 1))) {
    read_deallocate(read); return -2;
  }
  strcpy(read->info, desc);

  read->format = format;
  read->leftCutoff = 0;
  read->rightCutoff = len + 1;
  
  qualarr = (AV *) SvRV(qual);
  n = av_len(qualarr) + 1;
  for (i = 0 ; i < n && i < len ; i++) {
    val = *(av_fetch(qualarr, i, 0));
    qval = (unsigned char) SvIV(val);

    switch (read->base[i]) {
    case 'A' :
    case 'a' :
      read->prob_A[i] = qval;
      break;
    case 'C' :
    case 'c' :
      read->prob_C[i] = qval;
      break;
    case 'G' :
    case 'g' :
      read->prob_G[i] = qval;
      break;
    case 'T' :
    case 't' :
      read->prob_T[i] = qval;
      break;
    case 'N' :
    case 'n' :
    case '-' :
      read->prob_A[i] = read->prob_C[i] =
	read->prob_G[i] = read->prob_T[i] = qval / 4;
      break;
    default :
      read->prob_A[i] = read->prob_C[i] =
	read->prob_G[i] = read->prob_T[i] = 0;
      break;
    }
}

  i = fwrite_reading(fh, read, format);

  read_deallocate(read);
  return i;
}

void staden_read_trace(SV *self, FILE *fh, int format) {
  dXSARGS;
  Read *read;
  SV *seq = NULL, *qual = NULL;
  char *bases, *pA, *pC, *pG, *pT, base, conf;
  int b, e;

  read = fread_reading(fh, (char *) NULL, format);

  if (read == NULLRead) {
      sp = mark; XPUSHs(&PL_sv_undef); PUTBACK;
      XSRETURN(1);
  }

  b = read->leftCutoff;
  if (b <= 0) b = 0;
  e = read->rightCutoff - 1;
  if (e < 0 || e > read->NBases) e = read->NBases;

  for (bases = &read->base[b],
	 pA = &read->prob_A[b], pC = &read->prob_C[b],
	 pG = &read->prob_G[b], pT = &read->prob_T[b]
	 ; b < e ;
       b++, bases++, pA++, pC++, pG++, pT++
       ) {

    base = *bases;
    if (base == '-') base = 'N';
    if (seq) {
      sv_catpvf(seq, "%c", base);
    } else {
      seq = newSVpvf("%c", base);
    }

    switch (base) {
    case 'A' :
    case 'a' :
      conf = *pA;
      break;
    case 'T' :
    case 't' :
      conf = *pT;
      break;
   case 'C' :
    case 'c' :
      conf = *pC;
      break;
    case 'G' :
    case 'g' :
      conf = *pG;
      break;
    case 'n' :
    case 'N' :
    case '-' :
      conf = (*pA + *pC + *pG + *pT) / 4;
      break;
    default :
      conf = 2; /* from the staden source code - 2 is the default confidence value */
      break;
    }
	
    if(qual) {
      sv_catpvf(qual, " %d", conf);
    } else {
      qual = newSVpvf("%d", conf);
    }
  }

  sp = mark;
  XPUSHs(sv_2mortal(seq));
  XPUSHs(sv_2mortal(newSVpvf("%s", read->ident)));
  XPUSHs(sv_2mortal(newSVpvf("%s", read->info)));
  XPUSHs(sv_2mortal(qual));
  PUTBACK;

  read_deallocate(read);
  XSRETURN(4);
}

void staden_read_graph(SV *self, FILE *fh, int format)
{
      dXSARGS;

      Read *read;

      AV *aTrace, *cTrace, *gTrace, *tTrace;
      SV *aVal, *cVal, *gVal, *tVal, *baseLoc;
      SV *aRef, *cRef, *gRef, *tRef, *baseRef;
      AV *baseLocs;

      unsigned short points, location, counter;

      aTrace = newAV();
      cTrace = newAV();
      gTrace = newAV();
      tTrace = newAV();
      baseLocs = newAV();

      read = fread_reading(fh, (char *) NULL, format);

      if (read == NULLRead)
      {
              sp = mark;
                XPUSHs(&PL_sv_undef);
                PUTBACK;
              XSRETURN(1);
      }

      for (points = 0; points < read->NPoints; points++)
      {
              aVal = newSVuv(read->traceA[points]);
              cVal = newSVuv(read->traceC[points]);
              gVal = newSVuv(read->traceG[points]);
              tVal = newSVuv(read->traceT[points]);
              av_push(aTrace, aVal);
              av_push(cTrace, cVal);
              av_push(gTrace, gVal);
              av_push(tTrace, tVal);
      }

      for (counter = 0; counter < read->NBases; counter++)
      {
              location = read->basePos[counter];
              baseLoc = newSVuv(location);
              av_push(baseLocs, baseLoc);
      }

      aRef = newRV_inc((SV *) aTrace);
      cRef = newRV_inc((SV *) cTrace);
      gRef = newRV_inc((SV *) gTrace);
      tRef = newRV_inc((SV *) tTrace);
      baseRef = newRV_inc(baseLocs);
      
      sp = mark;
      XPUSHs(sv_2mortal(baseRef));
      XPUSHs(sv_2mortal(aRef));
      XPUSHs(sv_2mortal(cRef));
      XPUSHs(sv_2mortal(gRef));
      XPUSHs(sv_2mortal(tRef));
      XPUSHs(sv_2mortal(newSViv(read->NPoints)));
      XPUSHs(sv_2mortal(newSViv(read->maxTraceVal)));
      PUTBACK;

      read_deallocate(read);
      XSRETURN(7);

}

MODULE = Bio::SeqIO::staden::read	PACKAGE = Bio::SeqIO::staden::read	

PROTOTYPES: DISABLE

int
staden_write_trace (self, fh, format, seq, len, qual, id, desc)
	SV *	self
	FILE *	fh
	int	format
	char *	seq
	int	len
	SV *	qual
	char *	id
	char *	desc

void
staden_read_trace (self, fh, format)
	SV *	self
	FILE *	fh
	int	format
	PREINIT:
	I32* temp;
	PPCODE:
	temp = PL_markstack_ptr++;
	staden_read_trace(self, fh, format);
	if (PL_markstack_ptr != temp) {
          /* truly void, because dXSARGS not invoked */
	  PL_markstack_ptr = temp;
	  XSRETURN_EMPTY; /* return empty stack */
        }
        /* must have used dXSARGS; list context implied */
	return; /* assume stack size is correct */

void
staden_read_graph (self, fh, format)
	SV *	self
	FILE *	fh
	int	format
	PREINIT:
	I32* temp;
	PPCODE:
	temp = PL_markstack_ptr++;
	staden_read_graph(self, fh, format);
	if (PL_markstack_ptr != temp) {
          /* truly void, because dXSARGS not invoked */
	  PL_markstack_ptr = temp;
	  XSRETURN_EMPTY; /* return empty stack */
        }
        /* must have used dXSARGS; list context implied */
	return; /* assume stack size is correct */

