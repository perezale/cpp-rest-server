FROM alpine:3.8 as compiler

RUN echo -e '@edgunity http://nl.alpinelinux.org/alpine/edge/community\n\
@edge http://nl.alpinelinux.org/alpine/edge/main\n\
@testing http://nl.alpinelinux.org/alpine/edge/testing\n\
@community http://dl-cdn.alpinelinux.org/alpine/edge/community' \
>> /etc/apk/repositories

# --no-cache
RUN apk add --update \
      build-base \
      openblas-dev \
      unzip \
      wget \     
      cmake \
      g++ \
      libjpeg  \
      libjpeg-turbo-dev \
      libpng-dev \
      jasper-dev \
      tiff-dev \
      libwebp-dev \
      clang-dev \
      linux-headers

ENV CC /usr/bin/clang
ENV CXX /usr/bin/g++
ENV OPENCV_VERSION='3.4.10' DEBIAN_FRONTEND=noninteractive

RUN mkdir /opt && cd /opt && \
  wget https://github.com/opencv/opencv/archive/${OPENCV_VERSION}.zip && \
  unzip ${OPENCV_VERSION}.zip && \
  rm -rf ${OPENCV_VERSION}.zip

RUN  cd /opt && \
  wget https://github.com/opencv/opencv_contrib/archive/${OPENCV_VERSION}.zip && \
  unzip ${OPENCV_VERSION}.zip && \
  rm -rf ${OPENCV_VERSION}.zip

RUN mkdir -p /opt/opencv-${OPENCV_VERSION}/build && \
  cd /opt/opencv-${OPENCV_VERSION}/build && \
  cmake \
    -D BUILD_DOCS=OFF \
    -D BUILD_EXAMPLES=OFF \
    -D BUILD_opencv_apps=OFF \
    -D BUILD_opencv_python2=OFF \
    -D BUILD_opencv_python3=OFF \
    -D BUILD_PERF_TESTS=OFF \
    -D BUILD_SHARED_LIBS=OFF \ 
    -D BUILD_TESTS=OFF \
    -D CMAKE_BUILD_TYPE=RELEASE \
    -D ENABLE_PRECOMPILED_HEADERS=OFF \
    -D FORCE_VTK=OFF \
    -D WITH_FFMPEG=ON \
    -D WITH_GDAL=OFF \ 
    -D WITH_IPP=OFF \
    -D WITH_OPENEXR=OFF \
    -D WITH_OPENGL=OFF \ 
    -D WITH_QT=OFF \
    -D WITH_TBB=OFF \ 
    -D WITH_XINE=OFF \ 
    -D BUILD_JPEG=ON  \
    -D BUILD_TIFF=ON \
    -D BUILD_PNG=ON \
    -D OPENCV_EXTRA_MODULES_PATH=../../opencv_contrib-${OPENCV_VERSION}/modules \
    -D OPENCV_ENABLE_NONFREE=ON \
  .. && \
  make -j$(nproc) && \
  make install && \
  rm -rf /opt/opencv-${OPENCV_VERSION} && \
  rm -rf /opt/opencv_contrib-${OPENCV_VERSION}

RUN wget --progress=dot:giga https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.0.0-linux-x86-64.tar.gz && \
    pwd && \
    tar -xzf libwebp-1.0.0-linux-x86-64.tar.gz && \
    mv /libwebp-1.0.0-linux-x86-64/lib/libwebp.a /usr/lib && \
    rm -rf /libwebp*

RUN wget --progress=dot:giga http://www.ece.uvic.ca/~frodo/jasper/software/jasper-2.0.10.tar.gz && \
    tar -xzf jasper-2.0.10.tar.gz && \
    cd jasper-2.0.10 && \
    mkdir BUILD && \
    cd BUILD && \
    cmake -DCMAKE_INSTALL_PREFIX=/usr    \
      -DCMAKE_BUILD_TYPE=Release     \
      -DCMAKE_SKIP_INSTALL_RPATH=YES \
      -DCMAKE_INSTALL_DOCDIR=/usr/share/doc/jasper-2.0.10 \
      -DJAS_ENABLE_SHARED=FALSE \
      ..  && \
    make install && \
    rm -rf /jasper-2.0.10*

    # lib cpprestsdk build dependencies

RUN apk add --update \
    git \
    boost-dev \
    websocket++ \
    libressl-dev \
    ninja


RUN git clone https://github.com/Microsoft/cpprestsdk.git casablanca \
  && cd casablanca \
  && mkdir build.release \
  && cd build.release \
  && cmake -G Ninja .. -DBUILD_SHARED_LIBS=0 -DCMAKE_BUILD_TYPE=Release \
  && ninja \
  && ninja install

RUN apk add --update \
    curl-dev \
    && rm -rf /var/cache/apk/*

RUN wget https://github.com/nghttp2/nghttp2/releases/download/v1.41.0/nghttp2-1.41.0.tar.bz2 &&\
    pwd && \
    tar -xf nghttp2-1.41.0.tar.bz2 && \
    cd nghttp2-1.41.0 && \
    ./configure --enable-static && \
    make curl_LDFLAGS=-all-static V=1 && \
    make curl_LDFLAGS=-all-static install V=1 && \
    rm -rf /nghttp2*

# RUN git clone https://github.com/curl/curl.git \
#   && cd curl \
#   && ./configure --prefix='/' \
#   --enable-utp \
#   --with-inotify \
#   --enable-cli \
#   LIBCURL_LIBS="$(pkg-config --libs --static libcurl)" \
#   && make -j$(nproc) LDFLAGS="-all-static" DESTDIR=/tmp
 


ENV PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig:/usr/lib/pkgconfig

WORKDIR /src

COPY CMakeLists.txt /tmp

COPY main2.cpp /tmp
COPY /header /tmp/header
COPY /source /tmp/source
COPY /resources /tmp/resources



RUN cd /tmp && \
 g++ -g -Wl,-Bstatic -static-libgcc  -std=c++11 \   
	main2.cpp \
    	$(ls header/*) \
	$(ls source/*) \
	-o /tmp/app \
	$(pkg-config --cflags --libs -static opencv) \
  $(pkg-config --cflags --libs --static libcurl) \
	-lgfortran -lquadmath \
    	-lboost_system -lcpprest -lssl -lcrypto -lz

# g++ -g -Wl,-Bstatic -static-libgcc -std=c++11 main2.cpp $(ls header/*) $(ls source/*)  -o /tmp/app  $(pkg-config --cflags --libs -static opencv) -lgfortran -lquadmath -lboost_system -lcpprest -lssl -lcrypto -lz

## SOLO CPP REST
# RUN cd /tmp && g++ -g -Wl,-Bstatic -static-libgcc -std=c++11 main2.cpp -o /tmp/app $(pkg-config --cflags --libs -static opencv) -lgfortran -lquadmath -lboost_system -lcpprest -lssl -lcrypto -lz


# CMAKE BUILD
#RUN cd /tmp && mkdir build && cd build && cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Debug .. && make && mv opencvDemo ../app

FROM alpine    
WORKDIR /app
COPY ./resources ./resources
COPY --from=compiler /tmp/app ./app

EXPOSE 8080

STOPSIGNAL SIGTERM
#Defino el programa que se ejecutará al iniciar el contenedor
ENTRYPOINT ["/app/app"]
