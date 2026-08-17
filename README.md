## NeuralMarket, Enterprise-Ready Blockchain-AI Marketplace
This is a decentralized marketplace for buying and selling AI models and datasets with a token economy, staking, on-chain governance, oracle-verified quality, privacy controls, and cross-chain reach. By Jack Febles.
## What it Seeks to Do
Providers list their AI models; before a listing goes live, the platform will check an oracle-supplied quality score. Buyers pay in the platform token (NRL); a small, community-governed fee is routed to a staking reward pool. Premium items support sealed bid auctions via commit-reveal, and access to purchased models and datasets has a role-based permission system. Listings can be mirrored across blockchains. Token holders can help change rules through on-chain proposals.
## Deployment (Sepolia Testnet)

## Contract              Address
NeuralToken (NRL) --> 0x23e16B81aAb7E56d1Afd1a6E90FE9A2FCfB032C8
MockAggregator -->    0x716FDE06021e95EBfEE82B2C11D9cC209f67985B
AIDataOracle -->      0x1b8ACC94FeD4AC27c522B09c30D2af854c62628D
NeuralStaking -->     0xC42A6A77e41ad244fC2e4Ff1db8Ef4da26e45F22
NeuralGovernor -->    0x07448dbbc9187c473c19b956431E20a7749Fe0B4
AIModelMarketplace --> 0x482a3e2E3448F9f7605d58E002ffaFD9abc7fB95
MockEndpoint -->      0x5b75dE0E42309E3B0A2856EA2541f809598353C6
CrossChainListingBridge --> 0x93758839BcA799382Dd9987e5bD46ED3e8e792FC

## Tech Stack
Solidity ^ 0.8.24
OpenZeppelin Contracts 5.0.2 (ERC20Votes, AccessControl, ReentrancyGuard, SafeERC20
Hardhat for compilation, testing, and coverage
GitHub Actions CI (lint, compile, test, coverage)
Deployed and demonstrated Remix + Metamask on Sepolia

## Run Locally
npm install
npx hardhat compile
npx hardhat test
npx hardhat coverage

## Deploy to a testnet
npx hardhat run scripts/deploy.js --network sepolia

## All write-ups are in the /docs folder
Technical Documentation
Security Review
BusinessCase & ROI

## AI-Use Disclosure
Portions of this project's code were produced with the help of AI assistance under the course's permitted-use policy; it was then reviewed, tested, and adapted by the author. All external libraries are credited through their imports, and the design of the project is from this course's modules.
