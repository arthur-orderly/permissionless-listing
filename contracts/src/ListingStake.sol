// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IListingStake.sol";
import "./interfaces/IListingRegistry.sol";

/// @title ListingStake — Stake deposits and slashing for permissionless listings
/// @notice Listers stake USDC to back their listing; slashable for violations
contract ListingStake is IListingStake, UUPSUpgradeable, AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    struct StakeInfo {
        uint256 amount;
        uint256 stakedAt;
        address staker;
    }

    IERC20 public stakeToken;           // USDC
    IListingRegistry public registry;
    address public insuranceFund;
    uint256 public minStakeAmount;      // e.g. 50_000e6 ($50K USDC)
    uint256 public lockPeriod;          // e.g. 180 days

    mapping(uint256 => StakeInfo) private _stakes;

    error InsufficientStake();
    error StakeLocked();
    error ListingNotDelisted();
    error AlreadyStaked();
    error NoStake();
    error InvalidSlashPercentage();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() { _disableInitializers(); }

    function initialize(
        address admin,
        address _stakeToken,
        address _registry,
        address _insuranceFund,
        uint256 _minStake,
        uint256 _lockPeriod
    ) external initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);

        stakeToken = IERC20(_stakeToken);
        registry = IListingRegistry(_registry);
        insuranceFund = _insuranceFund;
        minStakeAmount = _minStake;
        lockPeriod = _lockPeriod;
    }

    /// @notice Stake tokens for a listing
    function stake(uint256 listingId, uint256 amount) external nonReentrant {
        if (amount < minStakeAmount) revert InsufficientStake();
        StakeInfo storage s = _stakes[listingId];
        if (s.amount > 0) revert AlreadyStaked();

        // Verify listing exists and is pending
        IListingRegistry.Listing memory listing = registry.getListing(listingId);
        require(listing.status == IListingRegistry.ListingStatus.Pending, "Not pending");

        s.amount = amount;
        s.stakedAt = block.timestamp;
        s.staker = msg.sender;

        stakeToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Staked(listingId, msg.sender, amount);
    }

    /// @notice Unstake after lock period expires AND listing is delisted
    function unstake(uint256 listingId) external nonReentrant {
        StakeInfo storage s = _stakes[listingId];
        if (s.amount == 0) revert NoStake();
        require(s.staker == msg.sender, "Not staker");

        if (block.timestamp < s.stakedAt + lockPeriod) revert StakeLocked();

        IListingRegistry.Listing memory listing = registry.getListing(listingId);
        if (listing.status != IListingRegistry.ListingStatus.Delisted) revert ListingNotDelisted();

        uint256 amount = s.amount;
        s.amount = 0;

        stakeToken.safeTransfer(msg.sender, amount);

        emit Unstaked(listingId, msg.sender, amount);
    }

    /// @notice Slash a listing's stake. Oracle role only.
    /// @param percentageBps Slash percentage in BPS (0-10000, i.e. 0%-100%)
    function slash(uint256 listingId, uint256 percentageBps, string calldata reason)
        external
        onlyRole(ORACLE_ROLE)
        nonReentrant
    {
        if (percentageBps == 0 || percentageBps > 10_000) revert InvalidSlashPercentage();
        StakeInfo storage s = _stakes[listingId];
        if (s.amount == 0) revert NoStake();

        uint256 slashAmount = (s.amount * percentageBps) / 10_000;
        s.amount -= slashAmount;

        stakeToken.safeTransfer(insuranceFund, slashAmount);

        emit Slashed(listingId, slashAmount, percentageBps, reason);
    }

    // ─── Views ───

    function getStake(uint256 listingId) external view returns (uint256 amount, uint256 stakedAt, bool locked) {
        StakeInfo storage s = _stakes[listingId];
        amount = s.amount;
        stakedAt = s.stakedAt;
        locked = block.timestamp < s.stakedAt + lockPeriod;
    }

    // ─── Admin ───

    function setMinStakeAmount(uint256 _amount) external onlyRole(ADMIN_ROLE) {
        minStakeAmount = _amount;
    }

    function setLockPeriod(uint256 _period) external onlyRole(ADMIN_ROLE) {
        lockPeriod = _period;
    }

    function setInsuranceFund(address _fund) external onlyRole(ADMIN_ROLE) {
        insuranceFund = _fund;
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
