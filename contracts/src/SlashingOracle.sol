// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./interfaces/IListingStake.sol";

/// @title SlashingOracle — Multisig-governed slashing with timelock
/// @notice Propose → Vote → Execute pattern. 3/5 quorum, 48h timelock.
contract SlashingOracle is UUPSUpgradeable, AccessControlUpgradeable {
    bytes32 public constant VOTER_ROLE = keccak256("VOTER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    uint256 public constant TIMELOCK = 48 hours;
    uint256 public constant QUORUM = 3; // out of 5

    enum ProposalStatus { None, Proposed, Executed, Cancelled }

    struct SlashProposal {
        uint256 listingId;
        uint256 percentageBps;
        string reason;
        uint256 proposedAt;
        uint256 voteCount;
        ProposalStatus status;
        address proposer;
    }

    IListingStake public stakeContract;
    uint256 public proposalCount;
    mapping(uint256 => SlashProposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event SlashProposed(uint256 indexed proposalId, uint256 indexed listingId, uint256 percentageBps, string reason);
    event SlashVoted(uint256 indexed proposalId, address indexed voter);
    event SlashExecuted(uint256 indexed proposalId, uint256 indexed listingId);
    event SlashCancelled(uint256 indexed proposalId);

    error ProposalNotFound();
    error AlreadyVoted();
    error TimelockNotExpired();
    error QuorumNotReached();
    error InvalidProposalStatus();
    error InvalidPercentage();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() { _disableInitializers(); }

    function initialize(address admin, address _stakeContract) external initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);

        stakeContract = IListingStake(_stakeContract);
    }

    /// @notice Propose a slash. Must be a voter.
    function proposeSlash(uint256 listingId, uint256 percentageBps, string calldata reason)
        external
        onlyRole(VOTER_ROLE)
        returns (uint256 proposalId)
    {
        if (percentageBps == 0 || percentageBps > 10_000) revert InvalidPercentage();

        proposalId = proposalCount++;
        SlashProposal storage p = proposals[proposalId];
        p.listingId = listingId;
        p.percentageBps = percentageBps;
        p.reason = reason;
        p.proposedAt = block.timestamp;
        p.status = ProposalStatus.Proposed;
        p.proposer = msg.sender;
        p.voteCount = 1;
        hasVoted[proposalId][msg.sender] = true;

        emit SlashProposed(proposalId, listingId, percentageBps, reason);
        emit SlashVoted(proposalId, msg.sender);
    }

    /// @notice Vote on a slash proposal
    function voteSlash(uint256 proposalId) external onlyRole(VOTER_ROLE) {
        SlashProposal storage p = proposals[proposalId];
        if (p.status != ProposalStatus.Proposed) revert InvalidProposalStatus();
        if (hasVoted[proposalId][msg.sender]) revert AlreadyVoted();

        hasVoted[proposalId][msg.sender] = true;
        p.voteCount++;

        emit SlashVoted(proposalId, msg.sender);
    }

    /// @notice Execute a slash after quorum + timelock
    function executeSlash(uint256 proposalId) external onlyRole(VOTER_ROLE) {
        SlashProposal storage p = proposals[proposalId];
        if (p.status != ProposalStatus.Proposed) revert InvalidProposalStatus();
        if (p.voteCount < QUORUM) revert QuorumNotReached();
        if (block.timestamp < p.proposedAt + TIMELOCK) revert TimelockNotExpired();

        p.status = ProposalStatus.Executed;
        stakeContract.slash(p.listingId, p.percentageBps, p.reason);

        emit SlashExecuted(proposalId, p.listingId);
    }

    /// @notice Cancel a proposal. Admin only.
    function cancelSlash(uint256 proposalId) external onlyRole(ADMIN_ROLE) {
        SlashProposal storage p = proposals[proposalId];
        if (p.status != ProposalStatus.Proposed) revert InvalidProposalStatus();
        p.status = ProposalStatus.Cancelled;
        emit SlashCancelled(proposalId);
    }

    function getProposal(uint256 proposalId) external view returns (SlashProposal memory) {
        return proposals[proposalId];
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
