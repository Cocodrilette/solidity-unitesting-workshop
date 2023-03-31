import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

const parseEthers = ethers.utils.parseEther;

describe("ERC20Token", function () {
	async function deployFixture() {
		const [owner, account1, notOwnerAccount, receiver] =
			await ethers.getSigners();

		const NAME = "MyToken";
		const SYMBOL = "MTK";
		const INITIAL_SUPPLY = parseEthers("1000");

		const ERC20Token = await ethers.getContractFactory("ERC20Token");
		const erc20Token = await ERC20Token.connect(owner).deploy(
			NAME,
			SYMBOL,
			INITIAL_SUPPLY,
		);

		return {
			owner,
			account1,
			erc20Token,
			notOwnerAccount,
			receiver,
			NAME,
			SYMBOL,
			INITIAL_SUPPLY,
		};
	}

	// * Deployment -------------------------------------------------------------

	describe("Deployment", async function () {
		it("Should set the correct constructor parameters", async function () {
			const { erc20Token, NAME, SYMBOL, INITIAL_SUPPLY } = await loadFixture(
				deployFixture,
			);

			const name = await erc20Token.name();
			const symbol = await erc20Token.symbol();
			const supply = await erc20Token.totalSupply();

			expect(name).to.be.equal(NAME);
			expect(symbol).to.be.equal(SYMBOL);
			expect(supply).to.be.equal(INITIAL_SUPPLY);
		});
	});

	// * Transfer ----------------------------------------------------------------

	describe("Transfer", async function () {
		it("Should transfer correctly", async function () {
			const { erc20Token, owner, receiver } = await loadFixture(deployFixture);

			const VALUE = parseEthers("10");

			const tx = await erc20Token
				.connect(owner)
				.transfer(receiver.address, VALUE);

			expect(tx)
				.to.emit(erc20Token, "Transfer")
				.withArgs(owner.address, receiver.address, VALUE);

			const balanceOfReceiver = await erc20Token.balanceOf(receiver.address);

			expect(balanceOfReceiver).to.be.equal(VALUE);
		});

		it("Should not transfer from third-party", async function () {
			const { erc20Token, receiver, notOwnerAccount } = await loadFixture(
				deployFixture,
			);

			const VALUE = parseEthers("10");

			let tx;
			try {
				tx = await erc20Token
					.connect(notOwnerAccount)
					.transfer(receiver.address, VALUE);
			} catch (error) {
				expect(tx).revertedWith("ERC20: Not an owner");
			}
		});
	});

	// * transferFrom -------------------------------------------------------------

	describe("Transfer From", async function () {
		it("Should transferFrom correctly", async function () {
			const { erc20Token, owner, account1, receiver } = await loadFixture(
				deployFixture,
			);

			const VALUE = parseEthers("10");

			await erc20Token.connect(owner).approve(account1.address, VALUE);

			const account1Allowance = await erc20Token.allowance(
				owner.address,
				account1.address,
			);

			// * 10 tokens allowed
			expect(account1Allowance).to.be.equal(VALUE);

			const transferFromTx = await erc20Token
				.connect(account1)
				.transferFrom(owner.address, receiver.address, VALUE);

			// * 10 tokens transfer
			expect(transferFromTx)
				.to.emit(erc20Token, "Transfer")
				.withArgs(account1.address, receiver.address, VALUE);

			const balanceOfReceiver = await erc20Token.balanceOf(receiver.address);

			expect(balanceOfReceiver).to.be.equal(VALUE);
		});

		it("Should not transferFrom if not allowed", async function () {
			const { erc20Token, receiver, notOwnerAccount } = await loadFixture(
				deployFixture,
			);

			const VALUE = parseEthers("10");

			let tx;
			try {
				tx = await erc20Token
					.connect(notOwnerAccount)
					.transfer(receiver.address, VALUE);
			} catch (error) {
				expect(tx).revertedWith("ERC20: Not an owner");
			}
		});
	});
});
