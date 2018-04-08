#!/bin/bash

# This script will pull your data from the MRN auto processing pipeline and put it into the appropriate
# file structure for analysis with canlab tools.
# You can run this from anywhere, just make sure you have permissions: chmod 775 ./mrn_to_canlab_v2.sh
# Run by entering: bash ./mrn_to_canlab_v2.sh
# You need to give it your study-specific wildcards for folder names.
# Edit below 	MRNSTUDYID 	for how to find your study in the MRN directory
#							this will be for the name of your study folder under twager/
#				CANSTUDYID 	for the name of your study in the CANLab directory
#				FUNC 		for the wildcard to pull your functional runs. NOTE: This avoids SBrefs!!
#				STRUCT 		for the wildcard to pull your structural data
#				TRIM 		how many scans to discard using disdaqs
#							Note: you likely do not need to do this / NOT YET IMPLEMENTED
# This script will out put an error log for missing files and directories. Find it in the 
# Canlab directory Imaging/mrn_notes
#
# Edit and save these MATLAB scripts in your CANLab Imaging directory under /Code/
#	mrn_qual_check.m
#	mrn_make_noise_model.m
#
# NOT TRUE IN THE VERSION - This script runs spike detection on the distortion corrected functional scans.
# NOT TRUE IN THE VERSION - This script includes (and therefore replaces) make_noise_model.m 
# This script also creates a 3Dprint folder with your subjects ready to be printed cortex
# This script sould run disdaqs for as specified number of images
# This script removes the first timepoint (the SBref) from the preprocesses functional images and 
# from the motion file sepi_vr_motion.1D file
#
# This script currently does not allow for disdaqs, this should be done in your modelling.
#
# Marianne 2018

# STUDY-SPECIFIC VARIABLES:
MRNSTUDYID="icap" 					# an identifier for the current study name (raw data)
CANSTUDYID="IAPS_Searchlight"		# new folder name for analysis
FUNC="IAPS*r" 						# identifier for functional image names
STRUCT="t1w" 						# identifier for structureal image names (If there is more than t1 it takes all)

# for testing: first one M80309514

###########################################################
##### YOU SHOULD NOT NEED TO EDIT ANYTHING BELOW THIS #####
###########################################################

# add freesurfer module
module add freesurfer/5.3.0

# allow globbing
shopt -s extglob

# set up data directories
basedir="/data/auto_analysis/human/twager/${MRNSTUDYID}*/AUTO_ANALYSIS/triotim" #mrn
basedir="/work/ics/data/projects/wagerlab/labdata/data/${CANSTUDYID}/MRN" #IAPS specific (remove later)
newdir="/work/ics/data/projects/wagerlab/labdata/data/${CANSTUDYID}/Imaging" #canlab format
mkdir -p ${newdir} #if the canlad directory doesn't exist, make it
mrnsubjdir="/M*/Study*" #for indexing of file dirs in mrn
err_log_dir="/work/ics/data/projects/wagerlab/labdata/data/${CANSTUDYID}/Imaging/mrn_notes"
mkdir ${err_log_dir}

#get preprocessed structural, move to appropriate folder
for mrn_file in ${basedir}/M*; do
	cd $mrn_file
	subid=${PWD##*/}  # goes by ursi number, code will give you back the ursi

	spgr=./S*/${STRUCT}*
	fs=./S*/analysis/fs*
	vbm=./S*/analysis/vbm
	func=./S*/${FUNC}*

	spgr="./S*/${STRUCT}*"
	fs="./S*/analysis/fs*mprage" #taking only one
	vbm="./S*/analysis/vbm"
	func="./S*/${FUNC}*"
	printmodel="./S*/analysis/fs*mprage/M*/surf"

	echo "MRN to CANLab transfer on Blanca log... by Marianne 2018" >  ${err_log_dir}/mrn_log_${subid}
	
	# copy preprocessed structural
	if [ -d $spgr ]; then
		cd $spgr
		echo "copying $mrn_file structural data..."
		mkdir -p ${newdir}/${subid}/Structural/SPGR #make canlab dir
		rsync -auR . ${newdir}/${subid}/Structural/SPGR #copy struc over
		cd $mrn_file
	else 
		echo "WARNING: No structural data for subj ${subid}" >>  ${err_log_dir}/mrn_log_${subid}
	fi

	# copy Freesurfer analysis
	if [ -d $fs ]; then
		cd $fs
		echo "copying $mrn_file FreeSurfer data..."
		mkdir -p ${newdir}/${subid}/Structural/FreeSurf #make canlab dir
		rsync -auR . ${newdir}/${subid}/Structural/FreeSurf #copy struc over
		cd $mrn_file
	else 
		echo "WARNING: No FreeSurfer data for subj ${subid}" >>  ${err_log_dir}/mrn_log_${subid}
	fi

	# create 3D printable cortex .stl file for subject
	if [ -d $printmodel ]; then
		cd $printmodel
		echo "converting cortex to 3D printable stl file for $mrn_file ..."
		mris_convert lh.pial lh.pial.stl
		mris_convert rh.pial rh.pial.stl
		echo "copying 3D printable stl file for $mrn_file ..."
		mkdir -p ${newdir}/${subid}/Structural/Print_Brain #make canlab dir
		rsync -auR ./*.stl ${newdir}/${subid}/Structural/Print_Brain #copy stl
		cd $mrn_file
	else 
		echo "WARNING: No FreeSurfer data for subj ${subid} Cannot make 3D printable file." >>  ${err_log_dir}/mrn_log_${subid}
	fi

	# copy VBM analysis
	if [ -d $vbm ]; then
		cd $vbm
		echo "copying $mrn_file VBM data..."
		mkdir -p ${newdir}/${subid}/Structural/VBM #make canlab dir
		rsync -auR . ${newdir}/${subid}/Structural/VBM #copy struc over
		cd $mrn_file
	else 
		echo "WARNING: No VBM data for subj ${subid}" >> ${err_log_dir}/mrn_log_${subid}
		#write warning to text file save in canlab dir
	fi
	cd $mrn_file

	# copy functional: preprocessed and raw
	# for now
	# /work/ics/data/projects/wagerlab/labdata/data/IAPS_Searchlight/MRN/M80309514/Study20141008at105815/IAPS_pa__32ch_mb8_v01_r01_0005
	# /work/ics/data/projects/wagerlab/labdata/data/IAPS_Searchlight/MRN/M80309514/Study20141008at105815/IAPS_pa_32ch_mb8_v01_r02_0007
	#i=0 # initiate counter
	#for funcfile in ${basedir}/M*/S*/$FUNC[0-9][0-9]['_'?][!'SBRef']*; do
	# repeat for as many functional scans that are in this subject folder
	for funcfile in $mrn_file/S*/$FUNC[0-9][0-9]['_'?][!'SBRef']*; do
		#i=$((i+1)) # update counter
		cd $funcfile
		funcid=${PWD##*/} 
		# identify if run1 or run2 and assign i
		if [[ $funcid = *"r01"* ]]; then
			i=1
			echo "Run 1 - $funcid"
  		fi
  		if [[ $funcid = *"r02"* ]]; then
			i=2
			echo "Run 2 - $funcid"
  		fi

		runame="r${i}_IAPS"
		mkdir -p ${newdir}/${subid}/Functional/Preprocessed/${runame}
		mkdir -p ${newdir}/${subid}/Functional/Raw/${runame}

		if [ -f $funcfile/d*.nii ]; then
			echo "Subj ${subid} preprocessed functionals exist for run ${runame}"
			# must remove the first timepoint (the SBref) from the  output files
			echo "removing SBref from swd for $mrn_file run $runame..."
			3dTcat -prefix d${funcid}_no_SBref.nii d*_.nii*'[1..$]'
		else
			echo "WARNING: Functional Preprocessing incomplete for ${subid} run ${runame} no swd and therefore no 3dTcat" >> ${err_log_dir}/mrn_log_${subid}
		fi

		if [ -f $funcfile/swd*_AQ.nii ]; then
			echo "Subj ${subid} preprocessed functionals exist for run ${runame}"
			# must remove the first timepoint (the SBref) from the  output files
			echo "removing SBref from swd for $mrn_file run $runame..."
			3dTcat -prefix swd${funcid}_AQ_no_SBref.nii swd*_AQ.nii'[1..$]'
		else
			echo "WARNING: Functional Preprocessing incomplete for ${subid} run ${runame} no swd and therefore no 3dTcat" >> ${err_log_dir}/mrn_log_${subid}
		fi

		# must remove the first timepoint (the SBref) from the final output file and the motion file sepi_vr_motion.1D file.
		echo "finding the motion regressors..."
		motion_file="./sepi_vr_motion.1D"
		if [ -f $motion_file ]; then
			echo "got motion...copying..."
			cp -p sepi_vr_motion.1D  sepi_vr_motion_no_SBref.1D
			echo "removing SBref from first line of motion regressors...new name is sepi_vr_motion_no_SBref"
			sed -i '1,1d' sepi_vr_motion_no_SBref.1D
			motion_file="sepi_vr_motion_no_SBref.1D"
		else
			echo "Missing afni motion regressors for ${subid} run ${runame}" >> ${err_log_dir}/mrn_log_${subid}
		fi

		# take all files in func
		echo "copying $mrn_file func preprocessed data run $runame..."
		rsync -auR . ${newdir}/${subid}/Functional/Preprocessed/${runame}

		# move single raw nii to raw folder
		mv ${newdir}/${subid}/Functional/Preprocessed/${runame}/${FUNC}*.nii* ${newdir}/${subid}/Functional/Raw/${runame}

		# MOVE TO NEW DIRECTORY FOR FURTHER PREPROC
		# perform data quality checks and create the nuisance covariates
		# using Tor's scn_session_spike_id
		# run in matlab
		cd ${newdir}/${subid}/Functional/Preprocessed/${runame}
		save_dir="${newdir}/${subid}/Functional/Preprocessed/${runame}"

		if [ -f d*.nii* ]; then
			echo "distortion corrected images exist..."
			distort_im=d*.nii*
			# if the last 2 char of the distor image are gz, gunzip em
			is_gz="$(echo $distort_im | grep -o ..$)"
			if [ $is_gz = "gz" ]; then
				echo "gunzipping the distortion corrected images..."
				gunzip $distort_im
			fi
			echo "removing distortion SBref..."
			3dTcat -prefix d${funcid}_no_SBref.nii d*.nii'[1..$]'
			echo "distortion SBref removed..."
			distort_im="d${funcid}_no_SBref.nii"

			# # REMOVE MATLAB FOR NOW - NOT WORKING BECAUSE OF A DISPLAY ISSUE IN SCN_SPIKE_ID
			# echo "running spike id..."
			# echo "We're about to go into MATLAB, hold onto your butts"
			# # the point is to make this Nuisance_covariates_R.mat which contains R{1} and R{2} where
			# # R{1} spikeids R{2} 24 motion regs
			# # may have to addpath to the repos addpath(genpath('/work/ics/data/projects/wagerlab/Repository'))
			# matlab -nodisplay -nojvm -noFigureWindows -r "addpath('/work/ics/data/projects/wagerlab/labdata/data/IAPS_Searchlight/code/');mrn_make_nuisance('$distort_im','$motion_file','$save_dir'); exit;"
			# # must store in noise_model_1.mat
			# # IT WILL OUTPUT Nuisance_covariates.mat but this will be for each run instead of cells per run
			# # instead of running make noise model, this skips that and creates the proper noise modeling file for you
			# # noise_model_1.mat
			# # for testing: matlab -r 'try myfunction(argument1,argument2); catch; end; quit'
			# echo "Matlab is done... for this sub"
			echo "$mrn_file complete"
		else
			echo "WARNING: No distortion corrected functional images exist for ${subid} run ${runame}... nuisance covariates not made" >> ${err_log_dir}/mrn_log_${subid}
		fi
	done
done

echo "All done. Check your run logs to make sure nothing is missing."
