#!/bin/bash

create_remote_ign_config ()
{
	IP=$1
	# Setup remote ignition config
	BUTANE=pin-trustee.bu
	IGNITION="${BUTANE%.bu}.ign"

	sed "s/<IP>/$IP/" configs/remote-ign/${BUTANE} > tmp/${BUTANE}

	podman run --interactive --rm --security-opt label=disable \
		--volume "$(pwd)/tmp:/pwd" \
		--workdir /pwd \
		quay.io/trusted-execution-clusters/butane:clevis-pin-trustee \
		--pretty --strict /pwd/$BUTANE --output "/pwd/$IGNITION"
	echo "$IGNITION"
}
