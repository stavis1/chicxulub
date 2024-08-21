FROM nathanhess/slurm:full

# Run installation as root
USER root

# Make bash the default shell
RUN ln -sf /bin/bash /bin/sh

# Install singularity-ce
RUN wget https://github.com/sylabs/singularity/releases/download/v4.1.5/singularity-ce_4.1.5-jammy_amd64.deb && \
    apt-get update && \
    apt-get install -y ./singularity-ce_4.1.5-jammy_amd64.deb

# Set standard user as default
USER docker

# Install nextflow
RUN curl -s https://get.sdkman.io | bash && \
    source "/home/docker/.sdkman/bin/sdkman-init.sh" && \
    sdk install java 17.0.10-tem && \
    curl -s https://get.nextflow.io | bash && \
    chmod +x nextflow && \
    ./nextflow self-update

#make nextflow available in $PATH
USER root
RUN mv nextflow /usr/local/bin
USER docker

# Install conda
RUN wget -O Miniforge3.sh "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh" && \
    bash Miniforge3.sh -b -p "${HOME}/conda" && \
    conda/bin/conda init

# Download git repo
RUN git clone https://github.com/stavis1/proteomics_cluster_submission
