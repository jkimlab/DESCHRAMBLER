CC = gcc
GCC = g++
CDEBUG = -g#-ggdb -g -pg
OPTM =-O3
WARN = -W
KLIB = ../lib/kent/src/lib/
KINC = ../lib/kent/src/inc
CFLAGS = $(WARN) $(OPTM) -I. -I$(KINC)
CLIB = $(KLIB)/jkweb.a -lm

RM = rm -rf

ALLSRC = inferAdjProb deschrambler 

all: $(ALLSRC)

%: %.c
	$(CC) $(CDEBUG) $(CFLAGS) $+ $(CLIB) -o $@

%: %.cpp 
	$(GCC) $+ -o $@

.PHONY: tags
tags:
	ctags *.[hc] lib/*.[hc]	inc/*.h

.PHONY: clean
clean:
	$(RM) $(ALLSRC) *.o *.dSYM
	
