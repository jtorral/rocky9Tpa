# rocky9Tpa

This repo allows you to run  a tpa container to orchestrate additional tpa deploys on your existing while keeping it local to your laptop or desktop. 

And are tired of all the headaches in setting up EC2' instances, providing credentials and accounts, this will make life easier as each student would simply run this on their own system without the need to use a cloud platform or anything else. Furthermore, they can keep the systems after the training. 

### Caveats

You need an EDB token to download from the EDB repo. However, this is is just a first run at this and the open source version should follow shortly where you can download tpa without a subscription.

Know your EDB Subscription token. You will need it .


## Highly recommended to read this section !

### Understand what we are doing 

This is a bit of a brain bender  at first, but it makes sense once you realize that the tpa container we are setting up here  isn't actually "hosting" the other containers that will be generated with tpa for either production or training. It's just the remote control for them.

This requires several explanations based on your environment. 

The explanation below is generic and applies to any environment.  But, I will describe some minor chnages needed based on the different environments.

### Setup: Windows laptop with WSL running Alma Linux

**The Docker out of Docker Concept**

Even though we call this DinD (Docker in Docker), what we are actually doing is DooD (Docker out of Docker).

If the tpa container was a  real DinD setup, it would have a whole Docker engine running inside it. That makes containers nested like Russian dolls, which is slow and often breaks. Instead, I want the tpa container to use the Docker engine already running on mAlmaLinux/WSL host or whatever host you have which is much more powerful.

**Why the socket reference (-v /var/run/docker.sock) for our docker run command ?**

The Docker Socket is the telephone line to the Docker Engine.

In this setup, the Docker Engine (the brain) lives on the AlmaLinux / WSL host.  Outside of the actual tpoa container.

The Docker CLI (the remote control) lives inside the tpa container.

By mounting -v /var/run/docker.sock:/run/docker.sock, I am literally plugging the  telephone line  from the host into the container. Without this, when tpa tries to run a command like docker run postgres, the container would say, "I don't see a docker engine here, I don't know what to do."  then fail.

What is with the environment variable ( -e DOCKER_HOST ) ?

In this specific setup, I mounted the socket to /run/docker.sock. However, the Docker CLI usually expects that telephone line to be at /var/run/docker.sock.

The `-e DOCKER_HOST=unix:///run/docker.sock` tells the CLI,  "Don't look in the usual spot,  use this specific plug I just gave you."  It ensures tpa doesn't get a "connection refused" error.

**How it works in reality**

When you tell tpa to build a Postgres cluster, 

Inside the container,  tpa issues a command "Hey Docker, create a new container for a Postgres node."

That command travels through the Telephone Line, /run/docker.sock file.

The host’s Docker Engine ( The Brain on the AlmaLinux / WSL )  hears the request and starts the new container next to our already running tpa container, not inside it.

To summarize it ...

 - This method uses the host's resources directly instead of nesting
   overhead. 
  - You can see all the generated Postgres containers by running docker ps on the AlmaLinux / WSL host, which makes debugging much easier.  
   - If the tpa container stops, the Postgres containers it created keep running on the host


### Setup: Fedora laptop ( the real McCoy )

This is very similar to the above scenario. However, even though it is straight forward Unix I had to work more to get this version working. Thus, I was running into the security layers specific to the RHEL family.  

By the way, Ubuntu and Debian users rarely see this because they use a different security framework.

**The :z flag ( selinux labeling )** 

On Fedora, selinux is the proverbial pain in the butt. It is like a strict security guard that checks the badge (label) of every file. Even if you mount the socket into the container, the guard sees that the socket has a **Host Badge** and the container has a **Container Badge**. It blocks the connection because the labels don't match.

When you add **:z** to your volume mount, Docker automatically tells selinux: "Hey dude, I'm sharing this file with multiple containers. Please relabel it so the containers are allowed to talk to it.

This changes the selinux context of the socket so the container process has permission to touch it.

I actually had to disable selinux on my Fedora laptop even with **:z**, sometimes the default selinux policy on Fedora is so restrictive that it blocks containers from accessing system sockets entirely for safety. By disabling it (or setting it to permissive), I told the guard to  take a hike and stop blocking actions.

**Does this apply to Ubuntu or Debian?**  

No. This is a Red Hat family trait.

Having said that about the :z flag,  You can leave the :z (or :Z) flag in the run command, and it will run perfectly fine on Ubuntu, Debian, and even macOS or Windows.

The Docker engine is designed to be cross platform. When you pass the :z flag to a Docker engine running on a system without selinux (like Ubutu ), Docker simply recognizes the flag but realizes there are no selinux labels to apply. It silently ignores the instruction and mounts the volume normally

## Lets get started

### Clone this repo.

**Make sure docker is running on the host computer. ( The Brain Computer )** 


**Build the x86 image option**  

    docker build \ 
       --build-arg EDBTOKEN="your-subscription-token-in-here" \
       --build-arg ADMINUSER="tpa_admin" \
       -t rocky9-tpa .

**Build ARM image option**

    docker build \ 
       --build-arg EDBTOKEN="your-subscription-token-in-here" \
       --build-arg ADMINUSER="tpa_admin" \
       -f DockerfileArm \
       -t rocky9-tpa .

In the above command, you can change the name of the **ADMINUSER** of you like.

**Run the container**

Once the image builds,  run the container.  Keep in mind everything mentioned above if you have any questions about the flags in our docker run command below.

    docker run -it -d \
       --name tpa \
       --hostname tpa \
       -v /var/run/docker.sock:/run/docker.sock:z \  
       -e DOCKER_HOST=unix:///run/docker.sock \ 
       rocky9-tpa

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

**For x86** 

    tpaexec configure ~/clusters/mytest \
      --architecture M1 \
      --postgresql 17 \
      --platform docker \
      --distribution Rocky \
      --enable-efm \
      --data-nodes-per-location 2 \
      --no-git

**For ARM**

    tpaexec configure ~/clusters/mytest \
      --architecture M1 \
      --postgresql 17 \
      --platform docker \
      --distribution Rocky \
      --enable-patroni \
      --data-nodes-per-location 2 \
      --no-git


The above will create a two node cluster named **mytest**

cd into the mytest directory

    cd mytest

Modify the config.yml file

Change

    keyring_backend: system

to

    keyring_backend: legacy


Save your changes

From within the same diredctory run

> tpaexec provision .

If successfull, follow up with a 

    tpaexec deploy .

Fron another terminal log onto your laptop or desktop and run

    docker ps

you should see the newly created containers there now.

**If you find this useful, send me a dozen Krispy Kreme Classic Doughnuts**






