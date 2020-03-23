# Building TensorFlow

**Проект** предназначен **для сборки** оптимизированной версии [**TensorFlow v1.15.2**](https://www.tensorflow.org/) и [**TensorFlow-GPU v1.15.2**](https://www.tensorflow.org/) под CPU и GPU на хост-машине из исходников в docker контейнере.

**Список уже собранных версий** и ссылки для их скачивания **доступны** в [соседнем репозитории](https://github.com/Desklop/optimized_tensorflow_builds).

Репозиторий содержит **2 Dockerfile**:

- [Dockerfile_cpu_cp37](https://github.com/Desklop/building_tensorflow/blob/master/Dockerfile_cpu_cp37) - сборка TensorFlow v1.15.2 для Python 3.7
- [Dockerfile_gpu_cp37](https://github.com/Desklop/building_tensorflow/blob/master/Dockerfile_gpu_cp37) - сборка TensorFlow-GPU v1.15.2 для Python 3.7

---

## Docker-образ

**Для сборки TensorFlow используется** ОС **Ubuntu 19.10** с установленными зависимостями в соответствии с официальной [инструкцией](https://www.tensorflow.org/install/source#setup_for_linux_and_macos). **Для сборки с поддержкой GPU** дополнительно **используется образ с** установленными библиотеками [**CUDA 10**](https://developer.nvidia.com/cuda-zone) и [**cuDNN 7.6**](https://developer.nvidia.com/cudnn): [Docker_image_with_CUDA10_cuDNN7](https://github.com/Desklop/Docker_image_with_CUDA10_cuDNN7).

**При сборке docker-образа** выполняется клонирование репозитория [**TensorFlow**](https://github.com/tensorflow/tensorflow), загрузка и установка [**Bazel v0.24.1**](https://github.com/bazelbuild/bazel/releases/tag/0.24.1) с помощью **скрипта** [**`install_bazel.sh`**](https://github.com/Desklop/building_tensorflow/blob/master/install_bazel.sh). Скрипт принимает версию Bazel в качестве аргумента, загружает её из официального [репозитория](https://github.com/bazelbuild/bazel) и выполняет установку (если не передавать аргумент - использовать значение `0.24.1`):

```bash
sudo ./install_bazel.sh 0.24.1
```

**Сборка TensorFlow** полностью **автоматизирована** с помощью скрипта [**`build.sh`**](https://github.com/Desklop/building_tensorflow/blob/master/build.sh), который принимает 2 необязательных аргумента при запуске:

```bash
sudo ./build.sh [-gpu] [-mkl]
```

Значения аргументов (если ничего не передавать - выполнить сборку только с поддержкой CPU, если передать оба аргумента - выполнить сборку с поддержкой GPU и Intel MKL):

- `-gpu`: выполнить сборку с поддержкой GPU
- `-mkl`: выполнить сборку с [Intel Math Kernel Library](https://software.intel.com/en-us/mkl)

**Скрипт** выполняет следующие **действия**:

- переключение на ветку `r1.15` в локальном репозитории TensorFlow
- исправление ошибок, которые могут возникнуть при сборке
- конфигурация сборки (вызов `./configure` с помощью скриптов [`run_configure_cpu_1.15`](https://github.com/Desklop/building_tensorflow/blob/master/run_configure_cpu_1.15)/[`run_configure_gpu_1.15`](https://github.com/Desklop/building_tensorflow/blob/master/run_configure_gpu_1.15))
- запуск сборки с параметрами под текущий CPU на хост-машине (вызов `bazel build --config=opt --copt=-march=native --noincompatible_strict_action_env //tensorflow/tools/pip_package:build_pip_package`, в зависимости от аргументов, переданных при запуске скрипта, может быть добавлено `--config=cuda` и/или `--config=mkl`)
- получение списка поддерживаемых инструкций CPU на хост-машине (данные берутся из файла `/proc/cpuinfo`) и, если передан аргумент `-gpu` при запуске скрипта, получение используемой версии CUDA (с помощью вызова `nvcc -V`)
- сборка Python пакета со списком поддерживаемых инструкций CPU и версией CUDA (если передан аргумент `-gpu` при запуске скрипта) в названии (вызов `./bazel-bin/tensorflow/tools/pip_package/build_pip_package ./built_packages --project_name tensorflow_[cpu|gpu]_[SUPPORTED_INSTRUCTIONS]_[CUDA_VERSION][_MKL][_XLA]`)

**ВНИМАНИЕ!** Для сборки **TensorFlow-GPU v1.15.2** необходимо сначала **подготовить хост машину!** Подготовка заключается в установке официального драйвера нужной версии для [NVIDIA GPU](https://www.nvidia.com/en-gb/graphics-cards/), установке [`nvidia-container-toolkit`](https://github.com/NVIDIA/nvidia-docker) и сборке базового docker-образа с [CUDA 10](https://developer.nvidia.com/cuda-zone) и [cuDNN 7.6](https://developer.nvidia.com/cudnn). Инструкцию и скрипты для подготовки можно найти в соседнем репозитории: [Docker_image_with_CUDA10_cuDNN7](https://github.com/Desklop/Docker_image_CUDA10_cuDNN7).

---

## Исправление ошибок при сборке TensorFlow

**При сборке TensorFlow** (т.е. при выполнении `bazel build ...`) по разным причинам **могут возникнуть** следующие **ошибки**:

1. Ошибка **`"/usr/bin/env: 'python': No such file or directory"`**.

Возникает вне зависимости от выбранных параметров сборки. Решение: добавление вызова python 3.7 по команде python. Исправление применяется при сборке docker-образа.

```bash
sudo update-alternatives --install /usr/bin/python python /usr/bin/python3.7 2
```

2. **Неподдерживаемая версия GCC** при сборке с поддержкой GPU.

Возникает из-за того, что сборка с поддержкой GPU требует GCC и G++ не выше 7 версии, а по умолчанию в Ubuntu 19.10 установлен GCC 9. Решение: установка GCC и G++ 7 версии. Исправление применяется при сборке docker-образа.

```bash
sudo apt-get install -y gcc-7 g++-7
sudo ln -s /usr/bin/gcc-7 /usr/local/cuda/bin/gcc
sudo ln -s /usr/bin/g++-7 /usr/local/cuda/bin/g++
```

3. Ошибка **`"fatbinary fatal : Unknown option '-bin2c-path'"`**.

Возникает из-за использования CUDA 10.2, которая по умолчанию не поддерживается TensorFlow-GPU v1.15.2.

Решение: применение коммита `"Make nccl bindings compilable with cuda 10.2"` из ветки `master` ([источник](https://github.com/tensorflow/tensorflow/issues/34429#issuecomment-574296455)). Исправление применяется скриптом `build.sh` после переключения на ветку `r1.15` в локальном репозитории TensorFlow.

```bash
git config user.email "example@mail.com"
git config user.name "Name"
git cherry-pick 67edc16326d6328e7ef096e1b06f81dae1bfb816
```

4. Ошибка с [gRPC](https://grpc.io/) **`"error: ambiguating new declaration of 'long int gettid()'"`**.

Возникает из-за того, что библиотека gRPC была обновлена и изменились имена функций с `gettid()` на `sys_gettid()` в файлах `src/core/lib/gpr/log_linux.cc`, `src/core/lib/gpr/log_posix.cc` и `src/core/lib/iomgr/ev_epollex_linux.cc`, что не предусмотрено в используемой версии bazel ([источник](https://github.com/clearlinux/distribution/issues/1151#issuecomment-580154128)).

Решение: применение патча [`Rename-gettid-functions.patch`](https://github.com/Desklop/building_tensorflow/blob/master/Rename-gettid-functions.patch), который изменяет имена функций на правильные (для применения патча используется другой патч [`Add-grpc-fix-for-gettid.patch`](https://github.com/Desklop/building_tensorflow/blob/master/Add-grpc-fix-for-gettid.patch), который указывает bazel, что после загрузки, но перед установкой gRPC необходимо применить патч). Исправление применяется скриптом `build.sh` после переключения на ветку `r1.15` в локальном репозитории TensorFlow и исправления ошибки в пункте 3 выше.

**Внимание:** данное исправление работает только с TensorFlow v1.15.2, 2.0.1 и 2.1.0. В остальных версиях работоспособность не гарантируется.

```bash
cp Add-grpc-fix-for-gettid.patch tensorflow
git apply Add-grpc-fix-for-gettid.patch
cp Rename-gettid-functions.patch tensorflow/third_party/Rename-gettid-functions.patch
```

---

## Сборка TensorFlow с поддержкой CPU

**Для сборки docker-образа**, находясь в папке с проектом, нужно **выполнить** (`-f Dockerfile_cpu_cp37` — использовать файл `Dockerfile_cpu_cp37` в качестве Dockerfile для сборки образа,`-t` — запуск в терминале, `.` — директория, из которой вызывается docker build (точка — значит в текущей директории находятся все файлы для образа), `building_tensorflow:1.15` — метка образа и его версия):

```bash
sudo docker build -f Dockerfile_cpu_cp37 -t building_tensorflow:1.15 .
```

После успешной сборки, можно **запустить полученный образ** в контейнере (`--cpuset-cpus="0-5"` — использовать только ядра с 0 по 5, `-m 16GB` — использовать не более 16Гб оперативной памяти, `-t` — запуск в терминале, `-i` — интерактивный режим, `--rm` — удалить контейнер после завершения его работы, `-v "$PWD:/building_tensorflow/built_packages"` — папка, из которой запускается образ, будет доступна в контейнере по адресу `/building_tensorflow/built_packages`, `-e HOST_PERMS="$(id -u):$(id -g)"` — перенос переменных окружения в контейнер (необходимо для корректной работы bazel)):

```bash
sudo docker run --cpuset-cpus="0-5" -m 16GB -ti --rm -v "$PWD:/building_tensorflow/built_packages" -e HOST_PERMS="$(id -u):$(id -g)" building_tensorflow:1.15
```

Если необходима поддержка Intel MKL-DNN, нужно при запуске контейнера в конец добавить `./build.sh -mkl`.

**При запуске контейнера** сразу же **начнётся сборка TensorFlow**. На машине с CPU Intel Xeon X5650 сборка **на всех 12 ядрах** занимает **около 1.5 часов**. При этом требуется **около 15Гб оперативной памяти** (при увеличении числа используемых ядер необходимо больше оперативной памяти, из рассчёта примерно 1-2Гб на 1 ядро).

**После завершения** сборки контейнер остановится и **в папке**, из которой он был запущен, **появится файл `tensorflow_cpu_[SUPPORTED_INSTRUCTIONS][_MKL][_XLA]-1.15.2-cp37-cp37m-linux_x86_64.whl`** (в случае CPU Intel Xeon X5650: `tensorflow_cpu_SSE4.1_SSE4.2_XLA-1.15.2-cp37-cp37m-linux_x86_64.whl`), оптимизированный под CPU на хост машине.

Для установки TensorFlow из полученного пакета можно использовать pip:

```bash
pip3 install tensorflow_cpu_SSE4.1_SSE4.2_XLA-1.15.2-cp37-cp37m-linux_x86_64.whl
```

**Примечание**: размер собранного docker-образа равен **1.5-1.7 Гб**.

---

## Сборка TensorFlow с поддержкой CPU и GPU

**ВНИМАНИЕ!** **Перед сборкой** и запуском сначала нужно **подготовить хост машину!** Инструкцию и скрипты для подготовки можно найти в [Docker_image_with_CUDA10_cuDNN7](https://github.com/Desklop/Docker_image_with_CUDA10_cuDNN7).

По умолчанию **в качестве базового образа используется образ с CUDA 10.2 и cuDNN 7.6**. Если необходима поддержка другой версии CUDA, нужно изменить имя базового образа во 2 строке файла [`Dockerfile_gpu_cp37`](https://github.com/Desklop/building_tensorflow/blob/master/Dockerfile_gpu_cp37) и предварительно собрать указанный базовый docker-образ (подробнее см. в [Docker_image_with_CUDA10_cuDNN7](https://github.com/Desklop/Docker_image_with_CUDA10_cuDNN7)).

**Для сборки docker-образа**, находясь в папке с проектом, нужно **выполнить**:

```bash
sudo docker build -f Dockerfile_gpu_cp37 -t building_tensorflow_gpu:1.15 .
```

После успешной сборки, можно **запустить полученный образ** в контейнере (`--gpus all` — предоставить доступ контейнеру ко всем имеющимся видеокартам):

```bash
sudo docker run --cpuset-cpus="0-5" -m 16GB --gpus all -ti --rm -v "$PWD:/building_tensorflow/built_packages" -e HOST_PERMS="$(id -u):$(id -g)" building_tensorflow_gpu:1.15
```

Если необходима поддержка Intel MKL-DNN, нужно при запуске контейнера в конец добавить `./build.sh -gpu -mkl`.

**При запуске контейнера** сразу же **начнётся сборка TensorFlow-GPU**. На машине с CPU Intel Xeon X5650 и GPU NVIDIA GeForce RTX2080 сборка **на всех 12 ядрах** занимает **около 2 часов**. При этом требуется **около 25Гб оперативной памяти** (при увеличении числа используемых ядер необходимо больше оперативной памяти, из рассчёта примерно 2-4Гб на 1 ядро).

**После завершения** сборки контейнер остановится и **в папке**, из которой он был запущен, **появится файл `tensorflow_gpu_[SUPPORTED_INSTRUCTIONS]_[CUDA_VERSION][_MKL][_XLA]-1.15.2-cp37-cp37m-linux_x86_64.whl`** (в случае CPU Intel Xeon X5650 и GPU NVIDIA GeForce RTX2080: `tensorflow_gpu_SSE4.1_SSE4.2_cuda10.0_XLA-1.15.2-cp37-cp37m-linux_x86_64.whl`), оптимизированный под CPU и GPU на хост машине.

Для установки TensorFlow-GPU из полученного пакета можно использовать pip:

```bash
pip3 install tensorflow_gpu_SSE4.1_SSE4.2_cuda10.0_XLA-1.15.2-cp37-cp37m-linux_x86_64.whl
```

**Примечание**: размер собранного docker-образа равен **4.5-5.3 Гб**.

---

## Дополнительные сведения

**Для успешной сборки нужен Bazel v0.24.1**, а для сборки с поддержкой GPU - **GCC и G++** не выше **7 версии**, и **CUDA 10.X с cuDNN 7.6**.

**Изменить параметры сборки** можно в скриптах [`run_configure_cpu_1.15`](https://github.com/Desklop/building_tensorflow/blob/master/run_configure_cpu_1.15) и [`run_configure_gpu_1.15`](https://github.com/Desklop/building_tensorflow/blob/master/run_configure_gpu_1.15) соответственно для CPU и GPU. Дополнительные параметры для сборщика bazel можно указать в скрипте [`build.sh`](https://github.com/Desklop/building_tensorflow/blob/master/build.sh#L54) в строке 45 или 54.

**Описание некоторых [аргументов](https://stackoverflow.com/questions/41293077/how-to-compile-tensorflow-with-sse4-2-and-avx-instructions) сборки** (их так же можно добавить как в `run_configure_cpu_1.15` (строка 32) или `run_configure_gpu_1.15` (строка 42), так и в `build.sh` (строка 45 или 54)):

- `-march=native` - использовать параметры текущего CPU (используется по умолчанию)
- `cuda` - выполнить сборку с поддержкой GPU под конкретную версию CUDA
- `libverbs` - для удалённого прямого доступа к памяти Remote Direct Memory Access (RDMA) (нужно перед установкой выполнить `sudo apt-get install libibverbs-dev`)
- `ngraph` - поддержка компилятора Intel nGraph (не работает ожидаемым образом, а сборка nGraph из исходников не дала ускорения работы, только замедление где-то в 1.5 раза, см. комментарии в строках 3-8 в `build.sh`)
- `gdr` - более крутая версия текущего протокола gRPC для распределённых вычислений на GPU (полезен когда размер тензора больше 100Мб и используется несколько видеокарт)
- `monolithic` - сборка без возможности создания своих операций (подробнее [тут](https://stackoverflow.com/questions/53705582/what-is-meant-by-static-monolithic-build-when-building-tensorflow-from-source))
- `mkl` - поддержка библиотеки Intel Math Kernel Library (со сборкой для GPU приводит к уменьшению производительности, в сборке для CPU не приводит к изменению производительности (нужны ещё тесты, подробнее [тут](https://github.com/tensorflow/tensorflow/issues/23238)) и доступно только в Linux) (также можно использовать через `pip3 install intel-tensorflow`, подробнее [тут](https://software.intel.com/en-us/articles/intel-optimization-for-tensorflow-installation-guide))

**Руководство по сборке вручную** находится в [`manual_build_order.md`](https://github.com/Desklop/building_tensorflow/blob/master/manual_build_order.md).

**Другие руководства по сборке:**

- [официальная инструкция](https://www.tensorflow.org/install/source) от разработчиков TensorFlow
- [Building TensorFlow from source (TF 2.1.0, Ubuntu 19.10)](https://gist.github.com/kmhofmann/e368a2ebba05f807fa1a90b3bf9a1e03)
- [tensorflow-community-wheels](https://github.com/yaroslavvb/tensorflow-community-wheels) (так же содержит множество собранных пакетов с различными параметрами от сообщества)

---

Если у вас возникнут вопросы или вы хотите сотрудничать, можете написать мне на почту: vladsklim@gmail.com или в [LinkedIn](https://www.linkedin.com/in/vladklim/).
