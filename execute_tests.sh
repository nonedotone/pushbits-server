find . -name '*.go' -printf '%h\n' | sort -u | xargs -n1 -P1 go test -cover
