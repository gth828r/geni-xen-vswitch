print_openflow_port_by_dev() {
    BRIDGE=$1
    DEV=$2

    LINE=`ovs-ofctl show $BRIDGE | grep $DEV`

    if [ -n "$LINE" ]; then
        OF_PORT=`echo $LINE | cut -d'(' -f 1`
        echo $OF_PORT
        return 0
    else
        OF_PORT=""
        return 1
    fi
}
