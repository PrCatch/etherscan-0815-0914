// SPDX-License-Identifier: UNLICENSED
// ALL RIGHTS RESERVED
// Unicrypt by SDDTech reserves all rights on this code. You may NOT copy these contracts.

pragma solidity 0.8.3;

import "./ERC20.sol";
import "./Ownable.sol";

import "./TransferHelper.sol";
import "./LiquidityAmounts.sol";
import "./TickMath.sol";
import "./FixedPoint128.sol";

import "./IERC20.sol";
import "./IUniswapV3MintCallback.sol";
import "./IUniswapV3Pool.sol";
import "./IWETH9.sol";
import "./IUnicryptUniV3LPFactory.sol";
import "./IFeeHelper.sol";

/// @title Uniswap V3 LP Token Helper on Unicrypt
/// @notice The Uniswap V3 LP Token Helper holds the logic for the Unicrypt LP tokens

contract UnicryptUniV3LPTokenHelper is ERC20, Ownable, IUniswapV3MintCallback {

    uint256 constant public CONTRACT_VERSION = 1;

    address public token0;
    address public token1;
    address public pool;
    uint24 public fee;
    /// @dev stores tick data, used by the V3 pool to calculate the range of concentrated liquidity
    int24 public tickUpper;
    int24 public tickLower;

    /// @dev stores position data from the V3 pool, used to calculate rewards from fees
    /// updated after each call to the V3 pool
    struct Position {
        uint256 liquidity;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    Position public positionState;

    /// @dev pool cannot be initiallized twice
    bool public initialized = false;

    address public WETH9;

    /// @dev used to create a unique pool key similar to what V3 uses
    struct PoolKey {
        address token0;
        address token1;
        uint24 fee;
    }

    /// @dev data format needed to decode the mintcallback data from the pool
    struct MintCallbackData {
        PoolKey poolKey;
        address payer;
    }
    
    PoolKey private poolKey;

    event Mint(address sender, int24 tickLower, int24 tickUpper, uint128 liquidity, uint256 amount0, uint256 amount1);
    event Burn(address sender, int24 tickLower, int24 tickUpper, uint128 liquidity, uint256 _desiredLiquidity, uint256 amount0, uint256 amount1);
    event Collect(address pool, uint128 amount0Collect, uint128 amount1Collect);
    event Fee(address token, address sender, address recipient, uint256 fee);
    event SetTicks(int24 tickUpper, int24 tickLower);
    event InitializePool(uint160 sqrtPriceX96);

    address private lpTokenHelper;

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /// @notice Sets the ticks on the LP Token
    /// @dev Must call this from the factory before doing any liquidity operations
    /// @param _tickUpper The higher tick
    /// @param _tickLower The lower tick
    function setTicks(int24 _tickUpper, int24 _tickLower) external onlyOwner{
        tickUpper = _tickUpper;
        tickLower = _tickLower;
        emit SetTicks(_tickUpper, _tickLower);
    }

    /// @dev helper to handle different types of payments depending on transactions.
    function pay(address token, address payer, address recipient, uint256 value) internal {
        if (token == WETH9 && address(this).balance >= value) {
            // pay with WETH9
            IWETH9(WETH9).deposit{value: value}(); // wrap only what is needed to pay
            bool res = IWETH9(WETH9).transfer(recipient, value);
            require(res);
        } else if (payer == address(this)) {
            // pay with tokens already in the contract (for the exact input multihop case)
            TransferHelper.safeTransfer(token, recipient, value);
        } else {
            // pull payment
            TransferHelper.safeTransferFrom(token, payer, recipient, value);
        }
    }

    /// @notice Called to `msg.sender` after minting liquidity to a position from IUniswapV3Pool#mint.
    /// @dev In the implementation you must pay the pool tokens owed for the minted liquidity.
    /// The caller of this method must be checked to be a UniswapV3Pool deployed by the canonical UniswapV3Factory.
    /// @param amount0Owed The amount of token0 due to the pool for the minted liquidity
    /// @param amount1Owed The amount of token1 due to the pool for the minted liquidity
    /// @param data Any data passed through by the caller via the IUniswapV3PoolActions#mint call
    function uniswapV3MintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata data) external override {
        require(msg.sender == pool);
        MintCallbackData memory decoded = abi.decode(data, (MintCallbackData));

        if (amount0Owed > 0) {
            pay(decoded.poolKey.token0, decoded.payer, msg.sender, amount0Owed);
        } 

        if (amount1Owed > 0) {
            pay(decoded.poolKey.token1, decoded.payer, msg.sender, amount1Owed);
        }
    }

    /// @dev approves the pool for the amount desired to use by the user
    function _approvePool(uint256 amount0Desired, uint256 amount1Desired) internal {
        IERC20 token0Interface = IERC20(token0);
        token0Interface.approve(pool, amount0Desired);
        IERC20 token1Interface = IERC20(token1);
        token1Interface.approve(pool, amount1Desired);
    }

    /// @dev approves the pool for the amount desired to use by the user
    function _computePositionKey (address lpToken) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(lpToken, tickLower, tickUpper));
    }

    /// @dev handles the updating of position data from the V3 pool to our end when adding liquidity
    /// required to calculate an accurate amount of tokens to collect from fees
    function _addPosition(IUniswapV3Pool poolContract) internal {
        bytes32 positionKey = _computePositionKey(address(this));
        (, uint256 _feeGrowthInside0LastX128, uint256 _feeGrowthInside1LastX128, , ) = poolContract.positions(positionKey);

        positionState.tokensOwed0 += uint128(
            FullMath.mulDiv(
                _feeGrowthInside0LastX128 - positionState.feeGrowthInside0LastX128,
                positionState.liquidity,
                FixedPoint128.Q128
            )
        );

        positionState.tokensOwed1 += uint128(
            FullMath.mulDiv(
                _feeGrowthInside1LastX128 - positionState.feeGrowthInside1LastX128,
                positionState.liquidity,
                FixedPoint128.Q128
            )
        );

        positionState.feeGrowthInside0LastX128 = _feeGrowthInside0LastX128;
        positionState.feeGrowthInside1LastX128 = _feeGrowthInside1LastX128;
    }

    /// @dev handles the updating of position data from the V3 pool to our end when removing liquidity
    /// required to calculate an accurate amount of tokens to collect from fees
    function _removePosition(IUniswapV3Pool poolContract, uint256 amount0 , uint256 amount1) internal {
        bytes32 positionKey = _computePositionKey(address(this));
        (, uint256 _feeGrowthInside0LastX128, uint256 _feeGrowthInside1LastX128, , ) = poolContract.positions(positionKey);

        positionState.tokensOwed0 +=
            uint128(amount0) +
            uint128(
                FullMath.mulDiv(
                    _feeGrowthInside0LastX128 - positionState.feeGrowthInside0LastX128,
                    positionState.liquidity,
                    FixedPoint128.Q128
                )
            );

        positionState.tokensOwed1 +=
            uint128(amount1) +
            uint128(
                FullMath.mulDiv(
                    _feeGrowthInside1LastX128 - positionState.feeGrowthInside1LastX128,
                    positionState.liquidity,
                    FixedPoint128.Q128
                )
            );

        positionState.feeGrowthInside0LastX128 = _feeGrowthInside0LastX128;
        positionState.feeGrowthInside1LastX128 = _feeGrowthInside1LastX128;
    }

    /// @dev handles the updating of position data from the V3 pool to our end when collecting fees
    /// required to calculate an accurate amount of tokens to collect from fees
    function _getTokensOwed(IUniswapV3Pool poolContract) internal returns (uint128 tokensOwed0, uint128 tokensOwed1) {
        poolContract.burn(tickLower, tickUpper, 0);

        bytes32 positionKey = _computePositionKey(address(this));
        (, uint256 _feeGrowthInside0LastX128, uint256 _feeGrowthInside1LastX128, , ) = poolContract.positions(positionKey);

        tokensOwed0 += uint128(
            FullMath.mulDiv(
                _feeGrowthInside0LastX128 - positionState.feeGrowthInside0LastX128,
                positionState.liquidity,
                FixedPoint128.Q128
            )
        );

        tokensOwed1 += uint128(
            FullMath.mulDiv(
                _feeGrowthInside1LastX128 - positionState.feeGrowthInside1LastX128,
                positionState.liquidity,
                FixedPoint128.Q128
            )
        );

        positionState.feeGrowthInside0LastX128 = _feeGrowthInside0LastX128;
        positionState.feeGrowthInside1LastX128 = _feeGrowthInside1LastX128;
    }

    /// @dev uses V3 libraries to calculate the amount of liquidity as a single number from 
    /// the amount of each token desired for liquidity
    /// @return liquidity as a uint128
    function getLiquidityAmount(uint256 amount0Desired, uint256 amount1Desired) public view returns (uint128 liquidity) {
        IUniswapV3Pool poolContract = IUniswapV3Pool(pool);

        (uint160 sqrtPriceX96, , , , , , ) = poolContract.slot0();
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(tickUpper);

        liquidity = LiquidityAmounts.getLiquidityForAmounts(sqrtPriceX96, sqrtRatioAX96, sqrtRatioBX96, amount0Desired, amount1Desired);
    }

    modifier isLPToken() {
        require(IUnicryptUniV3LPFactory(owner()).getLPTokenAddress(token0, token1, fee) != address(0), "Nice try! Contact boka@unicrypt.network for potential integrations");
        _;
    }


    function handleLiquidity(uint256 __amount0Desired, uint256 __amount1Desired, uint256 __amount0AfterFees, uint256 __amount1AfterFees) external isLPToken returns (uint128)  {
        uint128 __liquidity;
        _approvePool(__amount0Desired, __amount1Desired);

        __liquidity = getLiquidityAmount(__amount0AfterFees, __amount1AfterFees);  
        return __liquidity;
    }

    function finalizeLiquidity(uint128 liquidity, uint256 amount0, uint256 amount1, uint256 amount0Fee, uint256 amount1Fee) external isLPToken {
        IUnicryptUniV3LPFactory factory = IUnicryptUniV3LPFactory(owner());
        IUniswapV3Pool poolContract = IUniswapV3Pool(pool);
        IFeeHelper feeHelper = IFeeHelper(factory.getFeeHelperAddress());

        _mint(msg.sender, liquidity);
        _addPosition(poolContract);
        
        positionState.liquidity += liquidity;

        pay(token0, msg.sender, feeHelper.getFeeAddress(), amount0Fee);
        pay(token1, msg.sender, feeHelper.getFeeAddress(), amount1Fee);

        emit Fee(token0, msg.sender, feeHelper.getFeeAddress(), amount0Fee);
        emit Fee(token1, msg.sender, feeHelper.getFeeAddress(), amount1Fee);
        emit Mint(msg.sender, tickLower, tickUpper, liquidity, amount0, amount1); 
    }

    function getActualLiquidity(uint256 _desiredLiquidity) external payable isLPToken returns (uint128 actualLiquidity) {
        require(totalSupply() > 0, "No liquidity to remove");
        require(balanceOf(msg.sender) - _desiredLiquidity >= 0, "Not enough liquidity");
        actualLiquidity = uint128(FullMath.mulDiv(_desiredLiquidity, positionState.liquidity, totalSupply()));
    }

    function removeLiquidity(uint256 _desiredLiquidity, uint128 actualLiquidity, uint256 amount0 , uint256 amount1) external payable nonReentrant isLPToken {
        IUniswapV3Pool poolContract = IUniswapV3Pool(pool);
        _burn(msg.sender, _desiredLiquidity);
        _removePosition(poolContract, amount0, amount1);
        positionState.liquidity -= actualLiquidity;
        poolContract.collect(msg.sender, tickLower, tickUpper, uint128(amount0), uint128(amount1));

        emit Burn(msg.sender, tickLower, tickUpper, actualLiquidity, _desiredLiquidity, amount0, amount1);
    }


    /// @notice Collects tokens owed from the liquidity pool and sends back to the LP Token
    /// @dev the LP Token receives the fees, then mints them back into the pool. 
    /// @param amount0Max The maximum amount of token0 to collect from the liquidity pool
    /// @param amount1Max The maximum amount of token1 to collect from the liquidity pool
    /// @return amount0 and amount1 - the amount of each token collected
    function collect(uint128 amount0Max, uint128 amount1Max) external nonReentrant isLPToken returns (uint256 amount0, uint256 amount1,  uint128 liquidity) {
        require(amount0Max > 0 || amount1Max > 0, "Need to specify amount(s) to collect");

        IUniswapV3Pool poolContract = IUniswapV3Pool(pool);
        (uint128 _tokensOwed0, uint128 _tokensOwed1) = _getTokensOwed(poolContract);
        (uint128 amount0Collect, uint128 amount1Collect) =
            (
                amount0Max > _tokensOwed0 ? _tokensOwed0 : amount0Max,
                amount1Max > _tokensOwed1 ? _tokensOwed1 : amount1Max
            );
        (amount0, amount1) = poolContract.collect(
            address(this),
            tickLower,
            tickUpper,
            amount0Collect,
            amount1Collect
        );

        (positionState.tokensOwed0, positionState.tokensOwed1) = (_tokensOwed0 - amount0Collect, _tokensOwed1 - amount1Collect);

        emit Collect(pool, amount0Collect, amount1Collect);

        uint256 token0Balance = balance0();
        uint256 token1Balance = balance1();

        if(token0Balance != 0 && token1Balance != 0) {
            liquidity = getLiquidityAmount(token0Balance, token1Balance);
        } else {
            liquidity = 0;
        }
    }

    function mintCollected(uint128 liquidity) isLPToken external {
        IUniswapV3Pool poolContract = IUniswapV3Pool(pool);
        _addPosition(poolContract);

        positionState.liquidity += liquidity;
    }

    /// @dev retrieves the current balance of the LP Token from token0 
    function balance0() private view returns (uint256) {
        (bool success, bytes memory data) =
            token0.staticcall(abi.encodeWithSelector(IERC20.balanceOf.selector, address(this)));
        require(success && data.length >= 32);
        return abi.decode(data, (uint256));
    }

    /// @dev retrieves the current balance of the LP Token from token1
    function balance1() private view returns (uint256) {
        (bool success, bytes memory data) =
            token1.staticcall(abi.encodeWithSelector(IERC20.balanceOf.selector, address(this)));
        require(success && data.length >= 32);
        return abi.decode(data, (uint256));
    }

    /// @notice Sets the initial price for the pool. Can only be called once.
    /// @param _sqrtPriceX96 the initial sqrt price of the pool as a Q64.96
    function initializePool(uint160 _sqrtPriceX96) external isLPToken{
        require(!initialized, "Already Initialized");
        IUniswapV3Pool poolContract = IUniswapV3Pool(pool);
        (uint160 sqrtPriceX96, , , , , , ) = poolContract.slot0();
        if(sqrtPriceX96 != 0) {
            initialized = true;
            return;
        }
        IUniswapV3Pool(pool).initialize(_sqrtPriceX96);
        initialized = true;
        emit InitializePool(sqrtPriceX96);
    }
} 