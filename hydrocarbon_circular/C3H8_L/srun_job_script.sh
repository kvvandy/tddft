#!/bin/bash

#SBATCH --job-name=C3H8_L_3.5
#SBATCH --account=van128
#SBATCH --partition=shared
#SBATCH --nodes=1
#SBATCH --ntasks=5
#SBATCH --ntasks-per-node=5
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=2GB
#SBATCH --time=47:59:59
#SBATCH --signal=B:USR1@1800
#SBATCH --export=ALL

set -u

############################################
# Modules
############################################

module purge
module load cpu/0.15.4
module load intel/19.1.1.217
module load fftw/3.3.10/jq4mbmk
module load intel-mkl/2020.4.304/vg6aq26
module load intel-mpi/2019.10.317/ezrfjne
module load slurm

############################################
# Environment
############################################

export SLURM_EXPORT_ENV=ALL
export LIBXC_LIB=/expanse/lustre/projects/van128/yhu13/codes/libxc-7.0.0-intel-install/lib64
export LD_LIBRARY_PATH=$LIBXC_LIB:$LD_LIBRARY_PATH

############################################
# Path to code
############################################

dftdir=/expanse/lustre/projects/van128/yhu13/varga_dft_code_parallel-main/release

############################################
# Function to run the code
############################################

run_code() {
    echo "Starting job in scratch..."
    echo "PATH=$PATH"
    echo "LD_LIBRARY_PATH=$LD_LIBRARY_PATH"
    echo "SLURM_EXPORT_ENV=$SLURM_EXPORT_ENV"

    echo "Checking launcher:"
    /cm/shared/apps/slurm/current/bin/srun --version || true

    echo "Checking LibXC visibility:"
    ldd "$dftdir/dft" | grep -E 'libxc|libxcf03|mpi' || true

    /cm/shared/apps/slurm/current/bin/srun --mpi=pmi2 -n "$SLURM_NTASKS" \
        "$dftdir/dft" > output 2> error &

    MPI_PID=$!
}

############################################
# Setup scratch directory
############################################

ORIG_DIR="$SLURM_SUBMIT_DIR"
SCRATCH_BASE="/scratch/$USER/job_$SLURM_JOB_ID"

echo "Creating scratch directory: $SCRATCH_BASE"
mkdir -p "$SCRATCH_BASE" || exit 1

echo "Copying submit directory to scratch..."
rsync -a "$ORIG_DIR/" "$SCRATCH_BASE/" || exit 1

cd "$SCRATCH_BASE" || exit 1

############################################
# Determine absolute ground state path
############################################

GS_REL=$(grep -i "gs_path" control.inp | awk -F= '{print $2}' | tr -d ' ')

if [ -z "$GS_REL" ]; then
    echo "ERROR: gs_path not found in control.inp"
    exit 1
fi

GS_ABS=$(realpath "$ORIG_DIR/$GS_REL")

echo "Original GS relative path: $GS_REL"
echo "Absolute GS path: $GS_ABS"

sed -i "s|^\(.*gs_path *= *\).*|\1$GS_ABS|" control.inp

############################################
# Remove stale JOB_TO_BE_KILLED if present
############################################

if [ -f "JOB_TO_BE_KILLED" ]; then
    echo "Found stale JOB_TO_BE_KILLED file from a previous run. Deleting..."
    rm -f "JOB_TO_BE_KILLED"
fi

############################################
# Walltime signal handling
############################################

handle_usr1() {
    echo "[$(date)] 30 minutes remaining. Creating JOB_TO_BE_KILLED file."
    touch "JOB_TO_BE_KILLED"

    (
        sleep 1200
        if [ -n "${MPI_PID:-}" ] && kill -0 "$MPI_PID" 2>/dev/null; then
            echo "[$(date)] 10 minutes remaining. Forcing job termination."
            kill -TERM "$MPI_PID" 2>/dev/null || true
        fi
    ) &
}

trap 'handle_usr1' USR1

############################################
# Job information banner
############################################

echo "=============================================="
echo "SLURM Job ID        : $SLURM_JOB_ID"
echo "Running on node(s)  : $SLURM_JOB_NODELIST"
echo "Hostname (this node): $(hostname)"
echo "Working directory   : $(pwd)"
echo "=============================================="

############################################
# Extra diagnostics before run
############################################

echo "Checking DFT executable:"
ls -l "$dftdir/dft"

echo "Checking LibXC files:"
ls -l "$LIBXC_LIB/libxc.so.15"
ls -l "$LIBXC_LIB/libxcf03.so.15"

echo "Checking linker resolution before run:"
ldd "$dftdir/dft" | grep -E 'libxc|libxcf03|mpi' || true

############################################
# Run job
############################################

run_code

wait "$MPI_PID"
MPI_EXIT_CODE=$?

echo "Job finished with exit code $MPI_EXIT_CODE"

############################################
# Copy results back
############################################

echo "Copying results back to original directory..."
rsync -a --exclude control.inp --exclude 'slurm-*' "$SCRATCH_BASE/" "$ORIG_DIR/"

echo "Cleanup complete."
exit "$MPI_EXIT_CODE"
