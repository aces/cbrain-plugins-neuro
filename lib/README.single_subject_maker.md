This short document demonstrates with an example how
the new BoutiquesBidsSingleSubjectMaker module makes
everything easier.

The example chosen is from the Micapipe 0.2.3 descriptor.
The explanations will consists of selected snippets of
the descriptor. THere are two sections in this document
clearly identified with the words "OLD" and "NEW".

# OLD MECHANISM

0. See the full JSON of the old descriptor at:

https://github.com/aces/cbrain-plugins-neuro/blob/36ca8c588ba15a6cad557933a421814c4408a21f/boutiques_descriptors/micapipe_0_2_3.json

1. Old module integration custom block:

Notice we only provide the ID of the main file, which was
called "subject_dir" even though Micapipe internally works on a BidsDataset.

```json
  "BoutiquesBidsSingleSubjectMaker": "subject_dir"
```

2. Old command-line. Some observations:

a. we added bash commands to parse the BIDS subject filename.
b. we provide that to the parameter for the participant name (with -sub).
c. notice we hardcoded the flags "-bids" and "-sub".

```json
  "command-line": "SUBJECT_DIR=[SUBJECT_DIR]; SUBJECT=$(basename $SUBJECT_DIR/sub-*); SUBJECT_ID=${SUBJECT#*-};/neurodocker/startup.sh micapipe -bids $SUBJECT_DIR -sub $SUBJECT_ID [OUTPUT_DIR] [SES]..."
```

3. Old definition of the main input:

Again, notice that we don't even have "-bids" in there.

```json
  {
    "id": "subject_dir",
    "description": "Subject folder for BIDS (folders name should be sub-XXXXX).",
    "name": "BIDS Subject Folder",
    "optional": false,
    "type": "File",
    "value-key": "[SUBJECT_DIR]"
  }
```

4. The old JSON descriptor doesn't even have an input for the actual subject ID, because we were doing the work in the command-line.

# NEW MECHANISM

0. See the full JSON of the new descriptor at:

  https://github.com/prioux/cbrain-plugins-neuro/blob/48ec9811edeadd119f00a80ec13f009a8180ba16/boutiques_descriptors/micapipe_0_2_3.json

1. New module integration custom block:

We now should specify the main input (the one that can
be either a BidsDataset or a BidsSubject) with "dataset_input_id".
We can also provide the ID of any other input were user
are expected to enter one (or several) subject name (aka
participant label) in "subjects_input_id".

```json
  "BoutiquesBidsSingleSubjectMaker": {
    "dataset_input_id": "bids_dir",
    "subjects_input_id": "sub_id",
    "keep_sub_prefix": false
  }
```

2. New command-line. Some observations:

a. There are no longer any clumsy bash commands.
b. There are proper substitutions for both [BIDS_DATASET] (the renamed 'SUBJECT_DIR') and [SUBJECT_ID].
c. It is much more representative of how micapipe works.

```json
  "command-line": "/neurodocker/startup.sh micapipe [BIDS_DATASET] [SUBJECT_ID] [SES]..."
```

3. New definition of the main input:

a. It properly says that the input is a BidsDataset, because that is what micapipe works on.
b. Don't worry, the module adjusts the description to tell users that they can also use a BidsSubject.
c. The command-line flag "-bids" has been re-introduced (and you can see it was removed from the command-line above).

```json
  {
    "name": "BIDS Dataset Folder",
    "description": "The BIDS Dataset to process",
    "id": "bids_dir",
    "optional": false,
    "type": "File",
    "command-line-flag": "-bids",
    "value-key": "[BIDS_DATASET]"
  }
```

4. A new input was added to let users specify a subject name (participant label).

```json
  {
    "name": "Subject ID",
    "description": "The ID of the subject to process, with or without 'sub-'",
    "id": "sub_id",
    "optional": false,
    "type": "String",
    "value-key": "[SUBJECT_ID]",
    "command-line-flag": "-sub"
  }
```

Note that Micapipe only supports a single participant name, but any other tool
that supports multiple names (where `"list": true` would be in the descriptor) are also
supported by the module.

5. There are a few other adjustments, especially in other modules; see these diffs:

  https://github.com/prioux/cbrain-plugins-neuro/commit/48ec9811edeadd119f00a80ec13f009a8180ba16

