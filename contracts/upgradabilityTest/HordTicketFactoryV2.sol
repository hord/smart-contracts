//"SPDX-License-Identifier: UNLICENSED"
pragma solidity ^0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155PausableUpgradeable.sol";
import "../interfaces/IHordTicketManager.sol";
import "../system/HordUpgradable.sol";

/**
 * HordTicketManager contract.
 * @author Nikola Madjarevic
 * Date created: 8.5.21.
 * Github: madjarevicn
 */
contract HordTicketFactoryV2 is HordUpgradable, ERC1155PausableUpgradeable {

    // Store always last ID minted
    uint256 public lastMintedTokenId;
    // Maximal number of fungible tickets per Pool
    uint256 public maxFungibleTicketsPerPool;
    // Mapping token ID to minted supply
    mapping (uint256 => uint256) tokenIdToMintedSupply;

    // Manager contract handling tickets
    IHordTicketManager public hordTicketManager;


    event MintedNewNFT (
        uint256 tokenId,
        uint256 championId,
        uint256 initialSupply
    );

    event AddedNFTSupply(
        uint256 tokenId,
        uint256 supplyAdded
    );

    function initialize(
        address _hordCongress,
        address _maintainersRegistry,
        address _hordTicketManager,
        uint256 _maxFungibleTicketsPerPool,
        string memory _uri   // https://api.hord.app/metadata/ticket_manager  (for test: https://test-api.hord.app/metadata/ticket_manager)
    )
    public
    initializer
    {
        __ERC1155_init(_uri);

        // Set hord congress and maintainers registry contract
        setCongressAndMaintainers(_hordCongress, _maintainersRegistry);
        // Set hord ticket manager contract
        hordTicketManager = IHordTicketManager(_hordTicketManager);
        // Set max fungible tickets allowed to mint per pool
        maxFungibleTicketsPerPool = _maxFungibleTicketsPerPool;
    }

    /**
     * @notice  Function allowing congress to pause the smart-contract
     * @dev     Can be only called by HordCongress
     */
    function pause()
    public
    onlyHordCongress
    {
        _pause();
    }

    /**
     * @notice  Function allowing congress to unpause the smart-contract
     * @dev     Can be only called by HordCongress
     */
    function unpause()
    public
    onlyHordCongress
    {
        _unpause();
    }

    /**
     * @notice Set maximal fungible tickets possible to mint per pool (pool == class == tokenId)
     */
    function setMaxFungibleTicketsPerPool(
        uint _maxFungibleTicketsPerPool
    )
    external
    onlyHordCongress
    {
        require(_maxFungibleTicketsPerPool > 0);
        maxFungibleTicketsPerPool = _maxFungibleTicketsPerPool;
    }

    /**
     * @notice Mint new HPool NFT token.
     */
    function mintNewHPoolNFT(
        uint256 tokenId,
        uint256 initialSupply,
        uint256 championId
    )
    public
    onlyMaintainer
    {
        require(initialSupply <= maxFungibleTicketsPerPool, "MintNewHPoolNFT: Initial supply overflow.");
        require(tokenId == lastMintedTokenId.add(1), "MintNewHPoolNFT: Token ID is wrong.");

        // Set initial supply
        tokenIdToMintedSupply[tokenId] = initialSupply;

        // Mint tokens and store them on contract itself
        _mint(address(hordTicketManager), tokenId, initialSupply, "0x0");

        // Fire event
        emit MintedNewNFT(tokenId, championId, initialSupply);

        // Map champion id with token id
        hordTicketManager.addNewTokenIdForChampion(tokenId, championId);

        // Store always last minted token id.
        lastMintedTokenId = tokenId;
    }


    /**
     * @notice  Add supply to existing token
     */
    function addTokenSupply()
    public
    pure
    returns (string memory)
    {
        string memory str = "This was used to add supply in V1";
        return str;
    }


    /**
     * @notice  Get total supply minted for tokenId
     */
    function getTokenSupply(
        uint tokenId
    )
    external
    view
    returns (uint256)
    {
        return tokenIdToMintedSupply[tokenId];
    }

    function sayIamUpgradedVersion()
    public
    pure
    returns (string memory)
    {
        string memory str = "I am Upgraded to V2";
        return str;
    }
}
