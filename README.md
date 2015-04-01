
## Introduction

This repository is a package containing a set of plugins for the
[CBRAIN](https://github.com/aces/cbrain) platform.

## Contents of this package

This package provides some tasks and models supporting
parts of the [FreeSurfer](http://freesurfer.net/) suite.

#### 1. Userfile models

| Name                         | Description                                                                                     |
|------------------------------|-------------------------------------------------------------------------------------------------|
| ReconAllCrossSectionalOutput | Model for recon-all cross sectional output, result of the first step in longitudinal studies    |
| ReconAllBaseOutput           | Model for recon-all unbiased base output, result of the second step in longitudinal studies     |
| ReconAllLongiOutput          | Model for recon-all longitudinal output, result of the third step in longitudinal studies       |
| ReconAllOutput               | Model for recon-all collection (not directly used). All the ReconAll*Output inherits this model |

#### 2. CbrainTasks

| Name          | Description                                                                                    |
|---------------|------------------------------------------------------------------------------------------------|
| ReconAll      | To run [recon-all](https://surfer.nmr.mgh.harvard.edu/fswiki/recon-all)                        |
| ReconAllLongi | To run [Longitudinal Stream](https://surfer.nmr.mgh.harvard.edu/fswiki/LongitudinalProcessing) |

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
  `cbrain-plugins-freesurfer` with the content of this repository:

```bash
git clone git@github.com:aces/cbrain-plugins-freesurfer.git
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
git clone git@github.com:aces/cbrain-plugins-freesurfer.git
```
  * Run the following rake task (which is not the same as for
  the BrainPortal side):

``` bash
rake cbrain:plugins:install:plugins
```

  * Restart your execution server (with the interface, click stop, then start).

