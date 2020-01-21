FROM williamyeh/ansible:ubuntu18.04-onbuild

RUN apt-get update && apt-get install -y \
  # Needed locally for brianshumate.nomad role.
  python3 \
  # Needed to install netaddr, etc.
  python-pip

RUN pip install netaddr

RUN ansible-galaxy install brianshumate.nomad

# Install the terraform binary
RUN apt-get update && apt-get install -y unzip wget && \
  wget https://releases.hashicorp.com/terraform/0.12.13/terraform_0.12.13_linux_amd64.zip && \
  unzip terraform_0.12.13_linux_amd64.zip && \
  mv terraform /usr/local/bin/terraform && \
  rm terraform_0.12.13_linux_amd64.zip

# Install mitogen, an ansible plugin used for speedup.
RUN wget https://networkgenomics.com/try/mitogen-0.2.9.tar.gz && \
  tar -xf mitogen-0.2.9.tar.gz && \
  rm mitogen-0.2.9.tar.gz && \
  mv mitogen-0.2.9 /usr/lib/
