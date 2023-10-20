# ARG BASE_IMAGE=accetto/ubuntu-vnc-xfce-firefox-g3
ARG BASE_IMAGE=accetto/ubuntu-vnc-xfce-chromium-g3
ARG BASE_IMAGE_TAG=latest
FROM $BASE_IMAGE:$BASE_IMAGE_TAG

## install CUDA from nvidia repo
ARG DISTRO=ubuntu2204
ARG ARCH=x86_64
ARG CUDA_KEYRING="cuda-keyring_1.1-1_all.deb"
ARG NVIDIA_REPOS="https://developer.download.nvidia.com/compute/cuda/repos"
ARG CUDA_KEYRING_URL="$NVIDIA_REPOS/$DISTRO/$ARCH/$CUDA_KEYRING"

ENV HEADLESS_USER_ID=30000
ENV HEADLESS_USER_GROUP_ID=1136

USER root

### add 'index.html' for running vnc.html
RUN echo \
"<html>\n\
<head>\n\
  <meta http-equiv=\"refresh\" content=\"0; URL=vnc.html?password=headless&autoconnect=1&resize=remote&path=%NB_PREFIX%/webSockify\" />\n\
</head>\n\
<body>\n\
  <p>If you see this <a href=\"vnc.html?autoconnect=1&resize=remote\">click here</a>.</p>\n\
</body>\n\
</html>\n\
" > "${NOVNC_HOME}"/index.html

WORKDIR /tmp
RUN wget $CUDA_KEYRING_URL && \
  dpkg -i $CUDA_KEYRING && rm -f $CUDA_KEYRING && \
  apt-get update && apt-get install -y cuda-toolkit-12-2
ENV PATH="$PATH:/usr/local/cuda-12.2/bin"
## install dependencies for Slicer and a good text editor
RUN apt-get update && apt-get install -y libglu1-mesa-dev libnss3 libpulse-dev libxcb-xinerama0 qtbase5-dev vim xvfb

# Change UID/GID for headless user for HeLx purposes.
RUN groupmod -g "$HEADLESS_USER_GROUP_ID" "$HEADLESS_USER_GROUP_NAME" && \
    usermod -u "$HEADLESS_USER_ID" -g "$HEADLESS_USER_GROUP_ID" "$HEADLESS_USER_NAME"
RUN chmod 666 /etc/passwd /etc/group
# Remove .initial_sudo_password to get rid of using sudo.
RUN rm -f "${STARTUPDIR}"/.initial_sudo_password
RUN chown -R $HEADLESS_USER_ID:$HEADLESS_USER_GROUP_ID $STARTUPDIR $HOME
RUN chmod 666 /etc/passwd /etc/group

## Install Slicer
# https://download.slicer.org/

# Download Slicer and extract without any changes.
# Slicer Preview Release 5.5.0
ARG SLICER_DOWNLOAD_URL=https://download.slicer.org/bitstream/64e43b5e24417468602a0fa6
#
WORKDIR /app
RUN wget $SLICER_DOWNLOAD_URL -O slicer.tar.gz && \
  mkdir slicer && tar -xf slicer.tar.gz -C slicer --strip-components 1 && \
  rm -f slicer.tar.gz && \
  chown -R $HEADLESS_USER_ID:$HEADLESS_USER_GROUP_ID /app/slicer && \
  ln -s /app/slicer/Slicer /usr/local/bin/slicer

ARG WEIGHTS_URL=https://zenodo.org/record/6802052/files/Task256_TotalSegmentator_3mm_1139subj.zip?download=1

RUN apt-get update && apt-get install -y unzip && wget ${WEIGHTS_URL}  -O TotalSegmentatorWeights.zip && mkdir "/home/$HEADLESS_USER_NAME/.totalsegmentator"

# Install slicer extensions (defined in config.env)
ARG SLICER_EXTS
COPY install-slicer-extension.py /tmp
COPY install-pytorch-in-slicer.py /tmp
RUN \
for ext in ${SLICER_EXTS} ; \
do echo "Installing ${ext}" ; \
  EXTENSION_TO_INSTALL=${ext} \
  xvfb-run --auto-servernum /app/slicer/Slicer --python-script /tmp/install-slicer-extension.py ; \
done
ENV PATH="${PATH}:/app/slicer/bin"
RUN xvfb-run --auto-servernum /app/slicer/Slicer --python-script /tmp/install-pytorch-in-slicer.py ;
RUN /app/slicer/bin/PythonSlicer -m pip install matplotlib batchgenerators>=0.25 totalsegmentator==1.5.3
RUN /app/slicer/bin/PythonSlicer /app/slicer/lib/Python/bin/totalseg_import_weights -i /app/TotalSegmentatorWeights.zip

# ARG WEIGHTS_URL=https://zenodo.org/record/6802052/files/Task256_TotalSegmentator_3mm_1139subj.zip?download=1

# RUN apt-get update && apt-get install -y unzip && wget ${WEIGHTS_URL}  -O TotalSegmentatorWeights.zip && mkdir "/home/$HEADLESS_USER_NAME/.totalsegmentator" && \
#     unzip TotalSegmentatorWeights.zip -d "/home/${HEADLESS_USER_NAME}/.totalsegmentator/"

## final changes for user environment
WORKDIR "/home/$HEADLESS_USER_NAME"
RUN chmod -R 777 "/home/$HEADLESS_USER_NAME" && \
  chmod -R 777 "/tmp/" && \
  chmod -R 777 "$NOVNC_HOME/"
USER "$HEADLESS_USER_ID:$HEADLESS_USER_GROUP_ID"
## Start Slicer on desktop login
## This seems to be XFCE specific, so if the base env changes, will need to find an alternative to this
COPY Slicer.desktop "/home/$HEADLESS_USER_NAME/.config/autostart/"
## Copy the modified startup script. This is needed to change the index.html file to add NB_PREFIX to the vnc html file.
COPY startup.sh /dockerstartup/

# Use local Slicer tarball to extract app files.
# ARG SLICER_VERSION="Slicer-5.5.0-2023-08-25-linux-amd64"
# ARG SLICER_TARBALL="./host/$SLICER_VERSION.tar.gz"
# ADD $SLICER_TARBALL /app/
# RUN mv /app/$SLICER_VERSION /app/slicer && \
#   ln -s /app/slicer/Slicer /usr/local/bin/slicer && \
#   chown -R $HEADLESS_USER_ID:$HEADLESS_USER_GROUP_ID /app/slicer

# To have a Slicer in the image that already has the Total Segmentator
# extension and PyTorch you can use one of the two previous methods to get a
# vanilla version of Slicer, then create a container from the image.  Within
# the container start Slicer and install the Total Segmentator extension.
# Restart Slicer and then download the "CTA Abdomen (Panoramix)" sample data
# and create a new segmentation with Total Segmentator with it.  Then close
# Slicer and copy the /app/slicer directory to /host and specify it below.
# Then create a new image.
# See https://github.com/lassoan/SlicerTotalSegmentator#tutorial for
# instructions on loading the sample data.
# ARG PRERUN_SLICER_DIR=./host/Slicer-5.5.0-2023-08-25-linux-amd64-w-TS-PyTorch
# COPY $PRERUN_SLICER_DIR /app/slicer
# RUN chown -R $HEADLESS_USER_ID:$HEADLESS_USER_GROUP_ID /app/slicer && \
#   ln -s /app/slicer/Slicer /usr/local/bin/slicer
