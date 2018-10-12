# Build and install CMake from source
FROM julia:1 AS cmake
RUN apt-get update
RUN apt-get install -y g++ make unzip wget
RUN wget -O cmake.zip https://gitlab.kitware.com/cmake/cmake/-/archive/v3.9.0/cmake-v3.9.0.zip
RUN unzip cmake.zip -d /tmp/
WORKDIR /tmp/cmake-v3.9.0
RUN ./configure --no-qt-gui
RUN make
RUN make install

# Build and install 0MQ from source
FROM julia:1 AS zmq
COPY --from=cmake /usr/local /usr/local
RUN apt-get update
RUN apt-get install -y git g++ make
RUN git clone https://github.com/zeromq/libzmq /tmp/libzmq
WORKDIR /tmp/libzmq
RUN git checkout -b install v4.2.5
RUN mkdir build
WORKDIR /tmp/libzmq/build
RUN cmake -D CMAKE_INSTALL_PREFIX=/usr/local  \
          -D CMAKE_BUILD_TYPE=Release         \
          -D ENABLE_DRAFTS=OFF                \
          -D ENABLE_CURVE=OFF                 \
          -D BUILD_TESTS=OFF                  \
          -D BUILD_SHARED=ON                  \
          -D BUILD_STATIC=ON                  \
          -D WITH_OPENPGM=OFF                 \
          -D WITH_DOC=OFF                     \
          -D LIBZMQ_WERROR=ON                 \
          -D LIBZMQ_PEDANTIC=ON               \
          ../
RUN cmake --build .
RUN cmake --build . --target install

# Build and install reference LAPACK from source
FROM julia:1 AS lapack
COPY --from=zmq /usr/local /usr/local
RUN apt-get update
RUN apt-get install -y git gfortran g++ make
RUN git clone https://github.com/Reference-LAPACK/lapack-release /tmp/lapack
WORKDIR /tmp/lapack
RUN git checkout -b install lapack-3.8.0
RUN mkdir build
WORKDIR /tmp/lapack/build
RUN cmake -D CMAKE_INSTALL_PREFIX=/usr/local  \
          -D CMAKE_BUILD_TYPE=Release         \
          -D BUILD_SHARED_LIBS=ON             \
          -D BUILD_COMPLEX=OFF                \
          -D BUILD_COMPLEX16=OFF              \
          -D BUILD_TESTING=OFF                \
          ../
RUN cmake --build .
RUN cmake --build . --target install

# Install cereal from source
FROM julia:1 AS cereal
COPY --from=lapack /usr/local /usr/local
RUN apt-get update
RUN apt-get install -y git g++ make
RUN git clone https://github.com/USCiLab/cereal /tmp/cereal
WORKDIR /tmp/cereal
RUN git checkout -b install v1.2.2
RUN mkdir build
WORKDIR /tmp/cereal/build
RUN cmake -D CMAKE_INSTALL_PREFIX=/usr/local  \
          -D JUST_INSTALL_CEREAL=ON           \
          ../
RUN cmake --build .
RUN cmake --build . --target install

# Assemble all the built and installed libraries together
FROM julia:1 AS final
COPY --from=cereal /usr/local /usr/local
RUN apt-get update
RUN apt-get install -y gcc gfortran git g++ make
