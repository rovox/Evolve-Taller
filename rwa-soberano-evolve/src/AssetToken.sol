// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title AssetToken
 * @notice NFT que representa el título de propiedad del RWA
 * @dev Contrato ERC721 simple para el título de propiedad
 */
contract AssetToken is ERC721, Ownable {
    uint256 private constant RWA_TOKEN_ID = 1;

    constructor() ERC721("Sovereign RWATitle", "SRWA") Ownable(msg.sender) {
        _mint(msg.sender, RWA_TOKEN_ID);
    }

    function getRWATokenId() external pure returns (uint256) {
        return RWA_TOKEN_ID;
    }

    function isRWATokenOwner(address account) external view returns (bool) {
        return ownerOf(RWA_TOKEN_ID) == account;
    }

    function getRWATokenOwner() external view returns (address) {
        return ownerOf(RWA_TOKEN_ID);
    }
}

/**
pragma solidity ^0.8.24;

import {ERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {IERC4626} from "lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
// Importamos ERC20 para implementar los getters que tienen conflicto con ERC721
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title AssetToken
 * @notice Tokenización de Activos del Mundo Real (RWA) que combina ERC721 (título de propiedad)
 * con funcionalidad de vault ERC-4626 para gestionar rendimientos
 * @dev Separación clara entre la propiedad del NFT y las shares del vault
 */
/*contract AssetToken is ERC721, Ownable, IERC4626 {
    // --- Constantes y Estado ---
    uint256 private constant RWA_TOKEN_ID = 1;

    // Estado interno para evitar conflictos con getters de IERC4626
    uint256 private _totalAssets;
    address private immutable _asset;

    // Estado para shares ERC-20
    uint256 private _totalSharesSupply;
    mapping(address => uint256) private _sharesBalances;
    mapping(address => mapping(address => uint256)) private _sharesAllowances;

    // Eventos personalizados
    event YieldRegistered(uint256 amount);
    event VaultSharesTransferred(
        address indexed from,
        address indexed to,
        uint256 amount
    );

    // --- Modifiers ---
    modifier onlyRWATokenOwner() {
        require(
            ownerOf(RWA_TOKEN_ID) == msg.sender,
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
        address underlyingAsset_
    ) ERC721("Sovereign RWATitle", "SRWA") Ownable(msg.sender) {
        require(
            underlyingAsset_ != address(0),
            "RWAVault: asset cannot be zero address"
        );
        _asset = underlyingAsset_;

        // Mint del NFT de propiedad al deployer
        _mint(msg.sender, RWA_TOKEN_ID);
    }

    // --- Funciones de Información del Vault ---

    function asset() public view override returns (address) {
        return _asset;
    }

    function totalAssets() public view override returns (uint256) {
        return _totalAssets;
    }

    function totalSupply() external view returns (uint256) {
        return _totalSharesSupply;
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    // --- Conversiones Assets/Shares ---

    function convertToShares(
        uint256 assets
    ) public pure override returns (uint256) {
        return assets; // Relación 1:1 en este MVP
    }

    function convertToAssets(
        uint256 shares
    ) public pure override returns (uint256) {
        return shares; // Relación 1:1 en este MVP
    }

    function previewDeposit(
        uint256 assets
    ) public view override returns (uint256) {
        return convertToShares(assets);
    }

    function previewMint(
        uint256 shares
    ) public view override returns (uint256) {
        return convertToAssets(shares);
    }

    function previewWithdraw(
        uint256 assets
    ) public view override returns (uint256) {
        return convertToShares(assets);
    }

    function previewRedeem(
        uint256 shares
    ) public view override returns (uint256) {
        return convertToAssets(shares);
    }

    // --- Límites del Vault ---

    function maxDeposit(address) external pure override returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) external pure override returns (uint256) {
        return type(uint256).max;
    }

    function maxWithdraw(
        address owner
    ) external view override returns (uint256) {
        return _sharesBalances[owner]; // 1:1 con shares
    }

    function maxRedeem(address owner) external view override returns (uint256) {
        return _sharesBalances[owner];
    }

    // --- Operaciones del Vault ---

    function deposit(
        uint256 assets,
        address receiver
    ) public override validAmount(assets) returns (uint256 shares) {
        shares = convertToShares(assets);

        _totalAssets += assets;
        _mintShares(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
        return shares;
    }

    function mint(
        uint256 shares,
        address receiver
    ) external override validAmount(shares) returns (uint256 assets) {
        assets = convertToAssets(shares);
        return deposit(assets, receiver);
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public override validAmount(assets) returns (uint256 shares) {
        require(assets <= _totalAssets, "RWAVault: insufficient vault assets");
        require(
            owner == ownerOf(RWA_TOKEN_ID),
            "RWAVault: only RWA owner can withdraw"
        );

        shares = convertToShares(assets);
        require(
            shares <= _sharesBalances[owner],
            "RWAVault: insufficient shares"
        );

        _totalAssets -= assets;
        _burnShares(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        return shares;
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external override validAmount(shares) returns (uint256 assets) {
        assets = convertToAssets(shares);
        return withdraw(assets, receiver, owner);
    }

    // --- Gestión de Shares (ERC-20) ---

    function balanceOf(address account) public view returns (uint256) {
        return _sharesBalances[account];
    }

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256) {
        return _sharesAllowances[owner][spender];
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transferShares(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        _approveShares(msg.sender, spender, value);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool) {
        _spendSharesAllowance(from, msg.sender, value);
        _transferShares(from, to, value);
        return true;
    }

    // --- Funciones Específicas del RWA ---

    function registerYield(
        uint256 amount
    ) external onlyOwner validAmount(amount) {
        _totalAssets += amount;
        emit YieldRegistered(amount);
    }

    function getRWATokenOwner() external view returns (address) {
        return ownerOf(RWA_TOKEN_ID);
    }

    // --- Funciones Internas ---

    function _mintShares(address to, uint256 shares) internal {
        _sharesBalances[to] += shares;
        _totalSharesSupply += shares;
        emit Transfer(address(0), to, shares);
    }

    function _burnShares(address from, uint256 shares) internal {
        require(
            _sharesBalances[from] >= shares,
            "RWAVault: burn amount exceeds balance"
        );
        unchecked {
            _sharesBalances[from] -= shares;
        }
        _totalSharesSupply -= shares;
        emit Transfer(from, address(0), shares);
    }

    function _transferShares(
        address from,
        address to,
        uint256 shares
    ) internal {
        require(from != address(0), "RWAVault: transfer from zero address");
        require(to != address(0), "RWAVault: transfer to zero address");
        require(
            _sharesBalances[from] >= shares,
            "RWAVault: insufficient shares"
        );

        unchecked {
            _sharesBalances[from] -= shares;
            _sharesBalances[to] += shares;
        }

        emit VaultSharesTransferred(from, to, shares);
        emit Transfer(from, to, shares);
    }

    function _approveShares(
        address owner,
        address spender,
        uint256 amount
    ) internal {
        require(owner != address(0), "RWAVault: approve from zero address");
        require(spender != address(0), "RWAVault: approve to zero address");

        _sharesAllowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendSharesAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal {
        uint256 currentAllowance = _sharesAllowances[owner][spender];
        if (currentAllowance != type(uint256).max) {
            require(
                currentAllowance >= amount,
                "RWAVault: insufficient allowance"
            );
            unchecked {
                _approveShares(owner, spender, currentAllowance - amount);
            }
        }
    }

    // --- Overrides para Resolver Conflictos ---

    function name()
        public
        view
        override(ERC721, IERC20Metadata)
        returns (string memory)
    {
        return super.name();
    }

    function symbol()
        public
        view
        override(ERC721, IERC20Metadata)
        returns (string memory)
    {
        return super.symbol();
    }

    // Deshabilitar funciones ERC-721 no deseadas para evitar confusión
    function approve(
        address,
        uint256
    ) public pure override(ERC721, IERC20) returns (bool) {
        revert("RWAVault: use shares functions for vault operations");
    }

    function transferFrom(
        address,
        address,
        uint256
    ) public pure override(ERC721, IERC20) returns (bool) {
        revert("RWAVault: use shares functions for vault operations");
    }
}*/
