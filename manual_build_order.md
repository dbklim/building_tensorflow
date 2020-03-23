# Сборка TensorFlow v1.15.2 вручную из исходников

**Порядок сборки:**

1. Загрузить образ с Ubuntu 19.10, для поддержки GPU так же нужно установить актуальный драйвер для видеокарты nvidia и желаемую версию `CUDA` и `cuDNN`
2. Установить зависимости для Ubuntu (для сборки с поддержкой GPU так же нужны `gcc-7 g++-7`):

```bash
sudo apt-get update
sudo apt-get install -y python3.7 python3.7-dev python3-pip tzdata locales expect git wget unzip
```

3. Установка зависимостей для Python 3:

```bash
sudo pip3 install six==1.12.0 numpy==1.18.1 wheel==0.32.3 setuptools==41.1.0 mock==4.0.1 future==0.18.2
sudo pip3 install keras_applications==1.0.8 keras_preprocessing==1.1.0 --no-deps
```

4. Добавления вызова python 3.7 по команде python, без этого сборка может упасть с ошибкой `"/usr/bin/env: 'python': No such file or directory"`:

```bash
sudo update-alternatives --install /usr/bin/python python /usr/bin/python3.7 2
```

5. Для поддержки GPU: добавление ссылок на `gcc` и `g++` 7 версии (по умолчанию в Ubuntu 19.10 установлен `gcc-9`):

```bash
sudo ln -s /usr/bin/gcc-7 /usr/local/cuda/bin/gcc
sudo ln -s /usr/bin/g++-7 /usr/local/cuda/bin/g++
```

6. Установка Bazel v0.24.1:

```bash
wget https://github.com/bazelbuild/bazel/releases/download/0.24.1/bazel-0.24.1-installer-linux-x86_64.sh
chmod +x bazel-0.24.1-installer-linux-x86_64.sh
sudo ./bazel-0.24.1-installer-linux-x86_64.sh
bazel version
```

7. Загрузка репозитория TensorFlow:

```bash
git clone https://github.com/tensorflow/tensorflow.git
cd tensorflow
git checkout r1.15
```

8. Исправление ошибки `"fatbinary fatal : Unknown option '-bin2c-path'"` путём применения коммита `"Make nccl bindings compilable with cuda 10.2"` из `master`. Ошибка возникает из-за использования `CUDA 10.2`, которая по умолчанию не поддерживается TensorFlow ([источник](https://github.com/tensorflow/tensorflow/issues/34429#issuecomment-574296455)):

```bash
git config user.email "example@mail.com"
git config user.name "Name"
git cherry-pick 67edc16326d6328e7ef096e1b06f81dae1bfb816
```

9. Исправление ошибки с [`gRPC`](https://grpc.io/) `"error: ambiguating new declaration of 'long int gettid()'"` путём применения патча из ишью на гитхабе. Ошибка возникает из-за того, что недавно библиотека `gRPC` была обновлена, изменились имена функций с `gettid()` на `sys_gettid()` в файлах `src/core/lib/gpr/log_linux.cc`, `src/core/lib/gpr/log_posix.cc` и `src/core/lib/iomgr/ev_epollex_linux.cc`, но из-за старой версии, bazel это не учитывает ([источник](https://github.com/clearlinux/distribution/issues/1151#issuecomment-580154128)). Исправление так же должно работать с версиями `2.0.1` и `2.1.0`. Перед применением необходимо загрузить из данного репозитория файлы [`Rename-gettid-functions.patch`](https://github.com/Desklop/building_tensorflow/blob/master/Rename-gettid-functions.patch) и [`Add-grpc-fix-for-gettid.patch`](https://github.com/Desklop/building_tensorflow/blob/master/Add-grpc-fix-for-gettid.patch) в папку `tensorflow`:

```bash
git apply Add-grpc-fix-for-gettid.patch
cp Rename-gettid-functions.patch tensorflow/third_party/Rename-gettid-functions.patch
```

10. Конфигурация сборки:

```bash
./configure
```

11. Сборка TensorFlow (самый долгий этап, в зависимости от железа длится от 1 до 8-10 часов), для поддержки GPU нужно добавить `"--config=cuda"` (некоторые возможные аргументы сборки можно посмотреть в README.md в подразделе "Дополнительные сведения"):

```bash
bazel build --config=opt --copt=-march=native --noincompatible_strict_action_env //tensorflow/tools/pip_package:build_pip_package
```

12. Сборка пакета для Python, полученный `*.whl` файл будет помещён в папку `built_packages`:

```bash
./bazel-bin/tensorflow/tools/pip_package/build_pip_package built_packages --project_name "tensorflow-cpu-custom-build1"
```

**Готово.** С вероятностью 99% полученный пакет будет успешно работать как минимум на той же машине, на которой выполнялась сборка **:)**
