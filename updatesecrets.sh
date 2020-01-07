#!/usr/bin/env bash

randpw(){
  < /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-32}
}
whoami
# 1 namespace
# 2 secret name
gen_secret(){
  randpw | kubectl -n $1 create secret generic $2 --dry-run --from-file=foo=/dev/stdin -o json > ./tmp/$2.json
}

echo hello > tmp.2

mkdir -p ./tmp
#gen_secret test test

gen_secret test test2
kubeseal --controller-name sealed-secrets --controller-namespace sealed-secrets --merge-into ./tmp/test2-sealed.json < ./tmp/test2.json

#kubeseal < test.json > ./tmp/test-sealed.json

#randpw | kubeseal --controller-name sealed-secrets --controller-namespace sealed-secrets
