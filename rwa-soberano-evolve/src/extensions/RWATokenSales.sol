// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {RWATokenMinting} from "../core/RWATokenMinting.sol";

abstract contract RWATokenSales is RWATokenMinting, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using RWAMath for uint256;
    
    event AssetSaleUpdated(
        uint256 indexed assetId,
        address paymentToken,
        uint256 pricePerShareWei,
        bool saleActive
    );
    event SharesPurchased(
        address indexed buyer,
        uint256 indexed assetId,
        uint256 amount,
        uint256 cost
    );
    
    /// @notice Configure sale parameters for an asset
    /// @param _assetId Asset identifier
    /// @param _paymentToken Token address for payment (address(0) for ETH)
    /// @param _pricePerShareWei Price per whole share
    /// @param _saleActive Whether sale is active
    function setAssetSale(
        uint256 _assetId,
        address _paymentToken,
        uint256 _pricePerShareWei,
        bool _saleActive
    ) public onlyAssetManager assetExists(_assetId) {
        assets[_assetId].paymentToken = _paymentToken;
        assets[_assetId].pricePerShareWei = _pricePerShareWei;
        assets[_assetId].saleActive = _saleActive;
        emit AssetSaleUpdated(_assetId, _paymentToken, _pricePerShareWei, _saleActive);
    }
    
    /// @notice Purchase shares of an asset
    /// @param _assetId Asset identifier
    /// @param _shareAmount Amount of shares to buy (with 18 decimals)
    /// @param _data Additional data for the mint
    function buyShares(
        uint256 _assetId,
        uint256 _shareAmount,
        bytes calldata _data
    ) external payable nonReentrant assetExists(_assetId) {
        require(assets[_assetId].saleActive, "Sale not active");
        RWAValidation.requirePositiveAmount(_shareAmount);
        
        (uint256 wholeShares, uint256 cost) = RWAMath.calculateCost(
            _shareAmount,
            assets[_assetId].pricePerShareWei
        );
        
        _processPurchase(_assetId, cost);
        _mintSharesInternal(msg.sender, _assetId, _shareAmount, _data);
        
        emit SharesPurchased(msg.sender, _assetId, _shareAmount, cost);
    }
    
    /// @notice Process payment for share purchase (ETH or ERC20)
    function _processPurchase(uint256 _assetId, uint256 cost) private {
        address payToken = assets[_assetId].paymentToken;
        
        if (payToken == address(0)) {
            // ETH payment
            require(msg.value == cost, "Incorrect ETH sent");
        } else {
            // ERC20 payment - using SafeERC20 for compatibility with non-standard tokens
            require(msg.value == 0, "ETH not accepted");
            require(cost > 0, "Price not set");
            IERC20(payToken).safeTransferFrom(msg.sender, address(this), cost);
        }
    }
    
    /// @notice Withdraw accumulated payments (ETH or ERC20)
    /// @param _assetId Asset identifier
    /// @param _to Recipient address
    function withdrawPayments(uint256 _assetId, address _to)
        public
        onlyAssetManager
        assetExists(_assetId)
    {
        RWAValidation.requireValidAddress(_to);
        
        address payToken = assets[_assetId].paymentToken;
        
        if (payToken == address(0)) {
            // Withdraw ETH
            uint256 balance = address(this).balance;
            require(balance > 0, "No ETH to withdraw");
            payable(_to).transfer(balance);
        } else {
            // Withdraw ERC20 - using SafeERC20
            uint256 balance = IERC20(payToken).balanceOf(address(this));
            require(balance > 0, "No tokens to withdraw");
            IERC20(payToken).safeTransfer(_to, balance);
        }
    }
}
