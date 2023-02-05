conda activate pytorch
export CUDA_VISIBLE_DEVICES=0
export THC_CACHING_ALLOCATOR=0
export graphenc=$HOME/Eq2020/PrgEq
export OpenNMT_py=$HOME/Eq2020/OpenNMT-py
export data_path=$graphenc/runs/
cd $data_path
