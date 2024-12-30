#!/bin/bash
#
# 受Haohanyh Computer Software Products Open Source LICENSE保护 https://github.com/Hny0305Lin/LICENSE/blob/main/LICENSE
#
# ## musl-riscv-toolchain
#
# musl libc GCC 交叉编译工具链引导脚本
#
# 用法: ./bootstrap.sh <arch> [native-cross]
#
# 此脚本默认为支持的目标架构构建交叉编译器。如果指定了可选的
# "native-cross"选项，那么除了为目标构建交叉编译器外，脚本还会
# 使用目标交叉编译器构建一个链接到目标架构musl C库的本地编译器。
# 本地编译器安装在 ${SYSROOT}/usr/bin 目录中
#
# ## 支持的架构:
#
# - riscv32
# - riscv64
# - i386
# - x86_64
# - aarch64
#
# ## Tips: 最好在x86_64架构下运行其他架构的编译
#
# ## 目录结构
#
# - ${bootstrap_prefix}-${gcc_version}-${bootstrap_version}
#   - bin/
#     - {$triple}-{as,ld,gcc,g++,strip,objdump} # 主机二进制文件
#   - ${triple}                                 # 系统根目录
#     - include                                 # 目标头文件
#     - lib                                     # 目标库文件
#     - usr
#       - lib -> ../lib
#       - bin
#         - {as,ld,gcc,g++,strip,objdump}       # 目标二进制文件
#
# ## 浩瀚银河相关
# 该项目前身为 michaeljclark 作者，作者项目地址：https://github.com/michaeljclark/musl-riscv-toolchain 
#
# 浩瀚银河将为OpenHarmony 与 LiteOS 开发者们，提供Aarch64等架构的交叉编译工具链引导脚本、和编译工具链维护
# 为助推鸿蒙星闪开发发展，我们愿意贡献一份力量
# 我们保证，该项目将会：完整开放 + 完整文档提供 + 完整教程教学 + 完整应用展示
# 
# 同时，我们将会提供浩瀚银河镜像源 + 海星通社区镜像源无条件维护，为鸿蒙星闪开发者们提供良好国内环境

# utility functions
clean_build()
{
    rm -rf build stamps src
}

# GMP (gmp_version=6.1.2)
build_gmp()
{
  host=$1; shift
  test -f stamps/lib-gmp-${host} || (
    set -e
    test -d build/gmp-${host} || mkdir build/gmp-${host}
    cd build/gmp-${host}
    CFLAGS=-fPIE ../../src/gmp-${gmp_version}/configure \
        --disable-shared \
        --prefix=${TOPDIR}/build/install-${host} \
        $*
    make -j$(nproc) && make install
  ) && touch stamps/lib-gmp-${host}
  test "$?" -eq "0" || exit 1
}

# MPFR (mpfr_version=3.1.4)
build_mpfr()
{
  host=$1; shift
  test -f stamps/lib-mpfr-${host} || (
    set -e
    test -d build/mpfr-${host} || mkdir build/mpfr-${host}
    cd build/mpfr-${host}
    CFLAGS=-fPIE ../../src/mpfr-${mpfr_version}/configure \
        --disable-shared \
        --prefix=${TOPDIR}/build/install-${host} \
        --with-gmp=${TOPDIR}/build/install-${host} \
        $*
    make -j$(nproc) && make install
  ) && touch stamps/lib-mpfr-${host}
  test "$?" -eq "0" || exit 1
}

# MPC (mpc_version=1.0.3)
build_mpc()
{
  host=$1; shift
  test -f stamps/lib-mpc-${host} || (
    set -e
    test -d build/mpc-${host} || mkdir build/mpc-${host}
    cd build/mpc-${host}
    CFLAGS=-fPIE ../../src/mpc-${mpc_version}/configure \
        --disable-shared \
        --prefix=${TOPDIR}/build/install-${host} \
        --with-gmp=${TOPDIR}/build/install-${host} \
        --with-mpfr=${TOPDIR}/build/install-${host} \
        $*
    make -j$(nproc) && make install
  ) && touch stamps/lib-mpc-${host}
  test "$?" -eq "0" || exit 1
}

# ISL (isl_version=0.16.1)
build_isl()
{
  host=$1; shift
  if [ "${build_graphite}" = "yes" ]; then
    test -f stamps/lib-isl-${host} || (
      set -e
      test -d build/isl-${host} || mkdir build/isl-${host}
      cd build/isl-${host}
      CFLAGS=-fPIE ../../src/isl-${isl_version}/configure \
          --disable-shared \
          --prefix=${TOPDIR}/build/install-${host} \
          --with-gmp-prefix=${TOPDIR}/build/install-${host} \
          $*
      make -j$(nproc) && make install
    ) && touch stamps/lib-isl-${host}
    test "$?" -eq "0" || exit 1
  fi
}

# CLOOG (cloog_version=0.18.4)
build_cloog()
{
  host=$1; shift
  if [ "${build_graphite}" = "yes" ]; then
    test -f stamps/lib-cloog-${host} || (
      set -e
      test -d build/cloog-${host} || mkdir build/cloog-${host}
      cd build/cloog-${host}
      CFLAGS=-fPIE ../../src/cloog-${cloog_version}/configure \
          --disable-shared \
          --prefix=${TOPDIR}/build/install-${host} \
          --with-isl-prefix=${TOPDIR}/build/install-${host} \
          --with-gmp-prefix=${TOPDIR}/build/install-${host} \
          $*
      make -j$(nproc) && make install
    ) && touch stamps/lib-cloog-${host}
    test "$?" -eq "0" || exit 1
  fi
}

case "$1" in
    clean)
        clean_build
        exit 0
        ;;
    mirror)
        DEFAULT_MIRROR="$2"
        shift 2
        ;;
    all)
        for arch in riscv32 riscv64 i386 x86_64 aarch64; do
            echo "Building for $arch..."
            ./$0 ${2:+mirror $2} $arch || exit 1
            echo "Completed $arch build"
        done
        exit 0
        ;;
    riscv32)
        ARCH=riscv32
        LINUX_ARCH=riscv
        WITHARCH=--with-arch=rv32imafdc
        ;;
    riscv64)
        ARCH=riscv64
        LINUX_ARCH=riscv
        WITHARCH=--with-arch=rv64imafdc
        ;;
    i386)
        ARCH=i386
        LINUX_ARCH=x86
        WITHARCH=--with-arch-32=core2
        ;;
    x86_64)
        ARCH=x86_64
        LINUX_ARCH=x86
        WITHARCH=--with-arch-64=core2
        ;;
    aarch64)
        ARCH=aarch64
        LINUX_ARCH=arm64
        WITHARCH=--with-arch=armv8-a
        ;;
    *)
        echo "Usage: $0 {riscv32|riscv64|i386|x86_64|aarch64}"
        exit 1
esac

set -e

# build dependency versions
gmp_version=6.1.2
mpfr_version=3.1.4
mpc_version=1.0.3
isl_version=0.16.1
cloog_version=0.18.4
binutils_version=2.31.1
musl_version=1.1.18-riscv-a6
linux_version=4.18
gcc_version=8.2.0
gdb_version=15.1

# optimization flags for size
COMMON_FLAGS="-Os -ffunction-sections -fdata-sections -fno-unwind-tables -fno-asynchronous-unwind-tables"
CFLAGS_FOR_BUILD="${COMMON_FLAGS}"
CXXFLAGS_FOR_BUILD="${COMMON_FLAGS}"
LDFLAGS_FOR_BUILD="-Wl,--gc-sections"

# bootstrap install prefix and version
bootstrap_prefix=/opt/riscv/musl-riscv-toolchain
bootstrap_version=1

# derived variables
PREFIX=${bootstrap_prefix}-${gcc_version}-${bootstrap_version}
TRIPLE=${ARCH}-linux-musl${SUFFIX}
SYSROOT=${PREFIX}/${TARGET:=$TRIPLE}
TOPDIR=$(pwd)

# mirror sites
DEFAULT_MIRROR="default"
declare -A MIRROR_SITES=(
    # default urls 默认配置
    ["default:gmp"]="https://gmplib.org/download/gmp-${gmp_version}"
    ["default:mpfr"]="https://gcc.gnu.org/pub/gcc/infrastructure"
    ["default:mpc"]="https://gcc.gnu.org/pub/gcc/infrastructure"
    ["default:isl"]="https://gcc.gnu.org/pub/gcc/infrastructure"
    ["default:cloog"]="http://www.bastoul.net/cloog/pages/download"
    ["default:binutils"]="https://ftp.gnu.org/gnu/binutils"
    ["default:musl"]="https://codeload.github.com/rv8-io/musl-riscv/tar.gz"
    ["default:linux"]="https://cdn.kernel.org/pub/linux/kernel/v4.x"
    ["default:gcc"]="http://ftp.gnu.org/gnu/gcc/gcc-${gcc_version}"
    ["default:gdb"]="https://ftp.gnu.org/gnu/gdb"

    # github mirror (histarcom海星通社区源，暂时留空) 海星通社区源为指定版本, 不存储其他版本, 浩瀚银河维护者维护



    
    
    # china mirror (清华镜像) 清华缺少isl, cloog, musl
    ["china:gmp"]="https://mirrors.tuna.tsinghua.edu.cn/gnu/gmp"
    ["china:mpfr"]="https://mirrors.tuna.tsinghua.edu.cn/gnu/mpfr"
    ["china:mpc"]="https://mirrors.tuna.tsinghua.edu.cn/gnu/mpc"
    ["china:isl"]="https://gcc.gnu.org/pub/gcc/infrastructure"
    ["china:cloog"]="http://www.bastoul.net/cloog/pages/download"
    ["china:binutils"]="https://mirrors.tuna.tsinghua.edu.cn/gnu/binutils"
    ["china:musl"]="https://codeload.github.com/rv8-io/musl-riscv/tar.gz"
    ["china:linux"]="https://mirrors.tuna.tsinghua.edu.cn/kernel/v4.x"
    ["china:gcc"]="https://mirrors.tuna.tsinghua.edu.cn/gnu/gcc/gcc-${gcc_version}"
    ["china:gdb"]="https://mirrors.tuna.tsinghua.edu.cn/gnu/gdb"

    # ustc mirror (中科大镜像) 中科大缺少isl, cloog, musl, linux
    ["ustc:gmp"]="https://mirrors.ustc.edu.cn/gnu/gmp"
    ["ustc:mpfr"]="https://mirrors.ustc.edu.cn/gnu/mpfr"
    ["ustc:mpc"]="https://mirrors.ustc.edu.cn/gnu/mpc"
    ["ustc:isl"]="https://gcc.gnu.org/pub/gcc/infrastructure"
    ["ustc:cloog"]="http://www.bastoul.net/cloog/pages/download"
    ["ustc:binutils"]="https://mirrors.ustc.edu.cn/gnu/binutils"
    ["ustc:musl"]="https://codeload.github.com/rv8-io/musl-riscv/tar.gz"
    ["ustc:linux"]="https://cdn.kernel.org/pub/linux/kernel/v4.x"
    ["ustc:gcc"]="https://mirrors.ustc.edu.cn/gnu/gcc/gcc-${gcc_version}"
    ["ustc:gdb"]="https://mirrors.ustc.edu.cn/gnu/gdb"

    # haohanyh mirror (浩瀚银河福州大本营镜像) 浩瀚银河镜像源为指定版本, 不存储其他版本, 敬请谅解
    ["haohanyh:gmp"]="https://mirrors.haohanyh.com/gnu/gmp"
    ["haohanyh:mpfr"]="https://mirrors.haohanyh.com/gnu/mpfr"
    ["haohanyh:mpc"]="https://mirrors.haohanyh.com/gnu/mpc"
    ["haohanyh:isl"]="https://mirrors.haohanyh.com/gcc/infrastructure"
    ["haohanyh:cloog"]="http://www.bastoul.net/cloog/pages/download"
    ["haohanyh:binutils"]="https://mirrors.haohanyh.com/gnu/binutils"
    ["haohanyh:musl"]="https://mirrors.haohanyh.com/github-release/rv8-io/musl-riscv"
    ["haohanyh:linux"]="https://mirrors.haohanyh.com/kernel/v4.x"
    ["haohanyh:gcc"]="https://mirrors.haohanyh.com/gnu/gcc/gcc-${gcc_version}"
    ["haohanyh:gdb"]="https://mirrors.haohanyh.com/gnu/gdb"
)

make_directories()
{
  test -d src || mkdir src
  test -d build || mkdir build
  test -d stamps || mkdir stamps
  test -d archives || mkdir archives
  test -d ${PREFIX} || mkdir -p ${PREFIX}
}

download_prerequisites()
{
  # 使用指定的镜像源或默认源
  local mirror=${1:-$DEFAULT_MIRROR}
  
  # GMP
  local gmp_url="${MIRROR_SITES["${mirror}:gmp"]}/gmp-${gmp_version}.tar.bz2"
  test -f archives/gmp-${gmp_version}.tar.bz2 || \
      curl -o archives/gmp-${gmp_version}.tar.bz2 ${gmp_url}

  # MPFR  
  local mpfr_url="${MIRROR_SITES["${mirror}:mpfr"]}/mpfr-${mpfr_version}.tar.bz2"
  test -f archives/mpfr-${mpfr_version}.tar.bz2 || \
      curl -o archives/mpfr-${mpfr_version}.tar.bz2 ${mpfr_url}

  # MPC
  local mpc_url="${MIRROR_SITES[${mirror}:mpc]}/mpc-${mpc_version}.tar.gz"
  test -f archives/mpc-${mpc_version}.tar.gz || \
      curl -o archives/mpc-${mpc_version}.tar.gz ${mpc_url}

  # ISL
  local isl_url="${MIRROR_SITES[${mirror}:isl]}/isl-${isl_version}.tar.bz2"
  test -f archives/isl-${isl_version}.tar.bz2 || \
      curl -o archives/isl-${isl_version}.tar.bz2 ${isl_url}

  # CLOOG
  local cloog_url="${MIRROR_SITES[${mirror}:cloog]}/cloog-${cloog_version}.tar.gz"
  test -f archives/cloog-${cloog_version}.tar.gz || \
      curl -o archives/cloog-${cloog_version}.tar.gz ${cloog_url}

  # BINUTILS
  local binutils_url="${MIRROR_SITES[${mirror}:binutils]}/binutils-${binutils_version}.tar.bz2"
  test -f archives/binutils-${binutils_version}.tar.bz2 || \
      curl -o archives/binutils-${binutils_version}.tar.bz2 ${binutils_url}

  # MUSL
  local musl_url="${MIRROR_SITES[${mirror}:musl]}/${musl_version}"
  test -f archives/musl-riscv-${musl_version}.tar.gz || \
      curl -o archives/musl-riscv-${musl_version}.tar.gz ${musl_url}

  # LINUX
  local linux_url="${MIRROR_SITES[${mirror}:linux]}/linux-${linux_version}.tar.xz"
  test -f archives/linux-${linux_version}.tar.xz || \
      curl -L -o archives/linux-${linux_version}.tar.xz ${linux_url}

  # GCC
  local gcc_url="${MIRROR_SITES[${mirror}:gcc]}/gcc-${gcc_version}.tar.xz"
  test -f archives/gcc-${gcc_version}.tar.xz || \
      curl -o archives/gcc-${gcc_version}.tar.xz ${gcc_url}

  # GDB
  local gdb_url="${MIRROR_SITES[${mirror}:gdb]}/gdb-${gdb_version}.tar.xz"
  test -f archives/gdb-${gdb_version}.tar.xz || \
      curl -o archives/gdb-${gdb_version}.tar.xz ${gdb_url}
}

# 解压所有下载的源码包
extract_archives()
{
  # 依次解压各个组件的源码包到src目录
  test -d src/gmp-${gmp_version} || \
      tar -C src -xjf archives/gmp-${gmp_version}.tar.bz2
  test -d src/mpfr-${mpfr_version} || \
      tar -C src -xjf archives/mpfr-${mpfr_version}.tar.bz2
  test -d src/mpc-${mpc_version} || \
      tar -C src -xzf archives/mpc-${mpc_version}.tar.gz
  test -d src/isl-${isl_version} || \
      tar -C src -xjf archives/isl-${isl_version}.tar.bz2
  test -d src/cloog-${cloog_version} || \
      tar -C src -xzf archives/cloog-${cloog_version}.tar.gz
  test -d src/binutils-${binutils_version} || \
      tar -C src -xjf archives/binutils-${binutils_version}.tar.bz2
  test -d src/musl-riscv-${musl_version} || \
      tar -C src -xzf archives/musl-riscv-${musl_version}.tar.gz
  test -d src/linux-${linux_version} || \
      tar -C src -xJf archives/linux-${linux_version}.tar.xz
  test -d src/gcc-${gcc_version} || \
      tar -C src -xJf archives/gcc-${gcc_version}.tar.xz
  test -d src/gdb-${gdb_version} || \
      tar -C src -xJf archives/gdb-${gdb_version}.tar.xz
}

# 为musl打补丁,修复C++相关问题
patch_musl()
{
  test -f src/musl-riscv-${musl_version}/.patched || (
    set -e
    cd src/musl-riscv-${musl_version}
    # 应用stdbool补丁以支持C++
    patch -p0 < ../../patches/musl-stdbool-cpluscplus.patch
    touch .patched
  )
  test "$?" -eq "0" || exit 1
}

# 配置musl的编译环境
configure_musl()
{
  test -f stamps/musl-config-${ARCH} || (
    set -e
    # 复制源码到构建目录
    rsync -a src/musl-riscv-${musl_version}/ build/musl-${ARCH}/
    cd build/musl-${ARCH}
    # 创建musl的配置文件
    echo prefix= > config.mak
    echo exec_prefix= >> config.mak
    echo ARCH=${ARCH} >> config.mak
    # 设置交叉编译工具链
    echo CC=${PREFIX}/bin/${TRIPLE}-gcc >> config.mak
    echo AS=${PREFIX}/bin/${TRIPLE}-as >> config.mak
    echo LD=${PREFIX}/bin/${TRIPLE}-ld >> config.mak
    echo AR=${PREFIX}/bin/${TRIPLE}-ar >> config.mak
    echo RANLIB=${PREFIX}/bin/${TRIPLE}-ranlib >> config.mak
  ) && touch stamps/musl-config-${ARCH}
  test "$?" -eq "0" || exit 1
}

# 安装musl的头文件
install_musl_headers()
{
  test -f stamps/musl-headers-${ARCH} || (
    set -e
    cd build/musl-${ARCH}
    # 安装头文件到sysroot
    make DESTDIR=${SYSROOT} install-headers
    # 创建必要的符号链接
    mkdir -p ${SYSROOT}/usr
    test -L ${SYSROOT}/usr/lib || ln -s ../lib ${SYSROOT}/usr/lib
    test -L ${SYSROOT}/usr/include || ln -s ../include ${SYSROOT}/usr/include
  ) && touch stamps/musl-headers-${ARCH}
  test "$?" -eq "0" || exit 1
}

# 构建musl C库
build_musl()
{
  test -f stamps/musl-dynamic-${ARCH} || (
    set -e
    cd build/musl-${ARCH}
    # 编译musl
    make -j$(nproc)
    # 安装库文件到sysroot
    make DESTDIR=${SYSROOT} install-libs
  ) && touch stamps/musl-dynamic-${ARCH}
  test "$?" -eq "0" || exit 1
}

# 安装Linux内核头文件
install_linux_headers()
{
  test -f stamps/linux-headers-${ARCH} || (
    set -e
    mkdir -p build/linux-headers-${ARCH}/staged
    # 从Linux源码安装头文件
    ( cd src/linux-${linux_version} && \
        make ARCH=${LINUX_ARCH} O=../../build/linux-headers-${ARCH} \
             INSTALL_HDR_PATH=../../build/linux-headers-${ARCH}/staged headers_install )
    # 清理不需要的文件
    find build/linux-headers-${ARCH}/staged/include '(' -name .install -o -name ..install.cmd ')' -exec rm {} +
    # 复制头文件到sysroot
    rsync -a build/linux-headers-${ARCH}/staged/include/ ${SYSROOT}/usr/include/
  ) && touch stamps/linux-headers-${ARCH}
  test "$?" -eq "0" || exit 1
}

# 为GCC打补丁(当前未使用)
patch_gcc()
{
  test -f src/gcc-${gcc_version}/.patched || (
    set -e
    cd src/gcc-${gcc_version}
    #patch -p0 < ../../patches/gcc-7.1-strict-operands.patch
    touch .patched
  )
  test "$?" -eq "0" || exit 1
}

# BINUTILS (binutils_version=2.31.1)
build_binutils()
{
  host=$1; shift
  prefix=$1; shift
  destdir=$1; shift
  transform=$1; shift
  test -f stamps/binutils-${host}-${ARCH} || (
    set -e
    test -d build/binutils-${host}-${ARCH} || mkdir build/binutils-${host}-${ARCH}
    cd build/binutils-${host}-${ARCH}
    CFLAGS="${COMMON_FLAGS} -fPIE" \
    CXXFLAGS="${COMMON_FLAGS} -fPIE" \
    LDFLAGS="${LDFLAGS_FOR_BUILD}" \
    ../../src/binutils-${binutils_version}/configure \
        --prefix=${prefix} \
        --target=${TARGET:=$TRIPLE} ${WITHARCH} \
        ${transform:+--program-transform-name='s&^&'${TRIPLE}'-&'} \
        --with-sysroot=${SYSROOT} \
        --libdir=${prefix}/lib \
        --with-slibdir=${prefix}/lib \
        --enable-plugins \
        --enable-gold \
        --enable-ld=default \
        --disable-nls \
        --disable-libssp \
        --disable-shared \
        --disable-werror  \
        --disable-multilib \
        --with-gmp=${TOPDIR}/build/install-${host} \
        --with-mpfr=${TOPDIR}/build/install-${host} \
        --with-mpc=${TOPDIR}/build/install-${host} \
        ${build_graphite:+--disable-isl-version-check} \
        ${build_graphite:+--with-isl=${TOPDIR}/build/install-${host}} \
        ${build_graphite:+--with-cloog=${TOPDIR}/build/install-${host}} \
        $*
    make -j$(nproc) all
    make DESTDIR=${destdir} install
    
    # 创建bfd-plugins目录
    mkdir -p ${destdir}${prefix}/lib/bfd-plugins
    
    # 构建和安装libdep.so插件
    if [ -f ${destdir}${prefix}/lib/gcc/${TARGET}/${gcc_version}/libcc1.so ]; then
      # 复制libcc1.so作为libdep.so的基础
      cp ${destdir}${prefix}/lib/gcc/${TARGET}/${gcc_version}/libcc1.so \
         ${destdir}${prefix}/lib/bfd-plugins/libdep.so
      # 设置正确的权限
      chmod 755 ${destdir}${prefix}/lib/bfd-plugins/libdep.so
    fi
    
  ) && touch stamps/binutils-${host}-${ARCH}
  test "$?" -eq "0" || exit 1
}

# 构建第一阶段的GCC(只支持C语言)
build_gcc_stage1()
{
  # musl编译器
  host=$1; shift
  prefix=$1; shift
  destdir=$1; shift
  transform=$1; shift
  test -f stamps/gcc-stage1-${host}-${ARCH} || (
    set -e
    test -d build/gcc-stage1-${host}-${ARCH} || mkdir build/gcc-stage1-${host}-${ARCH}
    cd build/gcc-stage1-${host}-${ARCH}
    CFLAGS=-fPIE ../../src/gcc-${gcc_version}/configure \
        --prefix=${prefix} \
        --target=${TARGET:=$TRIPLE} ${WITHARCH} \
        ${transform:+--program-transform-name='s&^&'${TRIPLE}'-&'} \
        --with-sysroot=${SYSROOT} \
        --with-gnu-as \
        --with-gnu-ld \
        --enable-languages=c,c++ \
        --enable-target-optspace \
        --enable-initfini-array \
        --enable-zlib \
        --enable-libgcc \
        --enable-tls \
        --disable-shared \
        --disable-threads \
        --disable-libatomic \
        --disable-libstdc__-v3 \
        --disable-libquadmath \
        --disable-libsanitizer \
        --disable-libvtv \
        --disable-libmpx \
        --disable-multilib \
        --disable-libssp \
        --disable-libmudflap \
        --disable-libgomp \
        --disable-libitm \
        --disable-nls \
        --disable-plugins \
        --disable-sjlj-exceptions \
        --disable-bootstrap \
        --with-gmp=${TOPDIR}/build/install-${host} \
        --with-mpfr=${TOPDIR}/build/install-${host} \
        --with-mpc=${TOPDIR}/build/install-${host} \
        ${build_graphite:+--disable-isl-version-check} \
        ${build_graphite:+--enable-cloog-backend=isl} \
        ${build_graphite:+--with-isl=${TOPDIR}/build/install-${host}} \
        ${build_graphite:+--with-cloog=${TOPDIR}/build/install-${host}} \
        $*
    make -j$(nproc) inhibit-libc=true all-gcc all-target-libgcc
    make DESTDIR=${destdir} inhibit-libc=true install-gcc install-target-libgcc
  ) && touch stamps/gcc-stage1-${host}-${ARCH}
  test "$?" -eq "0" || exit 1
}

# 构建最终的GCC(支持C和C++)
build_gcc_stage2()
{
  # 最终编译器
  host=$1; shift
  prefix=$1; shift
  destdir=$1; shift
  transform=$1; shift
  test -f stamps/gcc-stage2-${host}-${ARCH} || (
    set -e
    test -d build/gcc-stage2-${host}-${ARCH} || mkdir build/gcc-stage2-${host}-${ARCH}
    cd build/gcc-stage2-${host}-${ARCH}
    # 设置库目录为lib而不是lib64
    export gcc_cv_lib_path=lib
    CFLAGS_FOR_TARGET="${COMMON_FLAGS}" \
    CXXFLAGS_FOR_TARGET="${COMMON_FLAGS}" \
    CFLAGS="${COMMON_FLAGS} -fPIE" \
    CXXFLAGS="${COMMON_FLAGS} -fPIE" \
    LDFLAGS="${LDFLAGS_FOR_BUILD}" \
    CFLAGS=-fPIE ../../src/gcc-${gcc_version}/configure \
        --prefix=${prefix} \
        --target=${TARGET:=$TRIPLE} ${WITHARCH} \
        ${transform:+--program-transform-name='s&^&'${TRIPLE}'-&'} \
        --with-sysroot=${SYSROOT} \
        --libdir=${prefix}/lib \
        --with-slibdir=${prefix}/lib \
        --enable-target-optspace \
        --enable-multilib \
        --with-multilib-list=rmprofile \
        --with-specs="%{save-temps: -fverbose-asm} %{funwind-tables|fno-unwind-tables|mabi=*|ffreestanding|nostdlib:;:-funwind-tables}" \
        --with-gnu-as \
        --with-gnu-ld \
        --enable-languages=c,c++,fortran,objc,obj-c++ \
        --enable-initfini-array \
        --enable-zlib \
        --enable-libgcc \
        --enable-tls \
        --enable-shared \
        --enable-threads \
        --enable-libatomic \
        --enable-libstdc__-v3 \
        --enable-libgomp \
        --enable-libquadmath \
        --enable-libitm \
        --enable-libssp \
        --enable-libvtv \
        --enable-libmpx \
        --enable-libasan \
        --enable-libtsan \
        --enable-libubsan \
        --enable-libcilkrts \
        --enable-libstdcxx-time \
        --enable-libstdcxx-filesystem-ts \
        --enable-libstdcxx-threads \
        --enable-gnu-indirect-function \
        --enable-gnu-unique-object \
        --enable-linker-build-id \
        --enable-lto \
        --enable-plugin \
        --enable-default-pie \
        --enable-default-ssp \
        --disable-multilib \
        --disable-libmudflap \
        --disable-nls \
        --disable-sjlj-exceptions \
        --disable-bootstrap \
        --with-gmp=${TOPDIR}/build/install-${host} \
        --with-mpfr=${TOPDIR}/build/install-${host} \
        --with-mpc=${TOPDIR}/build/install-${host} \
        ${build_graphite:+--disable-isl-version-check} \
        ${build_graphite:+--enable-cloog-backend=isl} \
        ${build_graphite:+--with-isl=${TOPDIR}/build/install-${host}} \
        ${build_graphite:+--with-cloog=${TOPDIR}/build/install-${host}} \
        $*
    make -j$(nproc) all
    make DESTDIR=${destdir} install

    # 构建特殊版本的libgcc
    cd ${destdir}${prefix}/${TARGET}/lib
    
    # 创建nano版本
    ${TRIPLE}-ar cr libgcc-nano.a $(${TRIPLE}-ar t libgcc.a | grep -v gcov)
    ${TRIPLE}-ar cr libgcc-nano-nopic.a $(${TRIPLE}-ar t libgcc.a | grep -v gcov | grep -v pic)
    
    # 创建nopic版本
    ${TRIPLE}-ar cr libgcc-nopic.a $(${TRIPLE}-ar t libgcc.a | grep -v pic)
    
    # 创建origin-noop版本
    ${TRIPLE}-ar cr libgcc-origin-noop.a $(${TRIPLE}-ar t libgcc.a | grep -v gcov | grep -v unwind)
    
    # 确保所有.o文件都存在
    for obj in crtbegin.o crtbeginS.o crtbeginT.o crtend.o crtendS.o crti.o crtn.o; do
      if [ ! -f $obj ]; then
        cp `${TRIPLE}-gcc -print-file-name=$obj` .
      fi
    done
    
    # 设置正确的权限
    chmod 644 *.a *.o
    
    # 创建include目录结构
    mkdir -p include/c++ include-fixed install-tools
    
    # 复制必要的头文件
    cp -r ${destdir}${prefix}/lib/gcc/${TARGET}/${gcc_version}/include/* include/
    cp -r ${destdir}${prefix}/lib/gcc/${TARGET}/${gcc_version}/include-fixed/* include-fixed/
    cp -r ${destdir}${prefix}/lib/gcc/${TARGET}/${gcc_version}/install-tools/* install-tools/

    # 确保所有库都被正确安装
    if [ -d ${destdir}${prefix}/${TARGET}/lib ]; then
      cd ${destdir}${prefix}/${TARGET}/lib
      # 创建必要的符号链接
      for lib in *.so.*; do
        if [ -f "$lib" ]; then
          base=$(echo $lib | sed 's/\.[0-9.]*$//')
          ln -sf $lib ${base}
          ln -sf $lib ${base}.0
        fi
      done
    fi
  ) && touch stamps/gcc-stage2-${host}-${ARCH}
  test "$?" -eq "0" || exit 1
}

# 构建GDB调试器
build_gdb()
{
  host=$1; shift
  prefix=$1; shift
  destdir=$1; shift
  transform=$1; shift
  test -f stamps/gdb-${host}-${ARCH} || (
    set -e
    test -d build/gdb-${host}-${ARCH} || mkdir build/gdb-${host}-${ARCH}
    cd build/gdb-${host}-${ARCH}
    CFLAGS=-fPIE ../../src/gdb-${gdb_version}/configure \
        --prefix=${prefix} \
        --target=${TARGET:=$TRIPLE} ${WITHARCH} \
        ${transform:+--program-transform-name='s&^&'${TRIPLE}'-&'} \
        --with-sysroot=${SYSROOT} \
        --disable-nls \
        --disable-werror \
        --disable-sim \
        --disable-gas \
        --disable-binutils \
        --disable-ld \
        --disable-gprof \
        --with-gmp=${TOPDIR}/build/install-${host} \
        --with-mpfr=${TOPDIR}/build/install-${host} \
        --with-mpc=${TOPDIR}/build/install-${host} \
        $*
    make -j$(nproc) && make DESTDIR=${destdir} install
  ) && touch stamps/gdb-${host}-${ARCH}
  test "$?" -eq "0" || exit 1
}


#
# 为主机构建musl libc工具链
#

make_directories
download_prerequisites
extract_archives
patch_musl
patch_gcc

# 按顺序构建所有组件
build_gmp             host
build_mpfr            host
build_mpc             host
build_isl             host
build_cloog           host
build_binutils        host ${PREFIX} / transform-name

configure_musl
install_musl_headers
install_linux_headers

build_gcc_stage1      host ${PREFIX} / transform-name
build_musl
build_gcc_stage2      host ${PREFIX} / transform-name
build_gdb            host ${PREFIX} / transform-name


#
# 如果指定了native-cross选项，为目标架构构建本地工具链
#
if [ "$2" = "native-cross" ]; then
  # 将新构建的工具链添加到PATH
  export PATH=${PREFIX}/bin:${PATH}

  # 为目标架构构建所有组件
  build_gmp             ${ARCH} --host=${TRIPLE}
  build_mpfr            ${ARCH} --host=${TRIPLE}
  build_mpc             ${ARCH} --host=${TRIPLE}
  build_isl             ${ARCH} --host=${TRIPLE}
  build_cloog           ${ARCH} --host=${TRIPLE}
  build_binutils        ${ARCH} /usr ${SYSROOT} '' --host=${TRIPLE}
  build_gcc_stage2      ${ARCH} /usr ${SYSROOT} '' --host=${TRIPLE}
  build_gdb            ${ARCH} /usr ${SYSROOT} '' --host=${TRIPLE}
fi