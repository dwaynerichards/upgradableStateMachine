pragma solidity ^0.8.0;
import "@openzeppelin/upgrades-core/contracts/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract PetroStake is OwnableUpgradeable, ERC721Upgradeable {
    type NFT_Id is uint256;
    type DeedAmount is uint256;
    type Time is uint256;
    type PaymentId is uint256;
    type ContractId is uint256;

    /**@dev change uint to type for contractId's, impoved readability for mappins */
    ContractId public contractIds;
    mapping(ContractId => OilContract) public oilContracts;

    struct OilContract {
        uint256 id;
        uint256 totalValue;
        string name;
        bool available;
        uint256 totalValueLocked;
        bool funded;
        NFT_Id nftIds;
        PaymentId paymentId;
        mapping(NFT_Id => DeedAmount) nftIdToAmount;
        mapping(NFT_Id => mapping(PaymentId => Payment)) payments;
    }
    struct Payment {
        NFT_Id nftId;
        PaymentId paymentId;
        Time time;
        uint256 paymentAmount;
        bool paymentRecieved;
        address owner;
        bool delayed;
    }

    /**
    * @dev contracts which have been extended must have thir intializer/constructor invoked
    __{contractName}_init acts as a constructor
    * @ param newOwner multsig wallet should be initialized as newOwner
     */
    function initialize(address, newOwner) public initializer {
        __Ownable_init();
        __ERC721_init("ArtPartitionTolerantStateDOA", "APTSD");
        transferOwnership(newOwner);
    }

    /**
     * @dev function will create Oil contract
     */
    event OilContractDeedPurchased(uint256 contractId, NFT_Id nftId, DeedAmount deedAmount);
    event OilContractCreated(uint256 contractId, uint256 contractValue);
    event OilContractAvail(uint256 contractId, string contractName, uint256 contractValue, bool available);
    event OilContractUnAvail(uint256 contractId, string contractName, uint256 contractValue, bool available);
    event ContractFunded(uint256 contractId, string contractName, uint256 totalValueLocked, bool isFunded);
    event LogError(uint256 contractId, string contractName, string reason);
    event PaymentError(uint256 contractId, NFT_Id nftId, Time time, uint256 paymentAmount);
    event PaymentDispatched(NFT_ID nftId, PaymentId paymentId, uint256 paymentAmount, address owner);

    modifier purchaseAmountAvail(uint256 contractId) {
        OilContract storage oilContract = oilContracts[contractId];
        uint256 availPurchaseAmount = oilContract.totalValue - oilContract.totalValueLocked;
        require(msg.value <= availPurchaseAmount, "Message value exceeds available amount");
        require(oilContract.funded == false, "Contract fully funded");
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
    function createOilContract(string contractName, uint256 contractValue) public onlyOwner {
        uint256 contractId = contractIds++;
        OilContract newContract = OilContract(contractId, contractValue, contractName);
        oilContracts[contractId] = newContract;
        emit OilContractCreated(contractId, contractValue);
        if (!_contractCreated(contractId)) emit LogError(contractId, contractName);
        //require(_contractCreated(contractId), "OilContract not created successfully");
    }

    /**
     * @dev _contractCreated will verify oil contract creation
     * @param contractId: the Id of contract
     * @return isCreated: boolean determiantion of contract creation
     **/
    function _contractCreated(uint256 _contractId) internal returns (bool isCreated) {
        //check all contract members for correct values
        OilContract storage oilContract = oilContracts[_contractId];
        (oilContract.name && oilContract.totalValue) ? isCreated = true : isCreated = false;
    }

    /**
     * @dev makeContractAvail will make well contract avail to public to buyStakeInOilContract
     */
    function makeContractAvail(uint256 contractId) public onlyOwner contractNotAvail(contractId) {
        bool isContractAvail = _makeContractAvail(contractId);
        require(isContractAvail, "OilContract not made available");
    }

    function _makeContractAvail(uint256 contractId) internal returns (bool) {
        OilContract storage oilContract = oilContracts[contractId];
        oilContract.available = true;
        emit OilContractAvail(contractId, oilContract.name, oilContract.totalValue, oilContract.available);
        return oilContract.available;
    }

    /**
     * @dev makeContractUnAvail will make well contract avail to public to buyStakeInOilContract
     */

    function makeContractUnAvail(uint256 contractId) public onlyOwner contractAvail(contractId) {
        bool isContractAvail = _makeContractUnAvail(contractId);
        require(isContractAvail == false, "OilContract not successfully made unavailable");
    }

    function _makeContractUnAvail(uint256 contractId) internal returns (bool) {
        OilContract storage oilContract = oilContracts[contractId];
        oilContract.available = false;
        emit OilContractUnAvail(contractId, oilContract.name, oilContract.totalValue, oilContract.available);
        return oilContract.available;
    }

    /**
     * @dev purchaseContractStake will update contracts and dispatch NFTS to funders
     * @param contractId: id of contract
     */
    //considerations should be made for if we dont meet demand
    function purchaseContractStake(uint256 contractId) public payable contractAvail(contractId) purchaseAmountAvail(contractId) {
        NFT_Id newTokenId = _updateContract(contractId);
        _dispatchNFT(msg.sender, newTokenId);
    }

    /**
     * @dev _updateContract increment contractNFTID, updates TVL, and adds newTokenId to mapping
     * @return newTokenId : the token ID to be passed into dispatchNFT internal function
     */
    function _updateContract(uint256 contractId) internal returns (NFT_Id newTokenId) {
        OilContract storage oilContract = oilContracts[contractId];
        newTokenId = oilContract.nftIds++;
        uint256 deedAmount = msg.value;
        oilContract.nftIdToAmount[newTokenId] = deedAmount;
        oilContract.totalValueLocked += deedAmount;
        if (oilContract.totalValueLocked >= oilContract.totalValue) {
            (string name, bool isFunded) = _changeFundingStatus(contractId);
            bool isContractAvail = _makeContractUnAvail(contractId);
            emit ContractFunded(contractId, name, oilContract.totalValueLocked, isFunded);
            require(isFunded, "Funding status not successfully changed");
            require(!isContractAvail, "Contract not made unavailable");
        }
    }

    //need to research strings and ABI encoded
    function _changeFundingStatus(contractId) internal returns (bool, string) {
        OilContract storage oilContract = oilContracts[contractId];
        oilContract.funded = !oilContract.funded;
        return (oilContract.funded, oilContract.name);
    }

    function _dispatchNFT(address to, NFT_Id nftId) internal {
        //safeMint emits transfer event
        _safeMint(to, nftId); //NEED META DATA
        //tokenURI requirment will involve erc721uristorage rather than regular erc721
        //_setTokenUri(nftId, tokenURI)
    }

    /**
     * @dev you will from 1- nftid's max number to dispatch payemntto each owner
     */
    function dispatchPayments(uint256 contractId) public payable owner contractNotAvail(contractId) contractFunded(contractId) {
        PaymentId paymentId = _getPaymentId(); //function increments paymentIDs
        _dispatchPayments(contractId, paymentId);
    }

    function _getPaymentId(uint256 contractId) internal returns (PaymentId paymentId) {
        OilContract storage oilContract = oilContracts[contractId];
        paymentId = oilContract.paymentID++;
    }

    function _dispatchPayments(uint256 contractId, PaymentId paymentId) internal {
        OilContract storage oilContract = oilContracts[contractId];
        for (uint256 nftId = 1; i < oilContract.nftIds; i++) {
            address owner = ownerOf(nftId);
            uint256 paymentDue = _calculatePayment(nftId);
            (bool success, ) = owner.call{value: paymentDue}();
            if (success) {
                Payment newPayment = Payment(nftId, paymentId, now, paymentDue, success, owner);
                payments[nftId][paymentId] = newPayment;
                emit Payment(nftId, paymentId, paymentDue, owner);
            } else emit PaymentError(contractId, nftID, now, paymentAmount);
        }
    }

    function _calculatePayment(NFT_Id nftId, uint256 contractId) internal views returns (uint256) {
        OilContract storage oilConract = oilContracts[contractId];
        //access nft  access deed, caliculate percentage of totalContractValue
        uint256 contractStake = oilContract.nftIdToAmount[nftId];
        uint256 contractTV = oilContract.totalValue;
        uint256 amountDue = contractStake / contractTv;
        //division needs to be ajusted to account for floating point math
        return amountDue;
    }
}
/**

    event PaymentError(uint256 contractId, NFT_Id nftId, Time time, uint256 paymentAmount);

    event PaymentError(uint256 contractId, NFT_Id nftId, Time time, uint256 paymentAmount);
    struct Payment {
        NFT_Id nftId;
        PaymentId paymentId;
        Time time;
        uint256 paymentAmount;
        bool paymentRecieved;
        address owner;
        bool delayed
    }
 */
