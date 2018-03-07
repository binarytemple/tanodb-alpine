# Building 

Start the apk-cache server :

```
docker run --network ci --name=apk-cache quay.io/vektorcloud/apk-cache:latest
```

Start an alpine erlang container :

```
docker run --link apk-cache:dl-cdn.alpinelinux.org --network ci -ti bitwalker/alpine-erlang:20.2.2 /bin/bash
```

Linking works when running containers - in the above example it overrides the hostname 'dl-cdn.alpinelinux.org' with 'apk-cache'.
But in our case we will need to override the name during build.
Needless to say docker build doesn't support this so we will need another approach.

The solution in this case is to run apk-cache with a resolvable name of 'dl-cdn.alpinelinux.org'.
You might wonder how this will work, surely it will resolve to itself? 
This is not the case, the author has configured the nginx proxy to use '8.8.8.8' (google) as it's name resolver.

Lets try again... 

Run the apk cache server:

```
docker run --network ci --name=dl-cdn.alpinelinux.org quay.io/vektorcloud/apk-cache:latest
```

And the container:

```
▷ docker run --network ci -ti bitwalker/alpine-erlang:20.2.2 /bin/bash
bash-4.4# apk update
fetch http://dl-cdn.alpinelinux.org/alpine/v3.7/main/x86_64/APKINDEX.tar.gz
fetch http://dl-cdn.alpinelinux.org/alpine/v3.7/community/x86_64/APKINDEX.tar.gz
fetch http://nl.alpinelinux.org/alpine/edge/main/x86_64/APKINDEX.tar.gz
WARNING: This apk-tools is OLD! Some packages might not function properly.
v3.7.0-111-gb96041de80 [http://dl-cdn.alpinelinux.org/alpine/v3.7/main]
v3.7.0-117-g9584b2309e [http://dl-cdn.alpinelinux.org/alpine/v3.7/community]
v3.7.0-2692-g7734160866 [http://nl.alpinelinux.org/alpine/edge/main]
OK: 14815 distinct packages available
```

We can observe the corresponding lookup requests on the apk-cache side: 

```
2018/03/07 15:32:28 [notice] 7#7: using the "epoll" event method
2018/03/07 15:32:28 [notice] 7#7: nginx/1.12.2
2018/03/07 15:32:28 [notice] 7#7: OS: Linux 4.9.75-linuxkit-aufs
2018/03/07 15:32:28 [notice] 7#7: getrlimit(RLIMIT_NOFILE): 1048576:1048576
2018/03/07 15:32:28 [notice] 7#7: start worker processes
2018/03/07 15:32:28 [notice] 7#7: start worker process 8
2018/03/07 15:32:28 [notice] 7#7: start worker process 9
2018/03/07 15:32:28 [notice] 7#7: start worker process 10
2018/03/07 15:32:28 [notice] 7#7: start worker process 11
172.21.0.2 - - [07/Mar/2018:15:32:43 +0000] "GET /alpine/v3.7/main/x86_64/APKINDEX.tar.gz HTTP/1.1" 200 768464 "-" "libfetch/2.0"
172.21.0.2 - - [07/Mar/2018:15:32:43 +0000] "GET /alpine/v3.7/community/x86_64/APKINDEX.tar.gz HTTP/1.1" 200 451609 "-" "libfetch/2.0"
2018/03/07 15:32:44 [info] 8#8: *1 client 172.21.0.2 closed keepalive connection

```

Lets see how this performs with a `docker build`.

```Dockerfile
FROM bitwalker/alpine-erlang:20.2.2 

MAINTAINER Bryan Hunt <admin@binarytemple.co.uk>

RUN apk update && apk upgrade && apk add --allow-untrusted abuild binutils build-base ccache cmake cmake-doc gcc git snappy-dev

RUN git config --global url."https://github.com/".insteadOf git@github.com: ; git config --global url."https://".insteadOf git://

#install rebar3
RUN curl https://s3.amazonaws.com/rebar3/rebar3 -o /bin/rebar3 && chmod 755 /bin/rebar3

WORKDIR /root

#get tanodb 
RUN git clone git@github.com:marianoguerra/tanodb.git

WORKDIR /root/tanodb

RUN make 

RUN make devrel

```
Build, tag, login, and push to Docker hub

```
docker build --network ci --tag bryanhuntesl/tanodb-linux .
docker login
docker push bryanhuntesl/tanodb-linux
```

Lets run our container, mounting the /root/tanodb2 directory locally :

```                                                                                                                                                                        
docker run --mount type=bind,source="$(pwd)"/tanodb,target=/root/tanodb2 --network ci -ti bryanhuntesl/tanodb-linux /bin/bash
```

Inside the container we copy the /root/tanodb directory to the /root/tanodb2 mount :

```
bash-4.4# pwd                                                                                                                                                                     
/root/tanodb                                                                                                                                                                      
bash-4.4# cp -pr . ../tanodb2
bash-4.4# cd ../tanodb2/
bash-4.4# ls -la                                                                                                                                                    
total 24
drwxr-xr-x    9 root     root           288 Mar  7 18:06 .
drwx------    1 root     root          4096 Mar  7 16:56 ..
-rw-r--r--    1 root     root          2273 Mar  7 16:01 Makefile
-rw-r--r--    1 root     root          2800 Mar  7 16:01 README.rst
drwxr-xr-x    3 root     root            96 Mar  7 16:02 _build
drwxr-xr-x    3 root     root            96 Mar  7 16:01 apps
drwxr-xr-x   17 root     root           544 Mar  7 16:01 config
-rw-r--r--    1 root     root          2827 Mar  7 16:01 rebar.config
-rw-r--r--    1 root     root          4173 Mar  7 16:02 rebar.lock
```

Now we can edit our code from outside the container, and inside the container:  

```                                                                                                                                                                        bash-4.4# make
rebar3 release
===> Verifying dependencies...
===> Compiling tanodb
===> Failed to restore /root/tanodb2/_build/default/lib/tanodb/.rebar3/erlcinfo file. Discarding it.
apps/tanodb/src/tanodb_vnode.erl:2: Warning: undefined callback function handle_overload_command/3 (behaviour 'riak_core_vnode') 
apps/tanodb/src/tanodb_vnode.erl:2: Warning: undefined callback function handle_overload_info/2 (behaviour 'riak_core_vnode')
apps/tanodb/src/tanodb_write_fsm.erl:39: Warning: gen_fsm:start_link/3 is deprecated and will be removed in a future release; use gen_statem:start_link/3 
===> Running cuttlefish schema generator                        
===> Starting relx build process ...
===> Resolving OTP Applications from directories:
/root/tanodb2/_build/default/lib                                                                                                                                        
/root/tanodb2/apps
/usr/lib/erlang/lib
/root/tanodb2/_build/default/rel
===> Resolved tanodb-0.1.0
===> Dev mode enabled, release will be symlinked
===> release successfully created!
mkdir -p _build/default/rel/tanodb_data/
mkdir -p _build/default/rel/tanodb_config/
cp _build/default/rel/tanodb/etc/* _build/default/rel/tanodb_config/
bash-4.4#
```