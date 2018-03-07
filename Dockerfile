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

COPY validate_config /usr/local/bin/validate_config


