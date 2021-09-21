pragma solidity 0.6.12;

/**
 * IHPool contract.
 * @author Nikola Madjarevic
 * Date created: 29.7.21.
 * Github: madjarevicn
 */
interface IHPool {
    function depositBudgetFollowers() external payable;
    function depositBudgetChampion() external payable;
    function mintHPoolToken(string memory name, string memory symbol, uint256 _totalSupply) external;
}
