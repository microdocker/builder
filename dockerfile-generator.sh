#!/bin/bash
declare -A LIBS LINKS PORTS

function getlibs {
  local bin=$1
  for f in $(ldd $bin|grep /|awk -F '=> ' '{if(NF==2)print $2;else print $1}'|awk '{print $1}'); do
    if [ -L $f ]; then
      LINKS[$f]=a
    elif [ -f $f ]; then
      LIBS[$f]=a
    fi
  done
}

function usage {
  (
    echo "Usage: $0 -b /path/to/binary/file -d /path/to/files/to/add"
    echo ""
    echo "Required Options:"
    echo "  -b The absolute path to your binary file."
    echo "     It will be the same as the entry point of the docker image."
    echo ""
    echo "Optional Options:"
    echo "  -d The files you want to add to the image."
    echo "     All files must within the same directory."
    echo "     The directory structure of the files will be mapped to the target image."
    echo ""
    echo "  -p The port you want to expose."
    echo "     This option can be specified multiple times."
  )>&2
  exit 1
}

function err_exit {
  echo "$1" >&2
  exit 1
}

declare -i port
while getopts ":b:d:p:" o; do
  case "${o}" in
    b)
      BIN=${OPTARG}
      [ -f $BIN ] || usage
      ;;
    d)
      DATA=${OPTARG}
      [ -d $DATA ] || usage
      ;;
    p)
      port=${OPTARG}
      if [ $port -lt 1 ] || [ $port -gt 65535 ]; then
        err_exit "port must between 1 and 65535"
      fi
      PORTS["$port"]=a
      ;;
    *)
      usage
      ;;
  esac
done
shift $((OPTIND-1))

[ -n "$BIN" ] || usage

TMP_PATH=/tmp/`head -c 1000 /dev/urandom |tr -dc 'a-z0-9A-Z'|tail -c 10`
mkdir -p $TMP_PATH

function cleanup {
  echo "Removing temporary directory $TMP_PATH"
  test "$TMP_PATH" = "/tmp" || rm -fr $TMP_PATH
}
#trap cleanup EXIT

DOCKERFILE=$TMP_PATH/Dockerfile
DEST_LIBS_DIR=$TMP_PATH/lib
DEST_BIN_DIR=$TMP_PATH/bin
DEST_DATA_DIR=$TMP_PATH/data
mkdir $DEST_LIBS_DIR
mkdir $DEST_BIN_DIR
echo "FROM busybox:latest" >> $DOCKERFILE

# add user specified data path
if [ -n "$DATA" ]; then
  cp -r $DATA $DEST_DATA_DIR
  (
    cd $DEST_DATA_DIR
    for f in $(find .); do
      [ $f = "." ] && continue
      dstpath=$(echo $f|awk '{print substr($1, 2)}')
      echo "ADD data$dstpath $dstpath" >> $DOCKERFILE
    done
  )
fi

# resolve libs and copy binary files to build path
getlibs $BIN
cp $BIN $DEST_BIN_DIR
echo "ADD bin/$(basename $BIN) $BIN" >> $DOCKERFILE

# copy lib files to build path
for lib in ${!LIBS[*]}; do
  cp $lib $DEST_LIBS_DIR
  echo "ADD lib/$(basename $lib) /lib/$(basename $lib)" >> $DOCKERFILE
done

# reslove symlinks and copy the target file to build path
for link in ${!LINKS[*]}; do
  ldir=$(dirname $link)
  target_name=$(readlink $link)
  name=$(basename $target_name)
  if echo $target_name|grep -qP '^/'; then
    cp $target_name $DEST_LIBS_DIR
  else 
    (
      cd $ldir
      cp $target_name $DEST_LIBS_DIR
    )
  fi
  echo "ADD lib/$name /lib/$name" >> $DOCKERFILE
  echo "RUN ln -sf /lib/$name /lib/$(basename $link)" >> $DOCKERFILE
done

echo "CMD [\"$BIN\"]" >> $DOCKERFILE

for p in ${!PORTS[*]}; do
  echo "EXPOSE $p" >> $DOCKERFILE
done

echo "The Dockerfile has been successfully generated and saved to $DOCKERFILE"
echo "You can build the image by run 'cd $TMP_PATH && docker build -t xxx .'"
