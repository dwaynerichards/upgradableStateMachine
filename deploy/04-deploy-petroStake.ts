import { log } from "console";
import { ContractFactory } from "ethers";
import { ethers, upgrades } from "hardhat";
import { DeployFunction, ExtendedArtifact } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { getArtifactAndFactory, ADDRESS_ZERO } from "../hardhat-helper-config";

const deployStakes: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  log("Deploying PetroStake Proxy and Imp");
  const { deployments } = hre;
  const { get, save } = deployments;

  const timeLock = await get("TimeLock");
  const ARGS = [
    timeLock.address,
    ADDRESS_ZERO,
    ADDRESS_ZERO,
    ADDRESS_ZERO,
    ethers.utils.parseUnits("3000", 0),
  ];
  const { SolidStakes, artifact } = await getArtifactAndFactory(hre, "SolidStakes");
  //you can deploy upgradeable contracts linked to external libraries by setting
  //the unsafeAllowLinkedLibraries flag to true in the deployProxy or upgradeProxy calls
  const solidStakes = await upgrades.deployProxy(SolidStakes as ContractFactory, ARGS, {
    kind: "uups",
  });
  log("4- SolidStakes deployed at :", solidStakes.address);
  const isTimeLockOWner = timeLock.address == (await solidStakes.owner());
  log("owner of Petro stake is now TimeLock Contract: ", isTimeLockOWner);
  //who is owner() of petrostake, timeLock
  //console.log("deployments post mutation:", DEPLOYMENTS);

  await save("PetroStake", {
    address: solidStakes.address,
    ...(artifact as ExtendedArtifact),
  });
};
deployStakes.tags = ["SolidStakes"];
deployStakes.dependencies = ["TimeLock"];
export default deployStakes;
