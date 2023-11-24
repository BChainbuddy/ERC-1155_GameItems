const {
  developmentChains,
  networkConfig,
} = require("../helper-hardhat-config");
const { verify } = require("../utils/verify");
const { network } = require("hardhat");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deployer } = await getNamedAccounts();
  const { log, deploy } = deployments;

  console.log("Collecting the args data...");
  let vrfCoordinatorV2Address, subscriptionId;
  const chainId = network.config.chainId;
  const keyHash = networkConfig[chainId].gasLane;
  const callbackGasLimit = networkConfig[chainId].callbackGasLimit;
  const packPrice = networkConfig[chainId].packPrice;

  if (!developmentChains.includes(network.name)) {
    vrfCoordinatorV2Address = networkConfig[chainId].vrfCoordinatorV2;
    subscriptionId = networkConfig[chainId].subscriptionId;
  } else {
    const vrfCoordinatorV2Mock = await ethers.getContract(
      "VRFCoordinatorV2Mock",
      deployer
    );
    vrfCoordinatorV2Address = vrfCoordinatorV2Mock.target;
    const txresponse = await vrfCoordinatorV2Mock.createSubscription();
    const txreceipt = await txresponse.wait(1);
    subscriptionId = txreceipt.logs[0].args.subId;
    await vrfCoordinatorV2Mock.fundSubscription(
      subscriptionId,
      ethers.parseEther("30")
    );
  }

  args = [
    subscriptionId,
    vrfCoordinatorV2Address,
    keyHash,
    callbackGasLimit,
    packPrice,
  ];

  log("Args data has been collected successfully!");
  log(`Deploying the contract AvatarItems on ${network.name}`);
  const avatarItems = await deploy("AvatarItems", {
    from: deployer,
    args: args,
    log: true,
  });
  log("The contract has been deployed successfully!");

  if (chainId == 31337) {
    const vrfCoordinatorV2Mock = await ethers.getContract(
      "VRFCoordinatorV2Mock"
    );
    await vrfCoordinatorV2Mock.addConsumer(subscriptionId, avatarItems.address);
    log("adding consumer...");
    log("Consumer added!");
  }

  if (!developmentChains.includes(network.name)) {
    log("Verifying the contract...");
    await verify(avatarItems.address, args);
  }
  log("---------------------");
};

module.exports.tags = ["all", "avatarItems"];
