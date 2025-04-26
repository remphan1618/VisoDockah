FROM nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04

ENV REFRESHED_AT 2024-08-12

LABEL io.k8s.description="Headless VNC Container with Xfce for Jupyter + SSH" \
      io.k8s.display-name="Jupyter + SSH Container" \
      io.openshift.expose-services="8888:http,22:ssh" \
      io.openshift.tags="jupyter, ssh, ubuntu, xfce"

### Connection ports:
### Jupyter: 8888
### SSH: 22
ENV DISPLAY=:1
ENV VNC_PORT=5901
ENV NO_VNC_PORT=6901
ENV JUPYTER_PORT=8888
ENV SSH_PORT=22
EXPOSE $JUPYTER_PORT $SSH_PORT

### Envrionment config
ENV HOME=/workspace
ENV TERM=xterm
ENV STARTUPDIR=/dockerstartup
ENV INST_SCRIPTS=/workspace/install
ENV NO_VNC_HOME=/workspace/noVNC
ENV DEBIAN_FRONTEND=noninteractive
ENV VNC_COL_DEPTH=24
ENV VNC_PW=vncpassword
ENV VNC_VIEW_ONLY=false
ENV TZ=Asia/Seoul
ENV JUPYTER_ENABLE_LAB=yes # Enable JupyterLab by default
WORKDIR $HOME

### Install necessary dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    wget \
    git \
    build-essential \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    unzip \
    ffmpeg \
    jq \
    tzdata \
    openssh-server \
    python3 \
    python3-pip && \
    ln -fs /usr/share/zoneinfo/$TZ /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata && \
    rm -rf /var/lib/apt/lists/* && \
    python3 -m pip install --no-cache-dir --upgrade pip

### Add all install scripts for further steps
COPY ./src/common/install/ $INST_SCRIPTS/
COPY ./src/debian/install/ $INST_SCRIPTS/
RUN chmod 765 $INST_SCRIPTS/*

### Install some common tools
RUN $INST_SCRIPTS/tools.sh
ENV LANG='en_US.UTF-8'
ENV LANGUAGE='en_US:en'
ENV LC_ALL='en_US.UTF-8'

### Install custom fonts
RUN $INST_SCRIPTS/install_custom_fonts.sh

### Install xvnc-server & noVNC - HTML5 based VNC viewer (for optional use)
RUN $INST_SCRIPTS/tigervnc.sh
RUN $INST_SCRIPTS/no_vnc_1.5.0.sh

### Install firefox and chrome browser
RUN $INST_SCRIPTS/firefox.sh

### Install IceWM UI (For potential minimal UI)
RUN $INST_SCRIPTS/icewm_ui.sh
ADD ./src/debian/icewm/ $HOME/

### Configure startup scripts
RUN $INST_SCRIPTS/libnss_wrapper.sh
COPY ./src/common/scripts $STARTUPDIR
RUN chmod 765 $STARTUPDIR/*
RUN $INST_SCRIPTS/set_user_permission.sh $STARTUPDIR $HOME

### Install VisoMaster and dependencies
WORKDIR /workspace
RUN git clone https://github.com/remphan1618/VisoMaster.git && \
    cd VisoMaster
RUN pip install --no-cache-dir -r requirements.txt

### Install jupyterlab using pip
RUN pip install --no-cache-dir jupyterlab

### Install filebrowser
RUN wget -O - https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash
EXPOSE 8585

# nvidia problem
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libegl1 \
    libgl1-mesa-glx \
    libglib2.0-0 && \
    rm -rf /var/lib/apt/lists/*
# qt prblem
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libxcb-cursor0 \
    libxcb-xinerama0 \
    libxkbcommon-x11-0 && \
    rm -rf /var/lib/apt/lists/*
    
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libqt5gui5 \
    libqt5core5a \
    libqt5widgets5 \
    libqt5x11extras5 && \
    rm -rf /var/lib/apt/lists/*

# fileman
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    pcmanfm && \
    rm -rf /var/lib/apt/lists/*

### SSH Configuration
RUN echo "root:vncpassword" | chpasswd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config
RUN sed -i 's/#PasswordAuthentication yes/g' /etc/ssh/sshd_config
RUN mkdir -p /root/.ssh
RUN ssh-keygen -t rsa -f /root/.ssh/id_rsa -N "" # No passphrase
COPY ./src/common/ssh/authorized_keys /root/.ssh/authorized_keys
RUN chmod 600 /root/.ssh/authorized_keys

### Copy the On-Start Script into the container
COPY ./your_on_start_script.sh /dockerstartup/on_start.sh # Copy the script
RUN chmod +x /dockerstartup/on_start.sh # Make it executable


### Startup Script Modification
COPY ./src/vnc_startup_jupyterlab_filebrowser.sh /dockerstartup/vnc_startup.sh
RUN chmod 765 /dockerstartup/vnc_startup.sh

# Add a new startup script specifically for ssh + jupyter
COPY ./src/common/scripts/start_jupyter_ssh.sh /dockerstartup/start_jupyter_ssh.sh
RUN chmod 755 /dockerstartup/start_jupyter_ssh.sh

ENV VNC_RESOLUTION=1280x1024

# Use the new script as the default
ENTRYPOINT ["/dockerstartup/start_jupyter_ssh.sh"]
CMD ["--wait"]
