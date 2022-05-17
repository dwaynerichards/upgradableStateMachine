import { DeployFunction, ExtendedArtifact } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { upgrades } from "hardhat";
import { log } from "console";
import { getArtifactAndFactory } from "../hardhat-helper-config";
import { ContractFactory } from "ethers";

const deployGovToken: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { getNamedAccounts, deployments } = hre;
  const { deployer } = await getNamedAccounts();
  const { save } = deployments;
  /***
   * You can use this plugin in a Hardhat script to deploy an upgradeable
   * instance of one of your contracts via the "deployProxy" function: */
  log("deployer address :", deployer);
  log("Deploying GovToken Proxy and implementation contract...");
  const { GovToken, artifact } = await getArtifactAndFactory(hre, "GovToken");
  const govToken = await upgrades.deployProxy(GovToken as ContractFactory, { kind: "uups" });
  await govToken.deployed();
  /****
   * save(name: string, deployment: DeploymentSubmission): Promise<void>; // low level save of deployment
  get(name: string): Promise<Deployment>; // fetch a deployment by name, throw if not existingsave(name: string, deployment: DeploymentSubmission): Promise<void>; // low level save of deployment
   */
  await save("GovToken", {
    address: govToken.address,
    ...(artifact as ExtendedArtifact),
  });
  log("01- GovToken deployed to:", govToken.address);

  const delegateTx = await govToken.delegate(deployer);
  await delegateTx.wait(1); //value passed into wait method = number of confirmations
  console.log("checkpoint: ", await govToken.numCheckpoints(deployer));
  //erc20Votes has concept of a checkpoint, a snapshot in time that summerizes voting power at that checkpoint in time
  //should be 1
};
export default deployGovToken;
deployGovToken.tags = ["GovToken"];

/***
 *
  await (async (govTokenAddress: string, delegatedAccount: string) => {
    const govToken = await ethers.getContractAt("GovToken", govTokenAddress);
    const delegateTx = await govToken.delegate(delegatedAccount);
    await delegateTx.wait(1); //value passed into wait method = number of confirmations
    console.log("checkpoint: ", await govToken.numCheckpoints(delegatedAccount));
  })(govToken.address, deployer);
 */
