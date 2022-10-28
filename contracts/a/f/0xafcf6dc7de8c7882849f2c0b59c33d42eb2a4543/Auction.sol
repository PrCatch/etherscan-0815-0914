// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./SimpleSale.sol";

contract Auction is SimpleSale {

    using SafeMath for uint256;
    
    uint256 public initialPrice;
    uint256 public maximumPrice;
    uint256 public bidStep;
    uint256 public period;
    bool public bidCompleted;

    constructor(
        address _administrator,
        address  _seller,
        uint256 _initialPrice,
        uint256 _maximumPrice,
        uint256 _bidStep,
        uint256 _period,
        string  memory _title,
        string  memory _description,
        address _feeTo,
        uint256 _feeRate,
        uint256 _collateralFactor
    ) SimpleSale(_administrator, _seller, 0, _title, _description, _feeTo, _feeRate, _collateralFactor) {
        price = initialPrice - bidStep;
        initialPrice = _initialPrice;
        maximumPrice = _maximumPrice;
        bidStep = _bidStep;
        period = _period;
        bidCompleted = false;
    }

    function bid(uint256 amount) external {
        require( !bidCompleted );
        require( sellerCollateralAmount >= maximumPrice.mul(collateralFactor).div(1000));

        if( msg.sender == buyer ){
            buyerCollateralAmount += amount;
        }
        else{
            require( amount >= price.add(bidStep) && amount <= maximumPrice);
            TransferHelper.safeTransfer( USDToken, buyer, buyerCollateralAmount);
            buyer = msg.sender;
            buyerCollateralAmount = amount;
        }
        price = buyerCollateralAmount;
        TransferHelper.safeTransferFrom(USDToken, msg.sender, address(this), amount);
    }

    function depositCollateral(uint amount) external virtual override onlySeller {
        require( status == Status.Created );
        require( amount > 0 );
        sellerCollateralAmount = sellerCollateralAmount.add(amount);
        TransferHelper.safeTransferFrom(USDToken, msg.sender, address(this), amount);
        require(IUSDT(USDToken).balanceOf(address(this)) >= sellerCollateralAmount.add(buyerCollateralAmount));
        emit Deposited( msg.sender, amount);
    }

    function withdraw(uint256 amount) external onlySeller override {
        require( status == Status.Created );
        require( bidCompleted && buyerCollateralAmount == 0 );
        sellerCollateralAmount = sellerCollateralAmount.sub(amount);
        TransferHelper.safeTransfer( USDToken, msg.sender, amount);
        require(IUSDT(USDToken).balanceOf(address(this)) >= sellerCollateralAmount.add(buyerCollateralAmount));
        emit Withdraw(msg.sender, amount);
    }

    function completeBid() external onlySeller {
        require( block.timestamp >= createdAt.add(period));
        bidCompleted = true;
        if( buyerCollateralAmount > 0){
            status = Status.ReadyToStart;
        }
    }
}