#!/bin/bash

check() {
    return 0
}

depends() {
    return 0
}

install () {
    inst_multiple \
        tpm2_create \
        tpm2_createak \
        tpm2_evictcontrol \
        tpm2_getrandom \
        tpm2_load \
        tpm2_nvread \
        tpm2_nvwrite \
        tpm2_pcrread \
        tpm2_unseal

    # Library dependencies
    inst_libdir_file "libtss2*" 
}
