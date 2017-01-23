ARCH ?= $(shell arch)

CC = gcc
CDEBUG = -ggdb -g -mcmodel=medium# -pg
OPTM = -O3
WARN = -W -Wall
CFLAGS = $(WARN) -I.

BIN = $(HOME)/bin/$(ARCH)
RM = rm -rf

ALLSRC = checkNets readNets getSegments partitionGenomes makeOrthologyBlocks \
		 makeOrthologyBlocks.pair \
         orthoBlocksToOrders makeConservedSegments outgroupSegsToOrders \
         cleanOutgroupSegs createGenomeFile createCarFile \
         splitChain splitNet onlySpe bpPosition mergePieces

OBJ = util.o base.o species.o

all: $(OBJ) $(ALLSRC)

%.o: %.c %.h
	$(CC) $(CDEBUG) $(CFLAGS) -c $(addsuffix .c, $(basename $@))

partitionGenomes: partitionGenomes.c $(OBJ)
	$(CC) $(CDEBUG) $(CFLAGS) $+ -o $@

%: %.c util.o species.o
	$(CC) $(CDEBUG) $(CFLAGS) $+ -o $@

.PHONY: clean
clean:
	$(RM) *.dSYM $(ALLSRC)  $(OBJ)
	
