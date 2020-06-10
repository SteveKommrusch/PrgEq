# pe-graph2axiom: Graph-to-sequence model based on OpenNMT-py framework.

pe-graph2axiom provides a model which allows training on equivalent program
pairs to create axiomatic proofs of equivalence. Included are scripts which
generate test and training data.

There are 2 versions of this dataset; a 44MB pe-graph2axiom.zip file and a 699MB pe-graph2axiom-big file.

### pe-graph2axiom.zip
  * Provides all control scripts to generate datasets and train models as well as key results files found in our paper.
  * src/ includes all scripts used to generate training data and search for proofs using our trained model.
  * data/ includes our dataset generation configuration files and the data/\*/all\_test\_fullaxiom.txt files showing the (P1,P2,S) tuples for the test sets.
  * runs/ includes results for all 4 models presented in our paper. For each model we provide training output files, testset input files, OpenNMT interface scripts, and P1,P2 proof results from the models for beam search 1 and 10 (2 and 5 are provided in pe-graph2axiom-big).

### pe-graph2axiom-big.zip
  * Includes all files from pe-graph2axiom.zip
  * Provides all files needed to reproduce results found in our paper including our specific dataset files and trained models.
  * src/ includes all scripts used to generate training data and search for proofs using our trained model.
  * data/ includes our dataset generation configuration files and the data/\*/all\_test\* files showing the (P1,P2,S) tuples for the test sets, and test files used during inference by our models.
  * runs/ includes input files, trained models, and results for all 4 models presented in our paper. In addition to files from pe-graph2axiom.zip, the full training dataset files for OpenNMT input are provided, as well as the save model with the best validation score. Our golden model is runs/AxiomStep10/final-model\_step\_300000.pt.

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

### Step 2: Install pe-graph2axiom: FIXME: Remove references to Kommrusch
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
../src/geneqv.pl genenv_AxiomStep10.txt > raw_arbitrary10.txt
# pre1axiom.pl creates N 1-axiom training samples for N-axiom long proofs in the raw file
../src/pre1axiom.pl 99 raw_AxiomStep10 > pre1_arbitrary10.txt
# pre2graph.pl creates GGNN input formate used by OpenNMT-py
../src/pre2graph.pl < pre1_AxiomStep10.txt > all_arbitrary10.txt
cd AxiomStep10
# srcvaltest.sh creates training, validation, and test files from full dataset
../../src/srcvaltest.sh ../all_AxiomStep10.txt
```

### Step 3: Create models
```bash
# cd to top of repository 
source ./env.sh
cd AxiomStep10_g10b
# Clean models if desired
rm *.pt *out 
# run.sh will use OpenNMT to preprocess datasets and train model. Can take several hours with GPU system
setsid nice -n 19 run.sh > run.nohup.out 2>&1 < /dev/null &
```

### Step 4: Use models
```bash
# cd to top of repository
source ./env.sh
cd AxiomStep10_g10b
data_path=`/bin/pwd`
# Doing these 4 beam widths takes under an hour on GPU system
for i in 1 2 5 10; do ../../src/search.pl $i 99 ../../data/AxiomStep10/all_test.txt final-model_step_300000.pt > mbest_300_arbitrary10/search$i.txt; done
```

### Step 5: Analyze results
```bash
# cd to top of repository
cd runs/AxiomStep10_g10b/mbest_300_arbitrary10
# Note that all search*.txt results have FAIL or FOUND lines for all 10000 samples
grep -c "^F" search*txt
# Report number of correctly FOUND proofs for the various beam searches
grep -c "^FOUND" search*txt
# View the full output for all FOUND proofs
grep "^FOUND" search*txt
```

## FileDescriptions

The repository contains data, models, and results used for publication, but these can be overwritten with the steps above as desired.

./env.sh: Environment variable setup 

src/

data/geneqv_\*txt: Files used by src/geneqv.pl to configure dataset generation.
data/KhanPlusManual: Includes test files for KhanAcademy problems and some manually generated problems used in our paper.
data/AxiomStep10: Includes test files for AxiomStep10 dataset described in our paper
data/AxiomStep5: Includes test files for AxiomStep5 dataset described in our paper
data/WholeProof10: Includes test files for WholeProof10 dataset described in our paper
data/WholeProof5: Includes test files for WholeProof5 dataset described in our paper

data/\*/all\_test.txt: Files providing P1,P2,S tuples for dataset tests.
data/\*/all\_test\_fullaxioms.txt: Files showing the 10000 samples and whole proof used in their generation.
data/\*/all\_test\_passible.txt: Files showing the 10000 samples and all possible axioms for P1.

runs/\*: 4 directories for our 4 primary models discussed in our paper.
runs/\*/???-train.txt are source input and target output files used for training our models.
runs/\*/???-val.txt are source input and target output files used for validating our models.
runs/\*/???-test.txt are source input and target output files used for testing our models.

runs/AxiomStep10/final-model\_step\_300000.pt is the golden model used to find proofs in our paper.
runs/\*/final-model\_step\_\*.pt are the best model resulting from training twice, based on validation score.

runs/AxiomStep10_g10b/mbest_300_arbitrary10/search\* are the final proof results used for our golden model in the paper.
runs/\*/mbest_\*/search\* are the final proof results used for experiments in our paper


## Acknowledgements

Will be added for camera-ready version.

## Citation

Will be added for camera-ready version.
