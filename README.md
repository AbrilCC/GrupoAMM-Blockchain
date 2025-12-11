## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Installation

### Install Dependencies

Clona con submódulos para traer `lib/forge-std` y `lib/openzeppelin-contracts`:
```shell
git clone --recursive <repository-url>
# Si ya lo clonaste:
git submodule update --init --recursive
```
No se requiere `npm install` porque las librerías viven en `lib/`.

## Usage

### Build

```shell
$ forge build
```

### Test

Ejecutar todos los tests:
```shell
forge test
```

Ejecutar tests específicos con logs verbosos:
```shell
# Test de swaps básicos
forge test --match-test test_SwapEthToToken -vv

# Test de roundtrip
forge test --match-test test_RoundtripPriceReturns -vv

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

### Deploy en Anvil


1. **Iniciar Anvil** (en una terminal): (esto corre un nodo local en el pueto http://127.0.0.1:8545 y ademas te da cuentas con balance de ETH y Private keys)
```shell
anvil
```

2. **Deploy del AMM y USD token**:
```shell
forge script script/Deploy.s.sol --tc DeployScript --rpc-url http://127.0.0.1:8545 --broadcast -vvv
```

Esto despliega:
- Token USD (ERC20)
- Contrato AMM con liquidez inicial (10 ETH + 30,000 USD a precio 3000 USD/ETH)
- Importante usar `--broadcast` para que se mande la tx al nodo local, si no, solo la simula.
El script mostrará las direcciones de los contratos en output en la terminal. Guardalas para el siguiente paso.

las guardas asi:
```shell
  export USD_ADDRESS=<direccion_usd>
  export AMM_ADDRESS=<direccion_amm>
```
3. **Ejecutar Sandwich Attack**:
```shell
forge script script/SandwichAttack.s.sol --tc SandwichAttackScript --rpc-url http://127.0.0.1:8545 --broadcast -vvv
```


El script ejecuta:
- **Front-run**: Atacante compra ETH con 100,000 USD
- **TX Víctima**: Víctima compra ETH con 6,000 USD (a peor precio)
- **Back-run**: Atacante vende el ETH recibido

**Nota**: Enrealidad el sandwich attack pasa todo en un mismo bloque, para no dejar la pool desbalanceada y otra persona aproveche el precio. Anvil por defecto mina una tx por bloque, para que las 3 transacciones estén en el mismo bloque, inicia Anvil con `anvil --no-mining` y mina manualmente después de enviar las 3 TXs. Esto esta hecho en el script `sandwich.sh`. 

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
