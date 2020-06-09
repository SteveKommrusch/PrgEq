# pe-graph2axiom: Graph-to-sequence model based on OpenNMT-py framework.

pe-graph2axiom provides a model which allows training on equivalent program
pairs to create axiomatic proofs of equivalence. Included are scripts which
generate test and training data.

<!-- Add image from paper for camera-ready <center style="padding: 40px"><img width="70%" src="http://Full.png" /></center> -->

Table of Contents
=================
  * [Requirements](#requirements)
  * [Quickstart](#quickstart)
  * [Pregenerated Results](#pregeneratedresults)
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
# For now, get pe-graph2axiom-big.zip
unzip pe-graph2axiom-big
```

## Quickstart

### Step 1: Environment setup
```bash
# cd to top of repository 
# Review env.sh script and adjust for your installation.
cat env.sh
ln -s ../src data
ln -s ../src runs
```

### Step 2: Prepare new datasets if desired
```bash
# cd to top of repository 
source ./env.sh
cd data
# geneqv.pl randomly generates program pairs and proofs in human-readable format
../src/geneqv.pl genenv_arbitrary10.txt > raw_arbitrary10.txt
# pre1axiom.pl creates N 1-axiom training samples for N-axiom long proofs in the raw file
../src/pre1axiom.pl 99 raw_arbitrary10 > pre1_arbitrary10.txt
# pre2graph.pl creates GGNN input formate used by OpenNMT-py
../src/pre2graph.pl < pre1_arbitrary10.txt > all_arbitrary10.txt
cd arbitrary10
# srcvaltest.sh creates training, validation, and test files from full dataset
../../src/srcvaltest.sh ../all_arbitrary10.txt
```

### Step 3: Create models
```bash
# cd to top of repository 
source ./env.sh
cd arbitrary10_g10b
# Clean models if desired
rm *.pt *out 
# run.sh will use OpenNMT to preprocess datasets and train model. Can take several hours with GPU system
setsid nice -n 19 run.sh > run.nohup.out 2>&1 < /dev/null &
```

### Step 4: Use models
```bash
# cd to top of repository
source ./env.sh
cd arbitrary10_g10b
data_path=`/bin/pwd`
# Doing these 4 beam widths takes under an hour on GPU system
for i in 1 2 5 10; do ../../src/search.pl $i 99 ../../data/arbitrary10/all_test.txt final-model_step_300000.pt > mbest_300_arbitrary10/search$i.txt; done
```

### Step 5: Analyze results
```bash
# cd to top of repository
cd runs/arbitrary10_g10b/mbest_300_arbitrary10
# Note that all search*.txt results have FAIL or FOUND lines for all 10000 samples
grep -c "^F" search*txt
# Report number of correctly FOUND proofs for the various beam searches
grep -c "^FOUND" search*txt
# View the full output for all FOUND proofs
grep "^FOUND" search*txt
```

## PregeneratedResults

The repository contains results used for publication, but these can be overwritten with the steps above

data/raw_arbitrary10 is the human-readable file for the AxiomStep10 dataset referred to in the paper.
data/raw_arbitrary5 is the human-readable file for the AxiomStep5 dataset referred to in the paper.
data/raw_ordered10 is the human-readable file for the WholeProof10 dataset referred to in the paper.
data/raw_ordered5 is the human-readable file for the WholeProof5 dataset referred to in the paper.

data/\*/all_test_fullaxioms.txt are files for all datasets showing the 10000 samples and whole proof used in their generation

data/\*/???-train.txt are the files used for training data by our models.
data/\*/???-val.txt are the files used for validation data by our models.
data/\*/???-test.txt are the files used for testing data by our models.

runs/arbitrary10_g10b/final-model_step_300000.pt in the golden model used to find proofs in our paper.

runs/arbitrary10_g10b/mbest_300_arbitrary10/search\* are the final proof results used for our golden model in the paper.
runs/\*/mbest_\*/search\* are the final proof results used for experiments in our paper


## Acknowledgements

Will be added for camera-ready version.

## Citation

Will be added for camera-ready version.
