#
# configure.ac
#
# Author: Michael Gilfix <mgilfix@eecs.tufts.edu>
#
# Copyright (c) 2002 Michael Gilfix <mgilfix@eecs.tufts.edu>
#                    All rights reserved.
#
dnl Process this file with autoconf to produce a configure script.

PACKAGE=peepd

MAJOR_VERSION=0
MINOR_VERSION=5
PATCH_VERSION="0-rc2"
VERSION=${MAJOR_VERSION}.${MINOR_VERSION}.${PATCH_VERSION}

dnl Perform initialization process
AC_INIT(peepd, 0.5.0-rc2, "mgilfix@eecs.tufts.edu")
AC_CONFIG_SRCDIR([server/mixer.c])
AC_PREREQ(2.53)
AM_INIT_AUTOMAKE($PACKAGE, $VERSION)
AM_CONFIG_HEADER([config.h])

dnl Define templates for autoheader constants
AH_TEMPLATE(DEBUG_LEVEL, [ ])
AH_TEMPLATE(DEFAULT_CONFIG_PATH, [ ])
AH_TEMPLATE(__LINUX__, [ ])
AH_TEMPLATE(__SOLARIS__, [ ])
AH_TEMPLATE(__BSD__, [ ])
AH_TEMPLATE(__USING_OSS__, [ ])
AH_TEMPLATE(__USING_ALSA__, [ ])
AH_TEMPLATE(STATIC_VOLUME, [ ])
AH_TEMPLATE(DYNAMIC_VOLUME, [ ])
AH_TEMPLATE(WITH_TCP_SERVER, [ ])
AH_TEMPLATE(WITH_UDP_SERVER, [ ])
AH_TEMPLATE(WITH_OPENSSL, [ ])

dnl Define the default location peep.conf relative to the
dnl installation prefix
if test $prefix = NONE; then
    SYSCONFDIR="/etc/peep/peep.conf"
else
    SYSCONFDIR="$prefix/etc/peep/peep.conf"
fi
AC_DEFINE_UNQUOTED(DEFAULT_CONFIG_PATH, "$SYSCONFDIR")

dnl Evaluate Options
AC_ARG_ENABLE(debug,
[  --enable-debug=[level] These are currently defined to be:

       0 - Lowest:  Prints default output and general debugging info.
       1 - Lower:   Lowest debuging and server info.
       2 - Medium:  Lower debugging, playback and engine info.
       3 - Higher:  Medium debugging and mixer, auto-discovery, and code hook info.
       4 - Highest: Higher debugging and queueing info.
       5 - Highest: Highest debugging with Assertions (whoa! this WILL slow down execution)

],
[case "${enableval}" in
    0)
        AC_MSG_RESULT(using lowest debugging output level...)
        AC_DEFINE(DEBUG_LEVEL, DBG_LOWEST)
    ;;
    1)
        AC_MSG_RESULT(using lower debugging output level...)
        AC_DEFINE(DEBUG_LEVEL, DBG_LOWER)
    ;;
    2)
        AC_MSG_RESULT(using medium debugging output level...)
        AC_DEFINE(DEBUG_LEVEL, DBG_MEDIUM)
    ;;
    3)
        AC_MSG_RESULT(using higher debugging output level...)
        AC_DEFINE(DEBUG_LEVEL, DBG_HIGHER)
    ;;
    4)
        AC_MSG_RESULT(using highest debugging output level...)
        AC_DEFINE(DEBUG_LEVEL, DBG_HIGHEST)
    ;;
    5)
        AC_MSG_RESULT(using highest debugging output level and code assertions...)
        AC_DEFINE(DEBUG_LEVEL, DBG_ALL_W_ASSERT)
    ;;
    *)
        AC_MSG_RESULT(using highest debugging output level and code assertions...)
        AC_DEFINE(DEBUG_LEVEL, DBG_ALL_W_ASSERT)
    ;;
esac],
[ AC_DEFINE(DEBUG_LEVEL, DBG_LOWEST) ]
)

dnl Figure out which server type we're using

SERVER_TYPE=""
AC_ARG_ENABLE(tcp-server,
[  --enable-tcp-server  (Compile with TCP server routines) ],
[ SERVER_TYPE="tcp" ])
AC_ARG_ENABLE(udp-server,
[  --enable-udp-server  (Compile with UDP server routines) ],
[ SERVER_TYPE="udp" ])
AC_ARG_ENABLE(openssl,
[  --enable-openssl     (Compile with OpenSSL support) ],
[ SERVER_TYPE="ssl" ])

case "$SERVER_TYPE" in
    tcp)
        AC_MSG_RESULT(compiling using tcp server routines...)
        AC_DEFINE(WITH_TCP_SERVER)
    ;;
    udp)
        AC_MSG_RESULT(compiling using udp sever routines...)
        AC_DEFINE(WITH_UDP_SERVER)
    ;;
    ssl)
        AC_MSG_RESULT(compiling with OpenSSL routines...)
        AC_DEFINE(WITH_OPENSSL)
    ;;
    *)
        AC_MSG_RESULT(compiling using tcp server routines...)
        AC_DEFINE(WITH_TCP_SERVER)
    ;;
esac

dnl Let's figure out what kind of mixing to use
AC_ARG_WITH(dynamic-volume,
[  --with-dynamic-volume  (Volume of sounds change with context -- Default) ],
AC_DEFINE(DYNAMIC_VOLUME)
)

static_volume=no
AC_ARG_WITH(static-volume,
[  --with-static-volume   (Volume of sounds are set at a constant to avoid clipping.) ],
[ AC_DEFINE(STATIC_VOLUME)
  static_volume=yes ]
)

dnl Now let's put our default if we didn't use static
if test "$static_volume" = "no"; then
    AC_DEFINE(DYNAMIC_VOLUME)
fi

dnl Figure out which sound device to use for compilation
snd_driver=""

AC_ARG_WITH(alsa-driver,
[  --with-alsa-driver (Compile to use alsa libraries for audio output.) ],
[ AC_DEFINE(__USING_ALSA__)
  snd_driver="alsa"
  AC_CHECK_LIB(asound, snd_pcm_open,
               [ LIBS="$LIBS -lasound"],
               [ AC_MSG_ERROR(Can't find asound library!) ])]
)

AC_ARG_WITH(oss-driver,
[  --with-oss-driver (Compile with /dev/audio support.) ],
[ AC_DEFINE(__USING_OSS__)
  snd_driver="oss" ])

if test "$snd_driver" = ""; then
    AC_DEFINE(__USING_OSS__)
fi
dnl End of sound driver configuration


# Checks for programs.
AC_PROG_CC
AC_PROG_INSTALL
AC_PROG_MAKE_SET
AC_PROG_AWK
AC_PROG_RANLIB

# Checks for libraries.
AC_CHECK_LIB(m, log)
AC_CHECK_LIB(socket, socket)
AC_CHECK_LIB(nsl, gethostbyname)

dnl For XML handling - the lovely expat
AC_ARG_WITH(expat,
[  --with-expat=path (Expat Prefix) ],
[with_expat="$withval"],
[with_expat=no])

if test "$with_libxerces_includes" != "no"; then
    CPPFLAGS="${CPPFLAGS} -I${with_expat}/include"
    LDFLAGS="${LDFLAGS}  -L${with_expat}/lib"
fi

AC_CHECK_LIB(expat, XML_ParserCreate, [],
[ AC_MSG_ERROR(Couldn't find the expat library and header!
    Peep requires the expat XML parsing library to compile.
    Expat can be obtained at: http://expat.sourceforge.net.)
])

dnl Handle some host specific stuff
AC_CANONICAL_HOST
case "$host" in
  *-*-linux*)
    AC_MSG_RESULT(compiling with Linux host definitions...)
    AC_DEFINE(__LINUX__)
    AC_CHECK_LIB(pthread, pthread_create)
  ;;
  *-*-solaris*)
    AC_MSG_RESULT(compiling with Solaris host definitions...)
    AC_DEFINE(__SOLARIS__)
    AC_CHECK_LIB(pthread, pthread_create)
    AC_CHECK_LIB(rt, sem_init,
                 [ LIBS="$LIBS -lrt" ],
                 [ AC_MSG_ERROR(couldn't find the rt library for semaphores...) ])
    AC_CHECK_LIB(resolv, inet_aton,
                 [ LIBS="$LIBS -lresolv" ],
                 [ AC_MSG_ERROR(couldn't find the resolv library for inet_aton...) ])
  ;;
  *-*-*bsd*)
    AC_MSG_RESULT(compiling with BSD host definitions...)
    AC_DEFINE(__BSD__)

    # Try to link in the BSD OSS compatible audio library if we can
    # find it
    AC_CHECK_LIB(ossaudio, ioctl,
                 [ LIBS="$LIBS -lossaudio" ],
                 [ AC_MSG_ERROR(couldn't find the linux audio compat library) ])

    # Try to find the threading library. First we check for pthread
    # to see if the pthread port exists. Otherwise, we use the
    # threading c_r library
    threading=no
    AC_CHECK_LIB(pthread, pthread_create,
                 [ LIBS="$LIBS -lpthread"
                   threading=yes ],
                 [ threading=no ])
    if test "$threading" = "no"; then
      AC_CHECK_LIB(c_r, pthread_create,
                 [ LIBS="$LIBS -lc_r"
                   threading=yes ],
                 [ threading=no ])
    fi
    if test "$threading" = "no"; then
      AC_MSG_ERROR(can't find either the pthread or c_r library for threading support...)
    fi
  ;;
  *)
    AC_WARN(***)
    AC_WARN(Your system isn't directly supported. Attempting to compile with Linux options...)
    AC_WARN(***)
    AC_DEFINE(__LINUX__)
    AC_CHECK_LIB(pthread, pthread_create)
  ;;
esac

# Checks for header files.
AC_HEADER_DIRENT
AC_HEADER_STDC
AC_CHECK_HEADERS([arpa/inet.h fcntl.h memory.h netdb.h netinet/in.h stdlib.h string.h strings.h sys/ioctl.h sys/socket.h sys/time.h unistd.h])

# Checks for typedefs, structures, and compiler characteristics.
AC_C_CONST
AC_C_BIGENDIAN
AC_TYPE_SIZE_T
AC_HEADER_TIME
AC_STRUCT_TM

# Checks for library functions.
AC_FUNC_FORK
AC_PROG_GCC_TRADITIONAL
AC_FUNC_MALLOC
AC_FUNC_MKTIME
AC_TYPE_SIGNAL
AC_FUNC_STAT
AC_FUNC_STRTOD
AC_CHECK_FUNCS([alarm gethostbyname gethostname gettimeofday inet_ntoa memset select socket strcasecmp strerror strstr])

############################################################
# OpenSSL section
#############################################################

AC_ARG_WITH(openssl-includes,
    [  --with-openssl-includes=DIR  OpenSSL include directory],
    [with_openssl_includes="$withval"],
    [with_openssl_includes=no])

if test "$with_openssl_includes" != "no"; then
   CPPFLAGS="${CPPFLAGS} -I${with_openssl_includes}"
fi

AC_ARG_WITH(openssl-libraries,
    [  --with-openssl-libraries=DIR   OpenSSL library directory],
    [with_openssl_libraries="$withval"],
    [with_openssl_libraries=no])

if test "$with_openssl_libraries" != "no"; then
   LDFLAGS="${LDFLAGS}  -L${with_openssl_libraries}"
fi

if test "$SERVER_TYPE" = ssl; then
   AC_MSG_CHECKING(for OpenSSL libraries...)
   USE_OPENSSL=""
   OLDLIBS="$LIBS"
   LIBS="$LIBS -lssl -lcrypto"
   AC_TRY_LINK([
     #include <openssl/rsa.h>
     #include <openssl/crypto.h>
     #include <openssl/x509.h>
     #include <openssl/pem.h>
     #include <openssl/ssl.h>
     #include <openssl/err.h>
   ],
   [
    SSL_METHOD *meth;
    SSL_CTX *ctx;

    OpenSSL_add_all_algorithms ();
    meth = SSLv23_server_method ();
    ctx = SSL_CTX_new (meth);
   ],
   [
    USE_OPENSSL=yes
   ],
   [
    USE_OPENSSL=no
    LIBS="$OLDLIBS"
   ])

   if test "$USE_OPENSSL" = "no"; then
     AC_MSG_RESULT(no)
     AC_MSG_ERROR(Could not find the openssl library. You must first install OpenSSL.)
   else
     AC_MSG_RESULT(yes)
   fi

   AC_CHECK_HEADERS(openssl/rsa.h openssl/crypto.h openssl/x509.h openssl/pem.h openssl/ssl.h openssl/err.h)
fi

############################################################
# End OpenSSL
#############################################################

AC_CONFIG_FILES([Makefile
                 server/Makefile])
AC_OUTPUT
