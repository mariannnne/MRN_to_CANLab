#!/bin/bash

# This script will pull your data from the MRN auto processing pipeline and put it into the appropriate
# file structure for analysis with canlab tools.
# You can run this from anywhere, just make sure you have permissions: chmod 775 ./mrn_to_canlab.sh
# You need to give it your study-specific wildcards for folder names.
# Edit below 	MRNSTUDYID 	for how to find your study in the MRN directory
#							this will be for the name of your study folder under twager/
#				CANSTUDYID 	for the name of your study in the CANLab directory
#				FUNC 		for the wildcard to pull your functional runs. NOTE: Avoid SBrefs!!
#				STRUCT 		for the wildcard to pull your structural data
#				TRIM 		how many scans to discard using disdaqs
#							Note: you likely do not need to do this / NOT YET IMPLEMENTED
# This script will out put an error log for missing files and directories. Find it in the 
# Canlab directory Imaging/mrn_notes
# Edit and save these MATLAB scripts in your CANLab Imaging directory under /Code/
#	mrn_qual_check.m
#	mrn_make_noise_model.m
# This script runs spike detection on the distortion corrected functional scans.
# This script includes (and therefore replaces) make_noise_model.m 
# This script also creates a 3Dprint folder with your subjects ready to be printed cortex
# This script sould run disdaqs for as specified number of images
#
# Marianne 2015

# STUDY-SPECIFIC VARIABLES:
MRNSTUDYID="icap"
CANSTUDYID="ICAPS"
FUNC="*APS*r" # DOESNT HAVE SBref
STRUCT="t1w" #what if there are more than one t1's -- take all
# TRIM=0 #Not sure if we can implement disdaqs without lots of modification, we would have to rerun the smoothing and modify disdaqs to run on nii (or convert back to dicom)

###########################################################
##### YOU SHOULD NOT NEED TO EDIT ANYTHING BELOW THIS #####
###########################################################

# add freesurfer module
$ module add freesurfer/5.3.0

# allow globbing
shopt -s extglob

# set up data directories
basedir="/data/auto_analysis/human/twager/${MRNSTUDYID}*/AUTO_ANALYSIS/triotim" #mrn
newdir="/work/ics/data/projects/wagerlab/labdata/data/${CANSTUDYID}/Imaging" #canlab format
mkdir -p ${newdir} #if the canlad directory doesn't exist, make it
mrnsubjdir="/M*/Study*" #more indexing of file dirs in mrn
err_log_dir="/work/ics/data/projects/wagerlab/labdata/data/${CANSTUDYID}/Imaging/mrn_notes"
mkdir ${err_log_dir}

#get preprocessed structural, move to appropriate folder
for mrn_file in ${basedir}/M*; do
	cd $mrn_file
	subid=${PWD##*/}  #goes by ursi number

	spgr="./S*/${STRUCT}*"
	fs="./S*/analysis/fs*"
	vbm="./S*/analysis/vbm"
	func="./S*/${FUNC}*"
	3d="./S*/analysis/fs*mprage/M*/surf"

	echo "MRN to CANLab transfer on Blanca log... by Marianne 2015" >  ${err_log_dir}/mrn_log_${subid}
	
	# copy preprocessed structural
	if [ -d $spgr ]; then
		cd $spgr
		echo "copying $mrn_file structural data..."
		mkdir -p ${newdir}/${subid}/Structural/SPGR #make canlab dir
		rsync -auR . ${newdir}/${subid}/Structural/SPGR #copy struc over
	else 
		echo "WARNING: No structural data for subj ${subid} !" >>  ${err_log_dir}/mrn_log_${subid}
	fi

	# copy Freesurfer analysis
	if [ -d $fs ]; then
		cd $fs
		echo "copying $mrn_file FreeSurfer data..."
		mkdir -p ${newdir}/${subid}/Structural/FreeSurf #make canlab dir
		rsync -auR . ${newdir}/${subid}/Structural/FreeSurf #copy struc over
	else 
		echo "WARNING: No FreeSurfer data for subj ${subid} !" >>  ${err_log_dir}/mrn_log_${subid}
	fi

	# create 3D printable cortex .stl file for subject
	if [ -d $3d ]; then
		cd $3d
		echo "converting cortex to 3D printable stl file for $mrn_file ..."
		mris_convert lh.pial lh.pial.stl
		mris_convert rh.pial rh.pial.stl
		echo "copying 3D printable stl file for $mrn_file ..."
		mkdir -p ${newdir}/${subid}/Structural/3dPrint #make canlab dir
		rsync -auR ./*.stl ${newdir}/${subid}/Structural/3dPrint #copy stl
	else 
		echo "WARNING: No FreeSurfer data for subj ${subid} ! Cannot make 3D printable file." >>  ${err_log_dir}/mrn_log_${subid}
	fi

	# copy VBM analysis
	if [ -d $vbm ]; then
		cd $vbm
		echo "copying $mrn_file VBM data..."
		mkdir -p ${newdir}/${subid}/Structural/VBM #make canlab dir
		rsync -auR . ${newdir}/${subid}/Structural/VBM #copy struc over
	else 
		echo "WARNING: No VBM data for subj ${subid} !" >> ${err_log_dir}/mrn_log_${subid}
		#write warning to text file save in canlab dir
	fi

	cd $mrn_file

	# copy functional: preprocessed and raw
	i=0

	for funcfile in ${basedir}/M*/S*/$FUNC[0-9][0-9]['_'?][!'SBRef']*; do
		i=i+1
		cd $funcfile
		runame="r${i}${FUNC}"
		mkdir -p ${newdir}/${subid}/Functional/Preprocessed/${runame}
		mkdir -p ${newdir}/${subid}/Functional/Raw/${runame}

		# take all files in func except the raw
		echo "copying $mrn_file func preprocessed data run $runame..."
		rsync -auR . ${newdir}/${subid}/Functional/Preprocessed/${runame}

		# move raw to raw folder
		mv ${newdir}/${subid}/Functional/Preprocessed/${runame}/${funcfile}*.nii* ${newdir}/${subid}/Functional/Raw/${runame}

		### TODO: For Raw folder, create the mean functional images

		if [ -f $funcfile/swd* ]; then
			echo "Subj #{subid} preprocessed functionals exist for run ${runame}"
		else
			echo "WARNING: Functional Preprocessing incomplete for ${subid} run ${runame} !" >> ${err_log_dir}/mrn_log_${subid}
		
		# perform data quality checks and create the nuisance covariates
		# using Tor's scn_session_spike_id
		# run in matlab
		echo "attempting scn_session_spike_id on distortion corrected data in matlab..."
		cd ${newdir}/${subid}/Functional/Preprocessed/${runame}
		save_dir="${newdir}/${subid}/Functional/Preprocessed/${runame}"
		sess_images="./d*.nii" # TAKE THIS FROM CANLAB TO AVOID PERMISSIONS ISSUES of gunzipping

		echo "finding the motion regressors..."
		motion_file="./sepi_vr_motion.1D"
		if [ -f $motion_file ]; then
			echo "got motion."
		else
			echo "Missing afni motion regressors for ${subid} run ${runame}!" >> ${err_log_dir}/mrn_log_${subid}
		fi

		if [ -f $sess_images ]; then
			echo "distortion corrected images exist... running spike id..."
			if [ ${sess_images:(-2)} = "gz" ]; then #of the last 2 char of the distor image are gz, gunzip em
				echo "gunzipping the distortion corrected images..."
				gunzip $sess_images
				sess_images="./d*.nii"  #update sess_images with the right string
			fi

			echo "We're about to go into MATLAB, hold onto your butts!"
			# the point is to make this Nuisance_covariates_R.mat which contains R{1} and R{2} where
			# R{1} spikeids R{2} 24 motion regs
			# may have to addpath to the repos addpath(genpath('/work/ics/data/projects/wagerlab/Repository'))
			matlab -nodisplay -nojvm -r "mrn_make_nuisance($sess_images,$motion_file,$save_dir); exit;"
			# must store in noise_model_1.mat
			# IT WILL OUTPUT Nuisance_covariates.mat but this will be for each run instead of cells per run
			# instead of running make noise model, this skips that and creates the proper noise modeling file for you
			# noise_model_1.mat
			#matlab -r 'try myfunction(argument1,argument2); catch; end; quit'
			echo "Matlab is done... for this sub!"
		else
			echo "WARNING: No distortion corrected functional images exist for ${subid} run ${runame}... nuisance covariates not made !" >> ${err_log_dir}/mrn_log_${subid}

		fi

	done

done

echo "All done! Check your run logs to make sure nothing is missing!"

### extra stuff
## from kathy
# You can pass a variable to matlab like this from the bash shell:
#     str=abc
#     num=123
#     matlab -r "myfunction('$str', $num);quit"
#
# don't pull the SBrefs
#ls ${FUNC}* | sed -e 
#ls !(SBref) | grep "${FUNC}*"
#ls !(*SBRef*) | grep $FUNC
