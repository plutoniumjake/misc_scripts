#!/bin/bash
# bash mount.sh /dev/rootfs /mnt/point

# dlau@liquidweb.com
# I am sure this will have some strangeness for things I didn't think of.
# So let me know. Plz to provide scenerio


VERSION=0.1

txtgrn='\e[0;32m' # Green
txtrst='\e[0m'    # Text Reset
txtylw='\e[0;33m' # Yellow
declare -A Sane
Sane=( ["/usr"]="local" ["/var"]="run" ["/"]="/opt" )
IsDryRun=false
Interactive=false

if [ -t 1 ] ; then
	Interactive=true 
fi

SanityCheck(){
	for K in ${!Sane[@]} ;do
		if ! [ -e $MountPoint/$K/${Sane[$K]} ] ; then
			warn "Sanity check failed. $MountPoint/$K/${Sane[$K]} does not exist"
			return 0
		fi
	done

}
ShouldShh(){
	if ! [ -z "$BeQuiet" ] ; then return 0 ; fi
	return 1
}
function dbg_msg {
	if [[ -z "$DEBUG" ]] ; then return ; fi
	echo -e $@ >&2
}
info(){
	if ShouldShh; then return ; fi
	echo -e "$@" >&2
}
fake_mount(){
	if $Interactive ;  then
		echo -e "${txtgrn}mount $@ $txtrst"
	else
		echo mount $@
	fi
}

warn(){
	if ShouldShh ; then return ; fi
	echo -e "${txtylw}$@${txtrst}" >&2
}

function print_help {
echo "\
	mount assist $VERSION

Help to quickly mount an OS install based on its fstab. Can set up an environment suitable for chroot.
Always ignores /backup ( --ignore=/backup) 
If you wish to review the commands that would be run you can use --dryrun and redirect to a file.
	mount.sh /bah /blah --dryrun > commands 
	less commands
	bash commands


usage:
	mount.sh [ /dev/root_partition ] [/mnt/wheretomount] [OPTIONS]

Options:
	--ignore=/mntpnt 
	-chroot      mount proc,sys,dev
	-ro      mounts partitions readonly (plus noload)
	--dryrun     just print what will be done ( / will need to be mounted )
	--quiet
	--debug      print more misc info
	==============================
	--help,-h   show this junk
"
}

ReadOnly=false
IGNORE=("/backup" "/")
MountCmd="mount"
if [ $# -lt 2 ]; then
	print_help
	exit
fi

function get_device_ {
	case $1 in 
		/dev/*)
			info $1 
			;;
		LABEL*|UUID*)
			$(blkid -o device -t $1 $2)
			;;
	esac
}

function ignore_mnt {
	for  ((i=0;i<=${#IGNORE[@]};i++)) ; do
		if [[ "$1" == "${IGNORE[$i]}" ]] ; then
			return 0
		fi 
	done
	return 1 
}

function ignore_fs {
	echo
}
RootDevice=
RootPart=$1
MountPoint=$2

FSTAB=${MountPoint}/etc/fstab

shift 1 

CHROOT=no
mountopts=""
while shift ; do
	case $1 in
		-chroot)
			CHROOT=yes 
			;;
		-ro)
			mountopts="-o ro,noload"
			ReadOnly=true
			;;
		--debug)
			DEBUG="yeah."
			;;
		--dryrun)
			MountCmd='fake_mount'
			IsDryRun=true
			;;
		--quiet)
			BeQuiet="yeahshutup"
			;;
		--help|-h)
			print_help
			exit 1
			;;
		--ignore=*)
			IGNORE+=("${1##--ignore=}")
	esac
done


dbg_msg "Debugging on"
if ! $MountCmd $RootPart $MountPoint $mountopts; then 
	warn "Couldn't mount root device, quitting"
	exit 1
fi

# resolve label or uuid to actual device.
RootPart=$(get_device_ $RootPart)

# assuming we are using a partion ON a device and not the whole thing (or... 
#    what would you expect this script to do?)
RootDevice=${RootPart%%[0-9]}

if [ ! -r $FSTAB ] ; then 
	warn "There isn't an /etc/fstab on $RootPart. Not sure what you want me to do buddy."
	umount $MountPoint
	exit
fi

Mounted=("$MountPoint" "other")
AddMount(){
	Mounted+=($@)
}
E2FS='ext[234]'

TmpFile=$(mktemp)
cat $FSTAB | 
	sed 's/#.*$//' |                    # strip comments
	sed -r 's/\s+/ /g' |                # replace all sections of whitespace with single space
	grep -v -E  '^[[:space:]]?*$' |      # kill empty lines.
	cat > $TmpFile


exec 3< $TmpFile
while read -u 3 BLKID MP FS OP IGNOREME;do 
	dbg_msg "Trying to resolve $BLKID"
		if ignore_mnt "$MP" ; then continue ; fi
		if ! [[ "$FS" =~ $E2FS ]] ; then
				dbg_msg "ignoring fs $FS"
				continue;
		fi

		case $BLKID in
			LABEL=*|UUID=*)
				obid=$BLKID
				BLKID=$(blkid -o device -t $BLKID $RootDevice*)
				if [[ -z "$BLKID" ]] ; then
						warn "got no result from 'blkid -o device -t $obid $RootDevice*'"
						warn "going to try mount with original $obid"
						BLKID=$obid
				else
				dbg_msg "Came up with $BLKID"
				fi
				;;
			/dev/*)
				 echo -n 
			;;
			*)
				warn "device id '$BLKID' is strange and scary to me"
			;;
		esac
		if [ ! -d $MountPoint/$MP ] ; then
		if $ReadOnly ; then
			warn "$MountPoint/$MP does not exist, and mounting read-only... so I can't fix it."
			warn "skipping $MountPoint/$MP"
			continue
		else
			info "creating dir $MountPoint/$MP"
				mkdir $MountPoint/$MP
		fi
		fi
		dbg_msg $MountCmd $BLKID $MountPoint/$MP -t $FS $mountopts
		if ! $MountCmd $BLKID $MountPoint/$MP -t $FS $mountopts ; then
				warn "unable to mount $MountPoint/$MP"
		else
				Mounted+=("$MountPoint/$MP") # this does nothing as nothing within the while is exported
		fi

done
3>&-
rm $TmpFile

if [[ $CHROOT == 'yes' ]] ; then 
	info "Setting up virtual filesystems"
	for B in sys proc dev ; do
	$MountCmd --bind /$B $MountPoint/$B
	done
fi
if ! $IsDryRun ; then SanityCheck ; fi

warn "Please double check that this is right before you go all rsyncy over it."
info "Done."
