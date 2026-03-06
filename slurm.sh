#!/bin/sh
#SBATCH --job-name=pqtl_scan
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=6
#SBATCH --mail-type=ALL
#SBATCH --time=95:59:59
#SBATCH --mail-user=aaron.mitchell@bristol.ac.uk
#SBATCH --nodes=1
#SBATCH --account=sscm013902
#SBATCH --mem=48G
#SBATCH --ntasks=1

module load apps/plink1.9/1.90-b77

cd /user/work/vc23656/proteins

bash /user/work/vc23656/proteins/pipeline.sh