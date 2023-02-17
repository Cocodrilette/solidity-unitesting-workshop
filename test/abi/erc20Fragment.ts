import { ethers } from "hardhat";

export const iERC20 = new ethers.utils.Interface([
  "function mint(uint amount) payable",
]);
