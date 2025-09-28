#!/bin/bash

set -xe

KBS=kbs:8080
SECRET_PATH=${SECRET_PATH:=default/machine/root}
KEY=${KEY:=/opt/confidential-containers/kbs/user-keys/private.key}


## set reference values for TPM 
podman exec -ti kbs-client \
	kbs-client --url http://${KBS}  config \
		--auth-private-key ${KEY} \
		set-sample-reference-value tpm_svn "1"
for i in {7,14}; do
    value=$(sudo tpm2_pcrread sha256:${i} | awk -F: '/0x/ {sub(/.*0x/, "", $2); gsub(/[^0-9A-Fa-f]/, "", $2); print tolower($2)}')
	podman exec -ti kbs-client \
		 kbs-client --url http://${KBS}  config \
			--auth-private-key ${KEY} \
			set-sample-reference-value tpm_pcr${i} "${value}"
done

# Check reference values
podman exec -ti kbs-client \
	kbs-client --url http://${KBS}  config \
		--auth-private-key ${KEY} \
		get-reference-values


# Create attestation policy
## This policy allows access only if the system’s TPM or SNP 
## hardware measurements match trusted reference values
cat << 'EOF' > A_policy.rego
package policy
import rego.v1

default hardware := 97
default executables := 3 
default configuration := 2 

##### TPM

hardware := 2 if {
	input.tpm.svn in data.reference.tpm_svn
	input.tpm.pcrs[7] in data.reference.tpm_pcr7
    input.tpm.pcrs[14] in data.reference.tpm_pcr14
}

hardware := 2 if {
	input.snp.reported_tcb_snp == 25
}


##### Final decision
allow if {
  hardware == 2
  executables == 3
  configuration == 2
}
EOF

podman cp A_policy.rego kbs-client:/A_policy.rego
podman exec -ti kbs-client \
	kbs-client --url http://${KBS}  config \
		--auth-private-key ${KEY} \
		set-attestation-policy \
		--policy-file A_policy.rego \
		--type rego --id default_cpu

# Upload resource
cat > test_data << EOF
1234567890abcde
EOF
podman cp test_data kbs-client:/secret
podman exec -ti kbs-client \
	kbs-client --url http://${KBS}  config \
		--auth-private-key ${KEY} \
		set-resource --resource-file /secret \
		--path ${SECRET_PATH}


# Create resource policy
## This policy allows access only if both CPUs report an "affirming" status 
## and provide TPM and SNP attestation evidence.
cat << 'EOF' > R_policy.rego
package policy
import rego.v1

default allow = false

allow if {
    input["submods"]["cpu0"]["ear.status"] == "affirming"
    input["submods"]["cpu1"]["ear.status"] == "affirming"
	input["submods"]["cpu1"]["ear.veraison.annotated-evidence"]["tpm"]
    input["submods"]["cpu0"]["ear.veraison.annotated-evidence"]["snp"]
}
EOF

podman cp R_policy.rego kbs-client:/R_policy.rego
podman exec -ti kbs-client \
	kbs-client --url http://${KBS}  config \
		--auth-private-key ${KEY} \
		set-resource-policy \
		--policy-file R_policy.rego \
