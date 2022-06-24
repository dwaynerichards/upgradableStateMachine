import * as dotenv from "dotenv";
dotenv.config();
import { ethers } from "ethers";
import { network } from "hardhat";
export const provider = new ethers.providers.AlchemyProvider(
  "homestead",
  process.env.ALCHEMY_API_KEY
);

export const getBlockNumber = async () => await provider.getBlockNumber();

export const resetFork = async (blockNumber: number) => {
  await network.provider.request({
    method: "hardhat_reset",
    params: [
      {
        forking: {
          jsonRpcUrl: process.env.ALCHEMY_API_KEY,
          blockNumber,
        },
      },
    ],
  });
};
