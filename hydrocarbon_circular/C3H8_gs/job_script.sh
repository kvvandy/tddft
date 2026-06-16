#!/bin/bash
#SBATCH --job-name=gs_test
#SBATCH --account=van128
#SBATCH --partition=shared
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem=2G
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --time=47:59:59

module purge
module load cpu/0.17.3b intel/19.1.3.304/6pv46so fftw/3.3.10/jq4mbmk intel-mkl/2020.4.304/vg6aq26

# libxc runtime path (THIS is the key fix)
export LIBXC=/expanse/lustre/projects/van128/yhu13/codes/libxc-7.0.0-intel-install
export LD_LIBRARY_PATH=$LIBXC/lib64:$LD_LIBRARY_PATH
export LIBRARY_PATH=$LIBXC/lib64:$LIBRARY_PATH
export CPATH=$LIBXC/include:$CPATH
export PKG_CONFIG_PATH=$LIBXC/lib64/pkgconfig:$PKG_CONFIG_PATH

# (optional) quick debug so you can see it in slurm output
echo "Using LIBXC=$LIBXC"
echo "$LD_LIBRARY_PATH" | tr ':' '\n' | grep libxc || echo "libxc missing from LD_LIBRARY_PATH"
ls -l $LIBXC/lib64/libxc.so.15

dftdir=/expanse/lustre/projects/van128/yhu13/varga_dft_code_serial-main/release

cd $SLURM_SUBMIT_DIR
$dftdir/dft > output 2> error

