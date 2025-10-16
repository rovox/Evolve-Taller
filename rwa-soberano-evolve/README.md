## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

## RWA-SOBERANO-EVOLVE

# 1. Configurar entorno

cp .env.example .env # Si tienes un ejemplo

# Luego edita .env con tus valores reales

# 2. Cargar variables

source .env

# 3. Compilar

forge build

# 4. Test

forge test -vvv

# 5. Desplegar Mock primero (opcional)

forge create src/MockERC20.sol:MockERC20 --rpc-url celestia --private-key $PRIVATE_KEY

# 6. Desplegar sistema completo

forge script script/Deploy.s.sol:DeployScript --rpc-url celestia --broadcast --verify -vvvv

## Para obtener fondos de prueba en Celestia Mocha:

Ve a: https://mocha.celenium.io/faucet

Conecta tu wallet (MetaMask)

Agrega la red Celestia Mocha:

Network Name: Celestia Mocha

RPC URL: https://rpc-mocha.pops.one/

Chain ID: 200101

Currency: TIA

Block Explorer: https://celestia-mocha.blockscout.com/

Solicita TIA del faucet

Usa esos TIA para desplegar contratos
