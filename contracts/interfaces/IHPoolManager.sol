pragma solidity 0.6.12;

/**
 * IHPoolManager contract.
 * @author Nikola Madjarevic
 * Date created: 20.7.21.
 * Github: madjarevicn
 */
interface IHPoolManager {
    function getPoolInfo(uint256 poolId) external view returns (uint256, uint256, address, uint256, uint256, bool, uint256, address, uint256);
    function getUserSubscriptionForPool(uint256 poolId, address user) external view returns (uint256, uint256);
}
