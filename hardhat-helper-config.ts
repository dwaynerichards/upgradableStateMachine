import { Contract } from "ethers";
import { ethers } from "hardhat";
import { network } from "hardhat";

export const VOTING_DELAY = 1;
export const VOTING_PERIOD = 45818;
export const QUORUM_PERCENTAGE = 4;
export const MIN_DELAY = 3600;
export const PROPOSERS = [];
export const EXECUTIONERS = [];
export const DEPLOYMENTS: deployment = {};
export const ADDRESS_ZERO = "0x0000000000000000000000000000000000000000";
export const PROPOSAL_FILE = "proposals.json";

export const PROPOSAL1 = {
  args: ["Deal1", ethers.utils.parseEther("100")],
  proposalDesc: "Proposal to create Lease 1",
  functionToCall: "createOilContract",
  value: [0],
};

export const moveBlocks = async (moves: number) => {
  for (let i = 0; i < moves; i++) {
    await network.provider.request({
      method: "evm_mine",
      params: [],
    });
  }
  console.log(`moved ${moves} blocks`);
};

export const devChains = ["hardhat", "localhost"];
interface deployment {
  [k: string]: Contract;
}
