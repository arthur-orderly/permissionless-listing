// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title FeeVault — Collects and distributes listing fees and broker fee markups
/// @notice Fee splits: protocol, lister, and insurance fund shares
contract FeeVault is UUPSUpgradeable, AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant COLLECTOR_ROLE = keccak256("COLLECTOR_ROLE");

    struct FeeSplit {
        uint256 protocolBps;      // Protocol share in BPS
        uint256 listerBps;        // Lister share in BPS
        uint256 insuranceBps;     // Insurance fund share in BPS
    }

    FeeSplit public feeSplit;
    address public protocolTreasury;
    address public insuranceFund;

    // token => listing => accumulated fees
    mapping(address => mapping(uint256 => uint256)) public accumulatedFees;
    // token => total undistributed
    mapping(address => uint256) public totalUndistributed;
    // listingId => lister address
    mapping(uint256 => address) public listerOf;

    event FeesCollected(address indexed token, uint256 indexed listingId, uint256 amount);
    event FeesDistributed(address indexed token, uint256 indexed listingId, uint256 protocol, uint256 lister, uint256 insurance);
    event FeeSplitUpdated(uint256 protocolBps, uint256 listerBps, uint256 insuranceBps);

    error InvalidFeeSplit();
    error NoFeesToDistribute();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() { _disableInitializers(); }

    function initialize(
        address admin,
        address _protocolTreasury,
        address _insuranceFund,
        uint256 protocolBps,
        uint256 listerBps,
        uint256 insuranceBps
    ) external initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);

        protocolTreasury = _protocolTreasury;
        insuranceFund = _insuranceFund;
        _setFeeSplit(protocolBps, listerBps, insuranceBps);
    }

    /// @notice Collect fees for a listing. Called by the protocol backend.
    function collectFees(address token, uint256 listingId, uint256 amount, address lister)
        external
        onlyRole(COLLECTOR_ROLE)
        nonReentrant
    {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        accumulatedFees[token][listingId] += amount;
        totalUndistributed[token] += amount;
        listerOf[listingId] = lister;

        emit FeesCollected(token, listingId, amount);
    }

    /// @notice Distribute accumulated fees for a listing
    function distributeFees(address token, uint256 listingId) external nonReentrant {
        uint256 amount = accumulatedFees[token][listingId];
        if (amount == 0) revert NoFeesToDistribute();

        accumulatedFees[token][listingId] = 0;
        totalUndistributed[token] -= amount;

        uint256 protocolAmt = (amount * feeSplit.protocolBps) / 10_000;
        uint256 insuranceAmt = (amount * feeSplit.insuranceBps) / 10_000;
        uint256 listerAmt = amount - protocolAmt - insuranceAmt;

        IERC20 t = IERC20(token);
        if (protocolAmt > 0) t.safeTransfer(protocolTreasury, protocolAmt);
        if (listerAmt > 0) t.safeTransfer(listerOf[listingId], listerAmt);
        if (insuranceAmt > 0) t.safeTransfer(insuranceFund, insuranceAmt);

        emit FeesDistributed(token, listingId, protocolAmt, listerAmt, insuranceAmt);
    }

    /// @notice Update fee split. Admin only.
    function updateFeeSplit(uint256 protocolBps, uint256 listerBps, uint256 insuranceBps)
        external
        onlyRole(ADMIN_ROLE)
    {
        _setFeeSplit(protocolBps, listerBps, insuranceBps);
    }

    function _setFeeSplit(uint256 protocolBps, uint256 listerBps, uint256 insuranceBps) internal {
        if (protocolBps + listerBps + insuranceBps != 10_000) revert InvalidFeeSplit();
        feeSplit = FeeSplit(protocolBps, listerBps, insuranceBps);
        emit FeeSplitUpdated(protocolBps, listerBps, insuranceBps);
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
