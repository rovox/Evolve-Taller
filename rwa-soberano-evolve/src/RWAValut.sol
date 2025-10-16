// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {AssetToken} from "./AssetToken.sol";

/**
 * @title RWAVault
 * @notice Vault simplificado para gestionar rendimientos del RWA
 * @dev Implementa lógica similar a ERC-4626 pero simplificada para el MVP
 */
contract RWAVault is ERC20, Ownable {
    // --- Estado ---
    AssetToken public immutable assetToken;
    address public immutable underlyingAsset;
    uint256 private _totalAssets;

    // --- Events ---
    event Deposit(
        address indexed sender,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );
    event Withdraw(
        address indexed sender,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );
    event YieldRegistered(uint256 amount);

    // --- Modifiers ---
    modifier onlyRWATokenOwner() {
        require(
            assetToken.isRWATokenOwner(msg.sender),
            "RWAVault: caller is not RWA token owner"
        );
        _;
    }

    modifier validAmount(uint256 amount) {
        require(amount > 0, "RWAVault: amount must be greater than zero");
        _;
    }

    // --- Constructor ---
    constructor(
        address underlyingAsset_,
        address assetToken_
    ) ERC20("RWA Vault Shares", "rwaSHR") Ownable(msg.sender) {
        require(
            underlyingAsset_ != address(0),
            "RWAVault: asset cannot be zero address"
        );
        require(
            assetToken_ != address(0),
            "RWAVault: assetToken cannot be zero address"
        );

        underlyingAsset = underlyingAsset_;
        assetToken = AssetToken(assetToken_);
    }

    /* --- Funciones IERC4626 ---
    function asset() external view override returns (address) {
        return asset;
    }

    function totalAssets() external view override returns (uint256) {
        return _totalAssets;
    }

    function convertToShares(
        uint256 assets
    ) public pure override returns (uint256) {
        return assets; // 1:1 ratio
    }

    function convertToAssets(
        uint256 shares
    ) public pure override returns (uint256) {
        return shares; // 1:1 ratio
    }

    function maxDeposit(address) external pure override returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) external pure override returns (uint256) {
        return type(uint256).max;
    }

    function maxWithdraw(
        address owner
    ) external view override returns (uint256) {
        return balanceOf(owner); // 1:1 with shares
    }

    function maxRedeem(address owner) external view override returns (uint256) {
        return balanceOf(owner);
    }

    function previewDeposit(
        uint256 assets
    ) external view override returns (uint256) {
        return convertToShares(assets);
    }

    function previewMint(
        uint256 shares
    ) external view override returns (uint256) {
        return convertToAssets(shares);
    }

    function previewWithdraw(
        uint256 assets
    ) external view override returns (uint256) {
        return convertToShares(assets);
    }

    function previewRedeem(
        uint256 shares
    ) external view override returns (uint256) {
        return convertToAssets(shares);
    }*/

    // --- Functions del Vault ---
    function deposit(
        uint256 assets,
        address receiver
    ) external validAmount(assets) returns (uint256 shares) {
        shares = assets; //1:1 ratio
        _totalAssets += assets;
        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
        return shares;
    }

    /** function mint(
        uint256 shares,
        address receiver
    ) external override validAmount(shares) returns (uint256 assets) {
        assets = convertToAssets(shares);
        return deposit(assets, receiver);
    }*/

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external validAmount(assets) onlyRWATokenOwner returns (uint256 shares) {
        require(assets <= _totalAssets, "RWAVault: insufficient vault assets");

        shares = assets; //1:1 ratio
        require(shares <= balanceOf(owner), "RWAVault: insufficient shares");

        _totalAssets -= assets;
        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        return shares;
    }

    /**function redeem(
        uint256 shares,
        address receiver,
        address owner
    )
        external
        override
        validAmount(shares)
        onlyRWATokenOwner
        returns (uint256 assets)
    {
        assets = convertToAssets(shares);
        return withdraw(assets, receiver, owner);
    }*/

    // --- Funciones de Informacion ---
    function getTotalAssets() external view returns (uint256) {
        return _totalAssets;
    }

    function convertToShare(uint256 assets) external pure returns (uint256) {
        return assets;
    }

    function convertToAssets(uint256 shares) external pure returns (uint256) {
        return shares;
    }

    // --- Funciones Específicas del RWA ---
    function registerYield(
        uint256 amount
    ) external onlyOwner validAmount(amount) {
        _totalAssets += amount;
        emit YieldRegistered(amount);
    }

    function getToAssets() external view returns (uint256) {
        return _totalAssets;
    }
}
