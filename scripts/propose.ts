import { ethers } from "hardhat";
import { DEPLOYMENTS, PROPOSAL1 } from "../hardhat-helper-config";
const { args, proposalDesc, functionToCall, value } = PROPOSAL1;

export const makeProposal = async (
  value: number[],
  functionToCall: string,
  args: unknown[],
  proposalDesc: string
) => {
  //get address of tragetContract
  //get Governer and invoke proposal
  //get callData
  //propDesc

  const { governor, petroStake } = DEPLOYMENTS;
  //function createOilContract(string calldata contractName, uint256 contractValue) external onlyOwner {
  const encodedFunctionCall = petroStake.interface.encodeFunctionData(functionToCall, args);

  const tx = await governor.propose([petroStake.address], value, [encodedFunctionCall], proposalDesc);
  const txReceipt = await tx.wait(1);
};
await makeProposal(value, functionToCall, args, proposalDesc)
  .then(() => process.exit(0))
  .catch((err) => {
    console.log(err);
    process.exit(1);
  });

/****
 * 
	function propose(
		address[] memory targets, -the traget contract(s) subject to governance
		uint256[] memory values, - ether send with each contract
		bytes[] memory calldatas, - in those target contracts, what functions are we calling and what args are we passing in
		string memory description - human readable description of what is being proposed
 */
