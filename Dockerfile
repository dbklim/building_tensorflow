# Для сборки TensorFlow-GPU вначале надо подготовить хост-машину! Подробнее в https://github.com/Desklop/Docker_image_CUDA10.0_cuDNN7.5
#FROM tensorflow/tensorflow:devel-gpu-py3
FROM tensorflow/tensorflow:devel-py3
MAINTAINER Vlad Klim 'vladsklim@gmail.com'

# Установка необходимых пакетов для Ubuntu
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -y
RUN apt-get install -y tzdata locales expect

# Установка часового пояса хост-машины
ENV TZ=Europe/Minsk
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
RUN dpkg-reconfigure -f noninteractive tzdata

# Копирование файлов проекта
COPY . /build_tensorflow
WORKDIR /build_tensorflow

# Загрузка исходных файлов TensorFlow
RUN git clone https://github.com/tensorflow/tensorflow.git

# Присваивание разрешения на выполнение
RUN chmod +x install_bazel.sh
RUN chmod +x build.sh

# Установка необходимой версии Bazel
RUN ./install_bazel.sh 0.21.0

# Копирование модифицированных скриптов
RUN cp run_configure_cpu_1.13.1 tensorflow/run_configure_cpu_1.13.1
RUN cp run_configure_gpu_1.13.1 tensorflow/run_configure_gpu_1.13.1
RUN chmod +x tensorflow/run_configure_cpu_1.13.1
RUN chmod +x tensorflow/run_configure_gpu_1.13.1

# Изменение локализации для вывода кириллицы в терминале
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Очистка кеша
RUN apt-get -y autoremove
RUN apt-get -y autoclean
RUN apt-get -y clean

#ENTRYPOINT ./run_rest_server.sh
#CMD ["./build.sh", "gpu", "mkl"]
#CMD ["./build.sh", "mkl"]
#CMD ["./build.sh", "gpu"]
CMD ["./build.sh"]