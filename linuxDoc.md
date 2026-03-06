
# rocky9Tpa - Pure Linux version


So, you finally ditched the glitchy map, executed a perfect U turn, and found your way back to the main road. Welcome to Pure Linux the land of open highways, high performance, and absolutely no locked doors.

The GPS has stopped recalculating because, for the first time, you actually know exactly where you are. No more secret passages through WSL, no more Windows plumbing, and definitely no more 45 minute updates holding your terminal hostage. You’ve traded the I can’t believe it’s not Linux tunnel for the actual sunlight of the open source world.

## Understand what we are doing

### The "Docker out of Docker" (DooD) Concept

This is a bit of a brain bender at first, but it makes sense once you realize that the **TPA container** we are setting up isn’t actually “hosting” the other containers. It is just the **remote control**.

### DooD vs. DinD

Even though people call this **DinD** (Docker in Docker), we are actually doing **DooD** (Docker out of Docker).

**The Russian Doll Problem** Real DinD runs a whole Docker engine inside a container. It’s slow, it’s heavy, and it often breaks.
    
**The DooD Solution** We want the TPA container to use the Docker engine already running on your host (AlmaLinux, Fedora, or WSL), which is much more powerful.
    

### The Socket (`-v /var/run/docker.sock`)

The Docker Socket is the **telephone line** to the Docker Engine.

**The Brain** The Docker Engine lives on your Linux host.
    
**The Remote** The Docker CLI lives inside the TPA container.
    

By mounting `-v /var/run/docker.sock:/run/docker.sock`, you are plugging the telephone line from the host into the container. Without this, TPA would say,  "Dude! I don’t see a Docker engine here" and fail immediately.

### The Environment Variable (`-e DOCKER_HOST`)

We mounted the socket to `/run/docker.sock`, but the Docker CLI usually looks for it at `/var/run/docker.sock`. The `-e DOCKER_HOST=unix:///run/docker.sock` tells the CLI: _"Don't look in the usual spot; use this specific plug I just gave you."_

----------

## The Red Hat Family Caveats (SELinux)

If you are running Pure Linux on the Red Hat family (Fedora, RHEL, AlmaLinux, Rocky), you will hit a bump in the road that Ubuntu users don't see.

### The `:z` Flag (SELinux Labeling)

On Fedora/RHEL, **SELinux** is the proverbial security guard. It checks the "badge" (label) of every file. Even if you mount the socket, the guard sees a "Host Badge" on the file and a "Container Badge" on the process and blocks the connection.

When you add `:z` to your volume mount: `-v /var/run/docker.sock:/run/docker.sock:z`

Docker tells selinux:  "I’m sharing this. Please relabel it so the container is allowed to talk to it."

**The Nuclear Option** Sometimes Fedora's default policy is so restrictive that even `:z` isn't enough. In those cases, setting selinux to `permissive` (telling the guard to "take a hike") is the only way to get TPA to talk to the socket. It's a PITA, but it's a Red Hat trait.

### Does this apply to Ubuntu or Debian?

**No.** They use AppArmor, which handles things differently. However, you can leave the `:z` flag in the command regardless of the OS. The Docker engine is smart, on Ubuntu, it sees the `:z`, realizes there is no selinux to worry about, and simply ignores it. It makes your `docker run` command **cross platform**.

----------

### Summary of the DooD Advantage

-   **Direct Resources** No nesting overhead uses the host's power.
    
-   **Visibility** Run `docker ps` on your host and you'll see all your Postgres nodes sitting right next to your TPA container.
    
-   **Persistence** If the TPA "remote control" container stops, your Postgres cluster keeps running on the host.


## Getting started

**Make sure docker is running on the host computer. ( The Brain Computer )**

Make sure you have your e=EDB subscription token. You will need it for the next command.

    docker build --build-arg EDBTOKEN="your-subscription-token-in-here" --build-arg ADMINUSER="tpa_admin" -t rocky9-tpa .


**Run the container**

Once the image builds,  run the container.  Keep in mind everything mentioned above if you have any questions about the flags in our docker run command below.

    docker run -it -d --name tpa --hostname tpa -v /var/run/docker.sock:/run/docker.sock:z -e DOCKER_HOST=unix:///run/docker.sock  rocky9-tpa

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

    tpaexec configure ~/clusters/tpademo--architecture M1 --postgresql 17 --platform docker --distribution Rocky --enable-efm --data-nodes-per-location 2 --no-git

The above will create a two node cluster named **tpademo**

cd into the tpademo directory

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

When you are ready to remove everything

From within the same directory run

    tpaexec deprovision .

**If you find this useful, send me a dozen Krispy Kreme Classic Doughnuts**
