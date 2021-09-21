const {
    address,
    encodeParameters
} = require('./ethereum');
const configuration = require('../deployments/deploymentConfig.json');
const { ethers, expect, isEthException, awaitTx, toHordDenomination, waitForSomeTime} = require('./setup')
const hre = require("hardhat");


const zeroAddress = "0x000000000000000000000000000000000000000000";
const minAmountToStake = 100;
const maxTickets = 100;
const minTickets = 0;

let hordCongress, hordCongressAddress, accounts, owner, ownerAddr, maintainer, maintainerAddr,
    user, userAddress, config,
    hordToken, maintainersRegistryContract, ticketFactoryContract, ticketManagerContract,
    championId, supplyToMint, tx, tokenId, lastAddedId, ticketsToBuy, reservedTickets,
    hordBalance, ticketsBalance, amountStaked, ticketFactory, factoryAddress, supplyToAdd, index, maintainersRegistry;

async function setupAccounts () {
    config = configuration[hre.network.name];
    let accounts = await ethers.getSigners()
    owner = accounts[0];
    ownerAddr = await owner.getAddress()

    // Mock hord congress
    hordCongress = accounts[7];
    hordCongressAddress = await hordCongress.getAddress();
    // Mock maintainer address
    maintainer = accounts[8]
    maintainerAddr = await maintainer.getAddress()

    user = accounts[9]
    userAddress = await user.getAddress()

    ticketFactory = accounts[4]
    factoryAddress = await ticketFactory.getAddress()

}

async function setupContracts () {
    const Hord = await hre.ethers.getContractFactory("HordToken");

    hordToken = await Hord.deploy(
        config.hordTokenName,
        config.hordTokenSymbol,
        toHordDenomination(config.hordTotalSupply.toString()),
        ownerAddr
    );
    await hordToken.deployed()

    hordToken = hordToken.connect(owner)


    const MaintainersRegistry = await ethers.getContractFactory('MaintainersRegistry')
    maintainersRegistry = await upgrades.deployProxy(MaintainersRegistry, [[maintainerAddr], hordCongressAddress]);
    await maintainersRegistry.deployed()
    maintainersRegistryContract = maintainersRegistry.connect(owner);


    const HordTicketManager = await ethers.getContractFactory('HordTicketManager');
    hordTicketManager = await upgrades.deployProxy(HordTicketManager, [
            hordCongressAddress,
            maintainersRegistry.address,
            hordToken.address,
            config['minTimeToStake'],
            toHordDenomination(config['minAmountToStake'])
        ]
    );
    await hordTicketManager.deployed()
    ticketManagerContract = hordTicketManager.connect(owner);

    const HordTicketFactory = await ethers.getContractFactory('HordTicketFactory')
    hordTicketFactory = await upgrades.deployProxy(HordTicketFactory, [
            hordCongressAddress,
            maintainersRegistry.address,
            hordTicketManager.address,
            config["maxFungibleTicketsPerPool"],
            config["uri"],
            config["contractMetadataUri"]
        ]
    );
    await hordTicketFactory.deployed()

    ticketFactoryContract = hordTicketFactory.connect(maintainer);

    supplyToMint = 20;
    supplyToAdd = 10;

    await hordTicketManager.setHordTicketFactory(hordTicketFactory.address);
}

describe('HordTicketFactory & HordTicketManager Test', async () => {

    before('setup contracts', async () => {
        await setupAccounts();
        await setupContracts()
    });

    describe('Test initial values are properly set in HordTicketManager contract', async () => {

        const minTimeToStake = 100;

        it('should not let initialize twice.', async() => {
            await expect(ticketManagerContract.initialize(hordCongressAddress, maintainersRegistryContract.address, hordToken.address, config['minTimeToStake'],
                toHordDenomination(config['minAmountToStake']))).to.be.reverted;
        });

        it('should not let initialize with false args', async() => {
            await expect(ticketManagerContract.initialize(zeroAddress, zeroAddress, zeroAddress, config['minTimeToStake'],
                toHordDenomination(config['minAmountToStake']))).to.be.reverted;
        });

        it('should let hordCongress to call setHordTicketFactory function', async() => {
            await ticketManagerContract.connect(hordCongress).setHordTicketFactory(ticketFactoryContract.address);
            expect(await ticketManagerContract.hordTicketFactory()).to.equal(ticketFactoryContract.address);
        });

        it('should not let maintainer to call setHordTicketFactory function', async() => {
            await expect(ticketManagerContract.connect(maintainer).setHordTicketFactory(ticketFactoryContract.address))
                .to.be.reverted;
        });

        it('should not let user to call setHordTicketFactory function', async() => {
            await expect(ticketManagerContract.connect(user).setHordTicketFactory(ticketFactoryContract.address))
                .to.be.reverted;
        });

        it('should not let hordCongress to call setHordTicketFactory function with worng args', async() => {
            await expect(ticketManagerContract.connect(hordCongress).setHordTicketFactory(zeroAddress))
                .to.be.reverted;
        });

        it('should let hordCongress to call setMinTimeToStake function', async() => {
            await ticketManagerContract.connect(hordCongress).setMinTimeToStake(minTimeToStake);
            expect(await ticketManagerContract.minTimeToStake()).to.equal(minTimeToStake);
        });

        it('should not let user to call setMinTimeToStake function', async() => {
            await expect(ticketManagerContract.connect(user).setMinTimeToStake(minTimeToStake))
                .to.be.revertedWith("HordUpgradable: Restricted only to HordCongress");
        });

        it('should not let maintainer to call setMinTimeToStake function', async() => {
            await expect(ticketManagerContract.connect(maintainer).setMinTimeToStake(minTimeToStake))
                .to.be.revertedWith("HordUpgradable: Restricted only to HordCongress");
        });

        it('should not let user to call setMinAmountToStake function', async() => {
            await expect(ticketManagerContract.connect(user).setMinAmountToStake(minAmountToStake))
                .to.be.revertedWith("HordUpgradable: Restricted only to HordCongress");
        });

        it('should not let maintainer to call setMinAmountToStake function', async() => {
            await expect(ticketManagerContract.connect(maintainer).setMinAmountToStake(minAmountToStake))
                .to.be.revertedWith("HordUpgradable: Restricted only to HordCongress");
        });

        it('should check if non hordCongress address call setMaintainersRegistry function in HordUpgradable contract', async() => {
            await expect(ticketManagerContract.connect(user).setMaintainersRegistry(maintainersRegistry.address))
                .to.be.revertedWith("HordUpgradable: Restricted only to HordCongress");
        });

        it('should check if hordCongress address call setMaintainersRegistry function in HordUpgradable contract', async() => {
            await ticketManagerContract.connect(hordCongress).setMaintainersRegistry(maintainersRegistry.address);
            const maintainerReg = await ticketManagerContract.maintainersRegistry();
            expect(maintainersRegistry.address)
                .to.be.equal(maintainerReg);
        });

    });

    describe('Test initial values are properly set in HordTicketFactory contract', async() => {

        tokenId = 10;

        it('should not let initialize twice.', async() => {
            await expect(ticketFactoryContract.initialize(hordCongressAddress, maintainersRegistryContract.address, ticketFactoryContract.address,
                config["maxFungibleTicketsPerPool"], config["uri"], config["contractMetadataUri"])).to.be.reverted;
        });

        it('should not let initialize with false args', async() => {
            await expect(ticketManagerContract.initialize(zeroAddress, zeroAddress, zeroAddress, config['minTimeToStake'],
                config["maxFungibleTicketsPerPool"], config["uri"], config["contractMetadataUri"])).to.be.reverted;
        });

        it('should let hordCongress to call setNewUri function', async() => {
            await expect(ticketFactoryContract.connect(hordCongress).setNewUri(config["uri"]));
        });

        it('should not let user to call setNewUri function', async() => {
            await expect(ticketFactoryContract.connect(user).setNewUri(config["uri"]))
                .to.be.revertedWith("HordUpgradable: Restricted only to HordCongress");
        });

        it('should not let maintainer to call setNewUri function', async() => {
            await expect(ticketFactoryContract.connect(maintainer).setNewUri(config["uri"]))
                .to.be.revertedWith("HordUpgradable: Restricted only to HordCongress");
        });

        it('should check return value in contractURI function', async() => {
            await ticketFactoryContract.connect(hordCongress).setNewContractLevelUri(config["contractMetadataUri"]);
            expect(await ticketFactoryContract.connect(user).contractURI())
                .to.be.equal(config["contractMetadataUri"]);
        });

        it('should not let user to call setNewContractLevelUri function', async() => {
            await expect(ticketFactoryContract.connect(user).setNewContractLevelUri(config["uri"]))
                .to.be.revertedWith("HordUpgradable: Restricted only to HordCongress");
        });

        it('should not let maintainer to call setNewContractLevelUri function', async() => {
            await expect(ticketFactoryContract.connect(maintainer).setNewContractLevelUri(config["uri"]))
                .to.be.revertedWith("HordUpgradable: Restricted only to HordCongress");
        });

        it('should let hordCongress to call setMaxFungibleTicketsPerPool function', async() => {
            await ticketFactoryContract.connect(hordCongress).setMaxFungibleTicketsPerPool(maxTickets);
            expect(await ticketFactoryContract.maxFungibleTicketsPerPool())
                .to.be.equal(maxTickets);
        });

        it('should not let hordCongress to call setMaxFungibleTicketsPerPool with 0 tickets', async() => {
            await expect(ticketFactoryContract.connect(hordCongress).setMaxFungibleTicketsPerPool(minTickets))
                .to.be.reverted;
        });

        it('should not let user to call setMaxFungibleTicketsPerPool function', async() => {
           await expect(ticketFactoryContract.connect(user).setMaxFungibleTicketsPerPool(maxTickets))
               .to.be.revertedWith("HordUpgradable: Restricted only to HordCongress");
        });

        it('should not let maintainer to call setMaxFungibleTicketsPerPool function', async() => {
            await expect(ticketFactoryContract.connect(maintainer).setMaxFungibleTicketsPerPool(maxTickets))
                .to.be.revertedWith("HordUpgradable: Restricted only to HordCongress");
        });

        it('should check return value in getMaxFungibleTicketsPerPoolForTokenId function', async() => {
            await ticketFactoryContract.connect(maintainer).setMaxFungibleTicketsPerPoolForTokenId(tokenId, maxTickets);
            expect(await ticketFactoryContract.connect(user).getMaxFungibleTicketsPerPoolForTokenId(tokenId))
                .to.be.equal(maxTickets);
        });

        it('should not let user to call setMaxFungibleTicketsPerPoolForTokenId function', async() => {
            await expect(ticketFactoryContract.connect(user).setMaxFungibleTicketsPerPoolForTokenId(tokenId, maxTickets))
                .to.be.revertedWith( "HordUpgradable: Restricted only to Maintainer");
        });

        it('should not let hordcongress to call setMaxFungibleTicketsPerPoolForTokenId function', async() => {
            await expect(ticketFactoryContract.connect(hordCongress).setMaxFungibleTicketsPerPoolForTokenId(tokenId, maxTickets))
                .to.be.revertedWith( "HordUpgradable: Restricted only to Maintainer");
        });

        it('should not let to call addTokenSupply function before mint token', async() => {
            await expect(ticketFactoryContract.connect(maintainer).addTokenSupply(tokenId, supplyToAdd))
                .to.be.revertedWith("AddTokenSupply: Firstly MINT token, then expand supply.");
        });

    });

    describe('HordTicketManager functions', async() => {

        const championId = 5;
        const numberOfTickets = 4;
        tokenId = 10;

        it('should not let user to call addNewTokenIdForChampion function', async() => {
            await expect(ticketManagerContract.connect(user).addNewTokenIdForChampion(tokenId, championId))
                .to.be.revertedWith('Only Hord Ticket factory can issue a call to this function');
        });

        it('should not let maintainer to call addNewTokenIdForChampion function', async() => {
            await expect(ticketManagerContract.connect(maintainer).addNewTokenIdForChampion(tokenId, championId))
                .to.be.revertedWith('Only Hord Ticket factory can issue a call to this function');
        });

        it('should not let hordCongress to call addNewTokenIdForChampion function', async() => {
            await expect(ticketManagerContract.connect(hordCongress).addNewTokenIdForChampion(tokenId, championId))
                .to.be.revertedWith('Only Hord Ticket factory can issue a call to this function');
        });

        it('should not let to user to buy more tickets than exists', async() => {
            await expect(ticketManagerContract.connect(user).stakeAndReserveNFTs(tokenId, numberOfTickets))
                .to.be.revertedWith('Not enough tickets to sell.');
        });

        it('should let ticketFactoryContract to call addNewTokenIdForChampion function', async() => {
            await ticketManagerContract.connect(hordCongress).setHordTicketFactory(factoryAddress);
            await ticketManagerContract.connect(ticketFactory).addNewTokenIdForChampion(tokenId, championId);
            let tokenIds = await ticketManagerContract.connect(hordCongress).getChampionTokenIds(championId)

            for(let i = 0; i < tokenIds.length; i++){
                expect(tokenIds[i]).to.be.equal(tokenId);
            }

            await ticketManagerContract.connect(hordCongress).setHordTicketFactory(ticketFactoryContract.address);
        });

        it('should not let to call getNumberOfStakesForUserAndToken function with 0x0 address', async() => {
            await expect(ticketManagerContract.connect(user).getNumberOfStakesForUserAndToken(zeroAddress, tokenId))
                .to.be.reverted;
        });

        it('should not let to call getCurrentAmountStakedForTokenId function with 0x0 address', async() => {
            await expect(ticketManagerContract.connect(user).getCurrentAmountStakedForTokenId(zeroAddress, tokenId))
                .to.be.reverted;
        });

        it('should not let to call getUserStakesForTokenId function with 0x0 address', async() => {
            await expect(ticketManagerContract.connect(user).getUserStakesForTokenId(zeroAddress, tokenId))
                .to.be.reverted;
        });

    });

    describe('Pause and Unpause contract', async() => {
        it('should NOT be able to pause contract from NON-congress address', async() => {
           ticketFactoryContract = ticketFactoryContract.connect(user);
            expect(
                await isEthException(ticketFactoryContract.pause())
            ).to.be.true
        });

        it('should pause contract from congress', async() => {
            ticketFactoryContract = ticketFactoryContract.connect(hordCongress);
            await ticketFactoryContract.pause();
            expect(await ticketFactoryContract.paused()).to.be.true;
        });

        it('should unpause contract from congress', async() => {
            await ticketFactoryContract.unpause();
            expect(await ticketFactoryContract.paused()).to.be.false;
        });
    });

    describe('Minting from maintainer', async() => {
        it('should mint token', async() => {
            ticketFactoryContract = ticketFactoryContract.connect(maintainer);
            lastAddedId = await ticketFactoryContract.lastMintedTokenId();
            tokenId = parseInt(lastAddedId,10) + 1;
            championId = 1;
            tx = await awaitTx(ticketFactoryContract.mintNewHPoolNFT(tokenId, supplyToMint, championId));
        });

        it('should check MintedNewNFT event', async() => {
            expect(tx.events.length).to.equal(2)
            expect(tx.events[1].event).to.equal('MintedNewNFT')
            expect(parseInt(tx.events[1].args.tokenId)).to.equal(tokenId)
            expect(parseInt(tx.events[1].args.championId)).to.equal(championId)
            expect(parseInt(tx.events[1].args.initialSupply)).to.equal(supplyToMint)
        });

        it('should check that all minted tokens are on TicketManager contract', async () => {
            let balance = await ticketFactoryContract.balanceOf(ticketManagerContract.address, tokenId);
            expect(balance).to.be.equal(supplyToMint);
        })

        it('should check token supply', async() => {
            let tokenSupply = await ticketFactoryContract.getTokenSupply(tokenId);
            expect(parseInt(tokenSupply,10)).to.equal(supplyToMint, "Wrong supply minted.");
        });

        it('should check champion minted ids', async() => {
            let championMintedIds = await ticketManagerContract.getChampionTokenIds(championId);
            expect(parseInt(championMintedIds.slice(-1)[0])).to.equal(championId, "Champion ID does not match.");
        });
    });

    describe('Adding token supply', async() => {

        it('should not let user to call addTokenSupply function', async() => {
            await expect(ticketFactoryContract.connect(user).addTokenSupply(tokenId, supplyToAdd))
                .to.be.revertedWith( "HordUpgradable: Restricted only to Maintainer");
        });

        it('should not let hordCongress to call addTokenSupply function', async() => {
            await expect(ticketFactoryContract.connect(hordCongress).addTokenSupply(tokenId, supplyToAdd))
                .to.be.revertedWith( "HordUpgradable: Restricted only to Maintainer");
        });

        it('should add token supply within allowed range', async () => {
            await ticketFactoryContract.addTokenSupply(tokenId, supplyToAdd);
            expect(await ticketFactoryContract.getTokenSupply(tokenId))
                .to.be.equal(supplyToAdd * 3);
        });

        it('should not let to call addTokenSupply function with more supply than allowed', async() => {
            const notAllowedSupply = 1000;
            await expect(ticketFactoryContract.connect(maintainer).addTokenSupply(tokenId, notAllowedSupply))
                .to.be.revertedWith("More than allowed.");
        });

        it('should not let maintainer to call setMaxFungibleTicketsPerPoolForTokenId with fewer tickets', async() => {
            const tokenSupply = await ticketFactoryContract.getTokenSupply(tokenId) - 1;
            await expect(ticketFactoryContract.connect(maintainer).setMaxFungibleTicketsPerPoolForTokenId(tokenId, tokenSupply))
                .to.be.reverted;
        });
    });

    describe('Minting from address which is not maintainer', async() => {
       it('should not be able to mint from non-maintainer user', async() => {
           ticketFactoryContract = ticketFactoryContract.connect(user);
           lastAddedId = await ticketFactoryContract.lastMintedTokenId();
           tokenId = parseInt(lastAddedId,10) + 1;
           championId = 1;

           expect(
               await isEthException(ticketFactoryContract.mintNewHPoolNFT(tokenId, supplyToMint, championId))
           ).to.be.true
       });

       it('should not be able to mint non-ordered token id', async() => {
           ticketFactoryContract = ticketFactoryContract.connect(maintainer);
           tokenId = tokenId + 1;
           expect(
               await isEthException(ticketFactoryContract.mintNewHPoolNFT(tokenId, supplyToMint, championId))
           ).to.be.true
       });

       it('should not be able to mint more than max supply', async() => {
           ticketFactoryContract = ticketFactoryContract.connect(maintainer);
           lastAddedId = await ticketFactoryContract.lastMintedTokenId();
           tokenId = parseInt(lastAddedId,10) + 1;
           let _supplyToMint = config["maxFungibleTicketsPerPool"] + 1;
           expect(
               await isEthException(ticketFactoryContract.mintNewHPoolNFT(tokenId, _supplyToMint, championId))
           ).to.be.true
       });
    });

    describe('Staking HORD in order to get tickets', async() => {

        const tokensToStake = 3500;

        it('should have some hord tokens in order to stake', async() => {
            hordToken = hordToken.connect(owner);
            await hordToken.transfer(userAddress, toHordDenomination(tokensToStake));

            let balance = await hordToken.balanceOf(userAddress);
            expect(balance.toString()).to.be.equal(toHordDenomination(tokensToStake));
        });

        it('should approve HordTicketManager to take HORD', async () => {
            hordToken = hordToken.connect(user);
            let balance = await hordToken.balanceOf(userAddress);
            await hordToken.approve(ticketManagerContract.address, balance);
        });

        it('should check accounting state before deposit', async() => {
            tokenId = await ticketFactoryContract.lastMintedTokenId();
            reservedTickets = await ticketManagerContract.getAmountOfTicketsReserved(tokenId);
            expect(parseInt(reservedTickets,10)).to.equal(0);
        });

        it('should try to buy 3 tickets', async() => {
            ticketsToBuy = 3;
            ticketManagerContract = ticketManagerContract.connect(user);
            tokenId = await ticketFactoryContract.lastMintedTokenId();
            tx = await awaitTx(ticketManagerContract.stakeAndReserveNFTs(tokenId, ticketsToBuy));
        });

        it('should NOT be able to buy more tickets than user can afford', async() => {
            ticketManagerContract = ticketManagerContract.connect(user);
            tokenId = await ticketFactoryContract.lastMintedTokenId();
            expect(
                await isEthException(ticketManagerContract.stakeAndReserveNFTs(tokenId, 2))
            ).to.be.true
        });

        it('should check event TokensStaked', async() => {
            expect(tx.events.length).to.equal(5)
            expect(tx.events[2].event).to.equal('TokensStaked');
            expect(tx.events[2].args.user).to.equal(userAddress, "User address is not matching")
            expect(tx.events[2].args.amountStaked).to.equal(toHordDenomination(ticketsToBuy * config['minAmountToStake']));
            expect(parseInt(tx.events[2].args.inFavorOfTokenId)).to.equal(tokenId);
            expect(parseInt(tx.events[2].args.numberOfTicketsReserved)).to.equal(ticketsToBuy);
        });

        it('shpuld check event NFTsClaimed', async() => {
            expect(tx.events[4].event).to.equal('NFTsClaimed');
            expect(tx.events[4].args.beneficiary).to.equal(userAddress, "User address is not matching")
            expect(tx.events[4].args.amountUnstaked).to.equal(toHordDenomination(0));
            expect(parseInt(tx.events[4].args.amountTicketsClaimed)).to.equal(ticketsToBuy);
            expect(parseInt(tx.events[4].args.tokenId)).to.equal(tokenId);
        });

        it('should check amount user is actively staking', async() => {
            amountStaked = await ticketManagerContract.getCurrentAmountStakedForTokenId(userAddress, tokenId);
            expect(amountStaked).to.equal(toHordDenomination(ticketsToBuy * config['minAmountToStake']));
        });

        it('should check number of reserved tickets', async() => {
            reservedTickets = await ticketManagerContract.getAmountOfTicketsReserved(tokenId);
            expect(parseInt(reservedTickets, 10)).to.equal(ticketsToBuy);
        });

        it('should check number of user stakes', async() => {
            index = 0;
            const numberOfStakes = await ticketManagerContract.getNumberOfStakesForUserAndToken(userAddress, tokenId);
            const userStake = await ticketManagerContract.connect(hordCongress).addressToTokenIdToStakes(userAddress, tokenId, index);

            expect(numberOfStakes.length).to.be.equal(userStake[index].length);
        });


        it('should check return value in getAmountOfTokensClaimed function', async() => {
            const tokenSupply = await ticketFactoryContract.connect(maintainer).getTokenSupply(tokenId);
            const balanceOfTicketManager = await hordTicketFactory.balanceOf(ticketManagerContract.address, tokenId);
            expect(await ticketManagerContract.connect(user).getAmountOfTokensClaimed(tokenId))
                .to.be.equal(tokenSupply.sub(balanceOfTicketManager));
        });

        it('should check return values in getUserStakesForTokenId function', async() => {
            index = 0;
            let userStake = await ticketManagerContract.addressToTokenIdToStakes(userAddress, tokenId, index);

            let userStakes = await ticketManagerContract.getUserStakesForTokenId(userAddress, tokenId);

            expect(userStake.amountStaked)
                .to.be.equal(userStakes[0][index]);
            expect(userStake.amountOfTicketsGetting)
                .to.be.equal(userStakes[1][index]);
            expect(userStake.unlockingTime)
                .to.be.equal(userStakes[2][index]);
            expect(userStake.isWithdrawn)
                .to.be.equal(userStakes[3][index]);
        });

    });

    describe('Claiming tickets', async() => {
        it('should NOT BE ABLE claim NFT tickets and withdraw amount staked', async() => {
            ticketManagerContract = ticketManagerContract.connect(user);
            let startIndex = 0;
            let endIndex = await ticketManagerContract.getNumberOfStakesForUserAndToken(userAddress, tokenId);
            tx = await awaitTx(ticketManagerContract.claimNFTs(tokenId, startIndex, endIndex));
            expect(tx.events.length).to.equal(0);
        });

        it('should advance time so user can claim NFTs', async() => {
            await waitForSomeTime(owner.provider, config["minTimeToStake"]);
        });

        it('should get balance of tickets and hord before withdrawal', async() => {
            hordBalance = await hordToken.balanceOf(userAddress);
            ticketsBalance = await ticketFactoryContract.balanceOf(userAddress, tokenId);
            amountStaked = await ticketManagerContract.getCurrentAmountStakedForTokenId(userAddress, tokenId);
            expect(ticketsBalance).to.equal(ticketsToBuy);
        });

        it('should claim NFT tickets and withdraw amount staked', async() => {
            ticketManagerContract = ticketManagerContract.connect(user);
            let startIndex = 0;
            let endIndex = await ticketManagerContract.getNumberOfStakesForUserAndToken(userAddress, tokenId);
            tx = await awaitTx(ticketManagerContract.claimNFTs(tokenId, startIndex, endIndex));

            expect(tx.events.length).to.equal(2);
            expect(tx.events[1].event).to.equal('NFTsClaimed');
            expect(tx.events[1].args.beneficiary).to.equal(userAddress, "User address is not matching")
            expect(tx.events[1].args.amountUnstaked).to.equal(toHordDenomination(ticketsToBuy * config['minAmountToStake']));
            expect(parseInt(tx.events[1].args.amountTicketsClaimed)).to.equal(0);
            expect(parseInt(tx.events[1].args.tokenId)).to.equal(tokenId);
        });

        it('should check that user withdrawn amount staked', async() => {
            let balanceAfterWithdraw = await hordToken.balanceOf(userAddress);
            expect(hordBalance.add(amountStaked)).equal(balanceAfterWithdraw);
        });

        it('should check return value in getCurrentAmountStakedForTokenId function', async() => {
            index = 0;
            let userStakes = await ticketManagerContract.addressToTokenIdToStakes(userAddress, tokenId, index);

            let numberOfStakes = userStakes.length;
            let amountCurrentlyStaking = 0;

            for(let i = 0; i < numberOfStakes; i++) {
                if(userStakes[i].isWithdrawn == false) {
                    amountCurrentlyStaking = amountCurrentlyStaking.add(userStakes[i].amountStaked);
                }
            }

            expect(await ticketManagerContract.getCurrentAmountStakedForTokenId(userAddress, tokenId))
                .to.be.equal(amountCurrentlyStaking);
        });

        it('should check that user received NFTs', async() => {
           let balanceNFT = await ticketFactoryContract.balanceOf(userAddress, tokenId);
           expect(balanceNFT).to.equal(ticketsBalance);
        });

        it('should let hordCongress to call setMinAmountToStake function', async() => {
            await ticketManagerContract.connect(hordCongress).setMinAmountToStake(minAmountToStake);
            expect(await ticketManagerContract.minAmountToStake())
                .to.be.equal(minAmountToStake);
        });

    })


});
