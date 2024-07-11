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
    def underlying() -> address: nonpayable

interface CEther:
    def mint(): payable

event SendToBridge:
    nonce: uint256
    sender: address
    token: address
    amount: uint256

event ReceiveFromBridge:
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

VETH: constant(address) = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE
DENOMINATOR: constant(uint256) = 10 ** 18
USDC_TOKEN_MESSENGER: immutable(address)
MESSAGE_TRANSMITTER: immutable(address)
USDC: immutable(address)
CUSDC: immutable(address)
CETH: immutable(address)
compass: public(address)
refund_wallet: public(address)
gas_fee: public(uint256)
service_fee_collector: public(address)
service_fee: public(uint256)
paloma: public(bytes32)
last_nonce: public(uint256)

@external
def __init__(_usdc_token_messenger: address, _message_transmitter: address, usdc: address, cusdc: address, ceth: address, _compass: address, _refund_wallet: address, _gas_fee: uint256, _service_fee_collector: address, _service_fee: uint256):
    USDC_TOKEN_MESSENGER = _usdc_token_messenger
    MESSAGE_TRANSMITTER = _message_transmitter
    USDC = usdc
    CUSDC = cusdc
    CETH = ceth
    self.compass = _compass
    self.refund_wallet = _refund_wallet
    self.gas_fee = _gas_fee
    self.service_fee_collector = _service_fee_collector
    self.service_fee = _service_fee
    assert _service_fee < DENOMINATOR, "Wrong fee percentage"
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
@payable
@nonreentrant('lock')
def send_to_bridge_usdc(amount: uint256, destination_domain: uint32, mint_recipient: bytes32, burn_token: address):
    _gas_fee: uint256 = self.gas_fee
    if msg.value > _gas_fee:
        send(msg.sender, unsafe_sub(msg.value, _gas_fee))
    else:
        assert msg.value == _gas_fee, "Insufficient gas fee"
    if _gas_fee > 0:
        send(self.refund_wallet, _gas_fee)
    _c_amount: uint256 = amount
    if _c_amount > 0:
        self._safe_transfer_from(CUSDC, msg.sender, self, _c_amount)
    else:
        _c_amount = ERC20(CUSDC).balanceOf(msg.sender)
        self._safe_transfer_from(CUSDC, msg.sender, self, _c_amount)
    _amount: uint256 = ERC20(USDC).balanceOf(self)
    CToken(CUSDC).redeem(_c_amount)
    _amount = ERC20(USDC).balanceOf(self) - _amount
    assert _amount > 0, "USDC redeem failed"
    _service_fee: uint256 = self.service_fee
    _service_fee_amount: uint256 = 0
    if _service_fee > 0:
        _service_fee_amount = unsafe_div(_amount * _service_fee, DENOMINATOR)
        _amount = unsafe_sub(_amount, _service_fee_amount)
    assert _amount > 0, "Insufficient"
    if _service_fee_amount > 0:
        self._safe_transfer(USDC, self.service_fee_collector, _service_fee_amount)
    self._safe_approve(USDC, USDC_TOKEN_MESSENGER, _amount)
    TokenMessenger(USDC_TOKEN_MESSENGER).depositForBurn(_amount, destination_domain, mint_recipient, burn_token)
    nonce: uint256 = self.last_nonce
    self.last_nonce = unsafe_add(nonce, 1)
    log SendToBridge(nonce, msg.sender, USDC, _amount)

@external
@nonreentrant('lock')
def receive_from_bridge_usdc(message: Bytes[1024], signature: Bytes[1024], receiver: address):
    self._paloma_check()
    _amount: uint256 = ERC20(USDC).balanceOf(self)
    MessageTransmitter(MESSAGE_TRANSMITTER).receiveMessage(message, signature)
    _amount = ERC20(USDC).balanceOf(self) - _amount
    assert _amount > 0, "Transmit Message error"
    _c_amount: uint256 = ERC20(CUSDC).balanceOf(self)
    self._safe_approve(USDC, CUSDC, _amount)
    CToken(CUSDC).mint(_amount)
    _c_amount = ERC20(CUSDC).balanceOf(self) - _c_amount
    self._safe_transfer(CUSDC, receiver, _c_amount)
    nonce: uint256 = self.last_nonce
    self.last_nonce = unsafe_add(nonce, 1)
    log ReceiveFromBridge(nonce, msg.sender, CUSDC, _c_amount)

@external
def redeemable_amount(ctoken: address, sender: address, amount: uint256) -> uint256:
    # This function is to get redeemable amount of the cToken. Expected to run as view function only.
    assert msg.sender == empty(address)
    _c_amount: uint256 = amount
    if _c_amount > 0:
        self._safe_transfer_from(ctoken, sender, self, _c_amount)
    else:
        _c_amount = ERC20(ctoken).balanceOf(sender)
        self._safe_transfer_from(ctoken, sender, self, _c_amount)
    _amount: uint256 = 0
    if ctoken == CETH:
        _amount = self.balance
        CToken(ctoken).redeem(_c_amount)
        _amount = self.balance - _amount
    else:
        underlying_token: address = CToken(ctoken).underlying()
        _amount = ERC20(underlying_token).balanceOf(self)
        CToken(ctoken).redeem(_c_amount)
        _amount = ERC20(underlying_token).balanceOf(self) - _amount
    return _amount

@external
@payable
@nonreentrant('lock')
def send_to_bridge_other(ctoken: address, amount: uint256, dex: address, payload: Bytes[1024], destination_domain: uint32, mint_recipient: bytes32, burn_token: address):
    _gas_fee: uint256 = self.gas_fee
    if msg.value > _gas_fee:
        send(msg.sender, unsafe_sub(msg.value, _gas_fee))
    else:
        assert msg.value == _gas_fee, "Insufficient gas fee"
    if _gas_fee > 0:
        send(self.refund_wallet, _gas_fee)
    _c_amount: uint256 = amount
    if _c_amount > 0:
        self._safe_transfer_from(ctoken, msg.sender, self, _c_amount)
    else:
        _c_amount = ERC20(ctoken).balanceOf(msg.sender)
        self._safe_transfer_from(ctoken, msg.sender, self, _c_amount)
    _amount: uint256 = 0
    underlying_token: address = empty(address)
    if ctoken == CETH:
        _amount = self.balance
        CToken(ctoken).redeem(_c_amount)
        _amount = self.balance - _amount
        underlying_token = VETH
    else:
        underlying_token = CToken(ctoken).underlying()
        _amount = ERC20(underlying_token).balanceOf(self)
        CToken(ctoken).redeem(_c_amount)
        _amount = ERC20(underlying_token).balanceOf(self) - _amount
    assert _amount > 0, "redeem failed"
    _usdc_amount: uint256 = ERC20(USDC).balanceOf(self)
    if underlying_token == VETH:
        raw_call(dex, payload, value=_amount)
    else:
        self._safe_approve(underlying_token, dex, _amount)
        raw_call(dex, payload)
    _usdc_amount = ERC20(USDC).balanceOf(self) - _usdc_amount
    _service_fee: uint256 = self.service_fee
    _service_fee_amount: uint256 = 0
    if _service_fee > 0:
        _service_fee_amount = unsafe_div(_usdc_amount * _service_fee, DENOMINATOR)
        _usdc_amount = unsafe_sub(_usdc_amount, _service_fee_amount)
    assert _usdc_amount > 0, "Insuf deposit"
    if _service_fee_amount > 0:
        self._safe_transfer(USDC, self.service_fee_collector, _service_fee_amount)
    self._safe_approve(USDC, USDC_TOKEN_MESSENGER, _usdc_amount)
    TokenMessenger(USDC_TOKEN_MESSENGER).depositForBurn(_usdc_amount, destination_domain, mint_recipient, burn_token)
    nonce: uint256 = self.last_nonce
    self.last_nonce = unsafe_add(nonce, 1)
    log SendToBridge(nonce, msg.sender, underlying_token, _usdc_amount)

@external
@nonreentrant('lock')
def receive_from_bridge_other(message: Bytes[1024], signature: Bytes[1024], receiver: address, ctoken: address, dex: address, payload: Bytes[1024]):
    self._paloma_check()
    _usdc_amount: uint256 = ERC20(USDC).balanceOf(self)
    MessageTransmitter(MESSAGE_TRANSMITTER).receiveMessage(message, signature)
    _usdc_amount = ERC20(USDC).balanceOf(self) - _usdc_amount
    assert _usdc_amount > 0, "Transmit Message error"
    underlying_token: address = empty(address)
    _amount: uint256 = 0
    if ctoken == CETH:
        underlying_token = VETH
        _amount = self.balance
    else:
        underlying_token = CToken(ctoken).underlying()
        _amount = ERC20(underlying_token).balanceOf(self)
    self._safe_approve(USDC, dex, _usdc_amount)
    raw_call(dex, payload)
    _c_amount: uint256 = ERC20(ctoken).balanceOf(self)
    if underlying_token == VETH:
        _amount = self.balance - _amount
        CEther(CETH).mint(value=_amount)
    else:
        _amount = ERC20(underlying_token).balanceOf(self) - _amount
        CToken(ctoken).mint(_amount)
    _c_amount = ERC20(ctoken).balanceOf(self) - _c_amount
    assert _c_amount > 0, "Ctoken mint failed"
    self._safe_transfer(ctoken, receiver, _c_amount)
    nonce: uint256 = self.last_nonce
    self.last_nonce = unsafe_add(nonce, 1)
    log ReceiveFromBridge(nonce, msg.sender, ctoken, _c_amount)

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
    assert new_service_fee < DENOMINATOR, "Wrong fee percentage"
    self._paloma_check()
    old_service_fee: uint256 = self.service_fee
    self.service_fee = new_service_fee
    log UpdateServiceFee(old_service_fee, new_service_fee)

@external
@payable
def __default__():
    pass