pragma solidity ^0.8.0;
// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

contract PetroStake is Initializable, UUPSUpgradeable, OwnableUpgradeable, ERC721Upgradeable {
	uint256 public contractIds;
	mapping(uint256 => OilContract) public oilContracts;
	mapping(bytes32 => mapping(uint256 => uint256)) public contractIdToNftAmount;

	//	mapping(NFT_ID => mapping(uint256 => Payment)) payments;
	/**
    * @dev contracts which have been extended must have thir intializer/constructor invoked
    __{contractName}_init acts as a constructor
    * @ param newOwner multsig wallet should be initialized as newOwner
     */
	ISwapRouter public swapRouter;
	address public USDC;
	address public WETH;
	// For this example, we will set the pool fee to 0.3%.
	uint24 public constant poolFee = 3000;
	struct OilContract {
		uint256 id;
		uint256 totalValue;
		bytes32 name;
		bool available;
		uint256 totalValueLocked;
		bool funded;
		uint256 nftIds;
		uint256 paymentId;
		//payment dispatching should be indexedrather than saved onchain
	}

	function initialize(
		address newOwner,
		address _stableCoin,
		address _WETH,
		ISwapRouter _swapRouter
	) public initializer {
		__UUPSUpgradeable_init();
		__Ownable_init();
		__ERC721_init("ArtPartitionTolerantStateDOA", "APTSD");
		transferOwnership(newOwner);
		swapRouter = _swapRouter;
		USDC = _stableCoin;
		WETH = _WETH;
	}

	/**
	 * @dev function will create Oil contract
	 */
	event OilContractDeedPurchased(uint256 indexed contractId, uint256 indexed nftId, uint256 indexed deedAmount);
	event OilContractCreated(uint256 indexed contractId, uint256 indexed contractValue);
	event OilContractAvail(
		uint256 indexed contractId,
		bytes32 indexed contractName,
		uint256 indexed contractValue,
		bool available
	);
	event OilContractUnAvail(
		uint256 indexed contractId,
		bytes32 indexed contractName,
		uint256 indexed contractValue,
		bool available
	);
	event ContractFunded(
		uint256 indexed contractId,
		bytes32 indexed contractName,
		uint256 indexed totalValueLocked,
		bool isFunded
	);
	event PaymentDispatched(uint256 indexed nftId, uint256 indexed paymentId, uint256 indexed paymentAmount, address owner);

	function _createName(string calldata _name, uint256 _id) internal view returns (bytes32) {
		return keccak256(abi.encodePacked(_name, _id, address(this)));
	}

	/**
	 * @dev function will create oil contract
	 * @param contractName: the name of contract
	 * @param contractValue: the total value of contract
	 **/

	function createOilContract(string calldata contractName, uint256 contractValue) external onlyOwner {
		require(contractValue > 100000, "Contract Value under 100000");
		require(keccak256(abi.encodePacked(contractName)) != keccak256(abi.encodePacked("")), "Name required!");
		uint256 contractId = contractIds++;
		OilContract memory oilContract;
		oilContract.id = contractId;
		oilContract.totalValue = contractValue;
		oilContract.name = _createName(contractName, contractId);
		oilContracts[contractId] = oilContract;
		emit OilContractCreated(contractId, contractValue);
	}

	/**
	 * @dev makeContractAvail will make well contract avail to public to buyStakeInOilContract
	 */
	function makeContractAvail(uint256 contractId) external onlyOwner {
		OilContract memory oilContract = oilContracts[contractId];
		require(oilContract.available == false, "Oil contract not available");
		oilContract.available = _changeAvailability(oilContract);
		require(oilContract.available, "OilContract not made available");
		emit OilContractAvail(oilContract.id, oilContract.name, oilContract.totalValue, oilContract.available);
		oilContracts[contractId] = oilContract;
	}

	function _changeAvailability(OilContract memory oilContract) internal pure returns (bool) {
		oilContract.available = !oilContract.available;
		return oilContract.available;
	}

	/**
	 * @dev makeContractUnAvail will make well contract avail to public to buyStakeInOilContract
	 */
	function makeContractUnAvail(uint256 contractId) external onlyOwner {
		OilContract memory oilContract = oilContracts[contractId];
		require(oilContract.available, "Contract already unavailable");
		oilContract.available = _changeAvailability(oilContract);
		require(!oilContract.available, "OilContract still available");
		emit OilContractUnAvail(oilContract.id, oilContract.name, oilContract.totalValue, oilContract.available);
		oilContracts[contractId] = oilContract;
	}

	/**
	 * @dev purchaseContractStake will update contracts and dispatch NFTS to funders
	 * @param contractId: id of contract
	 */
	//considerations should be made for if we dont meet demand
	function purchaseContractStake(uint256 contractId) external payable {
		OilContract memory oilContract = oilContracts[contractId];
		uint256 availPurchaseAmount = oilContract.totalValue - oilContract.totalValueLocked;
		require(msg.value <= availPurchaseAmount, "Too much ether sent");
		require(!oilContract.funded, "Contract fully funded");
		require(oilContract.available, "Contract not available");
		
		uint usdcAmount = _swapEthForStable();

		contractIdToNftAmount[oilContract.name][oilContract.nftIds++] = usdcAmount;

		oilContract.totalValueLocked += usdAmount;
		emit OilContractDeedPurchased(oilContract.id, oilContract.nftIds, usdAmount);
		if (oilContract.totalValueLocked >= oilContract.totalValue) {
			oilContract.funded = true;
			oilContract.available = false;
			emit ContractFunded(oilContract.id, oilContract.name, oilContract.totalValueLocked, oilContract.funded);
		}
		_dispatchNFT(msg.sender, oilContract.nftIds);
		oilContracts[contractId] = oilContract;
	}
   /// @notice swapEthRoStable swaps a fixed amount of WETH (amountIn) for a maximum possible amount of USDC
    /// @return amountOut The amount of USDC received.
	function _swapEthToStable() internal view returns (uint256 usdAmount) {
		uint minUSDC = _getAmountOutMin()
		ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
			tokenIn: WETH,
			tokenOut: USDC,
			fee: poolFee,
			recipient: address(this),
			deadline: block.timestamp,
			amountIn: msg.value,
			amountOutMinimum: minUSDC,
			sqrtPriceLimitX96: 0
		});

		usdcAmount = swapRouter.exactInput(params);
	}

	function _getAmountOutMin() internal view returns (uint256) {
		//minAmount is product of offcahin rate
		//In production, use an oracle or other data source to choose a safer value for amountOutMinimum.
		uint256 oracleUSDPerEth = _getOracleRate(USDC, WETH);
		uint256 usdcAmount = oracleUSDPerEth * msg.value;
		return usdcAmount;
	}

	function _getOracleRate(
		address USDS,
		address WETH,
		uint256 amount
	) internal pure returns (uint256) {}
}

/**
 * @dev _updateContract increment contractNFTID, updates TVL, and adds newTokenId to mapping
 * @return newTokenId : the token ID to be passed into dispatchNFT internal function
 */

/** @dev function dispatches token using _safeMint, an internal function extended from 721Upgradeable */
function _dispatchNFT(address to, uint256 nftId) internal {
	//safeMint emits transfer event
	_safeMint(to, nftId); //NEED META DATA
	//tokenURI requirment will involve erc721uristorage rather than regular erc721
	//_setTokenUri(nftId, tokenURI)
}

/**
 * @dev functions dispatches and records payments to each ownerOf NFT associated with contract
 */
function dispatchPayments(uint256 contractId) external payable onlyOwner {
	OilContract memory oilContract = oilContracts[contractId];
	require(oilContract.funded, "contract must me funded");
	oilContracts[contractId] = _dispatchPayments(oilContract);
}

/**
	* @dev function iterates through nftId's, dispatches payment to ownerOf nft, records Payment receipt
    consider putting in reentrancy guard as contract will continue to execute as itteration continues through nftId's
    * @param oilContract: oilContract with which to dispatch payments
     */
//instead of dispatching payment to wallet
//pay into oilContract
//let owner of nft pull payments from contract
//or instantiate new literal contract/ with address for each oil contract
//dispatch payents to each oil contract
//let nft owners pull payment from each oil contract address
function _dispatchPayments(OilContract memory oilContract) internal returns (OilContract memory) {
	for (uint256 nftId = 1; nftId <= oilContract.nftIds; nftId++) {
		uint256 paymentId = oilContract.paymentId++; //function increments paymentIDs
		address nftOwner = ownerOf(nftId);
		uint256 paymentDue = _calculatePayment(nftId, oilContract.name, oilContract.totalValue);
		(bool success, ) = payable(nftOwner).call{ value: paymentDue }("");
		require(success, "PaymentError");
		emit PaymentDispatched(nftId, paymentId, paymentDue, nftOwner);
	}
	return oilContract;
}

/**
 * @dev function calculates payment die to an ownerOf nft associated with contract
 * @param nftId: uint identifier associated with nft
 * @param contractName: encoded name of contract
 * @param contractVal: total value of contract
 */
function _calculatePayment(
	uint256 nftId,
	bytes32 contractName,
	uint256 contractVal
) internal view returns (uint256 amountDue) {
	//access nft  access deed, caliculate percentage of totalContractValue
	//mapping(bytes32 => mapping(uint256 => uint256)) contractIdToNFT_Amount;
	uint256 ownerStake = contractIdToNftAmount[contractName][nftId];
	amountDue = _getAmountDue(ownerStake, contractVal);
	return amountDue;
}

/**
 * @dev function calculates percentage of contract owned by ownerOf NFT, and determines amount due to ownerOf NFT
 * @param ownerStake: theamount of value the owner has in he oil contract
 * @param contractValue: the total value of the oil contract
 */
function _getAmountDue(uint256 ownerStake, uint256 contractValue) private pure returns (uint256 amountDue) {
	uint256 percentageOwed = _getBasis(ownerStake, contractValue);
	amountDue = (percentageOwed * contractValue) / 10000;
}

function _getBasis(uint256 _numerator, uint256 denominator) private pure returns (uint256 _basis) {
	// caution, check safe-to-multiply here
	uint256 numerator = _numerator * 10000;
	// with rounding of last digit
	_basis = numerator / denominator;
	// 101 numeratr,450 denominator, 3 percision : will equal 224, i.e. 22.4%.
	return _basis;
}

function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

}

