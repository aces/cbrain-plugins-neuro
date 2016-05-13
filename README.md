
## Introduction

This repository is a package containing a set of plugins for the
[CBRAIN](https://github.com/aces/cbrain) platform. This repository
supersedes the content of three other packages: `cbrain-plugins-freesurfer`,
`cbrain-plugins-fsl` and `cbrain-plugins-mni`.



## Contents of this package

This package provides some tasks and models supporting:

* parts of the [FreeSurfer](http://freesurfer.net/) suite.
* parts of the FMRIB Software Library ([FSL](http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/)).
* parts of the [MNI tools](http://www.bic.mni.mcgill.ca/ServicesSoftware/HomePage).



#### 1. Userfile models

For Freesurfer tools:

| Name                         | Description                                                                                     |
|------------------------------|-------------------------------------------------------------------------------------------------|
| ReconAllCrossSectionalOutput | Model for recon-all cross sectional output, result of the first step in longitudinal studies    |
| ReconAllBaseOutput           | Model for recon-all unbiased base output, result of the second step in longitudinal studies     |
| ReconAllLongiOutput          | Model for recon-all longitudinal output, result of the third step in longitudinal studies       |
| ReconAllOutput               | Model for recon-all collection (not directly used). All the ReconAll*Output inherits this model |
| MghFile                      | Model for MGH structural files                                                                  |

For FSL tools:

| Name                         | Description                                                                                     |
|------------------------------|-------------------------------------------------------------------------------------------------|
| FslDesignFile                | Model for FSL design file                                                                       |
| FslDesignCollection          | Model for FSL collection with matrix for FSL randomise                                          |
| FslFastOutput                | Model for FAST output                                                                           |
| FslFirstOutput               | Model for FIRST output                                                                          |
| FslMelodicOutput             | Model for MELODIC output                                                                        |
| NiftiFile                    | Model for NIfTI medical data files                                                              |
| StructuralNiftiFile          | Model for structural NIfTI medical data files                                                   |
| FunctionalNiftiFile          | Model for functional NIfTI medical data files                                                   |

For MNI and DICOM tools:

| Name                         | Description                                                                                     |
|------------------------------|-------------------------------------------------------------------------------------------------|
| CivetOutput                  | Model for [CIVET outputs](http://www.bic.mni.mcgill.ca/ServicesSoftware/OutputsOfCIVET)         |
| CivetStudy                   | Model for several outputs of CIVET                                                              |
| DicomCollection              | Model for a collection of DICOM files                                                           |
| DicomFile                    | Model for a DICOM file                                                                            |
| LorisSubject                 | Model for LORIS subject files                                                                   |
| Minc1File                    | Model for MINC files in MINC1 format                                                            |
| Minc2File                    | Model for MINC files in MINC2 format                                                            |
| MincCollection               | Model for a collection of MINC files                                                            |
| MincFile                     | Model for MINC files; superclass of MINC1 and MINC2                                             |


#### 2. CbrainTasks

For Freesurfer tools:

| Name          | Description                                                                                    |
|---------------|------------------------------------------------------------------------------------------------|
| ReconAll      | To run [recon-all](https://surfer.nmr.mgh.harvard.edu/fswiki/recon-all)                        |
| ReconAllLongi | To run [Longitudinal Stream](https://surfer.nmr.mgh.harvard.edu/fswiki/LongitudinalProcessing) |

For FSL tools:

| Name          | Description                                                                                    |
|---------------|------------------------------------------------------------------------------------------------|
| FslBedpostx   | To run [BEDPOSTX](http://fsl.fmrib.ox.ac.uk/fsl/fsl4.0/fdt/fdt_bedpostx.html)                  |
| FslBet        | To run [BET](http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/BET)                                        |
| FslFast       | To run [FAST]( http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FAST)                                     |
| FslFeat       | To run [FEAT](http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FEAT)                                      |
| FslFirst      | To run [FIRST](http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FIRST)                                    |
| FslFlirt      | To run [FLIRT](http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FLIRT)                                    |
| FslMelodic    | To run [MELODIC](http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/MELODIC)                                |
| FslProbtrackx | To run [PROBTRACKX](http://fsl.fmrib.ox.ac.uk/fsl/fsl-4.1.9/fdt/fdt_probtrackx.html)           |
| FslRandomise  | To run [RANDOMISE](http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/Randomise)                            |

For MNI and DICOM tools:

| Name          | Description                                                                                    |
|---------------|------------------------------------------------------------------------------------------------|
| Civet         | To run CIVET pipeline                                                                          |
| CivetCombiner | Combines several CivetOutputs into a single CivetStudy                                         |
| CivetQc       | To run CIVET QC pipeline on a CivetStudy                                                       |
| Dcm2mnc       | To run dcm2mnc, in order to convert DICOM to MINC                                              |
| Dcm2nii       | To run dcm2nii, in order to convert DICOM to NIfTI                                             |
| MincConvert   | To run minc_convert, in order to convert MINC1 to MINC2 or MINC2 to MINC1                      |
| Mnc2nii       | To run mnc2nii, in order to convert MINC to NIfTI                                              |
| Nii2mnc       | To run nii2mnc, in order to convert NIfTI to MINC                                              |
| NuCorrect     | To run nu_correct                                                                              |
| MincBet       | To run brain extraction tool wrapper                                                           |


## How to install this package

An existing CBRAIN installation is assumed to be operational before
proceeding.

This package must be installed once on the BrainPortal side of a
CBRAIN installation, and once more on each Bourreau side.

#### 1. Installation on the BrainPortal side:

  * Go to the `cbrain_plugins` directory under BrainPortal:

```bash
cd /path/to/BrainPortal/cbrain_plugins
```

  * Clone this repository. This will create a subdirectory called
  `cbrain-plugins-neuro` with the content of this repository:

```bash
git clone git@github.com:aces/cbrain-plugins-neuro.git
```

  * Run the following rake task:

```bash
rake cbrain:plugins:install:all
```

  * Restart all the instances of your BrainPortal Rails application.

#### 2. Installation on the Bourreau side:

**Note**: If you are using the Bourreau that is installed just
besides your BrainPortal application, you do not need to make
any other installation steps, as they share the content of
the directory `cbrain_plugins` through a symbolic link; you
only need to *restart your Bourreau server*.

  * Go to the `cbrain_plugins` directory under BrainPortal
  (yes, *BrainPortal*, because that's where files are installed; on
  the Bourreau side `cbrain_plugins` is a symbolic link):

```bash
cd /path/to/BrainPortal/cbrain_plugins
```

  * Clone this repository:

```bash
git clone git@github.com:aces/cbrain-plugins-neuro.git
```
  * Run the following rake task (which is not the same as for
  the BrainPortal side):

```bash
rake cbrain:plugins:install:plugins
```

  * If you want FSL tools to be parallelized in CBRAIN (limited to FSL Melodic for now), replace the fsl_sub script in your FSL installation with the one in the plugin:

```bash
cp cbrain-plugins-neuro/bin/fsl_sub ${FSLDIR}/bin
```

  * Restart your execution server (with the interface, click stop, then start).

#### 3. In case of problems during installation

  * Consider running the rake task that cleans all previous installations
    of tools and userfiles, then trying again the rake tasks mentioned above.

```bash
rake cbrain:plugins:clean:all
```
