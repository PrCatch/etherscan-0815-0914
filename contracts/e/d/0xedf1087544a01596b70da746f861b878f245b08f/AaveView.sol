// SPDX-License-Identifier: MIT

pragma solidity =0.8.10;




contract DSMath {
    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x + y;
    }

    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x - y;
    }

    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x * y;
    }

    function div(uint256 x, uint256 y) internal pure returns (uint256 z) {
        return x / y;
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        return x <= y ? x : y;
    }

    function max(uint256 x, uint256 y) internal pure returns (uint256 z) {
        return x >= y ? x : y;
    }

    function imin(int256 x, int256 y) internal pure returns (int256 z) {
        return x <= y ? x : y;
    }

    function imax(int256 x, int256 y) internal pure returns (int256 z) {
        return x >= y ? x : y;
    }

    uint256 constant WAD = 10**18;
    uint256 constant RAY = 10**27;

    function wmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = add(mul(x, y), WAD / 2) / WAD;
    }

    function rmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = add(mul(x, y), RAY / 2) / RAY;
    }

    function wdiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = add(mul(x, WAD), y / 2) / y;
    }

    function rdiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = add(mul(x, RAY), y / 2) / y;
    }

    // This famous algorithm is called "exponentiation by squaring"
    // and calculates x^n with x as fixed-point and n as regular unsigned.
    //
    // It's O(log n), instead of O(n) for naive repeated multiplication.
    //
    // These facts are why it works:
    //
    //  If n is even, then x^n = (x^2)^(n/2).
    //  If n is odd,  then x^n = x * x^(n-1),
    //   and applying the equation for even x gives
    //    x^n = x * (x^2)^((n-1) / 2).
    //
    //  Also, EVM division is flooring and
    //    floor[(n-1) / 2] = floor[n / 2].
    //
    function rpow(uint256 x, uint256 n) internal pure returns (uint256 z) {
        z = n % 2 != 0 ? x : RAY;

        for (n /= 2; n != 0; n /= 2) {
            x = rmul(x, x);

            if (n % 2 != 0) {
                z = rmul(z, x);
            }
        }
    }
}





interface ILendingPoolAddressesProviderV2 {
  event LendingPoolUpdated(address indexed newAddress);
  event ConfigurationAdminUpdated(address indexed newAddress);
  event EmergencyAdminUpdated(address indexed newAddress);
  event LendingPoolConfiguratorUpdated(address indexed newAddress);
  event LendingPoolCollateralManagerUpdated(address indexed newAddress);
  event PriceOracleUpdated(address indexed newAddress);
  event LendingRateOracleUpdated(address indexed newAddress);
  event ProxyCreated(bytes32 id, address indexed newAddress);
  event AddressSet(bytes32 id, address indexed newAddress, bool hasProxy);

  function setAddress(bytes32 id, address newAddress) external;

  function setAddressAsProxy(bytes32 id, address impl) external;

  function getAddress(bytes32 id) external view returns (address);

  function getLendingPool() external view returns (address);

  function setLendingPoolImpl(address pool) external;

  function getLendingPoolConfigurator() external view returns (address);

  function setLendingPoolConfiguratorImpl(address configurator) external;

  function getLendingPoolCollateralManager() external view returns (address);

  function setLendingPoolCollateralManager(address manager) external;

  function getPoolAdmin() external view returns (address);

  function setPoolAdmin(address admin) external;

  function getEmergencyAdmin() external view returns (address);

  function setEmergencyAdmin(address admin) external;

  function getPriceOracle() external view returns (address);

  function setPriceOracle(address priceOracle) external;

  function getLendingRateOracle() external view returns (address);

  function setLendingRateOracle(address lendingRateOracle) external;
}




library DataTypes {
  // refer to the whitepaper, section 1.1 basic concepts for a formal description of these properties.
  struct ReserveData {
    //stores the reserve configuration
    ReserveConfigurationMap configuration;
    //the liquidity index. Expressed in ray
    uint128 liquidityIndex;
    //variable borrow index. Expressed in ray
    uint128 variableBorrowIndex;
    //the current supply rate. Expressed in ray
    uint128 currentLiquidityRate;
    //the current variable borrow rate. Expressed in ray
    uint128 currentVariableBorrowRate;
    //the current stable borrow rate. Expressed in ray
    uint128 currentStableBorrowRate;
    uint40 lastUpdateTimestamp;
    //tokens addresses
    address aTokenAddress;
    address stableDebtTokenAddress;
    address variableDebtTokenAddress;
    //address of the interest rate strategy
    address interestRateStrategyAddress;
    //the id of the reserve. Represents the position in the list of the active reserves
    uint8 id;
  }

  struct ReserveConfigurationMap {
    //bit 0-15: LTV
    //bit 16-31: Liq. threshold
    //bit 32-47: Liq. bonus
    //bit 48-55: Decimals
    //bit 56: Reserve is active
    //bit 57: reserve is frozen
    //bit 58: borrowing is enabled
    //bit 59: stable rate borrowing enabled
    //bit 60-63: reserved
    //bit 64-79: reserve factor
    uint256 data;
  }

  struct UserConfigurationMap {
    uint256 data;
  }

  enum InterestRateMode {NONE, STABLE, VARIABLE}
}

interface ILendingPoolV2 {
  /**
   * @dev Emitted on deposit()
   * @param reserve The address of the underlying asset of the reserve
   * @param user The address initiating the deposit
   * @param onBehalfOf The beneficiary of the deposit, receiving the aTokens
   * @param amount The amount deposited
   * @param referral The referral code used
   **/
  event Deposit(
    address indexed reserve,
    address user,
    address indexed onBehalfOf,
    uint256 amount,
    uint16 indexed referral
  );

  /**
   * @dev Emitted on withdraw()
   * @param reserve The address of the underlyng asset being withdrawn
   * @param user The address initiating the withdrawal, owner of aTokens
   * @param to Address that will receive the underlying
   * @param amount The amount to be withdrawn
   **/
  event Withdraw(address indexed reserve, address indexed user, address indexed to, uint256 amount);

  /**
   * @dev Emitted on borrow() and flashLoan() when debt needs to be opened
   * @param reserve The address of the underlying asset being borrowed
   * @param user The address of the user initiating the borrow(), receiving the funds on borrow() or just
   * initiator of the transaction on flashLoan()
   * @param onBehalfOf The address that will be getting the debt
   * @param amount The amount borrowed out
   * @param borrowRateMode The rate mode: 1 for Stable, 2 for Variable
   * @param borrowRate The numeric rate at which the user has borrowed
   * @param referral The referral code used
   **/
  event Borrow(
    address indexed reserve,
    address user,
    address indexed onBehalfOf,
    uint256 amount,
    uint256 borrowRateMode,
    uint256 borrowRate,
    uint16 indexed referral
  );

  /**
   * @dev Emitted on repay()
   * @param reserve The address of the underlying asset of the reserve
   * @param user The beneficiary of the repayment, getting his debt reduced
   * @param repayer The address of the user initiating the repay(), providing the funds
   * @param amount The amount repaid
   **/
  event Repay(
    address indexed reserve,
    address indexed user,
    address indexed repayer,
    uint256 amount
  );

  /**
   * @dev Emitted on swapBorrowRateMode()
   * @param reserve The address of the underlying asset of the reserve
   * @param user The address of the user swapping his rate mode
   * @param rateMode The rate mode that the user wants to swap to
   **/
  event Swap(address indexed reserve, address indexed user, uint256 rateMode);

  /**
   * @dev Emitted on setUserUseReserveAsCollateral()
   * @param reserve The address of the underlying asset of the reserve
   * @param user The address of the user enabling the usage as collateral
   **/
  event ReserveUsedAsCollateralEnabled(address indexed reserve, address indexed user);

  /**
   * @dev Emitted on setUserUseReserveAsCollateral()
   * @param reserve The address of the underlying asset of the reserve
   * @param user The address of the user enabling the usage as collateral
   **/
  event ReserveUsedAsCollateralDisabled(address indexed reserve, address indexed user);

  /**
   * @dev Emitted on rebalanceStableBorrowRate()
   * @param reserve The address of the underlying asset of the reserve
   * @param user The address of the user for which the rebalance has been executed
   **/
  event RebalanceStableBorrowRate(address indexed reserve, address indexed user);

  /**
   * @dev Emitted on flashLoan()
   * @param target The address of the flash loan receiver contract
   * @param initiator The address initiating the flash loan
   * @param asset The address of the asset being flash borrowed
   * @param amount The amount flash borrowed
   * @param premium The fee flash borrowed
   * @param referralCode The referral code used
   **/
  event FlashLoan(
    address indexed target,
    address indexed initiator,
    address indexed asset,
    uint256 amount,
    uint256 premium,
    uint16 referralCode
  );

  /**
   * @dev Emitted when the pause is triggered.
   */
  event Paused();

  /**
   * @dev Emitted when the pause is lifted.
   */
  event Unpaused();

  /**
   * @dev Emitted when a borrower is liquidated. This event is emitted by the LendingPool via
   * LendingPoolCollateral manager using a DELEGATECALL
   * This allows to have the events in the generated ABI for LendingPool.
   * @param collateralAsset The address of the underlying asset used as collateral, to receive as result of the liquidation
   * @param debtAsset The address of the underlying borrowed asset to be repaid with the liquidation
   * @param user The address of the borrower getting liquidated
   * @param debtToCover The debt amount of borrowed `asset` the liquidator wants to cover
   * @param liquidatedCollateralAmount The amount of collateral received by the liiquidator
   * @param liquidator The address of the liquidator
   * @param receiveAToken `true` if the liquidators wants to receive the collateral aTokens, `false` if he wants
   * to receive the underlying collateral asset directly
   **/
  event LiquidationCall(
    address indexed collateralAsset,
    address indexed debtAsset,
    address indexed user,
    uint256 debtToCover,
    uint256 liquidatedCollateralAmount,
    address liquidator,
    bool receiveAToken
  );

  /**
   * @dev Emitted when the state of a reserve is updated. NOTE: This event is actually declared
   * in the ReserveLogic library and emitted in the updateInterestRates() function. Since the function is internal,
   * the event will actually be fired by the LendingPool contract. The event is therefore replicated here so it
   * gets added to the LendingPool ABI
   * @param reserve The address of the underlying asset of the reserve
   * @param liquidityRate The new liquidity rate
   * @param stableBorrowRate The new stable borrow rate
   * @param variableBorrowRate The new variable borrow rate
   * @param liquidityIndex The new liquidity index
   * @param variableBorrowIndex The new variable borrow index
   **/
  event ReserveDataUpdated(
    address indexed reserve,
    uint256 liquidityRate,
    uint256 stableBorrowRate,
    uint256 variableBorrowRate,
    uint256 liquidityIndex,
    uint256 variableBorrowIndex
  );

  /**
   * @dev Deposits an `amount` of underlying asset into the reserve, receiving in return overlying aTokens.
   * - E.g. User deposits 100 USDC and gets in return 100 aUSDC
   * @param asset The address of the underlying asset to deposit
   * @param amount The amount to be deposited
   * @param onBehalfOf The address that will receive the aTokens, same as msg.sender if the user
   *   wants to receive them on his own wallet, or a different address if the beneficiary of aTokens
   *   is a different wallet
   * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
   *   0 if the action is executed directly by the user, without any middle-man
   **/
  function deposit(
    address asset,
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode
  ) external;

  /**
   * @dev Withdraws an `amount` of underlying asset from the reserve, burning the equivalent aTokens owned
   * E.g. User has 100 aUSDC, calls withdraw() and receives 100 USDC, burning the 100 aUSDC
   * @param asset The address of the underlying asset to withdraw
   * @param amount The underlying amount to be withdrawn
   *   - Send the value type(uint256).max in order to withdraw the whole aToken balance
   * @param to Address that will receive the underlying, same as msg.sender if the user
   *   wants to receive it on his own wallet, or a different address if the beneficiary is a
   *   different wallet
   **/
  function withdraw(
    address asset,
    uint256 amount,
    address to
  ) external;

  /**
   * @dev Allows users to borrow a specific `amount` of the reserve underlying asset, provided that the borrower
   * already deposited enough collateral, or he was given enough allowance by a credit delegator on the
   * corresponding debt token (StableDebtToken or VariableDebtToken)
   * - E.g. User borrows 100 USDC passing as `onBehalfOf` his own address, receiving the 100 USDC in his wallet
   *   and 100 stable/variable debt tokens, depending on the `interestRateMode`
   * @param asset The address of the underlying asset to borrow
   * @param amount The amount to be borrowed
   * @param interestRateMode The interest rate mode at which the user wants to borrow: 1 for Stable, 2 for Variable
   * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
   *   0 if the action is executed directly by the user, without any middle-man
   * @param onBehalfOf Address of the user who will receive the debt. Should be the address of the borrower itself
   * calling the function if he wants to borrow against his own collateral, or the address of the credit delegator
   * if he has been given credit delegation allowance
   **/
  function borrow(
    address asset,
    uint256 amount,
    uint256 interestRateMode,
    uint16 referralCode,
    address onBehalfOf
  ) external;

  /**
   * @notice Repays a borrowed `amount` on a specific reserve, burning the equivalent debt tokens owned
   * - E.g. User repays 100 USDC, burning 100 variable/stable debt tokens of the `onBehalfOf` address
   * @param asset The address of the borrowed underlying asset previously borrowed
   * @param amount The amount to repay
   * - Send the value type(uint256).max in order to repay the whole debt for `asset` on the specific `debtMode`
   * @param rateMode The interest rate mode at of the debt the user wants to repay: 1 for Stable, 2 for Variable
   * @param onBehalfOf Address of the user who will get his debt reduced/removed. Should be the address of the
   * user calling the function if he wants to reduce/remove his own debt, or the address of any other
   * other borrower whose debt should be removed
   **/
  function repay(
    address asset,
    uint256 amount,
    uint256 rateMode,
    address onBehalfOf
  ) external;

  /**
   * @dev Allows a borrower to swap his debt between stable and variable mode, or viceversa
   * @param asset The address of the underlying asset borrowed
   * @param rateMode The rate mode that the user wants to swap to
   **/
  function swapBorrowRateMode(address asset, uint256 rateMode) external;

  /**
   * @dev Rebalances the stable interest rate of a user to the current stable rate defined on the reserve.
   * - Users can be rebalanced if the following conditions are satisfied:
   *     1. Usage ratio is above 95%
   *     2. the current deposit APY is below REBALANCE_UP_THRESHOLD * maxVariableBorrowRate, which means that too much has been
   *        borrowed at a stable rate and depositors are not earning enough
   * @param asset The address of the underlying asset borrowed
   * @param user The address of the user to be rebalanced
   **/
  function rebalanceStableBorrowRate(address asset, address user) external;

  /**
   * @dev Allows depositors to enable/disable a specific deposited asset as collateral
   * @param asset The address of the underlying asset deposited
   * @param useAsCollateral `true` if the user wants to use the deposit as collateral, `false` otherwise
   **/
  function setUserUseReserveAsCollateral(address asset, bool useAsCollateral) external;

  /**
   * @dev Function to liquidate a non-healthy position collateral-wise, with Health Factor below 1
   * - The caller (liquidator) covers `debtToCover` amount of debt of the user getting liquidated, and receives
   *   a proportionally amount of the `collateralAsset` plus a bonus to cover market risk
   * @param collateralAsset The address of the underlying asset used as collateral, to receive as result of the liquidation
   * @param debtAsset The address of the underlying borrowed asset to be repaid with the liquidation
   * @param user The address of the borrower getting liquidated
   * @param debtToCover The debt amount of borrowed `asset` the liquidator wants to cover
   * @param receiveAToken `true` if the liquidators wants to receive the collateral aTokens, `false` if he wants
   * to receive the underlying collateral asset directly
   **/
  function liquidationCall(
    address collateralAsset,
    address debtAsset,
    address user,
    uint256 debtToCover,
    bool receiveAToken
  ) external;

  /**
   * @dev Allows smartcontracts to access the liquidity of the pool within one transaction,
   * as long as the amount taken plus a fee is returned.
   * IMPORTANT There are security concerns for developers of flashloan receiver contracts that must be kept into consideration.
   * For further details please visit https://developers.aave.com
   * @param receiverAddress The address of the contract receiving the funds, implementing the IFlashLoanReceiver interface
   * @param assets The addresses of the assets being flash-borrowed
   * @param amounts The amounts amounts being flash-borrowed
   * @param modes Types of the debt to open if the flash loan is not returned:
   *   0 -> Don't open any debt, just revert if funds can't be transferred from the receiver
   *   1 -> Open debt at stable rate for the value of the amount flash-borrowed to the `onBehalfOf` address
   *   2 -> Open debt at variable rate for the value of the amount flash-borrowed to the `onBehalfOf` address
   * @param onBehalfOf The address  that will receive the debt in the case of using on `modes` 1 or 2
   * @param params Variadic packed params to pass to the receiver as extra information
   * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
   *   0 if the action is executed directly by the user, without any middle-man
   **/
  function flashLoan(
    address receiverAddress,
    address[] calldata assets,
    uint256[] calldata amounts,
    uint256[] calldata modes,
    address onBehalfOf,
    bytes calldata params,
    uint16 referralCode
  ) external;

  /**
   * @dev Returns the user account data across all the reserves
   * @param user The address of the user
   * @return totalCollateralETH the total collateral in ETH of the user
   * @return totalDebtETH the total debt in ETH of the user
   * @return availableBorrowsETH the borrowing power left of the user
   * @return currentLiquidationThreshold the liquidation threshold of the user
   * @return ltv the loan to value of the user
   * @return healthFactor the current health factor of the user
   **/
  function getUserAccountData(address user)
    external
    view
    returns (
      uint256 totalCollateralETH,
      uint256 totalDebtETH,
      uint256 availableBorrowsETH,
      uint256 currentLiquidationThreshold,
      uint256 ltv,
      uint256 healthFactor
    );

  function initReserve(
    address reserve,
    address aTokenAddress,
    address stableDebtAddress,
    address variableDebtAddress,
    address interestRateStrategyAddress
  ) external;

  function setReserveInterestRateStrategyAddress(address reserve, address rateStrategyAddress)
    external;

  function setConfiguration(address reserve, uint256 configuration) external;

  /**
   * @dev Returns the configuration of the reserve
   * @param asset The address of the underlying asset of the reserve
   * @return The configuration of the reserve
   **/
  function getConfiguration(address asset) external view returns (DataTypes.ReserveConfigurationMap memory);

  /**
   * @dev Returns the configuration of the user across all the reserves
   * @param user The user address
   * @return The configuration of the user
   **/
  function getUserConfiguration(address user) external view returns (DataTypes.UserConfigurationMap memory);

  /**
   * @dev Returns the normalized income normalized income of the reserve
   * @param asset The address of the underlying asset of the reserve
   * @return The reserve's normalized income
   */
  function getReserveNormalizedIncome(address asset) external view returns (uint256);

  /**
   * @dev Returns the normalized variable debt per unit of asset
   * @param asset The address of the underlying asset of the reserve
   * @return The reserve normalized variable debt
   */
  function getReserveNormalizedVariableDebt(address asset) external view returns (uint256);

  /**
   * @dev Returns the state and configuration of the reserve
   * @param asset The address of the underlying asset of the reserve
   * @return The state of the reserve
   **/
  function getReserveData(address asset) external view returns (DataTypes.ReserveData memory);

  function finalizeTransfer(
    address asset,
    address from,
    address to,
    uint256 amount,
    uint256 balanceFromAfter,
    uint256 balanceToBefore
  ) external;

  function getReservesList() external view returns (address[] memory);

  function getAddressesProvider() external view returns (ILendingPoolAddressesProviderV2);

  function setPause(bool val) external;

  function paused() external view returns (bool);
}





abstract contract IAaveProtocolDataProviderV2 {

  struct TokenData {
    string symbol;
    address tokenAddress;
  }

  function getAllReservesTokens() external virtual view returns (TokenData[] memory);

  function getAllATokens() external virtual view returns (TokenData[] memory);

  function getReserveConfigurationData(address asset)
    external virtual
    view
    returns (
      uint256 decimals,
      uint256 ltv,
      uint256 liquidationThreshold,
      uint256 liquidationBonus,
      uint256 reserveFactor,
      bool usageAsCollateralEnabled,
      bool borrowingEnabled,
      bool stableBorrowRateEnabled,
      bool isActive,
      bool isFrozen
    );

  function getReserveData(address asset)
    external virtual
    view
    returns (
      uint256 availableLiquidity,
      uint256 totalStableDebt,
      uint256 totalVariableDebt,
      uint256 liquidityRate,
      uint256 variableBorrowRate,
      uint256 stableBorrowRate,
      uint256 averageStableBorrowRate,
      uint256 liquidityIndex,
      uint256 variableBorrowIndex,
      uint40 lastUpdateTimestamp
    );

  function getUserReserveData(address asset, address user)
    external virtual
    view
    returns (
      uint256 currentATokenBalance,
      uint256 currentStableDebt,
      uint256 currentVariableDebt,
      uint256 principalStableDebt,
      uint256 scaledVariableDebt,
      uint256 stableBorrowRate,
      uint256 liquidityRate,
      uint40 stableRateLastUpdated,
      bool usageAsCollateralEnabled
    );

  function getReserveTokensAddresses(address asset)
    external virtual
    view
    returns (
      address aTokenAddress,
      address stableDebtTokenAddress,
      address variableDebtTokenAddress
    );
}




interface IAaveIncentivesController {
  
  event RewardsAccrued(address indexed user, uint256 amount);
  
  event RewardsClaimed(
    address indexed user,
    address indexed to,
    address indexed claimer,
    uint256 amount
  );

  event ClaimerSet(address indexed user, address indexed claimer);

  /**
   * @dev Whitelists an address to claim the rewards on behalf of another address
   * @param user The address of the user
   * @param claimer The address of the claimer
   */
  function setClaimer(address user, address claimer) external;

  /**
   * @dev Returns the whitelisted claimer for a certain address (0x0 if not set)
   * @param user The address of the user
   * @return The claimer address
   */
  function getClaimer(address user) external view returns (address);

  /**
   * @dev Configure assets for a certain rewards emission
   * @param assets The assets to incentivize
   * @param emissionsPerSecond The emission for each asset
   */
  function configureAssets(address[] calldata assets, uint256[] calldata emissionsPerSecond)
    external;


  /**
   * @dev Called by the corresponding asset on any update that affects the rewards distribution
   * @param asset The address of the user
   * @param userBalance The balance of the user of the asset in the lending pool
   * @param totalSupply The total supply of the asset in the lending pool
   **/
  function handleAction(
    address asset,
    uint256 userBalance,
    uint256 totalSupply
  ) external;

  /**
   * @dev Returns the total of rewards of an user, already accrued + not yet accrued
   * @param user The address of the user
   * @return The rewards
   **/
  function getRewardsBalance(address[] calldata assets, address user)
    external
    view
    returns (uint256);

  /**
   * @dev Claims reward for an user, on all the assets of the lending pool, accumulating the pending rewards
   * @param amount Amount of rewards to claim
   * @param to Address that will be receiving the rewards
   * @return Rewards claimed
   **/
  function claimRewards(
    address[] calldata assets,
    uint256 amount,
    address to
  ) external returns (uint256);

  /**
   * @dev Claims reward for an user on behalf, on all the assets of the lending pool, accumulating the pending rewards. The caller must
   * be whitelisted via "allowClaimOnBehalf" function by the RewardsAdmin role manager
   * @param amount Amount of rewards to claim
   * @param user Address to check and claim rewards
   * @param to Address that will be receiving the rewards
   * @return Rewards claimed
   **/
  function claimRewardsOnBehalf(
    address[] calldata assets,
    uint256 amount,
    address user,
    address to
  ) external returns (uint256);

  /**
   * @dev returns the unclaimed rewards of the user
   * @param user the address of the user
   * @return the unclaimed user rewards
   */
  function getUserUnclaimedRewards(address user) external view returns (uint256);

  /**
  * @dev for backward compatibility with previous implementation of the Incentives controller
  */
  function REWARD_TOKEN() external view returns (address);
}





contract MainnetAaveAddresses {
    address internal constant STAKED_CONTROLLER_ADDR = 0xd784927Ff2f95ba542BfC824c8a8a98F3495f6b5;
    address internal constant STAKED_TOKEN_ADDR = 0x4da27a545c0c5B758a6BA100e3a049001de870f5;
}




interface IStakedToken {
    function getTotalRewardsBalance(address) external view returns (uint256);
}








contract AaveHelper is MainnetAaveAddresses {
    uint16 public constant AAVE_REFERRAL_CODE = 64;

    uint256 public constant STABLE_ID = 1;
    uint256 public constant VARIABLE_ID = 2;

    bytes32 public constant DATA_PROVIDER_ID =
        0x0100000000000000000000000000000000000000000000000000000000000000;
    
    IAaveIncentivesController constant public AaveIncentivesController = IAaveIncentivesController(STAKED_CONTROLLER_ADDR);

    IStakedToken constant public StakedToken = IStakedToken(STAKED_TOKEN_ADDR);

    /// @notice Enable/Disable a token as collateral for the specified Aave market
    function enableAsCollateral(
        address _market,
        address _tokenAddr,
        bool _useAsCollateral
    ) public {
        address lendingPool = ILendingPoolAddressesProviderV2(_market).getLendingPool();

        ILendingPoolV2(lendingPool).setUserUseReserveAsCollateral(_tokenAddr, _useAsCollateral);
    }

    /// @notice Switches the borrowing rate mode (stable/variable) for the user
    function switchRateMode(
        address _market,
        address _tokenAddr,
        uint256 _rateMode
    ) public {
        address lendingPool = ILendingPoolAddressesProviderV2(_market).getLendingPool();

        ILendingPoolV2(lendingPool).swapBorrowRateMode(_tokenAddr, _rateMode);
    }

    /// @notice Fetch the data provider for the specified market
    function getDataProvider(address _market) internal view returns (IAaveProtocolDataProviderV2) {
        return
            IAaveProtocolDataProviderV2(
                ILendingPoolAddressesProviderV2(_market).getAddress(DATA_PROVIDER_ID)
            );
    }

    /// @notice Returns the lending pool contract of the specified market
    function getLendingPool(address _market) internal view returns (ILendingPoolV2) {
        return ILendingPoolV2(ILendingPoolAddressesProviderV2(_market).getLendingPool());
    }
}





abstract contract IPriceOracleGetterAave {
    function getAssetPrice(address _asset) external virtual view returns (uint256);
    function getAssetsPrices(address[] calldata _assets) external virtual view returns(uint256[] memory);
    function getSourceOfAsset(address _asset) external virtual view returns(address);
    function getFallbackOracle() external virtual view returns(address);
}





interface IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint256 digits);
    function totalSupply() external view returns (uint256 supply);

    function balanceOf(address _owner) external view returns (uint256 balance);

    function transfer(address _to, uint256 _value) external returns (bool success);

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool success);

    function approve(address _spender, uint256 _value) external returns (bool success);

    function allowance(address _owner, address _spender) external view returns (uint256 remaining);

    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}





abstract contract IWETH {
    function allowance(address, address) public virtual view returns (uint256);

    function balanceOf(address) public virtual view returns (uint256);

    function approve(address, uint256) public virtual;

    function transfer(address, uint256) public virtual returns (bool);

    function transferFrom(
        address,
        address,
        uint256
    ) public virtual returns (bool);

    function deposit() public payable virtual;

    function withdraw(uint256) public virtual;
}





library Address {
    //insufficient balance
    error InsufficientBalance(uint256 available, uint256 required);
    //unable to send value, recipient may have reverted
    error SendingValueFail();
    //insufficient balance for call
    error InsufficientBalanceForCall(uint256 available, uint256 required);
    //call to non-contract
    error NonContractCall();
    
    function isContract(address account) internal view returns (bool) {
        // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
        // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
        // for accounts without code, i.e. `keccak256('')`
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            codehash := extcodehash(account)
        }
        return (codehash != accountHash && codehash != 0x0);
    }

    function sendValue(address payable recipient, uint256 amount) internal {
        uint256 balance = address(this).balance;
        if (balance < amount){
            revert InsufficientBalance(balance, amount);
        }

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{value: amount}("");
        if (!(success)){
            revert SendingValueFail();
        }
    }

    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return _functionCallWithValue(target, data, 0, errorMessage);
    }

    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return
            functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        uint256 balance = address(this).balance;
        if (balance < value){
            revert InsufficientBalanceForCall(balance, value);
        }
        return _functionCallWithValue(target, data, value, errorMessage);
    }

    function _functionCallWithValue(
        address target,
        bytes memory data,
        uint256 weiValue,
        string memory errorMessage
    ) private returns (bytes memory) {
        if (!(isContract(target))){
            revert NonContractCall();
        }

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{value: weiValue}(data);
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}




library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}







library SafeERC20 {
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.transferFrom.selector, from, to, value)
        );
    }

    /// @dev Edited so it always first approves 0 and then the value, because of non standard tokens
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, 0));
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.approve.selector, spender, newAllowance)
        );
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(
            value,
            "SafeERC20: decreased allowance below zero"
        );
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.approve.selector, spender, newAllowance)
        );
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        bytes memory returndata = address(token).functionCall(
            data,
            "SafeERC20: low-level call failed"
        );
        if (returndata.length > 0) {
            // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}






library TokenUtils {
    using SafeERC20 for IERC20;

    address public constant WETH_ADDR = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant ETH_ADDR = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function approveToken(
        address _tokenAddr,
        address _to,
        uint256 _amount
    ) internal {
        if (_tokenAddr == ETH_ADDR) return;

        if (IERC20(_tokenAddr).allowance(address(this), _to) < _amount) {
            IERC20(_tokenAddr).safeApprove(_to, _amount);
        }
    }

    function pullTokensIfNeeded(
        address _token,
        address _from,
        uint256 _amount
    ) internal returns (uint256) {
        // handle max uint amount
        if (_amount == type(uint256).max) {
            _amount = getBalance(_token, _from);
        }

        if (_from != address(0) && _from != address(this) && _token != ETH_ADDR && _amount != 0) {
            IERC20(_token).safeTransferFrom(_from, address(this), _amount);
        }

        return _amount;
    }

    function withdrawTokens(
        address _token,
        address _to,
        uint256 _amount
    ) internal returns (uint256) {
        if (_amount == type(uint256).max) {
            _amount = getBalance(_token, address(this));
        }

        if (_to != address(0) && _to != address(this) && _amount != 0) {
            if (_token != ETH_ADDR) {
                IERC20(_token).safeTransfer(_to, _amount);
            } else {
                (bool success, ) = _to.call{value: _amount}("");
                require(success, "Eth send fail");
            }
        }

        return _amount;
    }

    function depositWeth(uint256 _amount) internal {
        IWETH(WETH_ADDR).deposit{value: _amount}();
    }

    function withdrawWeth(uint256 _amount) internal {
        IWETH(WETH_ADDR).withdraw(_amount);
    }

    function getBalance(address _tokenAddr, address _acc) internal view returns (uint256) {
        if (_tokenAddr == ETH_ADDR) {
            return _acc.balance;
        } else {
            return IERC20(_tokenAddr).balanceOf(_acc);
        }
    }

    function getTokenDecimals(address _token) internal view returns (uint256) {
        if (_token == ETH_ADDR) return 18;

        return IERC20(_token).decimals();
    }
}










contract AaveView is AaveHelper, DSMath{

    using TokenUtils for address;

    struct LoanData {
        address user;
        uint128 ratio;
        address[] collAddr;
        address[] borrowAddr;
        uint256[] collAmounts;
        uint256[] borrowStableAmounts;
        uint256[] borrowVariableAmounts;
    }

    struct TokenInfo {
        address aTokenAddress;
        address underlyingTokenAddress;
        uint256 collateralFactor;
        uint256 price;
    }

    struct TokenInfoFull {
        address aTokenAddress;
        address underlyingTokenAddress;
        uint256 supplyRate;
        uint256 borrowRateVariable;
        uint256 borrowRateStable;
        uint256 totalSupply;
        uint256 availableLiquidity;
        uint256 totalBorrow;
        uint256 collateralFactor;
        uint256 liquidationRatio;
        uint256 price;
        uint256 totalBorrowVar;	
        uint256 totalBorrowStab;
        bool isActive;
        bool isFrozen;
        bool usageAsCollateralEnabled;
        bool borrowingEnabled;
        bool stableBorrowRateEnabled;
    }

    struct ReserveData {
        uint256 availableLiquidity;
        uint256 totalStableDebt;
        uint256 totalVariableDebt;
        uint256 liquidityRate;
        uint256 variableBorrowRate;
        uint256 stableBorrowRate;
    }

    struct UserToken {
        address token;
        uint256 balance;
        uint256 borrowsStable;
        uint256 borrowsVariable;
        uint256 stableBorrowRate;
        bool enabledAsCollateral;
    }

    function getSafetyRatio(address _market, address _user) public view returns(uint256) {
        ILendingPoolV2 lendingPool = ILendingPoolV2(ILendingPoolAddressesProviderV2(_market).getLendingPool());
        
        (,uint256 totalDebtETH,uint256 availableBorrowsETH,,,) = lendingPool.getUserAccountData(_user);

        if (totalDebtETH == 0) return uint256(0);

        return wdiv(totalDebtETH + availableBorrowsETH, totalDebtETH);
    }

    /// @notice Calculated the ratio of coll/debt for a compound user
    /// @param _market Address of LendingPoolAddressesProvider for specific market
    /// @param _user Address of the user
    function getRatio(address _market, address _user) public view returns (uint256) {
        // For each asset the account is in
        return getSafetyRatio(_market, _user);
    }

    /// @notice Fetches Aave prices for tokens
    /// @param _market Address of LendingPoolAddressesProvider for specific market
    /// @param _tokens Arr. of tokens for which to get the prices
    /// @return prices Array of prices
    function getPrices(address _market, address[] memory _tokens) public view returns (uint256[] memory prices) {
        address priceOracleAddress = ILendingPoolAddressesProviderV2(_market).getPriceOracle();
        prices = IPriceOracleGetterAave(priceOracleAddress).getAssetsPrices(_tokens);
    }

    /// @notice Fetches Aave collateral factors for tokens
    /// @param _market Address of LendingPoolAddressesProvider for specific market
    /// @param _tokens Arr. of tokens for which to get the coll. factors
    /// @return collFactors Array of coll. factors
    function getCollFactors(address _market, address[] memory _tokens) public view returns (uint256[] memory collFactors) {
        IAaveProtocolDataProviderV2 dataProvider = getDataProvider(_market);
        collFactors = new uint256[](_tokens.length);

        for (uint256 i = 0; i < _tokens.length; ++i) {
            (,collFactors[i],,,,,,,,) = dataProvider.getReserveConfigurationData(_tokens[i]);
        }
    }

    function getTokenBalances(address _market, address _user, address[] memory _tokens) public view returns (UserToken[] memory userTokens) {
        IAaveProtocolDataProviderV2 dataProvider = getDataProvider(_market);

        userTokens = new UserToken[](_tokens.length);

        for (uint256 i = 0; i < _tokens.length; i++) {
            address asset = _tokens[i];
            userTokens[i].token = asset;

            (userTokens[i].balance, userTokens[i].borrowsStable, userTokens[i].borrowsVariable,,,userTokens[i].stableBorrowRate,,,userTokens[i].enabledAsCollateral) = dataProvider.getUserReserveData(asset, _user);
        }
    }

    /// @notice Calculated the ratio of coll/debt for an aave user
    /// @param _market Address of LendingPoolAddressesProvider for specific market
    /// @param _users Addresses of the user
    /// @return ratios Array of ratios
    function getRatios(address _market, address[] memory _users) public view returns (uint256[] memory ratios) {
        ratios = new uint256[](_users.length);

        for (uint256 i = 0; i < _users.length; ++i) {
            ratios[i] = getSafetyRatio(_market, _users[i]);
        }
    }

    /// @notice Information about reserves
    /// @param _market Address of LendingPoolAddressesProvider for specific market
    /// @param _tokenAddresses Array of tokens addresses
    /// @return tokens Array of reserves information
    function getTokensInfo(address _market, address[] memory _tokenAddresses) public view returns(TokenInfo[] memory tokens) {
        IAaveProtocolDataProviderV2 dataProvider = getDataProvider(_market);
        address priceOracleAddress = ILendingPoolAddressesProviderV2(_market).getPriceOracle();

        tokens = new TokenInfo[](_tokenAddresses.length);

        for (uint256 i = 0; i < _tokenAddresses.length; ++i) {
            (,uint256 ltv,,,,,,,,) = dataProvider.getReserveConfigurationData(_tokenAddresses[i]);
            (address aToken,,) = dataProvider.getReserveTokensAddresses(_tokenAddresses[i]);

            tokens[i] = TokenInfo({
                aTokenAddress: aToken,
                underlyingTokenAddress: _tokenAddresses[i],
                collateralFactor: ltv,
                price: IPriceOracleGetterAave(priceOracleAddress).getAssetPrice(_tokenAddresses[i])
            });
        }
    }

    function getTokenInfoFull(IAaveProtocolDataProviderV2 _dataProvider, address _priceOracleAddress, address _token) public view returns(TokenInfoFull memory _tokenInfo) {
        (
            , // uint256 decimals
            uint256 ltv,
            uint256 liquidationThreshold,
            , //   uint256 liquidationBonus
            , //   uint256 reserveFactor
            bool usageAsCollateralEnabled,
            bool borrowingEnabled,
            bool stableBorrowRateEnabled,
            bool isActive,
            bool isFrozen
        ) = _dataProvider.getReserveConfigurationData(_token);

        ReserveData memory t;

        (
            t.availableLiquidity,
            t.totalStableDebt,
            t.totalVariableDebt,
            t.liquidityRate,
            t.variableBorrowRate,
            t.stableBorrowRate,
            ,
            ,
            ,

        ) = _dataProvider.getReserveData(_token);

        (address aToken,,) = _dataProvider.getReserveTokensAddresses(_token);

        uint price = IPriceOracleGetterAave(_priceOracleAddress).getAssetPrice(_token);

        _tokenInfo = TokenInfoFull({
            aTokenAddress: aToken,
            underlyingTokenAddress: _token,
            supplyRate: t.liquidityRate,
            borrowRateVariable: t.variableBorrowRate,
            borrowRateStable: t.stableBorrowRate,
            totalSupply: IERC20(aToken).totalSupply(),
            availableLiquidity: t.availableLiquidity,
            totalBorrow: t.totalVariableDebt+t.totalStableDebt,
            collateralFactor: ltv,
            liquidationRatio: liquidationThreshold,
            price: price,
            totalBorrowVar: t.totalVariableDebt,	
            totalBorrowStab: t.totalStableDebt,
            isActive: isActive,
            isFrozen: isFrozen,
            usageAsCollateralEnabled: usageAsCollateralEnabled,
            borrowingEnabled: borrowingEnabled,
            stableBorrowRateEnabled: stableBorrowRateEnabled
        });
    }

    /// @notice Information about reserves
    /// @param _market Address of LendingPoolAddressesProvider for specific market
    /// @param _tokenAddresses Array of token addresses
    /// @return tokens Array of reserves information
    function getFullTokensInfo(address _market, address[] memory _tokenAddresses) public view returns(TokenInfoFull[] memory tokens) {
        IAaveProtocolDataProviderV2 dataProvider = getDataProvider(_market);
        address priceOracleAddress = ILendingPoolAddressesProviderV2(_market).getPriceOracle();

        tokens = new TokenInfoFull[](_tokenAddresses.length);

        for (uint256 i = 0; i < _tokenAddresses.length; ++i) {
            tokens[i] = getTokenInfoFull(dataProvider, priceOracleAddress, _tokenAddresses[i]);
        }
    }


    /// @notice Fetches all the collateral/debt address and amounts, denominated in ether
    /// @param _market Address of LendingPoolAddressesProvider for specific market
    /// @param _user Address of the user
    /// @return data LoanData information
    function getLoanData(address _market, address _user) public view returns (LoanData memory data) {
        IAaveProtocolDataProviderV2 dataProvider = getDataProvider(_market);
        address priceOracleAddress = ILendingPoolAddressesProviderV2(_market).getPriceOracle();

        IAaveProtocolDataProviderV2.TokenData[] memory reserves = dataProvider.getAllReservesTokens();

        data = LoanData({
            user: _user,
            ratio: 0,
            collAddr: new address[](reserves.length),
            borrowAddr: new address[](reserves.length),
            collAmounts: new uint[](reserves.length),
            borrowStableAmounts: new uint[](reserves.length),
            borrowVariableAmounts: new uint[](reserves.length)
        });

        uint64 collPos = 0;
        uint64 borrowPos = 0;

        for (uint64 i = 0; i < reserves.length; i++) {
            address reserve = reserves[i].tokenAddress;

            (uint256 aTokenBalance, uint256 borrowsStable, uint256 borrowsVariable,,,,,,) = dataProvider.getUserReserveData(reserve, _user);
            uint256 price = IPriceOracleGetterAave(priceOracleAddress).getAssetPrice(reserve);

            if (aTokenBalance > 0) {
                uint256 userTokenBalanceEth = wmul(aTokenBalance, price) * (10 ** (18 - reserve.getTokenDecimals()));
                data.collAddr[collPos] = reserve;
                data.collAmounts[collPos] = userTokenBalanceEth;
                collPos++;
            }

            // Sum up debt in Eth
            if (borrowsStable > 0) {
                uint256 userBorrowBalanceEth = wmul(borrowsStable, price) * (10 ** (18 - reserve.getTokenDecimals()));
                data.borrowAddr[borrowPos] = reserve;
                data.borrowStableAmounts[borrowPos] = userBorrowBalanceEth;
            }

            // Sum up debt in Eth
            if (borrowsVariable > 0) {
                uint256 userBorrowBalanceEth = wmul(borrowsVariable, price) * (10 ** (18 - reserve.getTokenDecimals()));
                data.borrowAddr[borrowPos] = reserve;
                data.borrowVariableAmounts[borrowPos] = userBorrowBalanceEth;
            }

            if (borrowsStable > 0 || borrowsVariable > 0) {
                borrowPos++;
            }
        }

        data.ratio = uint128(getSafetyRatio(_market, _user));

        return data;
    }

    /// @notice Fetches all the collateral/debt address and amounts, denominated in ether
    /// @param _market Address of LendingPoolAddressesProvider for specific market
    /// @param _users Addresses of the user
    /// @return loans Array of LoanData information
    function getLoanDataArr(address _market, address[] memory _users) public view returns (LoanData[] memory loans) {
        loans = new LoanData[](_users.length);

        for (uint i = 0; i < _users.length; ++i) {
            loans[i] = getLoanData(_market, _users[i]);
        }
    }

    function getUserUnclaimedRewards(address _user) external view returns (uint256) {
        return AaveIncentivesController.getUserUnclaimedRewards(_user);
    }

    function getIncentivesRewardsBalance(
        address[] calldata _assets,
        address _user
    ) external view returns (uint256) {
        return AaveIncentivesController.getRewardsBalance(_assets, _user);
    }

    function getStakingRewardsBalance(address _staker) external view returns (uint256) {
        return StakedToken.getTotalRewardsBalance(_staker);
    }
}
