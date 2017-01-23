BIN ?= $(shell pwd)

all:
	sed -e 's:<pathtochainNet>:$(BIN)/examples/chainNet:g' examples/config.SFs.tmp > examples/config.SFs
	cd lib/kent/src/lib && ${MAKE}
	cd code/makeBlocks && ${MAKE}
	cd code && ${MAKE}

clean:
	cd lib/kent/src/lib && ${MAKE} clean
	cd code/makeBlocks && ${MAKE} clean
	cd code && ${MAKE} clean
	cd examples && rm -rf APCFs.300K config.SFs
