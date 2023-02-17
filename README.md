# **Solidity Unitesting**

# Content

- [**Solidity Unitesting**](#solidity-unitesting)
- [Content](#content)
- [Requirements](#requirements)
- [Set up](#set-up)
- [Common Hardhat tasks](#common-hardhat-tasks)
- [Walkthrough](#walkthrough)
  - [What's a multi-signature contract](#whats-a-multi-signature-contract)
  - [`describe` and `it`](#describe-and-it)
  - [Dissection](#dissection)
    - [Contract](#contract)
    - [Test](#test)
    - [Contract](#contract-1)
    - [Test](#test-1)
    - [Final contract](#final-contract)
- [Exercise - Implement a ERC-20 from scratch](#exercise---implement-a-erc-20-from-scratch)
  - [Description](#description)
- [Extra content](#extra-content)

# Requirements

- [Node.js](https://nodejs.org/en/) (_v18.14.0 LTS or higher_)

# Set up

1. Clone the repo

```shell
git clone https://github.com/Cocodrilette/solidity-unitesting-workshop
```

2. Install dependencies

```shell
cd solidity-unitesting-workshop
npm install
```

# Common Hardhat [tasks](https://hardhat.org/hardhat-runner/docs/advanced/create-task)

1. To compile the contracts inside `contracts/`

```shell
npx hardhat compile
```

2. To run the tests inside `test/`

```shell
npx hardhat test
```

3. To get help

```shell
npx hardhat help
```

3. Others.

```shell
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.ts
```

# Walkthrough

## What's a multi-signature contract

A multi-signature contract is a smart contract designed so that multiple signatures from different addresses are needed for a transaction to be executed.

In this workshop, we will be testing a multi-signature contract. The contract is a simple one, but it is enough to understand the basics of unit testing.

## `describe` and `it`

Usually a test looks like the code below. The building block of almost any test file are the functions `describe` and `it`.

> The best way to think of this is just a general function scope that **"describes"** the suite of test cases enumerated by the **"it"**. functions inside.

Inside that describe, we have an `it` function. These are the specific unit test targets... just sound it out!: "I want it to x.", "I want it to y.", etc.

```typescript
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");

describe("Faucet", function () {
  async function deployContractAndSetVariables() {
    const Faucet = await ethers.getContractFactory("Faucet");
    const faucet = await Faucet.deploy();

    const [owner] = await ethers.getSigners();

    console.log("Signer 1 address: ", owner.address);
    return { faucet, owner };
  }

  it("should deploy and set the owner correctly", async function () {
    const { faucet, owner } = await loadFixture(deployContractAndSetVariables);

    expect(await faucet.owner()).to.equal(owner.address);
  });
});
```

## Dissection

First we need know how are the owners and what is the required threshold to execute a proposal.

### [Contract](contracts/MultiSign.sol)

```solidity
contract MultiSig {
    uint256 public threshold;

    mapping(address => bool) private owners;
    uint256 public ownersCount;

    constructor(
        address[] memory _owners,
        uint256 _threshold
    ) {
        _setOwners(_owners);
        _setThreshold(_threshold);
    }

    function _setOwners(address[] memory _owners) private {
        if (_owners.length == 0) {
            revert(
                "MultiSign: No valid owners length. At least one is required."
            );
        }
        for (uint i = 0; i < _owners.length; i++) {
            owners[_owners[i]] = true;
            ownersCount++;
        }
    }

    function _setThreshold(uint256 _threshold) private {
        if (_threshold == 0) revert("MultiSign: Invalid value threshold value of 0. Required threshold > 1");
        if (_threshold > ownersCount) revert("MultiSign. Setting more threshold than owners.");
        threshold = _threshold;
    }

    receive() external payable {}

    fallback() external payable {}
}

```

### [Test](test/MultiSign.ts)

```typescript
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
```

Then we need to add transactions to approve it later.

### [Contract](contracts/MultiSign.sol)

```solidity
contract MultiSign {
    struct Transaction {
        address to;
        uint256 value;
        bool executed;
        bytes data;
    }

    ...

    mapping(bytes32 => Transaction) public transactions;

    mapping(bytes32 => mapping(address => bool)) public confirmations;

    event TransactionCreated(bytes32 txId);
    event TransactionSubmitted(address destination, uint256 value);
    event TransactionConfirmed(address owner, bytes32 txId);

    error NotAnOwner(address account);

    modifier onlyOwners() {
        if (!isOwner(msg.sender)) revert NotAnOwner(msg.sender);
        _;
    }

    modifier validAddress(address _to) {
        if (_to == address(0) && _to == address(this))
            revert("MultiSign: Invalid address.");
        _;
    }

    modifier validData(bytes memory _data) {
        if (_data.length == 0) revert("MultiSign: Empty data is not valid.");
        _;
    }

    modifier isExistingTransaction(bytes32 _txId) {
        if (
            keccak256(abi.encode(transactions[_txId])) !=
            keccak256(abi.encode(transactions[bytes32(0x0)]))
        ) revert("MultiSign: Transaction does not exist.");
        _;
    }

    constructor(address[] memory _owners, uint256 _threshold) {
        _setOwners(_owners);
        _setThreshold(_threshold);
    }

    function addTransaction(
        address _to,
        uint256 _value,
        bytes memory _data
    )
        internal
        onlyOwners
        validAddress(_to)
        validData(_data)
        returns (bytes32 _txId)
    {
        _txId = _getHashId(_to, _value, _data);

        transactions[_txId] = Transaction({
            to: _to,
            value: _value,
            executed: false,
            data: _data
        });

        emit TransactionCreated(_txId);
    }

    function submitTransaction(
        address _to,
        uint256 _value,
        bytes calldata _data
    ) external onlyOwners {
        _confirmTransaction(addTransaction(_to, _value, _data));
        emit TransactionSubmitted(_to, _value);
    }

    function confirmTransaction(bytes32 _txId) public onlyOwners {
        _confirmTransaction(_txId);
    }

    function _confirmTransaction(
        bytes32 _txId
    ) internal isExistingTransaction(_txId) {
        confirmations[_txId][msg.sender] = true;
        emit TransactionConfirmed(msg.sender, _txId);
    }

    function isOwner(address _address) public view returns (bool _isOwner) {
        _isOwner = owners[_address];
    }

    function _setOwners(address[] memory _owners) private {
        if (_owners.length == 0) {
            revert(
                "MultiSign: No valid owners length. At least one is required."
            );
        }
        for (uint i = 0; i < _owners.length; i++) {
            owners[_owners[i]] = true;
            ownersCount++;
        }
    }

    ...

    function _getHashId(
        address _to,
        uint256 _value,
        bytes memory _data
    ) private view returns (bytes32 _hashId) {
        _hashId = keccak256(
            abi.encodePacked(_to, _value, _data, block.timestamp)
        );
    }

    ...
}

```

### [Test](test/MultiSign.ts)

```typescript
// ...
import { iERC20 } from "./abi/erc20Fragment";

const parseEthers = ethers.utils.parseEther;
const stringToBytes = ethers.utils.toUtf8Bytes;

const mintSignature = iERC20.getSighash("mint");

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

  // ...

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
});
```

Now an owner can submit a transaction and confirm it in a single transaction and we reused the internal `_confirmTransaction` function to allow to an owner to confirm a proposed transaction. But, there is now way to execute a transaction.

### [Final contract](contracts/MultiSign.sol)

```solidity
contract MultiSign {
    struct Transaction {
        address to;
        uint256 value;
        bool executed;
        bytes data;
    }

    uint256 public threshold;

    address[] private owners;
    uint256 public ownersCount;

    mapping(bytes32 => Transaction) public transactions;

    mapping(bytes32 => mapping(address => bool)) public confirmations;

    event TransactionCreated(bytes32 indexed txId);
    event TransactionSubmitted(address destination, uint256 value);
    event TransactionConfirmed(address owner, bytes32 indexed txId);
    event TransactionExecuted(bytes32 txId, address destination, uint256 value);
    event FoundsAdded(address indexed owner, uint256 value);

    error NotAnOwner(address account);

    modifier onlyOwners() {
        if (!isOwner(msg.sender)) revert NotAnOwner(msg.sender);
        _;
    }

    modifier validAddress(address _to) {
        if (_to == address(0) && _to == address(this))
            revert("MultiSign: Invalid address.");
        _;
    }

    modifier validData(bytes memory _data) {
        if (_data.length == 0) revert("MultiSign: Empty data is not valid.");
        _;
    }

    modifier isExistingTransaction(bytes32 _txId) {
        if (
            keccak256(abi.encode(transactions[_txId])) ==
            keccak256(abi.encode(Transaction(address(0), 0, false, bytes(""))))
        ) revert("MultiSign: Transaction does not exist.");
        _;
    }

    modifier notZeroValue() {
        if (msg.value == 0) revert("MultSign: Zero value");
        _;
    }

    constructor(address[] memory _owners, uint256 _threshold) {
        _setOwners(_owners);
        _setThreshold(_threshold);
    }

    function addTransaction(
        address _to,
        uint256 _value,
        bytes memory _data
    ) internal onlyOwners validAddress(_to) validData(_data) returns (bytes32) {
        bytes32 _txId = _getHashId(_to, _value, _data);

        transactions[_txId] = Transaction({
            to: _to,
            value: _value,
            executed: false,
            data: _data
        });

        emit TransactionCreated(_txId);

        return _txId;
    }

    function submitTransaction(
        address _to,
        uint256 _value,
        bytes calldata _data
    ) external onlyOwners {
        _confirmTransaction(addTransaction(_to, _value, _data));
        emit TransactionSubmitted(_to, _value);
    }

    function confirmTransaction(bytes32 _txId) public onlyOwners {
        _confirmTransaction(_txId);
    }

    function getConfirmationsCount(
        bytes32 _txId
    ) public view returns (uint256) {
        uint256 confirmationsCount;
        for (uint256 i = 0; i < ownersCount; i++) {
            if (confirmations[_txId][owners[i]]) {
                confirmationsCount++;
            }
        }
        return confirmationsCount;
    }

    function isConfirmed(bytes32 _txId) public view returns (bool) {
        if (getConfirmationsCount(_txId) < threshold) return false;
        return true;
    }

    function executeTransaction(bytes32 _txId) public onlyOwners {
        Transaction storage _tx = transactions[_txId];

        if (!isConfirmed(_txId))
            revert("MultiSign: Trnsaction not confirmed yet");
        if (_tx.value > address(this).balance)
            revert("MultiSign: Not enougth balance");

        _tx.executed = true;

        (bool s, ) = payable(_tx.to).call{value: _tx.value}(_tx.data);
        if (!s) revert("TRANSACTION_FAILED");

        emit TransactionExecuted(_txId, _tx.to, _tx.value);
    }


    function isOwner(address _address) public view returns (bool _isOwner) {
        for (uint i = 0; i < owners.length; i++) {
            if (owners[i] == _address) {
                _isOwner = true;
                break;
            }
        }
    }


    function fund() external payable onlyOwners notZeroValue {
        emit FoundsAdded(msg.sender, msg.value);
    }

    function _confirmTransaction(
        bytes32 _txId
    ) internal isExistingTransaction(_txId) {
        confirmations[_txId][msg.sender] = true;

        emit TransactionConfirmed(msg.sender, _txId);

        if (getConfirmationsCount(_txId) >= threshold) {
            executeTransaction(_txId);
        } else {
            emit TransactionConfirmed(msg.sender, _txId);
        }
    }

    function _setOwners(address[] memory _owners) private {
        if (_owners.length == 0) {
            revert(
                "MultiSign: No valid owners length. At least one is required."
            );
        }

        owners = _owners;
        ownersCount = _owners.length;
    }

    function _setThreshold(uint256 _threshold) private {
        if (_threshold == 0)
            revert(
                "MultiSign: Invalid value threshold value of 0. Required threshold > 1"
            );
        if (_threshold > ownersCount)
            revert("MultiSign. Setting more threshold than owners.");
        threshold = _threshold;
    }

    function _getHashId(
        address _to,
        uint256 _value,
        bytes memory _data
    ) private view returns (bytes32 _hashId) {
        _hashId = keccak256(
            abi.encodePacked(_to, _value, _data, block.timestamp)
        );
    }

    receive() external payable notZeroValue {
        emit FoundsAdded(msg.sender, msg.value);
    }

    fallback() external payable {
        if (msg.value != 0) {
            emit FoundsAdded(msg.sender, msg.value);
        }
    }
}
```

[Final test](test/MultiSign.ts)

```typescript
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
```

# Exercise - Implement a ERC-20 from scratch

## Description

In this exercise you need to implement a ERC-20 implementation following the ERC-20 standard [here](https://eips.ethereum.org/EIPS/eip-20). Use the `contracts/Token.sol` file.
When you get that done execute the following command from the root folder.

```shell
npx hardhat test test/Token.ts
```

If you see all the test with a `✅` thats means you win!! else, you can see my solution in the `solution` branch.

# Extra content

1. [Get started with TypeScript](https://learn.microsoft.com/en-us/training/modules/typescript-get-started/)
