import { log } from "console";
import { ethers, upgrades } from "hardhat";
import { MIN_DELAY, PROPOSERS, EXECUTIONERS, DEPLOYMENTS } from "../hardhat-helper-config";

/***
 * proposers are those that can proposed a governance
 * only governor contract to be proposer, anyone can be executer
 *
 * executers are array of addresses that can execute a successful proposal
 * min delay is peroid of time after a vote has passed,
 * but before execution
 */
const deployTimeLock = async () => {
  const [deployer] = await ethers.getSigners();
  log("Deploying TimeLock Proxy and Imp contract...");

  const TimeLock = await ethers.getContractFactory("TimeLock");
  const ARGS = [MIN_DELAY, PROPOSERS, EXECUTIONERS];
  const timeLock = await upgrades.deployProxy(TimeLock, ARGS, {
    kind: "uups",
  });
  DEPLOYMENTS.timeLock = await timeLock.deployed();
  log("02- TimeLock deployed to :", timeLock.address);
  const ADMIN_ROLE = await timeLock.TIMELOCK_ADMIN_ROLE();
  log("Deployer has admin role: ", await timeLock.hasRole(ADMIN_ROLE, deployer));
};

deployTimeLock()
  .then(() => process.exit(0))
  .catch((err) => {
    console.log(err);
    process.exit(1);
  });
export default deployTimeLock;
deployTimeLock.tags = ["TimeLock"];
/***
 * 
	function initialize(
		uint256 minDelay,
		address[] memory proposers,
		address[] memory executors
	) external initializer {
		//passing variables to init is the same as passing to the parent contract's constructor
		__UUPSUpgradeable_init();
		__TimelockController_init(minDelay, proposers, executors);
	}

 */
