function gettop
{
    local TOPFILE=build/core/main.mk
    if [ -n "$TOP" -a -f "$TOP/$TOPFILE" ] ; then
        # The following circumlocution ensures we remove symlinks from TOP.
        (cd $TOP; PWD= /bin/pwd)
    else
        if [ -f $TOPFILE ] ; then
            # The following circumlocution (repeated below as well) ensures
            # that we record the true directory name and not one that is
            # faked up with symlink names.
            PWD= /bin/pwd
        else
            local HERE=$PWD
            T=
            while [ \( ! \( -f $TOPFILE \) \) -a \( $PWD != "/" \) ]; do
                \cd ..
                T=`PWD= /bin/pwd -P`
            done
            \cd $HERE
            if [ -f "$T/$TOPFILE" ]; then
                echo $T
            fi
        fi
    fi
}

# Clear this variable.  It will be built up again when the vendorsetup.sh
# files are included at the end of this file.
unset LUNCH_MENU_CHOICES
function add_lunch_combo()
{
   local new_combo=$1
   local c
   for c in ${LUNCH_MENU_CHOICES[@]} ; do
       if [ "$new_combo" = "$c" ] ; then
           return
       fi
   done
   LUNCH_MENU_CHOICES=(${LUNCH_MENU_CHOICES[@]} $new_combo)
}

function add_toolchain_combo()
{
   local new_combo=$1
   local c
   for c in ${TOOLCHAIN_CHOICES[@]} ; do
       if [ "$new_combo" = "$c" ] ; then
           return
       fi
   done
   TOOLCHAIN_CHOICES=(${TOOLCHAIN_CHOICES[@]} $new_combo)
}

function print_lunch_menu()
{
   local uname=$(uname)
   echo
   echo "You're building on" $uname
   echo
   echo "Lunch menu... pick a combo:"

   local i=1
   local choice
   for choice in ${LUNCH_MENU_CHOICES[@]}
   do
       echo " $i. $choice "
       i=$(($i+1))
   done | column

   echo
}

function print_toolchain_menu()
{
   echo "Toolchain menu... please choose"

   local i=1
   local choice
   for choice in ${TOOLCHAIN_CHOICES[@]}
   do
       echo " $i. $choice "
       i=$(($i+1))
   done | column

   echo
}
function toolchain()
{
    local answer

    if [ "$1" ] ; then
        answer=$1
    else
        print_toolchain_menu
        echo -n "Which would you like?"
        read answer
    fi

    local selection=

    if [ -z "$answer" ]
    then
        lunch
    elif (echo -n $answer | grep -q -e "^[0-9][0-9]*$")
    then
        if [ $answer -le ${#TOOLCHAIN_CHOICES[@]} ]
        then
            selection=${TOOLCHAIN_CHOICES[$(($answer-1))]}
        fi
    elif (echo -n $answer | grep -q -e "^[^\-][^\-]*-[^\-][^\-]*$")
    then
        selection=$answer
    fi

    if [ -z "$selection" ]
    then
        echo
        echo "Invalid toolchain: $answer"
        return 1
    fi
    toolchain=$selection
    check_toolchain $toolchain
    if [ ! -d toolchains/$(echo -n $toolchain | sed -e 's\-\/\') ]
    then
        # if we can't find a product, try to grab it off github
        T=$(gettop)
        pushd $T > /dev/null
        build/tools/roomservice.py $toolchain
        popd > /dev/null
        check_toolchain $toolchain
    else
        build/tools/roomservice.py $toolchain true
    fi
    if [ $? -ne 0 ]
    then
        echo
        echo "** Don't have a product spec for: '$product'"
        echo "** Do you have the right repo manifest?"
        toolchain=
    fi
}

function lunch()
{
    local answer

    if [ "$1" ] ; then
        answer=$1
    else
        print_lunch_menu
        echo -n "Which would you like?"
        read answer
    fi

    local selection=

    if [ -z "$answer" ]
    then
        lunch
    elif (echo -n $answer | grep -q -e "^[0-9][0-9]*$")
    then
        if [ $answer -le ${#LUNCH_MENU_CHOICES[@]} ]
        then
            selection=${LUNCH_MENU_CHOICES[$(($answer-1))]}
        fi
    elif (echo -n $answer | grep -q -e "^[^\-][^\-]*-[^\-][^\-]*$")
    then
        selection=$answer
    fi

    if [ -z "$selection" ]
    then
        echo
        echo "Invalid lunch combo: $answer"
        return 1
    fi

    local product=$(echo -n $selection | sed -e "s/-.*$//")
    echo "$product"
    unset DEVICE_MAKEFILE
    check_product $product
    if [ ! $DEVICE_MAKEFILE ]
    then
        # if we can't find a product, try to grab it off github
        T=$(gettop)
        pushd $T > /dev/null
        build/tools/roomservice.py $product
        popd > /dev/null
        check_product $product
    else
        build/tools/roomservice.py $product true
    fi
    if [ $? -ne 0 ]
    then
        echo
        echo "** Don't have a product spec for: '$product'"
        echo "** Do you have the right repo manifest?"
        product=
    fi

    local variant=$(echo -n $selection | sed -e "s/^[^\-]*-//")
    check_variant $variant
    if [ $? -ne 0 ]
    then
        echo
        echo "** Invalid variant: '$variant'"
        echo "** Must be one of ${VARIANT_CHOICES[@]}"
        variant=
    fi

    if [ -z "$product" -o -z "$variant" ]
    then
        echo
        return 1
    fi

    export TARGET_PRODUCT=$product
    export TARGET_BUILD_VARIANT=$variant

    echo
    toolchain
    printconfig
}

VARIANT_CHOICES=(kernel anykernel bootimg)

# check to see if the supplied variant is valid
function check_variant()
{
    for v in ${VARIANT_CHOICES[@]}
    do
        if [ "$v" = "$1" ]
        then
            return 0
        fi
    done
    return 1
}

function check_product()
{
    T=$(gettop)
    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree.  Try setting TOP." >&2
        return
    fi

    if [ $(grep -rl "$1" ./device/*/$(echo -n $1 | sed -e 's/^black_//g')/black.mk) ] ; then
       export BLACK_PRODUCT=$(echo -n $1 | sed -e 's/^black_//g')
       export DEVICE_MAKEFILE=$(grep -rl "$1" device/*/$BLACK_PRODUCT/black.mk)
       unset TOOLCHAIN_CHOICES       
       . device/*/$BLACK_PRODUCT/toolchainsetup.sh
    else
       echo "Configuration makefile for $1 device not found.. "
       echo "Calling for room service .. "
    fi
}

function check_toolchain()
{
    T=$(gettop)
    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree.  Try setting TOP." >&2
        return
    fi

    if [ -d ./toolchains/$(echo -n $1 | sed -e 's\-\/\g') ] ; then
       export BLACK_TOOLCHAIN=$(echo -n $1 | sed -e 's\-\/\g')
    else
       echo "Configuration for $1 toolchain not found.. "
       echo "Calling for room service .. "
    fi
}


# Get the exact value of a build variable.
function get_build_var()
{
    T=$(gettop)
    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree.  Try setting TOP." >&2
        return
    fi
    (\cd $T; CALLED_FROM_SETUP=true BUILD_SYSTEM=build/core \
      command make --no-print-directory -f build/core/config.mk dumpvar-$1)
}

function printconfig()
{
    T=$(gettop)
    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree.  Try setting TOP." >&2
        return
    fi
    get_build_var report_config
}

function get_make_command()
{
  echo command make
}

function make()
{
    local start_time=$(date +"%s")
    $(get_make_command) "$@"
    local ret=$?
    local end_time=$(date +"%s")
    local tdiff=$(($end_time-$start_time))
    local hours=$(($tdiff / 3600 ))
    local mins=$((($tdiff % 3600) / 60))
    local secs=$(($tdiff % 60))
    echo
	if [ $ret -eq 0 ] ; then
		echo -n -e "#### \033[32mMake completed successfully\033[0m "
	else
		echo -n -e "#### \033[31mMake failed to build some targets\033[0m "
	fi
    if [ $hours -gt 0 ] ; then
        printf "(%02g:%02g:%02g (hh:mm:ss))" $hours $mins $secs
    elif [ $mins -gt 0 ] ; then
        printf "(%02g:%02g (mm:ss))" $mins $secs
    elif [ $secs -gt 0 ] ; then
        printf "(%s seconds)" $secs
    fi
    echo -e " ####"
    echo
    return $ret
}

if [ "x$SHELL" != "x/bin/bash" ]; then
    case `ps -o command -p $$` in
        *bash*)
            ;;
        *zsh*)
            ;;
        *)
            echo "WARNING: Only bash and zsh are supported, use of other shell may lead to erroneous results"
            ;;
    esac
fi

# Execute the contents of any vendorsetup.sh files we can find.
for f in `test -d device && find -L device -maxdepth 4 -name 'vendorsetup.sh' 2> /dev/null` \
         `test -d vendor && find -L vendor -maxdepth 4 -name 'vendorsetup.sh' 2> /dev/null`
do
    echo "including $f"
    . $f
done
unset f

export CORE_COUNT=$(cat /proc/cpuinfo | grep "^processor" | wc -l)
export ANDROID_BUILD_TOP=$(gettop)
export OUT_DIR=$(get_build_var OUT_DIR)
echo 'Remember to "lunch" your device'
echo "Type help for functions and targets"
function help()
{
cat <<EOF
make kernel - will build source with $CORE_COUNT threads
make kernelclean - cleans source
make kernelclobber - cleans source & removes zImage from $OUT_DIR
make buildzip - builds flashable zip file (dependent on a successful make kernel attempt)
make black - runs make kernel then make buildzip in succession
EOF
}
