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

# Build and install OpenBLAS from source
RUN git clone https://github.com/xianyi/OpenBLAS /tmp/openblas
WORKDIR /tmp/openblas
RUN git checkout v0.3.3
RUN mkdir build
WORKDIR /tmp/openblas/build
RUN cmake -D CMAKE_INSTALL_PREFIX=/usr/local  \
          -D CMAKE_BUILD_TYPE=Release         \
          -D BUILD_SHARED_LIBS=ON             \
          -D BUILD_WITHOUT_LAPACK=OFF         \
          -D BUILD_WITHOUT_CBLAS=ON           \
          -D DYNAMIC_ARCH=ON                  \
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
RUN cmake --build . --target install

# Install polo C-API from source
RUN git clone https://github.com/pologrp/polo /tmp/polo
WORKDIR /tmp/polo
RUN mkdir build
WORKDIR /tmp/polo/build
RUN cmake -D CMAKE_INSTALL_PREFIX=${HOME}/usr/local \
          -D CMAKE_BUILD_TYPE=Release               \
          -D BUILD_SHARED_LIBS=ON                   \
          ../
RUN cmake --build . --target install

# Install POLO.jl and ParameterServer.jl
RUN julia --eval 'using Pkg; pkg"add https://github.com/pologrp/POLO.jl";'
RUN julia --eval 'using Pkg; pkg"add https://github.com/pologrp/ParameterServer.jl";'

# Assemble all the built and installed libraries together
FROM julia:1 AS final
COPY --from=binaries /usr/local /usr/local
COPY --from=binaries /root/usr/local /root/usr/local
COPY --from=binaries /root/.julia /root/.julia
RUN apt-get update
RUN apt-get install -y gcc gfortran git g++ make
RUN julia --eval 'using Pkg; pkg"build POLO ParameterServer"; pkg"precompile";'
