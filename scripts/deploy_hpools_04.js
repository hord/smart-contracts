const hre = require("hardhat");
const { toHordDenomination } = require('../test/setup');
const { getSavedContractAddresses, saveContractAddress, saveContractProxies, getSavedContractProxies } = require('./utils');
let c = require('../deployments/deploymentConfig.json');


async function main() {
    await hre.run('compile');
    const config = c[hre.network.name];
    const contracts = getSavedContractAddresses()[hre.network.name];
    const contractProxies = getSavedContractProxies()[hre.network.name];

    const HordConfiguration = await hre.ethers.getContractFactory('HordConfiguration');
    const hordConfiguration = await upgrades.deployProxy(HordConfiguration, [
        [contracts["HordCongress"], contractProxies["MaintainersRegistry"]],
        [toHordDenomination(config.minChampStake),
        config.maxWarmupPeriod,
        config.maxFollowerOnboardPeriod,
        toHordDenomination(config.minFollowerEthStake),
        toHordDenomination(config.maxFollowerEthStake),
        toHordDenomination(config.minStakePerPoolTicket),
        config.assetUtilizationRatio,
        config.gasUtilizationRatio,
        config.platformStakeRatio,
        toHordDenomination(config.maxSupplyHPoolToken),
        toHordDenomination(config.maxUSDAllocationPerTicket),
        toHordDenomination(config.totalSupplyHPoolTokens),
        config.endTimeTicketSale,
        config.endTimePrivateSubscription,
        config.endTimePublicSubscription]
    ]);
    await hordConfiguration.deployed();
    console.log('HordConfiguration Proxy is deployed to: ', hordConfiguration.address);
    saveContractProxies(hre.network.name, 'HordConfiguration', hordConfiguration.address);


    const HPoolFactory = await hre.ethers.getContractFactory('HPoolFactory');
    const hPoolFactory = await upgrades.deployProxy(HPoolFactory, [
        contracts["HordCongress"],
        contractProxies["MaintainersRegistry"]
    ]);
    await hPoolFactory.deployed();
    console.log('HPoolFactory Proxy is deployed to:', hPoolFactory.address);
    saveContractProxies(hre.network.name, 'HPoolFactory', hPoolFactory.address);


    const HPoolManager = await hre.ethers.getContractFactory('HPoolManager');
    const hPoolManager = await upgrades.deployProxy(HPoolManager, [
            contracts["HordCongress"],
            contractProxies["MaintainersRegistry"],
            contractProxies["HordTicketFactory"],
            contractProxies["HordTreasury"],
            contracts["HordToken"],
            hPoolFactory.address,
            contracts["AggregatorV3Interface"],
            hordConfiguration.address,
    ]);
    await hPoolManager.deployed();
    console.log('HPoolManager is deployed to:', hPoolManager.address);
    saveContractProxies(hre.network.name, 'HPoolManager', hPoolManager.address);

    // Setters
    await hPoolFactory.setHPoolManager(hPoolManager.address);
    console.log('hPoolFactory.setHPoolManager(', hPoolManager.address, ') is set successfully.');

    let admin = await upgrades.admin.getInstance();

    let hordConfigurationImplementation = await admin.getProxyImplementation(hordConfiguration.address);
    console.log('Hord Configuration Implementation: ', hordConfigurationImplementation);
    saveContractAddress(hre.network.name, 'HordConfiguration', hordConfigurationImplementation);


    let hPoolFactoryImplementation = await admin.getProxyImplementation(hPoolFactory.address);
    console.log('HPoolFactory Implementation: ', hPoolFactoryImplementation);
    saveContractAddress(hre.network.name, 'HPoolFactory', hPoolFactoryImplementation);


    let hPoolManagerImplementation = await admin.getProxyImplementation(hPoolManager.address);
    console.log('HPoolManager Implementation: ', hPoolManagerImplementation);
    saveContractAddress(hre.network.name, 'HPoolManager', hPoolManagerImplementation);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
