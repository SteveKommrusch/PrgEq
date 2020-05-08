conda activate pytorch
export CUDA_VISIBLE_DEVICES=0
export THC_CACHING_ALLOCATOR=0
export graphenc=/s/fir/c/nobackup/steveko/PrgEq
export OpenNMT_py=/s/fir/c/nobackup/steveko/OpenNMT-py
export data_path=$graphenc/runs/
cd $data_path
