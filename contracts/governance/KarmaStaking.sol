// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title KarmaStaking
 * @dev Staking contract for governance voting power calculation
 * 
 * Stage 7.1 Requirements:
 * - Staking mechanisms for voting power calculation
 * - Quadratic voting implementation with staked token amounts
 * - Participation requirements (0.1% stake threshold = 1M $KARMA)
 * - Staking rewards distribution integration
 * - Anti-spam mechanisms and quality controls
 */
contract KarmaStaking is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    // ============ CONSTANTS ============
    
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MINIMUM_STAKE_PERIOD = 7 days;
    uint256 public constant MAXIMUM_STAKE_PERIOD = 4 * 365 days; // 4 years
    uint256 public constant PROPOSAL_THRESHOLD = 1_000_000 * 1e18; // 1M KARMA
    uint256 public constant MIN_STAKE_AMOUNT = 1000 * 1e18; // 1000 KARMA minimum
    uint256 public constant EARLY_UNSTAKE_PENALTY = 1000; // 10%
    
    // Voting power calculation constants
    uint256 public constant LINEAR_WEIGHT = 5000; // 50% weight for linear component
    uint256 public constant TIME_WEIGHT = 3000; // 30% weight for time locked
    uint256 public constant QUADRATIC_WEIGHT = 2000; // 20% weight for quadratic component
    uint256 public constant MAX_VOTING_MULTIPLIER = 500; // 5x maximum multiplier
    
    // Role definitions
    bytes32 public constant STAKING_MANAGER_ROLE = keccak256("STAKING_MANAGER_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant REWARD_DISTRIBUTOR_ROLE = keccak256("REWARD_DISTRIBUTOR_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    // ============ ENUMS ============
    
    enum StakeType {
        FLEXIBLE,    // Can unstake anytime with penalty
        LOCKED_30,   // 30 days lock
        LOCKED_90,   // 90 days lock  
        LOCKED_365   // 1 year lock
    }
    
    // ============ STRUCTS ============
    
    struct StakeInfo {
        uint256 amount;          // Amount staked
        uint256 timestamp;       // When stake was created
        uint256 lockPeriod;      // Lock period in seconds
        StakeType stakeType;     // Type of stake
        uint256 rewardDebt;      // Rewards already claimed
        uint256 votingPower;     // Calculated voting power
        bool isActive;           // Whether stake is active
    }
    
    struct UserStakeData {
        uint256 totalStaked;     // Total amount staked
        uint256 totalVotingPower; // Total voting power
        uint256 lastActivity;    // Last stake/unstake activity
        uint256[] stakeIds;      // Array of stake IDs
        uint256 rewardsClaimed;  // Total rewards claimed
    }
    
    struct StakingMetrics {
        uint256 totalStaked;     // Total tokens staked
        uint256 totalStakers;    // Number of unique stakers
        uint256 totalVotingPower; // Total voting power
        uint256 averageStakePeriod; // Average stake duration
        uint256 totalRewardsDistributed; // Total rewards distributed
    }
    
    struct RewardConfig {
        uint256 baseAPY;         // Base APY in basis points (5% = 500)
        uint256 lockBonusAPY;    // Additional APY for locked stakes
        uint256 rewardsPerSecond; // Rewards distributed per second
        uint256 totalRewardPool; // Total rewards available
        uint256 distributedRewards; // Rewards already distributed
        uint256 lastUpdateTime;  // Last reward calculation update
    }
    
    // ============ STATE VARIABLES ============
    
    // Core contracts
    IERC20 public karmaToken;
    address public governance;
    address public treasury;
    
    // Staking data
    mapping(address => UserStakeData) private _userStakes;
    mapping(uint256 => StakeInfo) private _stakes;
    mapping(address => bool) public isStaker;
    
    uint256 private _nextStakeId;
    StakingMetrics public stakingMetrics;
    RewardConfig public rewardConfig;
    
    // Voting power calculation
    mapping(address => uint256) public votingPowerAtBlock;
    mapping(uint256 => uint256) public totalVotingPowerAtBlock; // block number => total voting power
    
    // Lock period configurations
    mapping(StakeType => uint256) public lockPeriods;
    mapping(StakeType => uint256) public apyBonuses; // Additional APY in basis points
    
    // Anti-spam and quality controls
    mapping(address => uint256) public lastStakeTime;
    uint256 public constant STAKE_COOLDOWN = 1 hours;
    
    // ============ EVENTS ============
    
    event Staked(
        address indexed user,
        uint256 indexed stakeId,
        uint256 amount,
        StakeType stakeType,
        uint256 lockPeriod,
        uint256 votingPower
    );
    
    event Unstaked(
        address indexed user,
        uint256 indexed stakeId,
        uint256 amount,
        uint256 penalty,
        uint256 netAmount
    );
    
    event RewardsClaimed(
        address indexed user,
        uint256 amount,
        uint256 timestamp
    );
    
    event VotingPowerUpdated(
        address indexed user,
        uint256 oldPower,
        uint256 newPower,
        uint256 blockNumber
    );
    
    event GovernanceSet(
        address indexed oldGovernance,
        address indexed newGovernance
    );
    
    event RewardConfigUpdated(
        uint256 baseAPY,
        uint256 lockBonusAPY,
        uint256 totalRewardPool
    );
    
    // ============ MODIFIERS ============
    
    modifier onlyStakingManager() {
        require(hasRole(STAKING_MANAGER_ROLE, msg.sender), "KarmaStaking: caller is not staking manager");
        _;
    }
    
    modifier onlyGovernanceRole() {
        require(hasRole(GOVERNANCE_ROLE, msg.sender), "KarmaStaking: caller does not have governance role");
        _;
    }
    
    modifier onlyRewardDistributor() {
        require(hasRole(REWARD_DISTRIBUTOR_ROLE, msg.sender), "KarmaStaking: caller is not reward distributor");
        _;
    }
    
    modifier onlyEmergencyRole() {
        require(hasRole(EMERGENCY_ROLE, msg.sender), "KarmaStaking: caller does not have emergency role");
        _;
    }
    
    modifier respectsCooldown() {
        require(
            block.timestamp >= lastStakeTime[msg.sender] + STAKE_COOLDOWN,
            "KarmaStaking: stake cooldown not met"
        );
        _;
    }
    
    modifier validStakeAmount(uint256 amount) {
        require(amount >= MIN_STAKE_AMOUNT, "KarmaStaking: amount below minimum");
        _;
    }
    
    modifier activeStake(uint256 stakeId) {
        require(_stakes[stakeId].isActive, "KarmaStaking: stake not active");
        require(_stakes[stakeId].amount > 0, "KarmaStaking: invalid stake");
        _;
    }
    
    // ============ CONSTRUCTOR ============
    
    constructor(
        address _karmaToken,
        address _treasury,
        address _admin
    ) {
        require(_karmaToken != address(0), "KarmaStaking: invalid token address");
        require(_treasury != address(0), "KarmaStaking: invalid treasury address");
        require(_admin != address(0), "KarmaStaking: invalid admin address");
        
        karmaToken = IERC20(_karmaToken);
        treasury = _treasury;
        
        // Grant roles
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(STAKING_MANAGER_ROLE, _admin);
        _grantRole(GOVERNANCE_ROLE, _admin);
        _grantRole(REWARD_DISTRIBUTOR_ROLE, _admin);
        _grantRole(EMERGENCY_ROLE, _admin);
        
        // Initialize lock periods
        lockPeriods[StakeType.FLEXIBLE] = 0;
        lockPeriods[StakeType.LOCKED_30] = 30 days;
        lockPeriods[StakeType.LOCKED_90] = 90 days;
        lockPeriods[StakeType.LOCKED_365] = 365 days;
        
        // Initialize APY bonuses for locked stakes
        apyBonuses[StakeType.FLEXIBLE] = 0; // No bonus
        apyBonuses[StakeType.LOCKED_30] = 200; // +2% APY
        apyBonuses[StakeType.LOCKED_90] = 500; // +5% APY
        apyBonuses[StakeType.LOCKED_365] = 1000; // +10% APY
        
        // Initialize reward configuration
        rewardConfig = RewardConfig({
            baseAPY: 500, // 5% base APY
            lockBonusAPY: 1000, // Up to 10% additional APY
            rewardsPerSecond: 0, // Will be set when rewards are configured
            totalRewardPool: 0, // Will be set from Treasury
            distributedRewards: 0,
            lastUpdateTime: block.timestamp
        });
        
        _nextStakeId = 1;
    }
    
    // ============ STAKING FUNCTIONS ============
    
    /**
     * @dev Stake KARMA tokens for governance voting power
     * @param amount Amount of tokens to stake
     * @param stakeType Type of stake (flexible or locked periods)
     */
    function stake(uint256 amount, StakeType stakeType) 
        external 
        whenNotPaused 
        nonReentrant 
        validStakeAmount(amount)
        respectsCooldown
        returns (uint256 stakeId)
    {
        require(karmaToken.balanceOf(msg.sender) >= amount, "KarmaStaking: insufficient balance");
        
        // Transfer tokens to contract
        karmaToken.safeTransferFrom(msg.sender, address(this), amount);
        
        // Create stake
        stakeId = _nextStakeId++;
        uint256 lockPeriod = lockPeriods[stakeType];
        
        _stakes[stakeId] = StakeInfo({
            amount: amount,
            timestamp: block.timestamp,
            lockPeriod: lockPeriod,
            stakeType: stakeType,
            rewardDebt: 0,
            votingPower: 0, // Will be calculated
            isActive: true
        });
        
        // Update user stake data
        UserStakeData storage userData = _userStakes[msg.sender];
        userData.totalStaked += amount;
        userData.stakeIds.push(stakeId);
        userData.lastActivity = block.timestamp;
        
        // Mark as staker if first stake
        if (!isStaker[msg.sender]) {
            isStaker[msg.sender] = true;
            stakingMetrics.totalStakers++;
        }
        
        // Calculate voting power
        uint256 votingPower = calculateVotingPower(amount, stakeType, lockPeriod);
        _stakes[stakeId].votingPower = votingPower;
        userData.totalVotingPower += votingPower;
        
        // Update global metrics
        stakingMetrics.totalStaked += amount;
        stakingMetrics.totalVotingPower += votingPower;
        
        // Update anti-spam tracking
        lastStakeTime[msg.sender] = block.timestamp;
        
        // Record voting power at current block
        _updateVotingPowerAtBlock(msg.sender);
        
        emit Staked(msg.sender, stakeId, amount, stakeType, lockPeriod, votingPower);
        
        return stakeId;
    }
    
    /**
     * @dev Unstake tokens (may incur penalty for early unstaking)
     * @param stakeId ID of the stake to unstake
     */
    function unstake(uint256 stakeId) 
        external 
        whenNotPaused 
        nonReentrant 
        activeStake(stakeId)
    {
        StakeInfo storage stakeInfo = _stakes[stakeId];
        require(stakeInfo.amount > 0, "KarmaStaking: no stake found");
        
        // Check if stake belongs to sender (need to implement ownership tracking)
        bool isOwner = false;
        uint256[] storage userStakeIds = _userStakes[msg.sender].stakeIds;
        for (uint256 i = 0; i < userStakeIds.length; i++) {
            if (userStakeIds[i] == stakeId) {
                isOwner = true;
                break;
            }
        }
        require(isOwner, "KarmaStaking: not stake owner");
        
        uint256 amount = stakeInfo.amount;
        uint256 penalty = 0;
        uint256 netAmount = amount;
        
        // Calculate penalty for early unstaking
        if (stakeInfo.stakeType != StakeType.FLEXIBLE) {
            uint256 lockEndTime = stakeInfo.timestamp + stakeInfo.lockPeriod;
            if (block.timestamp < lockEndTime) {
                penalty = (amount * EARLY_UNSTAKE_PENALTY) / BASIS_POINTS;
                netAmount = amount - penalty;
            }
        }
        
        // Update user data
        UserStakeData storage userData = _userStakes[msg.sender];
        userData.totalStaked -= amount;
        userData.totalVotingPower -= stakeInfo.votingPower;
        userData.lastActivity = block.timestamp;
        
        // Update global metrics
        stakingMetrics.totalStaked -= amount;
        stakingMetrics.totalVotingPower -= stakeInfo.votingPower;
        
        // Mark stake as inactive
        stakeInfo.isActive = false;
        
        // Transfer tokens back to user (minus penalty)
        karmaToken.safeTransfer(msg.sender, netAmount);
        
        // Send penalty to treasury if applicable
        if (penalty > 0) {
            karmaToken.safeTransfer(treasury, penalty);
        }
        
        // Update voting power at current block
        _updateVotingPowerAtBlock(msg.sender);
        
        emit Unstaked(msg.sender, stakeId, amount, penalty, netAmount);
    }
    
    /**
     * @dev Claim accumulated staking rewards
     */
    function claimRewards() 
        external 
        whenNotPaused 
        nonReentrant 
        returns (uint256 rewards)
    {
        require(isStaker[msg.sender], "KarmaStaking: not a staker");
        
        rewards = calculatePendingRewards(msg.sender);
        require(rewards > 0, "KarmaStaking: no rewards to claim");
        
        // Update user data
        UserStakeData storage userData = _userStakes[msg.sender];
        userData.rewardsClaimed += rewards;
        
        // Update global metrics
        rewardConfig.distributedRewards += rewards;
        stakingMetrics.totalRewardsDistributed += rewards;
        
        // Transfer rewards
        karmaToken.safeTransfer(msg.sender, rewards);
        
        emit RewardsClaimed(msg.sender, rewards, block.timestamp);
        
        return rewards;
    }
    
    // ============ VOTING POWER CALCULATION ============
    
    /**
     * @dev Calculate voting power based on staked amount, type, and lock period
     * @param amount Amount of tokens staked
     * @param stakeType Type of stake
     * @param lockPeriod Lock period in seconds
     * @return votingPower Calculated voting power
     */
    function calculateVotingPower(
        uint256 amount,
        StakeType stakeType,
        uint256 lockPeriod
    ) public pure returns (uint256 votingPower) {
        // Linear component (50% weight)
        uint256 linearComponent = (amount * LINEAR_WEIGHT) / BASIS_POINTS;
        
        // Time lock component (30% weight)
        uint256 timeMultiplier = lockPeriod > 0 ? 
            Math.min((lockPeriod * BASIS_POINTS) / (365 days), MAX_VOTING_MULTIPLIER * 100) : 0;
        uint256 timeComponent = (amount * timeMultiplier * TIME_WEIGHT) / (BASIS_POINTS * BASIS_POINTS);
        
        // Quadratic component (20% weight) - sqrt(amount) to reduce whale dominance
        uint256 quadraticComponent = (Math.sqrt(amount) * QUADRATIC_WEIGHT) / BASIS_POINTS;
        
        // Combine all components
        votingPower = linearComponent + timeComponent + quadraticComponent;
        
        // Apply maximum multiplier cap
        uint256 maxPower = (amount * MAX_VOTING_MULTIPLIER) / 100;
        if (votingPower > maxPower) {
            votingPower = maxPower;
        }
        
        return votingPower;
    }
    
    /**
     * @dev Get voting power for an address at a specific block
     * @param account Address to check
     * @param blockNumber Block number for historical lookup
     * @return votingPower Voting power at the specified block
     */
    function getVotingPowerAtBlock(address account, uint256 blockNumber) 
        external 
        view 
        returns (uint256 votingPower) 
    {
        // For current block, return current voting power
        if (blockNumber >= block.number) {
            return _userStakes[account].totalVotingPower;
        }
        
        // For historical blocks, this would require checkpoint system
        // For now, return current voting power (can be enhanced with checkpoints)
        return _userStakes[account].totalVotingPower;
    }
    
    /**
     * @dev Check if an address meets the proposal threshold
     * @param account Address to check
     * @return eligible Whether the address can create proposals
     */
    function canCreateProposal(address account) external view returns (bool eligible) {
        return _userStakes[account].totalStaked >= PROPOSAL_THRESHOLD;
    }
    
    // ============ REWARD CALCULATION ============
    
    /**
     * @dev Calculate pending rewards for a user
     * @param user Address to calculate rewards for
     * @return rewards Pending rewards amount
     */
    function calculatePendingRewards(address user) public view returns (uint256 rewards) {
        if (!isStaker[user]) return 0;
        
        UserStakeData storage userData = _userStakes[user];
        uint256 totalRewards = 0;
        
        // Calculate rewards for each active stake
        for (uint256 i = 0; i < userData.stakeIds.length; i++) {
            uint256 stakeId = userData.stakeIds[i];
            StakeInfo storage stakeInfo = _stakes[stakeId];
            
            if (!stakeInfo.isActive) continue;
            
            // Calculate time-based rewards
            uint256 stakeDuration = block.timestamp - stakeInfo.timestamp;
            uint256 effectiveAPY = rewardConfig.baseAPY + apyBonuses[stakeInfo.stakeType];
            
            // Calculate annualized rewards
            uint256 stakeRewards = (stakeInfo.amount * effectiveAPY * stakeDuration) / 
                                   (BASIS_POINTS * 365 days);
            
            totalRewards += stakeRewards;
        }
        
        // Subtract already claimed rewards
        return totalRewards > userData.rewardsClaimed ? 
               totalRewards - userData.rewardsClaimed : 0;
    }
    
    // ============ VIEW FUNCTIONS ============
    
    /**
     * @dev Get user staking information
     * @param user Address to get information for
     * @return data User stake data
     */
    function getUserStakeData(address user) 
        external 
        view 
        returns (UserStakeData memory data) 
    {
        return _userStakes[user];
    }
    
    /**
     * @dev Get specific stake information
     * @param stakeId ID of the stake
     * @return info Stake information
     */
    function getStakeInfo(uint256 stakeId) 
        external 
        view 
        returns (StakeInfo memory info) 
    {
        return _stakes[stakeId];
    }
    
    /**
     * @dev Get current staking metrics
     * @return metrics Current staking metrics
     */
    function getStakingMetrics() 
        external 
        view 
        returns (StakingMetrics memory metrics) 
    {
        return stakingMetrics;
    }
    
    /**
     * @dev Get reward configuration
     * @return config Current reward configuration
     */
    function getRewardConfig() 
        external 
        view 
        returns (RewardConfig memory config) 
    {
        return rewardConfig;
    }
    
    // ============ ADMINISTRATIVE FUNCTIONS ============
    
    /**
     * @dev Set governance contract address
     * @param _governance New governance contract address
     */
    function setGovernance(address _governance) 
        external 
        onlyGovernanceRole 
    {
        require(_governance != address(0), "KarmaStaking: invalid governance address");
        address oldGovernance = governance;
        governance = _governance;
        
        emit GovernanceSet(oldGovernance, _governance);
    }
    
    /**
     * @dev Update reward configuration
     * @param baseAPY New base APY in basis points
     * @param lockBonusAPY New lock bonus APY in basis points
     * @param totalRewardPool Total reward pool amount
     */
    function updateRewardConfig(
        uint256 baseAPY,
        uint256 lockBonusAPY,
        uint256 totalRewardPool
    ) external onlyRewardDistributor {
        require(baseAPY <= 2000, "KarmaStaking: base APY too high"); // Max 20%
        require(lockBonusAPY <= 3000, "KarmaStaking: lock bonus too high"); // Max 30%
        
        rewardConfig.baseAPY = baseAPY;
        rewardConfig.lockBonusAPY = lockBonusAPY;
        rewardConfig.totalRewardPool = totalRewardPool;
        rewardConfig.lastUpdateTime = block.timestamp;
        
        // Update rewards per second if pool is set
        if (totalRewardPool > 0) {
            rewardConfig.rewardsPerSecond = totalRewardPool / (365 days); // Distribute over 1 year
        }
        
        emit RewardConfigUpdated(baseAPY, lockBonusAPY, totalRewardPool);
    }
    
    /**
     * @dev Emergency pause staking operations
     */
    function emergencyPause() external onlyEmergencyRole {
        _pause();
    }
    
    /**
     * @dev Emergency unpause staking operations
     */
    function emergencyUnpause() external onlyEmergencyRole {
        _unpause();
    }
    
    // ============ INTERNAL FUNCTIONS ============
    
    /**
     * @dev Update voting power tracking at current block
     * @param user Address to update voting power for
     */
    function _updateVotingPowerAtBlock(address user) internal {
        uint256 oldPower = votingPowerAtBlock[user];
        uint256 newPower = _userStakes[user].totalVotingPower;
        
        votingPowerAtBlock[user] = newPower;
        totalVotingPowerAtBlock[block.number] = stakingMetrics.totalVotingPower;
        
        if (oldPower != newPower) {
            emit VotingPowerUpdated(user, oldPower, newPower, block.number);
        }
    }
} 