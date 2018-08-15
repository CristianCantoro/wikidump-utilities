#!/bin/sh
#PBS -V
#PBS -l walltime=12:00:00
#PBS -N test_job
#PBS -l nodes=100:ppn=4
echo "job.sh running on:"
hostname

echo "going in workdir:" "$PBS_O_WORKDIR"
cd "$PBS_O_WORKDIR"
#mpirun --pernode ./main.sh
mpirun --pernode ./tellhostname.sh

exit
