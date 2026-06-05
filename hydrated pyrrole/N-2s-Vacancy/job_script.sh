#!/bin/bash
#SBATCH --job-name=Pyr_O2s_40
#SBATCH --partition=cpu
#SBATCH --nodes=1
#SBATCH --ntasks=17
#SBATCH --mem=85GB
#SBATCH --ntasks-per-node=17
#SBATCH --cpus-per-task=1
#SBATCH --time=71:59:59

module load intel-compilers/2024.0.0
module load impi/2021.11.0
module load GCC/13.2.0
module load FFTW/3.3.10
module load imkl/2024.0.0

dftdir=/scratch/group/p.phy240167.000/codes/varga_dft_code_parallel/release/


cd $SLURM_SUBMIT_DIR

mpirun -n 17 $dftdir/dft > output 2> error
