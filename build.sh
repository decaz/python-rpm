#!/bin/bash
set -eux

yum update -y
yum install -y \
	wget \
	make \
	gcc-c++ \
	expat-devel \
	libffi-devel \
	gdbm-devel \
	libuuid-devel \
	ncurses-devel \
	openssl-devel \
	readline-devel \
	sqlite-devel \
	tk-devel \
	xz-devel \
	bzip2-devel \
	valgrind-devel \
	systemtap-sdt-devel \
	rpm-build \
	ruby-devel

# Install FPM
gem install --no-ri --no-rdoc fpm

IFS=. read MAJOR MINOR MICRO <<EOF
${PYTHON_VERSION}
EOF

# Download and verify sources
wget -O python.tar.xz "https://python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-${PYTHON_VERSION}.tar.xz"
wget -O python.tar.xz.asc "https://python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-${PYTHON_VERSION}.tar.xz.asc"
export GNUPGHOME="$(mktemp -d)"
gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "$GPG_KEY"
gpg --batch --verify python.tar.xz.asc python.tar.xz
mkdir -p ${BUILD_DIR}
tar -xJC ${BUILD_DIR} --strip-components=1 -f python.tar.xz

# Build sources
cd ${BUILD_DIR}
./configure \
	--enable-shared \
	--enable-loadable-sqlite-extensions \
	--enable-ipv6 \
	--with-system-expat \
	--with-system-ffi \
	--with-dbmliborder=gdbm:ndbm:bdb \
	--with-valgrind \
	--with-dtrace \
	--without-ensurepip
make -j $(($(nproc) + 1))
make test
make install DESTDIR=/tmp/installdir

# Remove tests and cache
rm -r /tmp/installdir/usr/local/lib/python${MAJOR}.${MINOR}/test
find -L /tmp/installdir -type d -name __pycache__ -prune -exec rm -rf {} \;

# Configure Dynamic Linker Run Time Bindings after installation
echo "echo /usr/local/lib > /etc/ld.so.conf.d/usr-local-lib.conf" > /tmp/installdir/run-ldconfig.sh
echo ldconfig >> /tmp/installdir/run-ldconfig.sh

# Build RPM
fpm \
	-t rpm \
	-s dir \
	-C /tmp/installdir \
	-n python${MAJOR}${MINOR} \
	-v ${PYTHON_VERSION} \
	-d "expat" \
	-d "libffi" \
	-d "gdbm" \
	-d "libuuid" \
	-d "ncurses" \
	-d "openssl" \
	-d "readline" \
	-d "sqlite" \
	-d "tk" \
	-d "xz" \
	-d "bzip2" \
	--directories /usr/local/lib/python${MAJOR}.${MINOR}/ \
	--directories /usr/local/include/python${MAJOR}.${MINOR}/ \
	--after-install /tmp/installdir/run-ldconfig.sh \
	usr/local
