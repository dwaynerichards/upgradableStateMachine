import { log } from "console";
import { ethers, upgrades } from "hardhat";
import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DEPLOYMENTS } from "../hardhat-helper-config";

const deployPetro: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  log("Deploying PetroStake Proxy and Imp");

  const ARGS = [DEPLOYMENTS.timeLock.address];
  const PetroStake = await ethers.getContractFactory("PetroStake");
  const petroStake = await upgrades.deployProxy(PetroStake, ARGS, { kind: "uups" });
  DEPLOYMENTS.petroStake = await petroStake.deployed();
  log("PetroStake deployed at :", petroStake.address);
  const isTimeLockOWner = DEPLOYMENTS.timeLock.address == (await petroStake.owner());
  log("PetroStake depoyed at :", petroStake.address);
  log("owner of Petro stake is now TimeLock Contract: ", isTimeLockOWner);
  //who is owner() of petrostake, timeLock
};

export default deployPetro;
