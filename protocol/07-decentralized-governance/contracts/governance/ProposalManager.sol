// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title ProposalManager
 * @dev Manages proposal lifecycle for the Karma DAO governance system
 */
contract ProposalManager is AccessControl, ReentrancyGuard {
    using Counters for Counters.Counter;
    
    bytes32 public constant PROPOSAL_CREATOR_ROLE = keccak256("PROPOSAL_CREATOR_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    enum ProposalState {
        PENDING,
        ACTIVE,
        CANCELED,
        DEFEATED,
        SUCCEEDED,
        QUEUED,
        EXPIRED,
        EXECUTED
    }
    
    enum ProposalCategory {
        TREASURY,
        PROTOCOL,
        EMERGENCY,
        UPGRADE
    }
    
    struct Proposal {
        uint256 id;
        address proposer;
        ProposalCategory category;
        string description;
        address[] targets;
        uint256[] values;
        bytes[] calldatas;
        uint256 startTime;
        uint256 endTime;
        uint256 executionTime;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool executed;
        bool canceled;
    }
    
    struct GovernanceConfig {
        uint256 proposalThreshold;
        uint256 quorumPercentage;
        uint256 votingDelay;
        uint256 votingPeriod;
        uint256 executionDelay;
        uint256 maxActions;
    }
    
    Counters.Counter private _proposalIds;
    GovernanceConfig public config;
    
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => mapping(address => uint8)) public voteChoices;
    
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        ProposalCategory indexed category,
        string description
    );
    
    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        uint8 support,
        uint256 weight
    );
    
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);
    
    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(PROPOSAL_CREATOR_ROLE, admin);
        _grantRole(EXECUTOR_ROLE, admin);
        
        config = GovernanceConfig({
            proposalThreshold: 1000000e18, // 1M KARMA
            quorumPercentage: 5,           // 5%
            votingDelay: 1 days,
            votingPeriod: 7 days,
            executionDelay: 3 days,
            maxActions: 10
        });
    }
    
    function createProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        ProposalCategory category
    ) external onlyRole(PROPOSAL_CREATOR_ROLE) returns (uint256) {
        require(targets.length == values.length, "ProposalManager: length mismatch");
        require(targets.length == calldatas.length, "ProposalManager: length mismatch");
        require(targets.length <= config.maxActions, "ProposalManager: too many actions");
        require(bytes(description).length > 0, "ProposalManager: empty description");
        
        _proposalIds.increment();
        uint256 proposalId = _proposalIds.current();
        
        uint256 startTime = block.timestamp + config.votingDelay;
        uint256 endTime = startTime + config.votingPeriod;
        
        proposals[proposalId] = Proposal({
            id: proposalId,
            proposer: msg.sender,
            category: category,
            description: description,
            targets: targets,
            values: values,
            calldatas: calldatas,
            startTime: startTime,
            endTime: endTime,
            executionTime: endTime + config.executionDelay,
            forVotes: 0,
            againstVotes: 0,
            abstainVotes: 0,
            executed: false,
            canceled: false
        });
        
        emit ProposalCreated(proposalId, msg.sender, category, description);
        
        return proposalId;
    }
    
    function castVote(
        uint256 proposalId,
        uint8 support,
        uint256 weight
    ) external onlyRole(PROPOSAL_CREATOR_ROLE) {
        require(proposals[proposalId].id == proposalId, "ProposalManager: proposal not found");
        require(!hasVoted[proposalId][msg.sender], "ProposalManager: already voted");
        require(block.timestamp >= proposals[proposalId].startTime, "ProposalManager: voting not started");
        require(block.timestamp <= proposals[proposalId].endTime, "ProposalManager: voting ended");
        require(support <= 2, "ProposalManager: invalid support value");
        
        hasVoted[proposalId][msg.sender] = true;
        voteChoices[proposalId][msg.sender] = support;
        
        if (support == 0) {
            proposals[proposalId].againstVotes += weight;
        } else if (support == 1) {
            proposals[proposalId].forVotes += weight;
        } else {
            proposals[proposalId].abstainVotes += weight;
        }
        
        emit VoteCast(proposalId, msg.sender, support, weight);
    }
    
    function executeProposal(uint256 proposalId) external onlyRole(EXECUTOR_ROLE) payable {
        require(state(proposalId) == ProposalState.SUCCEEDED, "ProposalManager: proposal not ready");
        require(block.timestamp >= proposals[proposalId].executionTime, "ProposalManager: execution delay not met");
        
        proposals[proposalId].executed = true;
        
        Proposal memory proposal = proposals[proposalId];
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            (bool success, ) = proposal.targets[i].call{value: proposal.values[i]}(proposal.calldatas[i]);
            require(success, "ProposalManager: execution failed");
        }
        
        emit ProposalExecuted(proposalId);
    }
    
    function state(uint256 proposalId) public view returns (ProposalState) {
        Proposal memory proposal = proposals[proposalId];
        
        if (proposal.id == 0) {
            revert("ProposalManager: proposal not found");
        }
        
        if (proposal.canceled) {
            return ProposalState.CANCELED;
        }
        
        if (proposal.executed) {
            return ProposalState.EXECUTED;
        }
        
        if (block.timestamp < proposal.startTime) {
            return ProposalState.PENDING;
        }
        
        if (block.timestamp <= proposal.endTime) {
            return ProposalState.ACTIVE;
        }
        
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        uint256 quorumReached = (totalVotes * 100) / 1000000e18; // Assuming 1B total supply
        
        if (quorumReached < config.quorumPercentage) {
            return ProposalState.DEFEATED;
        }
        
        if (proposal.forVotes > proposal.againstVotes) {
            if (block.timestamp >= proposal.executionTime) {
                return ProposalState.SUCCEEDED;
            } else {
                return ProposalState.QUEUED;
            }
        } else {
            return ProposalState.DEFEATED;
        }
    }
    
    function getProposal(uint256 proposalId) external view returns (Proposal memory) {
        return proposals[proposalId];
    }
    
    function updateConfig(GovernanceConfig memory newConfig) external onlyRole(ADMIN_ROLE) {
        config = newConfig;
    }
} 