// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract DecentralizedReputation is Ownable, ReentrancyGuard {
    struct Endorsement {
        address endorser;
        uint256 weight;
        uint256 timestamp;
        string comment;
        bool positive;
    }

    struct Credential {
        string credentialType;
        address issuer;
        uint256 timestamp;
        string data;
    }

    struct ReputationData {
        uint256 positiveScore;
        uint256 negativeScore;
        uint256 totalEndorsements;
        uint256 lastUpdateTime;
    }

    mapping(address => ReputationData) public reputation;
    mapping(address => Endorsement[]) public endorsements;
    mapping(address => Credential[]) public credentials;
    mapping(address => mapping(address => bool)) public hasEndorsed;
    mapping(address => uint256) public stakedAmount;

    uint256 public constant MIN_STAKE = 0.01 ether;
    uint256 public constant DECAY_PERIOD = 365 days;
    uint256 public constant DECAY_RATE = 10; // 10% per year

    event Endorsed(
        address indexed subject,
        address indexed endorser,
        uint256 weight,
        bool positive
    );
    event CredentialIssued(
        address indexed subject,
        address indexed issuer,
        string credentialType
    );
    event StakeDeposited(address indexed user, uint256 amount);
    event StakeWithdrawn(address indexed user, uint256 amount);
    event EndorsementRevoked(address indexed subject, address indexed endorser);

    constructor() Ownable(msg.sender) {}

    function stake() external payable {
        require(msg.value >= MIN_STAKE, "Stake too low");
        stakedAmount[msg.sender] += msg.value;
        emit StakeDeposited(msg.sender, msg.value);
    }

    function withdrawStake(uint256 amount) external nonReentrant {
        require(stakedAmount[msg.sender] >= amount, "Insufficient stake");
        stakedAmount[msg.sender] -= amount;
        
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Withdrawal failed");
        
        emit StakeWithdrawn(msg.sender, amount);
    }

    function endorse(
        address subject,
        bool positive,
        string calldata comment
    ) external {
        require(subject != address(0), "Invalid subject");
        require(subject != msg.sender, "Cannot endorse self");
        require(!hasEndorsed[msg.sender][subject], "Already endorsed");
        require(stakedAmount[msg.sender] >= MIN_STAKE, "Insufficient stake");

        uint256 weight = calculateWeight(msg.sender);
        
        endorsements[subject].push(Endorsement({
            endorser: msg.sender,
            weight: weight,
            timestamp: block.timestamp,
            comment: comment,
            positive: positive
        }));

        hasEndorsed[msg.sender][subject] = true;

        ReputationData storage rep = reputation[subject];
        if (positive) {
            rep.positiveScore += weight;
        } else {
            rep.negativeScore += weight;
        }
        rep.totalEndorsements++;
        rep.lastUpdateTime = block.timestamp;

        emit Endorsed(subject, msg.sender, weight, positive);
    }

    function revokeEndorsement(address subject) external {
        require(hasEndorsed[msg.sender][subject], "No endorsement to revoke");
        
        Endorsement[] storage userEndorsements = endorsements[subject];
        ReputationData storage rep = reputation[subject];
        
        for (uint256 i = 0; i < userEndorsements.length; i++) {
            if (userEndorsements[i].endorser == msg.sender) {
                uint256 weight = userEndorsements[i].weight;
                bool positive = userEndorsements[i].positive;
                
                if (positive) {
                    rep.positiveScore -= weight;
                } else {
                    rep.negativeScore -= weight;
                }
                rep.totalEndorsements--;
                
                userEndorsements[i] = userEndorsements[userEndorsements.length - 1];
                userEndorsements.pop();
                break;
            }
        }
        
        hasEndorsed[msg.sender][subject] = false;
        rep.lastUpdateTime = block.timestamp;
        
        emit EndorsementRevoked(subject, msg.sender);
    }

    function issueCredential(
        address subject,
        string calldata credentialType,
        string calldata data
    ) external {
        require(subject != address(0), "Invalid subject");
        
        credentials[subject].push(Credential({
            credentialType: credentialType,
            issuer: msg.sender,
            timestamp: block.timestamp,
            data: data
        }));

        emit CredentialIssued(subject, msg.sender, credentialType);
    }

    function calculateWeight(address user) public view returns (uint256) {
        uint256 stake = stakedAmount[user];
        if (stake == 0) return 0;
        
        uint256 baseWeight = stake / MIN_STAKE;
        uint256 repScore = getReputationScore(user);
        
        return baseWeight + (repScore / 100);
    }

    function getReputationScore(address user) public view returns (uint256) {
        ReputationData memory rep = reputation[user];
        if (rep.totalEndorsements == 0) return 0;

        uint256 decayedPositive = applyDecay(rep.positiveScore, rep.lastUpdateTime);
        uint256 decayedNegative = applyDecay(rep.negativeScore, rep.lastUpdateTime);

        if (decayedPositive <= decayedNegative) return 0;
        return decayedPositive - decayedNegative;
    }

    function applyDecay(uint256 score, uint256 lastUpdate) internal view returns (uint256) {
        if (score == 0) return 0;
        
        uint256 timePassed = block.timestamp - lastUpdate;
        if (timePassed < DECAY_PERIOD) return score;
        
        uint256 periods = timePassed / DECAY_PERIOD;
        uint256 decayFactor = 100 - (DECAY_RATE * periods);
        
        if (decayFactor <= 0) return 0;
        return (score * decayFactor) / 100;
    }

    function getEndorsements(address user) external view returns (Endorsement[] memory) {
        return endorsements[user];
    }

    function getCredentials(address user) external view returns (Credential[] memory) {
        return credentials[user];
    }

    function getReputationData(address user) external view returns (
        uint256 score,
        uint256 positiveScore,
        uint256 negativeScore,
        uint256 totalEndorsements,
        uint256 weight
    ) {
        ReputationData memory rep = reputation[user];
        return (
            getReputationScore(user),
            rep.positiveScore,
            rep.negativeScore,
            rep.totalEndorsements,
            calculateWeight(user)
        );
    }

    function hasEndorsedUser(address endorser, address subject) external view returns (bool) {
        return hasEndorsed[endorser][subject];
    }

    receive() external payable {
        stakedAmount[msg.sender] += msg.value;
        emit StakeDeposited(msg.sender, msg.value);
    }
}