
## Introduction

This repository is a package containing a set of plugins for the
[CBRAIN](https://github.com/aces/cbrain) platform.

## Contents of this package

This package provides some tasks and models supporting
parts of the [MNI tools](http://www.bic.mni.mcgill.ca/ServicesSoftware/HomePage).

**NOTE**: Many of these MNI tools are not yet available publicly (CIVET for instance)
so installing this package is of little utility for most installations.

#### 1. Userfile models

| Name                | Description                                                                             |
|---------------------|-----------------------------------------------------------------------------------------|
| CivetOutput         | Model for [CIVET outputs](http://www.bic.mni.mcgill.ca/ServicesSoftware/OutputsOfCIVET) |
| CivetStudy          | Model for several outputs of CIVET                                                      |
| DicomCollection     | Model for a collection of DICOM files                                                   |
| DicomFile           | Model for DICOM file                                                                    |
| FunctionalNiftiFile | Model for functional NIfTI medical data files                                           |
| LorisSubject        | Model for LORIS subject files                                                           |
| MgzFile             | Model for MGZ structural files                                                          |
| Minc1File           | Model for MINC files in MINC1 format                                                    |
| Minc2File           | Model for MINC files in MINC2 format                                                    |
| MincCollection      | Model for a collection of MINC files                                                    |
| MincFile            | Model MINC files; superclass of MINC1 and MINC2                                         |
| NiftiFile           | Model for NIfTI medical data files                                                      |
| StructuralNiftiFile | Model for structural NIfTI medical data files                                           |

#### 2. CbrainTasks

| Name          | Description                                                                      |
|---------------|----------------------------------------------------------------------------------|
| Civet         | To run [CIVET](http://www.bic.mni.mcgill.ca/ServicesSoftware/CIVET) pipeline     |
| CivetCombiner | Combines several CivetOutputs into a single CivetStudy                           |
| CivetQc       | To run CIVET QC pipeline on a CivetStudy                                         |
| Dcm2mnc       | To run [dcm2mnc](http://www.bic.mni.mcgill.ca/~mferre/fmri/dcm2mnc_help.html)    |
| Dcm2nii       | To rum [dcm2nii](http://www.mccauslandcenter.sc.edu/mricro/mricron/dcm2nii.html) |
| MincConvert   | To run minc_convert, in order to convert MINC1 to MINC2 or MINC2 to MINC1        |
| Mnc2nii       | To run mnc2nii, in order to convert MINC to NIfTI                                |
| Nii2mnc       | To run nii2mnc, in order to convert NIfTI to MINC                                |
| NuCorrect     | To run [nu_correct](http://en.wikibooks.org/wiki/MINC/Tools/N3)                  |


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
  `cbrain-plugins-mni` with the content of this repository:

```bash
git clone git@github.com:aces/cbrain-plugins-mni.git
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
git clone git@github.com:aces/cbrain-plugins-mni.git
```
  * Run the following rake task (which is not the same as for
  the BrainPortal side):

``` bash
rake cbrain:plugins:install:plugins
```

  * Restart your execution server (with the interface, click stop, then start).

