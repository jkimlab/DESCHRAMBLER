include ../inc/common.mk


O = verbose.o errabort.o dystring.o common.o dlist.o \
    wildcmp.o options.o osunix.o obscure.o pipeline.o memalloc.o \
    linefile.o localmem.o hash.o

jkweb.a: $(O)
	ar rcus jkweb.a $(O)

test:
	cd tests && ${MAKE} test

clean:
	rm -f ${O} jkweb.a

tags:
	etags ../inc/*.h ../lib/*.h ../lib/*.c  ../hg/inc/*.h ../hg/lib/*.h ../hg/lib/*.c ../hg/hgTracks/*.c ../hg/hgc/*.c ../hg/hgTrackUi/*.c
