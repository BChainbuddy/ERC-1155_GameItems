const { developmentChains } = require("../helper-hardhat-config");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { log, deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const VRF_FEE = ethers.parseEther("0.25");
  const LINK_GAS = 1e9;
  args = [VRF_FEE, LINK_GAS];

  if (developmentChains.includes(network.name)) {
    log(`Deploying the contract MockVRF on ${network.name}`);
    await deploy("VRFCoordinatorV2Mock", {
      from: deployer,
      log: true,
      args: args,
    });
    log("Mock has been deployed!");
    log("---------------------");
  }
};

module.exports.tags = ["all", "mock"];
