#!/usr/bin/env python3

# Based on code provided by Alex Palex Pastor Bernier
#   converted in Python from bash script by Natacha Beck nbeck@mcin.ca

from datetime import datetime
from pathlib import Path
import argparse
import subprocess
import sys
import glob
import os
import code


def print_log(message):
    time_stamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"{time_stamp}: {message}", flush=True)

def run_command(cmd, description,):
    print_log(f"Running command: {' '.join(cmd)}")
    try:
        result = subprocess.run(cmd, shell=False, check=True)
        print_log(f"{description} completed successfully")
    except subprocess.CalledProcessError as error:
        print_log(f"Error running {description}: {error}, code: {error.returncode}")
        print_log(f"Command: {cmd}")
        sys.exit(error.returncode)

def designer_file_extraction(args):

    if args.designer_file_pattern is None:
        print_log("Error: --designer_file_pattern is required.")
        sys.exit(2)

    phases, magnitudes, rpe_pair = [], [], []
    # Iterate over BIDS structure to find magnitude and phase files
    bids_absolute_path = os.path.abspath(args.bids_dir)
    for bids_subject_dir in os.listdir(bids_absolute_path):

        if bids_subject_dir != args.designer_bids_subject:
            continue

        bids_subject_absolute_path = os.path.join(bids_absolute_path, bids_subject_dir)

        if args.designer_ses_pattern:
            dirs = glob.glob(os.path.join(bids_subject_absolute_path, f"ses-{args.designer_ses_pattern}*"))
        else:
            dirs = [bids_subject_dir]

        # print list of sub-directories
        file_patterns = [string.strip() for string in args.designer_file_pattern.split(',')]
        for sub_dir in dirs:
            dwi_dir                   = os.path.join(sub_dir, "dwi")
            rpe_pair_relative_pattern = os.path.join(dwi_dir, f"*b0_dir-PA_dwi.nii*")
            for rpe_file in glob.glob(rpe_pair_relative_pattern):
                rpe_absolute_path = os.path.abspath(rpe_file)
                if not os.path.exists(rpe_absolute_path):
                    print_log(f"Error: RPE file {rpe_absolute_path} does not exist.")
                    sys.exit(2)
                rpe_pair.append(rpe_absolute_path)

            if os.path.isdir(dwi_dir):
                for file_pattern in file_patterns:
                    dwi_relative_pattern = os.path.join(dwi_dir, f"*{file_pattern}*_part-phase_dwi.nii*")
                    phase_files          = glob.glob(dwi_relative_pattern)
                    print_log(f"phase_files: {phase_files}")
                    magnitude_files      = []

                    for phase_file in phase_files:
                        # Search for corresponding magnitude file
                        extrapolated_magnitude_file = phase_file.replace("_part-phase", "")
                        if os.path.exists(extrapolated_magnitude_file):
                            magnitude_files.append(extrapolated_magnitude_file)
                            print_log(f"Found pair: {extrapolated_magnitude_file} <-> {phase_file}")
                        else:
                            print_log(f"Warning: Extrapolated magnitude file not found for phase file {phase_file}")
                            sys.exit(2)

                    # Remove BIDS directory prefix to get relative path
                    for phase_file in phase_files:
                        absolute_path = os.path.abspath(phase_file)
                        if not os.path.exists(absolute_path):
                            print_log(f"Error: Phase file {absolute_path} does not exist.")
                            sys.exit(2)
                        phases.append(os.path.abspath(phase_file))
                    for magnitude_file in magnitude_files:
                        absolute_path = os.path.abspath(magnitude_file)
                        if not os.path.exists(absolute_path):
                            print_log(f"Error: Magnitude file {absolute_path} does not exist.")
                            sys.exit(2)
                        magnitudes.append(os.path.abspath(magnitude_file))

    return magnitudes, phases, rpe_pair

def main():
    version = "1.0.0"
    print_log(f"Starting designer, mrconvert, and tmi wrapper script")
    print_log(f"By Natacha Beck nbeck@mcin.ca, based on code from Alex Palex Pastor Bernier")
    print_log(f"Version: {version}")

    parser = argparse.ArgumentParser(description='This is a wrapper to run designer, mrconvert, and tmi commands')

    # Bids directory input
    parser.add_argument('bids_dir',                                 type=str, help='BIDS directory input')
    parser.add_argument('output',                                   type=str, help='Designer output directory')

    # Inputs/Outputs parameters
    parser.add_argument('--designer_bids_subject',  required=True,  type=str, help='Designer: BIDS subject name')
    parser.add_argument('--designer_ses_pattern',                   type=str, help='Designer: session pattern')
    parser.add_argument('--designer_file_pattern',  required=True,  type=str, help='Designer: file pattern')

    # Designer parameters
    parser.add_argument('--designer_eddy',          action='store_true', help='Designer: eddy flag')
    parser.add_argument('--designer_denoise',       action='store_true', help='Designer: denoise flag')
    parser.add_argument('--designer_shrinkage',     type=str,            help='Designer: specify shrinkage type for MPPCA')
    parser.add_argument('--designer_algorithm',     type=str,            help='Designer: algorithm string')
    parser.add_argument('--designer_degibbs',       action='store_true', help='Designer: degibbs flag')
    parser.add_argument('--designer_pf',            type=float,          help='Designer: pf number')
    parser.add_argument('--designer_pe_dir',        type=str,            help='Designer: pe_dir string')
    parser.add_argument('--designer_b1correct',     action='store_true', help='Designer: b1correct flag')
    parser.add_argument('--designer_normalize',     action='store_true', help='Designer: normalize flag')
    parser.add_argument('--designer_scratch',       type=str,            help='Designer: scratch string')
    parser.add_argument('--designer_nocleanup',     action='store_true', help='Designer: nocleanup flag')

    # mrconvert parameters
    parser.add_argument('--mrconvert_fslgrad',      action='store_true', help='mrconvert: fslgrad flag')

    # tmi parameters
    parser.add_argument('--tmi_DKI',                action='store_true', help='tmi: DKI flag')
    parser.add_argument('--tmi_DTI',                action='store_true', help='tmi: DTI flag')
    parser.add_argument('--tmi_nocleanup',          action='store_true', help='tmi: nocleanup flag')

    args = parser.parse_args()

    cwd  = os.getcwd()


    # designer - handle extraction of magnitude and phase files
    magnitudes, phases, rpe_pair = designer_file_extraction(args)

    # Create output directory if it doesn't exist
    if not os.path.exists(args.output):
        os.makedirs(args.output)

    # Get absolute path of output directory
    output_absolute_path = os.path.abspath(args.output)

    # designer command construction
    designer_cmd = ["designer"]
    # Add magnitude files to command line all magnitude files should be separated by a ','
    # if magnitudes is empty, exit with error
    if magnitudes == []:
        print_log("Error: No magnitude files found based on the provided patterns.")
        sys.exit(2)

    # Add optional parameters
    if args.designer_denoise:
        designer_cmd.append("-denoise")

    if args.designer_shrinkage is not None:
        designer_cmd.append("-shrinkage")
        designer_cmd.append(args.designer_shrinkage)

    # Add phase files if present
    if phases != []:
        designer_cmd.append("-phase")
        designer_cmd.append(",".join(phases))

    if args.designer_algorithm is not None:
        designer_cmd.append("-algorithm")
        designer_cmd.append(args.designer_algorithm)

    if args.designer_degibbs:
        designer_cmd.append("-degibbs")

    if args.designer_pf is not None:
        designer_cmd.append("-pf")
        designer_cmd.append(str(args.designer_pf))

    if args.designer_pe_dir is not None:
        designer_cmd.append("-pe_dir")
        designer_cmd.append(args.designer_pe_dir)

    if args.designer_eddy:
        designer_cmd.append("-eddy")

    if rpe_pair != []:
        designer_cmd.append("-rpe_pair")
        designer_cmd.append(",".join(rpe_pair))

    if args.designer_normalize:
        designer_cmd.append("-normalize")

    if args.designer_b1correct:
        designer_cmd.append("-b1correct")

    if args.designer_scratch:
        designer_cmd.append("-scratch")

        designer_cmd.append(args.designer_scratch)

    if args.designer_nocleanup:
        designer_cmd.append("-nocleanup")

    # Input output
    designer_cmd.append(",".join(magnitudes))

    designer_cmd.append(f"{output_absolute_path}/DWI_designer.nii")

    # Create .mtrix.conf file
    mtrix_conf_path = Path.home() / ".mtrix.conf"
    if not os.path.exists(mtrix_conf_path):
        with open(mtrix_conf_path, 'w') as conf_file:
            conf_file.write("BZeroThreshold: 61\n")

    run_command(designer_cmd, "designer")

    # mrconvert
    mrconvert_cmd = ["mrconvert"]
    if args.mrconvert_fslgrad:
        mrconvert_cmd.append("-fslgrad")

    mrconvert_cmd.append(f"{output_absolute_path}/DWI_designer.bvec")
    mrconvert_cmd.append(f"{output_absolute_path}/DWI_designer.bval")
    mrconvert_cmd.append(f"{output_absolute_path}/DWI_designer.nii")
    mrconvert_cmd.append(f"{output_absolute_path}/DWI_designer.mif")

    run_command(mrconvert_cmd, "mrconvert")

    # tmi
    tmi_cmd = ["tmi"]
    if args.tmi_DKI:
        tmi_cmd.append("-DKI")
    if args.tmi_DTI:
        tmi_cmd.append("-DTI")
    tmi_cmd.append(output_absolute_path)
    if args.tmi_nocleanup:
        tmi_cmd.append("-nocleanup")

    tmi_cmd.append(f"{output_absolute_path}/DWI_designer.mif")
    tmi_cmd.append(f"{output_absolute_path}/tmi_output_phase")

    run_command(tmi_cmd, "tmi")

    print_log("Designer, mrconvert, and tmi commands completed successfully!")

if __name__ == "__main__":
    main()


