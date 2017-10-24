#!/bin/bash

function update_curl50() {
    local build_dir=/tmp/curl
    apt-get build-dep curl

    # Get latest (as of Feb 25, 2016) libcurl
    mkdir $build_dir
    cd $build_dir
    wget http://curl.haxx.se/download/curl-7.50.2.tar.bz2
    tar -xvjf curl-7.50.2.tar.bz2
    cd curl-7.50.2

    # The usual steps for building an app from source
    # ./configure
    # ./make
    # sudo make install
    ./configure
    make
    make install

    # Resolve any issues of C-level lib
    # location caches ("shared library cache")
    ldconfig

    rm -rf $build_dir
}

function install_base_requirements() {
    echo "Setting Timezone & Locale to Etc/UTC & C.UTF-8"

    ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime
    locale-gen C.UTF-8 || true
    update-locale LANG=en_US.UTF-8
    export LANG=C.UTF-8

    echo "export LANG=C.UTF-8" > ${CIRCLECI_HOME}/.bashrc

    echo ">>> Make Apt non interactive"

    echo 'force-confnew' >> /etc/dpkg/dpkg.cfg

    (cat <<'EOF'
// the /etc/apt/apt.conf file for the slave AMI

// Auto "-y" for apt-get
APT {
  Get {
    Assume-Yes "true";
    force-yes "true";
  };
};

// Disable HTTP pipelining, S3 doesn't support it properly.
Acquire {
  http {
    Pipeline-Depth 0;
  }
}

// Don't ask to update
DPkg {
  Options {
    "--force-confnew";
  };
};
EOF
) > /etc/apt/apt.conf

    echo 'Defaults    env_keep += "DEBIAN_FRONTEND"' >> /etc/sudoers.d/env_keep
    export DEBIAN_FRONTEND=noninteractive

    apt-get update -y
    apt-get install -y software-properties-common
    apt-add-repository ppa:git-core/ppa
    apt-get update -y


    # Install base packages
    apt-get install $(tr '\n' ' ' <<EOS
autoconf
bsdtar
build-essential
cmake
curl
ca-certificates
libssl1.0.0
dpkg-repack
gfortran
git
imagemagick
libav-tools
libicu-dev
liblapack-dev
lzop
make
mercurial
parallel
protobuf-compiler
sysv-rc-conf
unzip
zip
EOS
)

    # Update to the version where recent (as of Oct 2017) vulnerabilities were fixed
    update_curl50

    # For tests
    git clone https://github.com/sstephenson/bats.git && cd bats && ./install.sh /usr/local
}
