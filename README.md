[![codecov](https://codecov.io/gh/hord/smart-contracts/branch/develop/graph/badge.svg?token=8f1gfxIpRK)](https://codecov.io/gh/hord/smart-contracts)
[![Mythx](https://github.com/Hord/smart-contracts/actions/workflows/mythx.yml/badge.svg)](https://github.com/Hord/smart-contracts/actions/workflows/mythx.yml)

## Hord.app Smart Contracts

<img src="./favicon.png" width="100" style="float: left;">

_HORD enables crypto champions to tokenize and monetize their influence, and empowers crypto lovers to evolve from following news and tips to capitalizing on information flow._

- Website: [https://hord.app][Official website]
- Community: [https://t.me/hord_app][Official telegram community]

### Ethereum Mainnet Addresses:

- `HordToken` : [0x43A96962254855F16b925556f9e97BE436A43448](https://etherscan.io/token/0x43A96962254855F16b925556f9e97BE436A43448) 
- `HordTicketFactory (NFT)` : [0x32aa07e6ebf2340eef1f717197ade6982b815536](https://etherscan.io/address/0x32aa07e6ebf2340eef1f717197ade6982b815536)

### Developer instructions

#### Instal dependencies
`yarn install`

#### Create .env file and make sure it's having following information:
```
PK=YOUR_PRIVATE_KEY 
USERNAME=2key
```

#### Compile code
- `npx hardhat clean` (Clears the cache and deletes all artifacts)
- `npx hardhat compile` (Compiles the entire project, building all artifacts)

#### Deploy code 
- `npx hardhat node` (Starts a JSON-RPC server on top of Hardhat Network)
- `npx hardhat run --network {network} scripts/{desired_deployment_script}`

#### Flatten contracts
- `npx hardhat flatten` (Flattens and prints contracts and their dependencies)

#### Deployed addresses and bytecodes
All deployed addresses and bytecodes can be found inside `deployments/contract-addresses.json` file.


[Official website]: https://hord.app

[Official telegram community]: https://t.me/hord_app
