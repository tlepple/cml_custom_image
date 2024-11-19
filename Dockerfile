# Copyright 2024 Cloudera. All Rights Reserved.
FROM ubuntu:20.04

# Create user and group
RUN addgroup --gid 8536 cdsw && \
    adduser --disabled-password --gecos "CDSW User" --uid 8536 --gid 8536 cdsw

# Fix permissions
RUN for dir in /etc /etc/alternatives /bin /opt /sbin /usr; do \
      if [ -d "$dir" ]; then \
          chmod 777 "$dir" && \
          chown cdsw "$dir" && \
          find "$dir" -type d -exec chown cdsw {} +; \
      fi; \
    done && \
    chown cdsw /

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    LC_ALL=en_US.UTF-8 LANG=C.UTF-8 LANGUAGE=en_US.UTF-8 \
    TERM=xterm \
    PATH="/home/cdsw/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/conda/bin" \
    SHELL=/bin/bash \
    HADOOP_ROOT_LOGGER=WARN,console

# Install essential packages
RUN apt-get update && apt-get dist-upgrade -y && \
    apt-get install -y --no-install-recommends \
      locales apt-transport-https krb5-user xz-utils git ssh unzip gzip \
      curl nano emacs-nox wget ca-certificates zlib1g-dev libbz2-dev \
      liblzma-dev libssl-dev libsasl2-dev libsasl2-2 \
      libsasl2-modules-gssapi-mit libzmq3-dev cpio cmake make \
      libgl-dev libjpeg-dev libpng-dev ffmpeg fonts-roboto \
      fonts-dejavu libsqlite3-0 mime-support libpq-dev gcc g++ \
      libkrb5-dev unixodbc-dev software-properties-common && \
    apt-get clean && apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen

# Install Git LFS
RUN wget https://packagecloud.io/github/git-lfs/packages/ubuntu/focal/git-lfs_3.5.1_amd64.deb/download.deb?distro_version_id=210 -O git-lfs.deb && \
    echo "9eb957a155c088bfe68f4fcf051896d8321c5bc255f3dadea8f42ad8903bf22ef1803583f175a5d55fe68d359779ed1b566e7a86c77d91c272196ee50cc913fc  git-lfs.deb" | sha512sum -c - && \
    dpkg -i git-lfs.deb && \
    rm git-lfs.deb

# Create symlinks for certificates
RUN mkdir -p /etc/pki/tls/certs && \
    ln -s /etc/ssl/certs/ca-certificates.crt /etc/pki/tls/certs/ca-bundle.crt && \
    ln -s /usr/lib/x86_64-linux-gnu/libsasl2.so.2 /usr/lib/x86_64-linux-gnu/libsasl2.so.3

# Add Python runtime and requirements
ENV PYTHON3_VERSION=3.10.14 \
    ML_RUNTIME_KERNEL="Python 3.10"

#create the build directory
RUN mkdir -p /build

# Add additional files
COPY cloudera.mplstyle /etc/cloudera.mplstyle
COPY requirements.txt /build/requirements.txt
ADD python-prebuilt-3.10.14-20240911-pkg.tar.gz /usr/local
COPY pip.conf /etc/pip.conf


RUN ldconfig && \
    pip3 config set install.user false && \
    pip3 install --no-cache-dir --no-warn-script-location -r /build/requirements.txt && \
    rm -rf /build

# Install SQL Server ODBC and pyodbc

# Install required tools and add Microsoft repository
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl gpg && \
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/ubuntu/20.04/prod focal main" > /etc/apt/sources.list.d/msprod.list && \
    apt-get update && ACCEPT_EULA=Y apt-get install -y msodbcsql18 mssql-tools18 unixodbc-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Instll pyodbc
RUN pip install pyodbc


# Install Python requirements
#RUN pip3 install --no-cache-dir --no-warn-script-location -r /build/requirements.txt && \
#    rm -rf /build

# Environment variables for ML Runtime
ENV ML_RUNTIME_EDITOR="PBJ Workbench" \
    ML_RUNTIME_METADATA_VERSION=2 \
    ML_RUNTIME_EDITION="ODBC-Tim" \
    ML_RUNTIME_SHORT_VERSION="1.1" \
    ML_RUNTIME_MAINTENANCE_VERSION=1 \
    ML_RUNTIME_JUPYTER_KERNEL_NAME="python3" \
    ML_RUNTIME_DESCRIPTION="This runtime includes telnet, ODBC, and sklearn with upgraded packages" \
    ML_RUNTIME_FULL_VERSION="1.1.1"

LABEL \
    com.cloudera.ml.runtime.runtime-metadata-version=$ML_RUNTIME_METADATA_VERSION \
    com.cloudera.ml.runtime.editor=$ML_RUNTIME_EDITOR \
    com.cloudera.ml.runtime.edition=$ML_RUNTIME_EDITION \
    com.cloudera.ml.runtime.description=$ML_RUNTIME_DESCRIPTION \
    com.cloudera.ml.runtime.kernel=$ML_RUNTIME_KERNEL \
    com.cloudera.ml.runtime.full-version=$ML_RUNTIME_FULL_VERSION \
    com.cloudera.ml.runtime.short-version=$ML_RUNTIME_SHORT_VERSION \
    com.cloudera.ml.runtime.maintenance-version=$ML_RUNTIME_MAINTENANCE_VERSION

WORKDIR /home/cdsw
