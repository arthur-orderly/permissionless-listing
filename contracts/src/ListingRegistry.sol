// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "./interfaces/IListingRegistry.sol";
import "./libraries/ListingLib.sol";

/// @title ListingRegistry — Core registry for permissionless perpetual futures listings
/// @notice Manages the full lifecycle: create → activate → deactivate/delist
/// @dev UUPS upgradeable, role-gated
contract ListingRegistry is
    IListingRegistry,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable
{
    bytes32 public constant LISTER_ROLE = keccak256("LISTER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    uint256 private _listingCount;
    mapping(uint256 => Listing) private _listings;
    mapping(string => bool) public symbolExists;

    error ListingNotFound();
    error SymbolAlreadyListed();
    error InvalidStatus();
    error NotLister();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() { _disableInitializers(); }

    function initialize(address admin) external initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
    }

    // ─── Core functions ───

    /// @notice Create a new listing. Caller must have LISTER_ROLE.
    function createListing(
        string calldata symbol,
        ListingParams calldata params
    ) external onlyRole(LISTER_ROLE) nonReentrant returns (uint256 listingId) {
        if (symbolExists[symbol]) revert SymbolAlreadyListed();

        // Validate parameters using library
        ListingLib.validateParams(
            params.maxLeverage,
            params.marketCapUsd,
            params.baseSpread,
            params.takerFeeMarkup,
            params.makerFeeMarkup,
            params.fundingPeriod,
            params.minNotional
        );

        // Derive IMR/MMR and validate they match
        uint256 expectedImr = ListingLib.imrFromLeverage(params.maxLeverage);
        uint256 expectedMmr = ListingLib.mmrFromImr(expectedImr, params.marketCapUsd);
        require(params.baseImr == expectedImr, "IMR mismatch");
        require(params.baseMmr == expectedMmr, "MMR mismatch");

        listingId = _listingCount++;
        Listing storage l = _listings[listingId];
        l.lister = msg.sender;
        l.symbol = symbol;
        l.status = ListingStatus.Pending;
        l.params = params;
        l.createdAt = block.timestamp;

        symbolExists[symbol] = true;

        emit ListingCreated(listingId, msg.sender, symbol);
    }

    /// @notice Activate a pending listing. Admin or oracle only.
    function activateListing(uint256 listingId) external onlyRole(ADMIN_ROLE) {
        Listing storage l = _listings[listingId];
        if (l.status != ListingStatus.Pending) revert InvalidStatus();
        l.status = ListingStatus.Active;
        l.activatedAt = block.timestamp;
        emit ListingActivated(listingId);
    }

    /// @notice Deactivate (delist) a listing. Admin or lister.
    function deactivateListing(uint256 listingId) external {
        Listing storage l = _listings[listingId];
        if (l.status != ListingStatus.Active && l.status != ListingStatus.ReduceOnly) revert InvalidStatus();
        if (msg.sender != l.lister && !hasRole(ADMIN_ROLE, msg.sender)) revert NotLister();
        l.status = ListingStatus.Delisted;
        emit ListingDeactivated(listingId);
    }

    /// @notice Update listing parameters. Only lister or admin.
    function updateParams(uint256 listingId, ListingParams calldata params) external {
        Listing storage l = _listings[listingId];
        if (l.status == ListingStatus.None || l.status == ListingStatus.Delisted) revert InvalidStatus();
        if (msg.sender != l.lister && !hasRole(ADMIN_ROLE, msg.sender)) revert NotLister();

        ListingLib.validateParams(
            params.maxLeverage,
            params.marketCapUsd,
            params.baseSpread,
            params.takerFeeMarkup,
            params.makerFeeMarkup,
            params.fundingPeriod,
            params.minNotional
        );

        l.params = params;
        emit ListingParamsUpdated(listingId);
    }

    /// @notice Set listing to reduce-only mode. Admin only.
    function setReduceOnly(uint256 listingId) external onlyRole(ADMIN_ROLE) {
        Listing storage l = _listings[listingId];
        if (l.status != ListingStatus.Active) revert InvalidStatus();
        l.status = ListingStatus.ReduceOnly;
    }

    /// @notice Set the stake amount (called by ListingStake contract)
    function setStakeAmount(uint256 listingId, uint256 amount) external onlyRole(ORACLE_ROLE) {
        _listings[listingId].stakeAmount = amount;
    }

    // ─── Views ───

    function getListing(uint256 listingId) external view returns (Listing memory) {
        return _listings[listingId];
    }

    function listingCount() external view returns (uint256) {
        return _listingCount;
    }

    // ─── Upgrade auth ───
    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
