pragma solidity 0.6.12;

import "./interfaces/IERC20.sol";
import "./system/HordUpgradable.sol";
import "./interfaces/IHordTicketFactory.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155HolderUpgradeable.sol";
import "./libraries/SafeMath.sol";

/**
 * HordTicketManager contract.
 * @author Nikola Madjarevic
 * Date created: 11.5.21.
 * Github: madjarevicn
 */
contract HordTicketManager is HordUpgradable, ERC1155HolderUpgradeable {
    using SafeMath for *;
    // Minimal time to stake in order to be eligible for claiming NFT
    uint256 public minTimeToStake;
    // Minimal amount to stake in order to be eligible for claiming NFT
    uint256 public minAmountToStake;
    // Token being staked
    IERC20 public stakingToken;
    // Factory of Hord tickets
    IHordTicketFactory public hordTicketFactory;
    // Mapping championId to tokenIds
    mapping (uint256 => uint256[]) internal championIdToMintedTokensIds;

    // Users stake
    struct UserStake {
        uint256 amountStaked;
        uint256 amountOfTicketsGetting;
        uint256 unlockingTime;
        bool isWithdrawn;
    }

    /// @dev Mapping user address to tokenId to stakes for that token
    mapping(address => mapping(uint => UserStake[])) public addressToTokenIdToStakes;

    // Count number of reserved tickets for tokenId
    mapping(uint256 => uint256) internal tokenIdToNumberOfTicketsReserved;

    event TokensStaked(
        address user,
        uint amountStaked,
        uint inFavorOfTokenId,
        uint numberOfTicketsReserved,
        uint unlockingTime
    );

    event NFTsClaimed(
        address beneficiary,
        uint256 amountUnstaked,
        uint256 amountTicketsClaimed,
        uint tokenId
    );

    function initialize(
        address _hordCongress,
        address _maintainersRegistry,
        address _stakingToken,
        uint256 _minTimeToStake,
        uint256 _minAmountToStake
    )
    public
    initializer
    {
        // Set hord congress and maintainers registry
        setCongressAndMaintainers(_hordCongress, _maintainersRegistry);
        // Set staking token
        stakingToken = IERC20(_stakingToken);
        // Set minimal time to stake tokens
        minTimeToStake = _minTimeToStake;
        // Set minimal amount to stake
        minAmountToStake = _minAmountToStake;
    }

    /**
     * @notice  Set hord ticket factory contract. After set first time,
     *          can be changed only by HordCongress
     * @param _hordTicketFactory is the address of HordTicketFactory contract
     */
    function setHordTicketFactory(address _hordTicketFactory) public {
        // Initial setting is allowed during deployment, after that only congress can change it
        if(address(hordTicketFactory) != address(0)) {
            require(msg.sender == hordCongress);
        }
        // Set hord ticket factory
        hordTicketFactory = IHordTicketFactory(_hordTicketFactory);
    }

    /**
     * @notice  Set minimal time to stake, callable only by HordCongress
     * @param   _minimalTimeToStake is minimal amount of time (seconds) user has to stake
     *          staking token in order to be eligible to claim NFT
     */
    function setMinTimeToStake(
        uint256 _minimalTimeToStake
    )
    onlyHordCongress
    external
    {
        minTimeToStake = _minimalTimeToStake;
    }

    /**
     * @notice  Set minimal amount to stake, callable only by HordCongress
     * @param   _minimalAmountToStake is minimal amount of tokens (WEI) user has to stake
     *          in order to be eligible to claim NFT
     */
    function setMinAmountToStake(
        uint256 _minimalAmountToStake
    )
    onlyHordCongress
    external
    {
        minAmountToStake = _minimalAmountToStake;
    }

    /**
     * @notice  Map token id with champion id
     * @param   tokenId is the ID of the token (representing token class / series)
     * @param   championId is the ID of the champion
     */
    function addNewTokenIdForChampion(
        uint tokenId,
        uint championId
    )
    external
    {
        require(msg.sender == address(hordTicketFactory), "Only Hord Ticket factory can issue a call to this function");
        // Push token Id to champion id
        championIdToMintedTokensIds[championId].push(tokenId);
    }

    /**
     * @notice  Stake and reserve NFTs, per specific staking rules
     * @param   tokenId is the ID of the token being staked (class == series)
     * @param   numberOfTickets is representing how many NFTs of same series user wants to get
     */
    function stakeAndReserveNFTs(
        uint tokenId,
        uint numberOfTickets
    )
    public
    {
        // Get number of reserved tickets
        uint256 numberOfTicketsReserved = tokenIdToNumberOfTicketsReserved[tokenId];
        // Check there's enough tickets to get
        require(numberOfTicketsReserved.add(numberOfTickets)<= hordTicketFactory.getTokenSupply(tokenId),
            "Not enough tickets to sell.");

        // Fixed stake per ticket
        uint amountOfTokensToStake = minAmountToStake.mul(numberOfTickets);

        // Transfer tokens from user
        stakingToken.transferFrom(
            msg.sender,
            address(this),
            amountOfTokensToStake
        );

        UserStake memory userStake = UserStake({
            amountStaked: amountOfTokensToStake,
            amountOfTicketsGetting: numberOfTickets,
            unlockingTime: minTimeToStake.add(block.timestamp),
            isWithdrawn: false
        });

        addressToTokenIdToStakes[msg.sender][tokenId].push(userStake);

        // Increase number of tickets reserved
        tokenIdToNumberOfTicketsReserved[tokenId] = numberOfTicketsReserved.add(numberOfTickets);

        emit TokensStaked(
            msg.sender,
            amountOfTokensToStake,
            tokenId,
            numberOfTickets,
            userStake.unlockingTime
        );

        claimNFTsImmediately(numberOfTickets, tokenId);

    }

    function claimNFTsImmediately(uint256 numberOfTickets, uint256 tokenId) private {

        hordTicketFactory.safeTransferFrom(
            address(this),
            msg.sender,
            tokenId,
            numberOfTickets,
            "0x0"
        );

        emit NFTsClaimed(
            msg.sender,
            0,
            numberOfTickets,
            tokenId
        );

    }

    /**
     * @notice  Function to claim NFTs and withdraw tokens staked for that NFTs
     * @param   tokenId is representing token class for which user has performed stake
     */
    function claimNFTs(
        uint tokenId,
        uint startIndex,
        uint endIndex
    )
    public
    {
        UserStake [] storage userStakesForNft = addressToTokenIdToStakes[msg.sender][tokenId];

        uint256 totalStakeToWithdraw;

        uint256 i = startIndex;
        while (i < userStakesForNft.length && i < endIndex) {
            UserStake storage stake = userStakesForNft[i++];

            if(stake.isWithdrawn || stake.unlockingTime > block.timestamp) {
                continue;
            }

            totalStakeToWithdraw = totalStakeToWithdraw.add(stake.amountStaked);

            stake.isWithdrawn = true;
        }

        if(totalStakeToWithdraw > 0) {

            // Transfer staking tokens
            stakingToken.transfer(msg.sender, totalStakeToWithdraw);

            // Emit event
            emit NFTsClaimed(
                msg.sender,
                totalStakeToWithdraw,
                0,
                tokenId
            );
        }
    }

    /**
     * @notice  Get number of specific tokens claimed
     * @param   tokenId is the subject of search
     */
    function getAmountOfTokensClaimed(uint tokenId)
    external
    view
    returns (uint256)
    {
        uint mintedSupply = hordTicketFactory.getTokenSupply(tokenId);
        return mintedSupply.sub(hordTicketFactory.balanceOf(address(this), tokenId));
    }

    /**
     * @notice  Get amount of tickets reserved for selected tokenId
     * @param   tokenId is the subject of search
     */
    function getAmountOfTicketsReserved(
        uint tokenId
    )
    external
    view
    returns (uint256)
    {
        return tokenIdToNumberOfTicketsReserved[tokenId];
    }

    /**
     * @notice  Get account stakes for specified token Id
     * @param   account is user address
     * @param   tokenId is the id of the token in favor of which stake is made.
     */
    function getUserStakesForTokenId(
        address account,
        uint tokenId
    )
    external
    view
    returns (
        uint256[] memory,
        uint256[] memory,
        uint256[] memory,
        bool[] memory
    )
    {
        UserStake [] memory userStakes = addressToTokenIdToStakes[account][tokenId];

        uint numberOfStakes = userStakes.length;

        uint256[] memory amountsStaked = new uint256[](numberOfStakes);
        uint256[] memory ticketsBought = new uint256[](numberOfStakes);
        uint256[] memory unlockingTimes = new uint256[](numberOfStakes);
        bool[] memory isWithdrawn = new bool[](numberOfStakes);

        for(uint i = 0; i < numberOfStakes; i++) {
            // Fulfill arrays with stake information
            amountsStaked[i] = userStakes[i].amountStaked;
            ticketsBought[i] = userStakes[i].amountOfTicketsGetting;
            unlockingTimes[i] = userStakes[i].unlockingTime;
            isWithdrawn[i] = userStakes[i].isWithdrawn;
        }

        return (amountsStaked, ticketsBought, unlockingTimes, isWithdrawn);
    }

    /**
     * @notice  Get currently how many tokens is account actively staking
     * @param   account is address for which stakes are being checked
     * @param   tokenId is the subject of search for the passed account
     */
    function getCurrentAmountStakedForTokenId(
        address account,
        uint tokenId
    )
    external
    view
    returns (uint256)
    {
        UserStake [] memory userStakes = addressToTokenIdToStakes[account][tokenId];

        uint numberOfStakes = userStakes.length;
        uint amountCurrentlyStaking = 0;

        for(uint i = 0; i < numberOfStakes; i++) {
            if(userStakes[i].isWithdrawn == false) {
                amountCurrentlyStaking = amountCurrentlyStaking.add(userStakes[i].amountStaked);
            }
        }

        return amountCurrentlyStaking;
    }

    /**
     * @notice  Function to get all token ids minted for specific champion
     * @param   championId is the db id of the champion
     */
    function getChampionTokenIds(
        uint championId
    )
    external
    view
    returns (uint[] memory)
    {
        return championIdToMintedTokensIds[championId];
    }

    /**
     * @notice  Function to get number of stakes for user and token
     * @param   user is the address of selected user
     * @param   tokenId is the ID of the token
     */
    function getNumberOfStakesForUserAndToken(
        address user,
        uint tokenId
    )
    external
    view
    returns (uint256)
    {
        return addressToTokenIdToStakes[user][tokenId].length;
    }
}