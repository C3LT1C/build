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
    check_product $product
    if [ ! $DEVICE_MAKEFILE ]
    then
        # if we can't find a product, try to grab it off the RenderKernels github
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
    export TARGET_BUILD_TYPE=release

    echo
}

VARIANT_CHOICES=(kernel anykernel)

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

    if (echo -n $1) ; then
       export RENDER_PRODUCT=$(echo -n $1 | sed -e 's/^render_//g')
       export DEVICE_MAKEFILE=$(grep -rl "$1" ./device/*/$RENDER_PRODUCT/render.mk)
    else
       RENDER_PRODUCT=
    fi
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

export ANDROID_BUILD_TOP=$(gettop)
export OUT_DIR=$ANDROID_BUILD_TOP/out/$RENDER_PRODUCT
