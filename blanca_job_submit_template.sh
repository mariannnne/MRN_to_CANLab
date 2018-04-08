#!/bin/bash

# To submit jobs to blanca
# for more than 24 hours use this notation: 1-00:00:00 (e.g. 1 day)

#SBATCH --job-name matlab_job
#SBATCH --time 8:00:00
#SBATCH --nodes 1
#SBATCH --ntasks-per-node 1
#SBATCH --ntasks 1
#SBATCH --mem 16G
#SBATCH --cpus-per-task 2
#SBATCH --hint=nomultithread
#SBATCH --output std_out.out
#SBATCH --qos blanca-ics

module load matlab/R2016b

mkdir -p /projects/bope9760/.matlab/$SLURM_JOB_ID

matlab -nodisplay -logfile ~/matlab.log -nodesktop -r "run path_to_script.m";

rm -rf /projects/bope9760/.matlab/$SLURM_JOB_ID