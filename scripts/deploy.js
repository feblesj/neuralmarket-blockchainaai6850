// Full-stack deployment for the NeuralMarket platform.
// Usage: npx hardhat run scripts/deploy.js --network sepolia
const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deployer:", deployer.address);

  const CAP = hre.ethers.parseEther("100000000"); // 100M NRL cap

  // 1. Token
  const Token = await hre.ethers.getContractFactory("NeuralToken");
  const token = await Token.deploy(deployer.address, CAP);
  await token.waitForDeployment();
  console.log("NeuralToken:", await token.getAddress());

  // 2. Oracle (mock for testnet demo; swap for a live Chainlink feed in prod)
  const Mock = await hre.ethers.getContractFactory("MockAggregator");
  const mock = await Mock.deploy(9500, 2); // quality index 95.00
  await mock.waitForDeployment();
  const Oracle = await hre.ethers.getContractFactory("AIDataOracle");
  const oracle = await Oracle.deploy(await mock.getAddress());
  await oracle.waitForDeployment();
  console.log("AIDataOracle:", await oracle.getAddress());

  // 3. Staking (reward pool)
  const Staking = await hre.ethers.getContractFactory("NeuralStaking");
  const staking = await Staking.deploy(await token.getAddress(), hre.ethers.parseEther("0.01"));
  await staking.waitForDeployment();
  console.log("NeuralStaking:", await staking.getAddress());

  // 4. Governor (quorum 1M votes)
  const Governor = await hre.ethers.getContractFactory("NeuralGovernor");
  const governor = await Governor.deploy(await token.getAddress(), hre.ethers.parseEther("1000000"));
  await governor.waitForDeployment();
  console.log("NeuralGovernor:", await governor.getAddress());

  // 5. Marketplace (fee sink = staking pool)
  const Market = await hre.ethers.getContractFactory("AIModelMarketplace");
  const market = await Market.deploy(
    await token.getAddress(),
    await oracle.getAddress(),
    await staking.getAddress(),
    await governor.getAddress()
  );
  await market.waitForDeployment();
  console.log("AIModelMarketplace:", await market.getAddress());

  // 6. Cross-chain bridge (mock endpoint for demo)
  const Endpoint = await hre.ethers.getContractFactory("MockEndpoint");
  const endpoint = await Endpoint.deploy();
  await endpoint.waitForDeployment();
  const Bridge = await hre.ethers.getContractFactory("CrossChainListingBridge");
  const bridge = await Bridge.deploy(await endpoint.getAddress());
  await bridge.waitForDeployment();
  console.log("CrossChainListingBridge:", await bridge.getAddress());

  console.log("\nDeployment complete. Save these addresses for your docs and demo.");
}

main().catch((e) => { console.error(e); process.exitCode = 1; });
