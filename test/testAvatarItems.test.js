const { assert, expect } = require("chai");
const {
  developmentChains,
  networkConfig,
} = require("../helper-hardhat-config");
const { deployments, getNamedAccounts, ethers } = require("hardhat");

!developmentChains.includes(network.name)
  ? describe.skip()
  : describe("Avatar item test", () => {
      let vrfCoordinatorV2Mock, avatarItems, deployer, packPrice, user;
      beforeEach("", async () => {
        await deployments.fixture(["all"]);
        deployer = (await getNamedAccounts()).deployer;
        const accounts = await ethers.getSigners();
        user = accounts[1];
        vrfCoordinatorV2Mock = await ethers.getContract("VRFCoordinatorV2Mock");
        avatarItems = await ethers.getContract("AvatarItems", deployer);
        const chainId = network.config.chainId;
        packPrice = networkConfig[chainId].packPrice;
      });
      describe("AvatarItems", () => {
        it("Sets the packPrice and changes the packPrice", async () => {
          expect(await avatarItems.s_packPrice()).to.equal(packPrice);
          await avatarItems.setPackPrice(ethers.parseEther("2"));
          expect(await avatarItems.s_packPrice()).to.equal(
            ethers.parseEther("2")
          );
        });
        it("Adds new item", async () => {
          expect(await avatarItems.doesItemExist("blue Shirt")).to.equal(false);
          //   const itemType = await avatarItems.ItemType([0]);
          await avatarItems.addAvatarItem(0, "blue Shirt", "1000");
          expect(await avatarItems.s_itemCounter()).to.equal("2");
          const item = await avatarItems.viewItemDescription("1");
          expect(item.name).to.equal("blue Shirt");
          expect(item.itemSupply).to.equal(BigInt(1000));
          expect(await avatarItems.doesItemExist("blue Shirt")).to.equal(true);
          await avatarItems.addItemSupply(1, "1000");
          const itemAferAddSupply = await avatarItems.viewItemDescription("1");
          expect(await itemAferAddSupply.itemSupply).to.equal(BigInt(2000));
        });
        it("Authorizes contract and earns Rewards", async () => {
          await expect(avatarItems.earnRewards(user.address, 10)).to.be
            .reverted;
          const userConnected = await avatarItems.connect(user);
          expect(await avatarItems.balanceOf(user.address, 0)).to.equal("0");
          await expect(userConnected.authorizeContract(user.address)).to.be
            .reverted;
          await avatarItems.authorizeContract(user.address);
          await expect(avatarItems.earnRewards(user.address, 10)).to.be
            .reverted;
          await userConnected.earnRewards(user.address, 10);
          expect(await avatarItems.balanceOf(user.address, 0)).to.equal(
            BigInt(10)
          );
        });
        it("Buys a pack and fullfills the request", async () => {
          await avatarItems.addAvatarItem(0, "blue Shirt", "1000");
          await avatarItems.addAvatarItem(0, "red Shirt", "1000");
          await avatarItems.addAvatarItem(0, "yellow Shirt", "1000");
          await avatarItems.addAvatarItem(0, "purple Shirt", "1000");
          await avatarItems.authorizeContract(deployer);
          await avatarItems.earnRewards(deployer, "10");
          const buyPack = await avatarItems.buyPack(deployer);
          const buyPackReceipt = await buyPack.wait(1);
          expect(await avatarItems.balanceOf(deployer, 0)).to.equal(
            "10" - packPrice
          );
          await vrfCoordinatorV2Mock.fulfillRandomWords(
            buyPackReceipt.logs[2].args._requestId,
            avatarItems.target
          );
        });
      });
    });
