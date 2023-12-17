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
          await avatarItems.addAvatarItem(0, "blue skin", "1000"); // id 1
          await avatarItems.addAvatarItem(1, "red Shirt", "1000"); // id 2
          await avatarItems.addAvatarItem(2, "yellow Pants", "10"); // id 3
          await avatarItems.addAvatarItem(2, "red Pants", "10"); // id 4
          await avatarItems.addAvatarItem(2, "black Pants", "10"); // id 5
          await avatarItems.addAvatarItem(2, "brown Pants", "10"); // id 6
          await avatarItems.addAvatarItem(2, "paper Pants", "10"); // id 7

          await avatarItems.addAvatarItem(3, "purple Shoes", "1000"); // id 6
          await avatarItems.addAvatarItem(4, "chain", "1000"); // id 7
          await avatarItems.addAvatarItem(5, "blue Banner", "1000"); // id 8
          await avatarItems.authorizeContract(deployer);
          await avatarItems.earnRewards(deployer, 50);
          expect(await avatarItems.waitingForResponse(deployer)).to.equal(
            false
          );
          const buyPack = await avatarItems.buyPack(deployer);
          const buyPackReceipt = await buyPack.wait(1);
          // expect(
          //   await avatarItems.getRequestAddress(
          //     buyPackReceipt.logs[2].args._requestId
          //   )
          // ).to.equal(deployer);
          expect(await avatarItems.waitingForResponse(deployer)).to.equal(true);
          await vrfCoordinatorV2Mock.fulfillRandomWords(
            buyPackReceipt.logs[2].args._requestId,
            avatarItems.target
          );
          expect(await avatarItems.waitingForResponse(deployer)).to.equal(
            false
          );
        });
      });
      describe("powerUps", function () {
        it("Adds a powerup option", async () => {
          await avatarItems.addPowerUp("multiplier3", 3, 600); // 600 seconds
          expect(await avatarItems.s_itemCounter()).to.equal(2);
        });
        it("Mints the powerup", async () => {
          await avatarItems.addPowerUp("multiplier3", 3, 600); // 600 seconds
          await avatarItems.authorizeContract(deployer);
          await avatarItems.powerUpMint(deployer, 1, 1);
          expect(await avatarItems.balanceOf(deployer, 1)).to.equal(1);
        });
        it("Activates the power up", async () => {
          await avatarItems.addPowerUp("multiplier3", 3, 600); // 600 seconds
          await avatarItems.authorizeContract(deployer);
          await avatarItems.powerUpMint(deployer, 1, 2);
          expect(await avatarItems.timeLock(deployer)).to.equal(1);
          await avatarItems.activatePowerUp(1);
          await expect(avatarItems.activatePowerUp(1)).to.be.reverted;
          expect(await avatarItems.balanceOf(deployer, 1)).to.equal(1);
          // expect(
          //   (await avatarItems.ActivationCheck(deployer)).duration
          // ).to.equal(600);
          expect(await avatarItems.timeLock(deployer)).to.equal(3);
          await avatarItems.authorizeContract(deployer);
          await avatarItems.earnRewards(deployer, 1);
          expect(await avatarItems.balanceOf(deployer, 0)).to.equal(3);
          await network.provider.send("evm_increaseTime", [600]);
          await network.provider.send("evm_mine", []);
          expect(await avatarItems.timeLock(deployer)).to.equal(1);
        });
      });
    });
