for f in ./abi/*.json; do
  echo "Processing $f file..";
  GO_NAME=${f/json/go}
  DIR=./abi/
  GO_PKG=${GO_NAME/$DIR/""}
  GO_PKG=${GO_PKG/.go/""}
  GO_PKG_FL="$(tr [A-Z] [a-z] <<< "${GO_PKG:0:1}")"
  GO_PKG=${GO_PKG_FL}${GO_PKG:1}
  OUT_DIR=../gearscan/artifacts/${GO_PKG}

  # Create dir if not exists
  [ ! -d $OUT_DIR ] && mkdir $OUT_DIR

  # Export file
  OUT_FILE=${OUT_DIR}/abi.go
  rm -rf ./gearscan/artifacts/*
  abigen --abi $f --pkg $GO_PKG --out $OUT_FILE
done
