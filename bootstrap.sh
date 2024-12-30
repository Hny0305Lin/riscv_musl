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

MIRROR="default"  # 默认镜像源
ARCH_TYPE=""      # 目标架构
BUILD_TYPE=""     # 构建类型
COMPONENT=""      # 组件

# 显示帮助信息
show_usage() {
    echo "用法: $0 [选项] <架构>"
    echo "选项:"
    echo "  -m, --mirror <镜像源>    指定镜像源 (default|china|ustc)"
    echo "  -n, --native-cross      同时构建本地编译器"
    echo "  -c, --component <组件>   只构建指定组件(gmp|mpfr|mpc|isl|cloog|binutils|gcc1|gcc2|musl|gdb)"
    echo "  --clean [组件]          清理环境(不指定组件则清理全部)"
    echo "  -h, --help              显示此帮助信息"
    echo ""
    echo "支持的架构:"
    echo "  riscv32, riscv64, i386, x86_64, aarch64"
    echo ""
    echo "推荐示例:"
    echo "  $0 -m default aarch64             # 使用默认镜像源构建ARM64交叉编译器"
    echo "  $0 -m china -n riscv64            # 使用清华镜像源构建RISC-V 64位交叉编译器和本地编译器"
    echo "  $0 -m ustc x86_64                 # 使用中科大镜像源构建x86_64交叉编译器"
}

# 添加清理单个组件的函数
clean_component() {
    local component=$1
    case "$component" in
        gmp)
            rm -rf build/gmp-* stamps/lib-gmp-* src/gmp-*
            ;;
        mpfr)
            rm -rf build/mpfr-* stamps/lib-mpfr-* src/mpfr-*
            ;;
        mpc)
            rm -rf build/mpc-* stamps/lib-mpc-* src/mpc-*
            ;;
        isl)
            rm -rf build/isl-* stamps/lib-isl-* src/isl-*
            ;;
        cloog)
            rm -rf build/cloog-* stamps/lib-cloog-* src/cloog-*
            ;;
        binutils)
            rm -rf build/binutils-* stamps/binutils-* src/binutils-*
            ;;
        gcc1|gcc2)
            rm -rf build/gcc-* stamps/gcc-* src/gcc-*
            ;;
        musl)
            rm -rf build/musl-* stamps/musl-* src/musl-*
            ;;
        gdb)
            rm -rf build/gdb-* stamps/gdb-* src/gdb-*
            ;;
        all)
            echo "正在清理所有构建环境..."
            rm -rf build stamps archives src ${PREFIX}
            ;;
        *)
            echo "错误: 未知的组件 '$component'"
            echo "可清理的组件: gmp, mpfr, mpc, isl, cloog, binutils, gcc1, gcc2, musl, gdb, all"
            exit 1
            ;;
    esac
    echo "已清理组件: $component"
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--mirror)
            MIRROR="$2"
            shift 2
            ;;
        -n|--native-cross)
            BUILD_TYPE="native-cross"
            shift
            ;;
        -c|--component)
            COMPONENT="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        --clean)
            if [ -n "$2" ] && [[ "$2" != -* ]]; then
                clean_component "$2"
                shift 2
            else
                clean_component "all"
                shift
            fi
            exit 0
            ;;
        riscv32|riscv64|i386|x86_64|aarch64)
            ARCH_TYPE="$1"
            shift
            ;;
        *)
            echo "错误: 未知的选项或架构 '$1'"
            show_usage
            exit 1
            ;;
    esac
done

# 验证必要参数
if [ -z "$ARCH_TYPE" ]; then
    echo "错误: 必须指定目标架构"
    show_usage
    exit 1
fi
# 验证镜像源
case "$MIRROR" in
    default|china|ustc|haohanyh)
        DEFAULT_MIRROR="$MIRROR"
        ;;
    *)
        echo "错误: 不支持的镜像源 '$MIRROR'"
        show_usage
        exit 1
        ;;
esac

# 设置架构相关参数
case "$ARCH_TYPE" in
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
        echo "Usage: $0 {clean|riscv32|riscv64|i386|x86_64|aarch64}"
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
gcc_version=8.2.0
musl_version=1.1.18-riscv-a6
linux_version=4.18
gdb_version=8.2

# bootstrap install prefix and version
bootstrap_prefix=/opt/riscv/musl-riscv-toolchain
bootstrap_version=1

# derived variables
PREFIX=${bootstrap_prefix}-${gcc_version}-${bootstrap_version}
TRIPLE=${ARCH}-linux-musl${SUFFIX}
SYSROOT=${PREFIX}/${TARGET:=$TRIPLE}
TOPDIR=$(pwd)

# mirror sites
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
  local mirror_key="${DEFAULT_MIRROR}"
  
  test -f archives/gmp-${gmp_version}.tar.bz2 || \
      curl -o archives/gmp-${gmp_version}.tar.bz2 \
      "${MIRROR_SITES[${mirror_key}:gmp]}/gmp-${gmp_version}.tar.bz2"
      
  test -f archives/mpfr-${mpfr_version}.tar.bz2 || \
      curl -o archives/mpfr-${mpfr_version}.tar.bz2 \
      "${MIRROR_SITES[${mirror_key}:mpfr]}/mpfr-${mpfr_version}.tar.bz2"
      
  test -f archives/mpc-${mpc_version}.tar.gz || \
      curl -o archives/mpc-${mpc_version}.tar.gz \
      "${MIRROR_SITES[${mirror_key}:mpc]}/mpc-${mpc_version}.tar.gz"
      
  test -f archives/isl-${isl_version}.tar.bz2 || \
      curl -o archives/isl-${isl_version}.tar.bz2 \
      "${MIRROR_SITES[${mirror_key}:isl]}/isl-${isl_version}.tar.bz2"
      
  test -f archives/cloog-${cloog_version}.tar.gz || \
      curl -o archives/cloog-${cloog_version}.tar.gz \
      "${MIRROR_SITES[${mirror_key}:cloog]}/cloog-${cloog_version}.tar.gz"
      
  test -f archives/binutils-${binutils_version}.tar.bz2 || \
      curl -o archives/binutils-${binutils_version}.tar.bz2 \
      "${MIRROR_SITES[${mirror_key}:binutils]}/binutils-${binutils_version}.tar.bz2"
      
  test -f archives/musl-riscv-${musl_version}.tar.gz || \
      curl -o archives/musl-riscv-${musl_version}.tar.gz \
      "${MIRROR_SITES[${mirror_key}:musl]}/${musl_version}"
      
  test -f archives/linux-${linux_version}.tar.xz || \
      curl -L -o archives/linux-${linux_version}.tar.xz \
      "${MIRROR_SITES[${mirror_key}:linux]}/linux-${linux_version}.tar.xz"
      
  test -f archives/gcc-${gcc_version}.tar.xz || \
      curl -o archives/gcc-${gcc_version}.tar.xz \
      "${MIRROR_SITES[${mirror_key}:gcc]}/gcc-${gcc_version}.tar.xz"
      
  test -f archives/gdb-${gdb_version}.tar.xz || \
      curl -o archives/gdb-${gdb_version}.tar.xz \
      "${MIRROR_SITES[${mirror_key}:gdb]}/gdb-${gdb_version}.tar.xz"
}

extract_archives()
{
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

patch_musl()
{
  test -f src/musl-riscv-${musl_version}/.patched || (
    set -e
    cd src/musl-riscv-${musl_version}
    patch -p0 < ../../patches/musl-stdbool-cpluscplus.patch
    touch .patched
  )
  test "$?" -eq "0" || exit 1
}

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
    CFLAGS=-fPIE ../../src/binutils-${binutils_version}/configure \
        --prefix=${prefix} \
        --target=${TARGET:=$TRIPLE} ${WITHARCH} \
        ${transform:+--program-transform-name='s&^&'${TRIPLE}'-&'} \
        --with-sysroot=${SYSROOT} \
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
    make -j$(nproc) && make DESTDIR=${destdir} install
  ) && touch stamps/binutils-${host}-${ARCH}
  test "$?" -eq "0" || exit 1
}

configure_musl()
{
  test -f stamps/musl-config-${ARCH} || (
    set -e
    rsync -a src/musl-riscv-${musl_version}/ build/musl-${ARCH}/
    cd build/musl-${ARCH}
    echo prefix= > config.mak
    echo exec_prefix= >> config.mak
    echo ARCH=${ARCH} >> config.mak
    echo CC=${PREFIX}/bin/${TRIPLE}-gcc >> config.mak
    echo AS=${PREFIX}/bin/${TRIPLE}-as >> config.mak
    echo LD=${PREFIX}/bin/${TRIPLE}-ld >> config.mak
    echo AR=${PREFIX}/bin/${TRIPLE}-ar >> config.mak
    echo RANLIB=${PREFIX}/bin/${TRIPLE}-ranlib >> config.mak
  ) && touch stamps/musl-config-${ARCH}
  test "$?" -eq "0" || exit 1
}

install_musl_headers()
{
  test -f stamps/musl-headers-${ARCH} || (
    set -e
    cd build/musl-${ARCH}
    make DESTDIR=${SYSROOT} install-headers
    mkdir -p ${SYSROOT}/usr
    test -L ${SYSROOT}/usr/lib || ln -s ../lib ${SYSROOT}/usr/lib
    test -L ${SYSROOT}/usr/include || ln -s ../include ${SYSROOT}/usr/include
  ) && touch stamps/musl-headers-${ARCH}
  test "$?" -eq "0" || exit 1
}

install_linux_headers()
{
  test -f stamps/linux-headers-${ARCH} || (
    set -e
    mkdir -p build/linux-headers-${ARCH}/staged
    ( cd src/linux-${linux_version} && \
        make ARCH=${LINUX_ARCH} O=../../build/linux-headers-${ARCH} \
             INSTALL_HDR_PATH=../../build/linux-headers-${ARCH}/staged headers_install )
    find build/linux-headers-${ARCH}/staged/include '(' -name .install -o -name ..install.cmd ')' -exec rm {} +
    rsync -a build/linux-headers-${ARCH}/staged/include/ ${SYSROOT}/usr/include/
  ) && touch stamps/linux-headers-${ARCH}
  test "$?" -eq "0" || exit 1
}

build_gcc_stage1()
{
  # musl compiler
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

build_musl()
{
  test -f stamps/musl-dynamic-${ARCH} || (
    set -e
    cd build/musl-${ARCH}
    make -j$(nproc)
    make DESTDIR=${SYSROOT} install-libs
  ) && touch stamps/musl-dynamic-${ARCH}
  test "$?" -eq "0" || exit 1
}

build_gcc_stage2()
{
  # final compiler
  host=$1; shift
  prefix=$1; shift
  destdir=$1; shift
  transform=$1; shift
  test -f stamps/gcc-stage2-${host}-${ARCH} || (
    set -e
    test -d build/gcc-stage2-${host}-${ARCH} || mkdir build/gcc-stage2-${host}-${ARCH}
    cd build/gcc-stage2-${host}-${ARCH}
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
        --enable-shared \
        --enable-threads \
        --enable-libatomic \
        --enable-libstdc__-v3 \
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
    make -j$(nproc) all-gcc all-target-libgcc all-target-libstdc++-v3
    make DESTDIR=${destdir} install-gcc install-target-libgcc install-target-libstdc++-v3
  ) && touch stamps/gcc-stage2-${host}-${ARCH}
  test "$?" -eq "0" || exit 1
}

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
        --target=${TARGET:=$TRIPLE} \
        ${transform:+--program-transform-name='s&^&'${TRIPLE}'-&'} \
        --with-sysroot=${SYSROOT} \
        --with-python=no \
        --disable-werror \
        --disable-nls \
        --disable-sim \
        --disable-gas \
        --disable-binutils \
        --disable-ld \
        --disable-gprof \
        --disable-documentation \
        --with-gmp=${TOPDIR}/build/install-${host} \
        --with-mpfr=${TOPDIR}/build/install-${host} \
        $*
    make -j$(nproc) all
    make DESTDIR=${destdir} install
  ) && touch stamps/gdb-${host}-${ARCH}
  test "$?" -eq "0" || exit 1
}


#
# build musl libc toolchain for host
#

if [ -n "$COMPONENT" ]; then
    # 单个组件构建模式
    case "$COMPONENT" in
        gmp)
            build_gmp host
            ;;
        mpfr)
            build_mpfr host
            ;;
        mpc)
            build_mpc host
            ;;
        isl)
            build_isl host
            ;;
        cloog)
            build_cloog host
            ;;
        binutils)
            build_binutils host ${PREFIX} / transform-name
            ;;
        gcc1)
            build_gcc_stage1 host ${PREFIX} / transform-name
            ;;
        gcc2)
            build_gcc_stage2 host ${PREFIX} / transform-name
            ;;
        musl)
            configure_musl
            install_musl_headers
            build_musl
            ;;
        gdb)
            build_gdb host ${PREFIX} / transform-name
            ;;
        *)
            echo "错误: 未知的组件 '$COMPONENT'"
            echo "可用组件: gmp, mpfr, mpc, isl, cloog, binutils, gcc1, gcc2, musl, gdb"
            exit 1
            ;;
    esac
else
    # 原有的完整构建流程
    make_directories
    download_prerequisites
    extract_archives
    patch_musl
    patch_gcc

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
    build_gdb             host ${PREFIX} / transform-name

    # native-cross 部分保持不变...
fi


#
# build musl libc toolchain for target
#

if [ "$2" = "native-cross" ]; then

  export PATH=${PREFIX}/bin:${PATH}

  build_gmp             ${ARCH} --host=${TRIPLE}
  build_mpfr            ${ARCH} --host=${TRIPLE}
  build_mpc             ${ARCH} --host=${TRIPLE}
  build_isl             ${ARCH} --host=${TRIPLE}
  build_cloog           ${ARCH} --host=${TRIPLE}
  build_binutils        ${ARCH} /usr ${SYSROOT} '' --host=${TRIPLE}
  build_gcc_stage2      ${ARCH} /usr ${SYSROOT} '' --host=${TRIPLE}
  build_gdb             ${ARCH} /usr ${SYSROOT} '' --host=${TRIPLE}

fi