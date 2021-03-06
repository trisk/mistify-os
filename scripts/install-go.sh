#+
# Compile go from source and install it into the previously built toolchain.
# NOTE: The go repo is mirrored on github. The install instructions point to
# the googlesource repo so that URL is the default for this script. Of course
# it can be overridden using the --gouri command line option.
# NOTE: This relies upon the toolchainversion variable from the install-toolchain
# script. This is because th path to the toolchain is embedded and different
# versions of the toolchain can be selected.
#-
gouridefault=git@github.com:golang/go.git
godirdefault=$PWD/go
gotagdefault=go1.4.2

install-go () {
    #+
    # Determine the location of the go directory.
    #-
    if [ -z "$godir" ]; then
	if [ -f $statedir/godir ]; then
	    godir=`cat $statedir/godir`
	else
	    godir=$godirdefault
	fi
	message "Using go located at: $godir"
    fi
    eval godir=$godir
    verbose "Building go in: $godir"
    echo $godir >$statedir/godir

    #+
    # Determine the uri to use to fetch the go source.
    #-
    if [ -z "$gouri" ]; then
	if [ -f $statedir/gouri ]; then
	    gouri=`cat $statedir/gouri`
	else
	    gouri=$gouridefault
	fi
    fi
    if [[ "$gouri" == "default" ]]; then
      warning "Resetting the GO repository URI to the default: $gouridefault."
      gouri=$gouridefault
    fi
    message "The go source repository is: $gouri"
    echo $gouri >$statedir/gouri

    #+
    # Determine the tag or branch to use to fetch the go source.
    #-
    if [ -z "$gotag" ]; then
	if [ -f $statedir/gotag ]; then
	    gotag=`cat $statedir/gotag`
	else
	    gotag=$gotagdefault
	fi
    fi
    if [[ "$gotag" == "default" ]]; then
      warning "Resetting the GO repository tag to the default: $gotagdefault."
      gotag=$gotagdefault
    fi
    message "The go branch or tag is: $gotag"
    echo $gotag >$statedir/gotag

    golabel=$gotag-$toolchainversion
    verbose The Go label is: $golabel

    GOROOT=$godir/$golabel/go
    verbose "The go binaries are located at: $GOROOT"

    if [ -f $godir/.$golabel-built ]; then
	message "Using go version $gotag."
	return
    fi
    #+
    # The go binaries don't exist.
    #-
    if [ -n "$testing" ]; then
	message "Just a test run -- not building the toolchain."
	verbose "./all.bash"
    else
	run mkdir -p $godir/$golabel
	cd $godir/$golabel
	verbose "Working directory is: $PWD"
	if [ ! -d go ]; then
	    run git clone $gouri
	fi
	cd go
	run git fetch $gouri
	run git checkout $gotag
	cd src
	export GOOS=linux
	export GOARCH=amd64
	if [ -n "$TC_PREFIX_DIR" ]; then
	    export CC_FOR_TARGET="$TC_PREFIX_DIR/bin/${TC_PREFIX}-cc"
	    export CXX_FOR_TARGET="$TC_PREFIX_DIR/bin/${TC_PREFIX}-c++"
	fi
	export CGO_ENABLED=1

	run ./make.bash

	# Clean up
	unset CC_FOR_TARGET
	unset CXX_FOR_TARGET
	unset CGO_ENABLED

	touch $godir/.$golabel-built
    fi
}
