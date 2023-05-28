# Gearbox protocol

Gearbox is a generalized leverage protocol. It has two sides to it: passive liquidity providers who earn low-risk APY by providing single-asset liquidity; and active farmers, firms, or even other protocols who borrow those assets to trade or farm with even x10 leverage.

Gearbox Protocol allows anyone to take DeFi-native leverage and then use it across various (DeFi & more) protocols in a composable way. You take leverage with Gearbox and then use it on other protocols you already love: Uniswap, Curve, Convex, Lido, etc. For example, you can leverage trade on Uniswap, leverage farm on Yearn, make delta-neutral strategies, get Leverage-as-a-Service for your structured product, and more... Thanks to the Credit Accounts primitive!

_Some compare composable leverage as a primitive to DeFi-native prime brokerage._

## New in V2

- **Multicalls**. The new Gearbox V2 architecture allows users to submit a sequence of Credit Account management operations and calls to external contracts that are executed sequentially, with only one health check at the end. This enables users to implement arbitrarily complex strategies without significant gas overhead and maintain their account's health with a single transaction, while liquidators can liquidate positions without flash loans or capital requirements.
- **Modular architecture**. Compartmentalization of various functions makes parts of the system easily replaceable, which helps to both seamlessly update the system and swiftly respond to threats. E.g., all access and sanity checks when managing a Credit Account are performed inside a Credit Facade (a user-facing interface connected to its respective Credit Manager) - this allows to patch potential exploits or add new Credit Account management features without touching the Credit Manager itself or its connected Credit Accounts.
- **Improved integration potential**. With multicalls and improved risk customization, more collateral asset classes and protocols can be connected to the system.

## Repository overview

This repository contains the core smart contracts source code for Gearbox Protocol V2, as well as related Forge-based unit tests.

```
- contracts
  - adapters
  - core
  - credit
  - factories
  - interfaces
  - libraries
  - multicall
  - oracles
  - pool
  - support
  - tokens
```

### Adapters

This directory contains code used for third-party integration. Since this repository contains core protocol code, there are only 2 contracts:

1. `AbstractAdapter.sol` is the base contract for all adapters and contains the necessary logic to interact with Gearbox Credit Managers.
2. `UniversalAdapter.sol` is a special adapter used for convenience features (such as allowance revocations or limited collateral withdrawals) and (in future updates) for quick integrations with protocols where a complete adapter is not required.

### Core

This directory contains protocol contracts related to access, contract discovery, data reporting, etc.

1. `AccountFactory.sol` is used to deploy Credit Accounts and managed the existing Credit Account queue. Credit Managers take accounts from the factory when a new account in Gearbox is opened and return them after the account is closed.
2. `ACL.sol` is the main access control contract in the system. Contracts that inherit `ACLTrait.sol` use `ACL.sol` to determine access to configurator-only functions.
3. `AddressProvider.sol` is used by other contracts in the system to determine the up-to-date addresses of core contracts, such as `ACL`, `PriceOracleV2`, `GearToken`, etc.
4. `ContractsRegister.sol` contains a list of legitimate Gearbox Credit Managers and pools connected to the system.
5. `DataCompressor.sol` is used to retrieve detailed data on particular Credit Managers and Credit Accounts.
6. `WETHGateway.sol` is used to convert native ETH into WETH and vice versa.

### Credit

This directory contains the contracts responsible for managing Credit Accounts, tracking Credit Account collateral and debt, facilitating interactions with third-party contracts, etc. These contracts encapsulate the primary functions of the protocol.

1. `CreditAccount.sol` is a contract that acts as a user's smart wallet with out-of-the-box leverage. Credit Accounts store all of the user's collateral and borrowed assets, and can execute calls to third-party protocols routed to them by the user. In essence, a Credit Account acts as a substitute to the user's own EOA/Smart Wallet when interacting with protocols, but can also hold borrowed assets and only executes operations that are allowed by its respective Credit Manager.
2. `CreditManager.sol` is the primary backend contract of the Gearbox protocol, responsible for opening and closing accounts, routing calls to third-party protocols on behalf of Credit Account owners, performing account health checks, and tracking the lists of allowed third-party contracts and collateral tokens. Credit Managers cannot be interacted with directly by users - this has to be done through either an adapter or Credit Facade.
3. `CreditFacade.sol` is the main interface through which users interact with the Gearbox protocol. It allows users to manage their accounts and carry out multicalls, while performing necessary access and security checks for all operations.
4. `CreditConfigurator.sol` is an admin contract used to configure various security properties of the connected Credit Manager / Credit Facade, such as allowing new collateral tokens and adapters, changing fee parameters, etc.

### Factories

Contains factory contracts used for deployment and initial configuration of important system contracts.

1. `CreditManagerFactoryBase.sol` deploys a Credit Manager / Credit Facade / Credit Configurator suite. A special `_postInstall()` function can be overridden to additionally configure adapters.
2. `GenesisFactory.sol` deploys and sets up core contracts, such as `ACL`, `AddressProvider`, `PriceOracleV2`, etc.
3. `PoolFactory.sol` deploys and configures the borrowing pool.

### Multicall

Contains libraries that provide convenience functions to construct multicalls for target contracts using their normal function signatures. Since this repository is for core contracts, only contains a library for `CreditFacade`.

### Oracles

Contains the base contracts Gearbox uses to evaluate assets and convert them to each other.

1. `PriceOracleV2.sol` is a contract that serves both as a repository for price feeds, as well as the main interface through which other contracts query asset conversions.
2. `LPPriceFeed.sol` is an abstract contract that all LP price feeds (such as Curve LP price feeds) derive from. It implements logic for bounding the LP token / share prices, to prevent manipulation.
3. `ZeroPriceFeed.sol` is a dummy price feed used for assets with no reliable USD feeds. This allows to support operations with these assets (such as receiving them as farming rewards and selling) without exposing the protocol to risk.
4. `PriceFeedChecker.sol` is a helper contract implementing sanity checks on values returned from price feeds.

### Pool

Contains contracts related to passive LP side.

1. `PoolService.sol` implements a borrowing pool that loans assets to Credit Managers to be used in Credit Accounts.
2. `LinearInterestRateModel.sol` implements a function of interest rate from utilization.

### Support

Contains contracts that assist data retrieval and configuration.

1. `ContractUpgrader` is a helper contract used to manage configurator rights during initial contract deployment.
2. `PauseMulticall` is used to pause multiple Credit Managers / pools within a single transaction.
3. `MultiCall` is a read-only multicall contract by MakerDAO. See the [corresponding repository](https://github.com/makerdao/multicall).

### Tokens

Contains contracts for special tokens used by the system.

1. `DieselToken` implements an LP token for Gearbox borrowing pools.
2. `DegenNFTV2` is a special non-transferrable NFT required to open a Credit Account if the system is in Leverage Ninja mode.
3. `GearToken` is the contract for the Gearbox DAO GEAR token.
4. `PhantomERC20` is a special pseudo-ERC20 used to collateralize positions that are not represented as ERC20 on the third-party protocol side. Its `balanceOf` function is customized in concrete implementations to report, e.g., an amount staked in a particular farming pool.

## Using contracts

Source contracts and their respective interfaces can be imported from an npm package `@gearbox-protocol/core-v2`, e.g.:

```=solidity
import {ICreditFacadeV2, MultiCall} from '@gearbox-protocol/core-v2/contracts/interfaces/ICreditFacadeV2.sol';

contract MyContract {
  ICreditFacadeV2 creditFacade;

  function foo(MultiCall[] memory calls) {
    creditFacade.multicall(calls);
  }
}
```

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

The primary license for the Gearbox-protocol/core-v2 is the Business Source License 1.1 (BUSL-1.1), see [LICENSE](https://github.com/Gearbox-protocol/core-v2/blob/master/LICENSE). The files which are NOT licensed under the BUSL-1.1 have appropriate SPDX headers.

## Disclaimer

This application is provided "as is" and "with all faults." Me as developer makes no representations or
warranties of any kind concerning the safety, suitability, lack of viruses, inaccuracies, typographical
errors, or other harmful components of this software. There are inherent dangers in the use of any software,
and you are solely responsible for determining whether this software product is compatible with your equipment and
other software installed on your equipment. You are also solely responsible for the protection of your equipment
and backup of your data, and THE PROVIDER will not be liable for any damages you may suffer in connection with using,
modifying, or distributing this software product.
