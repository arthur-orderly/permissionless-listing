// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IListingStake {
    event Staked(uint256 indexed listingId, address indexed staker, uint256 amount);
    event Unstaked(uint256 indexed listingId, address indexed staker, uint256 amount);
    event Slashed(uint256 indexed listingId, uint256 amount, uint256 percentage, string reason);

    function stake(uint256 listingId, uint256 amount) external;
    function unstake(uint256 listingId) external;
    function slash(uint256 listingId, uint256 percentageBps, string calldata reason) external;
    function getStake(uint256 listingId) external view returns (uint256 amount, uint256 stakedAt, bool locked);
    function minStakeAmount() external view returns (uint256);
    function lockPeriod() external view returns (uint256);
}
