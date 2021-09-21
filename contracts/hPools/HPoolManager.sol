//"SPDX-License-Identifier: UNLICENSED"
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155HolderUpgradeable.sol";

import "../interfaces/AggregatorV3Interface.sol";
import "../interfaces/IHordTicketFactory.sol";
import "../interfaces/IHordTreasury.sol";
import "../interfaces/IHPoolFactory.sol";
import "../interfaces/IHordConfiguration.sol";
import "../interfaces/IHPool.sol";
import "../system/HordUpgradable.sol";
import "../libraries/SafeMath.sol";

/**
 * HPoolManager contract.
 * @author Nikola Madjarevic
 * Date created: 7.7.21.
 * Github: madjarevicn
 */
contract HPoolManager is ERC1155HolderUpgradeable, HordUpgradable {
    using SafeMath for *;

    // States of the pool contract
    enum PoolState {
        PENDING_INIT,
        TICKET_SALE,
        PRIVATE_SUBSCRIPTION,
        PUBLIC_SUBSCRIPTION,
        SUBSCRIPTION_FAILED,
        ASSET_STATE_TRANSITION_IN_PROGRESS,
        ACTIVE,
        FINISHING,
        ENDED
    }

    enum SubscriptionRound {
        PRIVATE,
        PUBLIC
    }

    // Address for HORD token
    address public hordToken;
    // Constant, representing 1ETH in WEI units.
    uint256 public constant one = 10e18;

    // Subscription struct, represents subscription of user
    struct Subscription {
        address user;
        uint256 amountEth;
        uint256 numberOfTickets;
        SubscriptionRound sr;
        bool isSubscriptionWithdrawnPoolTerminated;
    }

    // HPool struct
    struct hPool {
        PoolState poolState;
        uint256 championEthDeposit;
        address championAddress;
        uint256 createdAt;
        uint256 endTicketSalePhase;
        uint256 endPrivateSubscriptionPhase;
        uint256 endPublicSubscriptionSalePhase;
        uint256 nftTicketId;
        bool isValidated;
        uint256 followersEthDeposit;
        address hPoolContractAddress;
        uint256 treasuryFeePaid;
    }

    // Instance of Hord Configuration contract
    IHordConfiguration internal hordConfiguration;
    // Instance of oracle
    AggregatorV3Interface internal linkOracle;
    // Instance of hord ticket factory
    IHordTicketFactory internal hordTicketFactory;
    // Instance of Hord treasury contract
    IHordTreasury internal hordTreasury;
    // Instance of HPool Factory contract
    IHPoolFactory internal hPoolFactory;

    // All hPools
    hPool[] public hPools;
    //Number of tickets used for subscribing
    mapping(uint256 => uint256) usedTickets;
    // Map pool Id to all subscriptions
    mapping(uint256 => Subscription[]) internal poolIdToSubscriptions;
    // Map user address to pool id to his subscription for that pool
    mapping(address => mapping(uint256 => Subscription))
        internal userToPoolIdToSubscription;
    // Mapping user to ids of all pools he has subscribed for
    mapping(address => uint256[]) internal userToPoolIdsSubscribedFor;
    // Support listing pools per champion
    mapping(address => uint256[]) internal championAddressToHPoolIds;

    /**
     * Events
     */
    event PoolInitRequested(
        uint256 poolId,
        address champion,
        uint256 championEthDeposit,
        uint256 timestamp,
        uint256 bePoolId
    );
    event TicketIdSetForPool(uint256 poolId, uint256 nftTicketId);
    event HPoolStateChanged(uint256 poolId, PoolState newState);
    event Subscribed(
        uint256 poolId,
        address user,
        uint256 amountETH,
        uint256 numberOfTickets,
        SubscriptionRound sr
    );
    event TicketsWithdrawn(
        uint256 poolId,
        address user,
        uint256 numberOfTickets
    );
    event SubscriptionWithdrawn(
        uint256 poolId,
        address user,
        uint256 amountEth,
        uint256 numberOfTickets
    );
    event ServiceFeePaid(uint256 poolId, uint256 amount);
    event HPoolLaunchFailed(uint256 poolId);

    /**
     * @notice          Initializer function, can be called only once, replacing constructor
     * @param           _hordCongress is the address of HordCongress contract
     * @param           _maintainersRegistry is the address of the MaintainersRegistry contract
     */
    function initialize(
        address _hordCongress,
        address _maintainersRegistry,
        address _hordTicketFactory,
        address _hordTreasury,
        address _hordToken,
        address _hPoolFactory,
        address _chainlinkOracle,
        address _hordConfiguration
    ) external initializer {
        require(_hordCongress != address(0));
        require(_maintainersRegistry != address(0));
        require(_hordTicketFactory != address(0));
        require(_hordConfiguration != address(0));

        setCongressAndMaintainers(_hordCongress, _maintainersRegistry);
        hordTicketFactory = IHordTicketFactory(_hordTicketFactory);
        hordTreasury = IHordTreasury(_hordTreasury);
        hPoolFactory = IHPoolFactory(_hPoolFactory);
        hordToken = _hordToken;

        linkOracle = AggregatorV3Interface(_chainlinkOracle);
        hordConfiguration = IHordConfiguration(_hordConfiguration);
    }

    /**
     * @notice          Internal function to handle safe transferring of ETH.
     */
    function setLinkOracle(address _linkOracle)
    external
    {
        require(_linkOracle != address(0));
        linkOracle = AggregatorV3Interface(_linkOracle);
    }

    /**
     * @notice          Internal function to handle safe transferring of ETH.
     */
    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, "TransferHelper: ETH_TRANSFER_FAILED");
    }

    /**
     * @notice          Internal function to pay service to hord treasury contract
     */
    function payServiceFeeToTreasury(uint256 poolId, uint256 amount) internal {
        safeTransferETH(address(hordTreasury), amount);
        emit ServiceFeePaid(poolId, amount);
    }

    /**
     * @notice          Function where champion can create his pool.
     *                  In case champion is not approved, maintainer can cancel his pool creation,
     *                  and return him back the funds.
     */
    function createHPool(uint256 bePoolId) external payable {
        require(
            msg.value >= getMinimalETHToInitPool(),
            "ETH amount is less than minimal deposit."
        );

        // Create hPool structure
        hPool memory hp;

        hp.poolState = PoolState.PENDING_INIT;
        hp.championEthDeposit = msg.value;
        hp.championAddress = msg.sender;
        hp.createdAt = block.timestamp;

        // Compute ID to match position in array
        uint256 poolId = hPools.length;
        // Push hPool structure
        hPools.push(hp);

        // Add Id to list of ids for champion
        championAddressToHPoolIds[msg.sender].push(poolId);

        // Trigger events
        emit PoolInitRequested(
            poolId,
            msg.sender,
            msg.value,
            block.timestamp,
            bePoolId
        );
        emit HPoolStateChanged(poolId, hp.poolState);
    }

    /**
     * @notice          Function to set NFT for pool, which will at the same time validate the pool itself.
     * @param           poolId is the ID of the pool contract.
     */
    function setNftForPool(uint256 poolId, uint256 _nftTicketId)
        external
        onlyMaintainer
    {
        require(poolId < hPools.length, "hPool with poolId does not exist.");
        require(_nftTicketId > 0, "NFT id can not be 0.");
        require(_nftTicketId <= hordTicketFactory.lastMintedTokenId(), "NFT does not exist");

        hPool storage hp = hPools[poolId];

        require(!hp.isValidated, "hPool already validated.");
        require(
            hp.poolState == PoolState.PENDING_INIT,
            "Bad state transition."
        );

        hp.isValidated = true;
        hp.nftTicketId = _nftTicketId;
        hp.poolState = PoolState.TICKET_SALE;
        hp.endTicketSalePhase = block.timestamp + hordConfiguration.endTimeTicketSale();

        emit TicketIdSetForPool(poolId, hp.nftTicketId);
        emit HPoolStateChanged(poolId, hp.poolState);
    }

    /**
     * @notice          Function to start private subscription phase. Can be started only if previous
     *                  state of the hPool was TICKET_SALE.
     * @param           poolId is the ID of the pool contract.
     */
    function startPrivateSubscriptionPhase(uint256 poolId)
        external
        onlyMaintainer
    {
        require(poolId < hPools.length, "hPool with poolId does not exist.");

        hPool storage hp = hPools[poolId];

        require(hp.poolState == PoolState.TICKET_SALE);
        hp.poolState = PoolState.PRIVATE_SUBSCRIPTION;
        hp.endPrivateSubscriptionPhase = block.timestamp + hordConfiguration.endTimePrivateSubscription();

        emit HPoolStateChanged(poolId, hp.poolState);
    }

    /**
     * @notice          Function for users to subscribe for the hPool.
     */
    function privateSubscribeForHPool(uint256 poolId) external payable {
        hPool storage hp = hPools[poolId];
        require(
            hp.poolState == PoolState.PRIVATE_SUBSCRIPTION,
            "hPool is not in PRIVATE_SUBSCRIPTION state."
        );

        Subscription memory s = userToPoolIdToSubscription[msg.sender][poolId];
        require(s.amountEth == 0, "User can not subscribe more than once.");

        uint256 numberOfTicketsToUse = getRequiredNumberOfTicketsToUse(
            msg.value
        );
        require(numberOfTicketsToUse > 0);

        hordTicketFactory.safeTransferFrom(
            msg.sender,
            address(this),
            hp.nftTicketId,
            numberOfTicketsToUse,
            "0x0"
        );

        s.amountEth = msg.value;
        s.numberOfTickets = numberOfTicketsToUse;
        s.user = msg.sender;
        s.sr = SubscriptionRound.PRIVATE;

        // Store subscription
        poolIdToSubscriptions[poolId].push(s);
        userToPoolIdToSubscription[msg.sender][poolId] = s;
        userToPoolIdsSubscribedFor[msg.sender].push(poolId);
        usedTickets[poolId] = usedTickets[poolId].add(numberOfTicketsToUse);

        hp.followersEthDeposit = hp.followersEthDeposit.add(msg.value);

        emit Subscribed(
            poolId,
            msg.sender,
            msg.value,
            numberOfTicketsToUse,
            s.sr
        );
    }

    function startPublicSubscriptionPhase(uint256 poolId)
        external
        onlyMaintainer
    {
        require(poolId < hPools.length, "hPool with poolId does not exist.");

        hPool storage hp = hPools[poolId];

        uint256 maxTicketsToUse = getRequiredNumberOfTicketsToUse(hordConfiguration.maxFollowerUSDStake());

        require(block.timestamp >= hp.endPrivateSubscriptionPhase || usedTickets[poolId] < maxTicketsToUse);
        require(hp.poolState == PoolState.PRIVATE_SUBSCRIPTION);
        hp.poolState = PoolState.PUBLIC_SUBSCRIPTION;
        hp.endPublicSubscriptionSalePhase = block.timestamp + hordConfiguration.endTimePublicSubscription();

        emit HPoolStateChanged(poolId, hp.poolState);
    }

    /**
     * @notice          Function for users to subscribe for the hPool.
     */
    function publicSubscribeForHPool(uint256 poolId) external payable {
        hPool storage hp = hPools[poolId];
        require(
            hp.poolState == PoolState.PUBLIC_SUBSCRIPTION,
            "hPool is not in PUBLIC_SUBSCRIPTION state."
        );

        Subscription memory s = userToPoolIdToSubscription[msg.sender][poolId];
        require(s.amountEth == 0, "User can not subscribe more than once.");

        s.amountEth = msg.value;
        s.numberOfTickets = 0;
        s.user = msg.sender;
        s.sr = SubscriptionRound.PUBLIC;

        hp.followersEthDeposit = hp.followersEthDeposit.add(msg.value);

        // Store subscription
        poolIdToSubscriptions[poolId].push(s);
        userToPoolIdToSubscription[msg.sender][poolId] = s;
        userToPoolIdsSubscribedFor[msg.sender].push(poolId);

        emit Subscribed(poolId, msg.sender, msg.value, 0, s.sr);
    }

    /**
     * @notice          Maintainer should end subscription phase in case all the criteria is reached
     */
    function endSubscriptionPhaseAndInitHPool(uint256 poolId, string memory name, string memory symbol)
        external
        onlyMaintainer
    {
        hPool storage hp = hPools[poolId];
        require(
            hp.poolState == PoolState.PUBLIC_SUBSCRIPTION,
            "hPool is not in subscription state."
        );
        require(
            hp.followersEthDeposit >= getMinSubscriptionToLaunchInETH(),
            "hPool subscription amount is below threshold."
        );

        hp.poolState = PoolState.ASSET_STATE_TRANSITION_IN_PROGRESS;

        // Deploy the HPool contract
        IHPool hpContract = IHPool(hPoolFactory.deployHPool(poolId));

        //Mint HPoolToken for certain HPool
        hpContract.mintHPoolToken(name, symbol, hordConfiguration.totalSupplyHPoolTokens());

        // Set the deployed address of hPool
        hp.hPoolContractAddress = address(hpContract);

        uint256 treasuryFeeETH = hp
            .followersEthDeposit
            .mul(hordConfiguration.gasUtilizationRatio())
            .div(hordConfiguration.percentPrecision());

        payServiceFeeToTreasury(poolId, treasuryFeeETH);

        hpContract.depositBudgetFollowers{
            value: hp.followersEthDeposit.sub(treasuryFeeETH)
        }();
        hpContract.depositBudgetChampion{value: hp.championEthDeposit}();

        hp.treasuryFeePaid = treasuryFeeETH;

        // Trigger event that pool state is changed
        emit HPoolStateChanged(poolId, hp.poolState);
    }

    function endSubscriptionPhaseAndTerminatePool(uint256 poolId)
        external
        onlyMaintainer
    {
        hPool storage hp = hPools[poolId];

        require(
            hp.poolState == PoolState.PUBLIC_SUBSCRIPTION,
            "hPool is not in subscription state."
        );
        require(
            hp.followersEthDeposit < getMinSubscriptionToLaunchInETH(),
            "hPool subscription amount is above threshold."
        );

        // Set new pool state
        hp.poolState = PoolState.SUBSCRIPTION_FAILED;

        // Trigger event
        emit HPoolStateChanged(poolId, hp.poolState);
        emit HPoolLaunchFailed(poolId);
    }

    function withdrawDeposit(uint256 poolId) public {
        hPool storage hp = hPools[poolId];
        Subscription storage s = userToPoolIdToSubscription[msg.sender][poolId];

        require(
            hp.poolState == PoolState.SUBSCRIPTION_FAILED,
            "Pool is not in valid state."
        );
        require(
            !s.isSubscriptionWithdrawnPoolTerminated,
            "Subscription already withdrawn"
        );

        if (s.numberOfTickets > 0) {
            hordTicketFactory.safeTransferFrom(
                address(this),
                msg.sender,
                hp.nftTicketId,
                s.numberOfTickets,
                "0x0"
            );
        }

        // Transfer subscription back to user
        safeTransferETH(msg.sender, s.amountEth);
        // Mark that user withdrawn his subscription.
        s.isSubscriptionWithdrawnPoolTerminated = true;
        // Fire SubscriptionWithdrawn event
        emit SubscriptionWithdrawn(
            poolId,
            msg.sender,
            s.amountEth,
            s.numberOfTickets
        );
        // Mark that user taken all tickets
        s.numberOfTickets = 0;
    }

    /**
     * @notice          Function to withdraw tickets. It can be called whenever after subscription phase.
     * @param           poolId is the ID of the pool for which user is withdrawing.
     */
    function withdrawTickets(uint256 poolId) public {
        hPool storage hp = hPools[poolId];
        Subscription storage s = userToPoolIdToSubscription[msg.sender][poolId];

        require(s.amountEth > 0, "User did not participate in this hPool.");
        require(
            s.numberOfTickets > 0,
            "User have already withdrawn his tickets."
        );
        require(
            uint256(hp.poolState) > 3,
            "Only after Subscription phase user can withdraw tickets."
        );

        hordTicketFactory.safeTransferFrom(
            address(this),
            msg.sender,
            hp.nftTicketId,
            s.numberOfTickets,
            "0x0"
        );

        // Trigger event that user have withdrawn tickets
        emit TicketsWithdrawn(poolId, msg.sender, s.numberOfTickets);

        // Remove users tickets.
        s.numberOfTickets = 0;
    }

    /**
     * @notice          Function to get minimal amount of ETH champion needs to
     *                  put in, in order to create hPool.
     * @return         Amount of ETH (in WEI units)
     */
    function getMinimalETHToInitPool() public view returns (uint256) {
        uint256 latestPrice = uint256(getLatestPrice());
        uint256 usdEThRate = one.mul(one).div(latestPrice);
        return usdEThRate.mul(hordConfiguration.minChampStake()).div(one);
    }

    /**
     * @notice          Function to get maximal amount of ETH user can subscribe with
     *                  per 1 access ticket
     * @return         Amount of ETH (in WEI units)
     */
    function getMaxSubscriptionInETHPerTicket() public view returns (uint256) {
        uint256 latestPrice = uint256(getLatestPrice());
        uint256 usdEThRate = one.mul(one).div(latestPrice);
        return
            usdEThRate.mul(hordConfiguration.maxUSDAllocationPerTicket()).div(
                one
            );
    }

    /**
     * @notice          Function to get minimal subscription in ETH so pool can launch
     */
    function getMinSubscriptionToLaunchInETH() public view returns (uint256) {
        uint256 latestPrice = uint256(getLatestPrice());
        uint256 usdEThRate = one.mul(one).div(latestPrice);
        return usdEThRate.mul(hordConfiguration.minFollowerUSDStake()).div(one);
    }

    /**
     * @notice          Function to fetch the latest price of the stored oracle.
     */
    function getLatestPrice() public view returns (int256) {
        (, int256 price, , , ) = linkOracle.latestRoundData();
        return price;
    }

    /**
     * @notice          Function to fetch on how many decimals is the response
     */
    function getDecimalsReturnPrecision() public view returns (uint8) {
        return linkOracle.decimals();
    }

    /**
     * @notice          Function to convert USD to ETH.
     */
    function convertUSDtoETH(uint256 amount)
    external
    view
    returns
    (uint256)
    {
        uint256 latestPrice = uint256(getLatestPrice());
        uint256 usdEThRate = one.div(latestPrice);
        return usdEThRate;
    }

    /**
     * @notice          Function to get IDs of all pools for the champion.
     */
    function getChampionPoolIds(address champion)
        external
        view
        returns (uint256[] memory)
    {
        return championAddressToHPoolIds[champion];
    }

    /**
     * @notice          Function to get IDs of pools for which user subscribed
     */
    function getPoolsUserSubscribedFor(address user)
        external
        view
        returns (uint256[] memory)
    {
        return userToPoolIdsSubscribedFor[user];
    }

    /**
     * @notice          Function to compute how much user can currently subscribe in ETH for the hPool.
     */
    function getMaxUserSubscriptionInETH(address user, uint256 poolId)
        external
        view
        returns (uint256)
    {
        hPool memory hp = hPools[poolId];

        Subscription memory s = userToPoolIdToSubscription[user][poolId];

        if (s.amountEth > 0) {
            // User already subscribed, can subscribe only once.
            return 0;
        }

        uint256 numberOfTickets = hordTicketFactory.balanceOf(
            user,
            hp.nftTicketId
        );
        uint256 maxUserSubscriptionPerTicket = getMaxSubscriptionInETHPerTicket();

        return numberOfTickets.mul(maxUserSubscriptionPerTicket);
    }

    /**
     * @notice          Function to return required number of tickets for user to use in order to subscribe
     *                  with selected amount
     * @param           subscriptionAmount is the amount of ETH user wants to subscribe with.
     */
    function getRequiredNumberOfTicketsToUse(uint256 subscriptionAmount)
        public
        view
        returns (uint256)
    {
        uint256 maxParticipationPerTicket = getMaxSubscriptionInETHPerTicket();
        uint256 amountOfTicketsToUse = (subscriptionAmount).div(
            maxParticipationPerTicket
        );

        if (
            subscriptionAmount.mul(maxParticipationPerTicket) <
            amountOfTicketsToUse
        ) {
            amountOfTicketsToUse++;
        }

        return amountOfTicketsToUse;
    }

    /**
     * @notice          Function to get all subscribed addresses on one hPool
     */
    function getSubscribedAddresses(uint256 poolId)
    external
    view
    returns (address[] memory)
    {
        address[] memory subscribedAddresses = new address[](poolIdToSubscriptions[poolId].length);

        for (uint256 i = 0; i < poolIdToSubscriptions[poolId].length; i++) {
            subscribedAddresses[i] = poolIdToSubscriptions[poolId][i].user;
        }

        return subscribedAddresses;
    }

    function getUsedTickets(uint256 poolId)
    external
    view
    returns (uint256)
    {
        return usedTickets[poolId];
    }

    /**
     * @notice          Function to get AggregatorV3Interface
     */
    function getLinkOracle()
    external
    view
    returns (AggregatorV3Interface)
    {
        return linkOracle;
    }

    /**
     * @notice          Function to get user subscription for the pool.
     * @param           poolId is the ID of the pool
     * @param           user is the address of user
     * @return          amount of ETH user deposited and number of tickets taken from user.
     */
    function getUserSubscriptionForPool(uint256 poolId, address user)
        external
        view
        returns (uint256, uint256)
    {
        Subscription memory subscription = userToPoolIdToSubscription[user][
            poolId
        ];

        return (subscription.amountEth, subscription.numberOfTickets);
    }

    /**
     * @notice          Function to get information for specific pool
     * @param           poolId is the ID of the pool
     */
    function getPoolInfo(uint256 poolId)
        external
        view
        returns (
            uint256,
            uint256,
            address,
            uint256,
            uint256,
            bool,
            uint256,
            address,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        // Load pool into memory
        hPool memory hp = hPools[poolId];

        return (
            uint256(hp.poolState),
            hp.championEthDeposit,
            hp.championAddress,
            hp.createdAt,
            hp.nftTicketId,
            hp.isValidated,
            hp.followersEthDeposit,
            hp.hPoolContractAddress,
            hp.treasuryFeePaid,
            hp.endTicketSalePhase,
            hp.endPrivateSubscriptionPhase,
            hp.endPublicSubscriptionSalePhase
        );
    }
}
