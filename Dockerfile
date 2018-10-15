# Install the necessary tools to build the binaries from source
FROM julia:1 AS binaries
RUN apt-get update
RUN apt-get install -y gcc gfortran git g++ make unzip wget

# Build and install CMake from source
RUN wget -O cmake.zip https://gitlab.kitware.com/cmake/cmake/-/archive/v3.9.0/cmake-v3.9.0.zip
RUN unzip cmake.zip -d /tmp/
WORKDIR /tmp/cmake-v3.9.0
RUN ./configure --no-qt-gui
RUN make
RUN make install

# Build and install 0MQ from source
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
          -D LIBZMQ_WERROR=OFF                \
          -D LIBZMQ_PEDANTIC=OFF              \
          ../
RUN cmake --build .
RUN cmake --build . --target install

# Build and install reference LAPACK from source
RUN git clone https://github.com/Reference-LAPACK/lapack-release /tmp/lapack
WORKDIR /tmp/lapack
RUN git checkout -b install lapack-3.8.0
RUN mkdir build
WORKDIR /tmp/lapack/build
RUN cmake -D CMAKE_INSTALL_PREFIX=/usr/local  \
          -D CMAKE_BUILD_TYPE=Release         \
          -D BUILD_SHARED_LIBS=ON             \
          -D BUILD_TESTING=OFF                \
          ../
RUN cmake --build .
RUN cmake --build . --target install

# Install cereal from source
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

# Install polo C-API from source
RUN git clone https://github.com/pologrp/polo /tmp/polo
WORKDIR /tmp/polo
RUN git checkout -b install
RUN mkdir build
WORKDIR /tmp/polo/build
RUN cmake -D CMAKE_INSTALL_PREFIX=/usr/local  \
          -D CMAKE_BUILD_TYPE=Release         \
          -D BUILD_SHARED_LIBS=ON             \
          ../
RUN cmake --build .
RUN cmake --build . --target install

# Assemble all the built and installed libraries together
FROM julia:1 AS final
COPY --from=binaries /usr/local /usr/local
RUN apt-get update
RUN apt-get install -y gcc gfortran git g++ make
RUN julia --eval 'using Pkg; pkg"add https://github.com/pologrp/POLO.jl"'
