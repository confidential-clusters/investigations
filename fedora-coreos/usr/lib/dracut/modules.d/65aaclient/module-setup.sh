#!/bin/bash

check() {
    # Always include the module for now
    return 0
}

depends() {
    echo crypt systemd network
    return 0
}

install () {
    inst $systemdsystemunitdir/aa-rekey.service
    inst $systemdsystemunitdir/aa-unlock.service
    inst /usr/libexec/aa-rekey
    inst /usr/libexec/aa-unlock
    inst /usr/bin/trustee-attester

    inst curl
    inst cryptsetup
    inst tr
    inst lsblk
    inst base64

    # Should be add-requires
    systemctl -q --root "$initdir" add-wants ignition-complete.target aa-rekey.service
    # Should be add-requires
    systemctl -q --root "$initdir" add-wants ignition-subsequent.target aa-unlock.service

    # Need to figure out why systemd-unit-file get x mode
    chmod -x $systemdsystemunitdir/aa-client.service

    # Need network -- figure out how to do it without chaining the command line
    echo "rd.neednet=1" >  "${initdir}/etc/cmdline.d/65aa-client.conf"
}
