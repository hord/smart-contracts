const hre = require("hardhat");
const { toHordDenomination } = require('../test/setup');
const { getSavedContractABI, saveContractAbi } = require('./utils');
let c = require('../deployments/deploymentConfig.json');


async function main() {
    await hre.run('compile');

    saveContractAbi(hre.network.name, 'HordTicketManager', (await hre.artifacts.readArtifact("HordTicketManager")).abi)
    saveContractAbi(hre.network.name, 'HordTicketFactory', (await hre.artifacts.readArtifact("HordTicketFactory")).abi)
    saveContractAbi(hre.network.name, 'HPool', (await hre.artifacts.readArtifact("HPool")).abi)
    saveContractAbi(hre.network.name, 'HPoolManager', (await hre.artifacts.readArtifact("HPoolManager")).abi)
    saveContractAbi(hre.network.name, 'HordConfiguration', (await hre.artifacts.readArtifact("HordConfiguration")).abi)
    saveContractAbi(hre.network.name, 'HPoolFactory', (await hre.artifacts.readArtifact("HPoolFactory")).abi)
    saveContractAbi(hre.network.name, 'HordTreasury', (await hre.artifacts.readArtifact("HordTreasury")).abi)
    saveContractAbi(hre.network.name, 'MaintainersRegistry', (await hre.artifacts.readArtifact("MaintainersRegistry")).abi)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
