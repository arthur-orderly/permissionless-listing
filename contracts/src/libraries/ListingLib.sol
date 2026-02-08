// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title ListingLib — Parameter validation and derived calculations for permissionless listings
/// @notice Pure library for leverage caps, margin rates, fee bounds, and risk parameter derivation
library ListingLib {
    // ─── Leverage cap tiers (market cap in USD with 18 decimals) ───
    uint256 constant MCAP_TIER_LOW = 30_000_000e18;   // $30M
    uint256 constant MCAP_TIER_MID = 100_000_000e18;  // $100M

    uint256 constant MAX_LEVERAGE_LOW = 5;
    uint256 constant MAX_LEVERAGE_MID = 10;
    uint256 constant MAX_LEVERAGE_HIGH = 20;

    // Fee markup bounds (basis points)
    uint256 constant MAX_TAKER_FEE_MARKUP = 5;
    uint256 constant MAX_MAKER_FEE_MARKUP = 2;

    // Margin constants (basis points, i.e. 10000 = 100%)
    uint256 constant BPS = 10_000;

    /// @notice Errors
    error LeverageExceedsCap(uint256 requested, uint256 cap);
    error InvalidIMR();
    error InvalidMMR();
    error TakerFeeMarkupTooHigh();
    error MakerFeeMarkupTooHigh();
    error MinNotionalTooLow();
    error InvalidFundingPeriod();
    error ZeroBaseSpread();

    /// @notice Returns the maximum allowed leverage given a market cap (18-decimal USD value)
    function maxLeverageForMarketCap(uint256 marketCapUsd) internal pure returns (uint256) {
        if (marketCapUsd < MCAP_TIER_LOW) return MAX_LEVERAGE_LOW;
        if (marketCapUsd < MCAP_TIER_MID) return MAX_LEVERAGE_MID;
        return MAX_LEVERAGE_HIGH;
    }

    /// @notice Derives IMR from leverage: IMR = 1/leverage (returned in BPS)
    function imrFromLeverage(uint256 leverage) internal pure returns (uint256) {
        if (leverage == 0) revert InvalidIMR();
        return BPS / leverage;
    }

    /// @notice Derives MMR from IMR and market cap
    /// Special case: mcap < $100M and IMR = 10% → MMR = 6%
    function mmrFromImr(uint256 imrBps, uint256 marketCapUsd) internal pure returns (uint256) {
        if (imrBps == 1000 && marketCapUsd < MCAP_TIER_MID) {
            return 600; // 6%
        }
        return imrBps / 2;
    }

    /// @notice Validates that requested leverage does not exceed the market-cap-based cap
    function validateLeverage(uint256 leverage, uint256 marketCapUsd) internal pure {
        uint256 cap = maxLeverageForMarketCap(marketCapUsd);
        if (leverage > cap) revert LeverageExceedsCap(leverage, cap);
        if (leverage == 0) revert LeverageExceedsCap(0, cap);
    }

    /// @notice Validates fee markup bounds
    function validateFeeMarkups(uint256 takerBps, uint256 makerBps) internal pure {
        if (takerBps > MAX_TAKER_FEE_MARKUP) revert TakerFeeMarkupTooHigh();
        if (makerBps > MAX_MAKER_FEE_MARKUP) revert MakerFeeMarkupTooHigh();
    }

    /// @notice Validates all listing parameters
    function validateParams(
        uint256 leverage,
        uint256 marketCapUsd,
        uint256 baseSpread,
        uint256 takerFeeMarkup,
        uint256 makerFeeMarkup,
        uint256 fundingPeriod,
        uint256 minNotional
    ) internal pure {
        validateLeverage(leverage, marketCapUsd);
        validateFeeMarkups(takerFeeMarkup, makerFeeMarkup);
        if (baseSpread == 0) revert ZeroBaseSpread();
        if (fundingPeriod == 0) revert InvalidFundingPeriod();
        if (minNotional < 10e6) revert MinNotionalTooLow(); // 10 USDC (6 decimals)
    }

    /// @notice Calculates liquidation fee rate based on max leverage
    /// @return stdLiqFee in BPS, liquidatorFee in BPS
    function liquidationFees(uint256 leverage) internal pure returns (uint256 stdLiqFee, uint256 liquidatorFee) {
        if (leverage >= 50) {
            stdLiqFee = 80;  // 0.8%
        } else if (leverage >= 20) {
            stdLiqFee = 150; // 1.5%
        } else {
            stdLiqFee = 240; // 2.4%
        }
        liquidatorFee = stdLiqFee / 2;
    }

    /// @notice Impact margin notional based on leverage
    function impactMarginNotional(uint256 leverage) internal pure returns (uint256) {
        if (leverage > 10) return 1000e6;
        if (leverage > 5) return 500e6;
        return 100e6;
    }

    /// @notice Price range based on leverage
    function priceRange(uint256 leverage) internal pure returns (uint256) {
        if (leverage >= 20) return 300; // 3% in BPS
        return 500; // 5%
    }

    /// @notice IF Rate calculation: baseRate * leverageMultiplier (returns BPS)
    function ifRate(uint256 marketCapUsd, uint256 leverage) internal pure returns (uint256) {
        uint256 baseRate;
        if (marketCapUsd >= 1_000_000_000e18) baseRate = 300;       // 3%
        else if (marketCapUsd >= 500_000_000e18) baseRate = 400;    // 4%
        else if (marketCapUsd >= 100_000_000e18) baseRate = 500;    // 5%
        else if (marketCapUsd >= 25_000_000e18) baseRate = 700;     // 7%
        else baseRate = 1000;                                        // 10%

        uint256 multiplier;
        if (leverage <= 5) multiplier = 150;       // 1.5x (in 100-base)
        else if (leverage <= 10) multiplier = 120;  // 1.2x
        else if (leverage <= 20) multiplier = 100;  // 1.0x
        else multiplier = 80;                       // 0.8x

        return (baseRate * multiplier) / 100;
    }

    /// @notice Liquidation rate based on leverage (BPS)
    function liqRate(uint256 leverage) internal pure returns (uint256) {
        if (leverage <= 5) return 250;   // 2.5%
        if (leverage <= 10) return 200;  // 2.0%
        if (leverage <= 20) return 150;  // 1.5%
        return 100;                      // 1.0%
    }
}
