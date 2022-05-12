import { upgrades, ethers } from "hardhat";
import { log } from "console";
import { DEPLOYMENTS } from "../hardhat-helper-config";

const deployGovToken = async () => {
  log("Deploying GovToken Proxy and Implementation contract...");
  const GovToken = await ethers.getContractFactory("GovToken");
  const govToken = await upgrades.deployProxy(GovToken, { kind: "uups" });

  DEPLOYMENTS.govToken = await govToken.deployed();
  log("01- GovToken deployed to:", govToken.address);

  const [deployer] = await ethers.getSigners();

  const delegateTx = await govToken.delegate(deployer);
  await delegateTx.wait(1); //value passed into wait method = number of confirmations
  console.log("checkpoint: ", await govToken.numCheckpoints(deployer));
  //erc20Votes has concept of a checkpoint, a snapshot in time that summerizes voting power at that checkpoint in time
  //should be 1
};

deployGovToken()
  .then(() => process.exit(0))
  .catch((err) => {
    console.log(err);
    process.exit(1);
  });
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
