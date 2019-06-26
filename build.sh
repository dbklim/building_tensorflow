#!/bin/bash

# Сборка и установка ngraph работает крайне коряво, получилось завести версию r0.14 и получил наоборот, замедление работы где-то на 20-30%, вместо обещанного ускорения до х10 раз
# Для нормальной сборки надо cmake и python3-venv
# Собранный пакет ngraph работает только с указанной в ридми версией tensorflow, если подсунуть свой собранный tensorflow той же версии - ошибка, если в процессе сборки ngraph указать ему сборку и tensorflow - так же ошибка

#git clone https://github.com/tensorflow/ngraph-bridge.git
#cd ngraph-bridge
#git checkout r0.14
#python3 build_ngtf.py --use_prebuilt_tensorflow
#cp build_cmake/artifacts/ngraph_tensorflow_bridge*.whl /mnt
#cd /build_tensorflow

echo -e "\nSTEP 1 Preparation\n"
cd tensorflow
git checkout r1.13

echo -e "\nSTEP 2 Configure build\n"
if [[ $1 = 'gpu' ]]
then 
    ./run_configure_gpu_1.13.1
else 
    ./run_configure_cpu_1.13.1
fi

echo -e "\nSTEP 3 Build\n"
if [[ $1 = 'mkl' ]] || [[ $2 = 'mkl' ]]
then
    MKL="-MKL"
    bazel build --config=opt --config=mkl --noincompatible_strict_action_env //tensorflow/tools/pip_package:build_pip_package
else
    MKL=""
    bazel build --config=opt --noincompatible_strict_action_env //tensorflow/tools/pip_package:build_pip_package
fi

echo -e "\nSTEP 4 Create wheel\n"
CPU_MODEL=$(cat /proc/cpuinfo | grep -m 1 "model name" | grep -o "\S[0-9]\?-\?[0-9]\{3,5\}\S" | sed "s/\s//g")
if [[ $1 = 'gpu' ]] || [[ $2 = 'gpu' ]]
then 
    GPU_MODEL=$(nvidia-smi | grep -o -m 1 "GeForce\s\S*\s[0-9]\{0,4\}" | sed "s/\s//g")
    NAME="tensorflow-$CPU_MODEL-$GPU_MODEL$MKL"
else 
    NAME="tensorflow-$CPU_MODEL$MKL"
fi
./bazel-bin/tensorflow/tools/pip_package/build_pip_package /mnt --project_name $NAME

echo -e "\nDone. See $NAME-1.13.1-cp36-cp36m-linux_x86_64.whl\n"
