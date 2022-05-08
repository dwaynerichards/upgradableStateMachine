pragma solidity ^0.8.0;
// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract PetroStake is Initializable, UUPSUpgradeable, OwnableUpgradeable, ERC721Upgradeable {
	/**@dev change uint to type for contractId's, impoved readability for mappins */
	uint256 public contractIds;
	mapping(uint256 => OilContract) public oilContracts;
	mapping(bytes32 => mapping(uint256 => uint256)) public contractIdToNftAmount;
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
	//	mapping(NFT_ID => mapping(uint256 => Payment)) payments;
	struct Payment {
		uint256 nftId;
		uint256 paymentId;
		uint256 time;
		uint256 paymentAmount;
		bool paymentRecieved;
		address owner;
	}

	/**
    * @dev contracts which have been extended must have thir intializer/constructor invoked
    __{contractName}_init acts as a constructor
    * @ param newOwner multsig wallet should be initialized as newOwner
     */
	function initialize(address newOwner) public initializer {
		__UUPSUpgradeable_init();
		__Ownable_init();
		__ERC721_init("ArtPartitionTolerantStateDOA", "APTSD");
		transferOwnership(newOwner);
	}

	function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

	/**
	 * @dev function will create Oil contract
	 */
	event OilContractDeedPurchased(uint256 contractId, uint256 nftId, uint256 deedAmount);
	event OilContractCreated(uint256 contractId, uint256 contractValue);
	event OilContractAvail(uint256 contractId, bytes32 contractName, uint256 contractValue, bool available);
	event OilContractUnAvail(uint256 contractId, bytes32 contractName, uint256 contractValue, bool available);
	event ContractFunded(uint256 contractId, bytes32 contractName, uint256 totalValueLocked, bool isFunded);
	//@dev place indexing on payment dispatch event
	//payment dispatching should be indexedrather than saved onchain
	event PaymentDispatched(uint256 nftId, uint256 paymentId, uint256 paymentAmount, address owner);

	function _createName(string calldata _name, uint256 _id) internal view returns (bytes32) {
		return keccak256(abi.encodePacked(_name, _id, address(this)));
	}

	/**
	 * @dev function will creat oil contract
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

		contractIdToNftAmount[oilContract.name][oilContract.nftIds++] = msg.value;
		oilContract.totalValueLocked += msg.value;
		emit OilContractDeedPurchased(oilContract.id, oilContract.nftIds, msg.value);
		if (oilContract.totalValueLocked >= oilContract.totalValue) {
			oilContract.funded = true;
			oilContract.available = false;
			emit ContractFunded(oilContract.id, oilContract.name, oilContract.totalValueLocked, oilContract.funded);
		}
		_dispatchNFT(msg.sender, oilContract.nftIds);
		oilContracts[contractId] = oilContract;
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
}
