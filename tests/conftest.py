#!/usr/bin/python3

import pytest


@pytest.fixture(scope="session")
def Deployer(accounts):
    return accounts[0]


@pytest.fixture(scope="session")
def Alice(accounts):
    return accounts[1]


@pytest.fixture(scope="session")
def Bob(accounts):
    return accounts[2]


@pytest.fixture(scope="session")
def RefundWallet(accounts):
    return accounts[3]


@pytest.fixture(scope="session")
def ServiceFeeCollector(accounts):
    return accounts[4]


@pytest.fixture(scope="session")
def Compass(accounts):
    return accounts[5]


@pytest.fixture(scope="session")
def CurveRouter(project):
    return project.curve_router.at(
        "0xF0d4c12A5768D806021F80a262B4d39d26C58b8D")


@pytest.fixture(scope="session")
def WETH(project):
    return project.weth.at("0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2")


@pytest.fixture(scope="session")
def USDC(project):
    return project.usdc.at("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48")


@pytest.fixture(scope="session")
def cUSDC(project):
    return project.CErc20.at("0x39AA39c021dfbaE8faC545936693aC917d5E7563")


@pytest.fixture(scope="session")
def cETH(project):
    return project.CEther.at("0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5")


@pytest.fixture(scope="session")
def UniswapV3Router(project):
    return project.uniswap_v3_router.at(
        "0xE592427A0AEce92De3Edee1F18E0157C05861564")


@pytest.fixture(scope="session")
def USDCTokenManager(project):
    return project.usdc_token_manager.at(
        "0xBd3fa81B58Ba92a82136038B25aDec7066af3155")


@pytest.fixture(scope="session")
def MessageTransmitter(project):
    return project.message_transmitter.at(
        "0xC30362313FBBA5cf9163F0bb16a0e01f01A896ca")


@pytest.fixture(scope="session")
def CompoundMigrationBot(
        USDCTokenManager, MessageTransmitter, USDC, cUSDC, cETH, Compass,
        RefundWallet, ServiceFeeCollector, Deployer, project):
    gas_fee = 10_000_000_000_000_000
    service_fee = 2_000_000_000_000_000
    return Deployer.deploy(
        project.compound_migration_bot, USDCTokenManager, MessageTransmitter,
        USDC, cUSDC, cETH, Compass, RefundWallet, gas_fee, ServiceFeeCollector,
        service_fee)
