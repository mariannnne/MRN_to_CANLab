#!/bin/bash

# You can run this from anywhere, just make sure you have permissions: chmod 775 ./run_make_noisemodel.sh
# After running bash ./mrn_to_canlab_v2.sh
# you can use this to make your noise models for first level GLMs
# You need to give it your study-specific wildcards for folder names.
# Edit below 	
#				CANSTUDYID 	for the name of your study in the CANLab directory
# This script will out put an error log for missing files and directories. Find it in the 
# Canlab directory Imaging/mrn_notes/noisemod_log
#
# Edit and save these MATLAB scripts in your CANLab Imaging directory under /Code/
#	mrn_qual_check.m
#	mrn_make_noise_model.m
#
# This script runs spike detection on the distortion corrected functional scans.
# This script includes (and therefore replaces) make_noise_model.m 
#
# THIS STILL HAS IAPS STUDY SPECIFIC SHIT IN IT - SLIGHT MOD NEEDED TO BE GENERAL
#
# Marianne 2018

# STUDY-SPECIFIC VARIABLES:
CANSTUDYID="IAPS_Searchlight"		# new folder name for analysis

###########################################################
##### YOU SHOULD NOT NEED TO EDIT ANYTHING BELOW THIS #####
###########################################################

module load matlab/R2016b
# allow globbing
shopt -s extglob

# set up data directories
studydir="/work/ics/data/projects/wagerlab/labdata/data/${CANSTUDYID}/Imaging"
err_log_dir="/work/ics/data/projects/wagerlab/labdata/data/${CANSTUDYID}/Imaging/mrn_notes"

for mrn_file in ${studydir}/M*; do
	cd $mrn_file
	subid=${PWD##*/}  # goes by ursi number, code will give you back the ursi 

	echo "Make noise model on Blanca log... by Marianne 2018" >  ${err_log_dir}/noisemod_log_${subid}
	
	# repeat for as many functional scans that are in this subject folder
	for runs in $mrn_file/Functional/Preprocessed/*;do
		cd $runs
		runame=${PWD##*/} 

		save_dir="${studydir}/${subid}/Functional/Preprocessed/${runame}"

		# perform data quality checks and create the nuisance covariates
		# using Tor's scn_session_spike_id
		# run in matlab
		if [ -f sepi_vr_motion_no_SBref.1D ]; then
			# make it a text file for matlab
			mv sepi_vr_motion_no_SBref.1D sepi_vr_motion_text_no_SBref.txt
			motion_file="sepi_vr_motion_text_no_SBref.txt"
		else
			echo "Missing afni motion regressors for ${subid} run ${runame}" >> ${err_log_dir}/noisemod_log_${subid}
		fi

		if [ -f d*no_SBref.nii* ]; then
			echo "distortion corrected images exist..."
			distort_im=d*_no_SBref.nii #need update
			echo "running spike id..."
			echo "We're about to go into MATLAB, hold onto your butts"
			# make this Nuisance_covariates_R.mat which contains R{1} and R{2} where
			# R{1} spikeids R{2} 24 motion regs
			# # may have to addpath to the repos addpath(genpath('/work/ics/data/projects/wagerlab/Repository'))
			fname=$(basename $save_dir/$distort_im)
			matlab -nodisplay -noFigureWindows -nodesktop -r "addpath('/work/ics/data/projects/wagerlab/labdata/data/IAPS_Searchlight/code/');mrn_make_nuisance('$fname','$motion_file','$save_dir'); exit;"
			# must store in noise_model_1.mat
			# IT WILL OUTPUT Nuisance_covariates.mat but this will be for each run instead of cells per run
			# instead of running make noise model, this skips that and creates the proper noise modeling file for you
			# noise_model_1.mat
			# # for testing: matlab -r 'try myfunction(argument1,argument2); catch; end; quit'
			echo "Matlab is done... $mrn_file complete"
		else
			echo "WARNING: No distortion corrected functional images exist for ${subid} run ${runame}... nuisance covariates not made" >> ${err_log_dir}/noisemod_log_${subid}
		fi
	done
done

echo "All done. Check your run logs to make sure nothing is missing."
