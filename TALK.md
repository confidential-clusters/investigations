# Getting the Clevil Trustee Pin token from LUKS headers

```
$ sudo cryptsetup luksDump /dev/vda4
...
Tokens:
  0: clevis
        Keyslot:    1
...

$ sudo cryptsetup token export /dev/vda4 --token-id 0 | jq
{
  "type": "clevis",
  "keyslots": [
    "1"
  ],
  "jwe": {
    "ciphertext": "T5ofOoC5m3av9eTmU7mNWtNtxX3-XjawgwKf4rMacSPgxQO3H6gC1VeNiaV0d1CQtmNd1E2H",
    "encrypted_key": "",
    "iv": "Dil7xRFTAER1jxKU",
    "protected": "eyJhbGciOiJkaXIiLCJlbmMiOiJBMjU2R0NNIiwiY2xldmlzIjp7InBpbiI6InRydXN0ZWUiLCJzZXJ2ZXJzIjpbeyJ1cmwiOiJodHRwOi8vMTkyLjE2OC4xMjIuMTU4OjgwODAiLCJjZXJ0IjoiIn1dLCJwYXRoIjoiZGVmYXVsdC9tYWNoaW5lL3Jvb3QifX0",
    "tag": "9RRlZ2H8Gd1Nki3D72E37Q"
  }
}

$ sudo cryptsetup token export /dev/vda4 --token-id 0 | jq -r '.jwe.protected' | base64 -d | jq
{
  "alg": "dir",
  "enc": "A256GCM",
  "clevis": {
    "pin": "trustee",
    "servers": [
      {
        "url": "http://192.168.122.158:8080",
        "cert": ""
      }
    ],
    "path": "default/machine/root"
  }
}
```
