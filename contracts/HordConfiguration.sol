pragma solidity 0.6.12;

import "./system/HordUpgradable.sol";
import "@openzeppelin/contracts/proxy/Initializable.sol";

/**
 * HordConfiguration contract.
 * @author Nikola Madjarevic
 * Date created: 4.8.21.
 * Github: madjarevicn
 */
contract HordConfiguration is HordUpgradable, Initializable {
    // Stating minimal champion stake in USD in order to launch pool
    uint256 private _minChampStake;
    // Maximal warmup period
    uint256 private _maxWarmupPeriod;
    // Time for followers to stake and reach MIN/MAX follower etf stake
    uint256 private _maxFollowerOnboardPeriod;
    // Minimal ETH stake followers should reach together, in USD
    uint256 private _minFollowerUSDStake;
    // Maximal ETH stake followers should reach together, in USD
    uint256 private _maxFollowerUSDStake;
    // Minimal Stake per pool ticket
    uint256 private _minStakePerPoolTicket;
    // Percent used for purchasing underlying assets
    uint256 private _assetUtilizationRatio;
    // Percent for covering gas fees for hPool operations
    uint256 private _gasUtilizationRatio;
    // Representing % of HORD necessary in every pool
    uint256 private _platformStakeRatio;
    // Representing decimals precision for %, defaults to 100
    uint256 private _percentPrecision;
    //
    uint256 private _maxSupplyHPoolToken;
    // Representing maximal USD allocation per ticket
    uint256 private _maxUSDAllocationPerTicket;
    //Total supply for HPoolToken
    uint256 private _totalSupplyHPoolTokens;
    //End time for TICKET_SALE phase
    uint256 private _endTimeTicketSale;
    //End time for PRIVATE_SUBSCRIPTION phase
    uint256 private _endTimePrivateSubscription;
    //End time for PUBLIC_SUBSCRIPTION phase
    uint256 private _endTimePublicSubscription;

    event ConfigurationChanged(string parameter, uint256 newValue);

    /**
     * @notice          Initializer function
     */
    function initialize(
        address hordCongress_,
        address maintainersRegistry_,
        uint256 minChampStake_,
        uint256 maxWarmupPeriod_,
        uint256 maxFollowerOnboardPeriod_,
        uint256 minFollowerUSDStake_,
        uint256 maxFollowerUSDStake_,
        uint256 minStakePerPoolTicket_,
        uint256 assetUtilizationRatio_,
        uint256 gasUtilizationRatio_,
        uint256 platformStakeRatio_,
        uint256 maxSupplyHPoolToken_,
        uint256 maxUSDAllocationPerTicket_,
        uint256 totalSupplyHPoolTokens_
    ) external initializer {
        // Set hord congress and maintainers registry
        setCongressAndMaintainers(hordCongress_, maintainersRegistry_);

        _minChampStake = minChampStake_;
        _maxWarmupPeriod = maxWarmupPeriod_;
        _maxFollowerOnboardPeriod = maxFollowerOnboardPeriod_;
        _minFollowerUSDStake = minFollowerUSDStake_;
        _maxFollowerUSDStake = maxFollowerUSDStake_;
        _minStakePerPoolTicket = minStakePerPoolTicket_;
        _assetUtilizationRatio = assetUtilizationRatio_;
        _gasUtilizationRatio = gasUtilizationRatio_;
        _platformStakeRatio = platformStakeRatio_;
        _maxSupplyHPoolToken = maxSupplyHPoolToken_;
        _maxUSDAllocationPerTicket = maxUSDAllocationPerTicket_;
        _totalSupplyHPoolTokens = totalSupplyHPoolTokens_;

        _percentPrecision = 100;
    }

    // Setter Functions
    // _minChampStake setter function
    function setMinChampStake(uint256 minChampStake_)
        external
        onlyHordCongress
    {
        _minChampStake = minChampStake_;
        emit ConfigurationChanged("_minChampStake", _minChampStake);
    }

    // _maxWarmupPeriod setter function
    function setMaxWarmupPeriod(uint256 maxWarmupPeriod_)
        external
        onlyHordCongress
    {
        _maxWarmupPeriod = maxWarmupPeriod_;
        emit ConfigurationChanged("_maxWarmupPeriod", _maxWarmupPeriod);
    }

    // _maxFollowerOnboardPeriod setter function
    function setMaxFollowerOnboardPeriod(uint256 maxFollowerOnboardPeriod_)
        external
        onlyHordCongress
    {
        _maxFollowerOnboardPeriod = maxFollowerOnboardPeriod_;
        emit ConfigurationChanged(
            "_maxFollowerOnboardPeriod",
            _maxFollowerOnboardPeriod
        );
    }

    // _minFollowerUSDStake setter function
    function setMinFollowerUSDStake(uint256 minFollowerUSDStake_)
        external
        onlyHordCongress
    {
        _minFollowerUSDStake = minFollowerUSDStake_;
        emit ConfigurationChanged("_minFollowerUSDStake", _minFollowerUSDStake);
    }

    // _maxFollowerUSDStake setter function
    function setMaxFollowerUSDStake(uint256 maxFollowerUSDStake_)
        external
        onlyHordCongress
    {
        _maxFollowerUSDStake = maxFollowerUSDStake_;
        emit ConfigurationChanged("_maxFollowerUSDStake", _maxFollowerUSDStake);
    }

    // _minStakePerPoolTicket setter function
    function setMinStakePerPoolTicket(uint256 minStakePerPoolTicket_)
        external
        onlyHordCongress
    {
        _minStakePerPoolTicket = minStakePerPoolTicket_;
        emit ConfigurationChanged(
            "_minStakePerPoolTicket",
            _minStakePerPoolTicket
        );
    }

    // _assetUtilizationRatio setter function
    function setAssetUtilizationRatio(uint256 assetUtilizationRatio_)
        external
        onlyHordCongress
    {
        _assetUtilizationRatio = assetUtilizationRatio_;
        emit ConfigurationChanged(
            "_assetUtilizationRatio",
            _assetUtilizationRatio
        );
    }

    // _gasUtilizationRatio setter function
    function setGasUtilizationRatio(uint256 gasUtilizationRatio_)
        external
        onlyHordCongress
    {
        _gasUtilizationRatio = gasUtilizationRatio_;
        emit ConfigurationChanged("_gasUtilizationRatio", _gasUtilizationRatio);
    }

    // _platformStakeRatio setter function
    function setPlatformStakeRatio(uint256 platformStakeRatio_)
        external
        onlyHordCongress
    {
        _platformStakeRatio = platformStakeRatio_;
        emit ConfigurationChanged("_platformStakeRatio", _platformStakeRatio);
    }

    // Set percent precision
    function setPercentPrecision(uint256 percentPrecision_)
        external
        onlyHordCongress
    {
        _percentPrecision = percentPrecision_;
        emit ConfigurationChanged("_percentPrecision", _percentPrecision);
    }

    // _maxSupplyHPoolToken setter function
    function setMaxSupplyHPoolToken(uint256 maxSupplyHPoolToken_)
        external
        onlyHordCongress
    {
        _maxSupplyHPoolToken = maxSupplyHPoolToken_;
        emit ConfigurationChanged("_maxSupplyHPoolToken", _maxSupplyHPoolToken);
    }

    // set max usd allocation per ticket
    function setMaxUSDAllocationPerTicket(uint256 maxUSDAllocationPerTicket_)
        external
        onlyHordCongress
    {
        _maxUSDAllocationPerTicket = maxUSDAllocationPerTicket_;
        emit ConfigurationChanged(
            "_maxUSDAllocationPerTicket",
            _maxUSDAllocationPerTicket
        );
    }

    // _totalSupplyHPoolTokens setter function
    function setTotalSupplyHPoolTokens(uint256 totalSupplyHPoolTokens_)
    external
    onlyHordCongress
    {
        _totalSupplyHPoolTokens = totalSupplyHPoolTokens_;
        emit ConfigurationChanged("_totalSupplyHPoolTokens", _totalSupplyHPoolTokens);
    }

    // _endTimeTicketSale setter function
    function setEndTimeTicketSale(uint256 endTimeTicketSale_)
    external
    {
        _endTimeTicketSale = endTimeTicketSale_;
        emit ConfigurationChanged("_endTimeTicketSale", _endTimeTicketSale);
    }

    // _totalSupplyHPoolTokens setter function
    function setEndTimePrivateSubscription(uint256 endTimePrivateSubscription_)
    external
    {
        _endTimePrivateSubscription = endTimePrivateSubscription_;
        emit ConfigurationChanged("_endTimePrivateSubscription", _endTimePrivateSubscription);
    }
    // _totalSupplyHPoolTokens setter function
    function setEndTimePublicSubscription(uint256 endTimePublicSubscription_)
    external
    {
        _endTimePublicSubscription = endTimePublicSubscription_;
        emit ConfigurationChanged("_endTimePublicSubscription", _endTimePublicSubscription);
    }


    // Getter Functions
    // _minChampStake getter function
    function minChampStake() external view returns (uint256) {
        return _minChampStake;
    }

    // _maxWarmupPeriod getter function
    function maxWarmupPeriod() external view returns (uint256) {
        return _maxWarmupPeriod;
    }

    // _maxFollowerOnboardPeriod getter function
    function maxFollowerOnboardPeriod() external view returns (uint256) {
        return _maxFollowerOnboardPeriod;
    }

    // _minFollowerUSDStake getter function
    function minFollowerUSDStake() external view returns (uint256) {
        return _minFollowerUSDStake;
    }

    // _maxFollowerUSDStake getter function
    function maxFollowerUSDStake() external view returns (uint256) {
        return _maxFollowerUSDStake;
    }

    // _minStakePerPoolTicket getter function
    function minStakePerPoolTicket() external view returns (uint256) {
        return _minStakePerPoolTicket;
    }

    // _assetUtilizationRatio getter function
    function assetUtilizationRatio() external view returns (uint256) {
        return _assetUtilizationRatio;
    }

    // _gasUtilizationRatio getter function
    function gasUtilizationRatio() external view returns (uint256) {
        return _gasUtilizationRatio;
    }

    // _platformStakeRatio getter function
    function platformStakeRatio() external view returns (uint256) {
        return _platformStakeRatio;
    }

    // _percentPrecision getter function
    function percentPrecision() external view returns (uint256) {
        return _percentPrecision;
    }

    // _maxSupplyHPoolToken getter function
    function maxSupplyHPoolToken() external view returns (uint256) {
        return _maxSupplyHPoolToken;
    }

    // _maxUSDAllocationPerTicket getter function
    function maxUSDAllocationPerTicket() external view returns (uint256) {
        return _maxUSDAllocationPerTicket;
    }

    // _totalSupplyHPoolTokens getter function
    function totalSupplyHPoolTokens() external view returns (uint256) {
        return _totalSupplyHPoolTokens;
    }

    // _endTimeTicketSale getter function
    function endTimeTicketSale() external view returns (uint256) {
        return _endTimeTicketSale;
    }

    // _endTimePrivateSubscription getter function
    function endTimePrivateSubscription() external view returns (uint256) {
        return _endTimePrivateSubscription;
    }

    // _endTimePublicSubscription getter function
    function endTimePublicSubscription() external view returns (uint256) {
        return _endTimePublicSubscription;
    }

}
