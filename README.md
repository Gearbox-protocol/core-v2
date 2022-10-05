# Gearbox protocol

This repository contains the core smart contracts source code for Gearbox Protocol V2.

### What is Gearbox protocol?

Gearbox is a generalized leverage protocol: it allows you to take leverage in one place and then use it across various
DeFi protocols and platforms in a composable way. The protocol has two sides to it: passive liquidity providers who earn higher APY
by providing liquidity; active traders, farmers, or even other protocols who can borrow those assets to trade or farm with x4+ leverage.

Gearbox protocol is a Marketmake ETHGlobal hackathon finalist.

## Bug bounty

This repository is subject to the Gearbox bug bounty program, per the terms defined [here]().

## Documentation

General documentation of the Gearbox Protocol can be found [here](https://docs.gearbox.fi). Developer documentation with
more tech-related infromation about the protocol, contract interfaces, integration guides and audits is available on the
[Gearbox dev protal](https://dev.gearbox.fi).

## Testing

### Setup

Running Forge unit tests requires Foundry. See [Foundry Book](https://book.getfoundry.sh/getting-started/installation) for installation details.

### Solidity unit tests

`forge t`

## Licensing

The primary license for the Gearbox-Contracts is the Business Source License 1.1 (BUSL-1.1), see [LICENSE](https://github.com/Gearbox-protocol/gearbox-contracts/blob/master/LICENSE). The files licensed under the BUSL-1.1 have appropriate SPDX headers.

###

- The files in `contracts/adapters`, `contracts/fuzzing`, `contracts/interfaces`, `contracts/support` are licensed under GPL-2.0-or-later.
- The files in `contracts/libraries` are licensed under GPL-2.0-or-later or GNU AGPL 3.0 (as indicated in their SPDX headers).
- The files in `contracts/integrations` are either licensed under GPL-2.0-or-later or unlicensed (as indicated in their SPDX headers).
- The file `contracts/tokens/GearToken.sol` is based on [`Uni.sol`](https://github.com/Uniswap/governance/blob/master/contracts/Uni.sol) and distributed under the BSD 3-clause license.
- The files in `audits`, `scripts`, `test`, `contracts/mocks` are unlicensed.

## Disclaimer

This application is provided "as is" and "with all faults." Me as developer makes no representations or
warranties of any kind concerning the safety, suitability, lack of viruses, inaccuracies, typographical
errors, or other harmful components of this software. There are inherent dangers in the use of any software,
and you are solely responsible for determining whether this software product is compatible with your equipment and
other software installed on your equipment. You are also solely responsible for the protection of your equipment
and backup of your data, and THE PROVIDER will not be liable for any damages you may suffer in connection with using,
modifying, or distributing this software product.
