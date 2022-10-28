// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.16;


import {IERC165} from "IERC165.sol";

import {IERC721} from "IERC721.sol";

import {IERC721Enumerable} from "IERC721Enumerable.sol";

import {ILSSVMPairFactoryLike} from "ILSSVMPairFactoryLike.sol";
import {LSSVMPair, CurveErrorCodes} from "LSSVMPair.sol";

contract SudoGate {
    address private SUDO_PAIR_FACTORY_ADDRESS = 0xb16c1342E617A5B6E4b631EB114483FDB289c0A4;
    // address private SUDO_PAIR_ROUTER_ADDRESS = 0x2B2e8cDA09bBA9660dCA5cB6233787738Ad68329;
    address private constant BASED_GHOULS_CONTRACT_ADDRESS = 0xeF1a89cbfAbE59397FfdA11Fc5DF293E9bC5Db90;
    address private owner; 
    uint256 private contributorFeePerThousand = 1;
    
    // mapping from NFT addresses to array of known pools
    mapping (address => address[]) public pools;

    // who contributed each pool
    mapping (address => address) public poolContributors;

    constructor() {
        owner = msg.sender;
    }

    function setPairFactoryAddress(address addr) public {
        require(msg.sender == owner, "Only owner allowed to call setPairFactoryAddress");
        SUDO_PAIR_FACTORY_ADDRESS = addr;
    }

    /*
    function setPairRouterAddress(address addr) public {
        require(msg.sender == owner, "Only owner allowed to call setPairRouterAddress");
        SUDO_PAIR_ROUTER_ADDRESS = addr;
    }
    */ 

    function registerPool(address sudoswapPool) public returns (bool) {
        if (!ILSSVMPairFactoryLike(SUDO_PAIR_FACTORY_ADDRESS).isPair(sudoswapPool, ILSSVMPairFactoryLike.PairVariant.ENUMERABLE_ETH)) {
            require(ILSSVMPairFactoryLike(SUDO_PAIR_FACTORY_ADDRESS).isPair(sudoswapPool, ILSSVMPairFactoryLike.PairVariant.MISSING_ENUMERABLE_ETH), "Not a sudoswap ETH pool");
        }
        require(poolContributors[sudoswapPool] != address(0), "Pool already known");
        poolContributors[sudoswapPool] = msg.sender;
        address nft = address(LSSVMPair(sudoswapPool).nft());
        pools[nft].push(sudoswapPool); 
        
    }
    
    function buyFromPool(address pool, uint256 slippagePercent) public payable returns (bool) {
        CurveErrorCodes.Error err;
        uint256 inputAmount;
        (err, , , inputAmount, ) = LSSVMPair(pool).getBuyNFTQuote(1);
        if (err != CurveErrorCodes.Error.OK) { return false; }

        uint256 priceWithSlippage = inputAmount * (100 + slippagePercent) / 100;
        uint256 priceWithContributorFee = priceWithSlippage * contributorFeePerThousand / 1000; 
        if (priceWithContributorFee > msg.value) { return false; }
        uint256 usedAmt = LSSVMPair(pool).swapTokenForAnyNFTs{value: priceWithSlippage}(
            1, 
            priceWithSlippage, 
            msg.sender, 
            false, 
            address(0));
        require(usedAmt < msg.value, "Can't use more ETH than was originally sent");
        if (usedAmt > 0) {
            uint256 contributorFee = usedAmt * contributorFeePerThousand / 1000; 
            // send 0.1% to whoever added the pool to this contract
            payable(poolContributors[pool]).transfer(contributorFee);
            require(usedAmt + contributorFee <= msg.value, "Can't spend more than we were originally sent");
            uint256 diff = msg.value - (usedAmt + contributorFee);
            // send back unused ETH
            if (diff > 0) { payable(msg.sender).transfer(diff); }
            return true;
        }
        return false;
    }

    function tryToBuy(address nft, uint256 slippagePercent) public payable  {
        uint256 cheapestPrice;
        address cheapestPool;
        (cheapestPrice, cheapestPool) = buyQuote(nft);
        require(cheapestPool != address(0), "No pool found");
        require(cheapestPrice != type(uint256).max, "Invalid price");
        require(msg.value >= (cheapestPrice * contributorFeePerThousand / 1000) * slippagePercent / 100, "Not enough ETH");
        bool success = buyFromPool(cheapestPool, slippagePercent);
        require(success, "Failed to buy NFT");
    }

    function buyGhoul() public payable {
        tryToBuy(BASED_GHOULS_CONTRACT_ADDRESS, 0);
    }
    
    function buyQuote(address nft) public returns (uint256 cheapestPrice, address cheapestPool) {
        address[] storage nftPools = pools[nft];
        uint256 numPools = nftPools.length;
        require(numPools > 0, "No pools registered for given NFT");

        CurveErrorCodes.Error err;
        uint256 inputAmount;
        cheapestPrice = type(uint256).max;
        cheapestPool = address(0);

        address poolAddr;
        uint256 i = 0;
        for (; i < numPools; ++i) {
            poolAddr = nftPools[i];
            if (IERC721(nft).balanceOf(poolAddr) == 0) {
                // check if pool actually has any NFTs
                continue;
            } else {
                (err, , , inputAmount, ) = LSSVMPair(poolAddr).getBuyNFTQuote(1);
                if (err == CurveErrorCodes.Error.OK) {
                    if (inputAmount < cheapestPrice) {
                        cheapestPool = poolAddr;
                        cheapestPrice = inputAmount;
                    }
                }
            }
        }
    }
}