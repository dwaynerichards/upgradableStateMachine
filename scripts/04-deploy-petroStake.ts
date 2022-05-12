import { log } from "console";
import { ethers, upgrades } from "hardhat";
import { DEPLOYMENTS } from "../hardhat-helper-config";

const deployPetro = async () => {
  log("Deploying PetroStake Proxy and Imp...");

  const ARGS = [DEPLOYMENTS.timeLock.address];

  //timeLockaddress is passed into initializer function as owner
  const PetroStake = await ethers.getContractFactory("PetroStake");
  const petroStake = await upgrades.deployProxy(PetroStake, ARGS, { kind: "uups" });
  DEPLOYMENTS.petroStake = await petroStake.deployed();
  log("4- PetroStake deployed at :", petroStake.address);
  const isTimeLockOWner = DEPLOYMENTS.timeLock.address == (await petroStake.owner());
  log("owner of Petro stake is now TimeLock Contract: ", isTimeLockOWner);
  //who is owner() of petrostake, timeLock
};

deployPetro()
  .then(() => process.exit(0))
  .catch((err) => {
    console.log(err);
    process.exit(1);
  });
deployPetro.tags = ["PetroStake"];
export default deployPetro;
