pragma solidity ^0.8.0;
// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract PetroStake is OwnableUpgradeable, ERC721Upgradeable {
	type NFT_Id is uint256;
	type Time is uint256;

	/**@dev change uint to type for contractId's, impoved readability for mappins */
	uint256 public contractIds;
	mapping(uint256 => OilContract) public oilContracts;
	mapping(uint256 => mapping(NFT_Id => uint256)) contractIdToNFT_Amount;
	struct OilContract {
		uint256 id;
		uint256 totalValue;
		string name;
		bool available;
		uint256 totalValueLocked;
		bool funded;
		NFT_Id nftIds;
		uint256 paymentId;
		mapping(NFT_Id => uint256) nftIdtoAmount;
		//payment dispatching should be indexedrather than saved onchain
	}
	//	mapping(NFT_Id => mapping(uint256 => Payment)) payments;
	struct Payment {
		NFT_Id nftId;
		uint256 paymentId;
		Time time;
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
		__Ownable_init();
		__ERC721_init("ArtPartitionTolerantStateDOA", "APTSD");
		transferOwnership(newOwner);
	}

	/**
	 * @dev function will create Oil contract
	 */
	event OilContractDeedPurchased(uint256 contractId, NFT_Id nftId, uint256 deedAmount);
	event OilContractCreated(uint256 contractId, uint256 contractValue);
	event OilContractAvail(uint256 contractId, string contractName, uint256 contractValue, bool available);
	event OilContractUnAvail(uint256 contractId, string contractName, uint256 contractValue, bool available);
	event ContractFunded(uint256 contractId, string contractName, uint256 totalValueLocked, bool isFunded);
	event LogError(uint256 contractId, string contractName, string reason);

	event PaymentError(uint256 contractId, NFT_Id nftId, Time time, uint256 paymentAmount);
	//@dev place indexing on payment dispatch event
	//payment dispatching should be indexedrather than saved onchain
	event PaymentDispatched(NFT_Id nftId, uint256 paymentId, uint256 paymentAmount, address owner);

	modifier purchaseAmountAvail(uint256 contractId) {
		OilContract storage oilContract = oilContracts[contractId];
		uint256 availPurchaseAmount = oilContract.totalValue - oilContract.totalValueLocked;
		require(msg.value <= availPurchaseAmount, "Message value exceeds available amount");
		_;
	}
	modifier contractNotAvail(uint256 id) {
		require(id <= contractIds, "OilContract does not exists");
		OilContract storage oilContract = oilContracts[id];
		require(oilContract.available == false, "Oil contract not available");
		_;
	}
	modifier contractAvail(uint256 id) {
		require(id <= contractIds, "OilContract does not exists");
		OilContract storage oilContract = oilContracts[id];
		require(oilContract.available == true, "Oil contract is available");
		_;
	}

	/**
	 * @dev function will creat oil contract
	 * @param contractName: the name of contract
	 * @param contractValue: the total value of contract
	 **/
	function createOilContract(string calldata contractName, uint256 contractValue) external onlyOwner {
		require(contractValue > 100000, "Contract Value must be greater than 100000");
		require(keccak256(abi.encodePacked(contractName)) != keccak256(abi.encodePacked("")), "Name required!");
		uint256 contractId = contractIds++;
		OilContract storage oilContract = oilContracts[contractId];
		oilContract.id = contractId;
		oilContract.totalValue = contractValue;
		oilContract.name = contractName;
		emit OilContractCreated(contractId, contractValue);
	}

	//	mapping(NFT_Id => mapping(uint256 => Payment)) payments;
	/**
	 * @dev makeContractAvail will make well contract avail to public to buyStakeInOilContract
	 */
	function makeContractAvail(uint256 contractId) external onlyOwner contractNotAvail(contractId) {
		OilContract memory oilContract = oilContracts[contractId];
		bool isContractAvail = _changeAvailability(oilContract);
		require(isContractAvail, "OilContract not made available");
		emit OilContractAvail(oilContract.id, oilContract.name, oilContract.totalValue, oilContract.available);
		oilContracts[contractId] = oilContract;
	}

	function _changeAvailability(OilContract memory oilContract) internal returns (bool) {
		oilContract.available = !oilContract.available;
		return oilContract.available;
	}

	/**
	 * @dev makeContractUnAvail will make well contract avail to public to buyStakeInOilContract
	 */
	function makeContractUnAvail(uint256 contractId) external onlyOwner contractAvail(contractId) {
		OilContract memory oilContract = oilContracts[contractId];
		bool isContractAvail = _changeAvailability(oilContract);
		require(isContractAvail == false, "OilContract not successfully made unavailable");
		emit OilContractUnAvail(oilContract.id, oilContract.name, oilContract.totalValue, oilContract.available);
		oilContracts[contractId] = oilContract;
	}

	/**
	 * @dev purchaseContractStake will update contracts and dispatch NFTS to funders
	 * @param contractId: id of contract
	 */
	//considerations should be made for if we dont meet demand
	function purchaseContractStake(uint256 contractId)
		external
		payable
		contractAvail(contractId)
		purchaseAmountAvail(contractId)
	{
		OilContract memory oilContract = oilContracts[contractId];
		require(oilContract.funded == false, "Contract fully funded");
		NFT_Id newTokenId = _updateContract(oilContract);
		_dispatchNFT(msg.sender, newTokenId);
		oilContracts[contractId] = oilContract;
	}

	/**
	 * @dev _updateContract increment contractNFTID, updates TVL, and adds newTokenId to mapping
	 * @return newTokenId : the token ID to be passed into dispatchNFT internal function
	 */
	function _updateContract(OilContract memory oilContract) internal returns (NFT_Id newTokenId) {
		//1 memmory copy
		//3-5 memmory write
		newTokenId = oilContract.nftIds++;
		//call outside contract to change msgValue to USDC or use oracle to get price, and call contract to convert after
		oilContract.nftIdToAmount[newTokenId] = msg.value;
		oilContract.totalValueLocked += msg.value;
		if (oilContract.totalValueLocked >= oilContract.totalValue) {
			bool isFunded = _changeFundingStatus(oilContract);
			bool isContractAvail = _changeAvailability(oilContract);
			emit ContractFunded(oilContract.id, oilContract.name, oilContract.totalValueLocked, isFunded);
			require(isFunded, "Funding status not successfully changed");
			require(isContractAvail == false, "Contract not made unavailable");
		}
		return newTokenId;
	}

	/** @dev function changes contract funding status */
	function _changeFundingStatus(OilContract memory oilContract) internal returns (bool) {
		oilContract.funded = !oilContract.funded;
		return (oilContract.funded);
	}

	/** @dev function dispatches token using _safeMint, an internal function extended from 721Upgradeable */
	function _dispatchNFT(address to, NFT_Id nftId) internal {
		//safeMint emits transfer event
		_safeMint(to, nftId); //NEED META DATA
		//tokenURI requirment will involve erc721uristorage rather than regular erc721
		//_setTokenUri(nftId, tokenURI)
	}

	/**
	 * @dev functions dispatches and records payments to each ownerOf NFT associated with contract
	 */
	function dispatchPayments(uint256 contractId) external payable onlyOwner contractNotAvail(contractId) {
		OilContract memory oilContract = oilContracts[contractId];
		require(oilContract.funded, "contract must me funded");
		uint256 paymentId = oilContract.payment++; //function increments paymentIDs
		oilContracts[contractId] = _dispatchPayments(oilContract, paymentId);
	}

	/**@dev consider adding a event for payment dispatched */

	/**
	* @dev function iterates through nftId's, dispatches payment to ownerOf nft, records Payment receipt

    consider putting in reentrancy guard as contract will continue to execute as itteration continues through nftId's
    * @param oilContract: oilContract with which to dispatch payments
    * @param paymentId: monthly payment ID
     */

	function _dispatchPayments(OilContract memory oilContract, uint256 paymentId) internal returns (OilContract memory) {
		for (uint256 nftId = 1; nftId < oilContract.nftIds; nftId++) {
			address nftOwner = ownerOf(nftId);
			uint256 paymentDue = _calculatePayment(nftId);
			(bool success, ) = payable(nftOwner).call{ value: paymentDue }();
			require(success, "PaymentError");
			oilContract.payments[nftId][paymentId] = Payment(nftId, paymentId, block.timestamp, paymentDue, success, nftOwner);
			emit PaymentDispatched(nftId, paymentId, paymentDue, nftOwner);
		}
		return oilContract;
	}

	/**
	 * @dev function calculates payment die to an ownerOf nft associated with contract
	 * @param oilContract: oilContract with which to dispatch payments
	 * @param nftId: identification of nft
	 */
	function _calculatePayment(NFT_Id nftId, OilContract memory oilContract) internal view returns (uint256) {
		//access nft  access deed, caliculate percentage of totalContractValue
		uint256 ownerStake = oilContract.nftIdToAmount[nftId];
		uint256 amountDue = _getAmountDue(ownerStake, oilContract.totalValue);
		//division needs to be ajusted to account for floating point math
		return amountDue;
	}

	/**
	 * @dev function calculates percentage of contract owned by ownerOf NFT, and determines amount due to ownerOf NFT
	 * @param ownerStake: theamount of value the owner has in he oil contract
	 * @param contractValue: the total value of the oil contract
	 */
	function _getAmountDue(uint256 ownerStake, uint256 contractValue) internal view returns (uint256 amountDue) {
		uint256 percentageOwed = _getBasis(ownerStake, contractValue);
		amountDue = (percentageOwed * contractValue) / 10000;
	}

	function _getBasis(uint256 _numerator, uint256 denominator) internal view returns (uint256 _basis) {
		// caution, check safe-to-multiply here
		uint256 numerator = _numerator * 10000;
		// with rounding of last digit
		_basis = numerator / denominator;
		// 101 numeratr,450 denominator, 3 percision : will equal 224, i.e. 22.4%.
		return _basis;
	}
}
