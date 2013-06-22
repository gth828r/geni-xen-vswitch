##
# Prepare the installation mechanism
##
prepare_for_install() {
    apt-get update
}

##
# Install the vSwitch software
# 
# DEPENDS ON: prepare_for_install
##
install_vswitch_software() {
    # Install ovs and run it
    apt-get install -y openvswitch-common openvswitch-switch \
                       openvswitch-datapath-source
    module-assistant auto-install openvswitch-datapath
}

##
# Create a bridge for patching traffic between the correct
# experimental bridge and the shared physical NIC
#
# PARAMETERS:
##
create_infrastructure_bridge() {
    local INFRASTRUCTURE_BRIDGE=$1
    local UPLINK_DEV=$2

    # Create infrastructure bridge
    ovs-vsctl add-br $INFRASTRUCTURE_BRIDGE

    # Add data vswitch uplink
    ovs-vsctl add-port $INFRASTRUCTURE_BRIDGE $UPLINK_DEV

    # Bring up bridge
    ip link set dev $INFRASTRUCTURE_BRIDGE up

    # Do we need to remove any flows from this bridge?
    # ovs-ofctl del-flows $INFRASTRUCTURE_BRIDGE 
}

##
# Create an experimental bridge for non-OF experiments
##
create_nonof_bridge() {
    local NON_OF_BRIDGE=$1
    local INFRASTRUCTURE_BRIDGE=$2

    # Create the experimental bridge itself
    ovs-vsctl add-br $NON_OF_BRIDGE

    # Create the plumbing from the experimental bridge to the
    # infrastructure bridge
    ovs-vsctl add-port $NON_OF_BRIDGE $NON_OF_BRIDGE-ul
    ovs-vsctl add-port $INFRASTRUCTURE_BRIDGE $NON_OF_BRIDGE-dl
    ovs-vsctl set Interface $NON_OF_BRIDGE-ul type=patch \
        options:peer=$NON_OF_BRIDGE-dl
    ovs-vsctl set Interface $NON_OF_BRIDGE-dl type=patch \
        options:peer=$NON_OF_BRIDGE-ul

    # Bring up bridge
    ip link set dev $NON_OF_BRIDGE up
}

##
# Create an experimental bridge for OF experiments
##
create_of_bridge() {
    local OF_BRIDGE=$1
    local INFRASTRUCTURE_BRIDGE=$2
    local CONTROLLER_IP=$3
    local CONTROLLER_PORT=$4

    # Create the experimental bridge itself
    ovs-vsctl add-br $OF_BRIDGE

    # Create the plumbing from the experimental bridge to the
    # infrastructure bridge
    ovs-vsctl add-port $OF_BRIDGE $OF_BRIDGE-ul
    ovs-vsctl add-port $INFRASTRUCTURE_BRIDGE $OF_BRIDGE-dl
    ovs-vsctl set Interface $OF_BRIDGE-ul type=patch \
        options:peer=$OF_BRIDGE-dl
    ovs-vsctl set Interface $OF_BRIDGE-dl type=patch \
        options:peer=$OF_BRIDGE-ul

    # Bring up bridge
    ip link set dev $NON_OF_BRIDGE up

    # Point bridge at appropriate controller, avoid OVS preinstalled flows,
    # and put the switch in fail-secure mode
    ovs-ofctl del-flows $NON_OF_BRIDGE 
    ovs-vsctl set-controller expofbr tcp:$CONTROLLER_IP:$CONTROLLER_PORT
    ovs-vsctl set controller expofbr connection-mode=out-of-band
    ovs-vsctl set-fail-mode expofbr secure
}

configure_interface_on_nonof_bridge() {
    local VIF=$1
    local VLAN=$2

    # INFRASTRUCTURE_BRIDGE and OF port numbers on it 
    local INFRASTRUCTURE_BRIDGE=$3
    local UPLINK_PORT=$4
    local NON_OF_BRIDGE_PORT=$5
    
    # Make switchport corresponding to VM an access port
    #xm network-attach bridge=$BRIDGE ip=$IP_ADDRESS
    # ovs-vsctl add-port (called in Xen scripts)
    ovs-vsctl set port $VIF tag=$VLAN

    # Set up plumbing in infrastructure switch    
    ovs-ofctl add-flow $INFRASTRUCTURE_BRIDGE \
        in_port=$UPLINK_PORT,dl_vlan=$VLAN,action=output:$NON_OF_BRIDGE_PORT
    ovs-ofctl add-flow $INFRASTRUCTURE_BRIDGE \
        in_port=$NON_OF_BRIDGE_PORT,dl_vlan=$VLAN,action=output:$UPLINK_PORT
}

configure_interface_on_of_bridge() {
    local VIF=$1
    local VLAN=$2

    # INFRASTRUCTURE_BRIDGE and OF port numbers on it 
    local INFRASTRUCTURE_BRIDGE=$3
    local UPLINK_PORT=$4
    local OF_BRIDGE_PORT=$5
    
    # Make switchport corresponding to VM an access port
    #xm network-attach bridge=$BRIDGE ip=$IP_ADDRESS

    # ovs-vsctl add-port (called in Xen scripts)
    ovs-vsctl set port $VIF

    # Set up plumbing in infrastructure switch    
    ovs-ofctl add-flow $INFRASTRUCTURE_BRIDGE \
        in_port=$UPLINK_PORT,dl_vlan=$VLAN,action=strip_vlan,output:$OF_BRIDGE_PORT
    ovs-ofctl add-flow $INFRASTRUCTURE_BRIDGE \
        in_port=$OF_BRIDGE_PORT,action=mod_vlan_vid:$VLAN,output:$UPLINK_PORT
}
