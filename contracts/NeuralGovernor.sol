// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/governance/utils/IVotes.sol";

contract NeuralGovernor {
    IVotes public immutable votes;

    uint256 public votingDelay = 1;
    uint256 public votingPeriod = 45818;
    uint256 public quorumVotes;
    uint256 public timelock = 2 days;

    enum State { Pending, Active, Defeated, Succeeded, Queued, Executed }

    struct Proposal {
        address proposer;
        address target;
        bytes callData;
        uint256 startBlock;
        uint256 endBlock;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 eta;
        bool executed;
        string description;
    }

    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event ProposalCreated(uint256 indexed id, address indexed proposer, address target, string description);
    event VoteCast(uint256 indexed id, address indexed voter, bool support, uint256 weight);
    event ProposalQueued(uint256 indexed id, uint256 eta);
    event ProposalExecuted(uint256 indexed id);

    constructor(address votes_, uint256 quorumVotes_) {
        votes = IVotes(votes_);
        quorumVotes = quorumVotes_;
    }

    function propose(address target, bytes calldata callData, string calldata description)
        external
        returns (uint256 id)
    {
        require(target != address(0), "bad target");
        id = ++proposalCount;
        Proposal storage p = proposals[id];
        p.proposer = msg.sender;
        p.target = target;
        p.callData = callData;
        p.startBlock = block.number + votingDelay;
        p.endBlock = p.startBlock + votingPeriod;
        p.description = description;
        emit ProposalCreated(id, msg.sender, target, description);
    }

    function castVote(uint256 id, bool support) external {
        Proposal storage p = proposals[id];
        require(block.number >= p.startBlock, "not started");
        require(block.number <= p.endBlock, "ended");
        require(!hasVoted[id][msg.sender], "voted");

        uint256 weight = votes.getPastVotes(msg.sender, p.startBlock - 1);
        require(weight > 0, "no votes");
        hasVoted[id][msg.sender] = true;
        if (support) p.forVotes += weight;
        else p.againstVotes += weight;
        emit VoteCast(id, msg.sender, support, weight);
    }

    function state(uint256 id) public view returns (State) {
        Proposal storage p = proposals[id];
        if (p.executed) return State.Executed;
        if (block.number < p.startBlock) return State.Pending;
        if (block.number <= p.endBlock) return State.Active;
        if (p.forVotes <= p.againstVotes || p.forVotes < quorumVotes) return State.Defeated;
        if (p.eta == 0) return State.Succeeded;
        return State.Queued;
    }

    function queue(uint256 id) external {
        require(state(id) == State.Succeeded, "not succeeded");
        proposals[id].eta = block.timestamp + timelock;
        emit ProposalQueued(id, proposals[id].eta);
    }

    function execute(uint256 id) external returns (bytes memory) {
        require(state(id) == State.Queued, "not queued");
        Proposal storage p = proposals[id];
        require(block.timestamp >= p.eta, "timelock");
        p.executed = true;
        (bool ok, bytes memory ret) = p.target.call(p.callData);
        require(ok, "exec failed");
        emit ProposalExecuted(id);
        return ret;
    }
}