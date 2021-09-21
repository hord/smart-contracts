pragma solidity 0.6.12;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import "../system/HordUpgradable.sol";
import "../interfaces/IHPoolManager.sol";
import "./HPoolToken.sol";
import "../libraries/SafeMath.sol";

/**
 * HPool contract.
 * @author Nikola Madjarevic
 * Date created: 20.7.21.
 * Github: madjarevicn
 */
contract HPool is HordUpgradable, HPoolToken {

    using SafeMath for uint256;

    IHPoolManager public hPoolManager;
    IUniswapV2Router01 public uniswapRouter;

    uint256 public hPoolId;
    bool public isHPoolTokenMinted;
    mapping(address => bool) public didUserClaimHPoolTokens;
    mapping(address => uint256) public amountOfTokens;
    address[] public hPoolTokensHolders;

    event FollowersBudgetDeposit(uint256 amount);
    event ChampionBudgetDeposit(uint256 amount);
    event HPoolTokenMinted(string name, string symbol, uint256 totalSupply);
    event ClaimedHPoolTokens(address beneficiary, uint256 numberOfClaimedTokens);

    modifier onlyHPoolManager {
        require(msg.sender == address(hPoolManager), "Restricted only to HPoolManager.");
        _;
    }

    constructor(
        uint256 _hPoolId,
        address _hordCongress,
        address _hordMaintainersRegistry,
        address _hordPoolManager,
        address _uniswapRouter
    )
    public
    {
        setCongressAndMaintainers(_hordCongress, _hordMaintainersRegistry);
        hPoolId = _hPoolId;
        hPoolManager = IHPoolManager(_hordPoolManager);
        uniswapRouter = IUniswapV2Router01(_uniswapRouter);
    }

    function depositBudgetFollowers()
    external
    onlyHPoolManager
    payable
    {
        emit FollowersBudgetDeposit(msg.value);
    }

    function depositBudgetChampion()
    external
    onlyHPoolManager
    payable
    {
        emit ChampionBudgetDeposit(msg.value);
    }

    function mintHPoolToken(
        string memory name,
        string memory symbol,
        uint256 _totalSupply
    )
    external
    onlyHPoolManager
    {
        require(!isHPoolTokenMinted, "HPoolToken can be minted only once.");
        // Mark that token is minted.
        isHPoolTokenMinted = true;
        // Initially all HPool tokens are minted on the pool level
        createToken(name, symbol, _totalSupply, address(this));
        // Trigger even that hPool token is minted
        emit HPoolTokenMinted(name, symbol, _totalSupply);
    }

    function claimHPoolTokens()
    external
    {
        require(!didUserClaimHPoolTokens[msg.sender], "Follower already withdraw tokens.");

        uint256 numberOfTokensToClaim = getNumberOfTokensUserCanClaim(msg.sender);
        _transfer(address(this), msg.sender, numberOfTokensToClaim);

        didUserClaimHPoolTokens[msg.sender] = true;
        hPoolTokensHolders.push(msg.sender);

        emit ClaimedHPoolTokens(msg.sender, numberOfTokensToClaim);
    }

    function swapExactTokensForEth(
        address token,
        uint amountIn,
        uint amountOutMin,
        uint deadline
    )
    external
    {
        require(msg.sender.balance >= amountIn);
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = uniswapRouter.WETH();

        uint256[] memory amounts = uniswapRouter.swapExactTokensForETH(
            amountIn,
            amountOutMin,
            path,
            msg.sender,
            deadline
        );

        amountOfTokens[token] = amountOfTokens[token] - amounts[0];
        amountOfTokens[path[1]] = amountOfTokens[path[1]] + amounts[1];
    }


    function swapExactEthForTokens(
        address token,
        uint amountOutMin,
        uint deadline
    )
    external
    payable
    {
        require(msg.value > 0, "ETH amount is less than minimum amount.");
        address[] memory path = new address[](2);
        path[0] = uniswapRouter.WETH();
        path[1] = token;

        uint256[] memory amounts = uniswapRouter.swapExactETHForTokens(
            amountOutMin,
            path,
            msg.sender,
            deadline
        );

        amountOfTokens[path[0]] = amountOfTokens[path[0]] - amounts[0];
        amountOfTokens[token] = amountOfTokens[token] + amounts[1];
    }

    function swapExactTokensForTokens(
        address tokenA,
        address tokenB,
        uint amountIn,
        uint amountOutMin,
        uint deadline
    )
    external
    {
        require(msg.sender.balance >= amountIn);
        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;

        uint256[] memory amounts = uniswapRouter.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            msg.sender,
            deadline
        );

        amountOfTokens[tokenA] = amountOfTokens[tokenA] - amounts[0];
        amountOfTokens[tokenB] = amountOfTokens[tokenB] + amounts[1];
    }

    function getNumberOfTokensUserCanClaim(address follower)
    public
    view
    returns (uint256)
    {

        if(didUserClaimHPoolTokens[follower]) {
            return 0;
        }

        (uint256 subscriptionETHUser, ) = hPoolManager.getUserSubscriptionForPool(hPoolId, follower);
        (, , , , , , uint256 totalFollowerDeposit, , ) = hPoolManager.getPoolInfo(hPoolId);

        uint256 tokensForClaiming = subscriptionETHUser.mul(totalSupply()).div(totalFollowerDeposit);
        return tokensForClaiming;
    }

}
