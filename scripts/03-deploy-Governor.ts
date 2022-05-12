import { log, time } from "console";
import { ethers, upgrades } from "hardhat";
import {
  VOTING_DELAY,
  VOTING_PERIOD,
  QUORUM_PERCENTAGE,
  DEPLOYMENTS,
  ADDRESS_ZERO,
} from "../hardhat-helper-config";

const deployGovernor = async () => {
  const [deployer] = await ethers.getSigners();
  const { timeLock, govToken } = DEPLOYMENTS;

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

  const ADMIN_ROLE = await timeLock.TIMELOCK_ADMIN_ROLE();
  const PROPOSER_ROLE = await timeLock.PROPOSER_ROLE();
  const EXECUTOR_ROLE = await timeLock.EXECUTOR_ROLE();
  //const CANCELLER_ROLE = await TimeLock.CANCELLER_ROLE()
  await timeLock.grantRole(PROPOSER_ROLE, governor.address).then(async (tx: any) => await tx.wait(1));
  await timeLock.grantRole(EXECUTOR_ROLE, ADDRESS_ZERO).then(async (tx: any) => await tx.wait(1));
  await timeLock.revokeRole(ADMIN_ROLE, deployer).then(async (tx: any) => await tx.wait(1));

  log("Governor contract has Proposer Role :", await timeLock.hasRole(PROPOSER_ROLE, governor.address));
  log("Deployer contract has admin Role :", await timeLock.hasRole(ADMIN_ROLE, deployer));
};

deployGovernor()
  .then(() => process.exit(0))
  .catch((err) => {
    console.log(err);
    process.exit(1);
  });
deployGovernor.tags = ["Governor"];
deployGovernor.dependencies = ["GovToken", "TimeLock"];

export default deployGovernor;
