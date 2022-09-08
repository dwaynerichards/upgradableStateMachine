pragma solidity ^0.8.0;
// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/finance/PaymentSplitterUpgradeable.sol";
import "@openzeppelin/contracts/payment/PaymentSplitter.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

///@TODO Resolve remappings
///@TODO Do we need nft mints

contract PetroStake is Initializable, UUPSUpgradeable, OwnableUpgradeable, ERC721Upgradeable {
	using SafeERC20Upgradeable for IERC20;
	using SafeERC20Upgradeable for IERC20Upgradeable;
	uint24 public poolFee;

	ISwapRouter public swapRouter;
	address public USDC;
	address public WETH;

	/***
uint256 is 32 bytes
uint128 is 16 bytes
uint64 is 8 bytes
address (and address payable) is 20 bytes
bool is 1 byte
string is usually one byte per character
	 */

	/**
    * @dev contracts which have been extended must have thir intializer/constructor invoked
    __{contractName}_init acts as a constructor
    * @ param newOwner multsig wallet should be initialized as newOwner
     */
	function initialize(
		address newOwner,
		address _USDC,
		address _WETH,
		ISwapRouter _swapRouter,
		uint24 _poolFee
	) public initializer {
		__UUPSUpgradeable_init();
		__Ownable_init();
		__ERC721_init("ArtPartitionTolerantStateDOA", "APTSD");
		transferOwnership(newOwner);
		swapRouter = _swapRouter;
		USDC = _USDC;
		WETH = _WETH;
		poolFee = _poolFee;
	}

	/**
	 * @dev swapps ether sent to contract to USDC
	 */

	receive() external payable {
		uint256 buyerUSDC = _swapEthToStable();
	}

	/***
    @notice swapEthRoStable swaps a fixed amount of WETH (amountIn) for a maximum possible amount 
	of USDC using uniswap router
   @return amountOut The amount of USDC received.
	
	 */
	function _swapEthToStable() internal returns (uint256 usdcAmount) {
		uint256 minUSDC = _getAmountOutMin();
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

		usdcAmount = swapRouter.exactInputSingle(params);
	}

	function _getAmountOutMin() internal view returns (uint256) {
		//minAmount is product of offcahin rate
		//In production, use an oracle or other data source to choose a safer value for amountOutMinimum.
		uint256 oracleUSDPerEth = _getPrice(0);
		uint256 usdcAmount = oracleUSDPerEth * msg.value;
		return usdcAmount;
	}

	/**
	 * @dev returns usd equivelent of wei sent function
	 * @param _percision the amount of decimals to include in the returned chainlink price
	 **/
	function _getQuoterVal(uint256 _percision) internal view returns (uint256 usdcQuote) {
		uint256 price = _getPrice(_percision);
		usdcQuote = (msg.value * price) / 10**(18 + _percision); //all decimals removed before returning value
	}

	/**
	 * @dev returns price of eth per usd at the {_percision} amount of decimals
	 */
	function _getPrice(uint256 _percision) internal view returns (uint256 precisionPrice) {
		/**
		 * Network: Kovan
		 * Aggregator: ETH/USD
		 * Address: 0x9326BFA02ADD2366b30bacB125260Af641031331
		 */
		AggregatorV3Interface priceFeed = AggregatorV3Interface(0x9326BFA02ADD2366b30bacB125260Af641031331);
		require(_percision <= priceFeed.decimals(), "too many decimals in percision");
		(, int256 price, , , ) = priceFeed.latestRoundData(); //return price (8 decimalPoints)
		uint256 percisionDiff = priceFeed.decimals() - _percision;
		precisionPrice = uint256(price) / 10**(percisionDiff);
	}

	/** @dev function dispatches token using _safeMint, an internal function extended from 721Upgradeable */
	function _dispatchNFT(address to, uint256 nftId) internal {
		//safeMint emits transfer event
		_safeMint(to, nftId); //NEED META DATA
		//tokenURI requirment will involve erc721uristorage rather than regular erc721
		//_setTokenUri(nftId, tokenURI)
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
