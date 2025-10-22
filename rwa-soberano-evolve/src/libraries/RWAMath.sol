// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library RWAMath {
    uint256 constant DECIMALS = 18;
    uint256 constant SHARES_MULTIPLIER = 10 ** DECIMALS;
    uint256 constant PERCENTAGE_BASE = 100;
    
    /// @notice Calculate the percentage of shares held
    /// @param balance User's share balance
    /// @param totalShares Total shares in circulation
    /// @return Percentage with 2 decimal precision (e.g., 2550 = 25.50%)
    function calculateSharePercentage(
        uint256 balance,
        uint256 totalShares
    ) internal pure returns (uint256) {
        if (balance == 0) return 0;
        return (balance * PERCENTAGE_BASE) / (totalShares * SHARES_MULTIPLIER);
    }
    
    /// @notice Calculate USD value of shareholder's position
    /// @param balance User's share balance
    /// @param totalShares Total shares in circulation
    /// @param totalValue Total asset value in USD
    /// @return USD value of the position
    function calculateShareholderValue(
        uint256 balance,
        uint256 totalShares, 
        uint256 totalValue
    ) internal pure returns (uint256) {
        uint256 percentage = calculateSharePercentage(balance, totalShares);
        return (totalValue * percentage) / PERCENTAGE_BASE;
    }
    
    /// @notice Calculate cost for purchasing shares
    /// @param shareAmount Amount of shares to purchase (with decimals)
    /// @param pricePerShareWei Price per whole share in wei
    /// @return wholeShares Number of whole shares
    /// @return cost Total cost in wei
    function calculateCost(
        uint256 shareAmount,
        uint256 pricePerShareWei
    ) internal pure returns (uint256 wholeShares, uint256 cost) {
        wholeShares = shareAmount / SHARES_MULTIPLIER;
        require(wholeShares > 0, "Amount too small");
        cost = wholeShares * pricePerShareWei;
    }
    
    /// @notice Calculate percentage of an amount
    /// @param amount Base amount
    /// @param percentage Percentage to calculate (e.g., 25 = 25%)
    /// @return Result of percentage calculation
    function percentageOf(uint256 amount, uint256 percentage) internal pure returns (uint256) {
        return (amount * percentage) / PERCENTAGE_BASE;
    }
}
