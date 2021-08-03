FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

# Install python3, swig, and MKL
RUN apt-get update
RUN apt-get install -y python3-dev python3-pip
RUN apt-get install -y swig
RUN apt-get install -y libmkl-dev

# Install recent CMake
RUN apt-get install -y wget
RUN wget -nv -O - https://github.com/Kitware/CMake/releases/download/v3.17.1/cmake-3.17.1-Linux-x86_64.tar.gz | tar xzf - --strip-components=1 -C /usr

# Install numpy/scipy/pytorch for python tests
RUN pip3 install numpy scipy torch

ENV OMP_NUM_THREADS=10
ENV MKL_THREADING_LAYER=GNU

# Copy the repo to the docker image
COPY . /faiss
WORKDIR /faiss

# Build
RUN cmake -B build \
    -DBUILD_TESTING=ON \
    -DFAISS_ENABLE_GPU=OFF \
    -DFAISS_OPT_LEVEL=avx2 \
    -DFAISS_ENABLE_C_API=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DBLA_VENDOR=Intel10_64_dyn .
RUN make -C build -j faiss

# Run cpp tests
RUN make -C build -j faiss_test
RUN make -C build -j test

# Build python tests
RUN make -C build -j swigfaiss
RUN cd build/faiss/python && python3 setup.py build
RUN cd build/faiss/python && python3 setup.py install

RUN pip3 install pytest

ENV PYTHONPATH=/faiss/build/faiss/python/build/lib/

RUN pytest tests/test_*.py
RUN pytest tests/torch_*.py
