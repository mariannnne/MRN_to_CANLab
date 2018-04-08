#!/bin/bash

# You can run this from anywhere, just make sure you have permissions: chmod 775 ./move_mod_files.sh
# After running bash ./run_make_noisemodel.sh
# run_make_noisemodel didn't put the modelling files in the right folder (doh!)
# this fixes that and also checks and logs their filesize so you can look for errors
#
# Edit below 	
#				CANSTUDYID 	for the name of your study in the CANLab directory
#
# This script will out put an error log for missing files and directories. Find it in the 
# Canlab directory Imaging/mrn_notes/noisemodmove_log
#
#
# THIS STILL HAS IAPS STUDY SPECIFIC SHIT IN IT - SLIGHT MOD NEEDED TO BE GENERAL
# TO DO: COMBINE WITH run_make_noisemodel .... which should be combined with mrn_to_canlab_v2 !!
# Marianne 2018

# STUDY-SPECIFIC VARIABLES:
CANSTUDYID="IAPS_Searchlight"		# new folder name for analysis

###########################################################
##### YOU SHOULD NOT NEED TO EDIT ANYTHING BELOW THIS #####
###########################################################

# allow globbing
shopt -s extglob

# set up data directories
studydir="/work/ics/data/projects/wagerlab/labdata/data/${CANSTUDYID}/Imaging"
err_log_dir="/work/ics/data/projects/wagerlab/labdata/data/${CANSTUDYID}/Imaging/mrn_notes"

for mrn_file in ${studydir}/M*; do
	cd $mrn_file
	subid=${PWD##*/}  # goes by ursi number, code will give you back the ursi 

	echo "Move spm_mod files and check size on Blanca log... by Marianne 2018" >  ${err_log_dir}/noisemodmove_log${subid}
	
	# repeat for as many functional scans that are in this subject folder
	for runs in $mrn_file/Functional/Preprocessed/*;do
		cd $runs
		runame=${PWD##*/} 

		if [ -f noise_model_1.mat ]; then
			FILENAME=noise_model_1.mat
			FILESIZE=$(stat -c%s "$FILENAME")
			echo "Size of $FILENAME = $FILESIZE bytes." >  ${err_log_dir}/noisemodmove_log${subid}
			mv ./noise_model_1.mat ./spm_modeling/noise_model_1.mat
		else
			echo "noise_model_1 didnt exist for ${subid} run ${runame}" >  ${err_log_dir}/noisemodmove_log${subid}
		fi
	done
done

echo "All done. Check your run logs in labdata/data/${CANSTUDYID}/Imaging/mrn_notes"
