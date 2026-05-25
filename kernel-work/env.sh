# Kernel build environment - source this before working with the kernel
export KERNEL_SRC="/home/z/my-project/kernel-work/linux-6.18.33"
export PREFIX="/home/z/my-project/kernel-work/tools"
export PATH="$PREFIX/bin:$PATH"
export LD_LIBRARY_PATH="$PREFIX/lib:$PREFIX/lib64:${LD_LIBRARY_PATH:-}"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/lib64/pkgconfig:${PKG_CONFIG_PATH:-}"

echo "Kernel build environment loaded."
echo "  Kernel source: $KERNEL_SRC"
echo "  Tools prefix:  $PREFIX"
