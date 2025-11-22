#!/bin/bash

set -ex

KBC=kbs-client
URL=http://localhost:8080
KEY=trustee/keys/private.key

cat <<EOF >secret
{ "key_type": "oct", "key": "2b442dd5db4478367729ef8bbf2e7480" }
EOF

$KBC --url $URL  config \
	--auth-private-key $KEY  \
	set-resource --path default/machine/root \
	--resource-file $(pwd)/secret

cat <<EOF > tmp/resource-policy.rego
package policy
import rego.v1

default allow := false

allow if {
  input.submods.cpu0["ear.status"] == "affirming"
  input.submods.cpu0["ear.veraison.annotated-evidence"].init_data_claims.uuid == split(data["resource-path"], "/")[2]
}
EOF

$KBC --url http://localhost:8080  config \
	--auth-private-key $KEY  \
	set-resource-policy --policy-file tmp/resource-policy.rego


cat <<EOF > tmp/attestation-policy.rego
package policy
import rego.v1
default hardware := 97
default configuration := 36
default executables := 33

tpm_pcrs_valid if {
  input.tpm.pcr04 in data.reference.tpm_pcr4
  input.tpm.pcr07 in data.reference.tpm_pcr7
  input.tpm.pcr14 in data.reference.tpm_pcr14
}

hardware := 2 if tpm_pcrs_valid
executables := 3 if tpm_pcrs_valid
configuration := 2 if tpm_pcrs_valid

default file_system := 0
default instance_identity := 0
default runtime_opaque := 0
default storage_opaque := 0
default sourced_data := 0
result := {
  "executables": executables,
  "hardware": hardware,
  "configuration": configuration,
  "file-system": file_system,
  "instance-identity": instance_identity,
  "runtime-opaque": runtime_opaque,
  "storage-opaque": storage_opaque,
  "sourced-data": sourced_data,
}
EOF

$KBC --url $URL  config \
	--auth-private-key $KEY  \
	set-sample-reference-value tpm_pcr4 "ff2b357be4a4bc66be796d4e7b2f1f27077dc89b96220aae60b443bcf4672525"
$KBC --url $URL  config \
	--auth-private-key $KEY  \
	set-sample-reference-value tpm_pcr7 "b3a56a06c03a65277d0a787fcabc1e293eaa5d6dd79398f2dda741f7b874c65d"
$KBC --url $URL  config \
	--auth-private-key $KEY  \
	set-sample-reference-value tpm_pcr14 "17cdefd9548f4383b67a37a901673bf3c8ded6f619d36c8007562de1d93c81cc"

$KBC --url $URL config \
	--auth-private-key $KEY  \
	get-reference-values
$KBC --url $URL  config \
	--auth-private-key $KEY  \
	set-attestation-policy --policy-file tmp/attestation-policy.rego --id default_cpu --type rego
