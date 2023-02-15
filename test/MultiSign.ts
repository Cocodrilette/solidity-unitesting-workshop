import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect, assert } from "chai";
import { ethers } from "hardhat";

describe("MultiSign", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, account1, account2, account3, notOwnerAccount] =
      await ethers.getSigners();

    const OWNERS = [
      owner.address,
      account1.address,
      account2.address,
      account3.address,
    ];
    const THRESHOLD = 3;

    const MultiSign = await ethers.getContractFactory("MultiSign");
    const multiSign = await MultiSign.deploy(OWNERS, THRESHOLD);

    return {
      multiSign,
      owner,
      account1,
      account2,
      account3,
      notOwnerAccount,
      OWNERS,
      THRESHOLD,
    };
  }

  describe("Deployment", async function () {
    it("Should set owners correctly.", async function () {
      const { OWNERS, multiSign } = await loadFixture(deployFixture);

      for (const addr of OWNERS) {
        assert(
          (await multiSign.isOwner(addr)) === true,
          `${addr} must be an owner.`
        );
      }

      assert(
        (await multiSign.ownersCount()).toNumber() === 4,
        `Owners count must be 4`
      );
    });

    it("Should set threshold correctly.", async function () {
      const { THRESHOLD, multiSign } = await loadFixture(deployFixture);

      const threshold = await multiSign.threshold();

      expect(threshold).to.be.equal(THRESHOLD);
    });
  });
});
