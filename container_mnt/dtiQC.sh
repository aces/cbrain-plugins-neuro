#!/bin/bash


while getopts ":hq:i:o:g:" option; do
   case $option in
      h) # display Help
      echo "Usage: wrap_defaceV2.sh

### DTI_QC wraper pipeline ###########
Based on Alex_PastorBernier_25 - McGill MNI-BIC adaptation for CBRAIN by Natacha Beck

### Syntax:
./wrap_dtiQC.sh [-i|-o|-g]

Mandatory arguments
1) -i Subject ID (sub-XXXXX)
2) -o Output directory for QA -> DesignerV2 tmi folder with structure: tmi_output_phase
########################################"

      exit 0
      ;;
      i) # input
      SID="${OPTARG}"
      ;;
      o) # output
      OUT=${OPTARG}
      ;;
      :)                                    # If expected argument omitted:
        echo "Error: -${OPTARG} requires an argument."
        exit_abnormal                       # Exit abnormally.
      ;;
      *)                                    # If unknown (any other) option:
        exit_abnormal                       # Exit abnormally.
      ;;
   esac
done

echo "Processing subject" $SID "on" $OUT

# resize fa to mni res isometric
# run the command
cmd="resample_image --reference /cerebra/BrainExtractionBrain_mni_icbm152_t1_tal_nlin_asym_09c.nii.gz --nosmooth ${OUT}/fa_dti.nii ${OUT}/fa_dti.nii.gz"
echo $cmd

#register directly fa to mni space = same space as label atlas
#extract b0 from trace and bet
fslroi ${OUT}/trace_allshells.nii ${OUT}/b0.nii.gz 0 1
bet ${OUT}/b0.nii.gz ${OUT}/b0_BET.nii.gz -f 0.2 -g 0.3
#register b0 to MNI space
antsRegistrationSyN.sh -d 3 -f /cerebra/BrainExtractionBrain_mni_icbm152_t1_tal_nlin_asym_09c.nii.gz -m ${OUT}/b0_BET.nii.gz -o ${OUT}/b0_MNI.nii.gz
# resize fa to mni res isometric
resample_image --reference /cerebra/BrainExtractionBrain_mni_icbm152_t1_tal_nlin_asym_09c.nii.gz --nosmooth ${OUT}/fa_dti.nii /mnt_OUT/fa_dti_RSZ.nii.gz
##apply transformation to resized FA
antsApplyTransforms --verbose -d 3 -i ${OUT}/fa_dti_RSZ.nii.gz -r /cerebra/BrainExtractionBrain_mni_icbm152_t1_tal_nlin_asym_09c.nii.gz -o ${OUT}/fa_MNI.nii.gz -t ${OUT}/b0_MNI0GenericAffine.mat -n 'GenericLabel'

#copy files to output
cp /cerebra/CerebrAS_plus2RSZ.nii.gz ${OUT}/
cp /cerebra/Cerebra_Labels_Hem.csv ${OUT}/


#!#####################################################

FOUT=${OUT}/${SID}_Atlas_proj_FA_DESIGNER_MPPCA_PHASE_JESP_Thr.csv
echo 'DM',$(seq -f "atlas_roi%1g.nii.gz" -s ", " 1 103 | tr -s '[:blank:]' | paste -s -d,)>  ${FOUT}

thr=0.9
for file in ${OUT}/fa_MNIWarped.nii.gz; do

  #returns integer total voxels and total vol in mm3, we are getting voxel ratio
	vox_abovethr=$(fslstats -K /cerebra/CerebrAS_plus2RSZ.nii.gz ${file} -l ${thr} -V)

	vox_all=$(fslstats -K ${OUT}/CerebrAS_plus2RSZ.nii.gz ${file} -V)


	# convert to array take 1st arg voxels
  VOXALL=( $(echo "$vox_all" | cut -d ' ' -f 1) )
  VOXABV=( $(echo "$vox_abovethr" | cut -d ' ' -f 1) )

  # below give error - div by zero
  for i in "${!VOXABV[@]}"; do

    if [ ${VOXALL[$i]} == "0" ]; then # volume on this tag is zero
    result="NA"
    else
    result=$(echo "scale=6; ${VOXABV[$i]} / ${VOXALL[$i]}" | bc)
    fi
    results+=("$result")

  done

  echo "Voxel_noise-ratio",$(echo ${results[@]} | tr -s '[:blank:]' ',')

  minmax=$(fslstats -K ${OUT}/CerebrAS_plus2RSZ.nii.gz ${file} -R)
  max=$(echo "$minmax" | cut -d ' ' -f 2 |  tr -d '[:blank:]' | paste -s -d,)

  echo "max_noise",${max}

  echo "non-zero_mean_noise",$(fslstats -K ${OUT}/CerebrAS_plus2RSZ.nii.gz ${file} -M | tr -s '[:blank:]' ',')
  echo "non-zero_std",$(fslstats -K ${OUT}/CerebrAS_plus2RSZ.nii.gz ${file} -S | tr -s '[:blank:]' ',')

done >> ${FOUT}

unset result results

## Now gonna add fields concerning threshold estimates in roi 103 (genu corpus callossum)
# open csv again 		}'

thr=$(sed -n '4p' ${FOUT} | awk -F',' '{print $104}') # YES MEAN NOISE IN CC 0.83
unset VOXALL VOXABV result results
for file in ${OUT}/fa_MNIWarped.nii.gz; do

  #returns integer total voxels and total vol in mm3, we are getting voxel ratio
	vox_abovethr=$(fslstats -K ${OUT}/CerebrAS_plus2RSZ.nii.gz ${file} -l ${thr} -V)
	vox_all=$(fslstats -K ${OUT}/CerebrAS_plus2RSZ.nii.gz ${file} -V)

	# convert to array take 1st arg voxels
  VOXALL=( $(echo "$vox_all" | cut -d ' ' -f 1) )
  VOXABV=( $(echo "$vox_abovethr" | cut -d ' ' -f 1) )

  for i in "${!VOXABV[@]}"; do

    if [ ${VOXALL[$i]} == "0" ]; then # volume on this tag is zero
    result="NA"
    else
    result=$(echo "scale=6; ${VOXABV[$i]} / ${VOXALL[$i]}" | bc)
    fi
    results+=("$result")
  done

  echo "Voxel_noise-ratio_refCC",$(echo ${results[@]} | tr -s '[:blank:]' ',')

  # convert to array take 1st arg voxels
  VOXALL=( $(echo "$vox_all" | cut -d ' ' -f 2) )
  VOXABV=( $(echo "$vox_abovethr" | cut -d ' ' -f 2) )

  minmax=$(fslstats -K ${OUT}/CerebrAS_plus2RSZ.nii.gz ${file} -R)
  max=$(echo "$minmax" | cut -d ' ' -f 2 |  tr -d '[:blank:]' | paste -s -d,)

  echo "max_noise_refCC",${max}

  echo "non-zero_mean_noise_refCC",$(fslstats -K ${OUT}/CerebrAS_plus2RSZ.nii.gz ${file} -M | tr -s '[:blank:]' ',')
  echo "non-zero_std_refCC",$(fslstats -K ${OUT}/CerebrAS_plus2RSZ.nii.gz ${file} -S | tr -s '[:blank:]' ',')

done >> ${FOUT}
