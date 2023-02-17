import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect, assert } from "chai";
import { ethers } from "hardhat";
import { iERC20 } from "./abi/erc20Fragment";
import { getTxIdFromEvents } from "./helpers";

const parseEthers = ethers.utils.parseEther;
const stringToBytes = ethers.utils.toUtf8Bytes;
const keccak256 = ethers.utils.keccak256;

const mintSignature = iERC20.getSighash("mint");

const invalidTxId = keccak256("0x");

describe("MultiSign", function () {
  async function deployFixture() {
    const [owner, account1, account2, account3, notOwnerAccount, receiver] =
      await ethers.getSigners();

    const OWNERS = [owner, account1, account2, account3]; // *
    const THRESHOLD = 3;

    const MultiSign = await ethers.getContractFactory("MultiSign");
    const multiSign = await MultiSign.connect(OWNERS[0]).deploy(
      OWNERS.map((owner) => owner.address), // *
      THRESHOLD
    );

    return {
      multiSign,
      notOwnerAccount,
      OWNERS,
      receiver,
      THRESHOLD,
    };
  }

  // * Deployment -------------------------------------------------------------

  describe("Deployment", async function () {
    it("Should set owners correctly.", async function () {
      const { OWNERS, multiSign } = await loadFixture(deployFixture);

      for (const owner of OWNERS) {
        assert(
          (await multiSign.isOwner(owner.address)) === true,
          `${owner.address} must be an owner.`
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

  // * Fund ------------------------------------------------------------------

  describe("Fund", async function () {
    it("should return the correct balance after funding", async function () {
      const { multiSign, OWNERS } = await loadFixture(deployFixture);

      const owner = OWNERS[0];
      const value = parseEthers("10");

      const tx = await multiSign.connect(owner).fund({ value });

      expect(tx)
        .to.emit(multiSign, "FoundsAdded")
        .withArgs(owner.address, value);

      expect(await ethers.provider.getBalance(multiSign.address)).to.equal(
        value
      );
    });

    it("Should not fund from third-party.", async () => {
      const { multiSign, OWNERS } = await loadFixture(deployFixture);

      const owner = OWNERS[0];
      const value = parseEthers("0");

      try {
        const tx = await multiSign.connect(owner).fund({ value });

        expect(tx).to.revertedWith("MultSign: Zero value");
      } catch (error) {}
    });

    it("Should not fund from third-party.", async () => {
      const { multiSign, notOwnerAccount } = await loadFixture(deployFixture);

      const value = parseEthers("1");

      try {
        const tx = await multiSign.connect(notOwnerAccount).fund({ value });

        expect(tx)
          .to.revertedWithCustomError(multiSign, "NotAnOwner")
          .withArgs(notOwnerAccount.address);
      } catch (error) {}
    });
  });

  // * submitTransaction ------------------------------------------------------

  describe("submitTransaction", async function () {
    it("Should submit a transaction.", async () => {
      const { OWNERS, multiSign, receiver } = await loadFixture(deployFixture);

      for (const owner of OWNERS) {
        const tx = await multiSign
          .connect(owner)
          .submitTransaction(receiver.address, parseEthers("1"), mintSignature);

        expect(tx).to.emit(multiSign, "TransactionSubmitted");
        expect(tx).to.emit(multiSign, "TransactionCreated");
        expect(tx).to.emit(multiSign, "TransactionConfirmed");

        const receipt = await tx.wait();
        const txId = getTxIdFromEvents(receipt.events);

        const confirmationCount = await multiSign.getConfirmationsCount(txId);

        expect(confirmationCount.toNumber()).to.be.equal(1);
      }
    });

    it("Should not submit from third-party.", async () => {
      const { multiSign, notOwnerAccount, receiver } = await loadFixture(
        deployFixture
      );

      try {
        const tx = await multiSign
          .connect(notOwnerAccount)
          .submitTransaction(receiver.address, parseEthers("1"), mintSignature);

        expect(tx)
          .to.revertedWithCustomError(multiSign, "NotAnOwner")
          .withArgs(notOwnerAccount.address);
      } catch (error) {}
    });

    it("Should not submit with invalid `_to` value.", async () => {
      const { OWNERS, multiSign } = await loadFixture(deployFixture);

      // ! Zero address
      try {
        const tx1 = await multiSign
          .connect(OWNERS[0])
          .submitTransaction("0x0", parseEthers("1"), mintSignature);

        expect(tx1).to.revertedWith("MultiSign: Invalid address.");
      } catch (error) {}

      // ! Contract address
      try {
        const tx2 = await multiSign
          .connect(OWNERS[0])
          .submitTransaction(
            multiSign.address,
            parseEthers("1"),
            mintSignature
          );

        expect(tx2).to.revertedWith("MultiSign: Invalid address.");
      } catch (error) {}
    });

    it("Should not submit with invalid `_data` value.", async () => {
      const { OWNERS, multiSign, receiver } = await loadFixture(deployFixture);
      const owner = OWNERS[0];

      try {
        const tx = await multiSign
          .connect(owner)
          .submitTransaction(
            receiver.address,
            parseEthers("0"),
            stringToBytes("")
          );

        expect(tx).to.revertedWith("MultiSign: Invalid address.");
      } catch (error) {}
    });
  });

  // * confirmTransaction -----------------------------------------------------

  describe("confirmTransaction", async function () {
    it("Should confirm a transaction.", async () => {
      const { OWNERS, multiSign, receiver } = await loadFixture(deployFixture);

      const [owner, other, other2, ...rest] = OWNERS;

      const tx = await multiSign
        .connect(owner)
        .submitTransaction(receiver.address, parseEthers("1"), mintSignature);

      const receipt = await tx.wait();

      const txId = getTxIdFromEvents(receipt.events);

      for (const owner of rest) {
        const tx = await multiSign.connect(owner).confirmTransaction(txId);
        expect(tx)
          .to.emit(multiSign, "TransactionConfirmed")
          .withArgs(owner.address, txId);
      }
    });

    it("Should not confirm from third-party.", async () => {
      const { OWNERS, multiSign, receiver, notOwnerAccount } =
        await loadFixture(deployFixture);

      const [owner] = OWNERS;

      const submitTx = await multiSign
        .connect(owner)
        .submitTransaction(receiver.address, parseEthers("1"), mintSignature);

      const receipt = await submitTx.wait();

      const txId = getTxIdFromEvents(receipt.events);

      try {
        const confirmTx = await multiSign
          .connect(notOwnerAccount)
          .confirmTransaction(txId);
        expect(confirmTx)
          .to.revertedWithCustomError(multiSign, "NotAnOwner")
          .withArgs(notOwnerAccount.address);
      } catch (error) {}
    });

    it("Should not submit with inexistent `_txId` value.", async () => {
      const { OWNERS, multiSign } = await loadFixture(deployFixture);

      const [owner] = OWNERS;

      try {
        const confirmTx = await multiSign
          .connect(owner)
          .confirmTransaction(invalidTxId);
        expect(confirmTx)
          .to.revertedWithCustomError(multiSign, "NotAnOwner")
          .withArgs("MultiSign: Transaction does not exist.");
      } catch (error) {}
    });
  });

  // * executeTransaction -----------------------------------------------------

  describe("executeTransaction", async function () {
    it("Should create and execute a transaction.", async () => {
      const { OWNERS, multiSign, receiver } = await loadFixture(deployFixture);

      const [ownerA, ownerB, ownerC, ...rest] = OWNERS;
      let confirmationCount;
      const txValue = parseEthers("1");
      const fundValue = parseEthers("10");

      // * Provisioning the contract with enough balance
      await multiSign.connect(ownerA).fund({ value: fundValue });

      const txA = await multiSign
        .connect(ownerA)
        .submitTransaction(receiver.address, txValue, mintSignature);

      /*
       * At this point we know that this `tx` have one confirmation as
       * we test in `submitTransaction > Should submit a transaction`
       **/

      const receipt = await txA.wait();
      const txId = getTxIdFromEvents(receipt.events);

      await multiSign.connect(ownerB).confirmTransaction(txId);
      confirmationCount = await multiSign.getConfirmationsCount(txId);
      /*
       * Must have 2 confirmations
       **/
      expect(confirmationCount.toNumber()).to.be.equal(2);

      const txC = await multiSign.connect(ownerC).confirmTransaction(txId);
      confirmationCount = await multiSign.getConfirmationsCount(txId);
      /*
       * As we set a threshold of 3, this confirmation should execute the
       * transaction with id `txId`
       **/
      expect(txC)
        .to.emit(multiSign, "TransactionExecuted")
        .withArgs(txId, receiver.address, txValue);
      expect(confirmationCount.toNumber()).to.be.equal(3);
    });

    it("Should not execute a valid transaction from third-party.", async () => {
      const { OWNERS, multiSign, receiver, notOwnerAccount } =
        await loadFixture(deployFixture);

      const [owner] = OWNERS;

      const tx = await multiSign
        .connect(owner)
        .submitTransaction(receiver.address, parseEthers("1"), mintSignature);

      const receipt = await tx.wait();
      const txId = getTxIdFromEvents(receipt.events);

      try {
        const confirmTx = await multiSign
          .connect(notOwnerAccount)
          .executeTransaction(txId);
        expect(confirmTx)
          .to.revertedWithCustomError(multiSign, "NotAnOwner")
          .withArgs("MultiSign: Transaction does not exist.");
      } catch (error) {}
    });

    it("Should not execute with inexistent `_txId` value.", async () => {
      const { OWNERS, multiSign } = await loadFixture(deployFixture);

      const [owner] = OWNERS;

      try {
        const confirmTx = await multiSign
          .connect(owner)
          .executeTransaction(invalidTxId);
        expect(confirmTx)
          .to.revertedWithCustomError(multiSign, "NotAnOwner")
          .withArgs("MultiSign: Transaction does not exist.");
      } catch (error) {}
    });
  });
});
