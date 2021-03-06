#!/bin/bash
set -e # exit on errors
set -x # print commands and their arguments as they are executed

# Have normaliz testsuite print running time:
export NICE=time

# Limit number of threads
export OMP_NUM_THREADS=4

# Prepare configure flags
CONFIGURE_FLAGS="${CONFIGURE_FLAGS} --prefix=${INSTALLDIR}"

if [ "x$NO_OPENMP" != x ]; then
    CONFIGURE_FLAGS="${CONFIGURE_FLAGS} --disable-openmp"
fi

# install dependencies
if [[ $BUILDSYSTEM == *nauty* ]]; then
    CONFIGURE_FLAGS="${CONFIGURE_FLAGS} --with-nauty"
else
    CONFIGURE_FLAGS="${CONFIGURE_FLAGS} --without-nauty"
fi

if [[ $BUILDSYSTEM == *flint* || $BUILDSYSTEM == *eantic* ]]; then
    CONFIGURE_FLAGS="${CONFIGURE_FLAGS} --with-flint"
else
    CONFIGURE_FLAGS="${CONFIGURE_FLAGS} --without-flint"
fi

if [[ $BUILDSYSTEM == *eantic* ]]; then
    CONFIGURE_FLAGS="${CONFIGURE_FLAGS} --with-e-antic"
else
    CONFIGURE_FLAGS="${CONFIGURE_FLAGS} --without-e-antic"
fi

if [[ $BUILDSYSTEM == *cocoa* ]]; then
    CONFIGURE_FLAGS="${CONFIGURE_FLAGS} --with-cocoalib"
else
    CONFIGURE_FLAGS="${CONFIGURE_FLAGS} --without-cocoalib"
fi

# Build Normaliz.
./bootstrap.sh

if [[ -z $NO_COVERAGE ]]; then
    export CFLAGS="${CFLAGS} --coverage -O2 -g"
    export CXXFLAGS="${CXXFLAGS} --coverage -O2 -g"
    export LDFLAGS="${LDFLAGS} --coverage"
fi

if [[ $BUILDSYSTEM != makedistcheck ]]; then
    CONFIGURE_FLAGS="${CONFIGURE_FLAGS} --disable-shared"
fi

if [[ $BUILDSYSTEM == *extended* ]]; then
    export CPPFLAGS="${CPPFLAGS} -DNMZ_EXTENDED_TESTS"
fi

./configure ${CONFIGURE_FLAGS} || ( echo '#### Contents of config.log: ####'; cat config.log; exit 1)

case $BUILDSYSTEM in

    *static*)
        OPTLIBDIR=${INSTALLDIR}/lib

        # Remove shared libraries and libtool *.la files to force static linking
        rm -f ${OPTLIBDIR}/*.dylib*
        rm -f ${OPTLIBDIR}/*.so*
        rm -f ${OPTLIBDIR}/*la
        if [[ $OSTYPE == darwin* ]]; then
            BREWDIR=$(brew --prefix)
            rm -f ${BREWDIR}/lib/*gmp*.dylib*
            rm -f ${BREWDIR}/lib/*mpfr*.dylib*
            rm -f ${BREWDIR}/lib/*flint*.dylib*
        fi

        make -j2
        make install

        if [[ $OSTYPE == darwin* ]]; then
            install -m 0644 /usr/local/opt/llvm/lib/libomp.dylib ${INSTALLDIR}/bin
            install_name_tool -id "@loader_path/./libomp.dylib" ${INSTALLDIR}/bin/libomp.dylib
            install_name_tool -change "/usr/local/opt/llvm/lib/libomp.dylib" "@loader_path/./libomp.dylib" ${INSTALLDIR}/bin/normaliz
        fi

        if [[ $OSTYPE == darwin* ]]; then
            otool -L ${INSTALLDIR}/bin/*
        else
            ldd ${INSTALLDIR}/bin/*
        fi

        make check
        ;;

    makedistcheck)
        make -j2 distcheck
        ;;

    *)
        make -j2 -k
        make -j2 -k check
        make install
        make installcheck
        ;;
esac
