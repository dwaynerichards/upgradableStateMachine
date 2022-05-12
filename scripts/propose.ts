import { ethers, network, upgrades } from "hardhat";
import {
  DEPLOYMENTS,
  devChains,
  moveBlocks,
  PROPOSAL1,
  PROPOSAL_FILE,
  VOTING_DELAY,
} from "../hardhat-helper-config";
import * as fs from "fs";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/dist/types";
const { args, proposalDesc, functionToCall, value } = PROPOSAL1;
import { getImplementationAddress, } from "@openzeppelin/upgrades-core";


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
  /***
   * 
  value: number[],
  functionToCall: string,
  args: unknown[],
  proposalDesc: string
   */

  const { governor, petroStake } = DEPLOYMENTS;
  //function createOilContract(string calldata contractName, uint256 contractValue) external onlyOwner {

  //const petroStake = await ethers.getContractAt("PetroStake");
  //const governor = await ethers.getContractAt("Governor");

  console.log("***logging petrostake Interface ===> ***");
  console.log(DEPLOYMENTS);

  const encodedFunctionCall = petroStake.interface.encodeFunctionData(functionToCall, args);

  const tx = await governor.propose([petroStake.address], value, [encodedFunctionCall], proposalDesc);
  const txReceipt = await tx.wait(1);

  const proposalId = txReceipt.events[0].args.proposalId.toString();
  console.log("Proposal ID ===>", proposalId);

  fs.writeFileSync(
    PROPOSAL_FILE,
    JSON.stringify({
      [network.config.chainId!.toString()]: [proposalId],
    })
  );

  if (devChains.includes(network.name)) await moveBlocks(VOTING_DELAY + 1); //jumpingTime if in development
};

makeProposal(value, functionToCall, args, proposalDesc)
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
