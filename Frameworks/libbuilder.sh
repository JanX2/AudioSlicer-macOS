#!/bin/sh

#set -x

# set a default build dir and make sure it exists
: ${BUILDDIR:=$TARGET_TEMP_DIR}
mkdir -p "$BUILDDIR"

# extract archive if RELSRCDIR points to a tar.gz
if [ -f "$SRCROOT/$RELSRCDIR" ] ; then
	(cd "$BUILDDIR" && tar xzf "$SRCROOT/$RELSRCDIR")
	SRCDIR=$(find "$BUILDDIR/" -name "$BASENAME*" -prune)
	BUILDDIR=$SRCDIR
fi

# apply patches
if [ -f "$SRCROOT/$PATCHFILE" ] ; then
	(cd "$BUILDDIR" && patch -p0 < "$SRCROOT/$PATCHFILE")
fi

# default to no configure arguments
: ${CONFIGURE_ARGUMENTS:=""}

# set the src dir based on a relative path
: ${SRCDIR:="$SRCROOT/$RELSRCDIR"}

# make sure the destination dir exists
mkdir -p "$BUILT_PRODUCTS_DIR"

# run configure (if not done yet)
doConfigure() {
	#if [ ! -e "$BUILDDIR/Makefile" ]; then
		echo 1>&2 "note: Configuring $BASENAME..."
		chmod -f a+x "$BUILDDIR/configure"
		(cd "$BUILDDIR" && ./configure "--prefix=$BUILT_PRODUCTS_DIR/$BASENAME" $CONFIGURE_ARGUMENTS $ARCH_CONFIGURE_ARGUMENTS)
		if [ $? -ne 0 ]; then
			echo 1>&2 "error: Configuring $BASENAME failed"
			exit 1
		fi
	#fi
}

# run make, configure must have finished before
doMake() {
	MAKETARGET=${1:-"all"}
	echo 1>&2 "note: Making $MAKETARGET for $BASENAME..."
	if [ -e "$BUILDDIR/Makefile" ]; then
		(cd "$BUILDDIR" && make "$MAKETARGET")
		if [ $? -ne 0 ]; then
			echo 1>&2 "error: Making $MAKETARGET for $BASENAME failed"
			exit 1
		fi
	fi
}

# run configure and make for all architectures and link them together
doBuild() {
	ARCHPRODUCTS=""
	
	for arch in $ARCHS; do
		echo $arch
		if [ ${NO_CONFIGURE_HOST_ARGUMENT:-"0"} -eq 0 ]; then
			ARCH_CONFIGURE_ARGUMENTS="--host=$arch-apple-darwin"
		fi
		
		# find the gcc version to use
		VAR="GCC_VERSION_$arch"
		if [ ! -z ${!VAR} ]; then
			GCC="gcc-${!VAR}"
		else
			GCC="gcc"
		fi
		
		# find the sdk version to use
		VAR="SDKROOT_$arch"
		if [ ! -z ${!VAR} ]; then
			SDK=${!VAR}
		else
			SDK=$SDKROOT
		fi
		
		export CC="$GCC -arch $arch"
		export CXX="$GCC -arch $arch"
		export LDFLAGS="-Wl,-syslibroot,$SDK -arch $arch"
		$GCC --version | grep 'gcc-3'
		if [ $? -eq 0 -o ${NO_CFLAGS_SYSROOT:-"0"} -eq 1 ]; then
			# gcc 3 doesn't understand the sdk options
			export CFLAGS="-arch $arch"
		else
			export CFLAGS="-isysroot $SDK -arch $arch"
		fi
		
		doCleanAll
		doConfigure
		doMake $2
		
		mkdir -p "$TARGET_TEMP_DIR/archs/$arch"
		cp "$BUILDDIR/$1" "$TARGET_TEMP_DIR/archs/$arch/"
		ARCHPRODUCTS="$ARCHPRODUCTS $TARGET_TEMP_DIR/archs/$arch/$(basename $1)"
	done
	
	lipo -create -output "$BUILDDIR/$1" $ARCHPRODUCTS
}

# run make clean
doClean() {
	doMake clean
}

# run make distclean to also get rid of configure data
doCleanAll() {
	doMake distclean
}

# a helper method that copies a file from build dir to products dir
installFile() {
	FILENAME=$(basename $1)
	echo 1>&2 "note: Installing $BUILT_PRODUCTS_DIR/$2..."
	mkdir -p "$BUILT_PRODUCTS_DIR/$2"
	#if [ "$BUILDDIR/$1" -nt "$BUILT_PRODUCTS_DIR/$2/$FILENAME" ]; then
		cp "$BUILDDIR/$1" "$BUILT_PRODUCTS_DIR/$2"
		case $1 in
			*.a)
				ranlib "$BUILT_PRODUCTS_DIR/$2/$FILENAME"
				;;
		esac
	#fi
}

# do the right thing depending on the action
build() {
	case $ACTION in
		build )
			doBuild $1 $2
			;;
			
		clean )
			doClean
			;;
	esac
}
