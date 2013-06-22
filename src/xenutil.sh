print_domain_id_by_hostname() {
    HOSTNAME=$1

    LINE=`xm list | grep $HOSTNAME`

    if [ -n "$LINE" ]; then
        DOM_ID=`echo $LINE | tr -s ' ' | cut -d' ' -f 2`
        echo $DOM_ID
        return 0
    else
        echo ""
        return 1
    fi
}

print_vif_by_mac() {
    MAC=$1

}
