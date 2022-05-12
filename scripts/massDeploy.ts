// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.

// Hardhat always runs the compile task when running scripts with its command
// line interface.
//
// If this script is run directly using `node` you may want to call compile
// manually to make sure everything is compiled
// await hre.run('compile');

// We get the contract to deploy

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
import { upgrades, ethers } from "hardhat";
import { log } from "console";
import {
  VOTING_DELAY,
  VOTING_PERIOD,
  QUORUM_PERCENTAGE,
  ADDRESS_ZERO,
  MIN_DELAY,
  PROPOSERS,
  EXECUTIONERS,
  DEPLOYMENTS,
} from "../hardhat-helper-config";

/***
 * proposers are those that can proposed a governance
 * only governor contract to be proposer, anyone can be executer
 *
 * executers are array of addresses that can execute a successful proposal
 * min delay is peroid of time after a vote has passed,
 * but before execution
 */

const massDeploy = async () => {
  const [deployer] = await ethers.getSigners();

  log("Deploying GovToken Proxy and Implementation contract...");
  const GovToken = await ethers.getContractFactory("GovToken");
  const govToken = await upgrades.deployProxy(GovToken, { kind: "uups" });
  DEPLOYMENTS.govToken = await govToken.deployed();
  log("01- GovToken deployed to:", govToken.address);
  const delegateTx = await govToken.delegate(deployer);
  await delegateTx.wait(1); //value passed into wait method = number of confirmations
  console.log("checkpoint: ", await govToken.numCheckpoints(deployer));
  //erc20Votes has concept of a checkpoint, a snapshot in time that summerizes voting power at that checkpoint in time
  //should be 1

  log("Deploying TimeLock Proxy and Imp contract...");
  const TimeLock = await ethers.getContractFactory("TimeLock");
  const timeLock = await upgrades.deployProxy(TimeLock, [MIN_DELAY, PROPOSERS, EXECUTIONERS], {
    kind: "uups",
  });
  DEPLOYMENTS.timeLock = await timeLock.deployed();
  log("02- TimeLock deployed to :", timeLock.address);
  const ADMIN_ROLE = await timeLock.TIMELOCK_ADMIN_ROLE();
  log("Deployer has admin role: ", await timeLock.hasRole(ADMIN_ROLE, deployer));

  log("Deploying Governor proxy and Implementation contract...");
  const ARGS: unknown[] = [
    govToken.address,
    timeLock.address,
    VOTING_DELAY,
    VOTING_PERIOD,
    QUORUM_PERCENTAGE,
  ];
  const Governor = await ethers.getContractFactory("Governor");
  const governor = await upgrades.deployProxy(Governor, ARGS, { kind: "uups" });
  DEPLOYMENTS.governor = await governor.deployed();

  log("03 - Governor depoyed at :", governor.address);

  const PROPOSER_ROLE = await timeLock.PROPOSER_ROLE();
  const EXECUTOR_ROLE = await timeLock.EXECUTOR_ROLE();
  //const CANCELLER_ROLE = await TimeLock.CANCELLER_ROLE()
  await timeLock.grantRole(PROPOSER_ROLE, governor.address).then(async (tx: any) => await tx.wait(1));
  await timeLock.grantRole(EXECUTOR_ROLE, ADDRESS_ZERO).then(async (tx: any) => await tx.wait(1));
  await timeLock.revokeRole(ADMIN_ROLE, deployer).then(async (tx: any) => await tx.wait(1));

  log("Governor contract has Proposer Role :", await timeLock.hasRole(PROPOSER_ROLE, governor.address));
  log("Deployer contract has admin Role :", await timeLock.hasRole(ADMIN_ROLE, deployer));

  log("Deploying PetroStake Proxy and Imp...");

  //timeLockaddress is passed into initializer function as owner
  const PetroStake = await ethers.getContractFactory("PetroStake");
  const petroStake = await upgrades.deployProxy(PetroStake, [timeLock.address], { kind: "uups" });
  DEPLOYMENTS.petroStake = await petroStake.deployed();
  log("4- PetroStake deployed at :", petroStake.address);
  const isTimeLockOWner = DEPLOYMENTS.timeLock.address == (await petroStake.owner());
  log("owner of Petro stake is now TimeLock Contract: ", isTimeLockOWner);
  return DEPLOYMENTS;
};

export const deployedUpgrades = await massDeploy()
  .then(() => process.exit(0))
  .catch((err) => {
    console.log(err);
    process.exit(1);
  });
export default massDeploy;

/***
 *
  await (async (govTokenAddress: string, delegatedAccount: string) => {
    const govToken = await ethers.getContractAt("GovToken", govTokenAddress);
    const delegateTx = await govToken.delegate(delegatedAccount);
    await delegateTx.wait(1); //value passed into wait method = number of confirmations
    console.log("checkpoint: ", await govToken.numCheckpoints(delegatedAccount));
  })(govToken.address, deployer);
 */
