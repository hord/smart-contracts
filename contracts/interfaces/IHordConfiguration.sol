pragma solidity 0.6.12;

/**
 * IHordConfiguration contract.
 * @author Nikola Madjarevic
 * Date created: 4.8.21.
 * Github: madjarevicn
 */
interface IHordConfiguration {
    function minChampStake() external view returns(uint256);
    function maxWarmupPeriod() external view returns(uint256);
    function maxFollowerOnboardPeriod() external view returns(uint256);
    function minFollowerUSDStake() external view returns(uint256);
    function maxFollowerUSDStake() external view returns(uint256);
    function minStakePerPoolTicket() external view returns(uint256);
    function assetUtilizationRatio() external view returns(uint256);
    function gasUtilizationRatio() external view returns(uint256);
    function platformStakeRatio() external view returns(uint256);
    function percentPrecision() external view returns(uint256);
    function maxSupplyHPoolToken() external view returns(uint256);
    function maxUSDAllocationPerTicket() external view returns (uint256);
    function totalSupplyHPoolTokens() external view returns (uint256);
    function endTimeTicketSale() external view returns (uint256);
    function endTimePrivateSubscription() external view returns (uint256);
    function endTimePublicSubscription() external view returns (uint256);
}
