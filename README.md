
## Introduction

This repository is a package containing a set of plugins for the
[CBRAIN](https://github.com/aces/cbrain) platform.

## Contents of this package

This package provides some tasks and models supporting
parts of the FMRIB Software Library ([FSL](http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/)).

#### 1. Userfile models

| Name             | Description               |
|------------------|---------------------------|
| FslDesignFile    | Model for FSL design file |
| FslFastOutput    | Model for FAST output     |
| FslFirstOutput   | Model for FIRST output    |
| FslMelodicOutput | Model for MELODIC output  |

#### 2. CbrainTasks

| Name          | Description                                                                          |
|---------------|--------------------------------------------------------------------------------------|
| FslBedpostx   | To run [BEDPOSTX](http://fsl.fmrib.ox.ac.uk/fsl/fsl4.0/fdt/fdt_bedpostx.html)        |
| FslBet        | To run [BET](http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/BET)                              |
| FslFast       | To run [FAST]( http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FAST)                           |
| FslFeat       | To run [FEAT](http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FEAT)                            |
| FslFirst      | To run [FIRST](http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FIRST)                          |
| FslFlirt      | To run [FLIRT](http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FLIRT)                          |
| FslMelodic    | To run [MELODIC](http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/MELODIC)                      |
| FslProbtrackx | To run [PROBTRACKX](http://fsl.fmrib.ox.ac.uk/fsl/fsl-4.1.9/fdt/fdt_probtrackx.html) |

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
  `cbrain-plugins-fsl` with the content of this repository:

```bash
git clone git@github.com:aces/cbrain-plugins-fsl.git
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
git clone git@github.com:aces/cbrain-plugins-fsl.git
```
  * Run the following rake task (which is not the same as for
  the BrainPortal side):

``` bash
rake cbrain:plugins:install:plugins
```

  * Restart your execution server (with the interface, click stop, then start).

