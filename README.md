# OpenPad Contracts

## Hardhat Configuration

Smart contracts are compiled with Solidity compiler version `0.8.16` with optimizations enabled. Hardhat includes CLI commands for compiling, testing and verifying contracts.

- `hardhat compile` compiles every out of date contract
- `hardhat clean` removes any artifacts created by contract
- `hardhat test` runs tests

### Deploying Smart Contracts

Hardhat task `deploy` will deploy a smart contract to specified network with `--network` parameter and verify it. First positional argument is the contract name and followed by constructor arguments.

```sh
hardhat deploy --network NETWORK CONTRACT [...ARGS]
```

Deploy [OPN contract](./contracts/OPN.sol) the contract name is `OPN` and the contract doesn't require constructor arguments so we run following command to deploy it.
```sh
hardhat deploy OPN --network avalancheFujiNetwork
```

Deploy [Staking contract](./contracts/Staking.sol) the contract name is `Staking` and the contract requires ERC20 token address for staking, reward address and lastly reward rate.
```sh
hardhat deploy Staking 0xCC5119821Ee280DD0374308dC5B9fe905aff892B 0xBf1345f1b27A711EB3128288db1783DB19027DA2 100 --network avalancheFujiNetwork
```
