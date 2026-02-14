# rocky9Tpa - Windows & WSL



So you want to run TPA on a windows system. As you know, TPA is not available for Windows but we have a solution.

Welcome to the I Can’t Believe It’s Not Linux experience where we pretend Redmond isn't watching our every move.  Let’s get this installed before Windows decides your productivity is a security risk and forces a 2:00 PM update.

In order to run this on your windows system, you will need to install Docker desktop and WSL. No big deal since this is becoming standard practice .

### Make sure you have Docker Desktop and WSL

**Install  WSL and Docker Dsesktop if not already installed.**

Open **PowerShell as Administrator** and run:

    wsl --install --no-distribution

This enables the Virtual Machine without installing the default Ubuntu distribution.

Restart your machine.  Yes, the classic Windows tax. There are many reasons why we prefer Linux. This is forced reboot one of them.

**Install Docker Desktop**

https://www.docker.com/products/docker-desktop/

**Important!**

During installation, make sure the box **“Use the WSL 2 based engine”** is checked. If it’s not, Docker will try to use Hyper V, which is like trying to race a Ferrari in a school zone.

**Lets install a flavor of Linux.**

We’re going with **AlmaLinux 9** because it matches the enterprise grade environment used for Postgres 17.

Open **PowerShell as Administrator** and run:

    wsl --install AlmaLinux-9

Launch "AlmaLinux 9" from your Start Menu. It will ask for a username and password.

**Important!**

Go back to Docker Desktop Settings > Resources > WSL Integration and toggle the switch for AlmaLinux-9 to ON. Click "Apply & Restart."

**Log on to the new AlmaLinux WSL** 

At this point you might as well set a password for root so you can su to root as needed.

    sudo su -

Once you provide your pawssword and have the root prompt, change the password for root.

    passwd

Enter and confirm the new password when prompted.

Last thing,  since you will be cloning packages from git, you will need to install git.

As root, run

    dnf install -y git

This should take care of it.


**One last what if note**

Once you are logged in to your WSL instance. Not the container but the AlmuLinux on wsl.  If your run

    docker ps

And get the following error

    permission denied while trying to connect to the docker API at unix:///var/run/docker.sock  

Run this command as user root  to resolve the issue.

    chown root:docker /var/run/docker.soc

## Understand what what we are doing

With the above pre-requisites out of the way,  It's now time to see the big picture.

This is a bit of a brain bender at first, but it makes sense once you realize that the tpa container we are setting up here isn't actually "hosting" the other containers that will be generated with tpa for either production or training. It's just the remote control for them.

### **The "Docker out of Docker" (DooD) Concept**

Even though we often call this **DinD** (Docker in Docker), what we are actually doing is **DooD** (Docker out of Docker).

If the TPA container were a "real" DinD setup, it would have a whole Docker engine running  inside it. That makes containers nested like Russian dolls, which is slow, consumes massive overhead, and often breaks due to filesystem driver conflicts. Instead, we want the TPA container to use the powerful Docker engine already running on your **AlmaLinux / WSL** host.

#### **Why the socket reference (`-v /var/run/docker.sock`)?**

The **Docker Socket** is the telephone line to the Docker Engine.

-   **The Brain** The Docker Engine (the daemon) lives on the AlmaLinux / WSL host, outside the TPA container.

-   **The Remote Control** The Docker CLI (the commands you type) lives inside the TPA container.


By mounting `-v /var/run/docker.sock:/run/docker.sock`, you are literally plugging the telephone line from the host into the container.  Without this, when TPA tries to run a command like `docker run postgres`, the container would say "I don't see a Docker engine here!"  and fail immediately.

#### **What is with the environment variable (`-e DOCKER_HOST`)?**

In this specific setup, we mounted the host socket to `/run/docker.sock` inside the container. However, the Docker CLI usually expects that telephone line to be at `/var/run/docker.sock`.

The `-e DOCKER_HOST=unix:///run/docker.sock` tells the CLI "Don't look in the usual spot,  use this specific plug I just gave you." This ensures TPA doesn't get a "connection refused" error by looking for a socket that isn't there.

### **How it works in reality**

When you tell TPA to build a Postgres cluster

1.  **Inside the container** TPA issues a command:  "Hey Docker, create a new container for a Postgres node."

2.  **The Journey** That command travels through the "Telephone Line" (`/run/docker.sock`).

3.  **The Execution** The host’s Docker Engine (The Brain on AlmaLinux/WSL) hears the request and starts the new container **next to** our TPA container, not inside it.


### **Summary of the DooD Advantage**

-   **No Overhead** Uses the host's resources directly instead of nesting multiple engines.

-   **Visibility** You can see all the generated Postgres containers by running `docker ps` on your **AlmaLinux / WSL host**, which makes debugging much easier.

-   **Persistence** If the TPA container stops or crashes, the Postgres nodes it created keep running on the host.




## Getting started

**Make sure docker is running on the host computer. ( The Brain Computer )**

**Build the image.**

Make sure you have your subscription token handy. You will need it to run the next command.

    docker build --build-arg EDBTOKEN="your-subscription-token-in-here" --build-arg ADMINUSER="tpa_admin" -t rocky9-tpa .

In the above command, you can change the name of the **ADMINUSER** if you like.

**Run the container**

Once the image builds,  run the container.  Keep in mind everything mentioned above if you have any questions about the flags in our docker run command below.

    docker run -it -d  --name tpa  --hostname tpa  -v /var/run/docker.sock:/run/docker.sock:z  -e DOCKER_HOST=unix:///run/docker.sock  rocky9-tpa

**Log into the container**

    docker exec -it tpa /bin/bash


**Be patient the first time.**

If this is the first time logging in, be patient as there are some setup processes that are taking place and it takes a minute or two to complete. Mainly the tpa setup is executing.

You can check the status by running

    ps -ef | grep tpa

And if you see, the following, it is still setting up

```
root         7     1  0 14:55 pts/0    00:00:00 bash /opt/EDB/TPA/bin/tpaexec setup
root        43     7  0 14:55 pts/0    00:00:00 bash /opt/EDB/TPA/bin/tpaexec setup
root        44    43  0 14:55 pts/0    00:00:00 /bin/bash /opt/EDB/TPA/ansible/ansible-galaxy collection install -p /opt/EDB/TPA/tpa-venv/collections -r requirements.yml
root        46    44 10 14:55 pts/0    00:00:02 /opt/EDB/TPA/tpa-venv/bin/python3 /opt/EDB/TPA/tpa-venv/bin/ansible-galaxy collection install -p /opt/EDB/TPA/tpa-venv/collections -r requirements.yml

```

Once your ps command returns clean, you are good to go.

**Run a self test**

You can do this as the root user or the ADMINUSER you created.

To run as the tpa_admin user, simply run

    su - tpa_admin

And run the self test.

    tpaexec selftest

Which will show an output with and ending like ...

```
PLAY RECAP *******************************************************************************************************************************************************
localhost                  : ok=4    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

## A simple deploy example,

Still logged in as the admin_user

    cd

Then create a directory for your deploys

    mkdir clusters

Then cd into the clusters directory

**cd clusters**

Then run this simple configure

At the time of this writing efm was not available for ARM. So swapping for patroni.  There is a newer version. Once I get the details, I will update this doc.

    tpaexec configure ~/clusters/tpademo --architecture M1 --postgresql 17 --platform docker --distribution Rocky --enable-efm --data-nodes-per-location 2 --no-git

The above will create a two node cluster named **tpademo**

cd into the **tpademo** directory

    cd tpademo

Modify the config.yml file

Change

    keyring_backend: system

to

    keyring_backend: legacy


Save your changes

From within the same directory run

    tpaexec provision .

If successful, follow up with a

    tpaexec deploy .

From another terminal log onto your laptop or desktop and run

    docker ps

you should see the newly created containers there now.

When you are ready to remove everything and cleanup your environment

From within the same directory run

    tpaexec deprovision .

**If you find this useful, send me a dozen Krispy Kreme Classic Doughnuts**
