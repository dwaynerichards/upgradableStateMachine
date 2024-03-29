import { ContractFactory } from "ethers";
import { ethers } from "hardhat";
import { network } from "hardhat";
import { ExtendedArtifact } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { BigNumber } from "ethers"
//For timeLock
export const MIN_DELAY = 3600;
export const PROPOSERS = [];
export const EXECUTIONERS = [];

//For Governor Contract
export const VOTING_DELAY = 1;
export const VOTING_PERIOD = 66;
export const QUORUM_PERCENTAGE = 4;

export const ADDRESS_ZERO = "0x0000000000000000000000000000000000000000";
export const PROPOSAL_FILE = "proposals.json";

export const PROPOSAL1 = {
  args: ["Deal1", ethers.utils.parseUnits("1000000", 1)],
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
export const moveTime = async (seconds: number) => {
  await network.provider.send("evm_increaseTime", [seconds]);
  console.log(`moving time forward ${seconds} seconds`);
};

//function takes string returns obj {contract, artifact}
//obj will have address and artifact filds
//will get contract factory, get artifact, deploy, with args
export const getArtifactAndFactory = async (hre: HardhatRuntimeEnvironment, contractName: string) => {
  const { deployments } = hre;
  const { getExtendedArtifact } = deployments;
  const { getContractFactory } = ethers;
  const artifact = await getExtendedArtifact(contractName);
  return {
    artifact,
    [contractName]: (await getContractFactory(contractName)) as ContractFactory,
  };
  /***
   * {
   * constractName: Contract
   * ...artifact
   * }
   */
};


type NetworkConfigItem = {
  name: string
  fundAmount: BigNumber
  fee?: string
  keyHash?: string
  interval?: string
  linkToken?: string
  vrfCoordinator?: string
  keepersUpdateInterval?: string
  oracle?: string
  jobId?: string
  ethUsdPriceFeed?: string
}

type NetworkConfigMap = {
  [chainId: string]: NetworkConfigItem
}

export const networkConfig: NetworkConfigMap = {
  default: {
    name: "hardhat",
    fee: "100000000000000000",
    keyHash: "0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc",
    jobId: "29fa9aa13bf1468788b7cc4a500a45b8",
    fundAmount: BigNumber.from("1000000000000000000"),
    keepersUpdateInterval: "30",
  },
  31337: {
    name: "localhost",
    fee: "100000000000000000",
    keyHash: "0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc",
    jobId: "29fa9aa13bf1468788b7cc4a500a45b8",
    fundAmount: BigNumber.from("1000000000000000000"),
    keepersUpdateInterval: "30",
    ethUsdPriceFeed: "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419",
  },
  42: {
    name: "kovan",
    linkToken: "0xa36085F69e2889c224210F603D836748e7dC0088",
    ethUsdPriceFeed: "0x9326BFA02ADD2366b30bacB125260Af641031331",
    oracle: "0xc57b33452b4f7bb189bb5afae9cc4aba1f7a4fd8",
    jobId: "d5270d1c311941d0b08bead21fea7747",
    fee: "100000000000000000",
    fundAmount: BigNumber.from("1000000000000000000"),
    keepersUpdateInterval: "30",
  },
  4: {
    name: "rinkeby",
    linkToken: "0x01be23585060835e02b77ef475b0cc51aa1e0709",
    ethUsdPriceFeed: "0x8A753747A1Fa494EC906cE90E9f37563A8AF630e",
    keyHash: "0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc",
    vrfCoordinator: "0x6168499c0cFfCaCD319c818142124B7A15E857ab",
    oracle: "0xc57b33452b4f7bb189bb5afae9cc4aba1f7a4fd8",
    jobId: "6b88e0402e5d415eb946e528b8e0c7ba",
    fee: "100000000000000000",
    fundAmount: BigNumber.from("1000000000000000000"),
    keepersUpdateInterval: "30",
  },
  1: {
    name: "mainnet",
    linkToken: "0x514910771af9ca656af840dff83e8264ecf986ca",
    fundAmount: BigNumber.from("0"),
    keepersUpdateInterval: "30",
  },
  5: {
    name: "goerli",
    linkToken: "0x326c977e6efc84e512bb9c30f76e30c160ed06fb",
    fundAmount: BigNumber.from("0"),
  },
  137: {
    name: "polygon",
    linkToken: "0xb0897686c545045afc77cf20ec7a532e3120e0f1",
    ethUsdPriceFeed: "0xF9680D99D6C9589e2a93a78A04A279e509205945",
    oracle: "0x0a31078cd57d23bf9e8e8f1ba78356ca2090569e",
    jobId: "12b86114fa9e46bab3ca436f88e1a912",
    fee: "100000000000000",
    fundAmount: BigNumber.from("100000000000000"),
  },
}

export const developmentChains: string[] = ["hardhat", "localhost"]
export const VERIFICATION_BLOCK_CONFIRMATIONS = 6

export const devChains = ["hardhat", "localhost"];
