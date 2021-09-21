const {
    address,
    encodeParameters
} = require('./ethereum');
const hre = require("hardhat");
let configuration = require('../deployments/deploymentConfig.json');
const { ethers, expect } = require('./setup')

let config;
let accounts, owner, ownerAddr, hordCongress, hordCongressAddr, maintainer, maintainerAddr, maintainersRegistry, hordConfiguration;

async function setupContractAndAccounts () {
    config = configuration[hre.network.name]

    accounts = await ethers.getSigners()
    owner = accounts[0]
    ownerAddr = await owner.getAddress()
    hordCongress = accounts[5]
    hordCongressAddr = await hordCongress.getAddress()
    maintainer = accounts[8]
    maintainerAddr = await maintainer.getAddress()

    const MaintainersRegistry = await ethers.getContractFactory('MaintainersRegistry')
    maintainersRegistry = await upgrades.deployProxy(MaintainersRegistry, [[maintainerAddr], hordCongressAddr]);
    await maintainersRegistry.deployed()

    const HordConfiguration = await ethers.getContractFactory('HordConfiguration')
    hordConfiguration = await upgrades.deployProxy(HordConfiguration, [
            hordCongressAddr,
            maintainersRegistry.address,
            config["minChampStake"],
            config["maxWarmupPeriod"],
            config["maxFollowerOnboardPeriod"],
            config["minFollowerEthStake"],
            config["maxFollowerEthStake"],
            config["minStakePerPoolTicket"],
            config["assetUtilizationRatio"],
            config["gasUtilizationRatio"],
            config["platformStakeRatio"],
            config["maxSupplyHPoolToken"],
            config["maxUSDAllocationPerTicket"],
            config["totalSupplyHPoolTokens"]
        ]
    );
    await hordConfiguration.deployed()
}

describe('HordConfiguration', async() => {

    before('setup contracts', async () => {
        await setupContractAndAccounts();
    });

    it('should check return values in minChampStake function', async() => {
        let minChampStake = config["minChampStake"];
        await hordConfiguration.connect(hordCongress).setMinChampStake(minChampStake);
        expect(await hordConfiguration.minChampStake())
            .to.be.equal(minChampStake);
    });

    it('should check return values in maxWarmupPeriod function', async() => {
        let maxWarumPeriod = config["maxWarmupPeriod"];
        await hordConfiguration.connect(hordCongress).setMaxWarmupPeriod(maxWarumPeriod);
        expect(await hordConfiguration.maxWarmupPeriod())
            .to.be.equal(maxWarumPeriod);
    });

    it('should check return values in maxFollowerOnboardPeriod function', async() => {
        let maxFollowerOnboardPeriod = config["maxFollowerOnboardPeriod"];
        await hordConfiguration.connect(hordCongress).setMaxFollowerOnboardPeriod(maxFollowerOnboardPeriod);
        expect(await hordConfiguration.maxFollowerOnboardPeriod())
            .to.be.equal(maxFollowerOnboardPeriod);
    });

    it('should check return values in minFollowerUSDStake function', async() => {
        let minFollowerUSDStake = config["minFollowerEthStake"];
        await hordConfiguration.connect(hordCongress).setMinFollowerUSDStake(minFollowerUSDStake);
        expect(await hordConfiguration.minFollowerUSDStake())
            .to.be.equal(minFollowerUSDStake);
    });

    it('should check return values in maxFollowerUSDStake function', async() => {
        let maxFollowerUSDStake = config["maxFollowerEthStake"];
        await hordConfiguration.connect(hordCongress).setMaxFollowerUSDStake(maxFollowerUSDStake);
        expect(await hordConfiguration.maxFollowerUSDStake())
            .to.be.equal(maxFollowerUSDStake);
    });

    it('should check return values in minStakePerPoolTicket function', async() => {
        let minStakePerPoolTicket = config["minStakePerPoolTicket"];
        await hordConfiguration.connect(hordCongress).setMinStakePerPoolTicket(minStakePerPoolTicket);
        expect(await hordConfiguration.minStakePerPoolTicket())
            .to.be.equal(minStakePerPoolTicket);
    });

    it('should check return values in assetUtilizationRatio function', async() => {
        let assetUtilizationRatio = config["assetUtilizationRatio"];
        await hordConfiguration.connect(hordCongress).setAssetUtilizationRatio(assetUtilizationRatio);
        expect(await hordConfiguration.assetUtilizationRatio())
            .to.be.equal(assetUtilizationRatio);
    });

    it('should check return values in gasUtilizationRatio function', async() => {
        let gasUtilizationRatio = config["gasUtilizationRatio"];
        await hordConfiguration.connect(hordCongress).setGasUtilizationRatio(gasUtilizationRatio);
        expect(await hordConfiguration.gasUtilizationRatio())
            .to.be.equal(gasUtilizationRatio);
    });

    it('should check return values in platformStakeRatio function', async() => {
        let platformStakeRatio = config["platformStakeRatio"];
        await hordConfiguration.connect(hordCongress).setPlatformStakeRatio(platformStakeRatio);
        expect(await hordConfiguration.platformStakeRatio())
            .to.be.equal(platformStakeRatio);
    });

    it('should check return values in percentPrecision function', async() => {
        let percentPrecision = 10;
        await hordConfiguration.connect(hordCongress).setPercentPrecision(percentPrecision);
        expect(await hordConfiguration.percentPrecision())
            .to.be.equal(percentPrecision);
    });

    it('should check return values in maxSupplyHPoolToken function', async() => {
        let maxSupplyHPoolToken = config["maxSupplyHPoolToken"];
        await hordConfiguration.connect(hordCongress).setMaxSupplyHPoolToken(maxSupplyHPoolToken);
        expect(await hordConfiguration.maxSupplyHPoolToken())
            .to.be.equal(maxSupplyHPoolToken);
    });

    it('should check return values in maxUSDAllocationPerTicket function', async() => {
        let maxUSDAllocationPerTicket = config["maxUSDAllocationPerTicket"];
        await hordConfiguration.connect(hordCongress).setMaxUSDAllocationPerTicket(maxUSDAllocationPerTicket);
        expect(await hordConfiguration.maxUSDAllocationPerTicket())
            .to.be.equal(maxUSDAllocationPerTicket);
    });

    it('should check return values in totalSupplyHPoolTokens function', async() => {
        let totalSupplyHPoolTokens = config["totalSupplyHPoolTokens"];
        await hordConfiguration.connect(hordCongress).setTotalSupplyHPoolTokens(totalSupplyHPoolTokens);
        expect(await hordConfiguration.totalSupplyHPoolTokens())
            .to.be.equal(totalSupplyHPoolTokens);
    });

    it('should check return values in totalSupplyHPoolTokens function', async() => {
        let endTimeTicketSale = 10;
        await hordConfiguration.connect(hordCongress).setEndTimeTicketSale(endTimeTicketSale);
        expect(await hordConfiguration.endTimeTicketSale())
            .to.be.equal(endTimeTicketSale);
    });

    it('should check return values in totalSupplyHPoolTokens function', async() => {
        let endTimePrivateSubscription = 10;
        await hordConfiguration.connect(hordCongress).setEndTimePrivateSubscription(endTimePrivateSubscription);
        expect(await hordConfiguration.endTimePrivateSubscription())
            .to.be.equal(endTimePrivateSubscription);
    });

    it('should check return values in endTimePublicSubscription function', async() => {
        let endTimePublicSubscription = 10;
        await hordConfiguration.connect(hordCongress).setEndTimePublicSubscription(endTimePublicSubscription);
        expect(await hordConfiguration.endTimePublicSubscription())
            .to.be.equal(endTimePublicSubscription);
    });

});