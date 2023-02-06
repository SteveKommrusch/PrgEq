# S4Eq: Self-Supervised Learning to Prove Equivalence Between Programs via Semantics-Preserving Rewrite Rules

S4Eq provides a model which allows training on equivalent program pairs to 
create axiomatic proofs of equivalence. We use self-supervised sample selection to incrementally train
the model; a technique in which proof attempts can be used to train the model to improve itself.
Included are scripts which generate test and training data, as well as data mined from GitHub.

  * Our paper detailing the use and testing of S4Eq is on ArXiv at: https://arxiv.org/abs/2109.10476
  * src/ includes scripts used to generate training data and search for proofs using our trained model. Note: These scripts use slightly different axiom names than in the paper; in particular, Noop, Double, and Multzero are used in the code which correspond to NeutralOp, DoubleOp, and AbsorbOp in the paper.
  * data/ includes our dataset generation configuration files, raw data from GitHub program samples, our evaluation program pairs, etc.
  * runs/ includes results for models presented in our paper. In particular, runs/vfs4x/tr_h8_l8_512_r18 are our golden model and results for our model with 8 heads, 8 transformer layers, vector size 512, with a final iterative learning rate starting at 0.00005 and a final learning rate decay of 0.8.

Table of Contents
=================
  * [Requirements](#requirements)
  * [Quickstart](#quickstart)
  * [File Descriptions](#filedescriptions)

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

### Step 2: Install PrgEq
```bash
# cd to the parent directory of OpenNMT-py
# git clone https://github.com/SteveKommrusch/PrgEq.git
```

## Quickstart

### Step 1: Environment setup
```bash
# cd to top of PrgEq repository 
# Review env.sh script and adjust for your installation.
cat env.sh
```

### Step 2: Prepare new datasets if desired
```bash
# cd to top of PrgEq repository 
source ./env.sh
cd data/vsf4/
# geneqv.pl randomly generates program pairs and proofs in human-readable format
../../src/geneqv.pl straightline.txt > raw_straight.txt 
# pre1axiom.pl creates N 1-axiom training samples for N-axiom long proofs in the raw file
../../src/pre1axiom.pl 220 raw_straight.txt > pre1axiom.out
# pre2graph.pl creates GGNN input formate used by OpenNMT-py
../../src/pre2graph.pl < pre1axiom.out > all_straight.txt
# srcvaltest.sh creates training, validation, and test files from full dataset
../../src/srcvaltest.sh all_straight.txt
```

### Step 3: Create base model example
```bash
# cd to top of PrgEq repository 
source ./env.sh
cd runs/vsf4x
d=h8_l8_512_r18
# onmt.sh will use OpenNMT to preprocess datasets and train model. Can take several hours with GPU system
setsid nice -n 19 onmt.sh $d > tr_$d/onmt.out 2>&1 < /dev/null
```

### Step 4: Attempt proofs for incremental training of base model
```bash
# cd to top of PrgEq repository
source ./env.sh
# Generate template programs based on GitHub dataset
cd data
../src/usetemplate.pl vsf4/straightline.txt VRepair_templates.txt > vsf4_tune1/raw_template.txt
# Repeat synthetic program pair generation from step 4
cd vsf4x/vsf4_tune1
../../src/geneqv.pl straightline.txt > raw_straight.txt 
../../src/pre1axiom.pl 220 raw_straight.txt > pre1axiom.out
../../src/srcvaltest.sh all_straight.txt
# Create 10 sets of 10,000 program pairs for proof attempts
../../src/srcvaltest_tune.sh
```

### Step 5: Attempt proofs for incremental training of base model
```bash
# The 4 lines below can be run with i=1,2,3,4,5,6,7,8,9,10
# on the different test program pairs. The 20 search.pl commands can be run 
# on 20 different machines for improved throughput, or on 1 machine.
source eq.sh ; cd vsf4x ; t=tune1 ; i=1
ln -s ../../data/vsf4_${t}/tune_b${i}_fullaxioms.txt ${t}_b${i}_fullaxioms.txt
setsid nice -n 19 ../../src/search.pl 20 20 250 ${t}_b${i}_fullaxioms.txt tr_h8_l8_512_r18/model_step_100000.pt tr_h8_l8_512_r18/$t/b$i > tr_h8_l8_512_r18/$t/b$i/tune20_20.txt
setsid nice -n 19 ../../src/search.pl 20 2 250 ${t}_b${i}_fullaxioms.txt tr_h8_l8_512_r18/model_step_100000.pt tr_h8_l8_512_r18/$t/b$i > tr_h8_l8_512_r18/$t/b$i/tune20_2.txt
```

### Step 4: Use models
```bash
# cd to top of PrgEq repository
source ./env.sh
cd AxiomStep10
data_path=`/bin/pwd`
# Doing these 4 beam widths takes under an hour on GPU system
for i in 1 2 5 10; do ../../src/search.pl $i 99 ../../data/AxiomStep10/all_test.txt final-model_step_300000.pt > mbest_300_AxiomStep10/search$i.txt; done
```

### Step 5: Analyze results
```bash
# cd to top of PrgEq repository
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


