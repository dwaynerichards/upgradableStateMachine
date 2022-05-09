import { Contract } from "ethers";
import { ethers } from "hardhat";

export const VOTING_DELAY = 1;
export const VOTING_PERIOD = 45818;
export const QUORUM_PERCENTAGE = 4;
export const MIN_DELAY = 3600;
export const PROPOSERS = [];
export const EXECUTIONERS = [];
export const DEPLOYMENTS: deployment = {};
export const ADDRESS_ZERO = "0x0000000000000000000000000000000000000000";

export const PROPOSAL1 = {
  args: ["Deal1", ethers.utils.parseEther("100")],
  proposalDesc: "Proposal to create Lease 1",
  functionToCall: "createOilContract",
  value: [0],
};

interface deployment {
  [k: string]: Contract;
}
