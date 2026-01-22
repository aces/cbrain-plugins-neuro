#!/bin/bash

#SID="sub-MPN0000110"
#SES="ses-MPN1Scan1"
#ACQY=("desc-denoised_UNIT1" "T1w" "acq-aspire_desc-echoCombinedSensitivityCorrected_T2starw")
#ACQY=("acq-mtw_mt-on_MTR" "acq-mtw_mt-off_MTR" "acq-mtw_T1w" "angio" "FLAIR" "acq-05mm_UNIT1")
ACQY=()
MODALITY=("anat")


# while getopts ":hq:i:o:s:a:" option; do
#    case $option in
#       h) # display Help
#       echo "Usage: wrap_defaceV2.sh

# ### Defacing wraper pipeline ###########
# Alex_PastorBernier_25 - McGill MNI-BIC)

# ### Syntax:
# ./wrap_defaceV2.sh [-i|-s|-a|-h] bids_subject_folder output_folder

# Mandatory arguments
# 1) -i subject id
# 2) -s subject Session
# 3) -a Acquisition option parse the argument and populate the array using space delimiter ("i j k")
# subject folder in BIDS
# output directory for QA

# ########################################"

while [[ $# -gt 0 ]]; do
  case $1 in
    -h)
      echo "Usage: wrap_defaceV2.sh

### Defacing wraper pipeline ###########
Alex_PastorBernier_25 - McGill MNI-BIC)

### Syntax:
./wrap_defaceV2.sh [-i|-s|-m|-a|-h] bids_subject_folder output_folder

Mandatory arguments
1) -i subject id
2) -s subject Session
3) -m Modality option (e.g., anat, func)
4) -a Acquisition option parse the argument and populate the array using space delimiter ("i j k")
subject folder in BIDS
output directory for QA

########################################"
      exit 0
      ;;

    # For option -a, parse the argument and populate the array
    # Using space as a delimiter (requires quoted argument)
    -a)
      IFS=', ' read -r -a ACQY <<< "$2"
      shift 2
      ;;
    # session
    -s)
      SES="$2"
      shift 2
      ;;
    # modality
    -m)
      IFS=', ' read -r -a MODALITY <<< "$2"
      shift 2
      ;;
    # input
    -i)
      SID="${2}"
      shift 2
      ;;
    *)
      break
      ;;
  esac
done

if test $# -ne 2 ; then
  echo "Error: the script needs exactly two mandatory arguments. Run with -h for help"
  exit 2
fi

IN="${1}"
OUT="${2}"

echo "Processing subject" $SID
echo "Session:" $SES
echo "Modality:" "${MODALITY[@]}"
echo "Input BIDS folder:" $IN
echo "Output folder for QA:" $OUT
echo "Acquisitions to process:" "${ACQY[@]}"

## Loop through each element in ACQ array
for MOD in "${MODALITY[@]}"; do
  echo "Processing Modality: $MOD"
  for ACQ in "${ACQY[@]}"; do
    echo "Processing: $ACQ"
    sid_ses_acq="${SID}_ses-${SES}_${ACQ}"
    OUT2=${OUT}/Anonymized_${sid_ses_acq}
    input_file=${IN}/${SID}/ses-${SES}/${MOD}/${sid_ses_acq}.nii.gz
    deface_output=${sid_ses_acq}_defaced.nii.gz
    qc_dir=${OUT2}/QC

    mideface_command="mideface --i ${input_file} --o ${deface_output} --odir ${qc_dir} --back-of-head"
    echo "Running command: $mideface_command"
    eval $mideface_command || { echo "Error: mideface command failed for ${sid_ses_acq}" >&2; exit 2; }
    # move defaced file to output directory
    mv ${deface_output} ${OUT2}/
  done
done

