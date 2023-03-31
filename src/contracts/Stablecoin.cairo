// authors: Pikkuherkko & banch12

#[contract]
mod Stablecoin {

    // USES
    use zeroable::Zeroable; // what is this?
    use starknet::get_caller_address;
    use starknet::get_contract_address; // to check this
    use starknet::ContractAddressZeroable;
    use starknet::ContractAddressIntoFelt;
    use starknet::FeltTryIntoContractAddress;
    use starknet::contract_address_try_from_felt;
    use traits::Into;
    use traits::TryInto;
    use array::ArrayTrait;
    use option::OptionTrait;

    use src::interfaces::IERC20; // Import IERC20 interface
    use src::libraries::ERC20_library::ERC20Library::ERC20Impl;

    use src::interfaces::IReentrancyGuard; 
    use src::libraries::ReentrancyGuard_library::ReentrancyGuardLibrary::ReentrancyGuardImpl; 

    // Impiric Oracle related stuff: TODO it later

    ////////////////////////////////
    // EVENTS
    ////////////////////////////////

    #[event]
    fn CreateVault_event(vaultID: u256, creator: ContractAddress) {}
    
    #[event]
    fn DestroyVault_event(vaultID: u256) {}
    
    #[event]
    fn TransferVault_event(vaultID: u256, from_: ContractAddress, to: ContractAddress) {}
    
    #[event]
    fn DepositCollateral_event(vaultID: u256, amount: u256) {}
    
    #[event]
    fn WithdrawCollateral_event(vaultID: u256, amount: u256) {}
    
    #[event]
    fn BorrowToken_event(vaultID: u256, amount: u256) {}

    #[event]
    fn PayBackToken_event(vaultID: u256, amount: u256, closingFee: u256) {}
    
    #[event]
    fn BuyRiskyVault_event(vaultID: u256, owner: ContractAddress, buyer: ContractAddress, amountPaid: u256) {}


    // Storage

    struct Storage {
	wethAddress: ContractAddress,
	ethPriceSource: ContractAddress,
	_minimumCollateralPercentage: u256,
	erc721: ContractAddress,
	vaultCount: u256,
        debtCeiling: u256,
	closingFee: u256,
	openingFee: u256,
	treasury: u256,
	tokenPeg: u256,
	vaultExistence: LegacyMap::<u256, ContractAddress>,
	vaultOwner: LegacyMap::<u256, ContractAddress>,
	vaultCollateral: LegacyMap::<u256, u256>,
	vaultDebt: LegacyMap::<u256, u256>,
	stabilityPool: u256,
    }

    ////////////////////////////////
    // CONSTRUCTOR
    ////////////////////////////////
    // TODO Later


    #[constructor]
    fn constructor(
        weth_: ContractAddress,
        ethPriceSourceAddress_: ContractAddress,
        minimumCollateralPercentage_: u256,
        name_: felt252,
        symbol_: felt252,
        vaultAddress_: ContractAddress,
        owner_: ContractAddress
    ) {
        ERC20::initializer(name_, symbol_, 18_u8); // ??. Is it constructor? I don't see initializer fn in ERC20
        IOwnable::initializer(owner_);
        wethAddress::write(weth_);

        //assert_not_zero(ethPriceSourceAddress); // do we need this ?
        //let zero_as_uint256: Uint256 = Uint256(0,0); // do we need this
        //let (le) = uint256_lt(zero_as_uint256, minimumCollateralPercentage);
        //assert le = 1;
        assert(minimumCollateral >= 0_u256, 'invalid value of minimumCollateralPercentage');

        //let ten_as_uint256: u256 = Uint256(10000000000000000000, 0);
        debtCeiling::write(10_u256); // ten
        //let fifty_as_uint256: Uint256 = Uint256(50,0);
        closingFee::write(50_u256); // 0.5%
        openingFee::write(0_u256);
        ethPriceSource::write(ethPriceSourceAddress_);
        stabilityPool::write(0_u256);
        //let one_as_uint256: Uint256 = Uint256(100000000, 0);
        tokenPeg::write(1_u256); // $1
        erc721::write(vaultAddress_);
        _minimumCollateralPercentage::write(minimumCollateralPercentage_);
        return();
    }

    fn onlyVaultOwner( vaultID: u256) {
        let existence: ContractAddress = vaultExistence::read(vaultID);
        assert(existence == 1, 'Vault does not exist'); // to check if 1 is ok here. 
        let owner: ContractAddress = vaultOwner.read(vaultID);
        let (caller) = get_caller_address();
        assert(caller == owner, 'Vault is not owned by you');
        return();
}

    ////////////////////////////////
    // VIEW FUNCTIONS
    ////////////////////////////////

    #[view]
    fn getDebtCeiling() -> (u256) {
        debtCeiling::read()
    }

    #[view]
    fn getClosingFee() -> u256 {
        closingFee::read()
    }
    
    #[view]
    fn getOpeningFee() -> u256 {
        openingFee::read()
    }
    
    #[view]
    fn getTokenPriceSource() -> u256 {
        tokenPeg::read()
    }
    
    #[view]
    fn getEthPriceSource() -> u256 {
        const PAIR_ID = 19514442401534788;  // str_to_felt("ETH/USD")
	let priceSource = ethPriceSource::read();
	let (price, decimals, last_updated_timestamp, num_sources_aggregated) = IEmpiricOracle::get_spot_median(priceSource, PAIR_ID);
	let res: u256 = price.try_into().unwrap; // convert felt to u256
	return res;
    }

    // TODO Later
    // internal function
    fn calculateCollateralProperties(
        collateral: u256, debt: u256
	) -> (
	collateralValueTimes100: u256, debtValue: u256
	)
    {
        let ethPrice = getEthPriceSource();
	assert(ethPrice > 0, 'Invalid ETH Price');

	let _tokenPeg: u256 = getTokenPriceSource();
	assert(_tokenPeg > 0, 'Invalid tokenPeg value');
	
	let collateralValue: u256 = collateral * ethPrice;
	assert(collateralValue > collateral, 'Invalid value');

	let debtValue: u256 = debt * _tokenPeg;
	assert(debtValue > debt, 'Invalid value');

	let collateralValueTimes100 = collateralValue * 100_u256;
	assert(collateralValueTimes100 > collateralValue 'Invalid value');

	return (collateralValueTimes100, debtValue);
    }

    fn isValidCollateral() -> bool {

    let (collateralValueTimes100: u256, debtValue: u256) = calculateCollateralProperties(collateral, debt);

    let collateralPercentage: u256 = collateralValueTimes100/debtValue;

    let minimumCollateralPercentage: u256 = _minimumCollateralPercentage::read();

    if (minimumCollateralPercentage <= collateralPercentage) {
        return 1;
    }

    0 // return 0
    }

    ////////////////////////////////
    // EXTERNAL FUNCTIONS
    ////////////////////////////////


    #[external]
    fn createVault() -> (id: u256) {
        let caller = get_called_address();
        let id: u256 =  vaultCount::read();

        let updated_vaultCount = id + 1_u256;

        assert(updated_vaultCount >= id 'same vaultCount value');

	vaultExistence:write(id, 1);
	vaultOwner::write(id, caller);
	
	CreateVault_event(id, caller); 

	let _erc721 = IERC721::read();
	IMyValut::mint(_erc721, caller, id);

	return id;

    }
    #
    #[external]
    fn destroyVault(vaultID: u256) {
    
        IReentrancyGuard::start();
	onlyVaultOwner(vaultID);  // To implement this fn

	let _vaultDebt: u256 = vaultDebt::read(vaultID);
        assert(_vaultDebt == 0_256 'Vault has outstanding debt'); // error msg when _vaultDebt is not 0

	let caller = get_caller_address();
	let _vaultCollateral: u256 = vaultCollateral::read(vaultID);

	// to check whether <= comparison is valid
	if (_vaultCollateral <= 1_u256) {
	    ERC20::transfer(caller, _vaultCollateral);
	}

	let _erc721 = IERC721::read();
	IMyVault::burn(_erc721, vaultID);
	vaultExistence:write(vaultID, 1); // to check if 1 is valid argument
	vaultOwner::write(vaultID, 0); // to check if 0 is valid argument
	vaultCollateral::write(vaultID, 0_256);
	vaultDebt::write(vaultID, 0_256);

	DestroyVault_event(vaultID);
        IReentrancyGuard::end();
	return();

    }
    
    #[external]
    fn transferVault(vaultID: u256, to:  ContractAddress) {

        onlyVaultOwner(vaultID);  // To implement this fnonlyVaultOwner(vaultID)
	let _erc721 = IERC721::read();
	IMyVault::burn(_erc721, vaultID);
	IMyVault::mint(_erc721, to, vaultID);

	let caller = get_caller_address();
	TransferVault_event(vaultID, caller, to);
	return();
    }

    #[external]
    fn depositCollateral( vaultID: u256, amount: u256) {

        onlyVaultOwner(vaultID);  // To implement this fnonlyVaultOwner(vaultID)
	let _vaultCollateral: u256 = vaultCollateral::read(vaultID);
	let newCollateral = _vaultCollateral + amount;

	// no need to check overflow, since operation is Cairo1 is overflow protected

	let caller = get_caller_address();
	let this = get_contract_address();
	let weth = wethAddress::read();
	IERC20::transferFrom(weth, caller, this, amount); // to check this

	vaultCollateral::write(vaultID, newCollateral);
	DepositCollateral_event(vaultID, amount);
	return();
    }

    #[external]
    fn withdrawCollateral( vaultID: u256, amount: u256) {

        onlyVaultOwner(vaultID);  // To implement this fnonlyVaultOwner(vaultID)
        IReentrancyGuard::start();

	let _vaultCollateral: u256 = vaultCollateral::read(vaultID);
        assert(amount <= _vaultCollateral, 'Vault does not have enough collateral'); 

	let newCollateral = _vaultCollateral - amount;
	let _vaultDebt: u256 = vaultDebt::read(vaultID);

	if (_vaultDebt != 0_u256) {
	    let bool  = isValidCollateral(newCollateral, _vaultDebt);
	    assert( bool == 1, 'Withdrawal would put vault below minimum collateral percentage');
	}

	let caller = get_caller_address();
	vaultCollateral::write(vaultID, newCollateral);
	let weth = wethAddress::read();
        IERC20::approve(weth, caller, amount);
	IERC20::transfer(weth, caller, amount);
	WithdrawCollateral_event(vaultID, amount);
	IReentrancyGuard::end()
	return();
    }

    #[external]
    fn borrowToken( vaultID: u256, amount: u256) {
        onlyVaultOwner(vaultID);  // To implement this fnonlyVaultOwner(vaultID)

	assert (amount != 0_u256, 'Must borrow non-zero amount');

	let _totalSupply: u256 = ERC20::total_supply();
	let newSupply: u256 = _totalSupply + amount;
	let _debtCeiling:  u256 = debtCeiling::read();
	
	assert (newSupply <= _debtCeiling, 'borrowToken: Cannot mint over totalSupply');

	let _vaultDebt: u256 = vaultDebt::read(vaultID);
	let _newDebt: u256 = _vaultDebt + amount; // this opn is overflow protected

	let _vaultCollateral: u256 = vaultCollateral::read(vaultID);

	assert (_newDebt > _vaultDebt);

	let (bool) = isValidCollateral(_vaultCollateral, _newDebt);
	assert (bool == 1, 'Borrow would put vault below minimum collateral percentage');

	vaultDebt::write(vaultID, _newDebt);

	let caller = get_caller_address();
	mint(caller, amount);
	BorrowToken_event(vaultID, amount);
	return();
    }
    
    #[external]
    fn payBackToken( vaultID: u256, amount: u256) {
        
        onlyVaultOwner(vaultID);  // To implement this fnonlyVaultOwner(vaultID)
	let caller = get_caller_address();
	let bal = ERC20::balance_of(caller);
	assert (bal >= amount , 'Token balance too low');

	let _vaultDebt: u256 = vaultDebt::read(vaultID);
	assert (_valutDebt >= amount , 'Token balance too low');

	let _ethPrice: u256 = getEthPriceSource();
	let _tokenPeg: u256 = getTokenPriceSource();
	let _closingFee: u256 = closingFee::read();

	uint256 _closingFee = (amount.mul(closingFee).mul(getTokenPriceSource())).div(getEthPriceSource().mul(10000));

	let closingFeeEth: u256 = (_tokenPeg * amount * _closingFee)/(_ethPrice * 10000_u256);

	let _newDebt: u256 = _vaultDebt - amount;
	vaultDebt::write(vaultID);

	let _vaultCollateral: u256  = vaultCollateral::read(vaultID);
	let _newVaultCollateral: u256 = _vaultCollateral -  _closingFeeEth;
	vaultCollateral::write(vaultID, _newVaultCollateral);

	ERC20::_burn(caller, amount);
	PayBackToken_event(vaultID, amount, closingFeeEth);
	return();
    }

    #[external]
    fn buyRiskyValut( vaultID: u256) {

        let _vaultExistence = vaultExistence::read(vaultID);
	assert (_vaultExistence == 1 , 'Vault does not exist');

	let _vaultCollateral: u256  = vaultCollateral::read(vaultID);
	let _vaultDebt: u256 = vaultDebt::read(vaultID);

	let (_collateralValueTimes100: u256, _debtValue: u256) = calculateCollateralProperties(_vaultCollateral, _vaultDebt);

	let collateralPercentage: u256 = _collateralValueTimes100 / _debtValue;
	let minimumCollateralPercentage = _minimumCollateralPercentage::read();
	assert(collateralPercentage < _minimumCollateralPercentage, 'Vault is not below minimum collateral percentage');

	let maximumDebtValue: u256 = _collateralValueTimes100 / minimumCollateralPercentage;

	let ethPrice: u256 = getEthPriceSource();
	let maximumDebt: u256 = maximumDebtValue / ethPrice;

	let debtDifference: u256 = _vaultDebt - maximumDebt;

	let caller = get_caller_address();
	let caller_bal: u256 = balanceOf(caller); // to implement balanceOf

	assert(caller_bal >= debtDifference, 'Token balance too low to pay off outstanding debt');

	let previusOwner = vaultOwner::read(vaultID);

        vaultOwner::write(vaultID, caller);
	vaultDebt::write(vaultID, maximumDebt);

	let _tokenPeg: u256 = getTokenPriceSource();
	let _closingFee: u256 = closingFee.read();

	let closingFeeEth: u256 = (_tokenPeg * debtDifference * _closingFee)/(_ethPrice * 10000_u256);

	let newVaultCollateral: u256 = _vaultCollateral - closingFeeEth;
	vaultCollateral::write(vaultID, newVaultCollateral);

	let _treasury: u256 = treasury::read();
	let treasuryVaultCollateral: u256 = vaultCollateral::read(_treasury);
        let newTreasuryVaultCollateral: u256 = treasuryVaultCollateral + closingFeeEth;
	vaultCollateral::write(_treasury, newTreasuryVaultCollateral);

	ERC20::_burn(caller, debtDifference);
	let _erc721 = IERC721::read();
	IMyValut::burn(_erc721, vaultID);
	IMyValut::mint(_erc721, caller, id);

	BuyRiskyVault_event(vaultID, previusOwner, caller, debtDifference);
	return();
    }
    
 


// OZ ERC20

    #view
    func name() -> felt {
        ERC20::name()
    }
    
    #view
    func symbol() -> felt {
        ERC20::symbol()
    }
    
    #view
    func totalSupply() -> (totalSupply: u256) {
        let (totalSupply: u256) = ERC20::total_supply();
        return totalSupply;
    }
    
    #view
    func decimals() -> felt {
        ERC20::decimals()
    }
    
    #view
    func balanceOf(account: felt) -> u256 {
        ERC20::balance_of(account)
    }
    
    #view
    func allowance( owner: felt, spender: felt) -> (remaining: u256) {
        ERC20::allowance(owner, spender)
    }
    
    #view
    func owner() -> (owner: felt) {
        //Ownable::owner()
        IOwnable::get_owner() // To check this
    }
    
    #external
    func transfer( recipient: felt, amount: Uint256) -> (success: felt) {
        ERC20::transfer(recipient, amount)
    }
    
    #external
    func transferFrom( sender: felt, recipient: felt, amount: u256) -> (success: felt) {
        ERC20::transfer_from(sender, recipient, amount)
    }
    
    #external
    func approve( spender: felt, amount: u256) -> (success: felt) {
        ERC20::approve(spender, amount)
    }
    
    #external
    func increaseAllowance( spender: felt, added_value: u256) -> (success: felt) {
        ERC20::increase_allowance(spender, added_value)
    }
    
    #external
    func decreaseAllowance( spender: felt, subtracted_value: u256) -> (success: felt) {
        ERC20::decrease_allowance(spender, subtracted_value)
    }
    
    #external
    func mint( to: felt, amount: u256) {
        IOwnable::assert_only_owner();
        ERC20::_mint(to, amount);
        return ();
    }
    
    #external
    func transferOwnership( newOwner: felt) {
        IOwnable::transfer_ownership(newOwner)
    }
    
    #external
    func renounceOwnership() {
        IOwnable::renounce_ownership();
        return ();
    }


}
