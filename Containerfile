
FROM registry.opensuse.org/opensuse/leap:15.6

LABEL maintainer="nerett"

RUN zypper --non-interactive refresh && \
    zypper --non-interactive install \
    curl \
    git \
    gzip \
    tar \
    python311 \
    python311-pip \
    java-11-openjdk-headless \
    which \
    sudo

RUN zypper ar --refresh https://download.opensuse.org/repositories/devel:/tools:/building/15.6/ devel_tools_building && \
    zypper ar --refresh https://download.opensuse.org/repositories/devel:/tools:/compiler/15.6/ devel_tools_compiler && \
    zypper --non-interactive --gpg-auto-import-keys refresh

RUN zypper --non-interactive install --no-recommends \
    cmake \
    ninja \
    make \
    binutils \
    gcc13-c++ \
    llvm20 \
    llvm20-devel \
    clang20 \
    clang20-devel \
    libLTO20

RUN curl https://storage.googleapis.com/git-repo-downloads/repo > /usr/local/bin/repo && \
    chmod a+x /usr/local/bin/repo

RUN pip3.11 install lit>=17.0.0 requests>=2.28.0 rich>=12.0.0

WORKDIR /project

CMD ["/bin/bash"]
