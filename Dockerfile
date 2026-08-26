#By NightAsylum
#https://github.com/NightAsylum/Linux-PrivEsc-Container


FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive


#Configure Users
RUN echo 'root:toor' | chpasswd
RUN useradd -m -s /bin/bash user && \
    echo 'user:password' | chpasswd


# Install Necessary Packages
RUN  apt-get update &&  apt-get install -y \
    nano \
    tree \
    strace \ 
    less \
    vim \
    apache2 \
    iftop \
    gawk \
    openssh-server \
    build-essential \
	gdebi-core  \
    cron \
    unzip \
    net-tools \
    libcap2-bin \
    openvpn && \
    apt-get clean

#Install Vulnerable Sudo Version
COPY /Data/Files/sudo_1.8.31-1ubuntu1_amd64.deb .
RUN gdebi -n sudo_1.8.31-1ubuntu1_amd64.deb
RUN rm -f sudo_1.8.31-1ubuntu1_amd64.deb


#Set Bash History and Password in Config File

RUN echo "echo Hello World" >> /home/user/.bash_history
RUN echo "ls -al" >> /home/user/.bash_history
RUN echo "cat /etc/passwd" >> /home/user/.bash_history
RUN echo "whoami" >> /home/user/.bash_history
RUN echo "su root toor" >> /home/user/.bash_history
RUN echo "su root" >> /home/user/.bash_history
RUN echo "ps aux" >> /home/user/.bash_history
RUN echo "ifconfig" >> /home/user/.bash_history
RUN echo "ping google.com" >> /home/user/.bash_history
RUN echo "mkdir Backup" >> /home/user/.bash_history
RUN echo "top" >> /home/user/.bash_history
RUN echo "head /etc/apt/sources.list" >> /home/user/.bash_history

COPY /Data/Files/myvpn.ovpn  /home/user/
RUN echo 'root,toor' > /etc/openvpn/auth.txt


#Set SSH Backup Keys
RUN    mkdir -p /root/.ssh && \
    ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N "" && \
    cat /root/.ssh/id_ed25519.pub >> /root/.ssh/authorized_keys && \
	cp -r /root/.ssh/ /home/.ssh &&  \
    chmod 745 /home/.ssh && \
	chmod 704 /home/.ssh/*



#Set Incorrect File Permissions On Important OS Files
RUN sudo chmod 766 /etc/passwd && chmod 444 /etc/shadow

#Configure CronJobs 
COPY /Data/Scripts/compress.sh /Data/Scripts/backup.sh   /usr/local/bin/
RUN mkdir /root/scripts
COPY /Data/Scripts/getopenports.sh /root/scripts
RUN chmod 747 /usr/local/games

RUN chown root:root /usr/local/bin/backup.sh /usr/local/bin/compress.sh /root/scripts/getopenports.sh && \
    chmod 746 /usr/local/bin/backup.sh 
RUN chmod +x /root/scripts/getopenports.sh



# Copy Various Needed Files
COPY /Data/Files/suid-so /Data/Files/suid-env  /usr/local/bin/
COPY /Data/Files/crontab  /etc/
COPY /Data/Files/sudoers /etc/
COPY /Data/Files/top12000.txt /home/user/top12000.txt
COPY /Data/Scripts/suBF.sh /home/user/suBF.sh
RUN chmod +x /home/user/suBF.sh


# Add Capabilities
RUN  cp /bin/python3.8 /home/user/python3.8
RUN  setcap cap_setuid+ep /home/user/python3.8
RUN setcap CAP_DAC_OVERRIDE=eip /bin/head
RUN setcap CAP_DAC_READ_SEARCH=eip /bin/tree


# Copy And Set SUID On Binaries
RUN chmod +s /usr/local/bin/suid-so /usr/local/bin/suid-env  /usr/bin/grep /usr/bin/timeout /usr/bin/strace


# Copy And Config Broken Service
COPY /Data/Files/PyWeb /etc/init.d/PyWeb
RUN chmod 746 /etc/init.d/PyWeb
COPY /Data/Scripts/webserver.py /usr/local/bin/webserver.py
RUN chmod +x  /etc/init.d/PyWeb && chmod +x  /usr/local/bin/webserver.py && chmod 706 /usr/local/bin/webserver.py


# Use an Entrypoint Script To Start Services
COPY /Data/Scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh


EXPOSE  22

# Set The Entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
