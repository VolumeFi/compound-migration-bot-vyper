#!/usr/bin/python3
import ape


def test_send_cusdc(
        UniswapV3Router, WETH, USDC, cUSDC, Alice, CompoundMigrationBot):
    UniswapV3Router.exactInputSingle(
        [WETH, USDC, 500, Alice, 2**256 - 1, 10**18, 1000 * 10**6, 0],
        sender=Alice, value=10**18)

    USDC.approve(cUSDC, 1000 * 10**6, sender=Alice)
    cUSDC.mint(1000 * 10**6, sender=Alice)
    balance = cUSDC.balanceOf(Alice)
    cUSDC.approve(CompoundMigrationBot, balance, sender=Alice)
    CompoundMigrationBot.send_to_bridge_usdc(balance, 4, b"1234567890", USDC, sender=Alice, value=10_000_000_000_000_000)



def test_send_ceth(
        UniswapV3Router, WETH, USDC, cETH, Alice, CompoundMigrationBot):
    cETH.mint(sender=Alice, value=10**18)
    balance = cETH.balanceOf(Alice)
    print(balance)
    cETH.approve(CompoundMigrationBot, balance, sender=Alice)
    input_amount = CompoundMigrationBot.redeemable_amount.call(cETH, Alice, balance)
    print(input_amount)
    payload = UniswapV3Router.exactInputSingle.encode_input([WETH, USDC, 500, CompoundMigrationBot, 2**256 - 1, input_amount, 1000 * 10**6, 0])
    CompoundMigrationBot.send_to_bridge_other(cETH, balance, UniswapV3Router, payload, 4, b"1234567890", USDC, sender=Alice, value=10_000_000_000_000_000)
