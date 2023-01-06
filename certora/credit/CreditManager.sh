certoraRun contracts/credit/CreditManager.sol \
  --verify CreditManager:certora/credit/CreditManager.spec \
  --solc solc8.10 \
  --msg "CreditManager" \
  --optimistic_loop \
  --rule_sanity basic \
  --packages @openzeppelin=node_modules/@openzeppelin