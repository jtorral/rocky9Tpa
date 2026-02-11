
# rocky9Tpa - Windows Version

So, you’ve taken the road less traveled. Or maybe you just held the map upside down, missed the turn at the fork, and materialized here on Windows. Either way, the doors have locked and the GPS is recalculating. There’s no turning back now so lets keep going :)

## Understand what we are doing 

This is a bit of a brain bender  at first, but it makes sense once you realize that the tpa container we are setting up here  isn't actually "hosting" the other containers that will be generated with tpa for either production or training. It's just the remote control for them.

**The Docker out of Docker Concept**

Even though we call this DinD (Docker in Docker), what we are actually doing is DooD (Docker out of Docker).

If the tpa container was a  real DinD setup, it would have a whole Docker engine running inside it. That makes containers nested like Russian dolls, which is slow and often breaks. Instead, I want the tpa container to use the Docker engine already running on mAlmaLinux/WSL host or whatever host you have which is much more powerful.

**Why the socket reference (-v /var/run/docker.sock) for our docker run command ?**

The Docker Socket is the telephone line to the Docker Engine.

In this setup, the Docker Engine (the brain) lives on a Windows host.  Outside of the actual tpa container.

The Docker CLI (the remote control) lives inside the tpa container which is a Linux Host.

By mounting  **-v /var/run/docker.sock:/var/run/docker.sock** , I am literally plugging the  telephone line  from the host into the container. Without this, when tpa tries to run a command like docker run postgres, the container would say, "Dude! I don't see a docker engine here, I don't know what to do."  then fail.

**What is with the environment variable ( -e DOCKER_HOST ) ?**


The `-e DOCKER_HOST=unix:///var/run/docker.sock` tells the CLI,  "Don't look in the usual spot,  use this specific plug I just gave you."  It ensures tpa doesn't get a "connection refused" error.

We use because this is the most widely recognized standard. If you mount it there, most Docker tools look there by default for the socket


**How it works in reality**

When you tell tpa to build a Postgres cluster, 

Inside the container,  tpa issues a command "Hey Docker, create a new container for a Postgres node."

That command travels through the Telephone Line, /run/docker.sock file.

The host’s Docker Engine ( The Brain on the Windows host )  hears the request and starts the new container next to our already running tpa container, not inside it.

To summarize it ...

 - This method uses the host's resources directly instead of nesting
   overhead. 
  - You can see all the generated Postgres containers by running docker ps on the Windows host, which makes debugging much easier.  
   - If the tpa container stops, the Postgres containers it created keep running on the host


### Getting started

**Before you clone the repo. Read this. !!!!**

By default, Git for Windows converts Linux line endings (LF) to Windows line endings (CRLF) when you check out code.

When Docker copies the entrypoint.sh or other files into the container we are creating which is a Rocky Linux container, the linux shell sees the hidden **\r** (carriage return) at the end of the line (#!/bin/bash\r) and fails to execute it because it looks for a shell named bash\r, which doesn't exist.

**The quick fix ( If you didn't read Before you clone the repo )**

Fix the line endings . Open entrypoint.sh in Notepad++.  Look at the bottom right corner of the window and confirm it says  CRLF. 

**To fix this this with Notepad++**

- Open the file in Notepad++.
- Go to the Edit menu.
- Select EOL Conversion.
- Choose Unix (LF).
- Save the file.

**If you paid attention and didn't clone the repo yet.** 

To stop Windows from messing with your scripts in the future, run this command in your PowerShell terminal

    git config --global core.autocrlf false



### Now, go ahead and clone this repo.

**Make sure docker is running on the host computer. ( The Brain Computer )** 


    docker build \ 
       --build-arg EDBTOKEN="your-subscription-token-in-here" \
       --build-arg ADMINUSER="tpa_admin" \
       -t rocky9-tpa .


In the above command, you can change the name of the **ADMINUSER** if you like.

**Run the container**

Once the image builds,  run the container.  Keep in mind everything mentioned above if you have any questions about the flags in our docker run command below.

    docker run -it -d  --name tpa  --hostname tpa  -v /var/run/docker.sock:/var/run/docker.sock  -e DOCKER_HOST=unix:///var/run/docker.sock  rocky9-tpa

**Log into the container**

    docker exec -it tpa /bin/bash


**Be patient the first time.**

If this is the first time logging in, be patient as there is some setup that is taking place and it takes a minute or two to complete. Mainly the tpa setup is executing.

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

At this point you are good to go.


### A simple deploy example,

Still logged in as the admin_user

    cd

Then create a directory for your deploys

    mkdir clusters

Then cd into the clusters directory

**cd clusters**

Then run this simple configure

At the time of this writing efm was not available for ARM. So swapping for patroni.  There is a newer version. Once I get the details, I will update this doc.

    tpaexec configure ~/clusters/mytest --architecture M1 --postgresql 17 --platform docker --distribution Rocky --enable-efm --data-nodes-per-location 2 --no-git

The above will create a two node cluster named **mytest**

cd into the mytest directory

    cd mytest

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

When you are ready to remove everything

From within the same directory run

    tpaexec deprovision .

**If you find this useful, send me a dozen Krispy Kreme Classic Doughnuts**

