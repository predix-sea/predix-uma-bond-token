// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/// @title PredixUmaBondToken
/// @author PrediX
/// @notice Production-grade ERC20 with role-based minting, supply cap, rolling mint rate limits,
///         and mint-only pause. Intended as PrediX's UMA bond / staking-related token module.
/// @dev Transfer and approve are intentionally NOT blocked while paused so circulating supply
///      remains liquid during operational incidents. Only `mint` is gated by `whenNotPaused`.
contract PredixUmaBondToken is ERC20, ERC20Permit, AccessControl, Pausable {
    // -------------------------------------------------------------------------
    // Roles
    // -------------------------------------------------------------------------

    /// @notice Mints new bond tokens subject to cap and rate limits.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice May pause / unpause minting (transfer remains enabled).
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice May adjust mint rate-limit parameters; DEFAULT_ADMIN may also adjust.
    bytes32 public constant RISK_ROLE = keccak256("RISK_ROLE");

    // -------------------------------------------------------------------------
    // Immutable supply cap
    // -------------------------------------------------------------------------

    /// @notice Hard upper bound on total supply; set once in the constructor.
    uint256 public immutable maxSupply;

    // -------------------------------------------------------------------------
    // Rolling mint rate limit
    // -------------------------------------------------------------------------

    /// @notice Timestamp when the current mint window started.
    uint256 public mintWindowStart;

    /// @notice Amount minted within the current window.
    uint256 public mintedInWindow;

    /// @notice Maximum amount mintable per rolling window.
    uint256 public mintLimitPerWindow;

    /// @notice Duration of each mint window in seconds.
    uint256 public mintWindowSizeSeconds;

    // -------------------------------------------------------------------------
    // Events (audit trail beyond ERC20 Transfer/Approval)
    // -------------------------------------------------------------------------

    /// @notice Emitted after a successful guarded mint.
    /// @param operator The account that invoked `mint` (holds MINTER_ROLE).
    /// @param to Recipient of minted tokens.
    /// @param amount Amount minted.
    event BondMinted(address indexed operator, address indexed to, uint256 amount);

    /// @notice Emitted when `mintLimitPerWindow` is updated.
    event BondMintLimitUpdated(uint256 oldLimit, uint256 newLimit);

    /// @notice Emitted when `mintWindowSizeSeconds` is updated.
    event BondMintWindowUpdated(uint256 oldWindow, uint256 newWindow);

    /// @notice Emitted when minting is paused.
    event BondPaused(address indexed operator);

    /// @notice Emitted when minting is unpaused.
    event BondUnpaused(address indexed operator);

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error ZeroAddress();
    error ExceedsMaxSupply(uint256 requested, uint256 available);
    error MintRateLimitExceeded(uint256 requested, uint256 availableInWindow);
    error InvalidMintWindowSize();
    error UnauthorizedRiskOrAdmin(address account);
    error MintLimitBelowCurrentWindowUsage(uint256 mintedInWindow_, uint256 newLimit);

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    /// @param name_ ERC20 name.
    /// @param symbol_ ERC20 symbol.
    /// @param maxSupply_ Immutable maximum total supply.
    /// @param admin Receives DEFAULT_ADMIN_ROLE (governance; prefer multisig).
    /// @param minter Receives MINTER_ROLE.
    /// @param pauser Receives PAUSER_ROLE.
    /// @param risk Receives RISK_ROLE.
    /// @param mintLimitPerWindow_ Initial per-window mint cap.
    /// @param mintWindowSizeSeconds_ Initial window length (must be > 0).
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 maxSupply_,
        address admin,
        address minter,
        address pauser,
        address risk,
        uint256 mintLimitPerWindow_,
        uint256 mintWindowSizeSeconds_
    ) ERC20(name_, symbol_) ERC20Permit(name_) {
        if (admin == address(0) || minter == address(0) || pauser == address(0) || risk == address(0)) {
            revert ZeroAddress();
        }
        if (mintWindowSizeSeconds_ == 0) revert InvalidMintWindowSize();

        maxSupply = maxSupply_;
        mintLimitPerWindow = mintLimitPerWindow_;
        mintWindowSizeSeconds = mintWindowSizeSeconds_;
        mintWindowStart = block.timestamp;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, minter);
        _grantRole(PAUSER_ROLE, pauser);
        _grantRole(RISK_ROLE, risk);
    }

    // -------------------------------------------------------------------------
    // Minting
    // -------------------------------------------------------------------------

    /// @notice Mint bond tokens to `to`.
    /// @dev Reverts when paused, over maxSupply, or over rolling window limit.
    /// @param to Recipient; must not be zero address.
    /// @param amount Amount to mint.
    function mint(
        address to,
        uint256 amount
    ) external onlyRole(MINTER_ROLE) whenNotPaused {
        if (to == address(0)) revert ZeroAddress();

        _rollMintWindowIfNeeded();

        uint256 availableInWindow = mintLimitPerWindow - mintedInWindow;
        if (amount > availableInWindow) {
            revert MintRateLimitExceeded(amount, availableInWindow);
        }

        uint256 supplyAfter = totalSupply() + amount;
        if (supplyAfter > maxSupply) {
            revert ExceedsMaxSupply(amount, maxSupply - totalSupply());
        }

        mintedInWindow += amount;
        _mint(to, amount);
        emit BondMinted(msg.sender, to, amount);
    }

    // -------------------------------------------------------------------------
    // Pause (mint only)
    // -------------------------------------------------------------------------

    /// @notice Pause minting. Transfers and permits remain available.
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
        emit BondPaused(msg.sender);
    }

    /// @notice Resume minting.
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
        emit BondUnpaused(msg.sender);
    }

    // -------------------------------------------------------------------------
    // Risk / admin parameter governance
    // -------------------------------------------------------------------------

    /// @notice Update per-window mint limit. Callable by RISK_ROLE or DEFAULT_ADMIN_ROLE.
    /// @param newLimit New `mintLimitPerWindow`.
    function setMintLimitPerWindow(
        uint256 newLimit
    ) external {
        _requireRiskOrAdmin();
        if (!_windowExpired() && newLimit < mintedInWindow) {
            revert MintLimitBelowCurrentWindowUsage(mintedInWindow, newLimit);
        }
        uint256 oldLimit = mintLimitPerWindow;
        mintLimitPerWindow = newLimit;
        emit BondMintLimitUpdated(oldLimit, newLimit);
    }

    /// @notice Update mint window size. Callable by RISK_ROLE or DEFAULT_ADMIN_ROLE.
    /// @param newWindow New window length in seconds; must be > 0.
    function setMintWindowSizeSeconds(
        uint256 newWindow
    ) external {
        _requireRiskOrAdmin();
        if (newWindow == 0) revert InvalidMintWindowSize();
        uint256 oldWindow = mintWindowSizeSeconds;
        mintWindowSizeSeconds = newWindow;
        emit BondMintWindowUpdated(oldWindow, newWindow);
    }

    // -------------------------------------------------------------------------
    // Views
    // -------------------------------------------------------------------------

    /// @notice Remaining mint capacity in the current window (may roll window on next mint).
    function remainingMintInWindow() external view returns (uint256) {
        if (_windowExpired()) {
            return mintLimitPerWindow;
        }
        return mintLimitPerWindow - mintedInWindow;
    }

    /// @notice Remaining supply until `maxSupply`.
    function remainingMaxSupply() external view returns (uint256) {
        return maxSupply - totalSupply();
    }

    // -------------------------------------------------------------------------
    // Internal
    // -------------------------------------------------------------------------

    /// @dev We deliberately do NOT override `_update` with `whenNotPaused`.
    ///      Pausable is only enforced on the external `mint` entrypoint so transfers,
    ///      burns, and EIP-2612 permits remain available while minting is halted.

    function _rollMintWindowIfNeeded() internal {
        if (_windowExpired()) {
            mintWindowStart = block.timestamp;
            mintedInWindow = 0;
        }
    }

    function _windowExpired() internal view returns (bool) {
        return block.timestamp >= mintWindowStart + mintWindowSizeSeconds;
    }

    function _requireRiskOrAdmin() internal view {
        if (!hasRole(RISK_ROLE, msg.sender) && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert UnauthorizedRiskOrAdmin(msg.sender);
        }
    }
}
