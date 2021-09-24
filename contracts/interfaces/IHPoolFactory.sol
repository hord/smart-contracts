pragma solidity 0.6.12;

/**
 * IHPoolFactory contract.
 * @author Nikola Madjarevic
 * Date created: 29.7.21.
 * Github: madjarevicn
 */
interface IHPoolFactory {
    function deployHPool(uint256 hPoolId) external returns (address);
}
