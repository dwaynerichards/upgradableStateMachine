import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { upgrades, ethers } from "hardhat";

const govToken: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { getNamedAccounts } = hre;
  const { deployer } = await getNamedAccounts();

  /***
   * You can use this plugin in a Hardhat script to deploy an upgradeable
   * instance of one of your contracts via the "deployProxy" function: */

  const GovToken = await ethers.getContractFactory("GovToken");
  const govToken = await upgrades.deployProxy(GovToken);
  await govToken.deployed();
  console.log("GovToken deployed to:", govToken.address);
};
export default govToken;
