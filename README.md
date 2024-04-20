## StableCoin

1. Anchored or Pegged -> $1.00
   1. chainlink Price Feed.
   2. set a function to exchange ETH & BtC -> $$
2. Stability Mechanism (Minting): Algorithmic (Decentralied)
   1. People can only Mint the stableCoin with enough collateral (coded)
3. Collateral: Exagenous (Crypto)
   - ETH wETH
   - BTC wBTC

- @title StableCoin
- @author Web3Santa
- @notice Algorithmic

## WETH contract - sepolia

- 0x8a7d85bbC5153396357Ee30ba0d2b964022B4DC8

## WBTC contract - sepolia

- 0xD8D7B82506Fb204af708134999Bb775069e0b1e4

forge coverage --report debug

1. some proper oracle use
2. write more tests

0: contract DecentralizedStableCoin 0x108B53A7246c1de29bF866c96330C1A1A8433179
1: contract DSCEngine 0x2a9d306079A48D0d3b25a2C9ec6a82D5302Bf422
2: contract HelperConfig 0xC7f2Cf4845C6db0e1a1e91ED41Bcd0FcC1b0E141

healthfactor
2.04
1.5
1.3
1.05
