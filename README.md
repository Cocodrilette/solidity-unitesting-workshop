# Solidity Unitesting

# Content

- [Solidity Unitesting](#solidity-unitesting)
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
- [Extra content](#extra-content)

---

# Requirements

- [Node.js](https://nodejs.org/en/) (_v18.14.0 LTS or higher_)

---

# Set up

1. Clone the repo

```shell
git clone https://github.com/Cocodrilette/solidity-unitesting-workshop
```

2. Install dependencies

```shell
npm install
```

---

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

---

# Walkthrough

## What's a multi-signature contract

A multi-signature contract is a smart contract designed so that multiple signatures from different addresses are needed for a transaction to be executed.

In this workshop, we will be testing a multi-signature contract. The contract is a simple one, but it is enough to understand the basics of unit testing.

## `describe` and `it`

Usually a test looks like the code below. The building block of almost any test file are the functions `describe` and `it`.

> The best way to think of this is just a general function scope that **"describes"** the suite of test cases enumerated by the **"it"**. functions inside.

Inside that describe, we have an `it` function. These are the specific unit test targets... just sound it out!: "I want it to x.", "I want it to y.", etc.

```
const { loadFixture } = require('@nomicfoundation/hardhat-network-helpers');
const { expect } = require('chai');

describe('Faucet', function () {
  async function deployContractAndSetVariables() {
    const Faucet = await ethers.getContractFactory('Faucet');
    const faucet = await Faucet.deploy();

    const [owner] = await ethers.getSigners();

    console.log('Signer 1 address: ', owner.address);
    return { faucet, owner };
  }

  it('should deploy and set the owner correctly', async function () {
    const { faucet, owner } = await loadFixture(deployContractAndSetVariables);

    expect(await faucet.owner()).to.equal(owner.address);
  });
});
```

## Dissection

First we need know how are the owners and what is the required threshold to execute a proposal.

### Contract

```solidity
contract MultiSig {
    mapping(address => bool) public owners;
    uint256 private ownersCount;
    uint256 public threshold;

    error NotAnOwner(address account);

    modifier onlyOwners() {
        if (!_isOwner(msg.sender)) revert NotAnOwner(msg.sender);
        _;
    }

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

    function _isOwner(address _address) private view returns (bool) {
        return owners[_address];
    }

    receive() external payable {}

    fallback() external payable {}
}

```

### Test

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

---

# Extra content

1. [Writing Upgradeable Contracts](https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable)
2. [Get started with TypeScript](https://learn.microsoft.com/en-us/training/modules/typescript-get-started/)
