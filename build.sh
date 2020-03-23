#!/bin/bash

# Сборка и установка ngraph работает крайне коряво, получилось завести версию r0.14 с TensorFlow v1.13.1 и получил наоборот, замедление работы где-то на
# 20-30%, вместо обещанного ускорения до х10 раз.
# Для нормальной сборки надо cmake и python3-venv.
# Собранный пакет ngraph работает только с указанной в ридми версией tensorflow, если подсунуть свой собранный tensorflow той же версии - ошибка,
# если в процессе сборки ngraph указать ему сборку и tensorflow - так же ошибка.
# https://github.com/tensorflow/ngraph-bridge.git

echo -e "\n------------------------------\nSTEP 1. Preparation\n------------------------------\n"
XLA="-XLA"
ROOT_WORK_DIR=$PWD
cd tensorflow
git checkout r1.15

# Исправление ошибки "fatbinary fatal : Unknown option '-bin2c-path'" путём применения коммита "Make nccl bindings compilable with cuda 10.2" из master.
# Ошибка возникает из-за использования cuda 10.2, которая по умолчанию не поддерживается TensorFlow.
# Источник: https://github.com/tensorflow/tensorflow/issues/34429#issuecomment-574296455
git config user.email "vladsklim@gmail.com"
git config user.name "Desklop"
git cherry-pick 67edc16326d6328e7ef096e1b06f81dae1bfb816

# Исправление ошибки с gRPC "error: ambiguating new declaration of 'long int gettid()'" путём применения патча из ишью на гитхабе.
# Ошибка возникает из-за того, что недавно библиотека gRPC была обновлена, изменились имена функций с gettid() на sys_gettid() в файлах
# src/core/lib/gpr/log_linux.cc, src/core/lib/gpr/log_posix.cc и src/core/lib/iomgr/ev_epollex_linux.cc, но из-за старой версии bazel это не учитывает.
# Источник: https://github.com/clearlinux/distribution/issues/1151#issuecomment-580154128
# Внимание! Патч, предложенный в ишью на гитхабе tensorflow не работает: https://github.com/tensorflow/tensorflow/issues/34291#issuecomment-570925292
# Так же не работают конкретно с веткой r1.15 исправления, которые были добавлены в master после того, как проблема появилась.
# Попробовать найти исправления для других версий TensorFlow (ветка r1.14) можно тут: https://github.com/tensorflow/tensorflow/issues/33758
# Нижеописанное исправление так же должно работать с версиями 2.0.1 и 2.1.0.
cp $ROOT_WORK_DIR/Add-grpc-fix-for-gettid.patch ./
git apply Add-grpc-fix-for-gettid.patch
cp $ROOT_WORK_DIR/Rename-gettid-functions.patch ./third_party/Rename-gettid-functions.patch


echo -e "\n------------------------------\nSTEP 2. Configure the build\n------------------------------\n"
if [[ $1 = '-gpu' ]] || [[ $2 = '-gpu' ]]; then
    ./run_configure_gpu_1.15
else 
    ./run_configure_cpu_1.15
fi


echo -e "\n------------------------------\nSTEP 3. Build\n------------------------------\n"
BUILD_ARGUMENTS="--config=opt --copt=-march=native"
if [[ $1 = '-mkl' ]] || [[ $2 = '-mkl' ]]; then
    MKL="-MKL"
    BUILD_ARGUMENTS+=" --config=mkl"
fi
if [[ $1 = '-gpu' ]] || [[ $2 = '-gpu' ]]; then
    BUILD_ARGUMENTS+=" --config=cuda"
fi

# Аргумент --noincompatible_strict_action_env говорит bazel использовать ранее указанный/найденный в ./configure путь к Python
bazel build $BUILD_ARGUMENTS --noincompatible_strict_action_env //tensorflow/tools/pip_package:build_pip_package


echo -e "\n------------------------------\nSTEP 4. Create wheel\n------------------------------\n"
# Получение списка поддерживаемых текущим CPU инструкций
ALL_CPU_INSTRUCTIONS=("sse4.1" "sse4.2" "avx" "avx2" "fma" "avx512f")
CPU_INSTRUCTIONS=($(cat /proc/cpuinfo | grep -m 1 flags | grep -o "sse4_1\s\|sse4_2\s\|avx\s\|avx2\s\|fma\s\|avx512f\s" | sed "s/_/./g" | sed "s/\s//g"))
SUPPORTED_CPU_INSTRUCTIONS=""

# Если длина массива найденных инструкций равна длине массива со всеми известными инструкциями - используем постфикс "-ALL"
if [ ${#CPU_INSTRUCTIONS[@]} -eq ${#ALL_CPU_INSTRUCTIONS[@]} ]; then
    SUPPORTED_CPU_INSTRUCTIONS="-ALL"
fi

# Если длина массива найденных инструкций равна 0 - используем постфикс "-noALL"
if [ ${#CPU_INSTRUCTIONS[@]} -eq 0 ]; then
    SUPPORTED_CPU_INSTRUCTIONS="-noALL"
fi

# Если длина массива найденных инструкций больше 0 и меньше длины массива со всеми известными инструкциями
if [ -z "$SUPPORTED_CPU_INSTRUCTIONS" ]; then
    # Определение числа элементов в массиве найденных инструкций, после которого переходить в постфиксе с перечисления найденных инструкций
    # на перечисление отсутствующих инструкций (вычисляется как "половина длины массива со всеми известными инструкциями + 1")
    LIMIT=$(expr ${#ALL_CPU_INSTRUCTIONS[@]} - ${#ALL_CPU_INSTRUCTIONS[@]} / 2 + 1)

    # Если число найденных инструкций больше или равно "границе перехода"
    if [ ${#CPU_INSTRUCTIONS[@]} -ge $LIMIT ]; then
        # Поиск отсутствующих инструкций
        for found_instruction in ${CPU_INSTRUCTIONS[@]}; do
            for i in ${!ALL_CPU_INSTRUCTIONS[@]}; do
                if [ ${ALL_CPU_INSTRUCTIONS[$i]} = $found_instruction ]; then
                    unset ALL_CPU_INSTRUCTIONS[$i]
                fi
            done
        done
        
        # Сохранение отсутствующих инструкций в постфикс
        for not_found_instruction in ${ALL_CPU_INSTRUCTIONS[@]}; do
            SUPPORTED_CPU_INSTRUCTIONS+="-no${not_found_instruction^^}"
        done
    else
        # Сохранение найденных инструкций в постфикс
        for found_instruction in ${CPU_INSTRUCTIONS[@]}; do
            SUPPORTED_CPU_INSTRUCTIONS+="-${found_instruction^^}"
        done
    fi
fi

# Что бы флаг FMA был в конце списка инструкций, а не в начале (просто для красоты)
if [[ -n $(echo $SUPPORTED_CPU_INSTRUCTIONS | grep -o "FMA") ]] >> /dev/null; then
    SUPPORTED_CPU_INSTRUCTIONS=$(echo $SUPPORTED_CPU_INSTRUCTIONS | sed "s/-FMA//")
    SUPPORTED_CPU_INSTRUCTIONS+="-FMA"
fi

if [[ $1 = '-gpu' ]] || [[ $2 = '-gpu' ]]; then
    # Определение версии CUDA
    CUDA_VERSION=$(nvcc -V | grep -o "release [0-9]\{1,2\}\.[0-9]" | sed "s/release //g")
    CUDA_VERSION="-cuda${CUDA_VERSION}"
    NAME="tensorflow-gpu${SUPPORTED_CPU_INSTRUCTIONS}${CUDA_VERSION}${MKL}${XLA}"
else 
    NAME="tensorflow-cpu${SUPPORTED_CPU_INSTRUCTIONS}${MKL}${XLA}"
fi

PACKAGE_DIR="${ROOT_WORK_DIR}/built_packages"
./bazel-bin/tensorflow/tools/pip_package/build_pip_package $PACKAGE_DIR --project_name $NAME

# Что бы имя не отличалось от присвоенного пакету (bazel в названии проекта все '-' заменяет на '_')
NAME=$(echo $NAME | sed "s/-/_/g")
PYTHON3_VERSION=$(python3 -V | grep -o "[0-9]\.[0-9]" | sed "s/\.//g")
echo -e "\nDone. See ${PACKAGE_DIR}/${NAME}-1.15.2-cp${PYTHON3_VERSION}-cp${PYTHON3_VERSION}m-linux_x86_64.whl\n"

# OLD
#CPU_MODEL=$(cat /proc/cpuinfo | grep -m 1 "model name" | grep -o "\S[0-9]\?-\?[0-9]\{3,5\}\S\?" | sed "s/\s//g")
#CPU_SERIES=$(cat /proc/cpuinfo | grep -m 1 "model name" | grep -o "\(Xeon\)\|\(KVM\)")
#if [[ $CPU_SERIES = 'Xeon' ]]; then
#    CPU_MODEL="$CPU_SERIES$CPU_MODEL"
#fi
#if [[ $CPU_SERIES = 'KVM' ]]; then
#    CPU_MODEL="$CPU_SERIES$CPU_MODEL"
#fi

#if [[ $1 = '-gpu' ]] || [[ $2 = '-gpu' ]]; then
#    GPU_MODEL=$(nvidia-smi | grep -o -m 1 "\(GeForce\|Tesla\)\s\S*\s[0-9]\{0,4\}" | sed "s/\s//g")
#    # Костыль, nvidia-smi выводит модель видеокарт серии RTX не полностью, т.к. они слишком длинные, теряется 0 в конце
#    if echo $GPU_MODEL | grep -o -m 1 "RTX" > /dev/null; then
#        GPU_MODEL+="0"
#    fi
#    CUDA_VERSION=$(nvcc -V | grep -o "release [0-9]\{1,2\}\.[0-9]" | sed "s/release //g")
#    CUDA_VERSION="-cuda${CUDA_VERSION}"
#    NAME="tensorflow-gpu-${CPU_MODEL}-${GPU_MODEL}${CUDA_VERSION}${MKL}${XLA}"
#else 
#    NAME="tensorflow-cpu-${CPU_MODEL}${MKL}${XLA}"
#fi