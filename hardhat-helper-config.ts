import { Contract } from "ethers";

export const VOTING_DELAY = 1;
export const VOTING_PERIOD = 45818;
export const QUORUM_PERCENTAGE = 4;
export const MIN_DELAY = 3600;
export const PROPOSERS = [];
export const EXECUTIONERS = [];
export const DEPLOYMENTS: deployment = {};
export const ADDRESS_ZERO = "0x0000000000000000000000000000000000000000";

interface deployment {
  [k: string]: Contract;
}
