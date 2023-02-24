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

### Step 0: Set up miniconda, or other virtual environtment
https://www.anaconda.com/products/distribution#linux

### Step 1: Install PrgEq
```bash
# cd to a directory where you want to install PrgEq
git clone https://github.com/SteveKommrusch/PrgEq.git
```

### Step 2: Install OpenNMT-py and related packages
```bash
# Start up virtual environment
conda activate
# cd to the parent directory of PrgEq
# Install `OpenNMT-py` :
git clone https://github.com/OpenNMT/OpenNMT-py.git
cd OpenNMT-py
python setup.py install
```

## Quickstart

### Step 1: Environment setup
```bash
# cd to top of PrgEq repository 
# Review env.sh script and adjust for your installation.
# The script expects PrgEg and OpenNMT-py to be in $HOME/S4Eq
# The script expect a conda environment to run in (edit for venv or other setups)
cat env.sh   # Edit as appropriate
source env.sh
# install pytorch 
conda install pytorch torchvision torchaudio pytorch-cuda=11.7 -c pytorch -c nvidia
pip install --upgrade OpenNMT-py==2.0.0rc1
```

### Step 2: Prepare new datasets if desired
```bash
cd $PrgEqDir     # From PrgEq/env.sh
cd data
ln -s ../src .
cd vsf4
# geneqv.pl randomly generates program pairs and proofs in human-readable format
../../src/geneqv.pl straightline.txt > raw_straight.txt 
# pre1axiom.pl creates N 1-axiom training samples for N-axiom long proofs in the raw file
../../src/pre1axiom.pl 220 raw_straight.txt > pre1axiom.out
# pre2graph.pl creates GGNN input formate used by OpenNMT-py
../../src/pre2graph.pl < pre1axiom.out > all_straight.txt
# srcvaltest.sh creates training, validation, and test files from full dataset
../../src/srcvaltest.sh all_straight.txt
```

### Step 2b: Generate template data from VRepair github data
```bash
cd $PrgEqDir/..     # From PrgEq/env.sh
git clone https://github.com/chenzimin/VRepair.git
cd VRepair/data/Full
# gentemplate.pl processes files into a form of compiler IR (Intermediate Representation)
$PrgEqDir/src/gentemplate.pl > $PrgEqDir/data/DBG_VRepair_templates.txt
cd $PrgEqDir/data
grep "^ t1" $PrgEqDir/data/DBG_VRepair_templates.txt | sort -u | shuf > $PrgEqDir/data/VRepair_templates.txt 
```

### Step 3: Create base model example
```bash
cd $PrgEqDir     # From PrgEq/env.sh
cd runs
ln -s ../src .
cd vsf4x
d=h8_l8_512_r18
ln -s ../../data/vsf4/src-trainx.txt src-train.txt
ln -s ../../data/vsf4/src-valx.txt src-val.txt
ln -s ../../data/vsf4/src-testx.txt src-test.txt
ln -s ../../data/vsf4/tgt-train.txt tgt-train.txt
ln -s ../../data/vsf4/tgt-val.txt tgt-val.txt
ln -s ../../data/vsf4/tgt-test.txt tgt-test.txt
# onmt.sh will use OpenNMT to preprocess datasets and train model. Can take several hours with GPU system
setsid nice -n 19 onmt.sh $d > tr_$d/onmt.out 2>&1 < /dev/null
```

### Step 4: Create propgram pairs to attempt with trained model
```bash
cd $PrgEqDir     # From PrgEq/env.sh
# Generate template programs based on GitHub dataset
cd data
../src/usetemplate.pl vsf4/straightline.txt VRepair_templates.txt > vsf4_tune1/raw_template.txt
# Repeat synthetic program pair generation from step 4
cd vsf4_tune1
../../src/geneqv.pl straightline.txt > raw_straight.txt 
../../src/pre1axiom.pl 220 raw_straight.txt > pre1axiom.out
../../src/pre2graph.pl < pre1axiom.out > all_straight.txt
# Create 10 sets of 10,000 program pairs for proof attempts
../../src/srcvaltest_tune.sh
```

### Step 5: Attempt proofs for incremental training of base model
```bash
cd $PrgEqDir     # From PrgEq/env.sh
cd runs/vsf4x
# The 4 lines below can be run with i=1,2,3,4,5,6,7,8,9,10
# on the different test program pairs. The 20 search.pl commands can be run 
# on 20 different machines for improved throughput, or on 1 machine.
t=tune1 ; i=1
ln -s ../../data/vsf4_${t}/tune_b${i}_fullaxioms.txt ${t}_b${i}_fullaxioms.txt
setsid nice -n 19 ../../src/search.pl 20 20 250 ${t}_b${i}_fullaxioms.txt tr_h8_l8_512_r18/model_step_100000.pt tr_h8_l8_512_r18/$t/b$i > tr_h8_l8_512_r18/$t/b$i/tune20_20.txt
setsid nice -n 19 ../../src/search.pl 20 2 250 ${t}_b${i}_fullaxioms.txt tr_h8_l8_512_r18/model_step_100000.pt tr_h8_l8_512_r18/$t/b$i > tr_h8_l8_512_r18/$t/b$i/tune20_2.txt
```

### Step 6: Create new training data from challenging proofs
```bash
cd $PrgEqDir     # From PrgEq/env.sh
cd runs/vsf4x/tr_h8_l8_512_r18/tune1
# srcvaltest_findallrare.sh will process easy vs hard proofs and include rare 
# steps (hindsight experience replay as per paper)
../../../../src/srcvaltest_findallrare.sh
```

### Step 7: Train model incrementally with 4 different learning rates
```bash
cd $PrgEqDir     # From PrgEq/env.sh
cd runs/vsf4x/tr_h8_l8_512_r18
# The lines below can be run with r=r18,r19,r58,r59
# on the different test program pairs. The 4 different learning rate runs
# can run on 4 different machines for improved throughput, or on 1 machine.
t=tune1 ; r=r18
# onmt_train should be found from OpenNMT
setsid nice -n 19 onmt_train --config ${t}_$r.yaml > $t/train_$r.out 2>&1 < /dev/null
```

### Step 8: Evaluate incremental model with validation set
```bash
cd $PrgEqDir     # From PrgEq/env.sh
cd runs/vsf4x
# The lines below can be run with m=m1_r18_step_50000, m1_r58_step_30000, m1_r59_step_40000, etc
# Typically we validated 30000, 40000, and 50000 for the 4 different learning rates.
t=tune1; m=m1_r18_step_50000
mkdir -p tr_h8_l8_512_r18/$t/$m
setsid nice -n 19 ../../src/search.pl 25 10 250 all_test_fullaxioms.txt tr_h8_l8_512_r18/$m.pt tr_h8_l8_512_r18/$t/$m > tr_h8_l8_512_r18/$t/$m/search25_10.txt 2>&1 < /dev/null
setsid nice -n 19 ../../src/search.pl 25 10 250 template_test_fullaxioms.txt tr_h8_l8_512_r18/$m.pt tr_h8_l8_512_r18/$t/$m > tr_h8_l8_512_r18/$t/$m/template25_10.txt 2>&1 < /dev/null
# Of the 1,000 synthetic and template validation program pairs, count the number of found proofs
grep -c FOUND tr_h8_l8_512_r18/$t/m*/*25_10.txt
```

### Iterate for model improvement using self-supervised sample selection
Repeat steps 4 through 8 to continuously improve model

### Analyze 10,000 synthetic and 10,000 GitHub sample test results
```bash
cd $PrgEqDir     # From PrgEq/env.sh
cd runs/vsf4x
t=tune6; m=m6_r58_step_40000
setsid nice -n 19 ../../src/search.pl 50 10 250 syn_eval_fullaxioms.txt tr_h8_l8_512_r18/$m.pt tr_h8_l8_512_r18/tune6/$m > tr_h8_l8_512_r18/tune6/$m/syn50_10.txt 2>&1 < /dev/null
setsid nice -n 19 ../../src/search.pl 50 10 250 tpl_eval_fullaxioms.txt tr_h8_l8_512_r18/$m.pt tr_h8_l8_512_r18/tune6/$m > tr_h8_l8_512_r18/tune6/$m/tpl50_10.txt 2>&1 < /dev/null
# Count found proofs
grep -c "^FOUND" tr_h8_l8_512_r18/tune6/$m/???50_10.txt
```

## FileDescriptions

The repository contains data, models, and results used for publication, but these can be overwritten with the steps above as desired.

 * ./env.sh: Environment variable setup 

 * src/geneqv.pl: Uses language grammar file to generate random sample program pair for dataset.
 * src/pre1axiom.pl: Turns dataset which may include multi-axiom proofs into a dataset with single-axiom targets for each step along the proof sequence
 * src/pre2graph.pl: Legacy program which adds OpenNMT GGNN input format including node feature values and edge connections but also prunes program sizes as described in our paper
 * src/srcvaltest.sh: Generates training, validation and test for dataset
 * src/usetemplate.pl: Attempt compiler optization steps to generate program pair data from GitHub templates
 * src/gentemplate.pl: Generate templates from VRepair/data/full samples 
 * src/srcvaltest.sh: Generates training, validation and test for dataset
 * src/srcvaltest_tune.sh: Generates training, validation and test using synthetic and template data for test program pairs which can be used to incrementally train model.
 * src/search.pl: Search for proofs on a test set using trained model
 * src/srcvaltest_findallrare.sh: Generates training, validation and test using results from proof attempts for self-supervised sample selection.

 * runs/vsf4x/onmt.sh: Run training on model while checking for alternate users on machine to allow machine sharing
 * runs/vsf4x/tr_h8_l8_512_r18/model_step_100000.pt: The initial model trained for 100,000 steps on only synthetic pair examples the paper refers to this as M1.
 * runs/vsf4x/tr_h8_l8_512_r18/m6_m58_step_40000.pt: This the model referred to as M7 in the paper (it is the m6 model trained with 0.00005 initial learning rate, learning_rate_decay of 0.8, and for 40,000 steps).
 * runs/vsf4x/tr_h8_l8_512_r18/cont_r18_step_240000.pt: This is the the result of training model_step_100000.pt for an additional 240000 steps on the same synthetic examples. In the paper this is the Q model.
 * runs/vsf4x/tr_h8_l8_512_r18/*yaml: These are the yaml files used to set up training parameters for onmt_train.
 * runs/vsf4x/tr_h8_l8_512_r18/tune1: Intermediate files for incremental testing and training of M1 model, included as examples of results that occur as steps are followed.
 * runs/vsf4x/tr_h8_l8_512_r18/tune6/m6_m58_step_40000/syn50_10.txt: Results for proof attempts of 10,000 held out synthetic program pairs on golden model (9,844 proofs were found).
 * runs/vsf4x/tr_h8_l8_512_r18/tune6/m6_m58_step_40000/syn50_10.txt: Results for proof attempts of 10,000 held out GitHub template program pairs on golden model (9,688 proofs were found).
 
 * data/VRepair_sourcecode.txt: 16,383 unique samples of straightline computation code mined from GitHub
 * data/VRepair_templates.txt: 16,383 unique templates of input, temporary, and output variable computions implementing the sourcecode mined from GitHub.
 * data/vsf4/straightline.txt: Description of our language grammar used by program pair generation scripts.
 * data/vsf4/src-*.txt: Source files for input to transformer model.
 * data/vsf4/tgt-*.txt: Target rewrite rule outputs for training and testing transformer model
