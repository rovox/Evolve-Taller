// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./RWAToken.sol";

/**
 * @title DividendDistributor
 * @dev Contrato para distribuir dividendos entre accionistas
 */
contract DividendDistributor is Ownable {
    RWAToken public rwaToken;

    struct Dividend {
        uint256 assetId;
        uint256 totalAmount;
        uint256 timestamp;
        bool distributed;
    }

    mapping(uint256 => Dividend[]) public dividends;
    mapping(uint256 => mapping(address => uint256)) public claimedDividends;

    event DividendCreated(
        uint256 indexed assetId,
        uint256 totalAmount,
        uint256 timestamp
    );

    event DividendClaimed(
        uint256 indexed assetId,
        address indexed shareholder,
        uint256 amount
    );

    constructor(address _rwaTokenAddress) Ownable(msg.sender) {
        rwaToken = RWAToken(_rwaTokenAddress);
    }

    /**
     * @dev Crear un dividendo para un activo
     */
    function createDividend(uint256 _assetId) public payable onlyOwner {
        require(msg.value > 0, "Dividend amount must be greater than 0");

        Dividend memory dividend = Dividend({
            assetId: _assetId,
            totalAmount: msg.value,
            timestamp: block.timestamp,
            distributed: false
        });

        dividends[_assetId].push(dividend);
        emit DividendCreated(_assetId, msg.value, block.timestamp);
    }

    /**
     * @dev Reclamar dividendos para un accionista
     */
    function claimDividend(uint256 _assetId, uint256 _dividendIndex)
        public
    {
        require(
            _dividendIndex < dividends[_assetId].length,
            "Dividend does not exist"
        );

        Dividend storage dividend = dividends[_assetId][_dividendIndex];
        uint256 percentage = rwaToken.getSharePercentage(_assetId, msg.sender);

        require(percentage > 0, "No shares in this asset");
        require(
            claimedDividends[_assetId][msg.sender] < _dividendIndex + 1,
            "Already claimed"
        );

        uint256 amount = (dividend.totalAmount * percentage) / 100;
        claimedDividends[_assetId][msg.sender] = _dividendIndex + 1;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        emit DividendClaimed(_assetId, msg.sender, amount);
    }

    /**
     * @dev Obtener dividendos disponibles
     */
    function getDividends(uint256 _assetId)
        public
        view
        returns (Dividend[] memory)
    {
        return dividends[_assetId];
    }

    receive() external payable {}
}