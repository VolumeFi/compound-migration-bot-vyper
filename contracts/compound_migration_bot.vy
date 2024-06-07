#pragma version 0.3.10
#pragma optimize gas
#pragma evm-version shanghai
"""
@title Compound Migration Bot
@license Apache 2.0
@author Volume.finance
"""

interface ERC20:
    def balanceOf(_owner: address) -> uint256: view
    def approve(_spender: address, _value: uint256) -> bool: nonpayable
    def transfer(_to: address, _value: uint256) -> bool: nonpayable
    def transferFrom(_from: address, _to: address, _value: uint256) -> bool: nonpayable

interface TokenMessenger:
    def depositForBurn(amount: uint256, destinationDomain: uint32, mintRecipient: bytes32, burnToken: address) -> uint64: nonpayable

interface MessageTransmitter:
    def receiveMessage(message: Bytes[1024], signature: Bytes[1024]): nonpayable

interface CToken:
    def redeem(redeemTokens: uint256) -> uint256: nonpayable
    def mint(mintAmount: uint256): nonpayable

event MigrationStart:
    nonce: uint256
    sender: address
    token: address
    amount: uint256

event MigrationEnd:
    nonce: uint256
    sender: address
    token: address
    amount: uint256

event UpdateCompass:
    old_compass: address
    new_compass: address

event UpdateRefundWallet:
    old_refund_wallet: address
    new_refund_wallet: address

event SetPaloma:
    paloma: bytes32

event UpdateGasFee:
    old_gas_fee: uint256
    new_gas_fee: uint256

event UpdateServiceFeeCollector:
    old_service_fee_collector: address
    new_service_fee_collector: address

event UpdateServiceFee:
    old_service_fee: uint256
    new_service_fee: uint256

USDC_TOKEN_MESSENGER: immutable(address)
MESSAGE_TRANSMITTER: immutable(address)
USDC: immutable(address)
CUSDC: immutable(address)
compass: public(address)
refund_wallet: public(address)
gas_fee: public(uint256)
service_fee_collector: public(address)
service_fee: public(uint256)
paloma: public(bytes32)
last_nonce: public(uint256)

@external
def __init__(_usdc_token_messenger: address, _message_transmitter: address, usdc: address, cusdc: address, _compass: address, _refund_wallet: address, _gas_fee: uint256, _service_fee_collector: address, _service_fee: uint256):
    USDC_TOKEN_MESSENGER = _usdc_token_messenger
    MESSAGE_TRANSMITTER = _message_transmitter
    USDC = usdc
    CUSDC = cusdc
    self.compass = _compass
    self.refund_wallet = _refund_wallet
    self.gas_fee = _gas_fee
    self.service_fee_collector = _service_fee_collector
    self.service_fee = _service_fee
    log UpdateCompass(empty(address), _compass)
    log UpdateRefundWallet(empty(address), _refund_wallet)
    log UpdateGasFee(empty(uint256), _gas_fee)
    log UpdateServiceFeeCollector(empty(address), _service_fee_collector)
    log UpdateServiceFee(empty(uint256), _service_fee)

@internal
def _safe_approve(_token: address, _spender: address, _value: uint256):
    assert ERC20(_token).approve(_spender, _value, default_return_value=True), "Failed approve"

@internal
def _safe_transfer(_token: address, _to: address, _value: uint256):
    assert ERC20(_token).transfer(_to, _value, default_return_value=True), "Failed transfer"

@internal
def _safe_transfer_from(_token: address, _from: address, _to: address, _value: uint256):
    assert ERC20(_token).transferFrom(_from, _to, _value, default_return_value=True), "Failed transferFrom"

@external
@nonreentrant('lock')
def migrate_usdc_start(amount: uint256, destination_domain: uint32, mint_recipient: bytes32, burn_token: address):
    _amount: uint256 = amount
    if _amount > 0:
        self._safe_transfer_from(CUSDC, msg.sender, self, _amount)
    else:
        _amount = ERC20(CUSDC).balanceOf(msg.sender)
        self._safe_transfer_from(CUSDC, msg.sender, self, _amount)
    _amount = ERC20(USDC).balanceOf(self)
    CToken(CUSDC).redeem(_amount)
    _amount = ERC20(USDC).balanceOf(self) - _amount
    assert _amount > 0, "USDC redeem failed"
    self._safe_approve(USDC, USDC_TOKEN_MESSENGER, _amount)
    TokenMessenger(USDC_TOKEN_MESSENGER).depositForBurn(_amount, destination_domain, mint_recipient, burn_token)
    nonce: uint256 = self.last_nonce
    self.last_nonce = unsafe_add(nonce, 1)
    log MigrationStart(nonce, msg.sender, USDC, _amount)

@external
@nonreentrant('lock')
def migrate_usdc_finish(message: Bytes[1024], signature: Bytes[1024], receiver: address):
    _amount: uint256 = ERC20(USDC).balanceOf(self)
    MessageTransmitter(MESSAGE_TRANSMITTER).receiveMessage(message, signature)
    _amount = ERC20(USDC).balanceOf(self) - _amount
    assert _amount > 0, "Transmit Message error"
    _c_amount: uint256 = ERC20(CUSDC).balanceOf(self)
    self._safe_approve(USDC, CUSDC, _amount)
    CToken(CUSDC).mint(_amount)
    _c_amount = ERC20(CUSDC).balanceOf(self) - _c_amount
    self._safe_approve(CUSDC, receiver, _c_amount)
    nonce: uint256 = self.last_nonce
    self.last_nonce = unsafe_add(nonce, 1)
    log MigrationEnd(nonce, msg.sender, CUSDC, _amount)

@internal
def _paloma_check():
    assert msg.sender == self.compass, "Not compass"
    assert self.paloma == convert(slice(msg.data, unsafe_sub(len(msg.data), 32), 32), bytes32), "Invalid paloma"

@external
def update_compass(new_compass: address):
    self._paloma_check()
    self.compass = new_compass
    log UpdateCompass(msg.sender, new_compass)

@external
def set_paloma():
    assert msg.sender == self.compass and self.paloma == empty(bytes32) and len(msg.data) == 36, "Invalid"
    _paloma: bytes32 = convert(slice(msg.data, 4, 32), bytes32)
    self.paloma = _paloma
    log SetPaloma(_paloma)

@external
def update_refund_wallet(new_refund_wallet: address):
    self._paloma_check()
    old_refund_wallet: address = self.refund_wallet
    self.refund_wallet = new_refund_wallet
    log UpdateRefundWallet(old_refund_wallet, new_refund_wallet)

@external
def update_gas_fee(new_gas_fee: uint256):
    self._paloma_check()
    old_gas_fee: uint256 = self.gas_fee
    self.gas_fee = new_gas_fee
    log UpdateGasFee(old_gas_fee, new_gas_fee)

@external
def update_service_fee_collector(new_service_fee_collector: address):
    self._paloma_check()
    old_service_fee_collector: address = self.service_fee_collector
    self.service_fee_collector = new_service_fee_collector
    log UpdateServiceFeeCollector(old_service_fee_collector, new_service_fee_collector)

@external
def update_service_fee(new_service_fee: uint256):
    self._paloma_check()
    old_service_fee: uint256 = self.service_fee
    self.service_fee = new_service_fee
    log UpdateServiceFee(old_service_fee, new_service_fee)

@external
@payable
def __default__():
    pass