# ZShaolin build script
# (C) 2013 Denis Roio - GNU GPL v3
# refer to zmake for license details

# configure the logfile
LOGS=build.log
rm -f $LOGS; touch $LOGS

prepare_sources

# make openssl static libraries
zndk-build openssl-static
rsync openssl-static/obj/local/armeabi/*.a $PREFIX/lib/
rsync -r openssl-static/include/openssl $PREFIX/include

# make openssh
{ test -r android-openssh.done } || {
    cp openssh-config.h android-openssh/jni/config.h
    cp openssh-pathnames.h android-openssh/jni/pathnames.h
    zndk-build android-openssh
    { test $? = 0 } && { 
	touch android-openssh.done
	rm -f android-openssh.installed }
}
{ test -r android-openssh.installed } || {
    rsync android-openssh/libs/armeabi/* $PREFIX/bin
    rsync android-openssh/obj/local/armeabi/libssh.a $PREFIX/lib
    rsync android-openssh/jni/*.1 $PREFIX/share/man/man1/
    rsync android-openssh/jni/*.5 $PREFIX/share/man/man5/
    rsync android-openssh/jni/*.8 $PREFIX/share/man/man8/
    mv $PREFIX/bin/client-ssh $PREFIX/bin/ssh
    mkdir -p $PREFIX/etc/ssh
    rsync android-openssh/jni/*-config $PREFIX/etc/ssh/
    touch android-openssh.installed
}

# make rsync
compile rsync default
zinstall rsync

# make git
{ test -r git.done } || {
notice "Building git"
GIT_FLAGS=(prefix=${APKPATH}/files/system NO_INSTALL_HARDLINKS=1 NO_NSEC=1 NO_ICONV=1)
GIT_FLAGS+=(NO_PERL=1 NO_PYTHON=1)
pushd git
autoconf
zconfigure default "--without-iconv"
{ test $? = 0 } && {
    make git ${GIT_FLAGS}
#    make man prefix=${APKPATH}/files/system
    { test $? = 0 } && {
	touch ../git.done
	rm -f ../git.installed
    }
}
popd
}

{ test -r git.installed } || {
pushd git
make install ${GIT_FLAGS}
{ test $? = 0 } && { touch ../git.installed }
#make install-man prefix=${APKPATH}/files/system NO_INSTALL_HARDLINKS=1

# now fix all shellbangs in git's scripts. can't do that from config
# flags because of config checks conflicting with cross-compilation.
notice "Fixing shell bangs in git scripts"
gitshellscripts=`find $PREFIX/libexec/git-core -type f`
for i in ${(f)gitshellscripts}; do
    func "git: fixing shellbang for $i"
    file $i | grep -i 'posix shell script' > /dev/null
    { test $? = 0 } && { sed -i "s@^#!/bin/sh@#!$PREFIX/bin/zsh@" $i }
done
popd
}

