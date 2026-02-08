// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IListingRegistry {
    enum ListingStatus { None, Pending, Active, ReduceOnly, Delisted }

    struct ListingParams {
        uint256 baseSpread;         // Base spread in BPS
        uint256 maxLeverage;        // 5, 10, or 20
        uint256 baseImr;            // Initial margin rate (BPS)
        uint256 baseMmr;            // Maintenance margin rate (BPS)
        uint256 fundingPeriod;      // Funding interval in seconds (3600, 14400, 28800)
        uint256 minNotional;        // Min notional in USDC (6 decimals)
        uint256 takerFeeMarkup;     // 0-5 BPS
        uint256 makerFeeMarkup;     // 0-2 BPS
        uint256 marketCapUsd;       // Market cap at listing time (18 decimals)
    }

    struct Listing {
        address lister;
        string symbol;
        uint256 stakeAmount;
        ListingStatus status;
        ListingParams params;
        uint256 createdAt;
        uint256 activatedAt;
    }

    event ListingCreated(uint256 indexed listingId, address indexed lister, string symbol);
    event ListingActivated(uint256 indexed listingId);
    event ListingDeactivated(uint256 indexed listingId);
    event ListingParamsUpdated(uint256 indexed listingId);

    function createListing(string calldata symbol, ListingParams calldata params) external returns (uint256);
    function activateListing(uint256 listingId) external;
    function deactivateListing(uint256 listingId) external;
    function updateParams(uint256 listingId, ListingParams calldata params) external;
    function getListing(uint256 listingId) external view returns (Listing memory);
    function listingCount() external view returns (uint256);
}
