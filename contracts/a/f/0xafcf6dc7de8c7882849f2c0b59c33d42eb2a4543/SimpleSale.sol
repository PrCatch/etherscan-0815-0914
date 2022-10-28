// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./Escrow.sol";

contract SimpleSale is Escrow {

    using SafeMath for uint256;

    constructor(
        address _administrator,
        address  _seller,
        uint256 _price,
        string  memory _title,
        string  memory _description,
        address _feeTo,
        uint256 _feeRate,
        uint256 _collateralFactor
    ) Escrow(_administrator, _seller, address(0), _price, _title, _description, _feeTo, _feeRate, _collateralFactor) {

    }

    function depositCollateral(uint amount) external virtual override {
        require( buyer == address(0) || msg.sender == seller);
        require( status == Status.Created );
        require( amount > 0 );
        if( msg.sender == seller ){
            sellerCollateralAmount = sellerCollateralAmount.add(amount);
        }else{
            require( amount >= price );
            buyer = msg.sender;
            buyerCollateralAmount = amount;
        }
        TransferHelper.safeTransferFrom(USDToken, msg.sender, address(this), amount);

        if( buyerCollateralAmount >= price && sellerCollateralAmount >= price.mul(collateralFactor).div(1000) ){
            status = Status.ReadyToStart;
        }

        require(IUSDT(USDToken).balanceOf(address(this)) >= sellerCollateralAmount.add(buyerCollateralAmount));
        emit Deposited( msg.sender, amount);
    }
}