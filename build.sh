#!/bin/bash

set -eux

ZSTD_VERSION=1.5.7
ZSTD_SHA256=eb33e51f49a15e023950cd7825ca74a4a2b43db8354825ac24fc1b7ee09e6fa3

GMP_VERSION=6.3.0
GMP_SHA256=a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898

MPFR_VERSION=4.2.2
MPFR_SHA256=b67ba0383ef7e8a8563734e2e889ef5ec3c3b898a01d00fa0a6869ad81c6ce01

MPC_VERSION=1.3.1
MPC_SHA256=ab642492f5cf882b74aa0cb730cd410a81edcdbec895183ce930e706c1c759b8

ISL_VERSION=0.26
ISL_SHA256=a0b5cb06d24f9fa9e77b55fabbe9a3c94a336190345c2555f9915bb38e976504

EXPAT_VERSION=2.7.1
EXPAT_SHA256=354552544b8f99012e5062f7d570ec77f14b412a3ff5c7d8d0dae62c0d217c30

BINUTILS_VERSION=2.45
BINUTILS_SHA256=c50c0e7f9cb188980e2cc97e4537626b1672441815587f1eab69d2a1bfbef5d2

GCC_VERSION=15.2.0
GCC_SHA256=438fd996826b0c82485a29da03a72d71d6e3541a83ec702df4271f6fe025d24e

MINGW_VERSION=13.0.0
MINGW_SHA256=5afe822af5c4edbf67daaf45eec61d538f49eef6b19524de64897c6b95828caf

GDB_VERSION=16.3
GDB_SHA256=bcfcd095528a987917acf9fff3f1672181694926cc18d609c99d0042c00224c5

MAKE_VERSION=4.4.1
MAKE_SHA256=dd16fb1d67bfab79a72f5e8390735c49e3e8e70b4945a15ab1f81ddb78658fb3

ARCH=${1:-x86_64}
CRT=${2:-ucrt}

if [ "${CRT}" == "ucrt" ]; then
  EXTRA_CRT_ARGS="--with-default-msvcrt=ucrt"
elif [ "${CRT}" == "msvcrt" ]; then
  EXTRA_CRT_ARGS="--with-default-msvcrt=msvcrt-os"
else
  exit 1
fi

if [ "${ARCH}" == "i686" ]; then
  EXTRA_CRT_ARGS="${EXTRA_CRT_ARGS} --disable-lib64"
  EXTRA_GCC_ARGS="--disable-sjlj-exceptions --with-dwarf2"
elif [ "${ARCH}" == "x86_64" ]; then
  EXTRA_CRT_ARGS="${EXTRA_CRT_ARGS} --disable-lib32"
  EXTRA_GCC_ARGS=
else
  exit 1
fi

NAME=gcc-v${GCC_VERSION}-mingw-v${MINGW_VERSION}-${CRT}-${ARCH}
TARGET=${ARCH}-w64-mingw32

function get()
{
  mkdir -p ${SOURCE} && pushd ${SOURCE}
  FILE="${1##*/}"
  echo "$2 ${FILE}" | sha256sum -c - || rm -f ${FILE}
  if [ ! -f "${FILE}" ]; then
    curl -fL "$1" -o ${FILE}
    echo "$2 ${FILE}" | sha256sum -c -
    case "${1##*.}" in
    gz|tgz)
      tar --warning=none -xzf ${FILE}
      ;;
    bz2)
      tar --warning=none -xjf ${FILE}
      ;;
    xz)
      tar --warning=none -xJf ${FILE}
      ;;
    *)
      exit 1
      ;;
    esac
  fi
  popd
}

# by default place output in current folder
OUTPUT="${OUTPUT:-`pwd`}"

# place where source code is downloaded & unpacked
SOURCE=`pwd`/source

# place where build for specific target is done
BUILD=`pwd`/build-${CRT}/${TARGET}

# place where bootstrap compiler is built
BOOTSTRAP=`pwd`/bootstrap-${CRT}/${TARGET}

# place where build dependencies are installed
PREFIX=`pwd`/prefix-${CRT}/${TARGET}

# final installation folder
FINAL=`pwd`/${NAME}

get https://github.com/facebook/zstd/releases/download/v${ZSTD_VERSION}/zstd-${ZSTD_VERSION}.tar.gz                  ${ZSTD_SHA256}
get https://mirrors.kernel.org/gnu/gmp/gmp-${GMP_VERSION}.tar.xz                                                     ${GMP_SHA256}
get https://mirrors.kernel.org/gnu/mpfr/mpfr-${MPFR_VERSION}.tar.xz                                                  ${MPFR_SHA256}
get https://mirrors.kernel.org/gnu/mpc/mpc-${MPC_VERSION}.tar.gz                                                     ${MPC_SHA256}
get https://libisl.sourceforge.io/isl-${ISL_VERSION}.tar.xz                                                          ${ISL_SHA256}
get https://github.com/libexpat/libexpat/releases/download/R_${EXPAT_VERSION//./_}/expat-${EXPAT_VERSION}.tar.xz     ${EXPAT_SHA256}
get https://mirrors.kernel.org/gnu/binutils/binutils-${BINUTILS_VERSION}.tar.xz                                      ${BINUTILS_SHA256}
get https://mirrors.kernel.org/gnu/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.xz                                  ${GCC_SHA256}
get https://sourceforge.net/projects/mingw-w64/files/mingw-w64/mingw-w64-release/mingw-w64-v${MINGW_VERSION}.tar.bz2 ${MINGW_SHA256}
get https://mirrors.kernel.org/gnu/gdb/gdb-${GDB_VERSION}.tar.xz                                                     ${GDB_SHA256}
get https://mirrors.kernel.org/gnu/make/make-${MAKE_VERSION}.tar.gz                                                  ${MAKE_SHA256}

mkdir -p ${BUILD}/x-binutils && pushd ${BUILD}/x-binutils
sed -ri 's/(static bool insert_timestamp = )/\1!/' ${SOURCE}/binutils-${BINUTILS_VERSION}/ld/emultempl/pe*.em
export CFLAGS="-Os"
export CXXFLAGS="-Os"
export LDFLAGS="-s"
${SOURCE}/binutils-${BINUTILS_VERSION}/configure \
  --prefix=${BOOTSTRAP}                          \
  --with-sysroot=${BOOTSTRAP}                    \
  --target=${TARGET}                             \
  --disable-plugins                              \
  --disable-nls                                  \
  --disable-shared                               \
  --disable-multilib                             \
  --disable-werror
make -j`nproc`
make install
popd

mkdir -p ${BUILD}/x-mingw-w64-headers && pushd ${BUILD}/x-mingw-w64-headers
${SOURCE}/mingw-w64-v${MINGW_VERSION}/mingw-w64-headers/configure \
  --prefix=${BOOTSTRAP}                                           \
  --host=${TARGET}                                                \
  ${EXTRA_CRT_ARGS}
make -j`nproc`
make install
ln -sTf ${BOOTSTRAP} ${BOOTSTRAP}/mingw
popd

mkdir -p ${BUILD}/x-gcc && pushd ${BUILD}/x-gcc
${SOURCE}/gcc-${GCC_VERSION}/configure \
  --prefix=${BOOTSTRAP}                \
  --with-sysroot=${BOOTSTRAP}          \
  --target=${TARGET}                   \
  --enable-static                      \
  --enable-shared                     \
  --enable-lto                        \
  --disable-nls                        \
  --disable-multilib                   \
  --disable-werror                     \
  --disable-libgomp                    \
  --enable-languages=c,c++             \
  --enable-threads=posix               \
  --enable-checking=release            \
  --enable-large-address-aware         \
  --disable-libstdcxx-pch              \
  --disable-libstdcxx-verbose          \
  ${EXTRA_GCC_ARGS}
make -j`nproc` all-gcc
make install-gcc
popd

export PATH=${BOOTSTRAP}/bin:$PATH

mkdir -p ${BUILD}/x-mingw-w64-crt && pushd ${BUILD}/x-mingw-w64-crt
${SOURCE}/mingw-w64-v${MINGW_VERSION}/mingw-w64-crt/configure \
  --prefix=${BOOTSTRAP}                                       \
  --with-sysroot=${BOOTSTRAP}                                 \
  --host=${TARGET}                                            \
  --disable-dependency-tracking                               \
  --enable-warnings=0                                         \
  ${EXTRA_CRT_ARGS}
make -j`nproc`
make install
popd

mkdir -p ${BUILD}/x-mingw-w64-winpthreads && pushd ${BUILD}/x-mingw-w64-winpthreads
${SOURCE}/mingw-w64-v${MINGW_VERSION}/mingw-w64-libraries/winpthreads/configure \
  --prefix=${BOOTSTRAP}                                                         \
  --with-sysroot=${BOOTSTRAP}                                                   \
  --host=${TARGET}                                                              \
  --disable-dependency-tracking                                                 \
  --enable-static                                                               \
  --disable-shared                                                              \
  ${EXTRA_CRT_ARGS}
make -j`nproc`
make install
popd

pushd ${BUILD}/x-gcc
make -j`nproc`
make install
popd

mkdir -p ${BUILD}/zstd && pushd ${BUILD}/zstd
cmake ${SOURCE}/zstd-${ZSTD_VERSION}/build/cmake \
  -DCMAKE_BUILD_TYPE=Release                     \
  -DCMAKE_SYSTEM_NAME=Windows                    \
  -DCMAKE_INSTALL_PREFIX=${PREFIX}               \
  -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER      \
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY       \
  -DCMAKE_C_COMPILER=${TARGET}-gcc               \
  -DCMAKE_CXX_COMPILER=${TARGET}-g++             \
  -DZSTD_BUILD_STATIC=ON                         \
  -DZSTD_BUILD_SHARED=OFF                        \
  -DZSTD_BUILD_PROGRAMS=OFF                      \
  -DZSTD_BUILD_CONTRIB=OFF                       \
  -DZSTD_BUILD_TESTS=OFF
make -j`nproc`
make install
popd

mkdir -p ${BUILD}/gmp && pushd ${BUILD}/gmp
${SOURCE}/gmp-${GMP_VERSION}/configure \
  --prefix=${PREFIX}                   \
  --host=${TARGET}                     \
  --disable-shared                     \
  --enable-static                      \
  --enable-fat                         \
  CC=${TARGET}-gcc                     \
  CFLAGS="-O2 -std=gnu17"
make -j`nproc`
make install
popd

mkdir -p ${BUILD}/mpfr && pushd ${BUILD}/mpfr
${SOURCE}/mpfr-${MPFR_VERSION}/configure \
  --prefix=${PREFIX}                     \
  --host=${TARGET}                       \
  --disable-shared                       \
  --enable-static                        \
  --with-gmp-build=${BUILD}/gmp
make -j`nproc`
make install
popd

mkdir -p ${BUILD}/mpc && pushd ${BUILD}/mpc
${SOURCE}/mpc-${MPC_VERSION}/configure \
  --prefix=${PREFIX}                   \
  --host=${TARGET}                     \
  --disable-shared                     \
  --enable-static                      \
  --with-{gmp,mpfr}=${PREFIX}
make -j`nproc`
make install
popd

mkdir -p ${BUILD}/isl && pushd ${BUILD}/isl
${SOURCE}/isl-${ISL_VERSION}/configure \
  --prefix=${PREFIX}                   \
  --host=${TARGET}                     \
  --disable-shared                     \
  --enable-static                      \
  --with-gmp-prefix=${PREFIX}
make -j`nproc`
make install
popd

mkdir -p ${BUILD}/expat && pushd ${BUILD}/expat
${SOURCE}/expat-${EXPAT_VERSION}/configure \
  --prefix=${PREFIX}                       \
  --host=${TARGET}                         \
  --disable-shared                         \
  --enable-static                          \
  --without-examples                       \
  --without-tests
make -j`nproc`
make install
popd

mkdir -p ${BUILD}/binutils && pushd ${BUILD}/binutils
${SOURCE}/binutils-${BINUTILS_VERSION}/configure \
  --prefix=${FINAL}                              \
  --with-sysroot=${FINAL}                        \
  --host=${TARGET}                               \
  --target=${TARGET}                             \
  --enable-lto                                   \
  --enable-plugins                               \
  --enable-64-bit-bfd                            \
  --disable-nls                                  \
  --disable-multilib                             \
  --disable-werror                               \
  --with-{gmp,mpfr,mpc,isl}=${PREFIX}
make -j`nproc`
make install
popd

mkdir -p ${BUILD}/mingw-w64-headers && pushd ${BUILD}/mingw-w64-headers
${SOURCE}/mingw-w64-v${MINGW_VERSION}/mingw-w64-headers/configure \
  --prefix=${FINAL}/${TARGET}                                     \
  --host=${TARGET}                                                \
  ${EXTRA_CRT_ARGS}
make -j`nproc`
make install
ln -sTf ${FINAL}/${TARGET} ${FINAL}/mingw
popd

mkdir -p ${BUILD}/mingw-w64-crt && pushd ${BUILD}/mingw-w64-crt
${SOURCE}/mingw-w64-v${MINGW_VERSION}/mingw-w64-crt/configure \
  --prefix=${FINAL}/${TARGET}                                 \
  --with-sysroot=${FINAL}/${TARGET}                           \
  --host=${TARGET}                                            \
  --disable-dependency-tracking                               \
  --enable-warnings=0                                         \
  ${EXTRA_CRT_ARGS}
make -j`nproc`
make install
popd

mkdir -p ${BUILD}/gcc && pushd ${BUILD}/gcc
${SOURCE}/gcc-${GCC_VERSION}/configure \
  --prefix=${FINAL}                    \
  --with-sysroot=${FINAL}              \
  --target=${TARGET}                   \
  --host=${TARGET}                     \
  --disable-dependency-tracking        \
  --disable-nls                        \
  --disable-multilib                   \
  --disable-werror                     \
  --disable-shared                     \
  --enable-static                      \
  --enable-lto                         \
  --enable-languages=c,c++,lto         \
  --enable-libgomp                     \
  --enable-threads=posix               \
  --enable-checking=release            \
  --enable-mingw-wildcard              \
  --enable-large-address-aware         \
  --disable-libstdcxx-pch              \
  --disable-libstdcxx-verbose          \
  --disable-win32-registry             \
  --with-tune=intel                    \
  ${EXTRA_GCC_ARGS}                    \
  --with-{gmp,mpfr,mpc,isl,zstd}=${PREFIX}
make -j`nproc`
make install
popd

mkdir -p ${BUILD}/mingw-w64-winpthreads && pushd ${BUILD}/mingw-w64-winpthreads
${SOURCE}/mingw-w64-v${MINGW_VERSION}/mingw-w64-libraries/winpthreads/configure \
  --prefix=${FINAL}/${TARGET}                                                   \
  --with-sysroot=${FINAL}/${TARGET}                                             \
  --host=${TARGET}                                                              \
  --disable-dependency-tracking                                                 \
  --disable-shared                                                              \
  --enable-static
make -j`nproc`
make install
popd

mkdir -p ${BUILD}/gdb && pushd ${BUILD}/gdb
${SOURCE}/gdb-${GDB_VERSION}/configure     \
  --prefix=${FINAL}                        \
  --host=${TARGET}                         \
  --enable-64-bit-bfd                      \
  --disable-werror                         \
  --disable-source-highlight               \
  --with-static-standard-libraries         \
  --with-libexpat-prefix=${PREFIX}         \
  --with-{gmp,mpfr,mpc,isl,zstd}=${PREFIX} \
  CFLAGS="-O2 -std=gnu17"                  \
  CXXFLAGS="-O2 -D_WIN32_WINNT=0x0600"
make -j`nproc`
cp gdb/.libs/gdb.exe gdbserver/gdbserver.exe ${FINAL}/bin/
popd

mkdir -p ${BUILD}/make && pushd ${BUILD}/make
${SOURCE}/make-${MAKE_VERSION}/configure \
  --prefix=${FINAL}                      \
  --host=${TARGET}                       \
  --disable-nls                          \
  --disable-rpath                        \
  --enable-case-insensitive-file-system  \
  CFLAGS="-O2 -std=gnu17"
make -j`nproc`
make install
popd

rm -rf ${FINAL}/bin/${TARGET}-*
rm -rf ${FINAL}/bin/ld.bfd.exe ${FINAL}/${TARGET}/bin/ld.bfd.exe
rm -rf ${FINAL}/lib/bfd-plugins/libdep.dll.a
rm -rf ${FINAL}/share

find ${FINAL} -name '*.exe' -print0 | xargs -0 -n 8 -P 2 ${TARGET}-strip --strip-unneeded
find ${FINAL} -name '*.dll' -print0 | xargs -0 -n 8 -P 2 ${TARGET}-strip --strip-unneeded
find ${FINAL} -name '*.o'   -print0 | xargs -0 -n 8 -P 2 ${TARGET}-strip --strip-unneeded
find ${FINAL} -name '*.a'   -print0 | xargs -0 -n 8 -P `nproc` ${TARGET}-strip --strip-unneeded

rm ${FINAL}/mingw
7zr a -mx9 -mqs=on -mmt=on ${OUTPUT}/${NAME}.7z ${FINAL}

if [[ -v GITHUB_OUTPUT ]]; then
  echo "GCC_VERSION=${GCC_VERSION}"     >>${GITHUB_OUTPUT}
  echo "MINGW_VERSION=${MINGW_VERSION}" >>${GITHUB_OUTPUT}
  echo "GDB_VERSION=${GDB_VERSION}"     >>${GITHUB_OUTPUT}
  echo "MAKE_VERSION=${MAKE_VERSION}"   >>${GITHUB_OUTPUT}
fi