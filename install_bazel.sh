#!/bin/bash

echo_help() {
    echo "Выполняет загрузку и установку указанной версии Bazel."
    echo "Использование: ./install_bazel.sh [-h|--help] [version]"
    echo "Пример:"
    echo "./install_bazel.sh 0.21.0"
    echo "./install_bazel.sh 0.24.1"
}

BAZEL_VERSION="0.24.1"

if [ -n "$1" ]; then
    case "$1" in
        -h) echo_help
            exit;;
        --help) echo_help
            exit;;
    esac
    
    if echo $1 | grep -c "[0-9]\{1,2\}\.[0-9]\{1,2\}\.[0-9]\{1,2\}" > /dev/null; then
        BAZEL_VERSION=$1
    else            
        echo "Некорректное значение version, введите -h или --help для помощи"
        exit
    fi
else
    echo_help
    exit
fi

if [ ! -f "bazel-${BAZEL_VERSION}-installer-linux-x86_64.sh" ]; then
    wget https://github.com/bazelbuild/bazel/releases/download/${BAZEL_VERSION}/bazel-${BAZEL_VERSION}-installer-linux-x86_64.sh
else            
    echo -e "Found: bazel-${BAZEL_VERSION}-installer-linux-x86_64.sh\n"
fi

chmod +x bazel-${BAZEL_VERSION}-installer-linux-x86_64.sh
./bazel-${BAZEL_VERSION}-installer-linux-x86_64.sh
echo "Done"