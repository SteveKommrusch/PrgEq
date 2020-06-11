# pe-graph2axiom: Graph-to-sequence model based on OpenNMT-py framework.

pe-graph2axiom provides a model which allows training on equivalent program
pairs to create axiomatic proofs of equivalence. Included are scripts which
generate test and training data.

There are 2 versions of this file set; a 44MB pe-graph2axiom.zip file and a 699MB pe-graph2axiom-big file.

### pe-graph2axiom.zip
  * Provides all control scripts to generate datasets and train models as well as key results files found in our paper.
  * src/ includes all scripts used to generate training data and search for proofs using our trained model. Note: These scripts use slightly different axiom names than in the paper; in particular, Noop, Double, and Multzero are used in the code which correspond to NeutralOp, DoubleOp, and AbsorbOp in the paper.
  * data/ includes our dataset generation configuration files and the data/\*/all\_test\_fullaxiom.txt files showing the (P1,P2,S) tuples for the test sets.
  * runs/ includes results for all 4 models presented in our paper. For each model we provide training output files, testset input files, OpenNMT interface scripts, and P1,P2 proof results from the models for beam search 1 and 10 (2 and 5 are provided in pe-graph2axiom-big). Our golden results of 9,310 successful equivalence proofs on a 10,000 sample testset are in runs/AxiomStep10/mbest\_300\_AxiomStep10/search10.txt.

### pe-graph2axiom-big.zip
  * This file is available via anonymous URL at: http://gofile.io/d/4MxVv1
  * Includes all files from pe-graph2axiom.zip
  * Provides all files needed to reproduce results found in our paper including our specific dataset files and trained models.
  * src/ includes all scripts used to generate training data and search for proofs using our trained model.
  * data/ includes our dataset generation configuration files and the data/\*/all\_test\* files showing the (P1,P2,S) tuples for the test sets, and test files used during inference by our models.
  * runs/ includes input files, trained models, and results for all 4 models presented in our paper. In addition to files from pe-graph2axiom.zip, the full training dataset files for OpenNMT input are provided, as well as the saved model with the best validation score. Our golden model is runs/AxiomStep10/final-model\_step\_300000.pt.

Table of Contents
=================
  * [Requirements](#requirements)
  * [Quickstart](#quickstart)
  * [File Descriptions](#filedescriptions)
  * [Acknowledgements](#acknowledgements)
  * [Citation](#citation)

## Requirements

### Step 1: Install OpenNMT-py and related packages
Install `OpenNMT-py` from `pip`:
```bash
pip install OpenNMT-py
```

or from the sources:
```bash
git clone https://github.com/OpenNMT/OpenNMT-py.git
cd OpenNMT-py
python setup.py install
```

Note: If you have MemoryError in the install try to use `pip` with `--no-cache-dir`.

*(Optional)* some advanced features (e.g. working audio, image or pretrained models) requires extra packages, you can install it with:
```bash
pip install -r requirements.opt.txt
```

### Step 2: Install pe-graph2axiom
```bash
# cd to the parent directory to OpenNMT-py
# At camera-ready: git clone <anonymized>
# For now, get pe-graph2axiom.zip
unzip pe-graph2axiom.zip
```

## Quickstart

### Step 1: Environment setup
```bash
# cd to top of repository 
# Review env.sh script and adjust for your installation.
cat env.sh
```

### Step 2: Prepare new datasets if desired
```bash
# cd to top of repository 
source ./env.sh
cd data
# geneqv.pl randomly generates program pairs and proofs in human-readable format
../src/geneqv.pl genenv_AxiomStep10.txt > raw_AxiomStep10.txt
# pre1axiom.pl creates N 1-axiom training samples for N-axiom long proofs in the raw file
../src/pre1axiom.pl 99 raw_AxiomStep10 > pre1_AxiomStep10.txt
# pre2graph.pl creates GGNN input formate used by OpenNMT-py
../src/pre2graph.pl < pre1_AxiomStep10.txt > all_AxiomStep10.txt
cd AxiomStep10
# srcvaltest.sh creates training, validation, and test files from full dataset
../../src/srcvaltest.sh ../all_AxiomStep10.txt
```

### Step 3: Create models
```bash
# cd to top of repository 
source ./env.sh
cd AxiomStep10
# Clean models if desired
rm *.pt *out 
# run.sh will use OpenNMT to preprocess datasets and train model. Can take several hours with GPU system
setsid nice -n 19 run.sh > run.nohup.out 2>&1 < /dev/null &
```

### Step 4: Use models
```bash
# cd to top of repository
source ./env.sh
cd AxiomStep10
data_path=`/bin/pwd`
# Doing these 4 beam widths takes under an hour on GPU system
for i in 1 2 5 10; do ../../src/search.pl $i 99 ../../data/AxiomStep10/all_test.txt final-model_step_300000.pt > mbest_300_AxiomStep10/search$i.txt; done
```

### Step 5: Analyze results
```bash
# cd to top of repository
cd runs/AxiomStep10/mbest_300_AxiomStep10
# Note that all search*.txt results have FAIL or FOUND lines for all 10000 samples
grep -c "^F" search*txt
# Report number of correctly FOUND proofs for the various beam searches
grep -c "^FOUND" search*txt
# View the full output for all FOUND proofs
grep "^FOUND" search*txt
```

## FileDescriptions

The repository contains data, models, and results used for publication, but these can be overwritten with the steps above as desired.

 * ./env.sh: Environment variable setup 

 * src/allPossibleAxioms.pl: Provides subrouting with returns all possible axioms on an input program.
 * src/checkeq.pl: Used with WorldProof\* models to check how many test samples the model proved equivalent.
 * src/compare.py: Used with WorldProof\* models to check how many test sample outputs exactly match expected axiom proof.
 * src/geneqv.pl: Uses config files in data/geneqv*txt to generate random (P1,P2,S) samples for dataset.
 * src/genProgUsingAxioms.pl: Generates intemediate program given input program and axiom for use by AxiomStep models.
 * src/greps.sh: Counts distribution of axiom proof lengths in a file.
 * src/possibleAxioms.pl: Processes input file and prints all possible axioms for P1 samples.
 * src/pre1axiom.pl: Turns dataset with (P1,P2,S), where S may be a multi-axiom proof, into a dataset with single-axiom targets for training AxiomStep\* models.
 * src/pre2graph.pl: Turns human-readable (P1,P2,S) samples into OpenNMT GGNN input format including node feature values and edge connections.
 * src/search.pl: Search for proofs on a test set using trained AxiomStep\* model.
 * src/search_seq.pl: Adjusted version of search.pl to search using a trained sequence-to-sequence model for experimental evaluation.
 * src/srcvaltest.sh: Processes full OpenNMT dataset file to produce training, validation, and test sets.

 * data/geneqv_\*txt: Files used by src/geneqv.pl to configure dataset generation.
 * data/KhanPlusManual: Includes test files for KhanAcademy problems and some manually generated problems used in our paper.
 * data/AxiomStep10: Includes test files for AxiomStep10 dataset described in our paper
 * data/AxiomStep5: Includes test files for AxiomStep5 dataset described in our paper
 * data/WholeProof10: Includes test files for WholeProof10 dataset described in our paper
 * data/WholeProof5: Includes test files for WholeProof5 dataset described in our paper

 * data/\*/all\_test.txt: Files providing OpenNMT GGNN input and target and readable P1,P2,S tuples for dataset tests.
 * data/\*/all\_test\_fullaxioms.txt: Files showing the 10000 samples and whole proof used in their generation.
 * data/\*/all\_test\_passible.txt: Files showing the 10000 samples and all possible axioms for P1.

 * runs/\*: 4 directories for our 4 primary models discussed in our paper.
 * runs/\*/???-train.txt are source input and target output files used for training our models.
 * runs/\*/???-val.txt are source input and target output files used for validating our models.
 * runs/\*/???-test.txt are source input and target output files used for testing our models.
 * runs/\*/srcvocab.txt: Source vocabulary including tokens for Linear Algebra math.
 * runs/\*/tgtvocab.txt: Target vocabulary including 'left', 'right', and axiom names.
 * runs/\*/OpenNMT_train.out: Output file during model training showing parameter sizes and accuracy results during training.
 * runs/\*/preprocess.sh: Calls OpenNMT preprocess step to prepare data for training.
 * runs/\*/train.sh: Calls OpenNMT training step
 * runs/\*/run.sh: Combines preprocess and training to ease batch mode training.
 * runs/WorldProof\*/translate*sh: Calls OpenNMT translate step to produce proposed whole proofs on dataset.
 * runs/AxiomStep10/final-model\_step\_300000.pt is the golden model used to find proofs in our paper.
 * runs/\*/final-model\_step\_\*.pt are the best model resulting from training twice, based on validation score.

 * runs/AxiomStep10/mbest_300_AxiomStep10/search10.txt: The final beam with 10 proof results used for our golden model in the paper showing 9,310 proofs found out of 10,000 tests.
 * runs/\*/mbest\*AxiomStep10: Results for testing the given model using the AxiomStep10 test dataset.
 * runs/\*/mbest\*AxiomStep5: Results for testing the given model using the AxiomStep5 test dataset.
 * runs/\*/mbest\*WholeProof10: Results for testing the given model using the WholeProof10 test dataset.
 * runs/\*/mbest\*WholeProof5: Results for testing the given model using the WholeProof5 test dataset.
 * runs/AxiomStep\*/mbest_\*/search\*: are the final proof results used for our AxiomStep\* models.
 * runs/WholeProof\*/mbest_\*/check\*: are the results of checking whether generated proofs prove equivalence on test dataset.
 * runs/WholeProof\*/mbest_\*/pass\*: are the results of checking whether generated proofs prove exactly match the test sample target proof.


## Acknowledgements

Will be added for camera-ready version.

## Citation

Will be added for camera-ready version.
